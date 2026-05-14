use crate::{test::utils, TransitiveComposeHost};

#[test]
unconstrained fn transitive_root_template_is_available() {
    let (env, _caller, host_address) = utils::setup();
    let host = TransitiveComposeHost::at(host_address);

    assert_eq(env.view_public(host.mid_value()), 100);
}

#[test]
unconstrained fn transitive_composition_of_templates_is_flattened() {
    let (env, _caller, host_address) = utils::setup();
    let host = TransitiveComposeHost::at(host_address);

    // mid_template composes both foo_template and bar_template.
    assert_eq(env.view_public(host.foo_value()), 12);
    assert_eq(env.view_public(host.bar_value()), 24);
    assert_eq(env.view_public(host.foo_marker_via_internal()), 2);
    assert_eq(env.view_public(host.bar_marker_via_internal()), 3);
}
