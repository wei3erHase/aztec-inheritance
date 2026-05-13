use aztec::macros::{aztec, AztecConfig, contract_template};

/// Template that composes other templates via #[aztec(...)] compose.
///
/// In the current implementation, this does NOT become a transitive source of
/// composed methods for another host that only composes `mid_template`.
#[contract_template("mid_template")]
#[aztec(AztecConfig::new().compose("foo_template").compose("bar_template"))]
pub contract MidTemplate {
    use aztec::macros::functions::{external, internal, view};

    #[external("public")]
    #[view]
    fn mid_value() -> u32 {
        100
    }

    #[internal("public")]
    fn _mid_marker() -> u32 {
        10
    }

    #[external("public")]
    #[view]
    fn mid_marker_via_internal() -> u32 {
        self.internal._mid_marker()
    }
}
