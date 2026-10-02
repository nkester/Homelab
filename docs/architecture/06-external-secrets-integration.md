# Architecture Blueprint: External Secrets Integration

## 1. Abstract
**Purpose**: Integrates the local Kubernetes cluster with GitLab SaaS to securely provision credentials without exposing tokens in version control.
**Platform Tier**: Layer III (Management / GitOps)
**Owner**: Platform Engineering

## 2. Logical Design
*The External Secrets Operator acts as a synchronization engine between the GitLab API and the local etcd datastore.*

- **Service Type**: Operator (Deployment)
- **Namespace**: `external-secrets`
- **Upstream Source**: https://charts.external-secrets.io
- **Communication Pattern**: North-South via WAN (Outbound HTTP GET to gitlab.com).

## 3. Implementation Details
*Declarative state and configuration management.*

- **Repository Path**: `argocd/apps/external-secrets-operator.yaml`, `infrastructure/bootstrap/secret-store.yaml`
- **Dependency Chain**: Requires ArgoCD. Must deploy before any workloads (e.g., CNPG, RStudio) that require injected secrets.
- **Key Configuration Parameters**:
  - `ClusterSecretStore` pointing to GitLab Project ID.
  - Requires a manually injected, out-of-band `Secret` containing a GitLab Personal Access Token with the `read_api` scope. Execute the following command for bootstrapping:
    ```bash
    kubectl create secret generic gitlab-secret-token \
      --from-literal=token="<YOUR_READ_API_TOKEN>" \
      -n external-secrets
    ```

## 4. Resilience & Failure Domains
*Engineering for hardware/software failure.*

- **Replication Factor**: 1 replica for the ESO controller (default). High availability relies on Kubernetes rescheduling the pod if a node fails.
- **Disaster Recovery**: During a WAN outage, existing secrets are cached in `etcd`. New deployments requiring new secrets will hang in `ContainerCreating` until WAN is restored. A full bare-metal restore requires WAN connectivity to rehydrate the secrets.
- **Token Lifecycle & Rotation**: GitLab SaaS enforces a maximum token lifespan of 365 days. To prevent silent synchronization failures upon expiration, you must manually update the injected token before it expires:
  ```bash
  kubectl create secret generic gitlab-secret-token \
    --from-literal=token="<YOUR_NEW_TOKEN>" \
    -n external-secrets \
    --dry-run=client -o yaml | kubectl apply -f -
  ```

## 5. Security Posture
*Zero-Trust implementation details.*

- **Network Policies**: Requires outbound egress to `gitlab.com` (HTTPS port 443).
- **Secrets Management**: No tokens are stored in Git. The authentication token for the SecretStore is provisioned out-of-band via `kubectl`.

## 6. Verification & Validation (DoD)
*How to confirm the "Condition of Satisfaction" for this component.*

- **Command 1**: `kubectl get pods -n external-secrets`
- **Command 2**: `kubectl get clustersecretstore -o wide`
- **Command 3**: `kubectl get secret test-secret-sync -n default`
