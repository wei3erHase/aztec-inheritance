# Template Authoring Guide

> **Status:** Current  
> **Audience:** Developers writing composable Aztec contract templates  
> **Last updated:** 2026-05-13

## 0) Agent mindset

Treat this repo as a **composition operator**, not classical inheritance.
The core mental model:

1. Templates contribute callable fragments.
2. Host contributes runtime context, storage, imports, and bindings.
3. Override and collision rules are explicit and compile-time enforced.

When a request cannot be mapped to this model, it is likely a follow-on design discussion.

---

## 1) Core assumptions

**Host module is the resolution context** for every composed function body.

Global names, storage fields, imports, traits, and event types used by composed bodies must be
available in host scope at injection time.

This means templates should be explicit about what the host must provide.

---

## 2) Template author rules

### 2.1 Register with `#[contract_template("id")]`

Place template in its own crate.

```noir
#[contract_template("my_template")]
#[aztec]
pub contract MyTemplate { ... }
```

Use a stable, unique id.

### 2.2 Compose only supported function kinds

Use these for function kinds that participate in merge-and-replay:

| Kind | Annotation | Migration |
|---|---|---|
| External | `#[external("public")]`, etc. | Captured as `Quoted` and replayed in host |
| Internal | `#[internal("public")]`, etc. | Captured as `Quoted` and replayed in host |
| Helper | `#[contract_library_method]` | Migrates via typed expression (`f.as_typed_expr()`), safest for cross-crate constants/helpers |

### 2.3 Decide override intent explicitly

Add `#[template_virtual]` to any external function a host may replace.

```noir
use aztec::macros::functions::{external, template_virtual, view};

#[template_virtual]
#[external("public")]
#[view]
fn fee_bps() -> u16 {
    30
}
```

Host replacement requires compose config:

```noir
AztecConfig::new().compose("my_template").override_template("my_template", "fee_bps")
```

Rules:

- Non-virtual methods cannot be overridden.
- Host override signature must match target method signature.
- Abstract behavior is convention-driven: all externals are virtual + host overrides all.

### 2.4 Separate constants by ownership intent

**Template-owned constants/behaviors:** use `#[contract_library_method]`.

```noir
#[contract_library_method]
fn _initial_notes() -> u32 { 2 }

#[external("public")]
fn do_thing() -> u32 {
    _initial_notes()
}
```

**Host-configurable values:** use unqualified symbol references in body and document them as host
requirements.

```noir
#[external("public")]
fn use_config() -> u32 {
    FOO_CONFIG
}
```

Host can import or define:

```noir
use my_template::FOO_CONFIG;
// or
pub global FOO_CONFIG: u32 = 99;
```

### 2.5 Publish host requirements

Every template should document:

- required storage fields and types,
- required imports/traits,
- template init internal call.

Example:

```
Storage fields:
- name: PublicImmutable<FieldCompressedString, Context>
- symbol: PublicImmutable<FieldCompressedString, Context>
- decimals: PublicImmutable<u8, Context>

Imports:
- use aztec::protocol::traits::FromField;

Init:
- call self.internal._initialize_token(TokenInitParams { ... })
```

### 2.6 Naming to avoid accidental collisions

Use namespace prefixing:

- `foo_get()`, `foo_set()` for externals
- `_foo_validate()` for internals
- `_foo_magic()` for library methods
- `FooEvt` for events

---

## 3) Host author rules

### 3.1 Compose entry points

```noir
#[aztec(AztecConfig::new().compose("foo_template").compose("bar_template"))]
pub contract Host { ... }
```

Transitive templates compose automatically when a template composes another template.

### 3.2 Declare storage required by templates

Host declares every required storage field. Slot order is host-owned.

```noir
#[storage]
struct Storage<Context> {
    foo_counter: PublicMutable<u32, Context>,
    bar_counter: PublicMutable<u32, Context>,
}
```

### 3.3 Event structs

Event structs from template declarations are replayed by compose.
No manual redeclare is required unless host intentionally wants a custom shape.

### 3.4 Run template init from host constructor

```noir
#[initializer]
#[external("public")]
fn constructor(...) {
    self.internal._initialize_token(TokenInitParams { ... });
}
```

### 3.5 Keep override local and explicit

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

#[external("public")]
#[view]
fn fee_bps() -> u16 {
    5
}
```

No `super` semantics exist in this model.

---

## 4) Anti-patterns you should document as poison cases

Treat these as first-class cases when a new template abstraction is added.

| Pattern | Why it is an issue | Example fixture |
|---|---|---|
| Host omitted required storage slot | Composition will compile-check into host-owned storage and fail at composed body type-check (`foo_counter` missing) | `missing_storage_var` |
| Host declared slot with wrong shape | Same symbol name but type mismatch produces field/type errors and should be part of migration planning | `storage_shape_mismatch` |
| Host relies on template module globals | Raw globals are resolved in host scope; template-module-only globals are not inherited | `host_global_scope_resolved_limit`, `foo_raw_global_template` |
| Template emits `FooEvt` and host redeclares same `FooEvt` | Event replay makes duplicate event type definitions a compile error | `event_host_redeclares` |
| Two composed templates own same event type | Flattening + event replay keeps namespace singletons, so duplicate event names collide | `event_collision_across_templates` |
| Missing direct override target | `override_template(id, fn)` must point to a template id explicitly composed by the host | `override_transitive_missing_direct_compose` |
| Partial override in collision set | Any virtual function left un-overridden in the composed surface still collides | `override_transitive_partial_override` |
| Mid-template local selector collision with inherited virtual | Local template function can conflict with composed virtual without host override config | `override_mid_template_local_fee_bps` |
| Transitive duplicate selector | Duplicate selectors from transitive flattening still fail compilation (`leaf_value`) | `transitive_diamond_leaf_collision`, `transitive_diamond_leaf_collision_reverse` |
| Direct template collision path | Directly composing two templates with same external selector remains a hard error | `collision_no_override` |

How to use this table:

- If you touch behavior in this area, keep or add the matching poison case.
- When a fixture is not in automated CI, leave it documented here with explicit manual run command.

---

## 5) Agent review checklist (must pass)

- [ ] All composable functions are `external`, `internal`, or `contract_library_method`
- [ ] No unresolved template-only globals inside composable bodies
- [ ] Host requirements doc exists and includes storage + imports + init call
- [ ] Host storage fields match template names/types
- [ ] Event replay is validated (or intentional override documented)
- [ ] Every override is declared on `compose`d virtual target with matching signature
- [ ] Collision prevention strategy is documented in template/host naming
- [ ] Positive fixture + negative/poison path exist for changed behavior

## 6) Common footguns to flag early

- Assuming private scope from composed functions: composition is flat merge.
- Forgetting host imports for composed trait methods.
- Overusing direct globals for implementation constants.
- Treating duplicate storage names as harmless when shapes differ.
- Expecting chain/linearization behavior in override calls.
