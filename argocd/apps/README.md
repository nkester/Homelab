# ArgoCD Applications Directory (`/argocd/apps`)

## Purpose
This directory contains declarative Kubernetes `Application` CRD manifests and cluster system configuration overlays managed by the root App-of-Apps controller ([root-app.yaml](/argocd/root-app.yaml)).

## Execution Plan & Governance
1. **App-of-Apps Pattern Execution:** Any manifest placed in this directory is automatically discovered and applied by `root-app.yaml`.
2. **Sync Wave Ordering:** Application manifests placed here define `argocd.argoproj.io/sync-wave` annotations to control dependency execution order:
   * **Wave -1 / 0:** Core System Configuration & Operators (`argocd-cm.yaml`, `argo-workflows.yaml`, `gitlab-runner.yaml`).
   * **Wave 1 / 2:** Storage & Ingress (`longhorn.yaml`, NGINX Ingress, cert-manager).
   * **Wave 3+:** Workload Layer (CloudNativePG, RStudio, VSCode).
3. **Active Managed Applications:**
   * [`argocd-cm.yaml`](/argocd/apps/argocd-cm.yaml): Sync Wave `0` - ArgoCD System ConfigMap Patch (CiliumIdentity exclusion rules - ADR-0006).
   * [`argo-workflows.yaml`](/argocd/apps/argo-workflows.yaml): Sync Wave `0` - Argo Workflows Engine.
   * [`gitlab-runner.yaml`](/argocd/apps/gitlab-runner.yaml): Sync Wave `0` - In-cluster GitLab CI Runner Agent.
   * [`longhorn.yaml`](/argocd/apps/longhorn.yaml): Sync Wave `1` - Longhorn Distributed Block Storage.
4. **Naming Convention:** Files in this directory must match `<feature/service-name>.yaml` (e.g., `argo-workflows.yaml`, `longhorn.yaml`).
