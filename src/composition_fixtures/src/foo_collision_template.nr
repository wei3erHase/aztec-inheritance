use aztec::macros::{aztec, contract_template};

/// Collision template: deliberately exposes `foo_value()` -- same name as in foo_template.
/// Used by the composition_collision_fail poison package to confirm that composing two
/// templates with an overlapping function name causes a compile error.
/// There is no override/virtual mechanism in Aztec compose.
#[contract_template("foo_collision")]
#[aztec]
pub contract FooCollisionTemplate {
    use aztec::macros::functions::{external, view};

    /// Same name as foo_template::foo_value -- triggers collision when both are composed.
    #[external("public")]
    #[view]
    fn foo_value() -> u32 {
        999
    }
}
