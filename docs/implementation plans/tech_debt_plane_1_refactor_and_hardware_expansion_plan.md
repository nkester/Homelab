# Tech Debt Resolution: Plane 1 State Management & Bare-Metal Hardware Expansion

## Executive Summary

This work plan establishes the formal strategy for pausing **Feature 3.5 (Serverless Execution - Knative)** to resolve foundational architectural technical debt at **Plane 1 (Host OS & OpenTofu Bootstrap Layer)**. 

### Core Drivers:
1. **State Persistence Debt:** OpenTofu currently lacks a persistent, versioned, and locked remote state backend, having previously relied on ephemeral local `.tfstate` files excluded from Git. Managing Day 2 cluster changes without remote state risks catastrophic disruption to live physical nodes.
2. **Monolithic Code Coupling:** [infrastructure/bootstrap/main.tf](/infrastructure/bootstrap/main.tf) conflates one-time Day 0 Genesis operations (`talos_machine_bootstrap`, `time_sleep.wait_for_reboot`) with ongoing node lifecycle management and CNI bootstrapping.
3. **Hardware Constraints:** The existing cluster operates with a severely resource-constrained Dell laptop (`worker-2`, battery-backed laptop with unverified storage health) and a Lenovo desktop (`worker-1`, constrained to ~3.7GB usable RAM). Two newly acquired physical computers must be evaluated, integrated, and used to decommission suboptimal hardware.
4. **Layer 2 LoadBalancer Convergence:** Cilium's Helm configuration in Plane 1 currently lacks `l2announcements.enabled: true`, preventing LoadBalancer virtual IPs (such as Knative Kourier on `10.10.10.18` and NGINX Ingress on `10.10.10.17`) from answering ARP queries on the physical subnet.

---

## Roadmap Alignment & Sprint State

* **Interrupted Feature:** Feature 3.5 (Serverless Execution - Knative) → `Paused`
* **Active Sprint:** Tech Debt Resolution (Plane 1 State & Hardware Topology Refactor)
* **Target Outcome:** Deterministic, repeatable bare-metal cluster rebuild capability via GitLab-Managed OpenTofu State, expansion to high-capacity compute nodes, retirement of legacy laptop hardware, automated GitOps workload recovery via ArgoCD, and clean resumption of Feature 3.5.

---

## Phased Implementation Plan

```
┌────────────────────────────────────────────────────────────────────────┐
│                   TECH DEBT RESOLUTION WORKFLOW                        │
├────────────────────────────────────────────────────────────────────────┤
│  PHASE 1: Hardware Evaluation & Target Topology Architecture           │
│  ├── Audit 2 new computers (CPU, RAM, Disks, NICs, MACs)               │
│  ├── Architecture decision: Decommission laptop (Dell Inspiron 15R)    │
│  └── Update inventory, IPAM (VLAN 10), and ADR                         │
├────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: Decoupled OpenTofu Module Architecture                       │
│  ├── Extract Genesis (PKI/Bootstrap) from Node Lifecycle               │
│  ├── Decouple Node Provisioning via declarative map                    │
│  └── Configure Cilium Helm with L2 Announcements + Rate Limiting       │
├────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: GitLab-Managed Terraform State Implementation                │
│  ├── Configure native OpenTofu HTTP state backend in GitLab            │
│  └── Verify remote locking, encryption-at-rest, and versioning         │
├────────────────────────────────────────────────────────────────────────┤
│  PHASE 4: Bare-Metal Cluster Rebuild & Disaster Recovery Runbook       │
│  ├── Drain and reset legacy nodes (talosctl reset)                     │
│  ├── Physically commission new hardware into VLAN 10 switch            │
│  ├── Execute clean-room `tofu apply` against GitLab backend            │
│  └── Validate Talos quorum, VIP (10.10.10.10), and Cilium eBPF datapath│
├────────────────────────────────────────────────────────────────────────┤
│  PHASE 5: GitOps Workload Restoration (ArgoCD App-of-Apps)             │
│  ├── Bootstrap ArgoCD and apply root-app.yaml                          │
│  └── Reconcile Waves -1 through 2 (Storage, Ingress, Operators)        │
├────────────────────────────────────────────────────────────────────────┤
│  PHASE 6: Feature 3.5 Resumption & Cold Start Ingress Validation       │
│  ├── Reconcile Knative Service (helloworld-go.default.kester.lab)      │
│  ├── Verify Cilium L2 ARP resolution on 10.10.10.18                    │
│  └── Execute curl cold-start and verify scale-to-zero (0 -> 1 -> 0)    │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Phase 1: Hardware Evaluation & Target Topology Architecture

**Objective:** Audit physical capabilities of the two new systems, define the permanent cluster topology, reallocate IP addresses, and formalize hardware retirement.

#### Work Items:
1. **Physical Audit:**
   * Power on both new machines and inspect BIOS/UEFI settings:
     * Enable Intel VT-x / AMD-V (Hardware Virtualization).
     * Set UEFI Boot Mode (disable Legacy CSM).
     * Configure AC Power Recovery to "Power On" (auto-reboot on power restoration).
   * Record hardware specifications:
     * CPU: Model, core/thread count, instruction set.
     * RAM: Total capacity, memory generation (DDR3/DDR4), speed.
     * Storage: Disk controllers, storage media (SATA SSD, NVMe, HDD), bus layout, drive capacity.
     * Network: NIC model (Intel, Realtek), Gigabit capability, MAC addresses.
2. **Topology Decision:**
   * Baseline the new node count: Evaluate whether to run 1 Control Plane + 3 Workers or 1 Control Plane + 4 Workers.
   * Formalize decommissioning: Designate the Dell Inspiron 15R laptop (`10.10.10.53`) for immediate retirement to remove laptop battery/thermal failure domains.
   * Re-evaluate Lenovo desktop (`10.10.10.52`, 4GB RAM) as either a dedicated lightweight worker or secondary retirement candidate based on new machine specs.
3. **Documentation Updates:**
   * Update [docs/hardware_inventory.csv](/docs/hardware_inventory.csv) with full serials, MACs, and hardware roles.
   * Update [infrastructure/networking/README.md](/infrastructure/networking/README.md) with updated static IP assignments on VLAN 10 (`10.10.10.51 - 10.10.10.55`).
   * Author Architectural Decision Record: `docs/adr/0010-hardware-refresh-and-plane-1-state-architecture.md`.

#### Definition of Done (Phase 1):
* [ ] Both new machines fully inventoried in `hardware_inventory.csv`.
* [ ] IP and MAC table committed in `infrastructure/networking/README.md`.
* [ ] ADR-0010 accepted and committed documenting the hardware transition.

---

### Phase 2: Decoupled OpenTofu Module Architecture

**Objective:** Restructure [infrastructure/bootstrap/main.tf](/infrastructure/bootstrap/main.tf) from an imperative, coupled script into composable, modular Infrastructure as Code.

#### Work Items:
1. **Module Decomposition:**
   * `modules/pki/`: Generates and manages `talos_machine_secrets` and cluster certificates.
   * `modules/controlplane/`: Manages Control Plane machine configuration patches (binding to `eno1`, Layer 2 VIP `10.10.10.10`, disk installation targets).
   * `modules/genesis/`: Houses the one-time `talos_machine_bootstrap` resource and initial kubeconfig extraction, protected by lifecycle guards.
   * `modules/workers/`: Parameterized module accepting a `map(object)` of worker nodes:
     ```hcl
     variable "worker_nodes" {
       type = map(object({
         ip        = string
         interface = string
         disk      = string
         hostname  = string
       }))
     }
     ```
     Uses `for_each` over `talos_machine_configuration_apply` to permit adding or replacing nodes without altering root code.
   * `modules/cni/`: Manages `helm_release "cilium"` with explicit values:
     * `kubeProxyReplacement: true`
     * `l2announcements.enabled: true`
     * `k8sClientRateLimit: { qps: 50, burst: 100 }`
     * `routingMode: native`
     * `autoDirectNodeRoutes: true`
2. **Talos Extensions Validation:**
   * Build hardware-specific Talos installer image URLs via Sidero Factory matching the NIC chipsets (e.g., `realtek-firmware`, `intel-ucode`) and Longhorn storage prerequisites (`iscsi-tools`, `util-linux-tools`).
3. **Code Quality & Validation:**
   * Format and validate: `tofu fmt -recursive` and `tofu validate`.

#### Definition of Done (Phase 2):
* [ ] OpenTofu codebase decoupled into distinct modules (`pki`, `controlplane`, `genesis`, `workers`, `cni`).
* [ ] Worker node provisioning driven dynamically by a single map variable.
* [ ] Cilium Helm values explicitly declare `l2announcements.enabled: true` and rate limits.
* [ ] `tofu validate` passes with zero errors.

---

### Phase 3: GitLab-Managed Terraform State Implementation

**Objective:** Migrate OpenTofu state permanently to GitLab's encrypted, locked HTTP state backend.

#### Work Items:
1. **GitLab Project Access Token:**
   * Generate a dedicated Project Access Token in the GitLab repository UI (`https://gitlab.com/nkester-personal-cloud/homelab`) named `opentofu-bootstrap-token` with `api` scope.
2. **Backend Configuration:**
   * Declare the `backend "http" {}` block in `infrastructure/bootstrap/main.tf`.
   * Author an initialization script [infrastructure/bootstrap/init-state.sh](/infrastructure/bootstrap/init-state.sh):
     ```bash
     #!/usr/bin/env bash
     set -euo pipefail
     
     PROJECT_ID="<GITLAB_PROJECT_ID>"
     STATE_NAME="homelab-bootstrap"
     
     tofu init \
       -backend-config="address=https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE_NAME}" \
       -backend-config="lock_address=https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE_NAME}/lock" \
       -backend-config="unlock_address=https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/${STATE_NAME}/lock" \
       -backend-config="username=${GITLAB_USER}" \
       -backend-config="password=${GITLAB_TOKEN}" \
       -backend-config="lock_method=POST" \
       -backend-config="unlock_method=DELETE" \
       -backend-config="retry_wait_min=5"
     ```
   * Set execution permissions: `chmod +x infrastructure/bootstrap/init-state.sh`.
   * Add `.env.example` documenting required environment variables (`GITLAB_USER`, `GITLAB_TOKEN`, `GITLAB_PROJECT_ID`).
3. **Verification:**
   * Execute `init-state.sh` and verify state file registration in **GitLab UI → Operate → Terraform states**.

#### Definition of Done (Phase 3):
* [ ] `init-state.sh` written, tested, and committed.
* [ ] OpenTofu successfully initializes against the GitLab HTTP backend.
* [ ] GitLab UI confirms presence of `homelab-bootstrap` state registry with automated lock/unlock functionality.

---

### Phase 4: Bare-Metal Cluster Rebuild & Disaster Recovery Runbook

**Objective:** Execute the clean-room cluster rebuild, physically retire legacy hardware, commission new nodes, and establish the healthy Talos + Cilium base.

#### Work Items:
1. **Pre-Rebuild Backups & Teardown:**
   * Confirm all Git commits are pushed to GitLab across active branches (`argocd-deploy`, `main`).
   * Issue node reset commands to existing nodes to clear partition tables:
     ```bash
     talosctl reset --nodes 10.10.10.51,10.10.10.52,10.10.10.53 --graceful=false --reboot
     ```
   * Physically disconnect and decommission the Dell Inspiron 15R laptop.
2. **Hardware Cabling & Maintenance Mode:**
   * Connect new physical nodes to the TL-SG108E switch on VLAN 10 untagged ports.
   * Boot HP Control Plane and all worker nodes via Talos v1.13.7 installer media into Maintenance Mode.
   * Query node links to verify interface enumeration and IP acquisition via DHCP:
     ```bash
     talosctl get links --nodes <Node_IP> --insecure
     ```
3. **OpenTofu Clean Apply:**
   * From `infrastructure/bootstrap/`, execute:
     ```bash
     tofu plan -out=tfplan
     tofu apply tfplan
     ```
   * OpenTofu applies machine configs, triggers control plane reboot, executes one-time bootstrap, and provisions Cilium CNI.
4. **Base Platform Verification:**
   * Extract fresh client configurations:
     ```bash
     tofu output -raw talosconfig > ~/.talos/config
     chmod 600 ~/.talos/config
     talosctl --nodes 10.10.10.51 kubeconfig ~/.kube/config
     chmod 600 ~/.kube/config
     ```
   * Validate Talos health and quorum:
     ```bash
     talosctl health --nodes 10.10.10.51
     talosctl get members
     ```
   * Validate Kubernetes nodes and VIP:
     ```bash
     kubectl get nodes -o wide
     ping -c 2 10.10.10.10
     ```

#### Definition of Done (Phase 4):
* [ ] Dell laptop decommissioned; new compute nodes active.
* [ ] OpenTofu clean `apply` completes with zero errors against the GitLab backend.
* [ ] All nodes report `Ready` in Kubernetes with correct hostnames, IPs, and Talos v1.13.7.
* [ ] Control plane VIP `10.10.10.10` reachable.
* [ ] Cilium pods running healthy across all nodes in `kube-system`.

---

### Phase 5: GitOps Workload Restoration (ArgoCD Cascading Sync)

**Objective:** Bootstrap ArgoCD and allow the App-of-Apps tree to automatically restore all cluster services and data plane operators.

#### Work Items:
1. **Bootstrap ArgoCD:**
   * Install foundational ArgoCD manifests into namespace `argocd`:
     ```bash
     kubectl create namespace argocd
     kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.0/manifests/install.yaml
     ```
2. **Deploy App-of-Apps Root Controller:**
   * Apply [argocd/root-app.yaml](/argocd/root-app.yaml) targeting `argocd-deploy` branch:
     ```bash
     kubectl apply -f argocd/root-app.yaml
     ```
3. **Monitor Automated Sync Waves:**
   * **Wave -1:** `system-config` reconciles CiliumIdentity exclusion rules.
   * **Wave 0:** `cilium-lb-ipam` provisions `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy`; `argo-workflows`, `gitlab-runner`, and `external-secrets-operator` come online.
   * **Wave 1:** `external-secrets-config` connects ClusterSecretStores; `longhorn` discovers and formats storage disks on the new compute nodes; `ingress-nginx` binds to `10.10.10.17`; `knative-operator` and `minio-operator` deploy CRDs.
   * **Wave 2:** `minio-tenant` initializes S3 storage pools on Longhorn; `knative-serving` installs serving control plane and Kourier gateway.
4. **Health Parity Verification:**
   * Query ArgoCD applications:
     ```bash
     kubectl get applications -n argocd
     ```
   * Ensure 100% parity with pre-rebuild state (all apps `Synced` and `Healthy`).

#### Definition of Done (Phase 5):
* [ ] ArgoCD managing all cluster applications via GitOps.
* [ ] Longhorn storage operational across the new node topology.
* [ ] External Secrets Operator successfully hydrating credentials from GitLab CI variables.
* [ ] NGINX Ingress and MinIO Tenant fully restored.
* [ ] Zero degraded or out-of-sync applications in ArgoCD.

---

### Phase 6: Resume & Complete Feature 3.5 (Serverless Execution - Knative)

**Objective:** Complete the final acceptance criteria of Feature 3.5 on the hardened, upgraded infrastructure.

#### Work Items:
1. **Resume Feature 3.5 in Roadmap:**
   * Transition Feature 3.5 status from `Paused` back to `In Progress`.
2. **Knative Ingress & Domain Verification:**
   * Verify [infrastructure/serverless/knative/serving/knative-serving-cr.yaml](/infrastructure/serverless/knative/serving/knative-serving-cr.yaml) reconciles `kester.lab` as the cluster domain.
   * Verify Service `kourier` receives dedicated LoadBalancer IP `10.10.10.18`.
3. **L2 ARP Resolution Verification:**
   * Because Cilium was deployed with `l2announcements.enabled: true`, verify Cilium L2 leases:
     ```bash
     kubectl get leases -n kube-system -l "cilium.io/l2-announcements=true"
     ```
   * Verify ARP cache on workstation:
     ```bash
     ip neigh flush 10.10.10.18 dev enp4s0
     ping -c 2 10.10.10.18
     ip neigh show 10.10.10.18 dev enp4s0
     ```
     *(Must show `REACHABLE` with physical node MAC address)*
4. **Deploy Test Knative Service & Validate Scale-to-Zero:**
   * Ensure `helloworld-go` is synced via ArgoCD in namespace `default`.
   * Verify 0 pods initially running:
     ```bash
     kubectl get pods -n default -l serving.knative.dev/service=helloworld-go
     ```
   * Execute cold-start curl via canonical VIP:
     ```bash
     curl -i -H "Host: helloworld-go.default.kester.lab" http://10.10.10.18
     ```
     *(Expected: HTTP 200 `Hello ORSA Homelab!`)*
   * Verify dynamic autoscaling: 1 pod spins up, handles request, and scales back to 0 after 15-second grace period.
5. **Feature Closure & Retrospective:**
   * Reconcile [docs/HomeLab_Project_Roadmap.csv](/docs/HomeLab_Project_Roadmap.csv) marking Feature 3.5 `Done`.
   * Execute agile retrospective ceremony per `.agents/workflows/retrospective.md`.

#### Definition of Done (Phase 6):
* [ ] Knative Serving operational with official `kester.lab` domain.
* [ ] Kourier gateway reachable via LoadBalancer VIP `10.10.10.18` via Cilium L2 ARP.
* [ ] Cold start and scale-to-zero empirically validated.
* [ ] Feature 3.5 marked `Done` in Roadmap and retrospective logged.

---

## Disaster Recovery & Failure Modes Matrix

| Failure Mode | Root Cause | Remediation Protocol |
| :--- | :--- | :--- |
| **Talos boot drive re-enumeration** | Linux kernel re-orders block devices on boot (e.g., `/dev/sdc` becomes `/dev/sda`). | Boot into Maintenance Mode, query `talosctl get links`, update `disk = "/dev/sdX"` in worker config map, and re-apply via OpenTofu. |
| **GitLab State Lock Hang** | Process terminated mid-apply leaving lock ID active in GitLab. | Execute `tofu force-unlock <LOCK_ID>` using Project Access Token credentials. |
| **Longhorn disk attachment failure** | New node storage drives have legacy partition signatures. | Boot node via Talos maintenance mode and issue disk wipe command: `talosctl reset --nodes <IP> --system-labels-to-wipe STATE,EPHEMERAL`. |
| **ArgoCD Sync Wave race condition** | CRD schema not fully established when custom resource applies. | Ensure explicit sync-wave annotations: Operator at Wave `1`, Custom Resource at Wave `2`. |

---

## Branching & Change Governance

* **Work Plan Branch:** `tech-debt-plane-1-state-and-hardware-refactor`
* **Feature 3.5 Branch (Frozen):** `31-feature-3-5-serverless-execution-knaitive`
* **Deployment Target:** `argocd-deploy`
* **Audit Trail:** All phases require explicit git commits, PR/MR reviews against `main`, and synchronization with the Project Roadmap CSV before execution.
