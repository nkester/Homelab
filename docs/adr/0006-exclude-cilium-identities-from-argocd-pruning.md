# ADR-0006: Exclude Cilium eBPF Identities from ArgoCD GitOps Resource Pruning

* **Status:** Accepted
* **Date:** 2026-08-13
* **Author:** Platform Engineering & ORSA Systems Architect

## 1. Context
During the GitOps deployment of Longhorn (Feature 3.2), ArgoCD entered a continuous automated synchronization loop (`Synced` $\leftrightarrow$ `OutOfSync`), constantly pruning and re-creating `CiliumIdentity` custom resources (`cilium.io/v2`).

* **Root Cause**: Cilium CNI (Feature 2.4) dynamically allocates `CiliumIdentity` objects in the cluster datapath at runtime whenever pod security labels change. Because ArgoCD has `prune: true` enabled in its automated sync policy, ArgoCD detects unmanaged `cilium.io` cluster resources as drift from Git and deletes (prunes) them. The Cilium eBPF agent immediately re-allocates them, creating an endless pruning/re-creation war.
* **GitOps Compliance**: Manual `kubectl patch` commands violate GitOps state management. All ArgoCD system settings must be declared version-controlled in Git.

## 2. Decision
1. **Declarative System Exclusions**: Create [`/argocd/argocd-cm.yaml`](/argocd/argocd-cm.yaml) declaring `resource.exclusions` for `cilium.io` `CiliumIdentity` across all cluster instances.
2. **GitOps Root Registration**: Register `argocd-cm.yaml` in [`/argocd/kustomization.yaml`](/argocd/kustomization.yaml) to ensure the ArgoCD system configuration is deployed and version-controlled via GitOps.

## 3. Consequences
* **Positive:** Completely eliminates the pruning war between ArgoCD and Cilium eBPF across all cluster namespaces; restores stable `Synced / Healthy` status.
* **Negative:** ArgoCD will no longer track or prune `CiliumIdentity` objects (which are managed exclusively by Cilium CNI).
* **Neutral:** Managed declaratively in Git without requiring out-of-band `kubectl` interventions.
