// Poison contract: EXPECTED to fail compilation.
//
// Same transitive selector collision as the existing diamond leaf case, but mirrored:
// - `transitive_diamond_left_conflict_template` contributes `leaf_value()` from
//   `transitive_diamond_conflict_leaf`.
// - `transitive_diamond_right_template` contributes `leaf_value()` from
//   `transitive_diamond_leaf`.
//
// If collision behavior is order-independent, this should fail with the same
// selector collision diagnostics.
use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new()
        .compose("transitive_diamond_left_conflict_template")
        .compose("transitive_diamond_right_template")
)]
pub contract TransitiveDiamondLeafCollisionMirrorHost {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn get() -> pub u32 {
        2
    }
}
