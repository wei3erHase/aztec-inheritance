use crate::main::InternalOverrideHost;
use crate::test::utils;

#[test]
unconstrained fn internal_override_is_used_from_template_entrypoint() {
    let (env, _caller, host_address) = utils::setup_internal_override();
    let host = InternalOverrideHost::at(host_address);

    // Template probe calls its internal helper. The host override should replace it.
    assert_eq(env.view_public(host.internal_magic_probe()), 14);
}
