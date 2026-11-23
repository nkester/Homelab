# ADR-0010: Plane 1 Remote State and Hardware Consolidation

* **Status:** Accepted
* **Date:** 2026-11-15
* **Author:** Neil Kester

## 1. Context

During the execution of **Epic 2 (Kubernetes Bootstrap)** and early **Epic 3 (GitOps & Analytic Stack)**, significant architectural and operational technical debt accumulated across **Plane 1 (Host OS & Physical Infrastructure Layer)**:

1. **State Vulnerability & Administrative Lockout:** OpenTofu was initially executed with a local `terraform.tfstate` backend. The loss of unversioned local state files resulted in the loss of `talos_machine_secrets`, severing administrative access to the Talos Machine API (`:50000`) and preventing declarative Day-2 machine configuration updates.
2. **Compute & Memory Starvation:** The initial worker cluster possessed only ~8 GB of allocatable RAM. `worker-1` (`Lenovo ideacenter 310S`) had only 4 GB of RAM, which caused immediate out-of-memory (OOM) evictions and scheduling failures when Feature 3.4 (MinIO Operator & Tenant) was introduced.
3. **Network Throughput Bottleneck:** `worker-2` (`Dell Inspiron 15R-5537` laptop) was constrained by an internal Fast Ethernet NIC (`Realtek RTL810xE`), capping network throughput at 100 Mbps (12.5 MB/s). This severely throttled synchronous Longhorn block replication and cross-node pod communication.
4. **Hardware Failure Domains:** Operating a consumer laptop with an aging lithium-ion battery, 5400 RPM 2.5" drive, and thermal throttling in a 24/7 server role introduced unacceptable hardware reliability risks.

Following the acquisition of two desktop chassis (`HP Pavilion 590-p0xxx` and `HP Pavilion 570-a1xx`), we initiated **Feature 3.4-R (Plane 1 State & Hardware Consolidation Refactor)** to rebuild the physical foundation into an all-desktop, all-Gigabit, enterprise-grade bare-metal cluster.

## 2. Decision

We executed a comprehensive refactoring of Plane 1 across hardware, networking, state management, and declarative bootstrap:

### 1. Component Harvesting & Topology Consolidation
We retired the `Dell Inspiron 15R` laptop and `HP Pavilion 570`, harvesting high-value components to maximize compute and storage density across three permanent desktop chassis:
* **`controlplane-1` (`HP Compaq Pro 6300 SFF` — `10.10.10.51`):** Intel i7-3770 (4C/8T), **20 GB DDR3**, `256 GB SATA SSD` (`/dev/sda` for OS/etcd) + `1.0 TB HDD` (`/dev/sdb1` harvested from Dell laptop, mounted at `/var/mnt/longhorn-extra`). Patched to **Port 1** of switch `TL-SG108E`.
* **`worker-1` (`HP Pavilion 590-p0xxx` — `10.10.10.52`):** Intel i5-8400 (6C/6T), **12 GB DDR4** (8 GB + 4 GB harvested from HP 570), `1.0 TB HDD` (`/dev/sdc` for OS) + `1.0 TB HDD` (`/dev/sdd1` harvested from HP 570, mounted at `/var/mnt/longhorn-extra`). Realtek Gigabit NIC (`f4:39:09:33:dc:f9`). Patched to **Port 2** of switch `TL-SG108E`.
* **`worker-2` (`Lenovo ideacenter 310S` — `10.10.10.53`):** Intel Celeron J3355 (2C/2T), **8 GB DDR3L** (harvested from Dell laptop), `500 GB 7200 RPM HDD` (`/dev/sdc`). Realtek Gigabit NIC (`6c:4b:90:45:42:16`). Patched to **Port 3** of switch `TL-SG108E`.

### 2. Pure Gigabit Datapath (`1000BASE-T`)
All cluster nodes now communicate exclusively over Gigabit Ethernet interfaces (`eno1` Intel, `enp2s0` Realtek) directly attached to the dedicated 8-port smart switch (`TL-SG108E`, `10.10.10.5`). Fast Ethernet has been completely eliminated from the cluster datapath.

### 3. Sovereign Remote State Backend (`homelab-bootstrap`)
* Discarded local state. Migrated OpenTofu state management to the **GitLab-managed HTTP Remote State Backend** (`https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/terraform/state/homelab-bootstrap`).
* Implemented distributed HTTP state locking (`POST /lock`, `DELETE /lock`).
* Created `infrastructure/bootstrap/init-state.sh` (`set -euo pipefail`) to initialize the backend dynamically using environment variables (`.env` strictly git-ignored), guaranteeing a Zero-Token-in-Git posture.

### 4. Modular, Parameterized OpenTofu Configuration
* Refactored `infrastructure/bootstrap/main.tf` to utilize a parameterized `worker_nodes` map (`for_each`), allowing iterative, single-node bare-metal provisioning and verification.
* Implemented a two-stage health gate surrounding `helm_release.cilium`:
  * `data.talos_cluster_health.pre_cni` (`skip_kubernetes_checks = true`): Verifies low-level Talos machine daemons and API server health before Helm execution.
  * `data.talos_cluster_health.post_cni` (`skip_kubernetes_checks = false`): Validates full Kubernetes CNI and node readiness.

### 5. Declarative GitOps ArgoCD Bootstrap via Helm
* Eliminated unnamespaced Talos `extraManifests` (which deployed ArgoCD pods improperly into the `default` namespace).
* Introduced a declarative OpenTofu resource `helm_release "argocd"` targeting namespace `argocd` (`argo-cd` chart `v6.7.18`), configured with `server.extraArgs = ["--insecure"]` and injecting the root app-of-apps manifest (`root-app.yaml`) via `extraObjects`.

## 3. Consequences

* **Positive:**
  * **Memory Ceiling Resolved:** Total cluster RAM expanded to **40 GB** (allocatable: 36.9 GiB), with **20 GB** dedicated to worker workloads, fully accommodating Longhorn, MinIO, Knative, and analytical workloads.
  * **Replication Throughput:** Synchronous Longhorn block replication bandwidth increased 10x (1000 Mbps full duplex), eliminating storage I/O stalls across the cluster.
  * **State Durability & Immutability:** Remote state in GitLab with distributed locking prevents state loss, secures Talos PKI machine secrets, and enables reproducible cluster provisioning from any workstation.
  * **Elimination of Hazardous Failure Domains:** Consumer laptop thermals and battery risks are eliminated; all nodes run on standardized desktop ATX/SFF power supplies with active cooling.
* **Negative / Operational Reality:**
  * Incurred a planned cluster downtime to rebuild the bare-metal OS layer and wipe/re-format persistent disks.
  * Required out-of-band injection of runner registration tokens (`gitlab-runner-secret`) and External Secrets GitLab tokens (`gitlab-secret-token`) post-bootstrap.
