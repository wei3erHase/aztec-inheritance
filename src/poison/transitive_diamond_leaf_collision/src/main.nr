// Poison contract: EXPECTED to fail compilation.
//
// The host composes two transitive branches that expose the same selector
// `leaf_value()`, but from different template IDs:
// - transitive_diamond_left_conflict_template -> transitive_diamond_conflict_leaf
// - transitive_diamond_right_conflict_template -> transitive_diamond_leaf
//
// This verifies that transitive duplicate selectors are rejected regardless of
// how many composition layers they are pulled through.

use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new()
        .compose("transitive_diamond_left_conflict_template")
        .compose("transitive_diamond_right_conflict_template")
)]
pub contract TransitiveDiamondLeafCollisionHost {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn get() -> pub u32 {
        1
    }
}
