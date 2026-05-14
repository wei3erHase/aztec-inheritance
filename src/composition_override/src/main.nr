use aztec::macros::{aztec, AztecConfig};

pub mod test;

#[aztec(
    AztecConfig::new().compose("virtual_template").override_template("virtual_template", "fee_bps"),
)]
pub contract VirtualOverrideHost {
    use aztec::macros::functions::{external, view};

    /// Host-specific fee implementation replaces template's fee_bps().
    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        5
    }
}
