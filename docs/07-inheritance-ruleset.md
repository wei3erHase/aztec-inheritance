# Aztec Composition Inheritance Ruleset (v1)

**Last updated:** 2026-05-13  
**Status:** Practical working model

This is the discussion document for inheritance-like composition.
It records assumptions, edge cases, and what to validate before treating a behavior as stable.

## What this model is

Aztec composition is **flattening by explicit template inclusion**, not class-style inheritance.

- You list templates in `AztecConfig::new().compose(...)`.
- The compiler copies template functions into the host by registry merge.
- There is no hidden parent/child dispatch chain.

## Core rules

1. **Flat, recursive inclusion**

   If a composed template `C` composes `D`, composing `C` also composes `D`.
   A host can call `D` methods as if they were in `C`.

2. **Only what you list is included**

   Behavior must come from the host’s compose list (plus recursive transitive closure),
   not from implicit import magic.

3. **One selector, one meaning**

   Public ABI selectors across host + all transitive templates must be unique.
   A duplicate selector is a hard failure.

4. **Host owns storage**

   Templates reference storage by name; the host declares and owns storage fields.

5. **Host global-name resolution is currently limited**

   Templates should be standalone and explicit, but raw unqualified global names are not
   reliably injected through composition today.
   Event types and shared helpers still need host-visible declarations/migration patterns.

6. **No auto event/type injection**

   Event structs and similar non-registry declarations are not injected automatically.
   The host must declare them.

7. **No override chain today**

   `super`, Solidity `virtual/override`, and C3-style MRO are not in this model yet.
   Duplicate names are rejected.

8. **Storage field name + shape collisions are a host responsibility**

   If two composed templates use the same storage name with different types, the host decides
   a single field type and the mismatch should surface as a compile-time type error in the
   template body that expects a different shape.

   If types match, they intentionally share that field.

## Concrete testing rules

For each feature, we test three things:

- `PASS`: can be composed and called as expected.
- `POISON`: must not compile (negative PoC proving what must never be allowed).
- `DOC`: behavior is mirrored in implementation notes and gap analysis.

### Flattening and dispatch

- `composition_transitive` should show host can call:
  - direct template method
  - child method
  - grandchild method

### Selector collision

- `composition_collision_fail` should compile-fail on duplicate selector.
- The transitive collision case is the same rule (single transitive poison is enough).

### Storage ownership

- `composition_host` should read/write host-owned fields via template code.
- Missing required field in host should be a compile-time break.
- Same name + same type should compile (shared field).
- Same name + different type should be a compile-time break (shape conflict).

### Host-scope symbol resolution limitations

- `host_global_scope_resolved_limit` should fail at compile-time, proving raw host-global symbol
  resolution is not available through composed body replay.

### Event declaration behavior

- Host must re-declare event structs used by composed code.
- Omitting declarations should be compile-time break.

## Planned model expansions (not yet in current model)

- Virtual/override mechanism
- Abstract templates

These are intended features and will be introduced only after explicit design and tests are added.

## Poisons (non-negotiable "must not compile")

1. Duplicate selector across host/transitive templates.
2. Composed function references unresolved host symbol.
3. Composed function references missing storage field.
4. Shared storage field same name but different type should fail.

If any of these compile, the ruleset is broken.
