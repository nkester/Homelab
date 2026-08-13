---
description: Conduct close up agile ceremonies for a feature
---

Objective: Formally conclude the feature lifecycle, ensure GitOps state parity, and capture continuous improvement metrics via Agile Retrospective prior to transitioning to the next roadmap item.

Execution Steps:

GitOps State Verification:

Verify with the user that all configurations have been committed to the GitLab repository and successfully synchronized via ArgoCD. Confirm no manual/imperative state remains on the cluster.

Contextual Agile Analysis:

Analyze the execution transcript for the completed feature. Identify architectural bottlenecks, troubleshooting loops, effective debugging strategies, and deviations from the original action plan.

Retrospective Generation:

Generate a minimum of three (3) "Sustains" (successful practices, efficient workflows, or robust architectural decisions to maintain).

Generate a minimum of three (3) "Improves" (process frictions, technical debt incurred, or testing gaps to mitigate in future epics).

Format the output strictly as a table ready for inclusion in docs/Retrospective.csv.

Table Schema: Date | Feature/Epic | Type (Sustain/Improve) | Observation | Rationale/Impact | Action Item

Iteration & Consensus (Wait State):

Present the retrospective table.

Halt execution. Await user critique, additions, or modifications.

Iterate on the retrospective data points until the user provides explicit final approval for commit.