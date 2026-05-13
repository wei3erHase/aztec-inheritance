pub mod test;

use aztec::macros::{aztec, AztecConfig};

#[aztec(AztecConfig::new().compose("mid_template"))]
pub contract TransitiveComposeHost {}
