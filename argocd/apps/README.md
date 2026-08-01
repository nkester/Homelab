# ArgoCD Applications Directory (`/argocd/apps`)

## Purpose
This directory contains declarative Kubernetes `Application` CRD manifests managed by the root App-of-Apps controller ([root-app.yaml](file:///home/neil/Documents/Projects/homelab/argocd/root-app.yaml)).

## Execution Plan & Governance
1. **App-of-Apps Pattern Execution:** Any `Application` manifest placed in this directory is automatically discovered and applied by `root-app.yaml`.
2. **Sync Wave Ordering:** Application manifests placed here will define `argocd.argoproj.io/sync-wave` annotations to control dependency execution order:
   * **Wave -1 / 0:** Core Operators & CRDs (Argo Workflows, External Secrets Operator).
   * **Wave 1 / 2:** Storage & Ingress (Longhorn, NGINX Ingress, cert-manager).
   * **Wave 3+:** Workload Layer (CloudNativePG, RStudio, VSCode).
3. **Naming Convention:** Files in this directory must match `<feature/service-name>.yaml` (e.g., `argo-workflows.yaml`, `longhorn.yaml`).
