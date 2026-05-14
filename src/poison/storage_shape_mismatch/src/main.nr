// Poison contract: expected to fail compilation.
//
// Hypothesis: two templates (through transitive composition) depend on `foo_counter`.
// If host declares `foo_counter` with a different type than the template expects,
// composition should fail at compile time with a type mismatch.

use aztec::macros::{aztec, AztecConfig};

#[aztec(AztecConfig::new().compose("foo_storage"))]
pub contract StorageShapeMismatchHost {
    use aztec::{
        macros::{events::event, storage::storage},
        state_vars::PublicMutable,
    };

    // Declaring the same event shape required by `foo_storage_template`.
    #[event]
    struct FooEvt {
        value: u32,
    }

    #[storage]
    struct Storage<Context> {
        // Intentionally wrong shape.
        foo_counter: PublicMutable<bool, Context>,
    }
}
