// Poison contract: EXPECTED to fail compilation.
//
// Hypothesis: composing two templates that both expose `foo_value()` causes a compile
// error -- two `__aztec_nr_internals__foo_value` wrappers are injected, which is a
// redefinition. There is no virtual/override mechanism in Aztec compose.
//
// Status: KNOWN_GAP -- function name collision is fatal; no override chain.

use aztec::macros::{AztecConfig, aztec};

#[aztec(AztecConfig::new().compose("foo_template").compose("foo_collision"))]
pub contract CollisionHost {
    use aztec::macros::functions::{external, view};
}
