# Development Workflow: Incremental Feature PRs

> **Status:** Current  
> **Audience:** Contributors working on the composition roadmap  
> **Last updated:** 2026-05-13

This document describes how to progressively address the PLANNED_CHANGE and KNOWN_GAP items from
[docs/02-feature-matrix.md](02-feature-matrix.md) through individual, discussion-oriented PRs.
Each PR ships both the implementation and the doc update that reflects the new state of the world.
The docs are not a lagging artifact -- they are part of the PR.

---

## Philosophy

**One feature per PR.** Each PR is a focused unit: one capability added, one set of docs updated
to match, one round of discussion closed.

**Docs evolve with code.** The feature matrix, gap analysis, authoring guide, and future-work doc
are living documents. When a PLANNED_CHANGE is implemented, its status moves to IMPLEMENTED. When
a KNOWN_GAP gets a workaround, the authoring guide gains a new section. The PR description and the
doc update tell the same story.

**Discussion before merge, not before opening.** Open the PR with a draft implementation and
explicit open questions. Use the PR itself as the discussion surface. Merge when the questions are
answered and the approach is agreed.

**Sequence is ordered by dependency and confidence.** Items with no blockers and high confidence
come first. Items with design uncertainty open as discussions first. Items blocked on upstream
(Noir/Aztec) get a placeholder PR that files the issue and updates the doc to say "blocked on X".

---

## PR template

Every feature PR must include:

```
## What this adds
One sentence.

## Which docs change and how
- docs/02-feature-matrix.md: entry #N status changes from X to Y
- docs/03-gap-analysis.md: G-N updated / removed
- docs/04-template-authoring.md: new section / updated section on [topic]
- docs/05-future-work.md: item removed / updated

## Open questions (discuss before merge)
1. ...
2. ...

## Acceptance criteria
- [ ] nargo check passes
- [ ] new test proves the behavior
- [ ] related docs updated
- [ ] open questions answered in PR discussion
```

---

## PR sequence

### PR-1: Transitive composition -- flatten transitive dependencies

**Closes:** G-1  
**Effort:** Medium (implemented)
**Blocker:** None
**Scope rule:** PR-1 should remain one-feature only (compose recursion + tests + doc updates). Do not merge other PoCs into this PR.

**What it adds:** Transitive template dependencies are now flattened during compose expansion.
Composing `mid_template` now includes `mid_template`'s own dependencies (`foo_template`, etc.) automatically.

**Implementation sketch (implemented):**

1. In `#[contract_template]` processing, after resolving the contract's compose config, register
   the composed template IDs in a new registry map:
   `TEMPLATE_COMPOSED_IDS: CHashMap<Field, [Field]>`
2. In `inject_template_functions_to_registries`, maintain a `processed_ids` set. After injecting
   the requested templates, look up each template's `TEMPLATE_COMPOSED_IDS` entry and recursively
   inject those too -- skipping any id already in the processed set (deduplication).
3. Same collision rules apply to transitively injected functions (collision without override =
   error; same as today for direct templates).

**Open questions for discussion:**
1. If a grandchild function appears via two paths (host composes A and B, both composed C), is
   deduplication the right behavior, or should we require an explicit include list?
2. Should transitive injection remain default, or should there be an explicit deep-compose opt-in path?

**Doc updates:**
- `02-feature-matrix.md`: entry #8 status changes from `KNOWN_GAP` to `IMPLEMENTED`
- `03-gap-analysis.md`: G-1 decision updated
- `04-template-authoring.md`: update the "list all templates explicitly" rule to reflect new behavior

---

### PR-2: Event struct auto-replay from template registry

**Closes:** G-3 (matrix #13)  
**Effort:** Medium  
**Blocker:** None (architecturally feasible, hook point exists)  
**Priority:** Low -- inconvenient but not critical; deprioritized unless implementation proves simple

**What it adds:** `#[contract_template]` registers event struct `Quoted` definitions alongside
function wrappers. `get_composed_templates_quoted` replays those struct declarations into the host
module. The host no longer needs to manually re-declare event structs used in composed bodies.

**Implementation sketch:**
1. In `template_registry.nr`, add `TEMPLATE_EVENTS_QUOTED: CHashMap<Field, Quoted>`.
2. In `contract_template` (`mod.nr`), iterate `m.structs()` filtered by `has_named_attribute("event")`,
   capture each as `Quoted`, store under the template key.
3. In `get_composed_templates_quoted`, include the event structs in the replayed output.
4. Verify idempotent event selector registration in `events.nr` handles re-registration correctly
   (already done for `Transfer`; confirm it generalizes).

**Open questions for discussion:**
1. If the host declares the same event struct independently (matching signature), does the replay
   cause a duplicate type definition error? Need to test this edge case.
2. Should replayed event structs be marked with a lint-suppression comment so the compiler does not
   flag "duplicate definition" if the host also declares it?
3. Should the template document event structs separately (host-declared) vs automatically injected
   (post this PR)?

**Doc updates:**
- `02-feature-matrix.md`: entry #13 status changes from `KNOWN_GAP` to `IMPLEMENTED`
- `03-gap-analysis.md`: G-3 removed or updated to "resolved"
- `04-template-authoring.md`: remove the "re-declare all event structs" host author rule;
  update the "publish a host requirements document" section to say events are injected automatically
- `05-future-work.md`: remove the event struct auto-injection item

---

### PR-3: Virtual/override mechanism -- MVP

**Closes:** G-2 (matrix #10), sets foundation for #16  
**Effort:** Large  
**Blocker:** None (macro-level only, no language changes needed)
**Current worktree status:** implementation wired for per-function registry storage + override-aware injection/quoted filtering (validation exists, but test/fixture coverage still needed).

**What it adds:** A host can override a specific template function. The template must declare the
function as overridable. Collision without an override declaration remains a fatal error with a
clear message.

**API shape (discuss before implementation):**

Option A -- function-level attributes:
```noir
// Template
#[external("public")]
#[template_virtual]
fn fee_bps() -> u16 { 30 }

// Host
#[external("public")]
#[template_override("foo_template")]
fn fee_bps() -> u16 { 5 }
```

Option B -- config-level declaration (MVP, no new function attributes):
```noir
#[aztec(
    AztecConfig::new()
        .compose("foo_template")
        .override_template("foo_template", "fee_bps")
)]
pub contract Host { ... }
```

**Implementation sketch (once API is agreed):**
1. Add `TEMPLATE_VIRTUAL_SIG_KEYS: CHashMap<Field, [Field]>` to `template_registry.nr`
2. Compute host own signature set from `get_own_*_functions` (no cross-crate body limitation)
3. In `inject_template_functions_to_registries`: for each template function, check if host declares
   an override -- if yes, skip injection (host version wins); if no + collision: error with message
4. In `get_composed_templates_quoted`: accept an include-filter; skip overridden function wrappers
   and ABI from the replay

**Open questions for discussion:**
1. Option A vs Option B for the API? Option A is cleaner long-term; Option B requires no new
   attribute handling. Can both be supported simultaneously?
2. What is the canonical identity for matching (name only, or name + full signature)? Name-only is
   simpler but breaks on overloads; full signature is robust but requires stable type printing.
3. What happens when the host override has a different signature than the template function?
   Hard error or silent mismatch?
4. Can the host override an internal function (not just external)?
5. Error messages: what exactly should "cannot override non-virtual function" say?

**Test cases in `src/composition_override/`:**
- `virtual_override_happy_path` -- host overrides a virtual template function; ABI has single entry
- `override_without_virtual_fails` -- override declared on non-virtual function, error
- `collision_without_override_fails` -- same name, no override config, error (same as today)
- `override_missing_target_fails` -- override references absent function, error
- `multi_template_conflict_with_override` -- two templates same sig, host override resolves it

**Doc updates:**
- `02-feature-matrix.md`: entry #10 status changes from `PLANNED_CHANGE` to `IMPLEMENTED`
- `03-gap-analysis.md`: G-2 updated to "resolved; see composition_override package for test cases"
- `04-template-authoring.md`: new section "Making template functions overridable" explaining
  `#[template_virtual]` and the host-side API
- `05-future-work.md`: M4 virtual/override section updated to "done"; abstract templates section
  updated to note they are now achievable by convention

---

### PR-4: Abstract template convention

**Closes:** matrix #16  
**Effort:** Small (convention + docs, no new mechanism if PR-3 is done)  
**Blocker:** PR-3 (virtual/override)

**What it adds:** Establishes the convention that a template whose external functions are all
`#[template_virtual]` is an "abstract template" -- it defines interface but not implementation.
Hosts MUST override every virtual function. Adds a validation that warns (or errors) if a host
composes an all-virtual template but does not override all virtual functions.

**Open questions for discussion:**
1. Should "abstract" be enforced (error if host doesn't override all virtual functions) or
   advisory (warning)?
2. Is there value in an explicit `#[abstract_template]` attribute to make intent clear, or is the
   all-virtual convention sufficient?

**Doc updates:**
- `02-feature-matrix.md`: entry #16 status changes from `PLANNED_CHANGE` to `IMPLEMENTED`
- `04-template-authoring.md`: new section "Abstract templates (all-virtual)" explaining the
  convention and when to use it
- `05-future-work.md`: abstract template item removed or marked done

---

### PR-5: Storage field injection (upstream Noir, placeholder)

**Closes:** G-4 (matrix #14 -- currently BY_DESIGN)  
**Effort:** Blocked on Noir upstream  
**Blocker:** `TypeDefinition::add_field` does not exist in the Noir comptime API

**What this PR does:** Files the upstream Noir issue, links it in `05-future-work.md`, and
documents the full Aztec-side design so it is ready to implement once the Noir API lands.
No code implementation in this PoC. The design sketch lives in `docs/05-future-work.md`
under "Possibilities with Noir support".

**Open questions for discussion:**
1. Which Noir maintainer or issue tracker is the right target?
2. Is there an intermediate workaround worth shipping before the Noir change lands (e.g., a
   compile-time checklist that validates the host has all required fields by name)?

**Doc updates:**
- `05-future-work.md`: Noir issue link added to the storage field injection section
- `03-gap-analysis.md`: G-4 / D-2 updated with the issue link

---

## How the docs converge to final form

The docs have a current state and a target state. Each PR moves specific entries:

| Doc | Each PR does |
|---|---|
| `02-feature-matrix.md` | One or more status changes (PLANNED -> IMPLEMENTED, KNOWN_GAP -> IMPLEMENTED) |
| `03-gap-analysis.md` | One gap entry updated or removed; one decision entry added if needed |
| `04-template-authoring.md` | One rule added, updated, or removed based on whether the host now needs to do less work |
| `05-future-work.md` | One section removed when the feature is done; one section updated when an upstream issue is filed |
| `ROADMAP.md` | Milestone status updated |
| `README.md` | "What is proven" and "Current limitations" updated when the surface changes significantly |

**Final form** is when:
- `02-feature-matrix.md` has no PLANNED_CHANGE entries (all either IMPLEMENTED, BY_DESIGN, or OUT_OF_SCOPE)
- `03-gap-analysis.md` has no open gaps (only design decisions)
- `04-template-authoring.md` contains only rules the host actually needs to follow (not workarounds for missing features)
- `05-future-work.md` contains only language-level asks that are genuinely upstream

---

## Exit criteria for each PR

A PR is ready to merge when:

1. `nargo check` passes on the workspace
2. The new behavior is proven by at least one test
3. All open questions in the PR description are answered in PR discussion
4. The doc changes are in the same commit as the code changes
5. The feature matrix reflects the new status
6. The authoring guide reflects the new rules (no outdated workarounds for fixed features)
