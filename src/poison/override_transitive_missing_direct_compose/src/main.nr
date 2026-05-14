// Poison contract: expected to fail compilation.
//
// Even with transitive flattening, `override_template` must point to a template id
// that is directly composed by this host.
//
// `virtual_mid_template` composes `virtual_template`, but only the former is
// listed in `compose(...)`, so overriding `virtual_template::fee_bps` must fail.

use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new()
        .compose("virtual_mid_template")
        .override_template("virtual_template", "fee_bps")
)]
pub contract OverrideTransitiveMissingDirectComposeHost {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        5
    }
}
