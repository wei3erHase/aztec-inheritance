# Aztec Contract Template Composition

> **What this is:** Production-focused validation of Solidity-style reuse via Aztec contract templates  
> **Status:** Core behavior validated for macro-level composition features  
> **Progress:** 12/18 implemented, 1 upstream-blocked gap, 2 BY_DESIGN, 3 OUT_OF_SCOPE  
> **Mechanism:** Generic contract-template composition via vendored Aztec macro changes

Solidity inheritance lets you write `contract Amm is ERC20 { ... }` and the host gets the full
parent surface. This repo validates how far that model can be implemented in Aztec without new Noir
syntax -- and records the current behavior with executable proofs.

See [docs/02-feature-matrix.md](docs/02-feature-matrix.md) for the full 18-hypothesis comparison.

---

## Quick start

```bash
nargo check   # all workspace packages compile
aztec test    # runs token + AMM behavior tests
```

---

## Repo layout

```
vendor/aztec/              Vendored Aztec macro changes that make template composition work
src/
  aztec-token-mixin/       AIP-20 token template (TokenContractTemplate) + TokenInitParams
  amm_token/               Host contract: Amm = AMM pool + full token at one address
  composition_fixtures/    Minimal foo/bar/mid/storage/virtual templates for hypothesis testing
  composition_multi/       Proof: multi-template compose works
  composition_transitive/  Proof: transitive compose is flattened
  composition_host/        Proof: storage + events + library constants via compose
  composition_override/    Proof: virtual/override mechanism works
  composition_collision_fail/  Poison: name collision => fatal compile error (excluded from workspace)
docs/
  01-architecture.md       How template composition works mechanically
  02-feature-matrix.md     Solidity vs. Aztec: 18 hypotheses with current milestone status (authoritative tracker)
  03-gap-analysis.md       Root causes and decisions for every known gap
  04-template-authoring.md Rules for writing composable templates
  05-future-work.md        What remains: storage injection (blocked on Noir upstream)
  06-development-workflow.md  PR workflow, branch conventions, poison-pattern testing
  07-design-decisions-and-progress.md  Agent inheritance playbook (good practices, no-gos, validation)
```

---

## How it works in one picture

**Template** (registered once, in its own crate):

```noir
#[contract_template("aip20_token")]
#[aztec]
pub contract TokenContractTemplate { ... }
```

**Host** (opts into the template during its own `#[aztec]` pass):

```noir
#[aztec(AztecConfig::new().compose("aip20_token"))]
pub contract Amm { ... }
```

The host gets the full composed external + internal surface as if those functions had been written
directly in `Amm`. Read [docs/01-architecture.md](docs/01-architecture.md) for the full mechanism.

---

## Solidity comparison: what works today

| Solidity feature | Aztec today |
|---|---|
| Inherit a full contract surface | Yes (`compose("id")`) |
| Call inherited internals from host | Yes |
| Read/write inherited storage fields | Yes (host declares fields; template uses them by name) |
| Library method constants cross-crate | Yes (`#[contract_library_method]`) |
| Transitive inheritance flattening | Yes (recursive compose flattening) |
| Event types available in derived contract | Yes (template events auto-replayed) |
| `virtual`/`override` single function | Yes (`#[template_virtual]` + `override_template(...)`) |
| Abstract contracts (all-virtual surface) | Yes (convention via `#[template_virtual]` on all externals) |
| Constructor/initializer chain | Yes (host calls template init internal explicitly) |
| Name collision is a hard error | Yes |
| `super` dispatch | No -- flat merge only, no chain |
| Automatic storage field injection | No -- host must declare fields (Noir upstream blocker) |

Full evidence table: [docs/02-feature-matrix.md](docs/02-feature-matrix.md)

---

## Known limitations

- **Host declares all template storage fields manually** -- `TypeDefinition::add_field` does not
  exist in the Noir comptime API. This is the only remaining functional gap.
  See [docs/03-gap-analysis.md](docs/03-gap-analysis.md) G-4 and [docs/05-future-work.md](docs/05-future-work.md).
- **No `super` dispatch** -- Aztec composition is a flat merge. There is no parent-implementation
  concept. This is architectural (BY_DESIGN), not a gap.
- **Raw module-scope globals cannot be used in composable function bodies** -- use
  `#[contract_library_method]` for template-owned constants. See [docs/04-template-authoring.md](docs/04-template-authoring.md).

---

## Design decisions and milestone notes

To keep the evolution story clean while removing historical folders, key design decisions and
engineering tradeoffs are now consolidated in:

- [docs/07-design-decisions-and-progress.md](docs/07-design-decisions-and-progress.md)

---

## Read order

1. [docs/02-feature-matrix.md](docs/02-feature-matrix.md) -- the comparison: what Aztec can do vs. Solidity
2. [docs/01-architecture.md](docs/01-architecture.md) -- understand the mechanism behind the comparison
3. [docs/03-gap-analysis.md](docs/03-gap-analysis.md) -- why each gap exists, and what's planned
4. [docs/04-template-authoring.md](docs/04-template-authoring.md) -- write your own template
5. [docs/05-future-work.md](docs/05-future-work.md) -- what comes next
