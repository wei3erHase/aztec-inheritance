# Inheritance Playbook for Agents

> **Status:** Composition behavior playbook  
> **Audience:** Agents implementing, testing, or reviewing Aztec inheritance-like composition  
> **Goal:** Make mechanism behavior predictable for the next change, PR, or security review  
> **Last updated:** 2026-05-13

This document is written as operational guidance.  
Read it before touching any inheritance-related code, and use it as the first pass of your implementation plan.

---

## 1) First principle (use this mental model always)

Aztec template composition is **explicit flat merge + replay**, not Solidity inheritance.

1. A host says which templates to compose by id.
2. The macro copies callable artifacts from those template registries into the host.
3. There is no runtime parent-child chain inside the merged code.
4. Anything outside the copied/replayed surface must still be explicitly available in the host.

If you cannot explain a behavior in this model, it is not part of current guarantees.

---

## 2) "How to think" framework for every change

For any requested behavior, run this sequence:

1. Classify  
   - **Flat merge** behavior (already supported mechanics)  
   - **Storage/symbol requirement** (host-provided)  
   - **Override semantics** (virtual + override)  
   - **Upstream gap** (blocked by Noir)

2. Predict outcome  
   - What is expected to compile?  
   - What is expected to fail?  
   - What failure is a bug (compile should fail, but currently passes)?

3. Prove with tests  
   - Add/adjust one passing fixture for expected behavior.  
   - Add a poison case for expected failure when behavior is forbidden.

4. Document immediately  
   - Update matrix entry status and the related gap/decision file in the same PR.  
   - Keep wording behavior-first, not feature-first.

5. Re-run assumptions  
   - If the change affects only behavior assumptions, reclassify "good practices / no-gos" in this file.

---

## 3) What this means for feature design

### 3.1 Multi-composition is additive and equal

Composing multiple templates means registry merge into one namespace.

- If identifiers collide across host/template(s), it is a compile blocker unless the collision is handled by explicit override.
- Compose order is not a general dispatch order model; do not assume parent/child precedence.

### 3.2 Transitivity is explicit flattening

If template `C` composes `D`, including `C` in host composition also flattens in `D` (and recursively, with deduplication).

- Don’t add secondary logic for implicit include beyond flattening unless required.
- Validate diamond behavior through registry dedup.

### 3.3 Storage is a host contract, not a template contract

Templates can depend on storage fields, but hosts declare storage structure.

- Template authors must publish required storage shape.
- Host authors must import or define trait/context helpers used by composed bodies.

### 3.4 Host-scope symbol resolution

Composed bodies execute in host scope for name resolution.

- Template-owned constants should prefer `#[contract_library_method]`.
- Host-configurable values should be declared/imported by name in host scope.

### 3.5 Override is single-level

Override replaces a host-visible virtual function declaration from a selected template.

- No `super` behavior in this model.
- "Override chain" reasoning is not valid unless a future feature is explicitly added.

---

## 4) Good practices (must-do)

Use this list as a PR pre-flight checklist.

- Keep templates minimal and explicit.
- Use clear namespacing conventions (`foo_get`, `foo_set`, `_foo_validate`) to avoid namespace collisions.
- Document host requirements with each template crate (storage fields, required imports, initializer call).
- Prefer `#[contract_library_method]` for constants/helpers intended to be implementation-locked.
- Prefer host-local globals for values that should be deploy-time configurable by host.
- Add both positive and negative proof cases when changing composition behavior.
- Keep one behavior change per PR to preserve review clarity.
- When touching PR behavior, update:
  - `docs/02-feature-matrix.md`
  - `docs/03-gap-analysis.md`
  - `docs/04-template-authoring.md`
  - `docs/05-future-work.md`
  - `docs/06-development-workflow.md` (status if sequence changed)

---

## 5) No-gos (hard boundaries)

Treat these as explicit limitations, not regressions:

- No expectation of Solidity-like C3 linearization.
- No `super` dispatch to parent implementation.
- No transparent module-scope global import from template internals unless host provides it.
- No automatic storage field injection from template `Storage`.
- No implicit inheritance of template module imports/traits.
- No silent semantics changes to collision behavior (must keep compile-time failure rules explicit).

If a request needs any of these, mark it as a follow-up feature decision and file upstream work only if needed.

---

## 6) Antipattern map to keep current (poison test source of truth)

If behavior is changed, check this list before merging:

| Area | Failure mode | Fixture |
|---|---|---|
| Selector collisions | Direct collision between two directly composed templates | `collision_no_override` |
| Selector collisions | Directly composed templates expose the same selector via transitive flattening | `transitive_diamond_leaf_collision`, `transitive_diamond_leaf_collision_reverse` |
| Storage fields | Required field missing from host `Storage` | `missing_storage_var` |
| Storage fields | Shared storage name with wrong shape/type | `storage_shape_mismatch` |
| Globals | Host assumes template module global is inherited implicitly | `host_global_scope_resolved_limit`, `foo_raw_global_template` |
| Events | Host redeclares an event already replayed from template | `event_host_redeclares` |
| Events | Two composed templates replay same event type | `event_collision_across_templates` |
| Overrides | Override target is transitive but not directly composed | `override_transitive_missing_direct_compose` |
| Overrides | Only one of multiple colliding virtuals is overridden | `override_transitive_partial_override` |
| Overrides | Local template override without host config entry in same scope | `override_transitive_collision_without_override`, `override_mid_template_local_fee_bps` |

Keep this map as the "negative coverage index": any new behavior in this area must either stay documented or come with a new matching poison case.

---

## 7) Catchas / recurring traps (what to watch for)

- **Template ID duplication**  
  Same ID from multiple crates is last-writer-wins today.
  This can be intentional (version pin) or dangerous (accidental overwrite). Call it out in reviews.

- **Shape mismatch on shared fields**  
  Same storage name, different type across composed expectations should fail during compilation at host-side use sites.
  Do not assume silent coercion.

- **Override missing target**  
  `override_template("id", "fn")` must map to a real virtual function from a composed template.

- **Transitive collision confusion**  
  Collision can surface from transitive flattening, not only direct composition. Test diamond shapes.

- **Event replay assumptions**  
  Event structs are replayed by implementation; avoid reintroducing manual requirements in docs that are already solved.

- **Poison case not tested**  
  If a feature has a forbidden path, include a manually runnable poison fixture instead of relying on assumptions.

---

## 8) Validation recipe for each inheritance mechanism question

For each candidate behavior:

1. Add a tiny positive fixture in existing `composition_*` package family.
2. Add a failing/poison package if the behavior should remain forbidden.
3. Validate selectors and ABI where relevant.
4. Record outcome under the right matrix entry (`IMPLEMENTED`, `PLANNED_CHANGE`, `KNOWN_GAP`, `BY_DESIGN`, `OUT_OF_SCOPE`).
5. Add one sentence in this playbook if the reasoning for agents changed.

Evidence anchor points you can reuse:
- `composition_fixtures` (templates)
- `composition_multi` (multi-compose basics)
- `composition_transitive` (flattening/diamond checks)
- `composition_host` (storage/events/constants assumptions)
- `composition_override` (template_virtual + override behavior)
- `composition_collision_fail` (negative example; excluded from workspace on purpose)

---

## 9) Current milestone status summary

- Completed and active:
  - recursive transitive composition flattening
  - event struct replay for composed bodies
  - virtual + override wiring via `template_virtual` + `override_template`
  - abstract-template convention via all-virtual external surface
- Remaining hard boundary:
  - storage auto-injection still blocked by Noir upstream API (`TypeDefinition::add_field`)
- Operational posture:
  - docs and tests are the source of truth; avoid adding behavior without proof.

---

## 10) Next decisions to revisit (if behavior request arrives)

- Should template-id overwrites become explicit-only?
- Should storage-shape mismatch handling become dedicated diagnostics?
- Should multi-layer override semantics be introduced, or remain single-level?
- Which current "host requirements" can be converted into stronger linting without harming composability?

Use this file as the decision prompt before changing core composition machinery.
