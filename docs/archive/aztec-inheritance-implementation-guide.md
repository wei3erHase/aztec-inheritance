# Aztec Inheritance-Style Composition: Implementation Guide (Current State)

**Last updated:** 2026-05-13
**Status:** PoC-ready, not full Solidity inheritance parity

## 1) What this is (and what it is not)

This implementation provides **template composition**, not Solidity `is`-based inheritance.

- Supported model: compose explicit templates into a host contract with `compose("template_id")`.
- Not supported model: language-level inheritance graph with automatic linearization, implicit transitivity, or `super` dispatch.

Think of it as:

- **Compose = explicit flat merge + replay**
- **Solidity inheritance = class hierarchy + dispatch rules**

## 2) Core mechanism

### 2.1 Core annotations

- Template: `#[contract_template("template_id")]`
- Host: `#[aztec(AztecConfig::new().compose("template_id"))]`

### 2.2 What is captured from a template

The template macro registers for each template id:

- external function wrappers
- internal function wrappers
- ABI exports
- `#[contract_library_method]` bodies as typed expressions

### 2.3 What happens in the host

At host expansion:

- compose ids are read from `AztecConfig`
- template wrappers are injected into host registries
- template bodies are replayed into host as quoted code
- ABI surfaces are merged
- dispatch is generated from merged registries

This is why duplicate names collide as selector errors.

## 3) What inheritance-like behavior works today

- Direct multiple composition is supported when function names are non-colliding.
- Composed externals are externally callable from host.
- Composed internals are callable from host internals.
- Template constants can be reused via `#[contract_library_method]`.
- Host controls storage layout and can expose/initialize fields accessed by composed code.

## 4) What NOT gets registered

The following items are **not** auto-registered/merged by composition:

### 4.1 Template storage schema
- `#[storage]` fields are not injected into host storage.
- `template`/`Storage` layout is not inherited.
- Host must declare fields manually.

### 4.2 Event type declarations
- `#[event]` structs used in template bodies are **not** auto-replayed.
- Host must declare matching event structs in host module scope.

### 4.3 Module-scope globals and helper values
- Unqualified module globals from templates are not reliably available in host composition scope.
- If needed, pass them through a host binding (`pub global`) or use `#[contract_library_method]`.

### 4.4 Imports and traits
- Host-side `use` / trait imports used by composed bodies are not injected.
- Host must import required traits/modules itself.

### 4.5 Transitive compositions
- A template composed by another template is auto-flattened for the host.
- Composing a root template injects transitive dependency functions recursively.

### 4.6 Override chain
- No inheritance-style virtual/override chain exists.
- No `super` dispatch or C3-style linearization.
- Duplicate external names are hard errors unless override is implemented in a future PR.

### 4.7 Constructors / initialization ownership
- A template initializer method is not automatically executed by host constructor.
- Host must call template init internals explicitly.

## 5) Current implications (DX)

- Treat composition as explicit and intentional.
- Do not rely on inheritance behavior unless it is implemented and documented.
- Keep all dependencies and requirements explicit in template docs and host comments.

## 6) Recommended naming/convention

Use prefixes to avoid collisions:

- Externals: `foo_get`, `foo_set`, `foo_transfer`
- Internals: `_foo_set`, `_foo_validate`
- Library helpers: `_foo_magic`
- Events: `FooEvt`, `FooTransfer`

## 7) Minimal test map (PoC level)

Use lightweight Foo/Bar fixtures (non-token) to validate each point:

- direct multi-template merge
- collision failure
- storage field requirement
- event declaration requirement
- recursive flattening of composed chains
- library-method reuse

## 8) Current roadmap items

- PR-1: transitive composition flattening (implemented)
- PR-3: virtual/override MVP
- PR-4: abstract-template convention (depends on PR-3)
- PR-5: storage injection (Noir API dependency)

## 9) Copyable definition

`Aztec composition today is explicit, flat, and non-hierarchical: it reuses contract templates by function/ABI replay and explicit registration, but does not implement Solidity-style inheritance semantics by default.`
