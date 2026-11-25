# Epic 4: Core Infrastructure Services - Engineering Log

## Overview
Hardening, expansion, and lifecycle governance of shared cluster infrastructure services: distributed multi-disk block storage (Longhorn), automated TLS/Ingress routing (NGINX Ingress & cert-manager), FOSS S3 object storage migration (ADR-0011), and Plane 1/2/3 version debt remediation.

---

## Feature 4.1: Longhorn Distributed Storage

### Key Technical Decisions & Milestones

* **Declarative Multi-Disk Activation (`longhorn-config`, Sync Wave 2):**
  * Audited live Talos `UserVolumeConfig` (`u-longhorn-extra`, `/dev/sdb1`, `1.0 TB` XFS) mounts across `controlplane-1` (`10.10.10.51`) and `worker-1` (`10.10.10.52`) and extracted existing auto-generated `default-disk-080400000000` keys to preserve active MinIO PVCs without disruption.
  * Authored declarative `longhorn.io/v1beta2` `Node` CRs under `infrastructure/storage/longhorn/nodes/` reconciled via a dedicated ArgoCD `Application` (`argocd/apps/longhorn-config.yaml`, `ServerSideApply=true`, `ServerSideDiff=true`, `automated.prune: false`, `selfHeal: true`).
  * Registered `/var/mnt/longhorn-extra` (`10 GiB` reserved, tags: `hdd`, `dedicated`) on `controlplane-1` and `worker-1`, bringing `~1.86 TB` of consolidated SATA HDD capacity online in Longhorn.

* **Control Plane `etcd` SSD Isolation:**
  * Configured `allowScheduling: false` on `controlplane-1`'s primary OS/etcd SSD (`default-disk-080400000000`, 256 GB) while enabling scheduling on its dedicated 1.0 TB SATA HDD (`/var/mnt/longhorn-extra`). This establishes a 3-node physical fault domain pool with zero `etcd` fsync I/O contention.

* **Helm Values Alignment & Dead-File Cleanup:**
  * Aligned inline Helm values in `argocd/apps/longhorn.yaml` (`defaultSettings.replicaSoftAntiAffinity: false`, `longhornUI.replicas: 1`, `metrics.prometheus.enabled: true`) while retaining pinned chart `v1.6.2` (deferring version upgrades to Feature 4.4).
  * Removed orphaned Feature 3.2 Kustomize-Helm files (`values.yaml`, `namespace.yaml`) from `infrastructure/storage/longhorn/`.

* **Empirical Validation (DoD #1 & DoD #2):**
  * **DoD #1 (All Disks Active):** Verified `longhorn` and `longhorn-config` both `Synced`/`Healthy`, all 3 Longhorn nodes `READY=True`, all 5 physical disks `Ready=True` (with `controlplane-1` OS/etcd SSD `allowScheduling=false`), and visual confirmation of `longhorn-extra` on `controlplane-1` and `worker-1` in the Longhorn UI (`http://localhost:8081`).
  * **DoD #2 (Cross-Node Replication):** Deployed a temporary GitOps validation workload (`argocd/apps/longhorn-validation.yaml` -> `2Gi` RWO PVC `longhorn-replication-test` / `pvc-b0d3e379-458c-45f9-ac1b-d31e186e2f7a`). Verified `STATE=attached`, `ROBUSTNESS=healthy`, `REPLICAS=2` synchronously running across **two distinct physical nodes** (`worker-1` and `controlplane-1`, both utilizing `/var/mnt/longhorn-extra`), and verified SHA-256 payload persistence (`/data/replication-verify.txt: OK`).
  * Declaratively removed `argocd/apps/longhorn-validation.yaml` and `infrastructure/storage/longhorn-validation/` in Phase 4 to prune temporary test resources via GitOps.
