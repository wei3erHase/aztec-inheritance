use aztec::macros::{aztec, contract_template};

/// Template for virtual override tests.
#[contract_template("virtual_template")]
#[aztec]
pub contract VirtualTemplate {
    use aztec::macros::functions::{external, template_virtual, view};

    /// Default fee basis points, can be overridden by host.
    #[external("public")]
    #[template_virtual]
    #[view]
    fn fee_bps() -> u16 {
        30
    }

    /// Non-virtual template function that should always come from this template.
    #[external("public")]
    #[view]
    fn template_fee_label() -> u16 {
        77
    }
}
