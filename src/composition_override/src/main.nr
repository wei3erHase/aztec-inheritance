use aztec::macros::{aztec, AztecConfig};

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

#[aztec(
    AztecConfig::new().compose("internal_override_template").override_internal_template(
        "internal_override_template",
        "_internal_magic",
    ),
)]
pub contract InternalOverrideHost {
    use aztec::macros::functions::internal;

    /// Host-specific internal replacement for template helper.
    #[internal("public")]
    fn _internal_magic(value: u16) -> pub u16 {
        value * 2
    }
}
