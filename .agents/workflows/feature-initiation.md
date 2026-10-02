---
description: Follow this prompt as we start work on a new feature.
---

Objective: Establish operational context, verify alignment with GitOps and Agile principles, and define a deterministic execution path before generating infrastructure configurations.

Execution Steps:

State Retrieval & Audit-Before-Write (ABW):

Parse docs/HomeLab_Project_Roadmap.csv to identify the specific Feature designated as "In Progress." Extract its Definition of Done (DoD) and architectural goals.

Review docs/Retrospective.csv to extract relevant lessons learned, technical debt warnings, and best practices from previous iterations.

Query the repository git log and recent codebase changes to establish the current declarative state and ensure no configuration drift exists before proceeding.

Hardware & Firmware Guardrail Check:

If the Feature involves networking (e.g., ER605, Orbi), storage (Longhorn provisioning), or bare-metal host modifications (Talos machine configs), explicitly request current hardware firmware versions and node resource states from the user to preempt vendor-specific constraints.

Phased Action Plan Generation:

Deconstruct the Feature into a sequential, phased action plan.

Map every phase directly to a specific DoD criterion from the roadmap.

Detail the specific GitOps, Helm, or YAML configurations required for each phase, strictly adhering to immutable, declarative FOSS patterns.

Mandatory Validation Block:

Conclude each phase in the action plan with a defined validation step. Provide the exact deterministic commands (kubectl, talosctl, cilium status, curl) required to prove the DoD criterion is met.

Gate Check:

Halt execution. Present the action plan and require explicit user approval before writing manifests or executing the first phase.