use aztec::macros::{aztec, contract_template};

/// Minimal template used only to create an event-name collision scenario.
///
/// Defines `FooEvt` with the same name as `foo_storage_template`. Composing both
/// into the same host triggers a duplicate struct definition error at replay time.
#[contract_template("foo_event_collision")]
#[aztec]
pub contract FooEventCollisionTemplate {
    use aztec::macros::{events::event, functions::{external, view}};

    #[event]
    struct FooEvt {
        value: u32,
    }

    #[external("public")]
    #[view]
    fn foo_event_collision_value() -> u32 {
        0
    }
}
