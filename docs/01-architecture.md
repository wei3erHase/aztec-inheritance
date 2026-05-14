# Architecture: How Template Composition Works

> **Status:** Current  
> **Audience:** Developers integrating or extending the composition mechanism  
> **Last updated:** 2026-05-13

Template composition lets an Aztec contract be registered as a named template and then injected
into a host contract, so the host behaves as if the template functions were written there directly.
No new Noir syntax is required.

---

## The core trick: double `#[aztec]`

A template contract is processed twice:

1. Once as a real `#[aztec]` contract in its own crate (type-checks, generates wrappers)
2. Once as a source of pre-generated code replayed into the host

```noir
// Template crate
#[contract_template("aip20_token")]
#[aztec]
pub contract TokenContractTemplate { ... }

// Host crate
#[aztec(AztecConfig::new().compose("aip20_token"))]
pub contract Amm { ... }
```

---

## Step-by-step flow

### 1. Template registers itself

`#[contract_template("id")]` runs on the template module and precomputes:

- Generated wrappers for all `#[external(...)]` functions
- Generated wrappers for all `#[internal(...)]` functions
- ABI export structs
- Generated forwarding wrappers for `#[contract_library_method]` helpers (via `f.as_typed_expr()`)

Results are stored in a keyed global registry under the template id.

Key files:
- `vendor/aztec/src/macros/mod.nr` -- `contract_template` macro
- `vendor/aztec/src/macros/template_registry.nr` -- keyed storage

### 2. Template is also processed as a normal `#[aztec]` contract

`#[aztec]` still runs on the template contract in its own crate. This is what `#[contract_template]`
reads to know which functions are external/internal and how to generate their wrappers.

### 3. Host requests composition

`AztecConfig::compose("id")` adds a template id to the host config. Before the host's normal Aztec
codegen runs:

- The selected template module's `FunctionDefinition`s are injected into the host's composed
  registries (external + internal)

Key file: `vendor/aztec/src/macros/compose_template.nr`

### 4. Host codegen sees the union of host + template functions

Once template `FunctionDefinition`s are in the composed registries, the normal generators for:
- external call interface
- self-call stubs
- internal-call helpers
- ABI exports
- dispatch

all see both host-authored and template-composed functions. The host gets the composed surface
without having written template functions in source.

### 5. Pre-generated quoted code is replayed

The host also needs the actual wrapper bodies. These are pulled from the template registry and
appended to the host's generated output. This is the key workaround for Noir's cross-crate body
limitation: function bodies are captured in the template crate (where they are in scope) and
replayed in the host crate.

Key files:
- `vendor/aztec/src/macros/compose_template.nr` -- `get_composed_templates_quoted`
- `vendor/aztec/src/macros/aztec.nr` -- injection point in host codegen

---

## Why `#[contract_library_method]` helpers migrate cleanly

Regular function bodies (`f.body()`) are captured as raw token streams. When replayed in the host,
identifiers must resolve in the host module's scope -- which means raw globals and event structs
must be re-declared in the host (see [docs/03-gap-analysis.md](03-gap-analysis.md) G-4 through G-6).

`#[contract_library_method]` functions are different: they are captured via `f.as_typed_expr()`,
a typed reference to the original function. The generated wrapper in the host calls through to the
original template function directly, so no name resolution in the host scope is needed.

This is why constants and helpers that need to cross the template/host boundary are written as
`#[contract_library_method]` functions, not raw globals.

---

## What the host must provide

Composition does not mean "any host works automatically." The host must satisfy the template's
assumptions:

| Assumption | Consequence of missing |
|---|---|
| Storage fields with matching names and types | Compile error when composed body references `self.storage.foo` |
| Event struct declarations matching template usage | Compile error when composed body does `self.emit(FooEvt {...})` |
| Initializer call to template's init internal | Runtime: uninitialized storage fields |
| `FromField` / other trait imports where composed bodies need them | Compile error |

There is no dedicated validation pass today. Failures surface as normal type or codegen errors.
See [docs/04-template-authoring.md](04-template-authoring.md) for the explicit contract a template
author must publish for host authors.

---

## Multi-template compose

A host can compose multiple templates:

```noir
#[aztec(AztecConfig::new().compose("foo_template").compose("bar_template"))]
pub contract MultiHost { ... }
```

All template ids are iterated in `inject_template_functions_to_registries`. The resulting host
gets the union of all template surfaces. Function name collisions between templates (or between
a template and the host) are fatal unless an override is declared via
`override_template("template_id", "fn_name")` in `AztecConfig`.

---

## What composition is NOT

- **No inheritance hierarchy:** this is merge-and-replay, not Solidity-style inheritance.
  There is no `super` dispatch or C3 linearization; composed function sets are flattened
  into a single host surface.
- **No `super`:** virtual/override is single-level only. A host can replace a template function
  via `override_template("id", "fn")`, but cannot call the original template implementation from
  the override. There is no parent-implementation concept in a flat merge.
- **Not automatic for storage:** fields must be manually declared in the host.
- **Not a new language feature:** this is purely macro-level, working within Noir's existing
  comptime system.

See [docs/02-feature-matrix.md](02-feature-matrix.md) for the full evidence table, and
[docs/03-gap-analysis.md](03-gap-analysis.md) for root causes and planned fixes.

---

## Vendor changes summary

All changes are in `vendor/aztec/src/macros/`:

| File | Change |
|---|---|
| `aztec.nr` | `AztecConfig` grew `compose("id")` + `override_template("id","fn")` support; host codegen injects composed functions before dispatch generation |
| `mod.nr` | `#[contract_template("id")]` registration macro; captures external wrappers per-function and event structs |
| `template_registry.nr` | Keyed registry: template module, per-function wrappers, ABI exports, library helpers, event structs, virtual flags |
| `compose_template.nr` | `inject_template_functions_to_registries` (override-aware) + `get_composed_templates_quoted` (override-aware, events) + `compute_template_override_signatures` |
| `internals_functions_generation/external_functions_registry.nr` | Composed external functions merged into host registries |
| `internals_functions_generation/internal_functions_registry.nr` | Same for composed internals |
| `events.nr` | `register_event_selector` made idempotent for same-name/same-signature re-registration |
