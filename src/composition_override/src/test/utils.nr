use aztec::{protocol::address::AztecAddress, test::helpers::test_environment::TestEnvironment};

pub unconstrained fn setup() -> (TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();
    let caller = env.create_light_account();
    let host =
        env.deploy("@composition_override_contract/VirtualOverrideHost").without_initializer();

    (env, caller, host)
}

pub unconstrained fn setup_transitive() -> (TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();
    let caller = env.create_light_account();
    let host =
        env.deploy("@composition_override_contract/TransitiveOverrideHost").without_initializer();

    (env, caller, host)
}
