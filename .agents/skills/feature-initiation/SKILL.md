---
name: feature-initiation
description: Establish operational context, audit roadmap and retrospective state, run upstream supply-chain and version-skew checks, and generate a phased, GitOps-aligned implementation plan before starting work on a new feature.
---

# Feature Initiation

Objective: Establish operational context, verify alignment with GitOps and Agile principles, and define a deterministic execution path before generating infrastructure configurations.

## Execution Steps

### 1. State Retrieval & Audit-Before-Write (ABW)
- Parse `docs/HomeLab_Project_Roadmap.csv` to identify the specific Feature designated as `In-progress`. Extract its Definition of Done (DoD) and architectural goals.
- Review `docs/Retrospective.csv` to extract relevant lessons learned, technical debt warnings, and best practices from previous iterations.
- Query the repository `git log` and recent codebase changes to establish the current declarative state and ensure no configuration drift exists before proceeding.

### 2. Hardware, Firmware & Upstream Supply-Chain Pre-Flight Audit
- **Hardware & Firmware Guardrails:** If the Feature involves networking (e.g., ER605, Orbi), storage (Longhorn provisioning), or bare-metal host modifications (Talos machine configs), explicitly request current hardware firmware versions and node resource states from the user to preempt vendor-specific constraints.
- **Upstream Supply-Chain & Version-Skew Audit:** Before selecting Helm charts, operators, or container images, perform live upstream verification (Search-Before-Write) to confirm:
  - Active FOSS licensing and public container registry availability (preventing supply-chain or registry-deprecation deadlocks).
  - Exact API, CRD, and Helm `values.yaml` schema compatibility with the live Kubernetes version (e.g., `v1.36.1`) and current ArgoCD version.

### 3. Phased Action Plan Generation
- Deconstruct the Feature into a sequential, phased action plan.
- Map every phase directly to a specific DoD criterion from the roadmap.
- Record the phased plan in `./docs/implementation plans/` with the format: `feature_#-#_implementation_plan.md`.
- **Upfront Cross-Layer Flow:** When introducing cross-layer integrations (e.g., DNS → Cilium LB IPAM → Ingress → TLS → Service), include a concise end-to-end datapath/control-flow summary before Phase 1.
- **Structured Rationale Standard:** Every proposed component or change in the plan MUST include explicit **"What it does"** and **"Why it is needed"** subsections.
- Detail the specific GitOps, native ArgoCD Helm, or YAML configurations required for each phase, strictly adhering to immutable, declarative FOSS patterns and Zero-Token-in-Git.
- **Declarative Validation Planning:** Plan ephemeral smoke/integration tests as temporary declarative ArgoCD `Application` manifests (`sync-wave: "3"` or higher, `prune: true`) rather than imperative test pods or jobs.

### 4. Mandatory Validation Block
- Conclude each phase in the action plan with a defined validation step.
- Provide the exact deterministic read-only commands (`kubectl`, `talosctl`, `cilium status`, `curl`) required to prove the DoD criterion is met, with each command in its own separate markdown code block and scoped to prevent terminal scrollback clipping.

### 5. Gate Check
- Halt execution. Present the action plan and require explicit user approval before writing manifests or executing the first phase.
