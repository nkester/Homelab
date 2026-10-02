# Implementation Plan - Feature 3.2: CNI & Storage Integration

This plan outlines the architecture, declarative manifests, documentation updates, and verification strategy to deploy **Longhorn Distributed Storage** on our 3-node bare-metal Talos Linux cluster (`HP Control Node 10.10.10.51`, `Lenovo Worker 1 10.10.10.52`, `Dell Worker 2 10.10.10.53`) under GitOps management via ArgoCD.

## State Audit & Audit-Before-Write (ABW) Review

The following existing repository files were audited prior to updating this plan:
- [`/docs/HomeLab_Project_Roadmap.csv`](file:///home/neil/Documents/Projects/homelab/docs/HomeLab_Project_Roadmap.csv): Verified active Feature 3.2 under Epic 3.
- [`/docs/Retrospective.csv`](file:///home/neil/Documents/Projects/homelab/docs/Retrospective.csv): Extracted lessons on Zero-Token-in-Git, mandatory CLI validation, ABW checks, and live documentation search.
- [`/docs/hardware_inventory.csv`](file:///home/neil/Documents/Projects/homelab/docs/hardware_inventory.csv): Audited node hardware specs (`HP` 256GB SSD, `Lenovo` 500GB HDD, `Dell` HDD).
- [`/docs/architecture/04-gitops-and-orchestration.md`](file:///home/neil/Documents/Projects/homelab/docs/architecture/04-gitops-and-orchestration.md): Reviewed App-of-Apps GitOps layout.
- [`/argocd/root-app.yaml`](file:///home/neil/Documents/Projects/homelab/argocd/root-app.yaml): Verified ArgoCD root application synchronization path.
- [`/argocd/apps/README.md`](file:///home/neil/Documents/Projects/homelab/argocd/apps/README.md): Audited existing GitOps app documentation for amendments.
- [`/infrastructure/storage/README.md`](file:///home/neil/Documents/Projects/homelab/infrastructure/storage/README.md): Audited storage subsystem documentation for expansion.

---

## User Review & Prerequisites (Resolved)

> [!NOTE]
> **Prerequisites & Requirements Confirmed**
> 1. **Talos OS Extensions**: Confirmed present across all nodes (`10.10.10.51`, `10.10.10.52`, `10.10.10.53`). Both `iscsi-tools` (v0.2.0) and `util-linux-tools` (2.42.2) are active.
> 2. **Storage Disks**: Confirmed targeting default OS partition mount paths (`/var/lib/longhorn`). No additional raw disks or dedicated partitions are attached.
> 3. **Storage Replica Count**: Default volume replica count set to `2` across the cluster worker nodes for fault tolerance.

---

## Roadmap Alignment & Definition of Done (DoD)

| DoD Criterion | Mapping Action |
| :--- | :--- |
| **1. Longhorn nodes report healthy** | Deploy Longhorn system components via ArgoCD and verify all 3 cluster nodes register as healthy in `nodes.longhorn.io`. |
| **2. StorageClass 'longhorn' set as default** | Configure `persistence.defaultClass: true` and `defaultClassReplicaCount: 2` in declarative Helm values, setting `longhorn` as default K8s StorageClass. |

---

## Proposed Changes

### Storage Subsystem (`/infrastructure/storage`)

#### [NEW] [kustomization.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/storage/longhorn/kustomization.yaml)
- **What it does**: Declares the Kustomize bundle for the Longhorn storage namespace and values overlay.
- **Why it is needed**: Establishes a clean, declarative GitOps structure for storage infrastructure components managed by ArgoCD.

#### [NEW] [namespace.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/storage/longhorn/namespace.yaml)
- **What it does**: Creates the `longhorn-system` namespace with required Pod Security Admission (PSA) labels set to `enforce: privileged`.
- **Why it is needed**: Longhorn engine and CSI plugin pods require host-level storage, block device, and network namespace access which is blocked under default restrictive PSA profiles.

#### [NEW] [values.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/storage/longhorn/values.yaml)
- **What it does**: Provides customized Helm values for the Longhorn installation, enabling default StorageClass setting (`persistence.defaultClass: true`), replica count tuning (`defaultClassReplicaCount: 2`), and default node storage path (`/var/lib/longhorn`).
- **Why it is needed**: Customizes the upstream Longhorn chart to align with our 3-node bare-metal architecture and satisfy DoD Criterion 2.

#### [MODIFY] [README.md](file:///home/neil/Documents/Projects/homelab/infrastructure/storage/README.md)
- **What it does**: Expands the storage subsystem documentation to describe the Longhorn component architecture, configuration parameters, directory layout, and references [`05-distributed-storage.md`](file:///home/neil/Documents/Projects/homelab/docs/architecture/05-distributed-storage.md).
- **Why it is needed**: Provides comprehensive documentation for the storage subsystem as required by system engineering and platform governance standards.

---

### GitOps Integration (`/argocd/apps`)

#### [NEW] [longhorn.yaml](file:///home/neil/Documents/Projects/homelab/argocd/apps/longhorn.yaml)
- **What it does**: Defines the ArgoCD `Application` resource targeting `infrastructure/storage/longhorn` (or Longhorn Helm chart) with sync wave 1 annotation (`argocd.argoproj.io/sync-wave: "1"`).
- **Why it is needed**: Integrates Longhorn into the 'App-of-Apps' pattern so ArgoCD automatically deploys, reconciles, and monitors the storage subsystem without manual intervention.

#### [MODIFY] [README.md](file:///home/neil/Documents/Projects/homelab/argocd/apps/README.md)
- **What it does**: Amends the application directory documentation to list `longhorn.yaml` under Sync Wave 1 storage applications.
- **Why it is needed**: Maintains accurate governance documentation for GitOps app discovery and execution ordering.

---

### Architecture & System Documentation (`/docs/architecture`)

#### [NEW] [05-distributed-storage.md](file:///home/neil/Documents/Projects/homelab/docs/architecture/05-distributed-storage.md)
- **What it does**: Documents the Longhorn storage architecture, replication topology, StorageClass parameters, and operational runbooks for volume management on Talos Linux.
- **Why it is needed**: Fulfills the project requirement for complete system documentation as a functional platform manual.

---

## Phased Action Plan & Validation Steps

### Phase 1: Hardware & Talos Extension State Audit (Prerequisites Verification)
- **Actions**:
  1. Audit Talos system extensions across nodes `10.10.10.51`, `10.10.10.52`, and `10.10.10.53` to verify `iscsi-tools` and `util-linux-tools`.
  2. Verify cluster node status in Kubernetes.
- **Validation Block**:
  ```bash
  # Verify Talos OS extensions on all nodes
  talosctl get extensions --nodes 10.10.10.51,10.10.10.52,10.10.10.53
  
  # Verify Kubernetes nodes state
  kubectl get nodes -o wide
  ```

### Phase 2: Storage Infrastructure Declarations & Manifest Creation
- **Actions**:
  1. Create `/infrastructure/storage/longhorn` directory with `namespace.yaml`, `values.yaml`, and `kustomization.yaml`.
  2. Update `/infrastructure/storage/README.md` with component design and architecture references.
  3. Create `/argocd/apps/longhorn.yaml` targeting sync wave 1.
  4. Update `/argocd/apps/README.md` to register `longhorn.yaml`.
- **Validation Block**:
  ```bash
  # Check local file structure
  ls -la infrastructure/storage/longhorn/
  ls -la argocd/apps/longhorn.yaml
  ```

### Phase 3: GitOps Deployment & Sync Verification
- **Actions**:
  1. Commit and push the new storage and GitOps manifests to trigger ArgoCD synchronization.
  2. Monitor ArgoCD reconciliation of the `longhorn` application.
  3. Verify pod status in `longhorn-system` namespace.
- **Validation Block**:
  ```bash
  # Verify ArgoCD Application status
  kubectl get application -n argocd longhorn
  
  # Verify Longhorn control plane and daemonset pod status
  kubectl get pods -n longhorn-system -o wide
  ```

### Phase 4: Definition of Done (DoD) Validation & Storage Test
- **Actions**:
  1. Verify all 3 nodes report healthy in `nodes.longhorn.io`.
  2. Verify `longhorn` is registered as the default `StorageClass`.
  3. Deploy a temporary PVC test workload to prove dynamic volume provisioning and replica binding across worker nodes.
- **Validation Block**:
  ```bash
  # DoD Criterion 1 Validation: Longhorn nodes report healthy
  kubectl get nodes.longhorn.io -n longhorn-system
  
  # DoD Criterion 2 Validation: StorageClass 'longhorn' set as default
  kubectl get storageclass
  
  # Dynamic Provisioning & Binding Test
  kubectl create ns storage-test
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: longhorn-pvc-test
    namespace: storage-test
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
  EOF
  kubectl get pvc -n storage-test longhorn-pvc-test
  kubectl delete ns storage-test
  ```

### Phase 5: Architecture Documentation & Retrospective Ceremony
- **Actions**:
  1. Author `/docs/architecture/05-distributed-storage.md`.
  2. Verify all DoD criteria are satisfied and prompt user for the Retrospective ceremony.
- **Validation Block**:
  ```bash
  # Check git status for clean state
  git status
  ```

## Conclusion / Summary (Gemini Final Walkthrough artifact)

We have completed the declarative configuration, subsystem documentation, GitOps app registration, and system architecture blueprint for **Longhorn Distributed Storage** on our 3-node bare-metal Talos Linux cluster.

### Summary of Completed Changes

#### Storage Subsystem Manifests (`/infrastructure/storage/longhorn`)
- [`namespace.yaml`](/infrastructure/storage/longhorn/namespace.yaml): Provisioned `longhorn-system` namespace with `pod-security.kubernetes.io/enforce: privileged` PSA labels.
- [`values.yaml`](/infrastructure/storage/longhorn/values.yaml): Configured Longhorn Helm overlay with `defaultClass: true`, `defaultClassReplicaCount: 2`, `defaultDataPath: "/var/lib/longhorn"`, and `kubeletRootDir: "/var/lib/kubelet"`.
- [`kustomization.yaml`](/infrastructure/storage/longhorn/kustomization.yaml): Created Kustomize manifest bundle with `helmCharts` generator targeting Longhorn v1.6.2.
- [`README.md`](/infrastructure/storage/README.md): Updated storage subsystem README with architectural design, directory layout, and blueprint references.

#### GitOps Application Registry (`/argocd/apps`)
- [`longhorn.yaml`](/argocd/apps/longhorn.yaml): Created ArgoCD `Application` manifest for Longhorn assigned to Sync Wave `1` under the App-of-Apps controller.
- [`README.md`](/argocd/apps/README.md): Updated application registry documentation to list `longhorn.yaml`.

#### Platform Architecture & System Documentation (`/docs/architecture`)
- [`05-distributed-storage.md`](/docs/architecture/05-distributed-storage.md): Authored complete Layer III storage architecture blueprint, including Mermaid topology diagram, iSCSI host integration specs, failure domain analysis, and dynamic provisioning runbooks.
- [`README.md`](/docs/architecture/README.md): Updated architecture index to register `05-distributed-storage.md` as Complete.

---

### Validation Protocols

Run the following deterministic commands against your cluster to verify the deployment against the **Definition of Done (DoD)**:

#### 1. Prerequisite Verification
```bash
# Verify Talos OS extensions across nodes
talosctl get extensions --nodes 10.10.10.51,10.10.10.52,10.10.10.53
```

#### 2. GitOps Reconciliation Check
```bash
# Verify ArgoCD Application status
kubectl get application -n argocd longhorn

# Verify Longhorn control plane and daemonsets in longhorn-system
kubectl get pods -n longhorn-system -o wide
```

#### 3. Definition of Done (DoD) Criteria Verification

```bash
# DoD Criterion 1: Longhorn nodes report healthy
kubectl get nodes.longhorn.io -n longhorn-system

# DoD Criterion 2: StorageClass 'longhorn' set as default
kubectl get storageclass
```

#### 4. Dynamic Provisioning Test
```bash
kubectl create ns storage-test
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-pvc-test
  namespace: storage-test
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
kubectl get pvc -n storage-test longhorn-pvc-test
kubectl delete ns storage-test
```
