# ArgoCD Applications Directory (`/argocd/apps`)

## Purpose
This directory contains declarative Kubernetes `Application` CRD manifests managed by the root App-of-Apps controller ([root-app.yaml](/argocd/root-app.yaml)).

## Execution Plan & Governance
1. **App-of-Apps Pattern Execution:** Any `Application` manifest (`kind: Application`) placed in this directory is automatically discovered and applied by `root-app.yaml`.
2. **Sync Wave Ordering:** Application manifests placed here define `argocd.argoproj.io/sync-wave` annotations to control dependency execution order:
   * **Wave -1:** System Configuration (`system-config.yaml` - CiliumIdentity exclusion rules).
   * **Wave 0:** Core Networking & Platform Operators (`cilium-lb-ipam.yaml`, `argo-workflows.yaml`, `gitlab-runner.yaml`, `external-secrets-operator.yaml`).
   * **Wave 1:** Storage, Ingress & Runtime Operators (`longhorn.yaml`, `ingress-nginx.yaml`, `knative-operator.yaml`, `minio-operator.yaml`).
   * **Wave 2:** Stateful Tenants & Serverless Control Plane (`minio-tenant.yaml`, `knative-serving.yaml`).
   * **Wave 3+:** Workload Layer (CloudNativePG, RStudio, VSCode).
3. **Active Managed Applications:**
   * [`system-config.yaml`](/argocd/apps/system-config.yaml): Sync Wave `-1` - ArgoCD System Configuration (ADR-0006).
   * [`cilium-lb-ipam.yaml`](/argocd/apps/cilium-lb-ipam.yaml): Sync Wave `0` - Cilium LoadBalancer IPAM & L2 Announcement.
   * [`argo-workflows.yaml`](/argocd/apps/argo-workflows.yaml): Sync Wave `0` - Argo Workflows Engine.
   * [`gitlab-runner.yaml`](/argocd/apps/gitlab-runner.yaml): Sync Wave `0` - In-cluster GitLab CI Runner Agent.
   * [`external-secrets-operator.yaml`](/argocd/apps/external-secrets-operator.yaml): Sync Wave `0` - External Secrets Operator.
   * [`external-secrets-config.yaml`](/argocd/apps/external-secrets-config.yaml): Sync Wave `1` - External Secrets Cluster Stores.
   * [`longhorn.yaml`](/argocd/apps/longhorn.yaml): Sync Wave `1` - Longhorn Distributed Block Storage.
   * [`ingress-nginx.yaml`](/argocd/apps/ingress-nginx.yaml): Sync Wave `1` - Ingress NGINX Controller.
   * [`knative-operator.yaml`](/argocd/apps/knative-operator.yaml): Sync Wave `1` - Knative Serving Operator.
   * [`minio-operator.yaml`](/argocd/apps/minio-operator.yaml): Sync Wave `1` - MinIO Object Storage Operator.
   * [`minio-tenant.yaml`](/argocd/apps/minio-tenant.yaml): Sync Wave `2` - MinIO S3 Tenant Data Plane.
   * [`knative-serving.yaml`](/argocd/apps/knative-serving.yaml): Sync Wave `2` - Knative Serving Runtime & Kourier Gateway.
4. **Naming Convention:** Files in this directory must match `<feature/service-name>.yaml` (e.g., `argo-workflows.yaml`, `longhorn.yaml`).
