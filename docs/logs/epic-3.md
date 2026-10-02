# Epic 3: GitOps & Analytic Stack - Engineering Log

## Overview
Deployment of management components, declarative GitOps continuous delivery (ArgoCD), workflow state machine orchestration (Argo Workflows), and in-cluster enclave agents (GitLab Runner).

---

## Feature 3.1: GitOps & Workflow Orchestration (ArgoCD & Argo Workflows)

### Key Technical Decisions & Milestones

* **ArgoCD App-of-Apps Pattern Bootstrap:**
  * Implemented `argocd/root-app.yaml` as the parent application managing sub-applications under `/infrastructure` and `/apps`.
  * Configured git tracking pointing to `https://github.com/nkester/homelab.git` on branch `argocd-deploy`.

* **Argo Workflows Controller & REST API Integration:**
  * Deployed Argo Workflows controller in namespace `argo-workflows`.
  * Registered `WorkflowTemplate/dag-workflow` establishing a 4-task Directed Acyclic Graph (DAG) state machine (`task-a` -> `task-b` & `task-c` -> `task-d`) with dynamic parameter injection (`commit_sha`, `branch`).

* **Hybrid Cloud CI Scope Discovery & In-Cluster Runner Deployment (ADR-0005):**
  * *Discovery:* SaaS cloud-hosted GitLab runners (`*.saas-linux-small-amd64.runners-manager.gitlab.com`) cannot route to private RFC 1918 IPs (`10.10.10.10`) inside VLAN 10 over the public WAN.
  * *Solution:* Deployed an in-cluster `gitlab-runner` container agent in namespace `gitlab-runner` managed declaratively via ArgoCD (`argocd/apps/gitlab-runner.yaml`). Now cluster resources can be orchestrated without exposing the control plane directly to the public internet.
  * *Network Dynamics:* Outbound HTTPS polling (TCP 443) connects to `gitlab.com` without exposing inbound WAN ports. Jobs tagged with `tags: [homelab-runner]` execute locally inside VLAN 10, issuing REST API calls to `https://argo-server.argo-workflows.svc:2746` and offloading 100% of compute minutes from the GitLab SaaS 400-minute limit.

* **Security & Secret Hygiene Hardening:**
  * Created ServiceAccount `gitlab-ci-runner` bound to `workflow-submitter` Role with `pods/attach`, `pods/exec`, `pods/status`, and `events` permissions.
  * Implemented dynamic TOML token expansion in `gitlab-runner-deployment.yaml` (`sed` shell wrapper) to ensure zero plain-text tokens leak into public version control.
  * **Out-of-Band Cluster Secret Provisioning:** To enforce the "Zero-Token-in-Git" security posture, sensitive credentials were created directly in the cluster via `kubectl` prior to deployment:
    ```bash
    # 1. Provision gitlab-runner authentication token secret
    kubectl create secret generic gitlab-runner-secret \
      -n gitlab-runner \
      --from-literal=runner-registration-token="glrt-YOUR_RUNNER_AUTHENTICATION_TOKEN"

    # 2. Extract Bearer token for ARGO_WORKFLOW_TOKEN in GitLab CI/CD Variables
    kubectl get secret gitlab-ci-runner-token -n argo-workflows -o jsonpath='{.data.token}' | base64 --decode | tr -d '\r\n'
    ```

* **Validation & Success Verification:**
  * End-to-end pipeline execution succeeded: GitLab CI triggered `homelab-runner`, which issued an HTTP POST payload to the Argo Workflows REST API, returning HTTP 200 OK and instantiating `Workflow` instance `dag-workflow-xtpnf`.
  * All 5 Definition of Done (DoD) criteria for Feature 3.1 complete and verified.
