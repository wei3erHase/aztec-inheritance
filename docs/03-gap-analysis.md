# Gap Analysis: Known Gaps and Architectural Decisions

> **Status:** Current  
> **Audience:** Developers, Aztec/Noir contributors, reviewers  
> **Last updated:** 2026-05-13

## 1) Agent decision loop

Use this loop when a behavior request appears to fail:

1. Map the request to a matrix entry in [docs/02-feature-matrix.md](02-feature-matrix.md).
2. Confirm whether the behavior is implemented, a deliberate design choice, or blocked.
3. If no row exists, add a hypothesis as a temporary note and capture a failing fixture before implementation.
4. Update this file only when behavior changes would affect compile/runtime guarantees.

Root causes and decisions for KNOWN_GAP and PLANNED_CHANGE entries from the matrix.
BY_DESIGN and OUT_OF_SCOPE are intentional behavior boundaries.

## G-1: Transitive composition is flattened

**Status:** Implemented (PR-1).

**Decision:** Recursive template closure during compose is required behavior.

**Implementation:** composing a template now injects both direct and transitive template functions.
`inject_template_functions_to_registries` now walks transitive closure and deduplicates.

**Root cause (historical):** inject path initially ignored composed IDs from template metadata.

**Evidence:** `composition_transitive` (`mid_value()`, `foo_value()`, `bar_value()`).

### Why this matters to agents

If transitive behavior appears broken, first inspect template graph walk and dedup logic before changing
any user-facing docs or tests.

## G-2: Virtual/override mechanism (resolved)

**Status:** Resolved (PR-3).

**Decision:** Template methods (external and internal) can be `#[template_virtual]` and replaced at host config level
using `override_template("template_id","fn_name")` or `override_internal_template("template_id","fn_name")`.

Compose validation now:

1. checks override targets exist and are not duplicated,
2. enforces the target function is virtual,
3. filters overridden wrappers/ABI from injected/template quoted output.

**Evidence:** `composition_override`, `composition_fixtures::virtual_template`,
`composition_fixtures::internal_override_template`.

### Why this matters to agents

Only a directly composed template can receive host override in current model.
If an override cannot compile, inspect compose ID + virtual registration metadata first.

## G-3: Event structs used by composed bodies are auto-replayed

**Status:** Implemented.

**Decision:** Event structs are now explicitly replayed into host output for composed templates.

**Implementation:**

- Template event structs are collected at `#[contract_template]` time.
- `get_composed_templates_quoted` replays those declarations into host generation.
- Event selector registration is idempotent.

**Evidence:** `composition_host` composes template event emission without manual host `FooEvt` declaration.

## D-1: Compose is merge-and-replay, not hierarchical dispatch

**Status:** Architected decision.

**Decision:** Composition is a flat merge of registries, not parent-child dispatch.

- No inheritance hierarchy.
- No C3 linearization.
- No `super`.
- Overrides are local to host and operate as replacement entries.

**Evidence / impact:** `docs/02-feature-matrix.md` entries 11, 17, 18.

### Why this matters to agents

Do not introduce chain semantics in reviews unless a feature explicitly adds a dispatch hierarchy.

## D-2: Host owns storage (by design)

**Status:** By design.

**Decision:** Templates do not own injected slot-level storage declarations. The host owns storage
and composes by field name references in template code.

**Operational rule:**

- Templates document required field names and types.
- Hosts declare matching fields.
- Slot ordering is host-defined by its `Storage` declaration order.

**Evidence / impact:** matrix entries 4, 5, 14, 15.

### Why this matters to agents

A host compile error on `self.storage.<field>` is typically a missing declaration error, not a
mechanism regression.

## D-3: Global names in composed bodies resolve in host scope

**Status:** By design.

**Decision:** Name resolution in composed quoted bodies happens in host module scope.

**Pattern:**

- Template-owned constants/helpers: use `#[contract_library_method]` (typed expr migration).
- Host-configurable values: require host-provided symbol/binding/import.

**Evidence / impact:** matrix entries 12 and 13.

### Why this matters to agents

Do not fix this by adding hidden global-copy features in compose; this is an intentional contract boundary.

## D-4: Poison packages are excluded from workspace

**Status:** Working decision.

**Decision:** Expected-fail composition fixtures live as evidence artifacts, not always in CI workspace.

**How to execute:** keep failing cases in dedicated packages (for example,
`composition_collision_fail`) and run manually when needed.

**Manual runbook:**

1. Temporarily add the package to `Nargo.toml`.
2. Run `nargo check --package composition_collision_fail_contract`.
3. Expect selector collision failure.

### Why this matters to agents

Keep CI green while still preserving a reproducible proof for forbidden paths.

## D-5: Template ID collisions are last-writer-wins today

**Status:** Observed behavior.

**Decision:** `register_template` inserts by key without duplicate guard, so later registrations win.

**Risk:** accidental overwrite across crates can silently change the composed template implementation.

**Current handling:** no hard assert; intentional re-registration can be used as a version-pin mechanism.

**Evidence / discussion:** unresolved but tracked; matrix remains unchanged because this is cross-cutting
and explicit design tradeoff.

### Safe handling recommendation for agents

- Flag duplicate IDs in review when this is unintentional.
- If intentional pinning is desired, add explicit docs or validation discussion before code changes.

## G-6: Duplicate signatures remain hard errors across direct and transitive merges

**Status:** Implemented behavior.

**Decision:** selector and event-name collisions are compile failures even when introduced by transitive composition.

**Evidence:** `collision_no_override` (direct), `transitive_diamond_leaf_collision`, and
`transitive_diamond_leaf_collision_reverse` (transitive flattening).

**Operational rule:** flattening contributes entries into one host merge surface before codegen; any duplicate
selector or duplicated event symbol in that merged view fails fast.

## G-4: Storage field injection blocked by Noir API

**Status:** Upstream-blocked gap.

**Gap:** host storage fields must be explicitly declared.

**Root cause:** no `TypeDefinition::add_field` in Noir comptime API.

**Design status:** full plan documented in [docs/05-future-work.md](05-future-work.md).

### Why this matters to agents

This is the last major known functional gap for parity and must stay in "upstream issue needed"
state until Noir supports field injection.
