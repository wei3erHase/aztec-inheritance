use aztec::macros::{aztec, contract_template};

pub global HOST_MAGIC: u32 = 123;

#[contract_template("raw_global_probe")]
#[aztec]
pub contract RawGlobalTemplate {
    use aztec::macros::functions::{external, view};

    #[view]
    #[external("public")]
    fn template_magic() -> u32 {
        HOST_MAGIC
    }
}
