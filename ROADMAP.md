# Roadmap: Aztec Contract Template Composition

> **Status:** M2 complete, M3 done (basic surface), M4 planned  
> **Last updated:** 2026-05-13

---

## Milestones

| ID | Milestone | Status | Notes |
|----|-----------|--------|-------|
| M0 | ADR + workspace setup | Done | Workspace, repo isolation, initial architecture decisions |
| M2 | Generic template composition PoC + test scaffold | Done | Generic vendor machinery; token mixin as first consumer; all 18 hypotheses validated |
| M3 | Basic test surface | Done | Core behavior tests pass; full parity not planned |
| M4 | Virtual/override mechanism + abstract templates | Planned | Macro-level only; see docs/05-future-work.md for design |
| M5 | Docs, migration guide, security review | Planned | After M4 |

---

## Current state (post-M2)

**What was built:**

- Generic `#[contract_template("id")]` + `AztecConfig::new().compose("id")` machinery in vendored Aztec macros
- `TokenContractTemplate` (AIP-20 surface) as first real consumer
- `Amm` host contract: AMM pool + full token at one address, 4 developer-written functions, 24 token functions generated
- Test scaffold: `composition_fixtures`, `composition_multi`, `composition_transitive`, `composition_host`, `composition_collision_fail` (poison)
- 18 Solidity inheritance hypotheses validated (10 IMPLEMENTED, 2 PLANNED_CHANGE, 2 KNOWN_GAP, 2 BY_DESIGN, 3 OUT_OF_SCOPE)

**What compiles and runs:**

```bash
nargo check   # full workspace
aztec test    # 4 amm_token tests pass; composition_multi + composition_transitive tests pass
```

---

## M4: Virtual/override (next)

See `docs/05-future-work.md` PR-3/PR-4 for the full design. In brief:

1. `#[template_virtual]` attribute on template functions marks them as overridable
2. Host declares `#[template_override("template_id")]` OR uses config-level
   `AztecConfig::new().compose("foo").override_template("foo", "fee_bps")`
3. `inject_template_functions_to_registries` skips overridden template functions; host version wins
4. Error on: collision without override declared; override declared for non-virtual function;
   override target not found

Test package: `src/composition_override/`

---

## Open limitations

| ID | Limitation | Status |
|----|-----------|--------|
| G-2 | No virtual/override mechanism; collision is fatal | PR-3/PR-4: M4 planned |
| G-3 | Event structs must be re-declared in host | Not planned; inconvenient but not critical |
| G-4 | Host must manually declare all template storage fields | Blocked on Noir `TypeDefinition::add_field`; design sketch in docs/05-future-work.md |

### 2026-05-13 -- PR-1 transitive composition shipped

Transitive composition is now implemented by recursive flattening at compose expansion (`mid_template` includes its
own transitive dependencies). This closes G-1 in `docs/03-gap-analysis.md`.

---

## Decision log

### 2026-05-13 -- removed dead storage-field registry

`TEMPLATE_STORAGE_FIELDS` registry in `vendor/aztec` was kept after L-15 rollback but had no consumer.
Removed. Vendor is now identical to upstream except for the generic compose machinery.

### 2026-05-13 -- compose-aware storage: cost/benefit too low, reverted

Implemented `#[varargs]` on `#[storage]` to accept template IDs and reorder slots. Slot ordering
guarantee and presence validation were marginally better than what the compiler already gave for
free. Rolled back. See docs/03-gap-analysis.md G-4 for full investigation.

### 2026-05-12 -- generic contract-template composition

Replaced token-only singleton registries with keyed template registry. `compose_token()` became
`compose("template-id")`. Template implementations live outside the vendor machinery and register
themselves by id. See docs/01-architecture.md for the current architecture.

### 2026-05-12 -- isolated repo packaging

Vendored only the Aztec macro crates that needed modification (`vendor/aztec`). Left unmodified
upstream-only dependencies on git where crate identity does not force a local copy. Reason: Noir
crate identity is nominal -- crates that depend on `aztec` cannot mix vendored and upstream `aztec`
and still share types safely.

### 2026-05-12 -- `#[contract_library_method]` as the migration path for helpers

Template-local `#[contract_library_method]` helpers migrate via `f.as_typed_expr()` (typed
reference, not body tokens). This is why constants and helpers that need to be accessible in the
host are written as helper functions inside the template, not as raw globals.
