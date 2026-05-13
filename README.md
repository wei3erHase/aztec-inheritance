# Aztec Contract Template Composition

> **Status:** Working PoC + test scaffold  
> **Mechanism:** Generic contract-template composition via vendored Aztec macro changes  
> **Flagship example:** `Amm` contract that IS a full AIP-20-style token at the same address

This repo proves that an Aztec contract can be registered as a **reusable template** and injected
into a host contract, so the host behaves as if those functions had been written there directly --
without new Noir syntax.

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
  composition_fixtures/    Minimal foo/bar/mid/storage templates for hypothesis testing
  composition_multi/       Proof: multi-template compose works
  composition_transitive/  Proof: transitive compose is NOT flattened (known gap)
  composition_host/        Proof: storage + events + library constants via compose
  composition_collision_fail/  Poison: name collision => fatal compile error (excluded from workspace)
docs/
  01-architecture.md       How template composition works mechanically
  02-feature-matrix.md     What is proven / what is a known gap (18 hypotheses)
  03-gap-analysis.md       Root causes and decisions for every known gap
  04-template-authoring.md Rules for writing composable templates
  05-future-work.md        Next steps: virtual/override, storage injection, language asks
  archive/                 Superseded planning docs (historical reference)
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

## What is proven

| Claim | Evidence |
|---|---|
| Template functions are injected into host ABI | `composition_multi` tests |
| Host can call composed internals directly | `composition_multi` + `composition_host` tests |
| Composed storage reads/writes work | `composition_host` tests |
| Library method constants migrate cross-crate | `composition_host` tests |
| AMM `add_liquidity` mints LP via composed token internals | `amm_token/test/add_liquidity.nr` |
| Full AIP-20 surface injected into one contract | `amm_token/test/token_surface.nr` |

See [docs/02-feature-matrix.md](docs/02-feature-matrix.md) for the complete 18-hypothesis matrix.

---

## Current limitations (short version)

- Host must declare all template storage fields manually (Noir lacks `TypeDefinition::add_field`)
- Event structs used in composed bodies must be re-declared in the host
- No virtual/override: same-name collision is a fatal compile error
- Transitive composition is not flattened (must list all templates explicitly)
- Raw module-scope globals cannot be used in composable function bodies

See [docs/03-gap-analysis.md](docs/03-gap-analysis.md) for root causes and workarounds.

---

## Read order

1. [docs/01-architecture.md](docs/01-architecture.md) -- understand the mechanism
2. [docs/02-feature-matrix.md](docs/02-feature-matrix.md) -- what works and what doesn't
3. [docs/03-gap-analysis.md](docs/03-gap-analysis.md) -- why, and what's planned
4. [docs/04-template-authoring.md](docs/04-template-authoring.md) -- write your own template
5. [docs/05-future-work.md](docs/05-future-work.md) -- what comes next
