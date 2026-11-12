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
| **`worker-1`** | Worker Node 01 | `10.10.10.52` | **HP Pavilion Desktop 590-p0xxx** | Intel `i5-8400` @ 2.8GHz (6C/6T) | **12 GB DDR4** (`8GB + 4GB` from HP 570; `11Gi` usable) | • `/dev/sda`: **931.5 GB 3.5" HDD** (`ST1000DM003-1SB1`, S/N: `ZN10H6ZF`)<br>• `/dev/sdb`: **931.5 GB 3.5" HDD** (`WDC WD10EZEX-60W`, S/N: `WD-WCC6Y1PYNSEJ` from HP 570) | Realtek `RTL8111/8168` (`enp2s0`, `r8169`)<br>`28:3a:4d:07:ee:65` |
| **`worker-2`** | Worker Node 02 | `10.10.10.53` | **Lenovo ideacenter 310S-08IAP** | Intel `Celeron J3355` (2C/2T) | **8 GB DDR3L** (`1x 8GB PC3L-12800S` from Dell 15R) | • `/dev/sdb`: **465.8 GB 3.5" 7200 RPM HDD** (`ST500DM002-1SB10` retained for 7200 RPM I/O over 5400 RPM laptop drive) | Realtek `RTL8111/8168` (`enp2s0`, `r8169`)<br>`6c:4b:90:45:42:16` |

### 3. Architectural Gains
1. **Cluster Memory Expansion (`40 GB Total RAM`):** Worker memory increased from `~8 GB` to **`20 GB` dedicated worker RAM** (`12 GB` on `worker-1` + `8 GB` on `worker-2`), plus `20 GB` on `controlplane-1`, permanently resolving the Feature 3.4 memory tech debt ([docs/Retrospective.csv](../Retrospective.csv)).
2. **Full Gigabit Datapath (`1000BASE-T`):** Eliminating the Dell Inspiron 15R (`RTL810xE` 100 Mbps Fast Ethernet) removes the 12.5 MB/s network ceiling on synchronous Longhorn block replication.
3. **Storage Density (`~3.65 TB Across 5 Drives`):** Retains the `256 GB SSD` on `controlplane-1` to protect `etcd` `wal_fsync` latency while adding `~3.4 TB` of rotational SATA capacity across the three nodes.
4. **Sidero Image Schematic Parity:** Because both `worker-1` (`HP 590`) and `worker-2` (`Lenovo 310S`) utilize the `r8169` Realtek Gigabit NIC driver, both worker nodes share the existing Talos `v1.13.7` worker image schematic (`71405e3fe611adf767ae6e03aa4bf7535f53b8f7abbdc24a466b65d06af43a09`).

---

## Next Phases (Pending Execution)
* **Phase 2:** Update `ER605` VLAN 10 DHCP MAC-to-IP reservations (`.51`, `.52`, `.53`), initialize GitLab HTTP Terraform state (`homelab-bootstrap`), and refactor OpenTofu (`infrastructure/bootstrap/main.tf`) for iterative node provisioning.
* **Phase 3:** Iteratively stage each node at the primary workstation (`controlplane-1` → `worker-1` → `worker-2`), apply its OpenTofu configuration, relocate to the `TL-SG108E` switch (`Port 1`, `Port 2`, `Port 3`), and validate cluster quorum.
* **Phase 4:** Declaratively bootstrap ArgoCD and reconcile Sync Waves `-1` through `2` (`system-config`, `cilium-lb-ipam`, `external-secrets`, `argo-workflows`, `gitlab-runner`, `longhorn`, `ingress-nginx`, `minio`, `knative`).
* **Phase 5:** Finalize post-provisioning device paths, record `ADR-0010`, and resume Feature 3.5.
