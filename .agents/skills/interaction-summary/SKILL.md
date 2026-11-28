---
name: interaction-summary
description: Synthesize a sanitized, high-signal Human–AI Interaction Summary for a completed feature under docs/logs/interactions/. Use during feature closeout or whenever analyzing how human–agent collaboration, rules, and skills performed during a session.
---

# Human–AI Interaction Summary

Objective: Capture a concise, high-signal qualitative record of **how the human and AI agent collaborated** during a feature—focusing on communication mechanics, guardrail effectiveness, human pushback, and `.agents/` evolution—without exposing sensitive data or bloating Git with raw transcripts.

## Output Location & Naming

Write the summary to:

```text
docs/logs/interactions/feature_<#-#>_<slug>.md
```

Example: `docs/logs/interactions/feature_4-2_ingress-cert-manager.md`

## Mandatory Zero-Token-in-Git Sanitization Gate

Before writing or committing the summary, enforce all of the following redaction rules (this repository mirrors to public GitHub):
1. **No Raw Command Dumps:** Synthesize patterns and failure modes; do not paste raw `kubectl`, `talosctl`, `helm`, or shell output blocks.
2. **No Credentials or Identifiers:** Strip or abstract any API tokens, PATs, kubeconfigs, base64 strings, TLS private keys, internal account emails, or sensitive host/network secrets.
3. **No Superseded Manifests:** Do not embed discarded YAML drafts or broken snippets that could pollute repository search (`git grep`). Reference committed files or ADRs by relative path instead.

## Document Template

Keep the summary concise (target ~1 page / 400–800 words):

```markdown
# Feature <#.#> Human–AI Interaction Summary: <Feature Title>

**Date:** YYYY-MM-DD  
**Feature:** <#.#> — <Feature Title>  
**Related Artifacts:** [Implementation Plan](../../implementation%20plans/feature_#-#_implementation_plan.md) | [Epic Log](../epic-#.md) | [Retrospective](../../Retrospective.csv)

## 1. Collaboration Arc
Brief 3–5 sentence overview of how human and agent progressed from initiation through validation (planning alignment, handoff cadence, and convergence speed).

## 2. Guardrails & Rules That Held
Which `.agents/rules/` or `.agents/skills/` constraints actively prevented errors, rework, or drift during this feature.

## 3. Agent Blind Spots & Human Pushback
Specific moments where the agent made a flawed assumption, missed a constraint, or needed human correction—and what signaled the gap.

## 4. Workflow & Context Friction
Process or tooling friction in the human–agent loop (e.g., context handoffs, terminal formatting, schema assumptions, scope creep).

## 5. `.agents/` Evolution
Concrete updates made to `.agents/rules/` or `.agents/skills/` as a direct result of this feature (or "None required").
```

## Execution Steps
1. Review the current feature's conversation trajectory and approved retrospective entries in `docs/Retrospective.csv`.
2. Draft the summary strictly using the template above, keeping the focus on **human–agent interaction mechanics** rather than recapping technical deliverables.
3. Run the **Zero-Token-in-Git Sanitization Gate** across the entire draft.
4. Present the draft (or write to `docs/logs/interactions/feature_<#-#>_<slug>.md`) and halt for user review before staging/committing via `commit-message`.
