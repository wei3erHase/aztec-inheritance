pub mod test;

use aztec::macros::{aztec, AztecConfig};

/// Host contract that composes the foo_storage template.
/// Tests: storage composition, event emission, internal reuse, library method migration.
///
/// Storage fields from FooStorageTemplate must be declared here -- Noir lacks
/// TypeDefinition::add_field, so field injection from templates is not possible (L-4, L-15).
///
/// Event structs referenced by composed function bodies must also be declared here;
/// composed bodies carry raw tokens that resolve in the host module scope (not the template's).
#[aztec(AztecConfig::new().compose("foo_storage"))]
pub contract FooStorageHost {
    use aztec::{
        macros::{events::event, functions::{external, view}, storage::storage},
        state_vars::PublicMutable,
    };

    // FooEvt is used in the body of the composed foo_increment function.
    // The composed body carries raw tokens; FooEvt must be in scope in this host module.
    #[event]
    struct FooEvt {
        value: u32,
    }

    #[storage]
    struct Storage<Context> {
        // foo_storage template fields -- must be declared here manually (see L-4, L-15)
        foo_counter: PublicMutable<u32, Context>,
    }

    /// Uses composed internal to drive storage writes from a host-owned entrypoint.
    #[external("public")]
    fn host_set_and_get(value: u32) -> u32 {
        self.internal._foo_set(value);
        self.storage.foo_counter.read()
    }

    /// Calls the library method migrated from the template (constant, no storage).
    /// _foo_magic is a #[contract_library_method] -- free function, not an internal.
    #[view]
    #[external("public")]
    fn host_library_constant() -> u32 {
        _foo_magic()
    }
}
