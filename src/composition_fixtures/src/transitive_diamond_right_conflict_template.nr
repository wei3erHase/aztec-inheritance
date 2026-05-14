use aztec::macros::{aztec, AztecConfig, contract_template};

/// Right template that composes the shared non-conflicting leaf.
/// Used with `transitive_diamond_left_conflict_template` to assert the same method
/// selector conflicts are rejected when it comes from two different templates.
#[contract_template("transitive_diamond_right_conflict_template")]
#[aztec(AztecConfig::new().compose("transitive_diamond_leaf"))]
pub contract TransitiveDiamondRightConflictTemplate {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn right_conflict_value() -> pub u32 {
        800
    }
}
