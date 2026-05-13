// Poison contract: EXPECTED to fail compilation.
//
// Composes foo_storage template but declares an empty Storage struct.
// The composed function bodies (foo_increment, foo_get, _foo_set) access
// self.storage.foo_counter, which does not exist on this Storage struct.
//
// This validates the requirement from the host authoring guide: every storage
// field referenced by composed template bodies MUST be declared in the host's
// Storage struct.

use aztec::macros::{aztec, AztecConfig};

#[aztec(AztecConfig::new().compose("foo_storage"))]
pub contract MissingStorageVar {
    use aztec::macros::storage::storage;

    #[storage]
    struct Storage<Context> {
        // foo_counter intentionally omitted -- composed bodies will fail to resolve it
    }
}
