use aztec::{protocol::address::AztecAddress, test::helpers::test_environment::TestEnvironment};

pub unconstrained fn setup() -> (TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();
    let caller = env.create_light_account();
    let host =
        env.deploy("@composition_transitive_contract/TransitiveComposeHost").without_initializer();

    (env, caller, host)
}
