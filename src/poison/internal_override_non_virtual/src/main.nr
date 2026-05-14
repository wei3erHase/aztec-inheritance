// Poison contract: expected to fail compilation.
//
// This template internal helper is not marked virtual, so host override must be rejected.
use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new()
        .compose("internal_override_non_virtual_template")
        .override_internal_template("internal_override_non_virtual_template", "_internal_magic"),
)]
pub contract InternalOverrideNonVirtualHost {
    use aztec::macros::functions::internal;

    #[internal("public")]
    fn _internal_magic(value: u16) -> u16 {
        value * 10
    }
}
