//! A server's firewall — ufw or firewalld — read and changed through their own
//! tools, and every change judged first against the connections the app (or
//! the panel) reaches the server by.
//!
//! Ported from the app's Dart (`service/firewall.dart`, `ufw_manager.dart`,
//! `firewalld_manager.dart` and their models), with its fixtures
//! (`tests/firewall_compat.rs`).
//!
//! What a change does to a connection ([`FirewallReach`]) is worked out here
//! rather than by each client: a change that refuses the connection in use
//! leaves the server unreachable once it drops, and that connection is
//! usually the only way to undo it.

pub mod firewalld;
pub mod ufw;

use std::net::IpAddr;

/// Where the firewalls' commands are: `/usr/sbin`, which Debian leaves out of
/// a non-root `PATH`. `C` because what they print is read.
pub const ENV: &str = r#"export LC_ALL=C PATH="$PATH:/usr/sbin:/sbin""#;

/// `commands` as one script, stopping at the first that fails.
///
/// Run in a subshell so its exit status can be looked at: 2 is how the app's
/// `PrivilegedExec` says sudo refused the password, and `firewall-cmd` exits 2
/// on a usage error too. One must not read as the other, or a refused command
/// asks for the password again.
pub fn script<S: AsRef<str>>(commands: &[S]) -> String {
    let mut lines = vec![ENV.to_owned(), "(".into(), "set -e".into()];
    lines.extend(commands.iter().map(|c| c.as_ref().to_owned()));
    lines.extend([")".into(), "rc=$?".into(), r#"[ "$rc" -ne 2 ] || rc=1"#.into(), r#"exit "$rc""#.into(), String::new()]);
    lines.join("\n")
}

/// The firewalls a server has.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FirewallKind {
    Ufw,
    Firewalld,
}

/// Which way of reaching the server an access is.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FirewallAccessVia {
    Ssh,
    Monitor,
}

/// One way the app reaches a server: the TCP port it connects to there, and
/// the addresses of the connection as the server sees them.
///
/// What every firewall change is checked against.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct FirewallAccess {
    pub via: FirewallAccessVia,
    /// The port on the server. From `SSH_CONNECTION` where the server said,
    /// so a NAT that maps another port to it does not mislead.
    pub port: u16,
    /// Where the server sees the device connect from: a NAT's address, or a
    /// jump server's. None where it could not be asked.
    pub client: Option<String>,
    /// The server's own address the connection arrived on.
    pub server: Option<String>,
}

impl FirewallAccess {
    /// Reads `SSH_CONNECTION` — `client_ip client_port server_ip server_port`
    /// — into the SSH access it describes. None for anything else.
    pub fn from_ssh_connection(value: &str) -> Option<FirewallAccess> {
        let fields: Vec<&str> = value.split_whitespace().collect();
        let [client, _, server, port] = fields[..] else { return None };
        let client = address(unscoped(client))?;
        let server = address(unscoped(server))?;
        let port: u16 = port.parse().ok().filter(|p| *p >= 1)?;
        Some(FirewallAccess {
            via: FirewallAccessVia::Ssh,
            port,
            client: Some(client.to_string()),
            server: Some(server.to_string()),
        })
    }

    fn client_ip(&self) -> Option<IpAddr> {
        self.client.as_deref().and_then(address)
    }

    fn server_ip(&self) -> Option<IpAddr> {
        self.server.as_deref().and_then(address)
    }
}

/// `fe80::1%eth0` without its zone, which an address does not parse with.
fn unscoped(address: &str) -> &str {
    address.split('%').next().unwrap_or(address)
}

fn address(value: &str) -> Option<IpAddr> {
    value.parse().ok()
}

/// Whether a new connection like a [`FirewallAccess`] would get through.
///
/// Ordered from best to worst, which is what [`FirewallReach::worse_than`]
/// compares.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum FirewallReach {
    Open,
    /// Let through, at a rate: ufw's `limit` refuses an address after six
    /// connections in thirty seconds.
    Limited,
    /// Turns on what cannot be known: the address or the interface the
    /// connection comes by, where a rule names one.
    Unknown,
    Blocked,
}

impl FirewallReach {
    pub fn admits(self) -> bool {
        matches!(self, Self::Open | Self::Limited)
    }

    /// Whether a change from `before` to this is one to stop and ask about.
    pub fn worse_than(self, before: FirewallReach) -> bool {
        self > before
    }
}

/// The worst of `reaches` that is worse than it was before, or None when none
/// got worse.
pub fn worst_change(reaches: &[(FirewallReach, FirewallReach)]) -> Option<FirewallReach> {
    reaches.iter().filter(|(before, after)| after.worse_than(*before)).map(|(_, after)| *after).max()
}

/// A rule's verdict on a connection, and whether it surely applies or only
/// might.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Judged {
    verdict: FirewallReach,
    sure: bool,
}

/// The first sure verdict among `checks`, else `fallback`; unknown where a
/// check that only might apply would decide otherwise.
fn decide(checks: impl IntoIterator<Item = Judged>, fallback: FirewallReach) -> FirewallReach {
    let mut maybes = Vec::new();
    let mut decided = None;
    for check in checks {
        if !check.sure {
            maybes.push(check.verdict);
            continue;
        }
        decided = Some(check.verdict);
        break;
    }
    let verdict = decided.unwrap_or(fallback);
    if maybes.iter().any(|m| m.admits() != verdict.admits()) {
        return FirewallReach::Unknown;
    }
    verdict
}

/// Whether `spec` — `22`, `80,443`, `6000:6010`, or firewalld's `6000-6010` —
/// names `port`. None is any port.
pub fn port_spec_covers(spec: Option<&str>, port: u16) -> bool {
    let Some(spec) = spec else { return true };
    let port = i64::from(port);
    spec.split(',').any(|part| {
        let range: Vec<&str> = part.trim().split([':', '-']).collect();
        match (range.first().and_then(|s| s.parse::<i64>().ok()), range.last().and_then(|s| s.parse::<i64>().ok())) {
            (Some(start), Some(end)) => port >= start && port <= end,
            _ => false,
        }
    })
}

/// Whether `network` — an address or a CIDR network — holds `address`.
///
/// None when `network` is neither, and false across families: a v4 network
/// never holds a v6 address, mapped or not, as iptables sees it.
pub fn network_contains(network: &str, address: IpAddr) -> Option<bool> {
    let (base, prefix) = match network.split_once('/') {
        Some((base, prefix)) => (base, Some(prefix)),
        None => (network, None),
    };
    let base: IpAddr = base.parse().ok()?;
    let (a, b): (Vec<u8>, Vec<u8>) = match (base, address) {
        (IpAddr::V4(a), IpAddr::V4(b)) => (a.octets().to_vec(), b.octets().to_vec()),
        (IpAddr::V6(a), IpAddr::V6(b)) => (a.octets().to_vec(), b.octets().to_vec()),
        _ => return Some(false),
    };
    let bits = a.len() * 8;
    let prefix = match prefix {
        None => bits,
        Some(p) => p.parse::<usize>().ok().filter(|p| *p <= bits)?,
    };
    Some((0..prefix).all(|bit| {
        let mask = 0x80u8 >> (bit % 8);
        a[bit / 8] & mask == b[bit / 8] & mask
    }))
}

/// Whether `network` holds the address `client`, where both are known.
fn holds(network: &str, client: Option<IpAddr>) -> Option<bool> {
    network_contains(network, client?)
}

/// What [`PROBE_SCRIPT`] found, asked without root.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct FirewallProbeResult {
    /// ufw, where installed: whether it is on, from its config (`ENABLED=yes`,
    /// readable by anyone).
    pub ufw: Option<bool>,
    /// firewalld, where installed: whether it is on, from systemd or the
    /// daemon itself.
    pub firewalld: Option<bool>,
    /// Whether commands run as root.
    pub root: bool,
    /// The SSH connection the probe ran over, as the server saw it. None when
    /// it ran over anything else.
    pub ssh: Option<FirewallAccess>,
    /// The interface `ssh` arrived on, which decides its firewalld zone.
    pub ssh_interface: Option<String>,
}

impl FirewallProbeResult {
    /// The firewall to show first: the one that is on; firewalld where both
    /// are, since its rules are the ones the kernel ends up with when both
    /// load theirs; ufw where neither is.
    pub fn preferred(&self) -> Option<FirewallKind> {
        match (self.ufw, self.firewalld) {
            (None, None) => None,
            (Some(_), None) => Some(FirewallKind::Ufw),
            (None, Some(_)) => Some(FirewallKind::Firewalld),
            (Some(_), Some(true)) => Some(FirewallKind::Firewalld),
            (Some(_), Some(false)) => Some(FirewallKind::Ufw),
        }
    }
}

pub const PROBE_UFW: &str = "SrvBoxFw.Ufw\t";
pub const PROBE_FIREWALLD: &str = "SrvBoxFw.Firewalld\t";
pub const PROBE_UID: &str = "SrvBoxFw.Uid\t";
pub const PROBE_SSH: &str = "SrvBoxFw.Ssh\t";
pub const PROBE_IFACE: &str = "SrvBoxFw.Iface\t";

/// Which firewalls a server has, and how the app reaches it. Never asks for
/// root: a server with neither firewall is said to be one before anyone is
/// asked for a password. `SSH_CONNECTION` is only there before `sudo`, which
/// drops it. For `sh`.
pub const PROBE_SCRIPT: &str = concat!(
    r#"export LC_ALL=C PATH="$PATH:/usr/sbin:/sbin""#,
    "\n",
    r#"if command -v ufw >/dev/null 2>&1; then
  printf 'SrvBoxFw.Ufw\t%s\n' "$(grep -E '^ENABLED=' /etc/ufw/ufw.conf 2>/dev/null | cut -d= -f2)"
fi
if command -v firewall-cmd >/dev/null 2>&1; then
  s=$(systemctl is-active firewalld 2>/dev/null)
  [ -n "$s" ] || s=$(firewall-cmd --state 2>&1)
  printf 'SrvBoxFw.Firewalld\t%s\n' "$s"
fi
printf 'SrvBoxFw.Uid\t%s\n' "$(id -u)"
printf 'SrvBoxFw.Ssh\t%s\n' "$SSH_CONNECTION"
if [ -n "$SSH_CONNECTION" ]; then
  set -- $SSH_CONNECTION
  printf 'SrvBoxFw.Iface\t%s\n' "$(ip -o addr show to "${3%%\%*}" 2>/dev/null | awk '{ print $2; exit }')"
fi
"#
);

pub fn parse_probe(output: &str) -> FirewallProbeResult {
    let mut result = FirewallProbeResult::default();
    for raw in output.replace("\r\n", "\n").split('\n') {
        let line = raw.trim_end();
        let value = |marker: &str| line.strip_prefix(marker).map(str::trim);
        if let Some(v) = value(PROBE_UFW) {
            result.ufw = Some(v.replace('"', "").eq_ignore_ascii_case("yes"));
        } else if let Some(v) = value(PROBE_FIREWALLD) {
            result.firewalld = Some(v == "active" || v == "running");
        } else if let Some(v) = value(PROBE_UID) {
            result.root = v == "0";
        } else if let Some(v) = value(PROBE_SSH) {
            result.ssh = FirewallAccess::from_ssh_connection(v);
        } else if let Some(v) = value(PROBE_IFACE).filter(|v| !v.is_empty()) {
            result.ssh_interface = Some(v.to_owned());
        }
    }
    result
}

/// What may be typed as an interface name: what the kernel allows, and
/// nothing a shell would read.
fn valid_interface(name: &str) -> bool {
    (1..=15).contains(&name.len()) && name.bytes().all(|b| b.is_ascii_alphanumeric() || b"_.+-".contains(&b))
}

/// A control character, which would end a script's line.
fn has_control(value: &str) -> bool {
    value.chars().any(|c| c.is_control() && (c as u32) < 0x80)
}

/// The family of an address or network, or None when `value` is neither.
fn family_of(value: &str) -> Option<bool> {
    let (host, prefix) = match value.split_once('/') {
        Some((host, prefix)) => (host, Some(prefix)),
        None => (value, None),
    };
    let v6 = address(host)?.is_ipv6();
    if let Some(prefix) = prefix {
        let bits = if v6 { 128 } else { 32 };
        prefix.parse::<u32>().ok().filter(|p| *p <= bits)?;
    }
    Some(v6)
}
