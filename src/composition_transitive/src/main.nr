pub mod test;

use aztec::macros::{AztecConfig, aztec};

#[aztec(AztecConfig::new().compose("mid_template"))]
pub contract TransitiveComposeHost {}
