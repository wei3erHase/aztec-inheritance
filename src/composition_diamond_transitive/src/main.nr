pub mod test;

use aztec::macros::{aztec, AztecConfig};

#[aztec(
    AztecConfig::new().compose("transitive_diamond_left_template").compose(
        "transitive_diamond_right_template",
    ),
)]
pub contract TransitiveDiamondSharedLeafHost {}
