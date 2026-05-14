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

## G-2: No virtual/override mechanism (resolved)

**Gap:** resolved by PR-3. Template external functions can be marked `#[template_virtual]`, and hosts
can replace them via `override_template("template_id", "fn_name")` in `AztecConfig`.

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

## G-3: Event structs used by composed bodies are auto-replayed (implemented)

**Gap status:** Implemented.

**Gap:** Host-side `#[event]` type declaration was previously required for event structs defined in templates
that were referenced from composed function bodies.

**Root cause:** Composed function bodies carry raw token streams. The body `{ self.emit(FooEvt {...}) }`
resolves `FooEvt` in the host module's scope at injection time.

This is now closed by replaying template event declarations during composition:

1. `#[contract_template]` stores declarations for all template structs marked `#[event]` in
   `template_registry.nr`.
2. `get_composed_templates_quoted` replays these declarations into the host output.
3. Existing event selector registration remains idempotent to tolerate harmless duplicate registration.

**Evidence:** `composition_host/src/main.nr` now composes `FooStorageTemplate` without a manually declared
`FooEvt` and still compiles/runs via composed `foo_increment`.

**Decision:** Implemented in PR-2.

**Solidity equivalent:** Base contract events are directly usable in derived contracts.

---

## D-1: Compose is merge-and-replay, not hierarchical dispatch

**Decision:** The current implementation is intentionally a "merge-and-replay" model. Functions
from selected templates are concatenated into the host. There is no dispatch hierarchy, no C3
linearization, no implicit ordering.

**Implications:**
- Multi-compose is flat: all templates at the same level with equal precedence
- Transitive flattening (G-1); all composed templates are recursively included by `compose()`
- No override chain today (G-2); single-level replacement implemented in PR-3. Overrides are
  local to the host's compose list and must target a directly composed template id.
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

## D-5: Template ID collision is a silent last-writer-wins overwrite

**Behavior:** `register_template` calls `CHashMap::insert` with no existence check. If two modules
register the same template ID string, the second registration silently overwrites the first across
all registry maps (`TEMPLATE_MODULES`, `TEMPLATE_FUNCTIONS_QUOTED`, `TEMPLATE_ABI_EXPORTS_QUOTED`,
`TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED`, `TEMPLATE_COMPOSED_KEYS`, …).

**Elaboration order determines the winner:**
- Same crate: `mod` declaration order — the module declared later wins.
- Cross-crate: Noir elaborates dependencies before dependents. The root crate (typically the
  host's crate) elaborates last and overwrites any library registration with the same ID.

**Why this matters:** The dangerous scenario is a user accidentally reusing a library template ID.
Their crate is the dependent, so it elaborates last, silently replaces the library template, and
the host composes the wrong module with no error or warning.

**Current status:** No guard exists. `register_template` does not assert on duplicate keys.

**Legitimate use case — version pinning:** If A composes B and C, and both transitively pull in
different implementations of the same interface registered under the same ID (call them D and D'),
A can explicitly pin a preferred version by re-registering that template ID in its own crate. Because
A's crate elaborates last, its registration wins. `flatten_template_keys` deduplicates by key, so
D/D' are treated as one template and A's pinned version is what gets injected and replayed. This is
the one scenario where intentional re-registration is semantically meaningful.

**Future discussion:** An unconditional assert would break version pinning. The right guard is
either (a) an explicit `.pin("d_template", module)` API in the compose config that opts into
intentional replacement, or (b) a `#[contract_template_override("d_template")]` attribute that
signals the re-registration is deliberate. Either approach converts the implicit overwrite into an
explicit, reviewable declaration. Tracked as a separate discussion — no implementation yet.

---

## G-4: Storage field injection blocked on Noir upstream

**Gap:** Host must manually declare every storage field referenced by composed function bodies.
Templates cannot inject fields automatically.

**Blocker:** `TypeDefinition::add_field` does not exist in the Noir comptime API. This is a
language-level change that must be contributed upstream.

**Status:** Blocked. Aztec-side design is documented in `docs/05-future-work.md` under
"Possibilities with Noir support". No Noir issue filed yet.

**Upstream issue:** TBD -- to be filed against https://github.com/noir-lang/noir
