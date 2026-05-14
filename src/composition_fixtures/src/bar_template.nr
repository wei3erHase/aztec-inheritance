use aztec::macros::{aztec, contract_template};

/// Minimal template used for composition behavior tests.
///
/// Exposed surface:
/// - `bar_value() -> u32`
/// - `bar_double(x: u32) -> u32`
/// - `_bar_marker() -> u32` (public internal helper)
#[contract_template("bar_template")]
#[aztec]
pub contract BarTemplate {
    use aztec::macros::functions::{external, internal, view};

    #[external("public")]
    #[view]
    fn bar_value() -> u32 {
        24
    }

    #[external("public")]
    #[view]
    fn bar_double(amount: u32) -> u32 {
        amount * 3
    }

    #[internal("public")]
    fn _bar_marker() -> u32 {
        3
    }

    #[external("public")]
    #[view]
    fn bar_marker_via_internal() -> u32 {
        self.internal._bar_marker()
    }
}
