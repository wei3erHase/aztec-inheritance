use crate::{FooStorageHost, test::utils};

/// Composed external functions from the template are directly callable on the host.
#[test]
unconstrained fn foo_storage_externals_are_exposed_on_host() {
    let (env, _caller, host_address) = utils::setup();
    let host = FooStorageHost::at(host_address);

    // foo_get() is composed from the template -- counter starts at 0.
    assert_eq(env.view_public(host.foo_get()), 0);
}

/// Composed internal _foo_set drives the host's own storage field.
#[test]
unconstrained fn composed_internal_drives_host_storage() {
    let (env, caller, host_address) = utils::setup();
    let host = FooStorageHost::at(host_address);

    // host_set_and_get uses the composed _foo_set internal then reads via host storage.
    assert_eq(env.call_public(caller, host.host_set_and_get(99)), 99);
}

/// foo_increment (composed external) mutates host storage; foo_get reads it back.
#[test]
unconstrained fn composed_external_mutates_host_storage() {
    let (env, caller, host_address) = utils::setup();
    let host = FooStorageHost::at(host_address);

    env.call_public(caller, host.foo_increment());
    env.call_public(caller, host.foo_increment());
    assert_eq(env.view_public(host.foo_get()), 2);
}

/// Library method _foo_magic is migrated via f.as_typed_expr() -- constant 42.
#[test]
unconstrained fn library_method_constant_is_migrated() {
    let (env, _caller, host_address) = utils::setup();
    let host = FooStorageHost::at(host_address);

    assert_eq(env.view_public(host.host_library_constant()), 42);
}

/// foo_magic_via_helper (composed external) calls _foo_magic internally -- still 42.
#[test]
unconstrained fn composed_function_calling_library_method_works() {
    let (env, _caller, host_address) = utils::setup();
    let host = FooStorageHost::at(host_address);

    assert_eq(env.view_public(host.foo_magic_via_helper()), 42);
}
