use crate::{MultiComposeHost, test::utils};

#[test]
unconstrained fn can_expose_two_direct_templates_in_one_host() {
    let (env, _caller, host_address) = utils::setup();
    let host = MultiComposeHost::at(host_address);

    assert_eq(env.view_public(host.foo_value()), 12);
    assert_eq(env.view_public(host.bar_value()), 24);
    assert_eq(env.view_public(host.foo_double(4)), 8);
    assert_eq(env.view_public(host.bar_double(4)), 12);
    assert_eq(env.view_public(host.foo_marker_via_internal()), 2);
    assert_eq(env.view_public(host.bar_marker_via_internal()), 3);
}

#[test]
unconstrained fn composed_internal_helpers_from_multiple_templates_are_callable() {
    let (env, _caller, host_address) = utils::setup();
    let host = MultiComposeHost::at(host_address);

    assert_eq(env.view_public(host.combined_internal_markers()), 5);
}
