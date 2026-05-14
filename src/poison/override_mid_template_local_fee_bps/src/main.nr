// Poison contract: expected to fail compilation.
//
// Hypothesis: a template that composes `virtual_template` and also defines `fee_bps()`
// collides with the same selector from the composed template, with no local override path.
// In this model, overrides are host-level and explicit via `override_template(...)`.

use aztec::macros::{AztecConfig, aztec, contract_template};

#[contract_template("override_mid_template_local_fee_bps")]
#[aztec(AztecConfig::new().compose("virtual_template"))]
pub contract OverrideMidTemplateLocalFeeBps {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn fee_bps() -> pub u16 {
        5
    }

    #[external("public")]
    #[view]
    fn virtual_mid_value() -> pub u16 {
        11
    }
}
