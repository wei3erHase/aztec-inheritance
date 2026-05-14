# Feature Matrix: Solidity Inheritance vs Aztec Compose

> **Status:** Current  
> **Audience:** Developers and reviewers evaluating composition capability  
> **Last updated:** 2026-05-13

## 1) Agent lens

Use this table as the decision source for "is this behavior done".

- `IMPLEMENTED`: we can reproduce it in an executable fixture.
- `KNOWN_GAP`: blocked behavior with a known root cause.
- `PLANNED_CHANGE`: doable at macro level but not yet implemented.
- `BY_DESIGN`: intentionally different from Solidity inheritance.
- `OUT_OF_SCOPE`: different model boundary.

For each candidate change:

1. Add/adjust a test (PASS or poison).
2. Update the row status and keep evidence explicit.
3. If the result is blocked, classify as `KNOWN_GAP` with a root-cause pointer.

Every Solidity inheritance feature is validated against Aztec template composition via executable
proof (pass/fail) with current implementation status tracked in this table.

**Status labels:**
- `IMPLEMENTED` -- works today, proven by a test
- `PLANNED_CHANGE` -- implementable at macro level without language changes; on the roadmap
- `KNOWN_GAP` -- does not work today; root cause in [docs/03-gap-analysis.md](03-gap-analysis.md)
- `BY_DESIGN` -- intentional difference from Solidity; not a gap
- `OUT_OF_SCOPE` -- not applicable to the Aztec model; different concept

---

## Feature Matrix

| # | Feature | Result | Evidence | Status |
|---|---|---|---|---|
| 1 | Multi-compose: two templates in one host | PASS | `composition_multi`: `foo_value()` and `bar_value()` both callable | **IMPLEMENTED** |
| 2 | Composed external surface callable from outside | PASS | `composition_multi`: `env.view_public(host.foo_value())` == 12 | **IMPLEMENTED** |
| 3 | Composed internal helpers callable from host function | PASS | `composition_multi`: `combined_internal_markers()` sums both template internals | **IMPLEMENTED** |
| 4 | Composed external reads host storage field | PASS | `composition_host`: `foo_get()` reads `foo_counter`; `foo_increment()` writes it | **IMPLEMENTED** |
| 5 | Composed internal writes host storage field | PASS | `composition_host`: `host_set_and_get(99)` via `self.internal._foo_set(99)` returns 99 | **IMPLEMENTED** |
| 6 | Library method constant migrated cross-crate | PASS | `composition_host`: `host_library_constant()` == 42; `foo_magic_via_helper()` == 42 | **IMPLEMENTED** |
| 7 | Constructor/initializer chain | PASS | `amm_token`: constructor calls `self.internal._initialize_token(TokenInitParams {...})` | **IMPLEMENTED** |
| 8 | Transitive composition flattens grandchild templates | PASS | `composition_transitive`: `mid_value()`, `foo_value()`, and `bar_value()` are all callable | **IMPLEMENTED** |
| 9 | Function name collision is a hard compile error | PASS | `composition_collision_fail`: "selector collision between foo_value and foo_value" at dispatch generation | **IMPLEMENTED** |
| 10 | Host can override a specific template function | PASS | `composition_override`: `fee_bps()` is implemented in host and overrides template default. Override must be declared in the host config for the target template id that is directly composed | **IMPLEMENTED** |
| 11 | `super` call to base implementation | N/A | Compose is flat/non-hierarchical; there is no base, no chain, no `super` concept | **OUT_OF_SCOPE** |
| 12 | Global names in composed bodies resolve in host scope | PASS (with pattern) | Host declares or imports `FOO_MAGIC`; injected body resolves it. Template must not self-reference its own module globals -- use `#[contract_library_method]` for template-owned constants | **IMPLEMENTED** |
| 13 | Event structs auto-injected into host from template | PASS | Event struct declarations from templates are replayed automatically | **IMPLEMENTED** |
| 14 | Host declares all template storage fields manually | PASS (by design) | Host fully owns its storage; templates have no private storage and should not reference slots by id | **BY_DESIGN** |
| 15 | Storage slot ordering is host-controlled | PASS (by design) | `storage.nr` assigns slots per `fields_as_written()` order in host's Storage struct | **BY_DESIGN** |
| 16 | Abstract template (all-virtual, not deployable) | PASS (convention) | `composition_fixtures::virtual_template` documents virtual-only external surface for override-based instantiation | **IMPLEMENTED** |
| 17 | `private` function inaccessible to host (Solidity visibility) | N/A | Compose copies quoted function bodies, not Solidity-style imports. There is no private scope in the copy model -- all composed functions are visible to the host | **OUT_OF_SCOPE** |
| 18 | Inheritable/overridable modifiers | N/A | Aztec uses function-level attributes (`#[only_self]`, `#[authorize_once]`); no modifier chain | **OUT_OF_SCOPE** |

**Summary: 12 IMPLEMENTED, 0 PLANNED_CHANGE, 1 KNOWN_GAP, 2 BY_DESIGN, 3 OUT_OF_SCOPE, 0 UNRESOLVED**

## 2) How to use the matrix during reviews

When reviewing an implementation PR:

- Confirm changed behavior is represented by at least one matrix row.
- Confirm the row points to a runnable evidence package (`composition_*`) or a manual poison path.
- Confirm no contradictory status remains between this table and the gap/workflow docs.
- If a row changes status, coordinate corresponding updates in:
  - [docs/03-gap-analysis.md](03-gap-analysis.md)
  - [docs/04-template-authoring.md](04-template-authoring.md)
  - [docs/05-future-work.md](05-future-work.md)

---

## Notes on selected entries

### #8 -- transitive composition is now flattened

Composing a template now recursively injects transitive dependencies, so grandchild template functions are
made available automatically.

### #12 -- globals are host-scope bindings, not template-owned statics

A global name referenced in a composed function body is resolved in the HOST module's scope at
injection time. This is a feature, not a gap: the host decides what the binding contains.

**What the template cannot do:** self-reference its own module globals in composable bodies.
The body is elaborated by `#[aztec]` inside the template module's contract block, where
module-scope globals are not accessible. Without Noir `crate::` self-reference in comptime
contexts, the template has no stable path to its own globals. Use `#[contract_library_method]`
for template-owned constants.

**What the host can do:** provide any global name the template's bodies reference, either by
importing it from the template's crate or by declaring its own value:

```noir
// Option A: import from the template crate
use composition_fixtures::foo_storage_template::FOO_MAGIC;

// Option B: declare a local binding (host decides the value)
pub global FOO_MAGIC: u32 = 99;
```

See [docs/04-template-authoring.md](04-template-authoring.md) for the full pattern.

### #10 and #16 -- implemented together

Virtual/override (#10) and abstract templates (#16) are two sides of the same mechanism. A template
with all-virtual functions is abstract by convention. Implementing #10 automatically enables #16.
Overrides are **host-only and single-level**: a template cannot declare a replacement for a function
defined by a composed template without `.override_template(...)` in the host config.
See [docs/05-future-work.md](05-future-work.md) M4 for the design.

## 3) Evidence quality rule

Each "PASS" row should remain reproducible with deterministic evidence and not rely on comments.
Each "KNOWN_GAP" row should describe why behavior is blocked and which upstream/API limitation causes it.
Each "OUT_OF_SCOPE/BY_DESIGN" row should include a short rationale that references model boundaries
(`merge-and-replay`, `host-owned storage`, `single-level override`, etc.).

---

## Evidence packages

| Package | Path | Proves |
|---|---|---|
| `composition_fixtures` | `src/composition_fixtures` | Template definitions: `foo_template`, `bar_template`, `mid_template`, `foo_storage_template`, `foo_collision_template`, `virtual_template` |
| `composition_multi` | `src/composition_multi` | #1, #2, #3, #9 |
| `composition_transitive` | `src/composition_transitive` | #8 |
| `composition_host` | `src/composition_host` | #4, #5, #6, #12, #13 |
| `composition_collision_fail` | `src/composition_collision_fail` | #9 (poison -- excluded from workspace) |
| `composition_override` | `src/composition_override` | #10, #16 (virtual override and template-overridable composition) |
| `amm_token` | `src/amm_token` | #7, #14 |

## Negative evidence (antipattern fixtures)

Poison paths are not ignored—they are part of the contract of merge-and-replay and are tracked under `src/poison/*`.

| Pattern | Proof package | Why this matters |
|---|---|---|
| Direct selector collision | `collision_no_override` | Confirms function names are unique in the host-level merged surface |
| Storage slot absent | `missing_storage_var` | Confirms host-owned storage requirements are mandatory |
| Storage slot shape mismatch | `storage_shape_mismatch` | Confirms shared-name/type alignment is enforced |
| Transitive duplicate selector | `transitive_diamond_leaf_collision`, `transitive_diamond_leaf_collision_reverse` | Confirms flattening does not bypass selector safety |
| Host redeclares template event | `event_host_redeclares` | Confirms replayed event declarations are authoritative |
| Event collision across composed templates | `event_collision_across_templates` | Confirms event namespaces stay singleton across flattened composition |
| Host global resolution gap | `host_global_scope_resolved_limit` | Confirms template module globals do not auto-bind into host scope |
| Override target not directly composed | `override_transitive_missing_direct_compose` | Confirms override binding requires direct template ID composition |
| Partial override in collision set | `override_transitive_partial_override` | Confirms all colliding virtual sources must be handled |
| Missing local override path | `override_mid_template_local_fee_bps`, `override_transitive_collision_without_override` | Confirms override contract remains host-explicit |

---

## Overall assessment

Aztec template composition is **merge-and-replay**, not Solidity `is`-based inheritance:

| Capability | Today |
|---|---|
| Reuse a full contract surface (externals + internals) without copy-paste | Yes |
| Initializer chaining via composed internals | Yes |
| Library method constants cross-crate | Yes |
| Host-parameterizable globals (host provides binding) | Yes, with pattern |
| Name collision detection (hard error) | Yes |
| Virtual/override single function | Yes (`#10`) |
| Abstract templates | Yes (`#16`; convention now documented) |
| Transitive template flattening | Yes |
| Automatic event struct injection | Yes (template replay) |

Root causes and decisions for known gaps: [docs/03-gap-analysis.md](03-gap-analysis.md)
