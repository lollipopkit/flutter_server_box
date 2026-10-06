//! iperf — the host and port a client is started with, and the command line it
//! is started as.
//!
//! Pure like the rest of this crate: a function takes what a user typed and
//! returns a value or a command, and nothing here runs anything. This was the
//! app's Dart (`lib/view/page/iperf.dart`), which built the command itself —
//! the one thing the architecture forbids — so the rules moved here and now
//! serve both the app (over FFI) and the agent's terminal `target`.

use std::net::IpAddr;

use serde::{Deserialize, Serialize};

/// The longest a host may be. 253 is DNS's own limit for a name.
const MAX_HOST_LEN: usize = 253;

/// Why a host or a port could not be used.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IperfError {
    /// The host was empty.
    EmptyHost,
    /// The host is not an IPv4/IPv6 literal or a domain name.
    InvalidHost,
    /// The port is not in 1..=65535.
    InvalidPort,
}

impl IperfError {
    /// The wire code, also what a refusal is recorded under.
    pub fn code(self) -> &'static str {
        match self {
            Self::EmptyHost => "empty_host",
            Self::InvalidHost => "invalid_host",
            Self::InvalidPort => "invalid_port",
        }
    }
}

impl std::fmt::Display for IperfError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::EmptyHost => "the host is empty",
            Self::InvalidHost => "the host is not an IPv4/IPv6 address or a domain name",
            Self::InvalidPort => "the port must be between 1 and 65535",
        })
    }
}

impl std::error::Error for IperfError {}

/// The canonical host to hand to `iperf`, or `None` if it is not one.
///
/// The rules are the Dart `normalizeIperfHost`'s, moved here unchanged: a
/// bracketed IPv6 literal loses its brackets, an IP literal is returned in its
/// canonical form (compressed lowercase for IPv6), and anything else must look
/// like a domain name — labels of `[A-Za-z0-9-]`, at most 63 each, none
/// starting or ending with `-`.
pub fn normalize_host(raw: &str) -> Option<String> {
    let host = raw.trim();
    if host.is_empty() || host.len() > MAX_HOST_LEN {
        return None;
    }

    if host.starts_with('[') || host.ends_with(']') {
        if !host.starts_with('[') || !host.ends_with(']') {
            return None;
        }
        let inner = &host[1..host.len() - 1];
        return match inner.parse::<IpAddr>() {
            Ok(IpAddr::V6(address)) => Some(address.to_string()),
            _ => None,
        };
    }

    if let Ok(address) = host.parse::<IpAddr>() {
        return Some(address.to_string());
    }
    if host.contains(':') {
        return None;
    }
    // All digits and dots is a malformed IPv4, not a domain name.
    if host.chars().all(|c| c.is_ascii_digit() || c == '.') {
        return None;
    }

    for label in host.split('.') {
        let valid = !label.is_empty()
            && label.len() <= 63
            && !label.starts_with('-')
            && !label.ends_with('-')
            && label
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-');
        if !valid {
            return None;
        }
    }
    Some(host.to_string())
}

/// The port as a number, or `None` if it is not one.
///
/// Only ASCII digits, at most five of them, and 1..=65535 when parsed — the
/// Dart `isValidIperfPort`'s rules.
pub fn valid_port(raw: &str) -> Option<u16> {
    let port = raw.trim();
    if port.is_empty() || port.len() > 5 || !port.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    match port.parse::<u32>() {
        Ok(value) if (1..=65535).contains(&value) => Some(value as u16),
        _ => None,
    }
}

/// `iperf -c <host> -p <port>`, the command a terminal is opened with.
///
/// The host is validated again here through [`normalize_host`], so a caller
/// cannot reach a command line by skipping it. The line is **unquoted on
/// purpose**: the validated character set contains no shell metacharacter, and
/// the same string has to work in Windows `cmd`, where single quotes are not
/// quoting.
pub fn client_command(host: &str, port: u16) -> Result<String, IperfError> {
    if host.trim().is_empty() {
        return Err(IperfError::EmptyHost);
    }
    let host = normalize_host(host).ok_or(IperfError::InvalidHost)?;
    if port == 0 {
        return Err(IperfError::InvalidPort);
    }
    Ok(format!("iperf -c {host} -p {port}"))
}

#[cfg(test)]
mod tests {
    //! Ported from the app's Dart suite (`test/unit/benchmark/iperf_test.dart`)
    //! before the Dart copy was rewritten onto the FFI, whose cases are now
    //! these.

    use super::*;

    #[test]
    fn normalizes_structurally_valid_hosts() {
        assert_eq!(normalize_host("example.com").as_deref(), Some("example.com"));
        assert_eq!(normalize_host("192.0.2.1").as_deref(), Some("192.0.2.1"));
        assert_eq!(
            normalize_host("[2001:db8::1]").as_deref(),
            Some("2001:db8::1")
        );
    }

    #[test]
    fn canonicalises_ip_literals() {
        // An unbracketed IPv6 literal is accepted too, and compressed the way
        // Dart's `InternetAddress.address` reports it.
        assert_eq!(
            normalize_host("2001:0db8:0000::0001").as_deref(),
            Some("2001:db8::1")
        );
        assert_eq!(normalize_host("192.000.002.001"), None);
    }

    #[test]
    fn rejects_malformed_hosts() {
        for host in [
            "999.999.999.999",
            "a..b",
            "-example.com",
            "example-.com",
            "[not-an-ip]",
            "host name",
            "host;echo",
            "",
            "   ",
        ] {
            assert_eq!(normalize_host(host), None, "{host:?}");
        }
        // A name longer than DNS allows.
        let long = format!("{}.com", "a".repeat(250));
        assert_eq!(normalize_host(&long), None);
    }

    #[test]
    fn rejects_hosts_with_a_shell_metacharacter() {
        for host in ["a;b", "$(id)", "`id`", "a\nb", "a b", "-leading"] {
            assert_eq!(normalize_host(host), None, "{host:?}");
        }
    }

    #[test]
    fn a_host_that_is_only_a_bracket_or_a_colon_is_rejected() {
        assert_eq!(normalize_host("["), None);
        assert_eq!(normalize_host("]"), None);
        assert_eq!(normalize_host("[2001:db8::1"), None);
        assert_eq!(normalize_host("2001:db8::1]"), None);
        assert_eq!(normalize_host("host:"), None);
    }

    #[test]
    fn validates_ports() {
        assert_eq!(valid_port("1"), Some(1));
        assert_eq!(valid_port("65535"), Some(65535));
        assert_eq!(valid_port(" 5201 "), Some(5201));
        assert_eq!(valid_port("0"), None);
        assert_eq!(valid_port("65536"), None);
        assert_eq!(valid_port(""), None);
        assert_eq!(valid_port("5201a"), None);
        assert_eq!(valid_port("52 01"), None);
        assert_eq!(valid_port("123456"), None);
    }

    #[test]
    fn builds_a_command_that_is_safe_for_posix_and_cmd_shells() {
        assert_eq!(
            client_command("2001:db8::1", 5201).unwrap(),
            "iperf -c 2001:db8::1 -p 5201"
        );
        assert_eq!(
            client_command("example.com", 1).unwrap(),
            "iperf -c example.com -p 1"
        );
    }

    #[test]
    fn a_command_refuses_what_it_cannot_build() {
        assert_eq!(client_command("", 5201), Err(IperfError::EmptyHost));
        assert_eq!(client_command("  ", 5201), Err(IperfError::EmptyHost));
        assert_eq!(
            client_command("host;echo", 5201),
            Err(IperfError::InvalidHost)
        );
        assert_eq!(client_command("example.com", 0), Err(IperfError::InvalidPort));
        // The error the refused values carry to the wire.
        assert_eq!(IperfError::InvalidHost.code(), "invalid_host");
        assert_eq!(
            serde_json::to_string(&IperfError::EmptyHost).unwrap(),
            r#""empty_host""#
        );
    }
}
