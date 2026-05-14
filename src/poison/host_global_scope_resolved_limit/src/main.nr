mod raw_global_template;

use aztec::macros::{aztec, AztecConfig};

// Host-level symbol resolution for composed template bodies should fail here.
// The composed template references HOST_MAGIC, but declaring it in the template
// module does not make it available through composition in the host context.
#[aztec(AztecConfig::new().compose("raw_global_probe"))]
pub contract HostGlobalProbe {}
