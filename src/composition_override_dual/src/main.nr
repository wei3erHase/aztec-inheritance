pub mod test;

use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new()
        .compose("virtual_fee_override_template")
        .compose("virtual_template")
        .override_template("virtual_fee_override_template", "fee_bps")
        .override_template("virtual_template", "fee_bps"),
)]
pub contract DualOverrideTransitiveHost {
    use aztec::macros::functions::{external, view};

    /// Host-specific fee implementation replaces both template selectors.
    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        9
    }
}
