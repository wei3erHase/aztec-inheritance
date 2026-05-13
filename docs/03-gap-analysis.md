# Gap Analysis: Known Gaps and Architectural Decisions

> **Status:** Current  
> **Audience:** Developers, Aztec/Noir contributors, reviewers  
> **Last updated:** 2026-05-13

Root causes, evidence, and decisions for KNOWN_GAP and PLANNED_CHANGE entries from
[docs/02-feature-matrix.md](02-feature-matrix.md). BY_DESIGN and OUT_OF_SCOPE entries are
explained inline in the matrix.

---

## G-1: Transitive composition is not flattened (silent fail)

**Gap:** Composing a template that itself composes others does NOT include grandchild functions
in the host. Only direct template functions are injected. The compiler emits no warning -- the
host simply does not get those functions, which can be surprising.

**Root cause:** `inject_template_functions_to_registries` iterates the requested template keys
and injects only their own `FunctionDefinition`s. It does not recurse into what those templates
themselves composed.

**Evidence:** `composition_transitive` -- `mid_value()` is callable (direct template function),
`foo_value()` is silently absent (grandchild, not flattened).

**Decision:** The non-flattening behavior is correct and intentional (D-1 below). The silent fail
is the problem. Planned fix: emit a compiler warning when `inject_template_functions_to_registries`
detects that a selected template itself has composed templates, so the developer knows transitive
functions are NOT included.

**Solidity equivalent:** `C is B, A` flattens the full hierarchy. Gap on flattening is accepted;
the warning closes the UX gap.

---

## G-2: No virtual/override mechanism (resolved)

**Gap:** resolved by PR-3

**Resolution:** Template external functions can be marked `#[template_virtual]`, and hosts can replace
them by declaring `override_template("template_id", "fn_name")` in `AztecConfig`.

compose machinery now:

1. validates override declarations (template exists, target exists, signature exists, not duplicated);
2. requires the target template function to be virtual;
3. skips overridden template functions during both composed function registry injection and template quoted replay;
4. preserves non-overridden template functions and ABI entries in host composition output.

**Evidence:** `composition_override` + `composition_fixtures::virtual_template`

**Solidity equivalent:** `virtual`/`override` (single-level merge-and-replay). There is still no C3 linearization or `super`.

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
- No transitive flattening (G-1); developer must list all templates explicitly
- No override chain today (G-2); single-level replacement implemented in PR-3
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

---

## G-4: Storage field injection blocked on Noir upstream

**Gap:** Host must manually declare every storage field referenced by composed function bodies.
Templates cannot inject fields automatically.

**Blocker:** `TypeDefinition::add_field` does not exist in the Noir comptime API. This is a
language-level change that must be contributed upstream.

**Status:** Blocked. Aztec-side design is documented in `docs/05-future-work.md` under
"Possibilities with Noir support". No Noir issue filed yet.

**Upstream issue:** TBD -- to be filed against https://github.com/noir-lang/noir
