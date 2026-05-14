use crate::main::TransitiveOverrideHost;
use crate::test::utils;

#[test]
unconstrained fn transitive_child_override_works_when_overriden_id_is_directly_composed() {
    let (env, _caller, host_address) = utils::setup_transitive();
    let host = TransitiveOverrideHost::at(host_address);

    // `virtual_mid_template` is transitive, and `virtual_template` is flattened;
    // override is only accepted because `virtual_template` is listed directly.
    assert_eq(env.view_public(host.fee_bps()), 5);
    assert_eq(env.view_public(host.virtual_mid_value()), 11);
    assert_eq(env.view_public(host.template_fee_label()), 77);
}
