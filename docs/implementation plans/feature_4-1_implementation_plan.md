# Feature 4.1: Longhorn Distributed Storage — Implementation Plan

Harden, expand, and empirically validate the cluster's **Longhorn** distributed block storage plane across all consolidated bare-metal SATA disks (`controlplane-1`, `worker-1`, `worker-2`), ensuring every physical disk is active in the Longhorn UI and synchronous cross-node block replication is verified under strict GitOps governance.

---

## 1. State Retrieval & Audit-Before-Write (ABW)

### Roadmap Alignment (`docs/HomeLab_Project_Roadmap.csv`)
* **Parent Epic:** Epic 4 (`Core Infrastructure Services`) — `In-progress`
* **Preceding Epic / Feature:** Epic 3 (`GitOps & Analytic Stack`) / Feature 3.5 (`Serverless Execution (Knative)`) — `Done`
* **Active Feature:** Feature 4.1 (`Longhorn Distributed Storage`) — `In-progress`
* **Definition of Done (DoD) Criteria:**
  1. Longhorn UI shows all disks active.
  2. Volume replication verified across nodes.

### Existing Files Audited
* [docs/HomeLab_Project_Roadmap.csv](../HomeLab_Project_Roadmap.csv)
* [docs/Retrospective.csv](../Retrospective.csv) (specifically Features 3.5, 3.4-R, 3.4, 3.3, 3.2, and 3.1)
* [docs/hardware_inventory.csv](../hardware_inventory.csv)
* [docs/adr/0010-plane-1-remote-state-and-hardware-consolidation.md](../adr/0010-plane-1-remote-state-and-hardware-consolidation.md)
* [docs/architecture/05-distributed-storage.md](../architecture/05-distributed-storage.md)
* [docs/runbooks/cluster-access.md](../runbooks/cluster-access.md)
* [infrastructure/bootstrap/main.tf](../../infrastructure/bootstrap/main.tf) & [infrastructure/bootstrap/terraform.tfvars](../../infrastructure/bootstrap/terraform.tfvars)
* [argocd/apps/longhorn.yaml](../../argocd/apps/longhorn.yaml) & [argocd/apps/README.md](../../argocd/apps/README.md)
* [infrastructure/storage/longhorn/kustomization.yaml](../../infrastructure/storage/longhorn/kustomization.yaml), [infrastructure/storage/longhorn/namespace.yaml](../../infrastructure/storage/longhorn/namespace.yaml), [infrastructure/storage/longhorn/values.yaml](../../infrastructure/storage/longhorn/values.yaml)
* [infrastructure/storage/README.md](../../infrastructure/storage/README.md)

### Cross-Layer Architectural Flow (Plane 1 -> Plane 2 -> Plane 3)
1. **Plane 1 (Talos Linux / OpenTofu):** `infrastructure/bootstrap/main.tf` provisions Talos `v1.13.7` with `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools`. On `controlplane-1` and `worker-1` (`mount_secondary_disk = true`), a `UserVolumeConfig` formats the secondary SATA HDD as XFS (`longhorn-extra`) and `machine.kubelet.extraMounts` bind-mounts `/var/mnt/longhorn-extra` (`rshared`, `rw`) into the kubelet mount namespace.
2. **Plane 2 (Longhorn Operator & Node CRs):** `argocd/apps/longhorn.yaml` (Sync Wave `1`, native Helm chart `v1.6.2`) deploys `longhorn-manager`, `longhorn-csi-plugin`, and `longhorn-ui` (`svc/longhorn-frontend:80`, accessed via port-forward `http://localhost:8081` per [docs/runbooks/cluster-access.md](../runbooks/cluster-access.md)). Longhorn manages per-node disk attachments via `longhorn.io/v1beta2` `Node` Custom Resources in `longhorn-system`.
3. **Plane 3 (Kubernetes CSI & Replicated Volumes):** Workload `PersistentVolumeClaim` objects targeting the default `longhorn` `StorageClass` dynamically provision block `PersistentVolume` instances backed by synchronous iSCSI replicas across physical nodes over the 1000BASE-T Gigabit enclave (`10.10.10.0/24`, TCP `9500-9501`).

### Physical Storage Inventory & Baseline Delta (Post-Feature 3.4-R)

| Node | IP | Primary OS Disk (`/var/lib/longhorn`) | Secondary Data Disk (`/var/mnt/longhorn-extra`) | Current Longhorn State |
| :--- | :--- | :--- | :--- | :--- |
| `controlplane-1` (HP Pro 6300 SFF) | `10.10.10.51` | `/dev/sda` — 256 GB SSD (OS + `etcd`) | `/dev/sdb` — 931.5 GB SATA HDD (XFS) | Only `/var/lib/longhorn` auto-discovered; `/var/mnt/longhorn-extra` **unregistered** |
| `worker-1` (HP Pavilion 590) | `10.10.10.52` | `/dev/sdc` — 931.5 GB SATA HDD (OS) | `/dev/sdd` — 931.5 GB SATA HDD (XFS) | Only `/var/lib/longhorn` auto-discovered; `/var/mnt/longhorn-extra` **unregistered** |
| `worker-2` (Lenovo 310S) | `10.10.10.53` | `/dev/sdc` — 465.8 GB SATA HDD (OS) | None (`mount_secondary_disk = false`) | `/var/lib/longhorn` active |

### Identified Configuration & Documentation Drift
1. **Unregistered Secondary SATA Disks (~1.86 TB Dormant Capacity):** Although OpenTofu mounts `/var/mnt/longhorn-extra` on `controlplane-1` and `worker-1`, Longhorn only auto-registers `defaultDataPath` (`/var/lib/longhorn`). The two 1 TB secondary drives are not yet registered in `nodes.longhorn.io` and do not appear as active disks in the Longhorn UI.
2. **`etcd` I/O Contention Risk on `controlplane-1`:** Because `allow_scheduling = true` on `controlplane-1`, Longhorn auto-registered `/var/lib/longhorn` on `/dev/sda` (the 256 GB OS + `etcd` SSD). Scheduling Longhorn block replicas on the `etcd` disk risks fsync latency spikes while the dedicated 931.5 GB HDD (`/var/mnt/longhorn-extra`) sits idle.
3. **Orphaned Kustomize/Helm Files (`infrastructure/storage/longhorn/`):** `argocd/apps/longhorn.yaml` uses ArgoCD native Helm rendering with inline `values`. The legacy `kustomization.yaml`, `namespace.yaml`, and `values.yaml` in `infrastructure/storage/longhorn/` are unreferenced and have drifted (`replicaSoftAntiAffinity: false`, `metrics.prometheus.enabled: true` exist in `values.yaml` but are missing from `argocd/apps/longhorn.yaml`).
4. **Documentation Drift:** [docs/architecture/05-distributed-storage.md](../architecture/05-distributed-storage.md) and [infrastructure/storage/README.md](../../infrastructure/storage/README.md) still describe single-path `/var/lib/longhorn` worker-only storage and contain imperative `kubectl apply`/`create ns` validation snippets.

### Retrospective Lessons Applied
* **Search-Before-Write Schema Verification (3.2, 3.3, 3.5 Sustain):** Verified upstream Longhorn `v1.6.x` `longhorn.io/v1beta2` `Node` CRD schema: `storageReserved` is strictly an `int64` in **bytes** (not a K8s Quantity string), and `node.longhorn.io/default-disks-config` annotations are **not** retroactively applied to already-initialized Longhorn `Node` CRs.
* **Default to Native Helm (3.2 Improve):** Retain native Helm rendering in `argocd/apps/longhorn.yaml`; repurpose `infrastructure/storage/longhorn/` strictly for declarative `longhorn.io/v1beta2` `Node` CRs (Option A) rather than Kustomize-wrapped Helm.
* **Operator Upgrade Deadlock & Version Debt Scope Containment (3.4-R, 3.5 Improve):** Retain pinned Longhorn chart `v1.6.2` during Feature 4.1; defer chart version upgrades to Feature 4.4 (`Platform Lifecycle & Version Debt Remediation`).
* **Terminal Scrollback Clipping (3.5 Improve):** Every diagnostic command in all Validation Blocks is isolated in its own markdown code block.
* **Strict GitOps & Command Execution Boundaries (3.3, 3.4, 3.5 Sustain):** Zero imperative `kubectl apply`/`create`/`edit`/`patch`/`delete` commands. Even Phase 3's replication verification workload is deployed and torn down declaratively via ArgoCD.

---

## 2. Architectural Decisions & Two-Option Trade-Offs

### Decision 1: Multi-Disk Registration Strategy (`/var/mnt/longhorn-extra`)
* **Option A (Ideal — Recommended): Strict GitOps via `longhorn.io/v1beta2` `Node` CRs (`argocd/apps/longhorn-config.yaml`)**
  * Capture each node's existing auto-generated `default-disk-<hash>` key in Phase 1 (preserving active MinIO PVCs without disruption).
  * Declare explicit `apiVersion: longhorn.io/v1beta2` `kind: Node` manifests under `infrastructure/storage/longhorn/nodes/` tracked by a dedicated ArgoCD `Application` (`argocd/apps/longhorn-config.yaml`, `sync-wave: "2"`, `ServerSideApply=true`, `ServerSideDiff=true`, `automated.prune: false` to prevent accidental volume loss).
  * Register `/var/mnt/longhorn-extra` on `controlplane-1` and `worker-1` with explicit byte-accurate `storageReserved` thresholds and disk tags (`["hdd", "dedicated"]`), and align `argocd/apps/longhorn.yaml` inline Helm values (`replicaSoftAntiAffinity: false`, `metrics.prometheus.enabled: true`).
* **Option B (High-Compatibility): Interactive Registration via Longhorn UI**
  * Register `/var/mnt/longhorn-extra` manually through the Longhorn UI (`http://localhost:8081`) on `controlplane-1` and `worker-1`, keeping only the Helm chart in Git. Avoids Server-Side Apply field-manager coordination on `nodes.longhorn.io`, at the cost of non-declarative disk topology that must be manually re-entered after any Plane 1 rebuild.

### Decision 2: `controlplane-1` Storage Scheduling & `etcd` I/O Isolation
* **Option A (Ideal — Recommended): Isolate `etcd` SSD (`/dev/sda`); Schedule Only on Dedicated HDD (`/var/mnt/longhorn-extra`)**
  * Set `allowScheduling: false` on `controlplane-1`'s OS disk (`/var/lib/longhorn` on `/dev/sda` 256 GB SSD) to guarantee zero Longhorn block I/O contention with `etcd` WAL/fsync operations.
  * Set `allowScheduling: true` on `controlplane-1`'s dedicated 931.5 GB HDD (`/var/mnt/longhorn-extra` on `/dev/sdb`).
  * **Result:** 3 distinct node fault domains (`controlplane-1` 931.5 GB dedicated HDD + `worker-1` ~1.8 TB dual HDDs + `worker-2` 465.8 GB HDD) backing `defaultReplicaCount: 2` volumes, enabling automatic cross-node rebuilds if any single node fails while protecting control plane quorum.
* **Option B (High-Compatibility): Leave All Disks Schedulable (Including `controlplane-1` OS SSD)**
  * Keep `/var/lib/longhorn` schedulable on `controlplane-1` with an elevated `storageReserved` buffer (e.g., 80 GiB). Adds ~170 GB usable capacity at the risk of `etcd` latency spikes during heavy volume rebuilds.

---

## 3. Hardware & Firmware Guardrail Check (Pre-Flight)

Because Feature 4.1 directly binds bare-metal SATA block devices and Talos OS host mounts into Longhorn's storage plane, confirm the following before Phase 1 execution:
1. **Host OS & Extensions:** Confirm all three nodes remain on **Talos `v1.13.7`** / **Kubernetes `v1.36.1`** with `siderolabs/iscsi-tools` and `siderolabs/util-linux-tools` loaded.
2. **Physical SATA Health:** Confirm no drive disconnects, SMART errors, or cabling issues have occurred on `controlplane-1` (`/dev/sdb`), `worker-1` (`/dev/sdc`, `/dev/sdd`), or `worker-2` (`/dev/sdc`) since Feature 3.4-R.

---

## 4. Phased Action Plan (Mapped to DoD)

### Phase 1: Baseline Audit of Talos Mounts & Live Longhorn Node State
* **Maps to DoD #1 (Prerequisite):** *Establish empirical ground truth of mounted host disks and existing `default-disk-<hash>` keys before authoring declarative manifests.*
* **Proposed Changes:** None (read-only audit phase).
* **Validation Block (Phase 1):**

Check ArgoCD `longhorn` application sync/health:
```bash
kubectl get application -n argocd longhorn
```

Check all Longhorn pods across all 3 nodes:
```bash
kubectl get pods -n longhorn-system -o wide
```

Verify Talos `UserVolumeConfig` (`longhorn-extra`) mount status on `controlplane-1` and `worker-1`:
```bash
talosctl get volumestatus --nodes 10.10.10.51,10.10.10.52
```

Inspect live `nodes.longhorn.io` specs to extract exact existing `default-disk-<hash>` keys and current scheduling states:
```bash
kubectl get nodes.longhorn.io -n longhorn-system -o yaml
```

Inspect existing Longhorn volumes and active replica placements (e.g., MinIO PVCs):
```bash
kubectl get volumes.longhorn.io,replicas.longhorn.io -n longhorn-system
```

---

### Phase 2: Declarative Multi-Disk Activation & Helm Values Alignment
* **Maps to DoD #1:** *Longhorn UI shows all disks active.*
* **Proposed Changes (Pending Option A/A Approval):**
  * `[MODIFY]` [argocd/apps/longhorn.yaml](../../argocd/apps/longhorn.yaml)
    * **What it does:** Aligns inline Helm `values` to enforce `defaultSettings.replicaSoftAntiAffinity: false`, `metrics.prometheus.enabled: true`, and `longhornUI.replicas: 1`.
    * **Why it is needed:** Eliminates drift against the legacy `values.yaml`, guarantees strict cross-node replica anti-affinity (two replicas of the same volume can never land on the same node), and readies Prometheus metrics scraping for Epic 5.
  * `[DELETE]` Stale unused files in `infrastructure/storage/longhorn/` (`values.yaml`, `namespace.yaml`) and `[REPLACE]` [infrastructure/storage/longhorn/kustomization.yaml](../../infrastructure/storage/longhorn/kustomization.yaml)
    * **What it does:** Removes dead Feature 3.2 Kustomize-Helm artifacts and converts `infrastructure/storage/longhorn/kustomization.yaml` into a pure Kustomize manifest list referencing the declarative `Node` CRs under `nodes/`.
    * **Why it is needed:** Eliminates configuration drift and enforces the Retrospective 3.2 standard (native Helm in `argocd/apps/longhorn.yaml`, pure Kustomize for supplementary CRs).
  * `[NEW]` `infrastructure/storage/longhorn/nodes/controlplane-1.yaml`, `worker-1.yaml`, `worker-2.yaml`
    * **What it does:** Declares `apiVersion: longhorn.io/v1beta2` `kind: Node` manifests preserving each node's Phase 1 `default-disk-<hash>` key, registering `/var/mnt/longhorn-extra` (`longhorn-extra`, `allowScheduling: true`, byte-accurate `storageReserved`, tags `["hdd", "dedicated"]`) on `controlplane-1` and `worker-1`, and disabling scheduling on `controlplane-1`'s OS/etcd SSD (`/dev/sda`) per Decision 2 Option A.
    * **Why it is needed:** Brings all ~1.86 TB of consolidated secondary SATA storage online declaratively in Git while isolating `etcd` IOPS.
  * `[NEW]` `argocd/apps/longhorn-config.yaml`
    * **What it does:** Registers a dedicated ArgoCD `Application` (`sync-wave: "2"`, `ServerSideApply=true`, `ServerSideDiff=true`, `automated.prune: false`, `selfHeal: true`) tracking `infrastructure/storage/longhorn`.
    * **Why it is needed:** Ensures every manifest under `/infrastructure` is reconciled by ArgoCD under strict GitOps exclusivity while preventing accidental `prune` deletion of live `Node` CRs.
* **Validation Block (Phase 2):**

Verify both `longhorn` and `longhorn-config` ArgoCD applications are `Synced` and `Healthy`:
```bash
kubectl get applications -n argocd longhorn longhorn-config
```

Verify all Longhorn nodes report `ALLOWSCHEDULING=true` and `READY=True`:
```bash
kubectl get nodes.longhorn.io -n longhorn-system
```

Verify every physical disk (including `/var/mnt/longhorn-extra` on `controlplane-1` and `worker-1`) reports `Ready=True` and `Schedulable=True` (with `controlplane-1` OS disk `Schedulable=False` if Option A selected):
```bash
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns='NODE:.metadata.name,DISKS:.status.diskStatus'
```

Open Longhorn UI via port-forward (`http://localhost:8081` per [docs/runbooks/cluster-access.md](../runbooks/cluster-access.md)) and visually confirm the **Node** tab shows all expected disks `Schedulable` and active:
```bash
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80
```

---

### Phase 3: Declarative Cross-Node Volume Replication & Persistence Verification
* **Maps to DoD #2:** *Volume replication verified across nodes.*
* **Proposed Changes:**
  * `[NEW]` `infrastructure/storage/longhorn-validation/` (`kustomization.yaml`, `namespace.yaml`, `pvc.yaml`, `deployment.yaml`)
    * **What it does:** Declares an ephemeral validation namespace (`storage-validation`), a `2Gi` `ReadWriteOnce` `PersistentVolumeClaim` (`longhorn-replication-test`, `storageClassName: longhorn`), and a `1`-replica `Deployment` (`busybox:1.36`) that writes a deterministic checksum file (`/data/replication-verify.txt` via `/bin/sh -eu -c`) and holds the volume mounted.
    * **Why it is needed:** Proves dynamic CSI provisioning, cross-node synchronous 2x replication (`replicaSoftAntiAffinity: false`), and data integrity strictly through GitOps without any imperative `kubectl apply` or `kubectl create`.
  * `[NEW]` `argocd/apps/longhorn-validation.yaml`
    * **What it does:** Registers the temporary validation workload in ArgoCD (`sync-wave: "3"`, `automated.prune: true`, `selfHeal: true`).
    * **Why it is needed:** Enforces strict GitOps exclusivity for test workloads and allows clean declarative teardown in Phase 4.
* **Validation Block (Phase 3):**

Verify `longhorn-validation` ArgoCD application sync and PVC binding:
```bash
kubectl get application -n argocd longhorn-validation
```

Verify the test PVC is `Bound` to a dynamically provisioned `longhorn` PV:
```bash
kubectl get pvc -n storage-validation longhorn-replication-test
```

Verify the Longhorn volume is `healthy` (`robustness: healthy`) with `numberOfReplicas: 2`:
```bash
kubectl get volumes.longhorn.io -n longhorn-system -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness,REPLICAS:.spec.numberOfReplicas,NODE:.status.currentNodeID'
```

Verify the 2 replicas for the test volume are scheduled on **two distinct physical nodes** and both report `running`:
```bash
kubectl get replicas.longhorn.io -n longhorn-system -o custom-columns='NAME:.metadata.name,VOLUME:.spec.volumeName,NODE:.spec.nodeID,STATE:.status.currentState,DISK:.spec.diskPath'
```

Verify checksum persistence inside the mounted volume (read-only):
```bash
kubectl exec -n storage-validation deploy/longhorn-replication-writer -- cat /data/replication-verify.txt
```

---

### Phase 4: Declarative Teardown of Validation Workload & Documentation Re-Baselining
* **Maps to Governance / ABW Closure:** Removes temporary validation resources declaratively and eliminates all Layer 2/3 documentation drift.
* **Proposed Changes:**
  * `[DELETE]` `argocd/apps/longhorn-validation.yaml` and `infrastructure/storage/longhorn-validation/`
    * **What it does:** Removes the temporary replication verification `Application` and manifests from Git so ArgoCD automatically prunes `storage-validation` and releases the test PV/replicas.
    * **Why it is needed:** Keeps the production cluster free of test artifacts via pure GitOps lifecycle management.
  * `[MODIFY]` [docs/architecture/05-distributed-storage.md](../architecture/05-distributed-storage.md) & [infrastructure/storage/README.md](../../infrastructure/storage/README.md)
    * **What it does:** Updates the Mermaid topology diagram, multi-disk `/var/mnt/longhorn-extra` layout, `etcd` SSD isolation posture, `longhorn-config` ArgoCD Application reference, and replaces imperative validation snippets with read-only GitOps validation commands.
    * **Why it is needed:** Ensures Layer 2/3 documentation accurately mirrors the validated Feature 4.1 state.
  * `[MODIFY]` [argocd/apps/README.md](../../argocd/apps/README.md)
    * **What it does:** Adds `longhorn-config.yaml` (Sync Wave `2`) to the active managed applications registry.
    * **Why it is needed:** Keeps the App-of-Apps index authoritative.
  * `[NEW]` `docs/logs/epic-4.md`
    * **What it does:** Initializes the Epic 4 chronological engineering log with Feature 4.1 milestones and empirical validation results.
    * **Why it is needed:** Satisfies chronological log governance established in Feature 0.5.
* **Validation Block (Phase 4):**

Verify `storage-validation` namespace and test PVC have been cleanly pruned by ArgoCD:
```bash
kubectl get ns storage-validation
```

Verify clean git status prior to merging to `Epic-4_Core-Infrastructure-Services` and `argocd-deploy`:
```bash
git status
```

---

## 5. Gate Check (Pre-Execution Approval Required)

Execution is **halted** pending your review and explicit approval of:
1. **Multi-Disk Management Strategy (Decision 1):** Approve **Option A** (Declarative `longhorn.io/v1beta2` `Node` CRs via `argocd/apps/longhorn-config.yaml`) or **Option B** (Interactive Longhorn UI registration).
2. **Control Plane Storage Isolation (Decision 2):** Approve **Option A** (Disable scheduling on `controlplane-1` OS/etcd SSD `/dev/sda`; schedule only on dedicated 931.5 GB HDD `/var/mnt/longhorn-extra`) or **Option B** (Keep all disks schedulable).
3. **Hardware & Firmware Guardrail Confirmation:** Confirm Talos `v1.13.7` / K8s `v1.36.1` baseline and SATA disk health across all three nodes, and confirm readiness to execute **Phase 1** read-only diagnostics.
