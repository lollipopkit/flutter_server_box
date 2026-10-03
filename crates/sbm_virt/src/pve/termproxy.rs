//! Proxmox VE's `termproxy` protocol, spoken over a node's `vncwebsocket`.
//!
//! Ported from the app's `lib/core/utils/pve_termproxy.dart`, written against
//! PVE's own client (`pve-xtermjs`) and verified on PVE 9.2.2
//! (proxmox-termproxy 2.1.0):
//!
//! - First, `<user>:<ticket>\n` — what `POST .../termproxy` answered. For an
//!   API token the user is the token itself (`root@pam!name`).
//! - termproxy answers `OK` (a binary frame of those two bytes) and the
//!   output follows; a refused ticket gets no answer — the socket ends.
//! - Then, client to server: `0:<len>:<data>` input (`len` in bytes),
//!   `1:<cols>:<rows>:` to resize, `2` every 30 s as a keep-alive.
//! - Server to client: raw terminal output.

use std::time::Duration;

/// The answer to an accepted ticket, before any output.
pub const ACCEPTED: &[u8] = b"OK";

/// Keeps an idle connection from being timed out by the proxy.
pub const KEEP_ALIVE: &[u8] = b"2";

/// `pve-xtermjs`'s interval.
pub const KEEP_ALIVE_INTERVAL: Duration = Duration::from_secs(30);

/// The first message.
pub fn auth(user: &str, ticket: &str) -> Vec<u8> {
    format!("{user}:{ticket}\n").into_bytes()
}

/// `data`, framed as input.
pub fn input(data: &[u8]) -> Vec<u8> {
    let mut out = format!("0:{}:", data.len()).into_bytes();
    out.extend_from_slice(data);
    out
}

/// A new terminal size.
pub fn resize(cols: u16, rows: u16) -> Vec<u8> {
    format!("1:{cols}:{rows}:").into_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frames() {
        assert_eq!(auth("root@pam!sb", "PVEVNC:x"), b"root@pam!sb:PVEVNC:x\n");
        // The length is in bytes, not characters.
        assert_eq!(input("é".as_bytes()), b"0:2:\xc3\xa9");
        assert_eq!(resize(80, 24), b"1:80:24:");
    }
}
