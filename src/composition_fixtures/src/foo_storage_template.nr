use aztec::macros::{aztec, contract_template};

/// Richer template used for storage / event / constant hypothesis tests.
///
/// Surfaces:
/// - Storage: `foo_counter: PublicMutable<u32>`
/// - Event: `FooEvt { value: u32 }` -- now auto-replayed for composed hosts
/// - External: `foo_increment()`, `foo_get() -> u32`, `foo_magic_via_helper() -> u32`
/// - Internal: `_foo_set(value: u32)`
/// - Library method (migrated): `_foo_magic() -> u32`
///
/// NOTE: raw globals (e.g. FOO_MAGIC) are NOT migrated -- see foo_raw_global_template.
/// NOTE: event structs used in composed bodies are auto-replayed from template declarations.
#[contract_template("foo_storage")]
#[aztec]
pub contract FooStorageTemplate {
    use aztec::{
        macros::{events::event, functions::{external, internal, view}, storage::storage},
        state_vars::PublicMutable,
    };

    #[event]
    struct FooEvt {
        value: u32,
    }

    #[storage]
    struct Storage<Context> {
        foo_counter: PublicMutable<u32, Context>,
    }

    /// Increment counter and emit event.
    #[external("public")]
    fn foo_increment() {
        let current = self.storage.foo_counter.read();
        let new_val = current + 1;
        self.storage.foo_counter.write(new_val);
        self.emit(FooEvt { value: new_val });
    }

    /// Read counter.
    #[view]
    #[external("public")]
    fn foo_get() -> u32 {
        self.storage.foo_counter.read()
    }

    /// Internal: set counter directly -- callable by host via self.internal._foo_set().
    #[internal("public")]
    fn _foo_set(value: u32) {
        self.storage.foo_counter.write(value);
    }

    /// Library method constant -- migrated via f.as_typed_expr() forwarding.
    /// Host receives a wrapper that calls the original function directly.
    #[contract_library_method]
    fn _foo_magic() -> u32 {
        42
    }

    /// Calls the library method helper -- works in host because _foo_magic is migrated.
    #[view]
    #[external("public")]
    fn foo_magic_via_helper() -> u32 {
        _foo_magic()
    }
}
