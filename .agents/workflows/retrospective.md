---
description: Conduct close up agile ceremonies for a feature
---

Objective: Formally conclude the feature lifecycle, eliminate documentation drift, enforce GitOps state parity, and capture continuous improvement metrics via Agile Retrospective prior to transitioning to the next roadmap item.

Execution Steps:

1. GitOps State Verification:

Verify with the user that all configurations have been committed to the GitLab repository and successfully synchronized via ArgoCD. Confirm no manual/imperative state remains on the cluster.

2. Documentation & Architectural Parity Audit:

Perform a systematic audit of all historical architecture artifacts and documentation to eliminate technical debt and drift resulting from the completed sprint:
* **ADR Review & Reconciliation (`docs/adr/`):** Audit all existing Architectural Decision Records against the newly deployed cluster state. Identify and update any ADRs superseded, modified, or contradicted by current configurations (e.g., VIP mechanics, IPAM ranges, storage replication, routing). Update `docs/adr/README.md` index.
* **Architecture Blueprints (`docs/architecture/`):** Verify that logical blueprints, Mermaid diagrams, and component tier definitions in `/docs/architecture/` remain strictly aligned with the live datapath and deployment topology.
* **Living System Manual & Schemas:** Reconcile IP allocations, hardware maps, and port assignments in `/docs/README.md` and `/infrastructure/networking/README.md`.
* **Dedicated Documentation Commit:** Draft, review, and commit all required documentation updates under a clean, dedicated `docs: (...) <commit message>` Git commit before recording retrospective metrics.

3. Contextual Agile Analysis:

Analyze the execution transcript for the completed feature. Focus exclusively on:
1. Team dynamics: How we communicated, collaborated, and passed state/context between user and agent.
2. Workflow friction: Process gaps, misaligned assumptions, or inefficiencies in how we executed tasks.
3. Future implications: Technical debt incurred, tasks blocked, or how decisions made today will impact tomorrow's roadmap items. Do NOT include purely historical architectural decisions unless they directly impact future work.

4. Retrospective Generation:

Generate a minimum of three (3) "Sustains" (successful collaboration practices, efficient communication loops, or process wins to maintain).

Generate a minimum of three (3) "Improves" (team communication breakdowns, process frictions, technical debt to resolve, or future tasks blocked).

Format the output strictly as a table ready for inclusion in docs/Retrospective.csv.

Table Schema: Feature/Epic Number | Feature Name | Type (Sustain/Improve) | Title | Discussion | Action Item

5. Iteration & Consensus (Wait State):

Present the retrospective table.

Halt execution. Await user critique, additions, or modifications.

Iterate on the retrospective data points until the user provides explicit final approval for commit.