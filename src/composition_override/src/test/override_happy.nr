use crate::{test::utils, VirtualOverrideHost};

#[test]
unconstrained fn virtual_template_function_is_overridden_by_host() {
    let (env, _caller, host_address) = utils::setup();
    let host = VirtualOverrideHost::at(host_address);

    // Host override takes precedence over template default.
    assert_eq(env.view_public(host.fee_bps()), 5);

    // Non-virtual template functions are still composed.
    assert_eq(env.view_public(host.template_fee_label()), 77);
}
