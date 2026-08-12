# Infrastructure Bootstrap Layer (`/infrastructure/bootstrap`)

## Talos OS Bootstrap Requirements

### Architecture & State Management
This module utilizes OpenTofu to generate deterministic cryptographic material, machine secrets, and YAML configuration patches for the immutable Talos Linux nodes. 
* **Provider:** `siderolabs/talos` locked to `v0.12.0-alpha.5`.
* **State:** Local `terraform.tfstate`.  
* **CRITICAL:** State files contain plaintext cryptographic root-of-trust material and are strictly excluded from version control via `.gitignore`.

### Hardware Configuration Exceptions
Talos implicit network configurations are overridden via `config_patches` to ensure high-availability routing and stable DHCP leases.
* **Control Node (HP Compaq Pro 6300 SFF):** The Intel 82579LM Gigabit Network Connection requires explicit binding to `eno1`. The Layer 2 VIP (`10.10.10.10`) is attached to this interface. 
* **Explicit TALOS Linux Version:** Through the `config_patches` block, we explicitly tell TALOS where to install the OS and which version to use. This was important because without this, the Open Tofu `siderolabs/talos` provider defaulted to installing the latest alpha version of the OS. This caused networking issues so we opted to use the latest stable deployment. The required manifest items are:
   ```yaml
   install = {
          disk = "/dev/sda"
          image = "ghcr.io/siderolabs/installer:v1.13.7"
        }
   ```
* **Establishing Kube-VIP:** To attach the Layer 2 VIP to the control plane's network interface, we added the `vip = {ip = "10.10.10.10"}` within the network portion of the `config_patches` block.  
  * See ADR-0003 for more information on this decision to use the Talos native layer 2 VIP.

### Execution SOP
To provision a node or rebuild the cluster from a bare-metal state:

1. **Initialize Workspace:**
   `tofu init`
2. **Apply Configuration State:**
   `tofu apply`
3. **Extract Talos Client Configuration:**
   `tofu output -raw talosconfig > ~/.talos/config`
   `chmod 600 ~/.talos/config`
   `export TALOSCONFIG=~/.talos/config`
4. **Extract Kubernetes Credentials (Post-Bootstrap):**
   `talosctl --nodes 10.10.10.51 kubeconfig ~/.kube/config`
   `chmod 600 ~/.kube/config`
5. **Check Nodes on the Cluster:**
   `kubectl get nodes -o wide`


## Known Limitations & Operational Guardrails

### 1. Bare-Metal Reprovisioning and Disk Mappings
Executing a node reset (`talosctl reset`) clears the `STATE` and `EPHEMERAL` partitions. However, rebooting physical bare-metal nodes (specifically the Lenovo and Dell worker nodes) can result in the kernel re-enumerating the block storage devices (e.g., shifting the primary installation drive from `/dev/sdc` to `/dev/sdb`). 

If the drive mapping shifts during a remote reset, the node will fail to initialize the Talos OS correctly and will not enter Maintenance Mode over the network. 
*   **Resolution:** This requires a physical failover. You must attach a monitor, insert the Talos bootable USB, and manually boot the machine back into Maintenance Mode, query the node with `talosctl get links --nodes <Node IP> --insecure`, update the `main.tf` manifest with the new mount, and apply to allow OpenTofu to push the configuration to the newly enumerated block device.

---

## Platform Architecture: Full Stack Layering

This bootstrap layer sits at **Plane 1** — the lowest abstraction in the platform. Understanding the full 4-tier stack and its two independent state planes is essential to knowing the correct tool for each class of change.

### 4-Tier Platform Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  TIER 4: Workloads                                              │
│  ArgoCD → Argo Workflows, RStudio, VSCode, CloudNativePG        │
│  ── Kubernetes manages pod lifecycle, scaling, reconciliation ── │
├─────────────────────────────────────────────────────────────────┤
│  TIER 3: System Services & Enclave Agents                       │
│  ArgoCD → Cilium (CNI), Longhorn (CSI), GitLab Runner           │
│  ── Kubernetes manages CNI, CSI, Ingress & runner pod state ─── │
├─────────────────────────────────────────────────────────────────┤
│  TIER 2: Kubernetes Control Plane                               │
│  kube-apiserver, etcd, kubelet, kube-proxy                      │
│  ── Running as a native construct WITHIN Talos OS ────────────  │
├─────────────────────────────────────────────────────────────────┤
│  TIER 1: Host OS & Physical Layer  ◄── THIS DIRECTORY           │
│  Talos Linux + OpenTofu (siderolabs/talos provider)             │
│  ── ArgoCD CANNOT see or manage this layer ────────────────── │
│  ── OpenTofu + talosctl are the ONLY state managers here ─────  │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Two Planes of State Management

The platform enforces a strict boundary between two **independent state planes**. Understanding this boundary defines the correct tool for each class of change and prevents operational conflation.

### Plane 1: OS & Infrastructure Layer (THIS LAYER — OpenTofu + Talos OS)

**Managed by:** OpenTofu (`siderolabs/talos` provider) + `talosctl`  
**Scope:** Physical nodes, Talos OS lifecycle, Kubernetes control plane bootstrap, machine configuration.

**Key properties:**
* **ArgoCD cannot see or manage this layer.** ArgoCD speaks exclusively to the Kubernetes API (`kube-apiserver`). It has zero visibility below that — no access to the host OS, kernel, disk, NIC firmware, or systemd units.
* **Talos is immutable.** It exposes no SSH surface. All configuration is applied exclusively via the Talos Machine API (`talosctl`), driven by OpenTofu declarative state.
* **`terraform.tfstate`** is the source of truth for what was applied to each physical node. It tracks node versions, machine configurations, and bootstrap state.

**OS Lifecycle Management — Current vs. Mature GitOps Approach:**  
In the future, we will work to adopt the Mature GitOps Approach.

| Scenario | Current Approach | Mature GitOps Approach |
| :--- | :--- | :--- |
| Initial node provisioning | Manual `tofu apply` from terminal | GitLab CI pipeline: `tofu apply` on merge to `main` |
| Talos OS version upgrade | Update image tag in `main.tf` → `tofu apply` | GitLab CI pipeline: PR review of `tofu plan`, auto-apply on approval |
| Kubernetes version bump | Update K8s version field → `tofu apply` | GitLab CI: version field change triggers plan diff as MR artifact |
| Add a new worker node | Add new resource block → `tofu apply` | PR into `main` triggers CI with `tofu plan` output for review |

> [!NOTE]
> Running `tofu apply` directly from the terminal is correct and GitOps-compliant as long as `main.tf` is committed to Git before applying. Pipeline automation of `tofu apply` is a future maturity objective.

---

### Plane 2: Kubernetes Application Layer (ArgoCD + Argo Workflows)

**Managed by:** ArgoCD (via GitOps sync from the active branch)  
**Scope:** Everything the `kube-apiserver` manages — workloads, services, networking policies, storage claims, RBAC, and operators.

**Key properties:**
* ArgoCD reconciles K8s manifests committed to Git against live cluster state.
* Argo Workflows executes ephemeral compute DAGs (data processing, ML pipelines, ETL) as a K8s-native workload engine.
* Neither tool can modify the host OS, kernel modules, or Talos machine configuration.

---

### The Intersection: GitLab CI as the Cross-Plane Orchestrator

GitLab CI is the **only tool in the stack that can coordinate operations across both planes** in a single automated pipeline:

```
Git commit pushed to GitLab
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  GitLab CI Pipeline                                             │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Plane 1 Job: tofu plan / tofu apply                       │ │
│  │  → Targets Talos Machine API                               │ │
│  │  → Manages Node OS version, K8s bootstrap, MachineConfig  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Plane 2 Job: Commit updated manifests to argocd-deploy    │ │
│  │  → ArgoCD detects commit, reconciles cluster workload state │ │
│  │  → Argo Workflows API triggered for compute DAG execution  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

### State Verification Commands Per Plane

```bash
# Plane 1: Verify OS and node state (Talos)
talosctl health --nodes 10.10.10.51,10.10.10.52,10.10.10.53
talosctl get members

# Plane 1: Verify OpenTofu drift (IaC)
tofu plan   # Reports any delta between main.tf and live Talos API state

# Plane 2: Verify ArgoCD sync state (Kubernetes)
kubectl get application -n argocd

# Plane 2: Verify Argo Workflows controller health
kubectl get pods -n argo-workflows
```
