# ArgoCD Applications Directory (`/argocd/apps`)

## Purpose
This directory contains declarative Kubernetes `Application` CRD manifests managed by the root App-of-Apps controller ([root-app.yaml](/argocd/root-app.yaml)).

## Execution Plan & Governance
1. **App-of-Apps Pattern Execution:** Any `Application` manifest (`kind: Application`) placed in this directory is automatically discovered and applied by `root-app.yaml`.
2. **Sync Wave Ordering:** Application manifests placed here define `argocd.argoproj.io/sync-wave` annotations to control dependency execution order:
   * **Wave -1:** System Configuration (`system-config.yaml` - CiliumIdentity exclusion rules).
   * **Wave 0:** Core Operators & System Services (`argo-workflows.yaml`, `gitlab-runner.yaml`).
   * **Wave 1 / 2:** Storage & Ingress (`longhorn.yaml`, NGINX Ingress, cert-manager).
   * **Wave 3+:** Workload Layer (CloudNativePG, RStudio, VSCode).
3. **Active Managed Applications:**
   * [`system-config.yaml`](/argocd/apps/system-config.yaml): Sync Wave `-1` - ArgoCD System Configuration (ADR-0006).
   * [`argo-workflows.yaml`](/argocd/apps/argo-workflows.yaml): Sync Wave `0` - Argo Workflows Engine.
   * [`gitlab-runner.yaml`](/argocd/apps/gitlab-runner.yaml): Sync Wave `0` - In-cluster GitLab CI Runner Agent.
   * [`longhorn.yaml`](/argocd/apps/longhorn.yaml): Sync Wave `1` - Longhorn Distributed Block Storage.
4. **Naming Convention:** Files in this directory must match `<feature/service-name>.yaml` (e.g., `argo-workflows.yaml`, `longhorn.yaml`).
