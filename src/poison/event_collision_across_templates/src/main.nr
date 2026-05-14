// Poison contract: EXPECTED to fail compilation.
//
// `foo_storage` and `foo_event_collision` both define `FooEvt`.
// PR-2 auto-replays events from all composed templates, so both structs
// are injected into this host, causing a duplicate struct definition.

use aztec::macros::{AztecConfig, aztec};

#[aztec(AztecConfig::new().compose("foo_storage").compose("foo_event_collision"))]
pub contract EventCollisionAcrossTemplates {
    use aztec::macros::{functions::{external, view}, storage::storage};
    use aztec::state_vars::PublicMutable;

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
