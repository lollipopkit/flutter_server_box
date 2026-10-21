/// The protocol this panel speaks: `sbm_parser::protocol::PROTOCOL`, named in
/// every request. `crates/sbm_parser/tests/protocol_clients.rs` keeps the two
/// equal.
export const PROTOCOL = 1

/// `sbm_parser::protocol::HEADER`.
export const PROTOCOL_HEADER = 'X-SBM-Protocol'

export const protocolHeaders: Record<string, string> = { [PROTOCOL_HEADER]: String(PROTOCOL) }

/// The agent's answer to a client it no longer serves.
export const CLIENT_TOO_OLD = 426
