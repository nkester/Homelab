# ADR-0008: Object Storage Foundation (MinIO Operator & Tenant)

* **Status:** Accepted
* **Date:** 2026-08-18
* **Author:** Neil Kester

## 1. Context
Feature 3.4 requires establishing an on-premise S3-compatible object storage layer to support enterprise data pipelines, analytical workloads (RStudio, KubeFlow), database WAL archiving (CloudNativePG), and disaster recovery backups (Velero). We evaluated a standalone MinIO Helm deployment, Ceph/Rook, and the MinIO Operator + Tenant CRD architecture on top of our existing Longhorn distributed block storage layer.

Ceph/Rook introduces excessive resource consumption and operational complexity for a 3-node bare-metal cluster (1 control plane, 2 workers). Standalone MinIO lacks declarative Custom Resource Definitions (CRDs) for lifecycle management and automated bucket/user provisioning.

## 2. Decision
We selected the **MinIO Operator** (`v6.0.2`) deploying a dedicated **MinIO Tenant** (`minio.min.io/v2`) backed by `storageClassName: longhorn` with `ReadWriteOnce` (RWO) persistent volume claims.

Key Architectural Decisions:
1. **Decoupled ArgoCD Deployment (2-App Pattern):** `minio-operator` is deployed in Sync Wave 1 via official Helm chart (`https://operator.min.io/`). `minio-tenant` is deployed in Sync Wave 2 from local Git tracking `infrastructure/storage/minio`.
2. **Storage Access Mode Rationale:** Individual MinIO server pods mount Longhorn PVCs using `ReadWriteOnce` (RWO) to give MinIO direct, unmediated block access for erasure coding and file locking integrity. S3 API consumers access the cluster concurrently (`ReadWriteMany` pattern) over HTTP/HTTPS REST protocol (`minio.minio-tenant.svc.cluster.local:9000`).
3. **Zero-Token-in-Git Secret Governance:** MinIO root credentials (`rootUser` and `rootPassword`) are managed via GitLab CI/CD variables and hydrated into K8s Secret `minio-creds` via External Secrets Operator (`ExternalSecret`).

## 3. Consequences
* **Positive:** Complete S3 API compatibility for cloud-native workloads; CRD readiness separation via Sync Waves; independent control plane (operator) and data plane (tenant) lifecycle; zero plain-text tokens in version control.
* **Negative:** Overlapping storage management (MinIO pool + Longhorn CSI) introduces potential write amplification on mechanical HDDs if both layers perform volume replication.
  * **Mitigation:** Longhorn volumes allocated to MinIO are configured with `numberOfReplicas: 1` (or local block storage), eliminating double-write penalties on mechanical HDDs and delegating multi-node fault tolerance to MinIO's application-level pool topology across worker nodes.
* **Neutral:** Downstream workloads consume S3 endpoints via internal DNS rather than mounting local filesystems or PVCs.
