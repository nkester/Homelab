# Distributed Storage Subsystem (`/infrastructure/storage`)

## Overview
This directory contains the declarative Kubernetes manifests for the cluster's distributed block storage layer (**Longhorn**) and object storage layer (**MinIO**, migrating to a FOSS S3 backend in Feature 4.3).

Longhorn provides resilient, replicated, persistent block storage across all three bare-metal Talos Linux desktop nodes (`controlplane-1` `10.10.10.51`, `worker-1` `10.10.10.52`, `worker-2` `10.10.10.53`).

## Architectural Design & Key Decisions
- **Helm Release Management:** Core Longhorn operator and CSI components are deployed via ArgoCD native Helm rendering in [`/argocd/apps/longhorn.yaml`](/argocd/apps/longhorn.yaml) (Sync Wave `1`, chart `v1.6.2`).
- **Declarative Multi-Disk Node Topology:** Per-node disk layouts (`longhorn.io/v1beta2` `Node` CRs) are managed declaratively in [`/infrastructure/storage/longhorn/nodes/`](/infrastructure/storage/longhorn/nodes/) and reconciled by [`/argocd/apps/longhorn-config.yaml`](/argocd/apps/longhorn-config.yaml) (Sync Wave `2`, `ServerSideApply=true`, `automated.prune: false`).
- **Secondary Dedicated HDDs:** `/var/mnt/longhorn-extra` (`1.0 TB` XFS via Talos `UserVolumeConfig`) is active on both `controlplane-1` and `worker-1` (`10 GiB` reserved, tags: `hdd`, `dedicated`).
- **`etcd` SSD Isolation:** Scheduling is explicitly disabled (`allowScheduling: false`) on `controlplane-1`'s 256 GB OS/etcd SSD (`/var/lib/longhorn`), isolating control plane quorum IOPS from block storage workloads.
- **Replica Topology:** Default volume replica count is `2` with `replicaSoftAntiAffinity: false`, enforcing strict synchronous cross-node replication across the 3-node fault domain pool.
- **Default StorageClass:** `longhorn` is configured as the default Kubernetes `StorageClass` for dynamic PVC provisioning.

## Directory Structure
```text
infrastructure/storage/
├── README.md                          # Subsystem overview (this file)
├── longhorn/
│   ├── kustomization.yaml             # Pure Kustomize bundle for Longhorn Node CRs
│   └── nodes/
│       ├── controlplane-1.yaml        # Isolates /var/lib/longhorn (etcd SSD); enables /var/mnt/longhorn-extra
│       ├── worker-1.yaml              # Enables /var/lib/longhorn + /var/mnt/longhorn-extra
│       └── worker-2.yaml              # Enables /var/lib/longhorn
└── minio/
    ├── README.md                      # MinIO object storage subsystem documentation (migrating in Feature 4.3)
    ├── tenant-secret.yaml             # ExternalSecret syncing MinIO root credentials from GitLab
    └── tenant.yaml                    # MinIO Tenant CR defining S3 pool size, volumes, and service exposure
```

## GitOps Deployment Path
Longhorn is deployed automatically via ArgoCD through the root App-of-Apps controller:  
- **Longhorn Operator (Helm):** [`/argocd/apps/longhorn.yaml`](/argocd/apps/longhorn.yaml) — Sync Wave `1`
- **Longhorn Node Disk Config:** [`/argocd/apps/longhorn-config.yaml`](/argocd/apps/longhorn-config.yaml) — Sync Wave `2`

## Documentation References
For detailed architectural blueprints, failure domain calculations, and operational runbooks, refer to:  
- Architecture Blueprint: [`/docs/architecture/05-distributed-storage.md`](/docs/architecture/05-distributed-storage.md)
- UI Access Runbook: [`/docs/runbooks/cluster-access.md`](/docs/runbooks/cluster-access.md)
