use aztec::macros::{aztec, contract_template};

/// Non-virtual internal helper template used as a negative inheritance test fixture.
#[contract_template("internal_override_non_virtual_template")]
#[aztec]
pub contract InternalOverrideNonVirtualTemplate {
    use aztec::macros::functions::{external, internal};

    #[internal("public")]
    fn _internal_magic(value: u16) -> u16 {
        value + 2
    }

    #[external("public")]
    fn internal_magic_probe() -> u16 {
        self.internal._internal_magic(7)
    }
}
