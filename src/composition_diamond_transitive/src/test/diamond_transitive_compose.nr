use crate::{test::utils, TransitiveDiamondSharedLeafHost};

#[test]
unconstrained fn transitive_diamond_same_leaf_is_merged_once() {
    let (env, _caller, host_address) = utils::setup();
    let host = TransitiveDiamondSharedLeafHost::at(host_address);

    assert_eq(env.view_public(host.left_value()), 100);
    assert_eq(env.view_public(host.right_value()), 200);
    assert_eq(env.view_public(host.leaf_value()), 500);
}
