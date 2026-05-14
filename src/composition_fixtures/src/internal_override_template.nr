use aztec::macros::{aztec, contract_template};

/// Template used for internal helper override tests.
#[contract_template("internal_override_template")]
#[aztec]
pub contract InternalOverrideTemplate {
    use aztec::macros::functions::{external, internal, template_virtual, view};

    #[internal("public")]
    #[template_virtual]
    fn _internal_magic(value: u16) -> u16 {
        value + 1
    }

    #[external("public")]
    #[view]
    fn internal_magic_probe() -> u16 {
        self.internal._internal_magic(7)
    }
}
