// Poison contract: expected to fail compilation.
//
// `virtual_mid_template` flattens `virtual_template`, which exports `fee_bps`.
// Declaring `fee_bps()` on the host without configuring override triggers
// selector collision handling at compose time.

use aztec::macros::{aztec, AztecConfig};

#[aztec(AztecConfig::new().compose("virtual_mid_template"))]
pub contract OverrideTransitiveCollisionWithoutOverrideHost {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        5
    }
}
