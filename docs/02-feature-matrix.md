# Feature Matrix: Solidity Inheritance vs Aztec Compose

> **Status:** Current  
> **Audience:** Developers and reviewers evaluating composition capability  
> **Last updated:** 2026-05-13

Every Solidity inheritance feature validated against Aztec template composition via executable
proof (pass/fail). Zero hypotheses unresolved.

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
| 8 | Composing a transitive template does not silently flatten grandchild functions | SILENT FAIL | `composition_transitive`: `foo_value()` silently absent; no compiler warning | **KNOWN_GAP** |
| 9 | Function name collision is a hard compile error | PASS | `composition_collision_fail`: "selector collision between foo_value and foo_value" at dispatch generation | **IMPLEMENTED** |
| 10 | Host can override a specific template function | NOT YET | No override mechanism; collision is fatal today | **PLANNED_CHANGE** |
| 11 | `super` call to base implementation | N/A | Compose is flat/non-hierarchical; there is no base, no chain, no `super` concept | **OUT_OF_SCOPE** |
| 12 | Global names in composed bodies resolve in host scope | PASS (with pattern) | Host declares or imports `FOO_MAGIC`; injected body resolves it. Template must not self-reference its own module globals -- use `#[contract_library_method]` for template-owned constants | **IMPLEMENTED** |
| 13 | Event structs auto-injected into host from template | FAIL | Host must re-declare every event struct used in composed bodies; language-blocked | **KNOWN_GAP** |
| 14 | Host declares all template storage fields manually | PASS (by design) | Host fully owns its storage; templates have no private storage and should not reference slots by id | **BY_DESIGN** |
| 15 | Storage slot ordering is host-controlled | PASS (by design) | `storage.nr` assigns slots per `fields_as_written()` order in host's Storage struct | **BY_DESIGN** |
| 16 | Abstract template (all-virtual, not deployable) | NOT YET | Implementable alongside #10: a template with only virtual functions is abstract by convention | **PLANNED_CHANGE** |
| 17 | `private` function inaccessible to host (Solidity visibility) | N/A | Compose copies quoted function bodies, not Solidity-style imports. There is no private scope in the copy model -- all composed functions are visible to the host | **OUT_OF_SCOPE** |
| 18 | Inheritable/overridable modifiers | N/A | Aztec uses function-level attributes (`#[only_self]`, `#[authorize_once]`); no modifier chain | **OUT_OF_SCOPE** |

**Summary: 9 IMPLEMENTED, 2 PLANNED_CHANGE, 3 KNOWN_GAP, 2 BY_DESIGN, 3 OUT_OF_SCOPE, 0 UNRESOLVED**

---

## Notes on selected entries

### #8 -- transitive composition: silent fail is the real problem

The behavior itself is correct by design (see D-1 in gap analysis). The problem is user experience:
composing `mid_template` produces no warning that `foo_template` and `bar_template` functions are
NOT included. Planned improvement: emit a compiler warning when `inject_template_functions_to_registries`
detects that a selected template itself has composed templates (indicating the developer may have
expected transitive flattening).

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

### #10 and #16 -- planned together

Virtual/override (#10) and abstract templates (#16) are two sides of the same mechanism. A template
with all-virtual functions is abstract by convention. Implementing #10 automatically enables #16.
See [docs/05-future-work.md](05-future-work.md) M4 for the design.

---

## Evidence packages

| Package | Path | Proves |
|---|---|---|
| `composition_fixtures` | `src/composition_fixtures` | Template definitions: `foo_template`, `bar_template`, `mid_template`, `foo_storage_template`, `foo_collision_template` |
| `composition_multi` | `src/composition_multi` | #1, #2, #3, #9 |
| `composition_transitive` | `src/composition_transitive` | #8 |
| `composition_host` | `src/composition_host` | #4, #5, #6, #12, #13 |
| `composition_collision_fail` | `src/composition_collision_fail` | #9 (poison -- excluded from workspace) |
| `amm_token` | `src/amm_token` | #7, #14 |

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
| Virtual/override single function | Planned (M4) |
| Abstract templates | Planned (M4, follows from virtual/override) |
| Transitive template flattening | No (accepted; warn on silent skip is planned) |
| Automatic event struct injection | No (language-blocked) |

Root causes and decisions for known gaps: [docs/03-gap-analysis.md](03-gap-analysis.md)
