// Poison contract: EXPECTED to fail compilation.
//
// PR-2 auto-replays `FooEvt` from `foo_storage_template` into this host.
// The manual re-declaration below was required before PR-2 but now creates
// a duplicate struct definition in the host module.

use aztec::macros::{events::event, AztecConfig, aztec};

#[aztec(AztecConfig::new().compose("foo_storage"))]
pub contract EventHostRedeclares {
    use aztec::macros::{functions::{external, view}, storage::storage};
    use aztec::state_vars::PublicMutable;

    // This was the old required pattern; now a duplicate of the auto-replayed struct.
    #[event]
    struct FooEvt {
        value: u32,
    }

    #[storage]
    struct Storage<Context> {
        foo_counter: PublicMutable<u32, Context>,
    }

    #[external("public")]
    #[view]
    fn get() -> u32 {
        self.storage.foo_counter.read()
    }
}
