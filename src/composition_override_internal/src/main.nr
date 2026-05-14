pub mod test;

use aztec::macros::{aztec, AztecConfig};

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
