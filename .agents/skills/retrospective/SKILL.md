---
name: retrospective
description: Conduct feature closeout Agile ceremonies, verify GitOps state parity, audit documentation for drift, generate a collaboration-focused retrospective table for docs/Retrospective.csv, and update .agents rules and skills from approved action items.
---

# Feature Retrospective

Objective: Formally conclude the feature lifecycle, eliminate documentation drift, enforce GitOps state parity, improve human–agent collaboration effectiveness via Agile Retrospective, and codify approved process improvements into `.agents/` before transitioning to the next roadmap item.

## Execution Steps

### 1. GitOps State Verification
- Verify with the user that all configurations have been committed to the GitLab repository and successfully synchronized via ArgoCD. Confirm no manual/imperative state remains on the cluster.

### 2. Documentation & Architectural Parity Audit
Perform a systematic audit of all historical architecture artifacts and documentation to eliminate technical debt and drift resulting from the completed sprint:
- **ADR Review & Reconciliation (`docs/adr/`):** Audit all existing Architectural Decision Records against the newly deployed cluster state. Identify and update any ADRs superseded, modified, or contradicted by current configurations (e.g., VIP mechanics, IPAM ranges, storage replication, routing). Update `docs/adr/README.md` index.
- **Architecture Blueprints (`docs/architecture/`):** Verify that logical blueprints, Mermaid diagrams, and component tier definitions in `/docs/architecture/` remain strictly aligned with the live datapath and deployment topology.
- **Living System Manual & Schemas:** Reconcile IP allocations, hardware maps, and port assignments in `/docs/README.md` and relevant `/infrastructure/*/README.md` files.
- **Cluster Access Runbook (`docs/runbooks/cluster-access.md`):** Record all verified UI/API access endpoints, Ingress routes, and port-forward commands introduced or modified during the feature.
- **Roadmap Closure Check (`docs/HomeLab_Project_Roadmap.csv`):** Confirm the completed feature is ready to be marked `Done` and that any deferred technical debt discovered during execution is explicitly logged as a future Feature or Epic. When confirmed, mark the feature as `Done` on both the `docs/HomeLab_Project_Roadmap.csv` and the `/README.md` file.
- **Dedicated Documentation Commit:** Draft, review, and commit all required documentation updates under a clean, dedicated `docs: (<scope>) <summary>` Git commit before recording retrospective metrics.

### 3. Contextual Agile Analysis (Collaboration Imperative)
> [!IMPORTANT]
> **Focus Strictly on How We Work:** The retrospective MUST focus on **how the human and agent worked together**—making future interactions, handoffs, and workflows more effective. Do **NOT** list "good technical actions," recap completed engineering tasks, or log purely architectural decisions unless they directly exposed a collaboration, communication, or workflow gap.

Analyze the execution transcript for the completed feature across three dimensions:
1. **Human–Agent Collaboration & Team Dynamics:** How we communicated, challenged assumptions, passed terminal/repo context, and converged on decisions.
2. **Workflow Friction:** Process gaps, misaligned assumptions, prompt/output ergonomics (e.g., command formatting, scrollback clipping, pre-flight blind spots), or inefficiencies in execution loops.
3. **Process & Future Implications:** Recurring friction patterns, technical debt that constrains upcoming human–agent workflows, or guardrails needed to prevent repeat rework.

### 4. Retrospective Generation
- Generate a minimum of three (3) **Sustains** (repeatable human–agent collaboration practices, communication loops, or workflow habits to preserve).
- Generate a minimum of three (3) **Improves** (communication breakdowns, process frictions, or tooling/prompting gaps to eliminate).
- Format the output strictly as a table matching the exact schema of `docs/Retrospective.csv`:

`Feature Number | Feature Name | Type | Title | Discussion | Action`

(Where `Type` is `Sustain` or `Improve`.)

### 5. Iteration & Consensus (Wait State)
- Present the retrospective table.
- Halt execution. Await user critique, additions, or modifications.
- Iterate on the retrospective data points until the user provides explicit final approval for commit.

### 6. `.agents/` Instructions Continuous Improvement Audit
- Once the retrospective table is approved, review all active instructions in `.agents/rules/` and `.agents/skills/` against the approved `Action` items.
- Identify any rules or skills that should be updated, tightened, or added so that approved improvements are permanently codified in the agent's operating instructions rather than left passive in `docs/Retrospective.csv`.
- Present proposed `.agents/` diffs to the user for approval before committing the governance closeout.

### 7. Human–AI Interaction Summary (Optional Closeout Artifact)
- Invoke the `interaction-summary` skill to generate a sanitized, high-signal summary of the feature's human–agent collaboration under `docs/logs/interactions/feature_<#-#>_<slug>.md`.
- Verify the Zero-Token-in-Git Sanitization Gate before committing.
- Present this for review and validation.
