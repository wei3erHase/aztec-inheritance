use aztec::macros::{aztec, AztecConfig, contract_template};

/// A virtual-function template wrapped behind a second layer.
///
/// This template is used to verify transitive composition and override behavior:
/// host contracts composing only this template still see virtual_template's behavior,
/// but override targets must explicitly compose the overridden template id.
#[contract_template("virtual_mid_template")]
#[aztec(AztecConfig::new().compose("virtual_template"))]
pub contract VirtualMidTemplate {
    use aztec::macros::functions::{external, view};

    /// Distinguishes values contributed by this template.
    #[external("public")]
    #[view]
    fn virtual_mid_value() -> u16 {
        11
    }
}
