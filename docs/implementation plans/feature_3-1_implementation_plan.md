# Feature 3.1 DoD Item 4 Implementation Plan (Updated): GitLab CI Integration, In-Cluster Runner & AWS Step Functions Parity

This updated implementation plan covers the expanded scope for **Phase 3 of the Epic 3 Action Plan** for **Feature 3.1 (GitOps & Workflow Orchestration)**.

---

## Agile Scope Discovery & Justification

During initial testing of DoD Item 4, runtime validation revealed an architectural constraint:
* **The Constraint:** Public cloud-hosted GitLab SaaS shared runners (`*.saas-linux-small-amd64.runners-manager.gitlab.com`) cannot route to private RFC 1918 IP addresses (`10.10.10.10`) inside the homelab's VLAN 10 enclave over the public internet.
* **The Solution (Option A):** Deploy an **in-cluster `gitlab-runner` agent** in namespace `gitlab-runner` via GitOps (ArgoCD). The local runner connects *outbound* over HTTPS to `gitlab.com` to poll for jobs. When pipeline events occur, the job executes *locally inside VLAN 10*, enabling the runner to directly issue cURL POST commands to `https://10.10.10.10:2746` without exposing any inbound ports on the WAN router.

---

## Retrospective Action Item Logging

> [!TIP]
> **Process Retrospective Item**: Formally document the requirement to retain the **"What it does"** and **"Why it is needed"** structured format across all future Implementation Plan "Proposed Changes" sections. This will be added to the Retrospective log upon completion of Feature 3.1.

---

## Architectural Parity & Execution Flow

```
+-----------------------------------------------------------------------------------+
|                            AWS CLOUD PATTERN                                      |
|                                                                                   |
|  GitLab CI / CodePipeline  --[ API: StartExecution ]-->  AWS Step Functions       |
|  (Lightweight Trigger)                                   (State Machine / ASL)    |
|                                                               |                   |
|                                                     +---------+---------+         |
|                                                     |                   |         |
|                                                Lambda Step 1       Lambda Step 2  |
+-----------------------------------------------------------------------------------+
                                       ||
                                  PARITY MIRROR
                                       ||
+-----------------------------------------------------------------------------------+
|                   BARE-METAL KUBERNETES ENCLAVE PATTERN                           |
|                                                                                   |
|  GitLab.com Event  ==[Outbound Poll]==>  Local GitLab Runner  (VLAN 10 Pod)      |
|                                                │                                  |
|                                                ▼ [Local REST API: submit]         |
|                                          Argo Workflows Server (10.10.10.10:2746) |
|                                                │                                  |
|                                     +----------+----------+                       |
|                                     |                     |                       |
|                                K8s Pod Task A        K8s Pod Task B               |
+-----------------------------------------------------------------------------------+
```

---

## Audit of Reviewed Files (ABW Protocol)

The following repository files were reviewed for architectural consistency before updating this plan:
1. [HomeLab_Project_Roadmap.csv](file:///home/neil/Documents/Projects/homelab/docs/HomeLab_Project_Roadmap.csv) (Verified status of Epic 3 and Feature 3.1 as `In Progress`)
2. [Action Plan.txt](file:///home/neil/Documents/Projects/homelab/docs/Action Plan.txt) (Verified Phase 3 scope for Feature 3.1)
3. [.gitlab-ci.yml](file:///home/neil/Documents/Projects/homelab/.gitlab-ci.yml) (Inspected GitLab CI orchestration stage and runner tags)
4. [root-app.yaml](file:///home/neil/Documents/Projects/homelab/argocd/root-app.yaml) (Inspected App-of-Apps root application)
5. [argo-workflows.yaml](file:///home/neil/Documents/Projects/homelab/argocd/apps/argo-workflows.yaml) (Inspected argo-workflows ArgoCD application)
6. [kustomization.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/argo-workflows/kustomization.yaml) (Inspected Kustomize manifest index)
7. [gitlab-runner-rbac.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/argo-workflows/gitlab-runner-rbac.yaml) (Inspected RBAC ServiceAccount and Secret)
8. [dag-workflow-template.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/argo-workflows/dag-workflow-template.yaml) (Inspected DAG WorkflowTemplate manifest)
9. [README.md](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/README.md) (Inspected root infrastructure bootstrap architecture manual)

---

## Proposed Changes

---

### ArgoCD App-of-Apps Layer (`/argocd/apps`)

#### [NEW] [gitlab-runner.yaml](file:///home/neil/Documents/Projects/homelab/argocd/apps/gitlab-runner.yaml)
* **What it does:** Registers the `gitlab-runner` ArgoCD `Application` resource under `namespace: argocd`, targeting path `infrastructure/bootstrap/gitlab-runner`.
* **Why it is needed:** Ensures that the in-cluster GitLab Runner infrastructure is declaratively managed, deployed, and reconciled by ArgoCD alongside `argo-workflows`.

---

### Infrastructure Layer (`/infrastructure/bootstrap/gitlab-runner`)

#### [NEW] [gitlab-runner-deployment.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/gitlab-runner/gitlab-runner-deployment.yaml)
* **What it does:** Defines the Kubernetes `Namespace`, `ServiceAccount`, `ConfigMap`, and `Deployment` running the official `gitlab/gitlab-runner` container agent.
* **Why it is needed:** Provisions the execution agent inside VLAN 10 that polls `gitlab.com` for pending jobs and executes cURL triggers against the internal `10.10.10.10` VIP over local network interfaces.

#### [NEW] [kustomization.yaml](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/gitlab-runner/kustomization.yaml)
* **What it does:** Indexes all manifests in `infrastructure/bootstrap/gitlab-runner/`.
* **Why it is needed:** Enables declarative Kustomize reconciliation for ArgoCD.

---

### System Documentation Updates (`/infrastructure/bootstrap` & Subdirectories)

#### [MODIFY] [README.md](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/README.md)
* **What it does:** Updates the core infrastructure bootstrap manual and architecture diagrams to detail the in-cluster `gitlab-runner` deployment layer.
* **Why it is needed:** Maintains complete platform documentation accuracy for system operators, explaining how local runners interact with Tier 1 (GitLab) and Tier 3 (Argo Workflows).

#### [NEW] [README.md](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/gitlab-runner/README.md)
* **What it does:** Documents the runner registration token provisioning process, runner tags (`homelab-runner`), security policies, and operational architecture for `gitlab-runner`.
* **Why it is needed:** Provides an authoritative functional manual for managing and troubleshooting the in-cluster runner enclave agent.

#### [MODIFY] [README.md](file:///home/neil/Documents/Projects/homelab/infrastructure/bootstrap/argo-workflows/README.md)
* **What it does:** Updates the execution flow section to explicitly show how local `gitlab-runner` pods perform L2/L3 REST API calls to the Argo Workflows server endpoint.
* **Why it is needed:** Reflects the actual network topology for AWS Step Functions parity execution.

---

### Root Pipeline Configuration

#### [MODIFY] [.gitlab-ci.yml](file:///home/neil/Documents/Projects/homelab/.gitlab-ci.yml)
* **What it does:** Adds `tags: [homelab-runner]` to the `trigger-argo-dag-workflow` job.
* **Why it is needed:** Directs GitLab CI to route the `orchestrate` pipeline stage exclusively to the in-cluster local runner running inside VLAN 10, preventing SaaS runners from attempting to hit private IP addresses.

---

## Verification Plan

### Automated & CLI Verification
1. **ArgoCD Application Sync Verification**:
   Verify that ArgoCD deploys both `argo-workflows` and `gitlab-runner` applications cleanly:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n gitlab-runner
   ```
2. **GitLab Runner Registration Status**:
   Verify that the in-cluster runner pod registers successfully with GitLab:
   ```bash
   kubectl logs -n gitlab-runner -l app=gitlab-runner --tail=50
   ```
3. **End-to-End Pipeline Verification**:
   Push a commit to `argocd-deploy`. Observe the GitLab CI pipeline:
   - Job `trigger-argo-dag-workflow` is picked up by `homelab-runner`.
   - The cURL POST payload successfully reaches `https://10.10.10.10:2746/api/v1/workflows/argo-workflows/submit`.
   - Argo Workflows executes `dag-workflow` pods (`task-a` -> `task-b` & `task-c` -> `task-d`) to completion.
   ```bash
   kubectl get workflows -n argo-workflows
   kubectl get pods -n argo-workflows -l argo-workflows.argoproj.io/workflow
   ```

### Manual Verification
- Confirm in GitLab Settings $\rightarrow$ CI/CD $\rightarrow$ Runners that `homelab-runner` appears as an active, online project runner.
- Audit documentation links across `/infrastructure/bootstrap/README.md`, `/infrastructure/bootstrap/gitlab-runner/README.md`, and `/infrastructure/bootstrap/argo-workflows/README.md`.

## Conclusion / Summary (Gemini Final Walkthrough artifact)

This walkthrough documents the successful closeout of **Feature 3.1 (GitOps & Workflow Orchestration)** across all 5 Definition of Done (DoD) success criteria.

---

### Final End-to-End Execution Trace (DoD 4 - AWS Step Functions Parity)

```text
$ curl -k -f -X POST "${ARGO_SERVER_URL}/api/v1/workflows/${ARGO_NAMESPACE}/submit" \
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2341    0  2071  100   270  39862   5197 --:--:-- --:--:-- --:--:-- 45901
{
  "metadata": {
    "name": "dag-workflow-xtpnf",
    "generateName": "dag-workflow-",
    "namespace": "argo-workflows",
    "uid": "53ee4eef-f378-4d13-abf5-b996c811f7b6",
    "resourceVersion": "2405786",
    "creationTimestamp": "2026-08-11T21:00:26Z",
    "labels": {
      "workflows.argoproj.io/creator": "system-serviceaccount-argo-workflows-gitlab-ci-runner",
      "workflows.argoproj.io/workflow-template": "dag-workflow"
    }
  },
  "spec": {
    "arguments": {
      "parameters": [
        { "name": "commit_sha", "value": "f24ee533fc27043c48739fbff4a813ff75509842" },
        { "name": "branch", "value": "argocd-deploy" }
      ]
    },
    "workflowTemplateRef": { "name": "dag-workflow" }
  }
}
Cleaning up project directory and file based variables
Job succeeded
```

---

### Feature 3.1 Definition of Done (DoD) Audit

| # | Definition of Done Success Criteria | Status | Empirical Validation Evidence |
| :-: | :--- | :-: | :--- |
| **1** | ArgoCD UI reachable | **DONE** ✅ | Exposed via NGINX/VIP; synced `root-app`, `argo-workflows`, and `gitlab-runner` applications cleanly. |
| **2** | Argo Workflows controller active on the cluster | **DONE** ✅ | Controller running in `argo-workflows` namespace scheduling ephemeral DAG pods across cluster worker nodes. |
| **3** | Event-driven DAG capability verified | **DONE** ✅ | `dag-workflow` template executed 4-task graph (`task-a` -> `task-b` & `task-c` -> `task-d`) with parameter injection. |
| **4** | Integration established with GitLab CI to mirror AWS Step Functions | **DONE** ✅ | In-cluster `homelab-runner` executed `.gitlab-ci.yml` pipeline, authenticated via RBAC token, and instantiated workflow `dag-workflow-xtpnf`. |
| **5** | App-of-apps pattern syncs without errors | **DONE** ✅ | `root-app.yaml` managing all application manifests under `/argocd/apps` in `Healthy / Synced` state. |

---

### Retrospective Action Items to Log (`docs/Retrospective.csv`)

1. **Implementation Plan Format Rule:** Retain the **"What it does"** and **"Why it is needed"** structured format across all future Implementation Plan "Proposed Changes" sections.
2. **Hybrid Cloud CI Pattern for Private Enclaves:** SaaS shared runners cannot hit RFC 1918 IPs. Deploying an in-cluster `gitlab-runner` with `tags: [homelab-runner]` offloads 100% of compute tasks from the 400-minute SaaS limit while enabling secure, unexposed local REST API orchestration.

