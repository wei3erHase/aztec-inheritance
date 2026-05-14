use aztec::macros::{aztec, AztecConfig, contract_template};

/// Left template that composes the conflicting leaf. Used in poison cases where two
/// transitive dependencies expose the same selector name from different templates.
#[contract_template("transitive_diamond_left_conflict_template")]
#[aztec(AztecConfig::new().compose("transitive_diamond_conflict_leaf"))]
pub contract TransitiveDiamondLeftConflictTemplate {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn left_conflict_value() -> pub u32 {
        700
    }
}
