use aztec::macros::{aztec, contract_template};

/// Minimal template used for composition behavior tests.
///
/// Exposed surface:
/// - `foo_value() -> u32`
/// - `foo_double(x: u32) -> u32`
/// - `_foo_marker() -> u32` (public internal helper)
#[contract_template("foo_template")]
#[aztec]
pub contract FooTemplate {
    use aztec::macros::functions::{external, internal, view};

    #[external("public")]
    #[view]
    fn foo_value() -> u32 {
        12
    }

    #[external("public")]
    #[view]
    fn foo_double(amount: u32) -> u32 {
        amount * 2
    }

    #[internal("public")]
    fn _foo_marker() -> u32 {
        2
    }

    #[external("public")]
    #[view]
    fn foo_marker_via_internal() -> u32 {
        self.internal._foo_marker()
    }
}
