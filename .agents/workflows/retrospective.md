---
description: Conduct close up agile ceremonies for a feature
---

Objective: Formally conclude the feature lifecycle, ensure GitOps state parity, and capture continuous improvement metrics via Agile Retrospective prior to transitioning to the next roadmap item.

Execution Steps:

GitOps State Verification:

Verify with the user that all configurations have been committed to the GitLab repository and successfully synchronized via ArgoCD. Confirm no manual/imperative state remains on the cluster.

Contextual Agile Analysis:

Analyze the execution transcript for the completed feature. Focus exclusively on:
1. Team dynamics: How we communicated, collaborated, and passed state/context between user and agent.
2. Workflow friction: Process gaps, misaligned assumptions, or inefficiencies in how we executed tasks.
3. Future implications: Technical debt incurred, tasks blocked, or how decisions made today will impact tomorrow's roadmap items. Do NOT include purely historical architectural decisions unless they directly impact future work.

Retrospective Generation:

Generate a minimum of three (3) "Sustains" (successful collaboration practices, efficient communication loops, or process wins to maintain).

Generate a minimum of three (3) "Improves" (team communication breakdowns, process frictions, technical debt to resolve, or future tasks blocked).

Format the output strictly as a table ready for inclusion in docs/Retrospective.csv.

Table Schema: Feature/Epic Number | Feature Name | Type (Sustain/Improve) | Title | Discussion | Action Item

Iteration & Consensus (Wait State):

Present the retrospective table.

Halt execution. Await user critique, additions, or modifications.

Iterate on the retrospective data points until the user provides explicit final approval for commit.