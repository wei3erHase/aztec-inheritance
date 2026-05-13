use aztec::macros::{aztec, contract_template};

/// Template for testing raw global constant migration (hypothesis: FAILS).
///
/// FOO_RAW_MAGIC is a module-level global. When foo_read_raw_global() body is injected
/// into a host contract, FOO_RAW_MAGIC is not in the host scope -> compile failure.
///
/// This template is intentionally not composable without also importing FOO_RAW_MAGIC
/// into the host. It exists solely to drive the poison compile-failure test.
pub global FOO_RAW_MAGIC: u32 = 99;

#[contract_template("foo_raw_global")]
#[aztec]
pub contract FooRawGlobalTemplate {
    use aztec::macros::functions::{external, view};

    /// References FOO_RAW_MAGIC from module scope.
    /// When composed into a host, FOO_RAW_MAGIC is not in host scope -> compile failure.
    #[view]
    #[external("public")]
    fn foo_read_raw_global() -> u32 {
        FOO_RAW_MAGIC
    }
}
