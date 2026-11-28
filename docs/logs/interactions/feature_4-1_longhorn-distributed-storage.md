# Feature 4.1 Human–AI Interaction Summary: Longhorn Distributed Storage

**Date:** 2026-11-25  
**Feature:** 4.1 — Longhorn Distributed Storage  
**Related Artifacts:** [Implementation Plan](../../implementation%20plans/feature_4-1_implementation_plan.md) | [Epic Log](../epic-4.md) | [Retrospective](../../Retrospective.csv)

## 1. Collaboration Arc
Feature 4.1 progressed smoothly from `/feature-initiation` through four gated phases to `/retrospective` and Epic 4 merge (`v2.4.1`) with high convergence speed and zero imperative cluster mutations. The agent established operational context via Audit-Before-Write (ABW) and Search-Before-Write, presented two explicit architectural trade-offs (declarative `Node` CRs vs. UI registration; control plane `etcd` SSD isolation vs. all-disk scheduling), and halted at the Gate Check until the human locked Option A for both. Execution followed a disciplined human-runs-CLI / agent-authors-Git cadence, passing live VS Code terminal context back to the agent to ground Phase 2 manifests in exact live disk keys, validate Phase 3 cross-node replication, and close out Phase 4 documentation via inline file review comments.

## 2. Guardrails & Rules That Held
* **Search-Before-Write & ABW:** Querying upstream Longhorn `v1.6.x` schemas before authoring prevented two major missteps: attempting to retroactively apply `node.longhorn.io/default-disks-config` annotations to already-initialized nodes, and specifying `storageReserved` as a Kubernetes Quantity string instead of `int64` bytes. Auditing `infrastructure/bootstrap/main.tf` alongside `argocd/apps/longhorn.yaml` also surfaced ~1.86 TB of dormant secondary SATA storage and dead Feature 3.2 Kustomize-Helm files.
* **Strict GitOps Exclusivity & Command Execution Boundaries:** Neither human nor agent resorted to imperative `kubectl apply`/`edit`/`delete`. Even the ephemeral Phase 3 replication test was deployed and pruned strictly via ArgoCD (`longhorn-validation`), proving full lifecycle hygiene.
* **Two-Option Rule & Gate Check:** Framing multi-disk management and `etcd` SSD isolation as structured Option A/B trade-offs enabled immediate alignment before any YAML was written.
* **Empirical Verification Before Advancement:** Checking `spec.disks.<key>.allowScheduling` explicitly after noticing Longhorn's `status.diskStatus` reports `Schedulable=True` for disk health/capacity confirmed `etcd` SSD isolation was genuinely enforced.

## 3. Agent Blind Spots & Human Pushback
* **ArgoCD `Unknown` Sync Status Questioned by Human:** During Phase 3 validation, the human flagged concern over `longhorn-validation` reporting `Sync Status: Unknown` despite passing PVC/replica/checksum checks. Rather than dismissing it, inspecting the live application condition isolated a real Kubernetes `v1.36.1` vs. ArgoCD chart `v6.7.18` diff skew (`.status.terminatingReplicas` missing from ArgoCD's bundled client-side diff schema when `ServerSideApply=true` is used without `ServerSideDiff=true`).
* **Incorrect `kubectl` Template Syntax:** In Phase 2, the agent supplied a Go template map-iteration expression inside `-o jsonpath`, which failed immediately on execution. The human surfaced the error via terminal context, prompting an immediate correction to `-o go-template`.
* **Inline Documentation Review Pushback:** Before committing Phase 4 documentation, the human left three targeted inline comments on [05-distributed-storage.md](../../architecture/05-distributed-storage.md) and [infrastructure/storage/README.md](../../../infrastructure/storage/README.md)—questioning an apparent removal of `replicaAutoBalance` (which had been renamed to its qualified Helm path), requesting an explicit `# 7.` code comment on the final validation query, and asking for consistent inline descriptions across the `minio/` directory tree.

## 4. Workflow & Context Friction
* **Terminal Scrollback Clipping:** Running six Phase 1 diagnostic commands consecutively—including a full `nodes.longhorn.io` YAML dump—overflowed the VS Code terminal buffer and clipped the first four outputs (`controlplane-1`'s disk key and Talos `volumestatus`), adding an extra diagnostic round-trip.
* **Dynamic Terminal Context Value:** Passing active terminal state directly into chat eliminated manual copy-paste errors and enabled exact root-cause isolation, though pairing it with compact field-scoped queries is necessary to keep buffer length bounded.

## 5. `.agents/` Evolution
Directly following Feature 4.1 closeout (commit `db065db`), the repository's agent governance layer was updated to codify these lessons:
* **Architect Rule ([gitops-lab-architect.md](../../../.agents/rules/gitops-lab-architect.md)):** Added the **ArgoCD Diff-Skew Guardrail** (requiring `ServerSideDiff=true` on any new `ServerSideApply=true` ArgoCD `Application` until Feature 4.4 upgrades ArgoCD) and **Diagnostic Output Hygiene** (mandating compact field-scoped queries over raw `-o yaml` dumps and `-o go-template` whenever iterating over map keys).
* **Skills Migration & Governance:** Migrated legacy workflows into `.agents/skills/` and introduced dedicated `commit-message` and `interaction-summary` closeout skills.
