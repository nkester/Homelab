# Feature 3.5: Serverless Execution (Knative) — Re-Baselined Implementation Plan

Introduce and validate **Knative Serving** to deliver scale-to-zero Function-as-a-Service (FaaS) capability mirroring AWS Lambda, re-baselined against the post-Feature 3.4-R hardware consolidation and GitOps restoration state.

---

## 1. State Retrieval & Audit-Before-Write (ABW)

### Roadmap Alignment (`docs/HomeLab_Project_Roadmap.csv`)
* **Parent Epic:** Epic 3 (`GitOps & Analytic Stack`) — `In Progress`
* **Preceding Feature:** Feature 3.4-R (`Plane 1 State & Hardware Consolidation Refactor`) — `Done`
* **Active Feature:** Feature 3.5 (`Serverless Execution (Knative)`) — `In Progress`
* **Definition of Done (DoD) Criteria:**
  1. Knative Serving layer active on cluster.
  2. "Scale-to-zero" functionality verified for analytic functions.
  3. Service routing configured for event-driven triggers.

### Existing Files Audited
* [docs/HomeLab_Project_Roadmap.csv](../HomeLab_Project_Roadmap.csv)
* [docs/Retrospective.csv](../Retrospective.csv) (specifically Feature 3.4-R, 3.4, 3.3, 3.2, and 3.1 entries)
* [docs/hardware_inventory.csv](../hardware_inventory.csv)
* [docs/logs/epic-3-refactor-hardware-and-state-consolidation.md](../logs/epic-3-refactor-hardware-and-state-consolidation.md)
* [docs/architecture/01-physical-network.md](../architecture/01-physical-network.md) & [docs/architecture/08-serverless-execution.md](../architecture/08-serverless-execution.md)
* [docs/adr/0009-serverless-knative-ingress.md](../adr/0009-serverless-knative-ingress.md)
* [argocd/apps/cilium-lb-ipam.yaml](../../argocd/apps/cilium-lb-ipam.yaml), [argocd/apps/ingress-nginx.yaml](../../argocd/apps/ingress-nginx.yaml), [argocd/apps/knative-operator.yaml](../../argocd/apps/knative-operator.yaml), [argocd/apps/knative-serving.yaml](../../argocd/apps/knative-serving.yaml), [argocd/apps/knative-test-service.yaml](../../argocd/apps/knative-test-service.yaml)
* [infrastructure/networking/cilium-lb-ipam.yaml](../../infrastructure/networking/cilium-lb-ipam.yaml)
* [infrastructure/serverless/knative/operator/kustomization.yaml](../../infrastructure/serverless/knative/operator/kustomization.yaml), [infrastructure/serverless/knative/serving/knative-serving-cr.yaml](../../infrastructure/serverless/knative/serving/knative-serving-cr.yaml), [infrastructure/serverless/knative/test-service/test-ksvc.yaml](../../infrastructure/serverless/knative/test-service/test-ksvc.yaml)
* [infrastructure/bootstrap/argo-workflows/dag-workflow-template.yaml](../../infrastructure/bootstrap/argo-workflows/dag-workflow-template.yaml)

### Post-Feature 3.4-R Baseline Delta
During Feature 3.4-R Phase 4, the ArgoCD App-of-Apps reconciliation loop (`argocd/root-app.yaml` tracking `argocd-deploy`) declaratively restored the foundational Feature 3.5 manifests across Waves 0–3:

| Sync Wave | ArgoCD Application | Namespace | Current Declarative State | Status Post-3.4-R |
| :--- | :--- | :--- | :--- | :--- |
| **Wave 0** | `cilium-lb-ipam` | `kube-system` | `CiliumLoadBalancerIPPool` (`10.10.10.20/28`) + `CiliumL2AnnouncementPolicy` | Reconciled; allocated `.17` (Kourier) & `.18` (NGINX) |
| **Wave 1** | `ingress-nginx` | `ingress-nginx` | Official Helm chart `v4.10.1` | Reconciled; VIP `10.10.10.18` |
| **Wave 1** | `knative-operator` | `knative-operator` | Upstream `knative-v1.14.0/operator.yaml` via Kustomize | Reconciled |
| **Wave 2** | `knative-serving` | `knative-serving` | `KnativeServing` CR (`kourier` enabled, domain `kester.lab`) | Reconciled; Kourier VIP `10.10.10.17` |
| **Wave 3** | `knative-test-service` | `default` | `Service/helloworld-go` (`scale-to-zero-pod-retention-period: 15s`, `window: 15s`) | Committed in Git; empirical scale-to-zero & routing unverified |

### Identified Configuration & Documentation Drift
1. **Obsolete Hardware/Memory Warnings:** The prior plan, [08-serverless-execution.md](../architecture/08-serverless-execution.md), and [ADR-0009](../adr/0009-serverless-knative-ingress.md) still reference `worker-1` having `~3.8 GB` RAM and `kube-vip` assigning Kourier's LoadBalancer IP. Post-3.4-R, the cluster has **40 GB total RAM** (`controlplane-1`: 20 GB, `worker-1`: 12 GB, `worker-2`: 8 GB) on **1000BASE-T Gigabit Ethernet**, and **Cilium eBPF LB-IPAM** exclusively manages service LoadBalancer VIPs.
2. **LB-IPAM vs. ER605 DHCP Pool Overlap:** [infrastructure/networking/cilium-lb-ipam.yaml](../../infrastructure/networking/cilium-lb-ipam.yaml) specifies `cidr: "10.10.10.20/28"` (`10.10.10.16–10.10.10.31`), which overlaps `.30–.31` with the ER605 VLAN 10 DHCP pool (`10.10.10.30–10.10.10.99`) configured in Feature 3.4-R Phase 2. Additionally, [ADR-0009](../adr/0009-serverless-knative-ingress.md) still lists obsolete `.101` / `.102–.120` addresses.
3. **DoD #3 Gap (Event-Driven Routing):** No declarative event-driven trigger path (e.g., Argo Workflows invoking a scaled-to-zero Knative Service over internal DNS) has been authored or empirically validated.

### Retrospective Lessons Applied
* **Hardware & Datapath Consolidation (3.4-R Sustain):** Leverage the expanded 40 GB RAM / 1000BASE-T topology; remove obsolete low-memory workarounds.
* **Pure GitOps Reconciliation Loop (3.4-R Sustain):** All manifest adjustments (IPAM pool tightening, workflow templates, image pins) occur strictly via Git commits reconciled by ArgoCD—zero imperative `kubectl apply`/`edit`/`patch`.
* **Upstream Supply-Chain Due Diligence (3.4-R Improve):** Audit container registries for all Knative components and sample workloads before validation. Retain pinned `knative-v1.14.0` for Feature 3.5 stability (current upstream `v1.24` requires Kubernetes `>= v1.35`) to avoid multi-minor-version operator upgrade deadlocks.
* **Operator Upgrade Deadlock Anticipation (3.4-R Improve):** Do not trigger in-place Knative Operator major/minor upgrades mid-feature without auditing sequential minor-version CRD migration paths.
* **Bash Scripting Strictness (3.4 Improve):** Enforce `set -euo pipefail` in any container command executed by Argo Workflows trigger templates.
* **Command Execution Boundaries (3.3 & 3.4 Sustain):** All `kubectl`/`curl` validation commands are provided in markdown blocks for manual operator execution.

---

## 2. Architectural Decisions & Two-Option Trade-Offs

### Decision 1: Cilium LB-IPAM vs. ER605 DHCP Pool Boundary (`10.10.10.30–.31` Overlap)
* **Option A (Ideal — Recommended):** Modify `infrastructure/networking/cilium-lb-ipam.yaml` to use explicit `start: "10.10.10.17"` and `stop: "10.10.10.25"` bounds inside `CiliumLoadBalancerIPPool`. This enforces strict, non-overlapping IPAM parity with the ER605 DHCP pool (`10.10.10.30–10.10.10.99`) declaratively in Git without touching router firmware. Existing allocations (`.17` Kourier, `.18` NGINX) remain undisturbed.
* **Option B (High-Compatibility):** Retain `cidr: "10.10.10.20/28"` in Git and manually narrow the ER605 VLAN 10 DHCP pool to `10.10.10.32–10.10.10.99` via the ER605 web UI.

### Decision 2: Service Routing Strategy for Event-Driven Triggers (DoD #3)
* **Option A (Ideal — Recommended):** Retain `kester.lab` in `KnativeServing` (`config.domain`). Route **in-cluster event-driven triggers** (Argo Workflows DAGs, GitLab Runner jobs) over native Kubernetes/Knative cluster DNS (`http://<service>.<namespace>.svc.cluster.local`), and route **external VLAN 1/10 requests** via Kourier VIP `10.10.10.17` with `Host: <service>.<namespace>.kester.lab` (deferring wildcard DNS + TLS certificates to Epic 4 Feature 4.2 `cert-manager`).
* **Option B (High-Compatibility):** Switch `config.domain` to `10.10.10.17.sslip.io` (Magic DNS) to allow browser resolution without `Host:` headers or local `/etc/hosts` entries, at the cost of external DNS resolution dependency on `sslip.io` for internal enclave traffic.

---

## 3. Phased Action Plan (Mapped to DoD)

### Phase 1: Control Plane Verification, Supply-Chain Audit & IPAM Hardening
* **Maps to DoD #1:** *Knative Serving layer active on cluster.*
* **Proposed Changes:**
  * `[MODIFY]` [infrastructure/networking/cilium-lb-ipam.yaml](../../infrastructure/networking/cilium-lb-ipam.yaml) *(Pending Option A approval)*
    * **What it does:** Replaces `cidr: "10.10.10.20/28"` with explicit `start: "10.10.10.17"` and `stop: "10.10.10.25"` under `spec.blocks`.
    * **Why it is needed:** Eliminates the `.30–.31` overlap with the ER605 VLAN 10 DHCP pool (`10.10.10.30–10.10.10.99`) while preserving existing `.17` (Kourier) and `.18` (NGINX) VIPs.
* **Validation Block (Phase 1):**
  ```bash
  # 1. Verify ArgoCD application sync and health for networking and serverless waves
  kubectl get applications -n argocd cilium-lb-ipam ingress-nginx knative-operator knative-serving knative-test-service

  # 2. Verify Knative Operator and Serving control plane pods (zero ImagePullBackOff / CrashLoopBackOff)
  kubectl get pods -n knative-operator -o wide
  kubectl get pods -n knative-serving -o wide

  # 3. Verify KnativeServing CR readiness
  kubectl get knativeserving -n knative-serving

  # 4. Verify Kourier (10.10.10.17) and NGINX (10.10.10.18) LoadBalancer VIPs and IPAM pool status
  kubectl get svc -n knative-serving kourier
  kubectl get svc -n ingress-nginx ingress-nginx-controller
  kubectl get ciliumloadbalancerippool homelab-lb-pool -o yaml
  ```

---

### Phase 2: Scale-to-Zero & Cold-Start Empirical Verification
* **Maps to DoD #2:** *"Scale-to-zero" functionality verified for analytic functions.*
* **Proposed Changes:**
  * Audit live reconciliation of [infrastructure/serverless/knative/test-service/test-ksvc.yaml](../../infrastructure/serverless/knative/test-service/test-ksvc.yaml) (`helloworld-go`).
  * `[CONDITIONAL MODIFY]` [infrastructure/serverless/knative/test-service/test-ksvc.yaml](../../infrastructure/serverless/knative/test-service/test-ksvc.yaml) *(Only if `gcr.io/knative-samples/helloworld-go` fails image pull)*
    * **What it does:** Switches image reference from `gcr.io/knative-samples/helloworld-go` to `ghcr.io/knative/helloworld-go:latest`.
    * **Why it is needed:** Enforces supply-chain resilience if legacy `gcr.io` sample registry access degrades.
* **Validation Block (Phase 2):**
  ```bash
  # 1. Verify Knative Service (ksvc) is Ready and inspect assigned URL
  kubectl get ksvc -n default helloworld-go

  # 2. Confirm scale-to-zero after >15s idle window (must return: No resources found)
  kubectl get pods -n default -l serving.knative.dev/service=helloworld-go

  # 3. Trigger cold start via Kourier LoadBalancer VIP (10.10.10.17) with Host header
  curl -i -H "Host: helloworld-go.default.kester.lab" http://10.10.10.17
  # Expected: HTTP/1.1 200 OK | Body: "Hello ORSA Homelab!"

  # 4. Immediately verify dynamic pod instantiation (2/2 Running: user-container + queue-proxy)
  kubectl get pods -n default -l serving.knative.dev/service=helloworld-go -o wide

  # 5. Wait ~30s with no traffic and verify scale-back-to-zero
  kubectl get pods -n default -l serving.knative.dev/service=helloworld-go
  ```

---

### Phase 3: Event-Driven Service Routing & Analytic Trigger Integration
* **Maps to DoD #3:** *Service routing configured for event-driven triggers.*
* **Proposed Changes:**
  * `[NEW]` `infrastructure/bootstrap/argo-workflows/knative-trigger-workflow-template.yaml`
    * **What it does:** Declares an Argo `WorkflowTemplate` (`knative-event-trigger` in namespace `argo-workflows`) running a `curlimages/curl:8.11.1` step with `set -euo pipefail` that issues an HTTP request to `http://helloworld-go.default.svc.cluster.local`, capturing HTTP status and response payload.
    * **Why it is needed:** Proves end-to-end event-driven routing from the cluster's DAG orchestration layer (Feature 3.1 Argo Workflows) to a scaled-to-zero Knative Service over cluster-internal DNS, mirroring an AWS Step Functions -> AWS Lambda invocation.
  * `[MODIFY]` [infrastructure/bootstrap/argo-workflows/kustomization.yaml](../../infrastructure/bootstrap/argo-workflows/kustomization.yaml)
    * **What it does:** Registers `knative-trigger-workflow-template.yaml` under `resources:` so the existing `argo-workflows` ArgoCD `Application` reconciles it declaratively.
    * **Why it is needed:** Maintains strict GitOps exclusivity without creating redundant ArgoCD `Application` objects.
* **Validation Block (Phase 3):**
  ```bash
  # 1. Verify WorkflowTemplate reconciled by ArgoCD
  kubectl get workflowtemplate -n argo-workflows knative-event-trigger

  # 2. Confirm helloworld-go is scaled to 0 prior to event trigger
  kubectl get pods -n default -l serving.knative.dev/service=helloworld-go

  # 3. Trigger WorkflowTemplate via Argo Workflows UI or GitLab CI pipeline (homelab-runner),
  #    then inspect workflow completion and pod logs (read-only)
  kubectl get workflows -n argo-workflows --sort-by=.metadata.creationTimestamp
  kubectl logs -n argo-workflows -l workflows.argoproj.io/workflow=<WORKFLOW_NAME> -c main
  # Expected: HTTP 200 and "Hello ORSA Homelab!"

  # 4. Confirm Knative Activator scaled helloworld-go up to serve the workflow event
  kubectl get pods -n default -l serving.knative.dev/service=helloworld-go
  ```

---

### Phase 4: Documentation Re-Baselining & Feature Closure
* **Maps to Governance / ABW Closure:** Reconciles all Layer 2/3 documentation with post-3.4-R hardware and Feature 3.5 validated state.
* **Proposed Changes:**
  * `[MODIFY]` [docs/architecture/08-serverless-execution.md](../architecture/08-serverless-execution.md)
    * **What it does:** Replaces obsolete `worker-1` (`~3.8 GB` RAM) constraint and `kube-vip` reference with the post-3.4-R 40 GB Gigabit topology, Cilium eBPF LB-IPAM (`10.10.10.17`), `kester.lab` routing, and Argo Workflows event-driven trigger architecture.
    * **Why it is needed:** Eliminates architectural drift in Layer 2/3 documentation.
  * `[MODIFY]` [docs/adr/0009-serverless-knative-ingress.md](../adr/0009-serverless-knative-ingress.md)
    * **What it does:** Updates LB-IPAM pool and static IP references (`.101` / `.102–.120` -> `.17–.25` pool, Kourier `.17`, NGINX `.18`) and updates resource constraint consequences to reflect the 40 GB cluster.
    * **Why it is needed:** Maintains factual accuracy in the ADR record.
  * `[MODIFY]` [docs/logs/epic-3.md](../logs/epic-3.md)
    * **What it does:** Records Feature 3.5 implementation milestones and empirical DoD validation results upon completion.
    * **Why it is needed:** Completes chronological Epic 3 engineering log governance.
* **Validation Block (Phase 4):**
  ```bash
  # Verify clean git state and zero untracked drift before merging to Epic-3 & argocd-deploy
  git status
  git diff --stat
  ```

---

## 4. Gate Check (Pre-Execution Approval Required)

Execution is **halted** pending your review and explicit approval of:
1. **IPAM Overlap Resolution (Decision 1):** Approve **Option A** (tighten `CiliumLoadBalancerIPPool` to `10.10.10.17–10.10.10.25`) or **Option B** (narrow ER605 DHCP pool).
2. **Routing Strategy (Decision 2):** Approve **Option A** (`kester.lab` + internal `svc.cluster.local` for Argo Workflows triggers) or **Option B** (`10.10.10.17.sslip.io`).
3. **Hardware/Node Baseline Confirmation:** Confirm all 3 nodes (`controlplane-1`, `worker-1`, `worker-2`) remain healthy post-3.4-R and whether you are ready to proceed with **Phase 1**.
