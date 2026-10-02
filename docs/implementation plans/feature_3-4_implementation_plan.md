# Feature 3.4: Object Storage Foundation (MinIO)

Establish an enterprise S3-compatible object storage layer within the Kubernetes cluster using the MinIO Operator and Tenant CRD, backed by Longhorn distributed storage. This provides S3 API endpoints required for downstream analytics pipelines, ML artifacts, and Velero cluster disaster recovery backups.

## State Retrieval & Audit-Before-Write (ABW)

### Roadmap Alignment
- **Parent Epic:** Epic 3 (GitOps & Analytic Stack) — `In Progress`
- **Feature:** Feature 3.4 (Object Storage Foundation (MinIO)) — `In Progress`
- **Definition of Done (DoD) Criteria:**
  1. MinIO Operator deployed via ArgoCD.
  2. S3-compatible API reachable via internal NGINX Ingress / Cluster Service.
  3. Test bucket provisioned declaratively via YAML/SecretStore.

### Retrospective Lessons Applied
- **Search-Before-Write Compliance:** Upstream `minio/operator` chart (`v6.0.2`) and `minio.min.io/v2` Tenant CRD schemas verified against upstream docs.
- **Zero-Token-in-Git via ESO:** MinIO root credentials (`rootUser` and `rootPassword`) provisioned via GitLab CI/CD variables and hydrated into K8s via External Secrets Operator (`ExternalSecret`). No manual out-of-band `kubectl create secret` will be used.
- **ArgoCD Loose Coupling (2-App Pattern):** Operator (`minio-operator`) and Tenant (`minio-tenant`) decoupled into separate ArgoCD `Application` manifests with distinct Sync Waves.
- **Node Alignment & Resource Guardrails:** Tenant configured for 2 servers across worker-1 (`10.10.10.52`) and worker-2 (`10.10.10.53`), utilizing `storageClassName: longhorn` with `ReadWriteOnce` volumes.

---

## User Review Required

> [!IMPORTANT]
> **Zero-Token-in-Git Policy Enforced via External Secrets Operator (ESO)**
> MinIO administrative credentials (`MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`) will NOT be committed to Git or manually injected via out-of-band `kubectl` commands. You will be prompted to create two CI/CD variables in the GitLab repository UI (`https://gitlab.com/nkester-personal-cloud/homelab`). The pre-existing `ClusterSecretStore` will fetch these via ESO to hydrate the `minio-creds` secret in the `minio-tenant` namespace.

> [!NOTE]
> **Storage Backend & Volume Access Mode Rationale (`ReadWriteOnce` vs `ReadWriteMany`)**
> MinIO Tenant volumes are explicitly provisioned with `ReadWriteOnce` (RWO) access mode backed by `storageClassName: longhorn`.
> - **Why RWO?** Distributed object stores (MinIO) perform block-level data placement, erasure coding, and integrity management at the *application layer*. Giving each MinIO server pod direct, unmediated block access (RWO) to its dedicated disk prevents POSIX file locking contention and filesystem corruption.
> - **Multi-Client Access:** Multi-client concurrent read/write capability is provided higher up at the **S3 HTTP API protocol layer** (`ReadWriteMany` for downstream clients consuming S3 endpoints), while individual storage pods maintain strict single-writer block isolation.

---

## Proposed Changes

### Documentation (Architectural & Decision Logs)

#### [NEW] [0008-object-storage-minio.md](/docs/adr/0008-object-storage-minio.md)
- **What it does:** Documents the architectural selection of MinIO Operator and Tenant CRD over monolithic S3 alternatives or standalone MinIO pods.
- **Why it is needed:** Establishes design rationale for S3 object storage compatibility, high availability on Longhorn, and GitOps lifecycle management.

#### [NEW] [07-object-storage-foundation.md](/docs/architecture/07-object-storage-foundation.md)
- **What it does:** Details the logical architecture, S3 API endpoint routing (`minio.minio-tenant.svc.cluster.local:9000`), authentication integration with ESO, and Longhorn persistence model.
- **Why it is needed:** Fulfills Layer 2 system documentation requirements for cluster operations.

#### [MODIFY] [README.md](/docs/architecture/README.md)
- **What it does:** Registers `07-object-storage-foundation.md` in the Architecture Documentation Index table.
- **Why it is needed:** Maintains complete indexing and operational navigation across all architecture blueprints.

---

### ArgoCD Manifests (`argocd/apps/`)

#### Architectural Rationale for Two ArgoCD Applications (Loose Coupling)
We deploy MinIO as **two separate ArgoCD Applications** (`minio-operator.yaml` and `minio-tenant.yaml`) rather than a single tightly coupled manifest:
1. **CRD Dependency & Readiness Boundary:** `minio-operator` installs the Custom Resource Definitions (`tenants.minio.min.io`). ArgoCD must fully register and establish CRD API schemas in Kubernetes (Sync Wave 1) before evaluating or applying `Tenant` custom resources (Sync Wave 2).
2. **Blast Radius & Lifecycle Decoupled:** Controller updates or restarts of the MinIO Operator do not restart or tear down running storage Tenants. The data plane (S3 storage) remains online independently of control plane operator lifecycle events.
3. **Multi-Tenant Scalability:** A single cluster operator can manage multiple isolated Tenants across namespaces without requiring operator helm chart re-deployments.

#### [NEW] [minio-operator.yaml](/homelab/argocd/apps/minio-operator.yaml)
- **What it does:** Defines an ArgoCD `Application` manifest subscribing to the official MinIO Operator Helm chart (`https://operator.min.io/`, chart: `operator`, targetRevision: `6.0.2`). Annotated with `sync-wave: "1"`.
- **Why it is needed:** Satisfies DoD Criterion 1 ("MinIO Operator deployed via ArgoCD").

#### [NEW] [minio-tenant.yaml](/homelab/argocd/apps/minio-tenant.yaml)
- **What it does:** Defines an ArgoCD `Application` manifest tracking `infrastructure/storage/minio` on `argocd-deploy` branch, deploying the MinIO Tenant custom resources. Annotated with `sync-wave: "2"`.
- **Why it is needed:** Manages the lifecycle of the MinIO S3 cluster, ESO secrets, and buckets via GitOps.

---

### Infrastructure Configurations (`infrastructure/storage/minio/`)

#### [NEW] [README.md](/homelab/infrastructure/storage/minio/README.md)
- **What it does:** Provides operational guidance for managing MinIO Tenants, bucket provisioning, and troubleshooting commands.
- **Why it is needed:** Maintains repository self-documentation standard.

#### [NEW] [tenant-secret.yaml](/homelab/infrastructure/storage/minio/tenant-secret.yaml)
- **What it does:** Defines an `ExternalSecret` resource syncing `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` from GitLab CI/CD variables into K8s Secret `minio-creds` in namespace `minio-tenant`.
- **Why it is needed:** Securely supplies root credentials to the MinIO Tenant via ESO without committing plain-text secrets to Git or executing manual `kubectl create secret` commands.

#### [NEW] [tenant.yaml](/homelab/infrastructure/storage/minio/tenant.yaml)
- **What it does:** Defines the `minio.min.io/v2` `Tenant` custom resource configuring 2 servers, 1 volume per server (10Gi storage request per volume using `storageClassName: longhorn` with `ReadWriteOnce`), exposing S3 service on port `9000` and Console on port `9001`.
- **Why it is needed:** Satisfies DoD Criterion 2 ("S3-compatible API reachable").

#### [NEW] [test-bucket.yaml](/homelab/infrastructure/storage/minio/test-bucket.yaml)
- **What it does:** Provisioning manifest using a lightweight MinIO Job or `mc` client container to declaratively create the `test-bucket` (and pre-stage `velero-backups` bucket) upon Tenant initialization.
- **Why it is needed:** Satisfies DoD Criterion 3 ("Test bucket provisioned declaratively").

---

## Verification Plan

### Phase 1: Operator Deployment Verification
- Verify MinIO Operator pods in `minio-operator` namespace are `Running` and CRDs (`tenants.minio.min.io`) are registered.

### Phase 2: GitLab Secrets & Tenant Deployment Verification
- Prompt user to create `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` in GitLab UI.
- Verify `ExternalSecret` in `minio-tenant` namespace syncs cleanly and generates `minio-creds` K8s secret.
- Verify MinIO Tenant pods in `minio-tenant` namespace reach `Running` state and Longhorn PVCs are bound.
- Test S3 API health endpoint via internal cluster DNS (`minio.minio-tenant.svc.cluster.local:9000/minio/health/live`).

### Phase 3: Declarative Bucket Sync Verification
- Inspect test bucket creation output to verify `test-bucket` exists and is writable via S3 API protocol.

---

## Phased Execution Plan & CLI Guidance

*Note: All CLI commands and Git operations will be provided in copy-paste markdown blocks for manual execution by the project manager.*

### Phase 1: Documentation, Architecture Index, & Operator Application
1. Generate `docs/adr/0008-object-storage-minio.md` and `docs/architecture/07-object-storage-foundation.md`.
2. Update `docs/architecture/README.md` index.
3. Commit `argocd/apps/minio-operator.yaml` to deploy operator via ArgoCD.

**Phase 1 Manual Commands (Executed by User):**
```bash
git add docs/ argocd/apps/minio-operator.yaml
git commit -m "feat(storage): deploy minio operator via argocd (sync wave 1)"
git push origin argocd-deploy

# Verify Operator Deployment
kubectl get pods -n minio-operator -l app.kubernetes.io/name=operator
kubectl get crd tenants.minio.min.io
```

### Phase 2: GitLab Secret Configuration & MinIO Tenant Deployment
1. **User Action (GitLab UI):** Create two masked, non-expanded CI/CD Variables in GitLab (`Settings > CI/CD > Variables`):
   - `MINIO_ROOT_USER`: (e.g., `admin-homelab`)
   - `MINIO_ROOT_PASSWORD`: (e.g., strong random password)
2. Commit `infrastructure/storage/minio/` manifests and `argocd/apps/minio-tenant.yaml`.

**Phase 2 Manual Commands (Executed by User):**
```bash
git add infrastructure/storage/minio/ argocd/apps/minio-tenant.yaml
git commit -m "feat(storage): deploy minio tenant and external secret (sync wave 2)"
git push origin argocd-deploy

# Verify ESO Secret Sync & Tenant Pods
kubectl get externalsecret -n minio-tenant
kubectl get secret minio-creds -n minio-tenant
kubectl get tenant -n minio-tenant
kubectl get pods -n minio-tenant -o wide
kubectl get pvc -n minio-tenant
```

### Phase 3: S3 API & Bucket Provisioning Validation
1. Verify S3 API reachability and bucket presence.

**Phase 3 Manual Commands (Executed by User):**
```bash
# Test internal S3 API endpoint health
kubectl run s3-test --rm -i --tty --image=curlimages/curl -- \
  curl -s -I http://minio.minio-tenant.svc.cluster.local:9000/minio/health/live

# Verify test-bucket creation job
kubectl logs -n minio-tenant job/create-test-bucket
```
