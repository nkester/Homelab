# Feature 3.4-R: Plane 1 State & Hardware Consolidation Refactor - Engineering Log

## Overview
* **Roadmap Position:** Situated in **Epic 3 (GitOps & Analytic Stack)** immediately following Feature 3.4 (Object Storage Foundation) and prior to resuming Feature 3.5 (Serverless Execution), while refactoring **Plane 1 (Epic 2: Kubernetes Bootstrap & Bare-Metal Hardware Layer)**.
* **Classification:** Infrastructure Refactoring & Hardware Consolidation (`Feature 3.4-R`).
* **Drivers:**
  1. **Talos PKI State Loss:** Reliance on unversioned local `terraform.tfstate` files resulted in the loss of `talos_machine_secrets`, severing administrative access to the Talos API (`:50000`).
  2. **Compute & Network Bottlenecks:** The initial worker pool relied on a 4GB RAM `Lenovo ideacenter 310S` (`worker-1`, which suffered memory starvation during Feature 3.4 MinIO deployment) and a `Dell Inspiron 15R-5537` laptop (`worker-2`, bottlenecked by a 10/100 Mbps Fast Ethernet `RTL810xE` NIC, a 5400 RPM 2.5" HDD, and consumer laptop thermal/battery failure domains).
  3. **Acquisition of Two Desktop Systems:** Two additional HP Pavilion desktop computers (`HP Pavilion 590-p0xxx` and `HP Pavilion 570-a1xx`) were acquired, enabling physical component consolidation (RAM and SATA storage) into an all-desktop, all-Gigabit 3-node cluster.

---

## Phase 1: Hardware Audit, Component Consolidation & Role Re-Alignment (Completed)

### 1. Physical Hardware Audit & Component Harvesting
Five candidate machines were inspected and benchmarked. Rather than running low-memory or 100 Mbps nodes, components from the **`HP Pavilion 570-a1xx`** and **`Dell Inspiron 15R-5537` laptop** were harvested to maximize per-node memory and storage density across the three primary desktop chassis:

* **Donor 1 (`HP Pavilion Desktop 570-a1xx` — Retired):**
  * Harvested `1x 4GB DDR4-2400 UDIMM` and `1x 1TB 3.5" 7200 RPM SATA HDD` (`WDC WD10EZEX-60W`, S/N: `WD-WCC6Y1PYNSEJ`) along with its 7-pin SATA data cable.
* **Donor 2 (`Dell Inspiron 15R-5537 Laptop` — Retired):**
  * Harvested `2x 8GB Samsung 2Rx8 PC3L-12800S-11-12-F3` (`DDR3L-1600` 204-pin SODIMM) modules and `1x 931.5GB 2.5" SATA HDD` (`ST1000LM024`).

### 2. Consolidated 3-Node Cluster Topology
| Node Hostname | Role | Static IP / VIP | Hardware Chassis | CPU | Consolidated RAM | Consolidated Storage | Wired NIC & MAC |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`controlplane-1`** | Control Plane | `10.10.10.51`<br>(VIP: `10.10.10.10`) | **HP Compaq Pro 6300 SFF** | Intel `i7-3770` @ 3.4GHz (4C/8T) | **20 GB DDR3** (`2x 8GiB + 2x 2GiB`) | • `/dev/sda`: **256 GB SATA SSD** (OS & `etcd`)<br>• `/dev/sdb`: **931.5 GB 2.5" HDD** (`ST1000LM024` from Dell 15R, mounted PCB-up in lower ODD bay via optical SATA/power) | Intel `82579LM` (`eno1`, `e1000e`)<br>`a0:48:1c:98:4e:e3` |
| **`worker-1`** | Worker Node 01 | `10.10.10.52` | **HP Pavilion Desktop 590-p0xxx** | Intel `i5-8400` @ 2.8GHz (6C/6T) | **12 GB DDR4** (`8GB + 4GB` from HP 570; `11Gi` usable) | • `/dev/sdc`: **931.5 GB 3.5" HDD** (`ST1000DM003-1SB1`, S/N: `ZN10H6ZF`)<br>• `/dev/sdd`: **931.5 GB 3.5" HDD** (`WDC WD10EZEX-60W`, S/N: `WD-WCC6Y1PYNSEJ` from HP 570) | Realtek `RTL8111/8168` (`enp2s0`, `r8169`)<br>`f4:39:09:33:dc:f9` |
| **`worker-2`** | Worker Node 02 | `10.10.10.53` | **Lenovo ideacenter 310S-08IAP** | Intel `Celeron J3355` (2C/2T) | **8 GB DDR3L** (`1x 8GB PC3L-12800S` from Dell 15R) | • `/dev/sdb`: **465.8 GB 3.5" 7200 RPM HDD** (`ST500DM002-1SB10` retained for 7200 RPM I/O over 5400 RPM laptop drive) | Realtek `RTL8111/8168` (`enp2s0`, `r8169`)<br>`6c:4b:90:45:42:16` |

### 3. Architectural Gains
1. **Cluster Memory Expansion (`40 GB Total RAM`):** Worker memory increased from `~8 GB` to **`20 GB` dedicated worker RAM** (`12 GB` on `worker-1` + `8 GB` on `worker-2`), plus `20 GB` on `controlplane-1`, permanently resolving the Feature 3.4 memory tech debt ([docs/Retrospective.csv](../Retrospective.csv)).
2. **Full Gigabit Datapath (`1000BASE-T`):** Eliminating the Dell Inspiron 15R (`RTL810xE` 100 Mbps Fast Ethernet) removes the 12.5 MB/s network ceiling on synchronous Longhorn block replication.
3. **Storage Density (`~3.65 TB Across 5 Drives`):** Retains the `256 GB SSD` on `controlplane-1` to protect `etcd` `wal_fsync` latency while adding `~3.4 TB` of rotational SATA capacity across the three nodes.
4. **Sidero Image Schematic Parity:** Because both `worker-1` (`HP 590`) and `worker-2` (`Lenovo 310S`) utilize the `r8169` Realtek Gigabit NIC driver, both worker nodes share the existing Talos `v1.13.7` worker image schematic (`71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09`).

---

## Phase 2: Network DHCP Reservations, GitLab OpenTofu State Backend & Modular IaC Setup (Completed)

### 1. Router DHCP Address Reservations & Pool Segmentation (`TP-Link Omada ER605`)
* Updated VLAN 10 (`10.10.10.0/24`) DHCP Address Reservations on the `ER605` gateway (`10.10.10.1`):
  * `10.10.10.51` → `A0-48-1C-98-4E-E3` (`controlplane-1` — `HP Compaq Pro 6300 SFF`)
  * `10.10.10.52` → `28-3A-4D-07-EE-65` (`worker-1` — `HP Pavilion 590-p0xxx`)
  * `10.10.10.53` → `6C-4B-90-45-42-16` (`worker-2` — `Lenovo ideacenter 310S-08IAP`)
* Restricted the dynamic VLAN 10 DHCP allocation pool to `10.10.10.30 – 10.10.10.99`, guaranteeing zero overlap with the Talos Layer 2 Control Plane VIP (`10.10.10.10`), switch management (`10.10.10.5`), and Cilium LoadBalancer IPAM pool (`10.10.10.17 – 10.10.10.25`).

### 2. GitLab-Managed HTTP OpenTofu State Backend (`homelab-bootstrap`)
* Created a GitLab Fine-Grained Personal Access Token scoped to `Terraform state` (`Read and write` + lock/unlock) on `nkester-personal-cloud/homelab`.
* Implemented `infrastructure/bootstrap/init-state.sh` (`set -euo pipefail`) and `infrastructure/bootstrap/.env.example`, keeping `.env` strictly git-ignored (`.gitignore`) to enforce the Zero-Token-in-Git security posture.
* Initialized OpenTofu against `https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/terraform/state/homelab-bootstrap` with distributed HTTP state locking (`POST /lock`, `DELETE /lock`).

### 3. Modular OpenTofu Configuration (`main.tf`, `variables.tf`, `terraform.tfvars`)
* Parameterized `control_plane` and `worker_nodes` (`for_each = var.worker_nodes`) so each node can be staged and provisioned individually at the primary workstation (`worker_nodes = {}` initially, followed by `worker-1` and `worker-2`).
* Configured `allowSchedulingOnControlPlanes = true` and multi-document Talos `v1alpha1` `UserVolumeConfig` (`longhorn-extra` at `/var/mnt/longhorn-extra`) for secondary SATA HDDs.
* Implemented a two-stage Talos health gate surrounding `helm_release.cilium`:
  * **Stage 1 (`pre_cni`, `skip_kubernetes_checks = true`):** Verifies low-level Talos OS daemons (`etcd`, `kubelet`, `machined`) and the API server (`:6443`) are online before Helm installs Cilium.
  * **Stage 2 (`post_cni`, `skip_kubernetes_checks = false`):** Verifies full Kubernetes and CNI readiness (`Node Ready` and `kube-system` pod readiness) after Cilium is installed.
* Validated configuration via `./init-state.sh`, `tofu fmt -check -recursive`, and `tofu validate` (`Success! The configuration is valid.`).

---

## Phase 3: Iterative Bare-Metal Node Provisioning (In Progress)

### Step 3.1: Control Plane Node (`controlplane-1` — HP Compaq Pro 6300 SFF at `10.10.10.51`) — COMPLETED
1. **Maintenance Mode & Disk Interrogation:**
   * Booted from the Talos `v1.13.7` USB installer. Executed a clean disk reset from the bootloader to clear old Talos `STATE` and `EPHEMERAL` signatures.
   * Interrogated hardware via `talosctl get discoveredvolumes --nodes 10.10.10.51 --insecure`:
     * `/dev/sda`: `256 GB` SATA SSD (KingFast) — targeted as primary boot/OS/etcd disk.
     * `/dev/sdb`: `1.0 TB` SATA rotational HDD (`ST1000LM024`) — confirmed raw/wiped with zero leftover partitions.
2. **OpenTofu Execution & Remote State Binding:**
   * Applied `tofu plan -out=tfplan` with `worker_nodes = {}`.
   * OpenTofu generated `talos_machine_secrets`, configured the node with Talos native Layer 2 VIP `10.10.10.10`, installed Talos `v1.13.7` to `/dev/sda`, and initialized `etcd`.
   * The OpenTofu state was automatically persisted to the GitLab HTTP remote backend (`homelab-bootstrap` State Version 1).
   * Helm provider deployed Cilium `v1.15.5` with `kubeProxyReplacement = true`, native eBPF routing, and L2 announcements.
   * `data.talos_cluster_health.post_cni` validated full cluster readiness with `skip_kubernetes_checks = false`.
3. **Storage Mount & Credential Extraction:**
   * Verified Talos `UserVolumeConfig` automatically partitioned `/dev/sdb`, formatted with XFS, and mounted to `/var/mnt/longhorn-extra` (`/dev/sdb1`).
   * Extracted `talosconfig` and `kubeconfig` to local directories (`~/.talos/config`, `~/.kube/config`).
4. **Relocation & Enclave Verification:**
   * Safely shut down node via `talosctl shutdown --nodes 10.10.10.51`, removed USB, moved chassis to the cluster shelf, and patched to **Port 1** of switch `TL-SG108E` (`10.10.10.5`).
   * Validated post-relocation health: ICMP ping to VIP `10.10.10.10` and IP `10.10.10.51` returned 0% packet loss; `talosctl health` reported all etcd, apid, kubelet, and static pod checks `OK`; `kubectl get nodes -o wide` reported `controlplane-1` as `Ready`.

---

### Step 3.2: Worker Node 1 (`worker-1` — HP Pavilion Desktop 590-p0xxx at `10.10.10.52`) — COMPLETED
1. **Maintenance Mode & Empirical Interrogation:**
   * Discovered wired Gigabit NIC (`enp2s0`) MAC address was `f4:39:09:33:dc:f9`. Corrected the `ER605` DHCP address reservation, updating dynamic lease `10.10.10.32` to static assignment `10.10.10.52`.
   * Interrogated attached disks via `talosctl get discoveredvolumes --nodes 10.10.10.52 --insecure`:
     * Discovered USB installer enumerated as `/dev/sdb`, shifting internal SATA drives to `/dev/sdc` (Seagate `ST1000DM003-1SB1`, 1.0 TB) and `/dev/sdd` (Western Digital `WD10EZEX-60W`, 1.0 TB).
     * Wiped residual GPT and ext4 partitions from both drives (`talosctl wipe disk sdc`, `talosctl wipe disk sdd`).
2. **OpenTofu Execution & Remote State Binding:**
   * Uncommented `"worker-1"` in `infrastructure/bootstrap/terraform.tfvars` targeting `install_disk = "/dev/sdc"` and worker schematic `71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09:v1.13.7` (`iscsi-tools`, `util-linux-tools`, `realtek-firmware`).
   * Executed `tofu apply tfplan`. OpenTofu pushed the worker machine configuration, installed Talos OS to `/dev/sdc`, and updated GitLab remote state (`homelab-bootstrap` State Version 2).
   * Verified Talos `UserVolumeConfig` automatically partitioned `/dev/sdd` as `/dev/sdd1`, formatted with XFS, and mounted to `/var/mnt/longhorn-extra`.
   * Two-stage health gate (`post_cni`) confirmed `worker-1` joined the cluster and reached `Ready`.
3. **Relocation & Enclave Verification:**
   * Safely shut down node via `talosctl shutdown --nodes 10.10.10.52`, removed USB drive, relocated chassis to the rack shelf, and patched to **Port 2** of switch `TL-SG108E` (`10.10.10.5`).
   * Validated post-relocation health: ICMP ping to `10.10.10.52` returned 0% packet loss; `kubectl get nodes -o wide` confirmed both `controlplane-1` and `worker-1` online and `Ready`.

---

### Step 3.3: Worker Node 2 (`worker-2` — Lenovo ideacenter 310S-08IAP at `10.10.10.53`) — COMPLETED
1. **Maintenance Mode & Empirical Interrogation:**
   * Booted from the Talos `v1.13.7` USB installer into Maintenance Mode.
   * Acquired `10.10.10.53` on `enp2s0` (MAC: `6c:4b:90:45:42:16`).
   * Interrogated disk layout via `talosctl get discoveredvolumes --nodes 10.10.10.53 --insecure`:
     * USB drive enumerated as `/dev/sdb`.
     * Internal 500GB HDD (`ST500DM002-1SB10`) enumerated as `/dev/sdc` (confirmed clean with zero leftover partitions).
2. **OpenTofu Execution & Remote State Binding:**
   * Configured `"worker-2"` in `terraform.tfvars` targeting `install_disk = "/dev/sdc"`, worker schematic `71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09:v1.13.7`, and `mount_secondary_disk = false`.
   * Executed `tofu apply tfplan`. OpenTofu applied the configuration, installed Talos OS to `/dev/sdc`, and persisted **State Version 3** to the GitLab remote HTTP backend (`homelab-bootstrap`).
   * Health gate (`post_cni`) confirmed all three cluster nodes reporting `Ready`.
3. **Relocation & Enclave Verification (DoD 1 Verified):**
   * Safely shut down node via `talosctl shutdown --nodes 10.10.10.53`, removed USB drive, relocated chassis to the rack shelf, and patched to **Port 3** of switch `TL-SG108E` (`10.10.10.5`).
   * Validated post-relocation health across the switch: ICMP pings to `10.10.10.10` (VIP), `10.10.10.51`, `10.10.10.52`, and `10.10.10.53` all returned 0% packet loss.
   * Talos API `talosctl --nodes 10.10.10.51 health` confirmed etcd, apid, kubelet, and static pod checks `OK`.
   * `talosctl get members` confirmed all three physical members active.
   * `kubectl get nodes -o wide` confirmed all 3 nodes `Ready`.
   * `kubectl get pods -n kube-system -o wide` confirmed Cilium eBPF agent pods running across all 3 nodes.
   * **DoD 1 Complete:** All physical nodes re-established through OpenTofu statements backed by GitLab-managed Terraform state, with Talos API and Kubernetes control plane fully verified.

---

## Next Steps (Pending Execution)
* **Phase 4:** Declaratively bootstrap ArgoCD and reconcile Sync Waves `-1` through `2` (`system-config`, `cilium-lb-ipam`, `external-secrets`, `argo-workflows`, `gitlab-runner`, `longhorn`, `ingress-nginx`, `minio`, `knative`) (DoD 2).
* **Phase 5:** Finalize post-provisioning device paths, record `ADR-0010`, and resume Feature 3.5 (DoD 3).
