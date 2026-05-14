use aztec::test::helpers::test_environment::TestEnvironment;
use crate::main::DualOverrideTransitiveHost;

#[test]
unconstrained fn dual_source_override_requires_directly_composed_template_ids_and_overrides_both() {
    let mut env = TestEnvironment::new();
    let _caller = env.create_light_account();
    let host = env
        .deploy("@composition_override_contract/DualOverrideTransitiveHost")
        .without_initializer();
    let host = DualOverrideTransitiveHost::at(host);

    // The host composes both template IDs that contribute `fee_bps`.
    // It overrides each one explicitly so no selector collision occurs.
    assert_eq(env.view_public(host.fee_bps()), 9);
    assert_eq(env.view_public(host.virtual_mid_value()), 11);
}
