# Development Workflow: Composition Feature Delivery

> **Status:** Current  
> **Audience:** Contributors working on roadmap items and PR execution  
> **Last updated:** 2026-05-13

This file is for agents: a practical workflow to move one composition behavior at a time from hypothesis
to proof and documentation closure.

---

## 1) One-feature loop (required for composition changes)

For each feature candidate:

1. define hypothesis and expected behavior;
2. create/adjust one passing fixture;
3. create/adjust one poison case if behavior is forbidden;
4. update docs in same PR;
5. review matrix/gap status alignment.

Never combine unrelated behavior changes.

---

## 2) PR template you can copy

Every feature PR must include:

```
## What this adds
- one sentence of intended behavior

## Why this is needed
- matrix mapping + expected evidence

## Docs changed
- docs/02-feature-matrix.md
- docs/03-gap-analysis.md
- docs/04-template-authoring.md
- docs/05-future-work.md

## Open questions
- decisions that need consensus before merge

## Poison/negative coverage
- added package + expected error (or explicit reason none needed)

## Acceptance checks
- tests proving behavior
- docs and status consistency
```

---

## 3) PR sequence (current milestone context)

### PR-1: Transitive composition flattening
**Status:** Done

Ensure flattening + dedup and transitive tests remain intact when touching injection paths.

### PR-2: Event struct auto-replay
**Status:** Implemented

Keep event declarations aligned: automatic replay is the current expectation.

### PR-3: Virtual/override + abstract convention
**Status:** Implemented

Remember single-level behavior and direct-template override target requirement.

### PR-5: Internal helper override support

**Status:** Implemented

Internal virtual helpers should now follow the same one-step override rule using
`override_internal_template(...)`; keep tests + poison coverage aligned before extending this behavior.

### PR-5: Storage injection blocker
**Status:** Upstream blocked

Only move here once upstream issue is filed and approved.

---

## 4) For agents: safety checks before merge

- `nargo check` passes on changed packages.
- Added/updated acceptance fixture verifies claimed behavior.
- matrix row status updated and evidence package linked.
- gap decision file updated if status category changed.
- workflow docs not stale.

---

## 5) How to mark failure paths

- Use poison artifacts under `src/` for behavior that should remain invalid.
- Keep poison packages out of workspace when they must fail.
- Link compile-time expectation text in PR notes.

Suggested command (manual only when needed):

```bash
nargo check --package <poison_package_name>
```

---

## 6) Finalization criteria for this milestone

The milestone reaches final form when:

- matrix has no unresolved `PLANNED_CHANGE`,
- gap analysis has no ambiguous blockers,
- authoring guide reflects actual host/template requirements (no stale workaround docs),
- future-work contains only true upstream or strategic items,
- `README` and `ROADMAP` reflect current milestone state.
