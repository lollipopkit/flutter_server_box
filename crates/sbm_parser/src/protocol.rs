//! The app ↔ agent protocol version: the one number both sides compare.
//!
//! [`PROTOCOL`] counts breaking changes to what the agent's HTTP API says —
//! a field removed or renamed, a meaning changed, a route gone. An addition
//! is not one: it is announced in `/capabilities`' `features`, and a client
//! ignores what it does not know. The agent's release version is for showing,
//! never for deciding.
//!
//! Both directions stay working across one step at least: an agent answers a
//! client still at `PROTOCOL - 1` in that client's shape, and the app still
//! reads an agent at `PROTOCOL - 1`. Raising [`MIN_CLIENT_PROTOCOL`] or
//! [`MIN_AGENT_PROTOCOL`] is what drops a shape, together with its shims.

/// What this build speaks.
///
/// 2: one account. `/capabilities` reports `access` instead of
/// `remote_access`, `grants` and `me`; `/bmc` no longer says `editable`;
/// accounts, roles and the SSH terminal are gone. A client at 1 is answered
/// in its shape by the agent's `api::compat_v1`.
pub const PROTOCOL: u32 = 2;

/// The oldest client the agent still answers; older ones get `426`.
pub const MIN_CLIENT_PROTOCOL: u32 = 1;

/// The oldest agent the app still reads.
pub const MIN_AGENT_PROTOCOL: u32 = 1;

/// The request header a client names its protocol in.
pub const HEADER: &str = "x-sbm-protocol";

/// What a client that names none speaks: every client before this header.
pub const UNNAMED: u32 = 1;

/// A client's protocol from [`HEADER`]'s value; [`UNNAMED`] when absent.
/// `None` when present but not a number, which is a broken client rather
/// than an old one.
pub fn client_protocol(header: Option<&str>) -> Option<u32> {
    match header {
        None => Some(UNNAMED),
        Some(raw) => raw.trim().parse().ok(),
    }
}

/// Whether the agent answers a client at [protocol].
pub fn agent_serves(protocol: u32) -> bool {
    protocol >= MIN_CLIENT_PROTOCOL
}

/// How an agent and this client stand, from what the agent's `/health` said.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProtocolCompat {
    Ok,
    /// The agent is older than this client reads: the agent needs updating.
    AgentTooOld,
    /// The agent no longer answers this client: the app needs updating.
    ClientTooOld,
}

/// [agent] and [min_client] are `/health`'s `protocol` and
/// `min_client_protocol`; an agent before them reports neither and speaks
/// [`UNNAMED`].
pub fn compat(agent: Option<u32>, min_client: Option<u32>) -> ProtocolCompat {
    if PROTOCOL < min_client.unwrap_or(UNNAMED) {
        ProtocolCompat::ClientTooOld
    } else if agent.unwrap_or(UNNAMED) < MIN_AGENT_PROTOCOL {
        ProtocolCompat::AgentTooOld
    } else {
        ProtocolCompat::Ok
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_client_without_the_header_is_the_first_protocol() {
        assert_eq!(client_protocol(None), Some(UNNAMED));
        assert_eq!(client_protocol(Some(" 3 ")), Some(3));
        assert_eq!(client_protocol(Some("v2")), None);
    }

    #[test]
    fn an_agent_from_before_the_protocol_is_read_as_the_first() {
        assert_eq!(compat(None, None), ProtocolCompat::Ok);
        assert_eq!(compat(Some(PROTOCOL), Some(MIN_CLIENT_PROTOCOL)), ProtocolCompat::Ok);
    }

    #[test]
    fn either_side_can_be_the_one_too_old() {
        assert_eq!(compat(Some(PROTOCOL + 5), Some(PROTOCOL + 1)), ProtocolCompat::ClientTooOld);
        assert_eq!(compat(Some(MIN_AGENT_PROTOCOL - 1), None), ProtocolCompat::AgentTooOld);
        // A newer agent that still answers this client is fine.
        assert_eq!(compat(Some(PROTOCOL + 1), Some(PROTOCOL)), ProtocolCompat::Ok);
    }

    #[test]
    fn the_minimums_never_pass_the_protocol() {
        const { assert!(MIN_CLIENT_PROTOCOL <= PROTOCOL && MIN_AGENT_PROTOCOL <= PROTOCOL && UNNAMED <= PROTOCOL) };
        assert!(agent_serves(PROTOCOL));
        assert!(!agent_serves(MIN_CLIENT_PROTOCOL - 1));
    }
}
