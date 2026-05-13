use crate::{test::utils, TransitiveComposeHost};

#[test]
unconstrained fn transitive_root_template_is_available() {
    let (env, _caller, host_address) = utils::setup();
    let host = TransitiveComposeHost::at(host_address);

    assert_eq(env.view_public(host.mid_value()), 100);
}

#[test(should_fail_with = "Unknown selector")]
unconstrained fn transitive_composition_of_templates_is_not_flattened() {
    let (env, caller, host_address) = utils::setup();

    let foo_selector = comptime { aztec::protocol::abis::function_selector::FunctionSelector::from_signature("foo_value()") };
    let _ = env.call_public(
        caller,
        aztec::context::calls::PublicCall::<9, 0, ()>::new(
            host_address,
            foo_selector,
            "foo_value",
            [],
        ),
    );
}
