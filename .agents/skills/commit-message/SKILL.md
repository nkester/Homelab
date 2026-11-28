---
name: commit-message
description: Generate concise, repository-compliant Git commit messages following the homelab `<type>: (<scope>) <summary>` convention. Use whenever drafting commit messages, preparing commits after feature phases, or closing out documentation and governance changes.
---

# Commit Message Generator

Generate Git commit messages that strictly match the homelab repository's established commit taxonomy and GitOps hygiene rules.

## Commit Format

```text
<type>: (<scope>) <concise imperative summary>
```

### Rules
1. **Type + Colon + Space + Parenthesized Scope:** Always place the colon immediately after `<type>`, followed by a space and `(<scope>)` in lowercase (e.g., `feat: (storage) ...`, `docs: (governance) ...`).
2. **Imperative Mood & Lowercase Start:** Start `<summary>` with a lowercase imperative verb (`add`, `configure`, `fix`, `pin`, `remove`, `re-baseline`, `close`, `update`).
3. **Concise Subject Line:** Keep the subject line direct, specific, and ideally under 80–100 characters. Omit trailing periods unless matching multi-clause technical summaries; prefer clean single-clause phrasing without a trailing period.
4. **Optional Body:** Omit the body for straightforward single-purpose commits. Include a brief bulleted body (separated by a blank line) only when a commit spans multiple distinct architectural components or records non-obvious rationale (e.g., ADR linkage, sync-wave dependency, or tech-debt deferral).
5. **Logical Commit Separation:** Never bundle unrelated infrastructure manifests and feature-closeout governance/retrospective updates into the same commit. Flag mixed staged changes and recommend splitting them into atomic commits (e.g., `feat:`/`fix:`/`test:` vs. `docs:`).

## Allowed Types
- `feat`: New declarative infrastructure, ArgoCD application, workload, or capability.
- `fix`: Bug fix, schema/annotation correction, reconciliation deadlock resolution, or security hardening.
- `test`: Declarative ephemeral validation workloads or smoke tests (e.g., temporary ArgoCD validation apps).
- `docs`: Architecture blueprints, ADRs, READMEs, runbooks, implementation plans, roadmap updates, or retrospective closeouts.
- `refactor`: Structural reorganization without changing runtime behavior (e.g., state backend migration, file restructuring).
- `chore`: Repository maintenance, `.agents/` rules/skills updates, `.gitignore`, or tooling housekeeping.

## Standard Scopes
Use the most specific domain scope matching the changed files:
- `bootstrap` — Plane 1 OpenTofu, Talos OS, bare-metal provisioning
- `networking` — Cilium, LB-IPAM, Ingress, cert-manager, DNS, VLANs
- `storage` — Longhorn, MinIO, SeaweedFS/Garage, PVCs
- `serverless` — Knative Serving, Argo Workflows event triggers
- `security` — External Secrets Operator, CiliumNetworkPolicy, RBAC, TLS
- `observability` — LGTM stack (Loki, Grafana, Tempo, Mimir)
- `dr` — Velero backups, restore drills
- `analytics` — CloudNativePG, RStudio, VSCode, KubeFlow
- `governance` — Roadmap (`HomeLab_Project_Roadmap.csv`), `Retrospective.csv`, ADRs, Epic logs
- `agents` — `.agents/rules/` and `.agents/skills/` customizations

## Execution Steps
1. Inspect staged and unstaged changes via read-only `git status` and `git diff --cached --stat` (or `git diff --stat` if nothing is staged yet).
2. Verify **Zero-Token-in-Git**: confirm no secrets, PATs, private keys, or placeholder credentials are staged. If detected, halt and warn the user immediately.
3. Check for mixed concerns (e.g., cluster manifests mixed with closeout governance docs); if present, recommend atomic commit splits.
4. Output the exact `git commit -m "..."` command inside a standalone markdown code block ready for the user to execute manually.

## Examples
- `feat: (networking) deploy cert-manager and NGINX Ingress Controller via ArgoCD`
- `fix: (serverless) explicitly bind KPA autoscaler class and harden securityContext`
- `test: (storage) add declarative Longhorn cross-node replication validation workload`
- `docs: (governance) close Feature 4.1 with retrospective entries and advance roadmap to Feature 4.2`
- `chore: (agents) migrate legacy workflows to skills and codify retrospective guardrails`
