# ADR-0011: MinIO FOSS Deprecation and Strategic S3 Migration Path

* **Status:** Accepted
* **Date:** 2026-11-15
* **Author:** Neil Kester

## 1. Context
In Feature 3.4 ([ADR-0008](./0008-object-storage-minio.md)), the MinIO Operator (`v6.0.2`) and MinIO Tenant CRDs were deployed over Longhorn distributed storage to establish the cluster's S3-compatible object storage layer for data pipelines, Argo Workflows artifact storage, and future disaster recovery backups (Velero).

Subsequent to that architectural baseline, MinIO altered its upstream distribution model:
1. MinIO transitioned to a "source-only" model for its community edition and archived the open-source community repository on GitHub.
2. MinIO completely removed or privatized official pre-built community container images from public registries. `quay.io/minio/minio` now returns HTTP `401 UNAUTHORIZED`, and `docker.io/minio/minio` returns API `404 / object not found`.
3. Continuing to run MinIO long-term introduces significant architectural and supply-chain technical debt: either the platform must build and maintain sovereign container images from an archived upstream Go codebase in a private GitLab Container Registry, or it must rely indefinitely on unvetted third-party community image builds (`pgsty/minio`, Chainguard, etc.).

This directly conflicts with the project's core operating principle: **Strictly FOSS** software with transparent, actively maintained, unencumbered distributions.

## 2. Decision

We adopt a two-phase architectural strategy:

### Phase 1: Tactical Interim Bridge (Feature 3.4-R)
To prevent expanding the blast radius of **Feature 3.4-R (Plane 1 State & Hardware Consolidation Refactor)** while physical node consolidation and OpenTofu remote state bootstrap are underway:
* Pin `infrastructure/storage/minio/tenant.yaml` to the community-maintained drop-in binary image `pgsty/minio:RELEASE.2026-08-04T00-00-00Z`.
* Pin `infrastructure/bootstrap/argo-workflows/kustomization.yaml` via Kustomize `images:` rewrite to the same release tag.
* This restores application state and unblocks Feature 3.4-R Definition of Done (DoD 2) immediately without introducing premature storage migrations.

### Phase 2: Strategic Migration at Feature 4.3
We formally log **Feature 4.3: FOSS S3 Object Storage Migration** into the HomeLab Project Roadmap under **Epic 4 (Core Infrastructure Services)**:
* **Sequencing Rationale:** Physical network constraints currently require the developer laptop to be physically hard-wired into VLAN 10 switch port infrastructure via Ethernet. To enable wireless development access from the main household WLAN into the VLAN 10 cluster enclave, **Feature 4.1 (Longhorn Storage)** and **Feature 4.2 (Ingress & cert-manager)** must be completed first.
* **Candidate Solutions:** The final replacement S3 engine will be evaluated and selected during Feature 4.3 planning. The primary candidates are:
  1. **SeaweedFS** (Apache 2.0): Highly performant distributed file and object store with native Kubernetes Helm/operator support and excellent small-file handling.
  2. **Garage** (AGPLv3): Lightweight, resilient, minimalist S3 store purpose-built for self-hosted homelab/edge clusters on commodity bare metal.

## 3. Consequences

* **Positive:**
  * Unblocks immediate validation and closure of Feature 3.4-R and Epic 3.
  * Preserves operational focus on network accessibility (Ingress and TLS certs) before tackling storage architecture overhauls.
  * Guarantees long-term adherence to pure FOSS principles by scheduling the elimination of MinIO and its proprietary operator before analytical workloads (Epic 6) scale.
* **Negative / Technical Debt:**
  * Temporarily accepts third-party build provenance risk (`pgsty/minio`) throughout the remainder of Epic 3 and early Epic 4.
  * Incurs future migration effort at Feature 4.3 to transfer S3 bucket contents, update DNS/Service routing for dependent workloads (Argo Workflows, Velero), and purge `minio.min.io` CRDs from the cluster.
