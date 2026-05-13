# Gap Analysis: Known Gaps and Architectural Decisions

> **Status:** Current  
> **Audience:** Developers, Aztec/Noir contributors, reviewers  
> **Last updated:** 2026-05-13

Root causes, evidence, and decisions for KNOWN_GAP and PLANNED_CHANGE entries from
[docs/02-feature-matrix.md](02-feature-matrix.md). BY_DESIGN and OUT_OF_SCOPE entries are
explained inline in the matrix.

---

## G-1: Transitive composition is flattened

**Status:** Implemented (PR-1).

**Implementation:** Composing a template now recursively injects all transitive template functions.
Function-name collisions still follow existing compose collision rules.

**Root cause (historical):** `inject_template_functions_to_registries` previously only injected
the directly composed templates and ignored their dependencies.

**Evidence:** `composition_transitive` -- `mid_value()`, `foo_value()`, and `bar_value()` are all
callable from the host.

**Decision:** PR-1 implemented recursive expansion and removed this gap.

**Solidity equivalent:** `C is B, A` flattens the full hierarchy. Gap on flattening is accepted;
the warning closes the UX gap.

---

## G-2: No virtual/override mechanism (blocked)

**Gap:** Two composed templates with the same function name cause a compile error. The host cannot
override a composed template function. This is currently blocked by registry shape: template wrappers
and ABI exports are stored as per-template aggregates, so selective override filtering is not
implemented without a deeper refactor.

**Root cause:** The compose machinery generates one `__aztec_nr_internals__<fn_name>` wrapper per
function. `generate_public_dispatch` rejects duplicate selectors. There is no mechanism to mark a
function as "overridable" or build an override chain.

**Evidence:** `composition_collision_fail` -- composing `foo_template` and `foo_collision_template`
(both define `foo_value()`) panics with "Public function selector collision detected".

**Implementation plan (M4):**

1. `#[template_virtual]` attribute on template functions to opt into override
2. Host declares `#[template_override("template_id")]` on the replacing function,
   OR config-driven: `AztecConfig::new().compose("foo").override_template("foo", "fee_bps")`
3. Logic in `inject_template_functions_to_registries` to skip overridden template functions
4. Selective quoted replay to exclude overridden ABI/wrappers from `get_composed_templates_quoted`
5. Errors: collision with no override declared, override declared for non-virtual function,
   override target not found

**See:** [docs/05-future-work.md](05-future-work.md) M4 for the full design.

**Solidity equivalent:** `virtual`/`override` + C3 linearization. Gap is real, fix is planned.

---

## G-3: Event struct types must be re-declared in host (language-blocked)

**Gap:** Event structs defined in a template and used in composed function bodies must be re-declared
in the host module. There is no automatic injection.

**Root cause:** Composed function bodies carry raw token streams. The body `{ self.emit(FooEvt {...}) }`
resolves `FooEvt` in the host module's scope at injection time. If the host does not declare `FooEvt`,
the injection fails to compile with "could not resolve FooEvt in path".

This is the same root cause as host-scope global resolution (#12 in the matrix): all identifiers in
composed bodies resolve in host scope. The difference is that event structs cannot be "imported from
the template crate" the same way globals can, because `#[event]` registration is part of the Aztec
contract machinery and the struct type must be physically declared in the host module for the
`self.emit(...)` call to type-check.

**Evidence:** `composition_host/src/main.nr` must declare `#[event] struct FooEvt { value: u32 }`.
Same pattern as `Transfer` re-declaration in `amm_token/src/main.nr`.

**Decision:** Accept for this PoC. Document as a template authoring rule.

**Potential improvement:** `#[contract_template]` registers event struct `Quoted` definitions
alongside function wrappers and replays them into the host. Architecturally feasible (the hook
point in `template_registry.nr` exists) but requires careful ordering relative to Aztec's own
event selector registration. Deferred to M5.

**Solidity equivalent:** Base contract events are directly usable in derived contracts. Gap is real.

---

## D-1: Compose is merge-and-replay, not hierarchical dispatch

**Decision:** The current implementation is intentionally a "merge-and-replay" model. Functions
from selected templates are concatenated into the host. There is no dispatch hierarchy, no C3
linearization, no implicit ordering.

**Implications:**
- Multi-compose is flat: all templates at the same level with equal precedence
- Transitive flattening (G-1); all composed templates are recursively included by `compose()`
- No override chain today (G-2); planned for M4
- `super` does not apply: there is no "parent implementation" in a flat merge
- All composed function names must be unique across the host and all composed templates

**Why this is the right tradeoff:** Implementing full Solidity-style inheritance in Noir's comptime
system requires language-level support (storage field injection, override attributes, super dispatch).
The merge-and-replay model is sufficient for the "AIP-20 token as a mixin" use case and can be
extended incrementally as language support improves.

---

## D-2: Host owns storage (by design)

**Decision:** The host is the single owner of all storage. Templates have no private storage and
should not reference storage slots by position/id. The host declares storage fields in whatever
order it chooses; slot numbers are assigned by the host's Storage struct declaration order.

This is not a gap -- it is an intentional architectural boundary:

- Templates are function sets, not state machines with private state
- Storage field declarations are a contract published by the template (see
  [docs/04-template-authoring.md](04-template-authoring.md)) that the host must satisfy
- The host can arrange fields in any order; composed function bodies reference fields by NAME
  (via `self.storage.foo_counter`) not by slot number, so order is irrelevant for correctness

**What this means for template authors:** document the storage field names and types your composed
functions reference. The host will declare them. Do not rely on slot numbers or ordering.

**Future possibility:** slot ordering enforcement could be added (e.g., template fields must occupy
lower slots for upgrade safety), but there is no current requirement for this.

---

## D-3: Global names in composed bodies are host-scope bindings (by design)

**Decision:** Any global name referenced in a composed function body resolves in the HOST module's
scope at injection time. This is intentional and useful: the host controls what the binding contains.

**What the template cannot do:** self-reference its own module globals in composable bodies. The
body is elaborated by `#[aztec]` during template processing inside the contract block context, where
module-scope globals are not accessible. Without Noir `crate::` self-reference in comptime contexts,
the template cannot write a stable path to its own globals. This is a Noir comptime limitation, not
an Aztec composition limitation.

**Pattern for template-owned constants:** use `#[contract_library_method]`:

```noir
// Template -- constant belongs to the template implementation
#[contract_library_method]
fn _initial_notes() -> u32 { 2 }

// In composable body: reference the helper, not a raw global
#[external("public")]
fn do_thing() {
    let n = _initial_notes();  // migrates via f.as_typed_expr(), always resolves
}
```

**Pattern for host-parameterizable names:** reference the name unqualified in the body; document it
as a "host-must-provide binding":

```noir
// Template -- body references FOO_CONFIG, which the host must supply
#[external("public")]
fn use_config() -> u32 {
    FOO_CONFIG  // host provides this name
}

// Host -- provides the binding (import or local declaration)
use composition_fixtures::foo_template::FOO_CONFIG;  // import from template crate
// OR:
pub global FOO_CONFIG: u32 = 99;  // host overrides with its own value
```

---

## D-4: Poison packages are excluded from workspace

**Decision:** Packages expected to fail compilation (`composition_collision_fail`) are NOT included
in `Nargo.toml`. They exist in `src/` as documentation and manual test evidence.

**To run a poison test manually:**
```bash
# Temporarily add to Nargo.toml, then:
nargo check --package composition_collision_fail_contract
# Expected: "Public function selector collision detected"
```
