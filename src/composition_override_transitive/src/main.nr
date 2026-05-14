pub mod test;

use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new()
        .compose("virtual_mid_template")
        .compose("virtual_template")
        .override_template("virtual_template", "fee_bps"),
)]
pub contract TransitiveOverrideHost {
    use aztec::macros::functions::{external, view};

    /// Host-specific fee implementation replaces the virtual `fee_bps()` defined in `virtual_template`.
    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        5
    }
}
