# Template Authoring Guide

> **Status:** Current  
> **Audience:** Developers writing composable Aztec contract templates  
> **Last updated:** 2026-05-13

Rules for writing a contract template that composes cleanly into a host. These rules exist because
composition is **merge-and-replay**, not Solidity-style inheritance -- the host's scope is the
resolution context for all injected function bodies.

---

## Core contract

**The host module is the resolution context.** Every identifier in a composed function body --
global names, storage fields, event types, trait methods, helper functions -- must resolve in the
host module at injection time. The template's own scope does not carry over.

This drives the template authoring model:

1. Global names in composable bodies are **host-provided bindings** -- the host decides the value
2. Template-owned constants must go through `#[contract_library_method]` (not raw globals)
3. Event structs referenced in composed bodies are replayed automatically from template declarations
4. Storage fields referenced in composed bodies must be declared in the host
5. Trait imports needed by composed bodies must be present in the host
6. All composed function names must be unique across the host and all composed templates

---

## Template author rules

### 1. Register with `#[contract_template("id")]`

Place the template in its own crate. Apply `#[contract_template("id")]` before `#[aztec]`:

```noir
#[contract_template("my_template")]
#[aztec]
pub contract MyTemplate { ... }
```

The id string is how hosts reference this template. Choose a stable, unique, human-readable id.

### 2. Use only composable function kinds

Functions that compose cleanly:

| Kind | Annotation | How it migrates |
|---|---|---|
| External public/private/utility | `#[external("public")]` etc. | Body captured as `Quoted`, replayed in host |
| Internal public/private | `#[internal("public")]` etc. | Body captured as `Quoted`, replayed in host |
| Library helper | `#[contract_library_method]` | Migrated via `f.as_typed_expr()` -- no body tokens |

### 2b. Mark overridable template methods

Add `#[template_virtual]` to any external function that a host may replace.

```noir
use aztec::macros::functions::{external, template_virtual, view};

#[template_virtual]
#[external("public")]
#[view]
fn fee_bps() -> u16 {
    30
}
```

The function is still implemented normally in the template. The host replaces it with
`override_template("template_id", "fee_bps")` and its own same-signature function body.

Guidance:

- Non-virtual template functions cannot be overridden.
- A host override must match the full signature (name + parameter types).
- A template where all external methods are virtual is an abstract template by convention.

### 3. Two patterns for constants: template-owned vs host-provided

There is no way for a template to self-reference its own module globals in composable function
bodies. The body is elaborated by `#[aztec]` during template compilation inside the contract block
context, where module-scope globals are not accessible. (If Noir gains `crate::` self-reference in
comptime contexts, stable qualified paths would fix this.)

**Pattern A -- template-owned constant (fixed value, implementation detail):**
Use `#[contract_library_method]`. These migrate via `f.as_typed_expr()` (a typed reference to the
original function) and always resolve correctly, cross-crate:

```noir
#[contract_library_method]
fn _initial_notes() -> u32 { 2 }

#[external("public")]
fn do_thing() {
    let n = _initial_notes();  // resolves via typed reference, always works
}
```

**Pattern B -- host-provided binding (parameterizable, host decides the value):**
Reference the name unqualified in the body. The name resolves in host scope at injection time.
Document it as a host requirement. The host can import it from the template's crate or declare its
own:

```noir
// Template: body references FOO_CONFIG -- host must provide this name
#[external("public")]
fn use_config() -> u32 {
    FOO_CONFIG  // host-scope binding; template does not define this
}

// Host option A: import from the template crate
use my_template::FOO_CONFIG;

// Host option B: override with a local value
pub global FOO_CONFIG: u32 = 99;
```

This makes templates parameterizable: the host is not locked into the template's value, it
decides what each host-expected global contains. Publish the list of host-provided bindings in
the template's host requirements document (see rule 4).

**Guidance on choosing the pattern:**

| Intent | Use |
|---|---|
| Fixed implementation constant (host must not change it) | `#[contract_library_method]` (Pattern A) |
| Configurable constant (host sets the value) | Host-provided binding (Pattern B) |
| Future: immutable at deploy time | Awaiting an `#[immutable]`-style macro |

If you want to expose a global as part of the template's public API (so the host CAN import it),
declare it in a dedicated module and ensure it is accessible via a fully-qualified path. Do NOT
count on the host using your template's version -- the host may override the binding with its own
value. If immutable behavior matters, enforce it through `#[contract_library_method]`, which
cannot be overridden by the host.

### 4. Publish a host requirements document

Hosts cannot figure out what they need by looking at the template's ABI alone. You must document:

- **Storage fields:** every field name and type that composed bodies reference via `self.storage.*`
- **Imports/traits:** any trait or import that composed bodies need in the host's `use` block
- **Initializer call:** the composed internal the host constructor must call, and the parameters

Example for the AIP-20 token template:

```
Storage fields required in host:
  name: PublicImmutable<FieldCompressedString, Context>
  symbol: PublicImmutable<FieldCompressedString, Context>
  decimals: PublicImmutable<u8, Context>
  private_balances: Owned<BalanceSet<Context>, Context>
  total_supply: PublicMutable<u128, Context>
  public_balances: Map<AztecAddress, PublicMutable<u128, Context>, Context>
  minter: PublicImmutable<AztecAddress, Context>

Imports required in host:
  use aztec::protocol::traits::FromField;

Initializer:
  Call self.internal._initialize_token(TokenInitParams { name, symbol, decimals, minter })
  from the host's own constructor.
```

### 5. Use name prefixes to avoid collisions

Since unmarked collisions remain fatal, use template-specific prefixes:

- External functions: `foo_get()`, `foo_increment()` (not `get()`, `increment()`)
- Internal helpers: `_foo_set()`, `_foo_validate()` (underscore + prefix)
- Library methods: `_foo_magic()` (same convention)
- Events: `FooEvt`, `FooTransfer` (not `Evt`, `Transfer` unless sharing a canonical event)

### 6. Declare the initializer as an internal

The initialization path for a template should be a `#[internal("public")]` function, not a
`#[initializer]` on the host. This keeps the host in control of its own constructor:

```noir
// Template: internal init, not an initializer
#[internal("public")]
fn _initialize_token(params: TokenInitParams) {
    self.storage.name.initialize(FieldCompressedString::from_string(params.name));
    // ...
}

// Host: own initializer calls the composed internal
#[initializer]
#[external("public")]
fn constructor(name: str<31>, ...) {
    self.internal._initialize_token(TokenInitParams { name, ... });
    // host-specific init
}
```

---

## Host author rules

### 1. Compose template entry points (transitive closure is automatic)

Compose chains are flattened recursively. If `mid_template` composes `foo_template` internally,
composing `mid_template` also includes `foo_template` and its transitive dependencies automatically:

```noir
#[aztec(AztecConfig::new().compose("foo_template").compose("bar_template"))]
```

### 2. Declare all required storage fields

Copy the template's storage requirements into your host's Storage struct. Order is your choice;
slots are assigned by declaration order in `Storage::init`.

```noir
#[storage]
struct Storage<Context> {
    // foo_storage template fields (required by composed function bodies)
    foo_counter: PublicMutable<u32, Context>,
    // host-specific fields
    my_field: PublicMutable<u64, Context>,
}
```

### 3. Event structs are auto-replayed

Template event structs marked `#[event]` are now replayed into the host during compose, so hosts do not
redeclare them unless customization is intentionally required.

### 4. Call the template's init internal from your constructor

```noir
#[initializer]
#[external("public")]
fn constructor(name: str<31>, symbol: str<31>, decimals: u8, token_a: AztecAddress, ...) {
    self.internal._initialize_token(TokenInitParams { name, symbol, decimals, minter: self.context.this_address() });
    self.storage.token_a.initialize(token_a);
    // ...
}
```

### 5. Document your composed surface

Add a header comment listing your composed templates and what they provide:

```noir
// Composed templates:
//   aip20_token -- full AIP-20 token surface (transfer, mint, burn, balance views)
// Host-declared storage: token fields (name, symbol, ...) + AMM fields (reserve_a, reserve_b, ...)
// Host-declared events: Transfer
// Required by template: FromField trait import
```

## Host override rules

### 1. Declare overrides in `AztecConfig`

```noir
use aztec::macros::AztecConfig;

#[aztec(
    AztecConfig::new()
        .compose("virtual_template")
        .override_template("virtual_template", "fee_bps")
)]
pub contract Host {
    ...
}
```

### 2. Provide the replacement body in the host contract

```noir
use aztec::macros::functions::{external, view};

#[external("public")]
#[view]
fn fee_bps() -> u16 {
    5
}
```

### 3. Keep replacements single-level

Override is local to the host. There is no `super` chain in this MVP.

---

## Quick checklist before opening a PR

- [ ] Template functions use only `#[external]`, `#[internal]`, `#[contract_library_method]`
- [ ] No raw module-scope globals referenced in composable function bodies
- [ ] Template has a published host requirements document (storage fields, imports, init call)
- [ ] All template function/event names are prefixed to avoid collisions
- [ ] Host declares all required storage fields from every composed template
- [ ] Validate that required events are replayed from composed templates (no manual redeclare needed)
- [ ] Host constructor calls `_initialize_<template>()` for every composed template that requires init
- [ ] All directly composed template ids are intentionally chosen (transitive dependencies are auto-included)
- [ ] A positive surface test exists (composed externals callable)
- [ ] A negative collision test or naming convention prevents accidental name overlap
