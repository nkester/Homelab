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

---

## Feature 3.5: Serverless Execution (Knative)

### Key Technical Decisions & Milestones

* **Post-3.4-R Re-Baseline & Control Plane Verification (DoD #1):**
  * Re-baselined [feature_3-5_implementation_plan.md](../implementation%20plans/feature_3-5_implementation_plan.md) against the consolidated 40 GB all-desktop Gigabit topology restored in Feature 3.4-R ([epic-3-refactor-hardware-and-state-consolidation.md](epic-3-refactor-hardware-and-state-consolidation.md)).
  * Verified `knative-operator` (2/2 pods), `knative-serving` `v1.14.0` (7/7 pods, `READY: True`), Kourier VIP `10.10.10.17`, and `ingress-nginx` VIP `10.10.10.18` reconciled cleanly via ArgoCD.
  * Tightened `CiliumLoadBalancerIPPool/homelab-lb-pool` (`infrastructure/networking/cilium-lb-ipam.yaml`) from `10.10.10.20/28` (`10.10.10.16–10.10.10.31`) to explicit bounds `10.10.10.17–10.10.10.25` (`IPsTotal: 9`, `IPsUsed: 2`, `PoolConflict: False`), eliminating the `.30–.31` overlap with the ER605 VLAN 10 DHCP pool (`10.10.10.30–10.10.10.99`).

* **Bootstrap KPA Race Diagnosis & Scale-to-Zero Verification (DoD #2):**
  * *Discovery:* Initial Revision `helloworld-go-00001` (created 30s after cluster bootstrap during Feature 3.4-R) remained stuck in `Unknown / RevisionMissing` with an empty `PodAutoscaler` status because it raced the Knative defaulting webhook and lacked `autoscaling.knative.dev/class: kpa.autoscaling.knative.dev`.
  * *Declarative Fix:* Updated `infrastructure/serverless/knative/test-service/test-ksvc.yaml` to explicitly bind `autoscaling.knative.dev/class: "kpa.autoscaling.knative.dev"` and enforce a hardened container `securityContext` (`runAsNonRoot: true`, `runAsUser: 1000`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`).
  * *Empirical Verification:* ArgoCD reconciled `helloworld-go-00002` (`READY: True`, `knative-test-service: Synced / Healthy`). Confirmed idle state at `0` pods; `curl -i -H "Host: helloworld-go.default.kester.lab" http://10.10.10.17` triggered an `896 ms` cold start returning `HTTP/1.1 200 OK` (`Hello ORSA Homelab!`), scaled to `2/2 Running`, and scaled back to `0` pods after the retention window.

* **Event-Driven Service Routing & Argo Workflows Integration (DoD #3):**
  * Added declarative `WorkflowTemplate/knative-event-trigger` (`infrastructure/bootstrap/argo-workflows/knative-trigger-workflow-template.yaml`) registered in `infrastructure/bootstrap/argo-workflows/kustomization.yaml`. Uses `curlimages/curl:8.11.1` with `/bin/sh -eu -c` and `curl -fsS --max-time 30` to invoke `http://helloworld-go.default.svc.cluster.local` over cluster-internal CoreDNS.
  * *Empirical Verification:* Submitted `knative-event-trigger-45djl` via Argo Workflows UI while `helloworld-go` was at `0` pods. Within 1 second, Knative Activator scaled `helloworld-go-00002` from `0` to `2/2 Running`, returned `Hello ORSA Homelab!` (`HTTP_STATUS:200`), completed `Succeeded`, and scaled back to `0` pods.

* **Documentation & Drift Reconciliation:**
  * Reconciled [08-serverless-execution.md](../architecture/08-serverless-execution.md), [0009-serverless-knative-ingress.md](../adr/0009-serverless-knative-ingress.md), and [infrastructure/networking/README.md](../../infrastructure/networking/README.md) with post-3.4-R hardware capacity, Cilium LB-IPAM allocations (`.17` Kourier, `.18` NGINX), and verified Feature 3.5 architecture.
