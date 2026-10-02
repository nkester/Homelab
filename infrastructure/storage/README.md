# Distributed Storage Subsystem (`/infrastructure/storage`)

## Overview
This directory contains the declarative manifests and values overlays for the cluster's distributed block storage layer powered by **Longhorn**.

Longhorn provides resilient, replicated, persistent block storage across bare-metal Talos Linux nodes (`HP Control Node 10.10.10.51`, `Lenovo Worker 1 10.10.10.52`, `Dell Worker 2 10.10.10.53`).

## Architectural Design & Key Decisions
- **Storage Driver**: Longhorn Engine & CSI Plugin.
- **Node Storage Mount**: `/var/lib/longhorn` on host node root file system partitions.
- **Replica Topology**: Default volume replica count set to `2`, distributing synchronous volume replicas across worker nodes (`10.10.10.52` and `10.10.10.53`).
- **Default StorageClass**: Longhorn is configured as the default Kubernetes `StorageClass` (`longhorn`), handling dynamic PVC provisioning across all cluster namespaces.
- **Talos OS Integration**: Utilizes Talos system extensions (`iscsi-tools` v0.2.0 and `util-linux-tools` 2.42.2) for host iSCSI volume attachments and `nsenter` support.
- **Pod Security Admission**: Namespace `longhorn-system` is configured with `pod-security.kubernetes.io/enforce: privileged` to permit host device and volume driver mounts.

## Directory Structure
```
infrastructure/storage/
├── README.md                 # Subsystem overview and operational guide (this file)
└── longhorn/
    ├── kustomization.yaml    # Kustomize manifest bundle with Helm inflation
    ├── namespace.yaml        # longhorn-system namespace with privileged PSA labels
    └── values.yaml           # Helm chart values overlay (replica count, storageclass settings)
```

## GitOps Deployment Path
Longhorn is deployed automatically via ArgoCD through the root App-of-Apps controller:
- **Application Manifest**: [`/argocd/apps/longhorn.yaml`](/argocd/apps/longhorn.yaml)
- **Sync Wave**: `1` (Infrastructure Storage Layer)

## Documentation References
For detailed architectural blueprints, failure domain calculations, and operational runbooks, refer to:
- [`/docs/architecture/05-distributed-storage.md`](/docs/architecture/05-distributed-storage.md)