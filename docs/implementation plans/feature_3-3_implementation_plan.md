# Feature 3.3: External Secrets Operator (Option A - GitLab)

Deploying the External Secrets Operator (ESO) to integrate the Kubernetes cluster with GitLab CI/CD Variables. This enables secure, GitOps-compliant secret management by ensuring zero tokens are committed to the infrastructure repository.

## User Review Required

> [!WARNING]
> **Zero-Token-in-Git Policy Enforced**
> The token required to connect the cluster to GitLab will NOT be stored in Git. During Phase 2, you will be required to manually inject a GitLab Access Token via the `kubectl` CLI. 

> [!TIP]
> **Least Privileged Access (Token Scope)**
> The cluster will **not** write anything to GitLab. The ESO controller only makes HTTP GET requests to read your project's CI/CD variables. Therefore, when generating the token in GitLab, ensure it is restricted to the `read_api` scope only. Do not grant `api`, `write_repository`, or any other write permissions.

## Proposed Changes

### Documentation (Architectural & Decision Logs)

#### [NEW] `docs/adr/0007-external-secrets-provider.md`
- **What it does:** Documents the architectural decision to utilize GitLab's native CI/CD variables as the SecretStore provider over deploying a dedicated FOSS solution like HashiCorp Vault, Mozilla SOPS, or Bitnami Sealed Secrets.
- **Why it is needed:** Records the trade-off analysis (WAN dependency vs. Administrative Overhead and FOSS licensing constraints) for future audits.

#### [NEW] `docs/architecture/06-external-secrets-integration.md`
- **What it does:** Details the logical data flow between the GitLab SaaS API (`https://gitlab.com`) and the on-premise cluster. Explains the mechanism of `ExternalSecret` custom resources and how they resolve into native `Secret` objects cached within `etcd`.
- **Why it is needed:** Fulfills the requirement to document the system interface and operational behavior during network disconnects.

### ArgoCD Manifests

#### [NEW] `argocd/apps/external-secrets-operator.yaml`
- **What it does:** Deploys the External Secrets Operator via ArgoCD, pointing directly to the official Helm repository (`https://charts.external-secrets.io`). 
- **Why it is needed:** Fulfills the retrospective requirement to utilize ArgoCD native Helm rendering for third-party releases, avoiding Kustomize wrappers.

### Infrastructure Configuration

#### [NEW] `infrastructure/bootstrap/secret-store.yaml`
- **What it does:** Defines a `ClusterSecretStore` custom resource pointing to your GitLab project (`https://gitlab.com/nkester-personal-cloud/homelab`). It references the read-only token we will manually inject.
- **Why it is needed:** Satisfies DoD Criterion 1 ("SecretStore connected to GitLab").

#### [NEW] `infrastructure/bootstrap/test-external-secret.yaml`
- **What it does:** Defines an `ExternalSecret` resource that fetches a test value from GitLab and generates a native Kubernetes `Secret` in the `default` namespace.
- **Why it is needed:** Satisfies DoD Criterion 2 ("Test secret successfully synced").

## Verification Plan

### Automated Tests
None required for this phase.

### Manual Verification
1. **ESO Deployment:** `kubectl get pods -n external-secrets` (Verify all controller pods are `Running`).
2. **Provider Authentication:** `kubectl get clustersecretstore -o wide` (Verify the `STATUS` reports `Valid` and `Ready`).
3. **End-to-End Sync Verification:** `kubectl get secret test-secret-sync -n default` and `kubectl describe externalsecret test-secret` (Confirm the payload successfully migrated from GitLab into the local `etcd` cache).
