# Feature 3.5: Serverless Execution (Knative)

Introduce Knative Serving to implement scale-to-zero FaaS capability, mirroring AWS Lambda functionality. This provides the event-driven compute layer for downstream analytics workloads.

## State Retrieval & Audit-Before-Write (ABW)

### Roadmap Alignment
- **Parent Epic:** Epic 3 (GitOps & Analytic Stack) — `In Progress`
- **Feature:** Feature 3.5 (Serverless Execution (Knative)) — `In Progress`
- **Definition of Done (DoD) Criteria:**
  1. Knative Serving layer active on cluster.
  2. "Scale-to-zero" functionality verified for analytic functions.
  3. Service routing configured for event-driven triggers.

### Retrospective Lessons Applied
- **Search-Before-Write Compliance:** Checked upstream Knative installation patterns. The upstream-supported method for GitOps/Helm is deploying the `Knative Operator` first, which then manages the `KnativeServing` CRD. 
- **Compute Constraint Tech Debt:** Verified node states. `worker-1` has severely constrained RAM (~3.7GB). We must ensure Knative controllers (Activator, Autoscaler, Webhooks) do not overwhelm this node.
- **Strict Validation:** Phased CLI validation commands will verify the scale-to-zero behavior empirically.

---

## User Review Required

> [!WARNING]
> **Resource Constraints on Worker-1**
> Based on your `kubectl top` output, `worker-1` only has ~3.8GB of total RAM. Knative Serving introduces several active controllers (Autoscaler, Activator, Controller, Webhooks). I recommend adding node selectors or tolerations in the future to keep heavy data workloads off `worker-1`, but for this deployment, we will proceed without hard constraints to ensure high availability.

## Architectural Decisions

> [!NOTE]
> **Ingress Architecture: Knative Kourier & NGINX**
> We have opted to deploy **Kourier** specifically for Knative Serving as it is the official, upstream-recommended, and most lightweight gateway for Knative (based on Envoy). Kourier will receive its own LoadBalancer IP via Kube-VIP.
> 
> Simultaneously, we are deploying the **NGINX Ingress Controller** in this feature to satisfy the technical debt from Feature 3.4. This provides a cluster-wide ingress for standard HTTP workloads (e.g., MinIO Console). While we are deploying NGINX without `cert-manager` at this stage, it will function normally on HTTP (Port 80) and utilize a self-signed certificate for HTTPS (Port 443) until `cert-manager` is introduced in Epic 4.

---

## Proposed Changes

### Documentation (Architectural & Decision Logs)

#### [NEW] [0009-serverless-knative-ingress.md](/docs/adr/0009-serverless-knative-ingress.md)
- **What it does:** Documents the decision between using Kourier vs NGINX for Knative Serving, and the deployment of the Knative Operator.
- **Why it is needed:** Fulfills ADR governance requirements for structural routing decisions.

#### [NEW] [08-serverless-execution.md](/docs/architecture/08-serverless-execution.md)
- **What it does:** Details the logical architecture of Knative Serving, the scale-to-zero lifecycle (Autoscaler & Activator), and internal DNS routing (`config-domain`).
- **Why it is needed:** Fulfills Layer 2 system documentation requirements.

#### [MODIFY] [README.md](/docs/architecture/README.md)
- **What it does:** Registers `08-serverless-execution.md` in the Architecture Documentation Index table.
- **Why it is needed:** Maintains complete indexing.

---

### ArgoCD Manifests (`argocd/apps/`)

#### [NEW] [ingress-nginx.yaml](/argocd/apps/ingress-nginx.yaml)
- **What it does:** Deploys the official `ingress-nginx` Helm chart to the `ingress-nginx` namespace. Annotated with `sync-wave: "1"`.
- **Why it is needed:** Pays off the tech debt from Feature 3.4 and provides a cluster-wide ingress for standard web workloads (like ArgoCD UI, MinIO console).

#### [NEW] [knative-operator.yaml](/argocd/apps/knative-operator.yaml)
- **What it does:** Deploys the official Knative Operator Helm chart. Annotated with `sync-wave: "1"`.
- **Why it is needed:** The operator manages the CRDs and lifecycle of the Knative Serving components securely.

#### [NEW] [knative-serving.yaml](/argocd/apps/knative-serving.yaml)
- **What it does:** Deploys the `KnativeServing` custom resource via GitOps tracking our `infrastructure/serverless/knative` directory. Annotated with `sync-wave: "2"`.
- **Why it is needed:** Satisfies DoD #1.

---

### Infrastructure Configurations (`infrastructure/serverless/knative/` & `infrastructure/ingress/`)

#### [NEW] [knative-serving-cr.yaml](/infrastructure/serverless/knative/knative-serving-cr.yaml)
- **What it does:** Defines the `KnativeServing` Custom Resource, instructing the Operator to install Serving components with the selected Ingress (Kourier or NGINX).
- **Why it is needed:** Triggers the actual installation of the serverless control plane.

#### [NEW] [test-ksvc.yaml](/infrastructure/serverless/knative/test-ksvc.yaml)
- **What it does:** A simple `hello-world` Knative Service (`ksvc`) used strictly for validation.
- **Why it is needed:** Satisfies DoD #2 (Scale-to-zero functionality verified).

---

## Verification Plan

### Phase 1: Ingress & Operator Deployment
- Verify NGINX Ingress Controller gets a LoadBalancer IP.
- Verify Knative Operator pods are `Running`.

### Phase 2: Knative Serving & DNS Configuration
- Verify `knative-serving` pods (Activator, Autoscaler, Controller, Webhooks) are `Running`.
- Verify the Knative gateway (Kourier/NGINX) receives a LoadBalancer IP.

### Phase 3: Scale-to-Zero Empirical Verification
- Deploy `test-ksvc.yaml`.
- Wait 60 seconds (default `scale-to-zero` grace period).
- **Validation Command:** `kubectl get pods -n default -l serving.knative.dev/service=hello` (Must show 0 pods).
- **Cold Start Validation:** `curl` the service endpoint and verify a pod spins up dynamically to serve the request.
