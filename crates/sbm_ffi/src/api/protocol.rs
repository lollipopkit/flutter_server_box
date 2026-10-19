//! The app ↔ agent protocol (`sbm_parser::protocol`): the number the app
//! names in every request, and how it stands with an agent's `/health`.

use flutter_rust_bridge::frb;
pub use sbm_parser::protocol::ProtocolCompat;
use sbm_parser::protocol;

#[frb(mirror(ProtocolCompat))]
pub enum _ProtocolCompat {
    Ok,
    AgentTooOld,
    ClientTooOld,
}

/// What this app speaks.
#[frb(sync)]
pub fn monitor_protocol() -> u32 {
    protocol::PROTOCOL
}

/// The header it is named in.
#[frb(sync)]
pub fn monitor_protocol_header() -> String {
    protocol::HEADER.to_string()
}

/// [agent] and [min_client] are `/health`'s `protocol` and
/// `min_client_protocol`, `None` where an older agent sent none.
#[frb(sync)]
pub fn monitor_protocol_compat(agent: Option<u32>, min_client: Option<u32>) -> ProtocolCompat {
    protocol::compat(agent, min_client)
}
