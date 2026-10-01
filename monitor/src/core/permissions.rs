//! What one account may do: grants, roles, and the options a grant carries.
//!
//! The agent used to answer "may this be done" from switches in `config.toml`
//! that applied to every panel login alike. It answers per account now: each
//! account holds one [`Role`], a role is a named set of [`Grants`], and every
//! request is checked against the caller's role (see `api::authz`).
//!
//! The grants are cut by risk rather than by endpoint. `shell` is everything
//! that runs code as the agent's account — a command, a terminal, a custom
//! command — because any one of them is all of them. `connect` and `listen`
//! are networking without a shell, which is the useful thing to hand out on
//! its own: remote desktop for someone who should not have a prompt. A shell
//! can do both of those itself, so granting `shell` without them hides a UI
//! and protects nothing; the agent says so in its log rather than refusing.
//!
//! What stays in `config.toml` is what is about the machine rather than about
//! an account — the roots the file API may reach, how long a command may run,
//! where sshd is — and a grant is only usable where the machine side allows it
//! (`files` with no roots configured answers `not_configured`).

use std::fmt;
use std::net::{IpAddr, SocketAddr};
use std::str::FromStr;

use serde::{Deserialize, Serialize};

/// The names of the built-in roles. Both exist from migration 010 on.
pub const ADMIN_ROLE: &str = "admin";
pub const VIEWER_ROLE: &str = "viewer";

/// One of the six things an account can be granted, beyond `read`, which
/// every account holds and is therefore not a grant at all.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Grant {
    /// `POST /exec`, the app's terminal (a local PTY), running custom commands.
    Shell,
    /// The panel's terminal, which logs into sshd with SSH credentials.
    SshTerminal,
    /// `/fs/*`, read or read-write.
    Files,
    /// `/stream/ws` `open`: a connection dialled out from this machine.
    Connect,
    /// `/listen/ws` and `/stream/ws` `accept`: a port listened on here.
    Listen,
    /// The hypervisors and BMCs the agent reaches for the panel: Proxmox VE,
    /// libvirt, Redfish. Seeing and controlling them; setting up where they
    /// are and how to sign in is the admin's.
    Virt,
}

impl Grant {
    pub const ALL: [Grant; 6] = [
        Grant::Shell,
        Grant::SshTerminal,
        Grant::Files,
        Grant::Connect,
        Grant::Listen,
        Grant::Virt,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            Grant::Shell => "shell",
            Grant::SshTerminal => "ssh_terminal",
            Grant::Files => "files",
            Grant::Connect => "connect",
            Grant::Listen => "listen",
            Grant::Virt => "virt",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FilesMode {
    /// List, stat, read, and the roots.
    Read,
    /// Read, plus write, mkdir, rename, chmod and remove.
    Write,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FilesGrant {
    pub mode: FilesMode,
}

impl FilesGrant {
    pub fn allows_write(&self) -> bool {
        self.mode == FilesMode::Write
    }
}

/// Dialling out. [`Self::allow`] empty means anywhere this machine can reach.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ConnectGrant {
    /// `"<ip or cidr>"` or `"<ip or cidr>:<port or lo-hi>"`, IPv6 bracketed
    /// when it carries a port (`"[fd00::/8]:443"`). Validated on the way in by
    /// [`Grants::validate`], so a stored entry always parses.
    #[serde(default)]
    pub allow: Vec<String>,
}

impl ConnectGrant {
    /// Whether [`addr`] may be dialled.
    ///
    /// An address, never a name: a host name is resolved by the caller and
    /// each address it resolved to asked about separately, so a name cannot
    /// stand in for an address that would have been refused.
    pub fn permits(&self, addr: SocketAddr) -> bool {
        if self.allow.is_empty() {
            return true;
        }
        self.allow
            .iter()
            .filter_map(|entry| entry.parse::<AllowEntry>().ok())
            .any(|entry| entry.matches(addr))
    }
}

/// Listening on this machine.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ListenGrant {
    /// Addresses other than loopback: sshd's `GatewayPorts`, and off by
    /// default for the same reason — a port bound to every interface is a
    /// port for everyone who can reach the machine.
    #[serde(default)]
    pub public: bool,
    /// `[lo, hi]`, inclusive, or any port when absent.
    #[serde(default)]
    pub ports: Option<[u16; 2]>,
}

impl ListenGrant {
    /// Whether [`port`] may be bound. With a range, port 0 — "any free port"
    /// — is refused, since what the OS would pick is not known to be in it.
    pub fn permits_port(&self, port: u16) -> bool {
        match self.ports {
            None => true,
            Some([lo, hi]) => port != 0 && (lo..=hi).contains(&port),
        }
    }
}

/// What a role holds. `null` (or absent) for an object grant is "not granted";
/// an object is "granted, with these options".
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Grants {
    #[serde(default)]
    pub shell: bool,
    #[serde(default)]
    pub ssh_terminal: bool,
    #[serde(default)]
    pub files: Option<FilesGrant>,
    #[serde(default)]
    pub connect: Option<ConnectGrant>,
    #[serde(default)]
    pub listen: Option<ListenGrant>,
    #[serde(default)]
    pub virt: bool,
}

impl Grants {
    /// Nothing beyond `read`.
    pub fn none() -> Self {
        Self::default()
    }

    /// Everything, at the defaults a fresh install starts with: files
    /// read-write, dialling anywhere, listening on loopback on any port.
    pub fn all() -> Self {
        Self {
            shell: true,
            ssh_terminal: true,
            files: Some(FilesGrant {
                mode: FilesMode::Write,
            }),
            connect: Some(ConnectGrant::default()),
            listen: Some(ListenGrant::default()),
            virt: true,
        }
    }

    /// What both allow: each grant held by both, with the narrower of their
    /// options. For a fresh install whose old configuration is a ceiling —
    /// see `db::bootstrap::ensure_roles`.
    pub fn intersect(&self, other: &Grants) -> Grants {
        let files = match (&self.files, &other.files) {
            (Some(a), Some(b)) => Some(FilesGrant {
                mode: if a.allows_write() && b.allows_write() {
                    FilesMode::Write
                } else {
                    FilesMode::Read
                },
            }),
            _ => None,
        };
        let connect = match (&self.connect, &other.connect) {
            (Some(a), Some(b)) => {
                // Empty is anywhere, so it gives way to the other list; two
                // lists narrow to what both name.
                let allow: Vec<String> = match (a.allow.is_empty(), b.allow.is_empty()) {
                    (true, _) => b.allow.clone(),
                    (_, true) => a.allow.clone(),
                    _ => a
                        .allow
                        .iter()
                        .filter(|entry| b.allow.contains(entry))
                        .cloned()
                        .collect(),
                };
                // Two lists with nothing in common allow nothing, and an
                // empty list would read as anywhere: that is no grant.
                let nothing_in_common =
                    allow.is_empty() && !(a.allow.is_empty() && b.allow.is_empty());
                (!nothing_in_common).then_some(ConnectGrant { allow })
            }
            _ => None,
        };
        let listen = match (&self.listen, &other.listen) {
            (Some(a), Some(b)) => match (a.ports, b.ports) {
                (None, ports) | (ports, None) => Some(ListenGrant {
                    public: a.public && b.public,
                    ports,
                }),
                (Some([alo, ahi]), Some([blo, bhi])) => {
                    let (lo, hi) = (alo.max(blo), ahi.min(bhi));
                    (lo <= hi).then_some(ListenGrant {
                        public: a.public && b.public,
                        ports: Some([lo, hi]),
                    })
                }
            },
            _ => None,
        };
        Grants {
            shell: self.shell && other.shell,
            ssh_terminal: self.ssh_terminal && other.ssh_terminal,
            files,
            connect,
            listen,
            virt: self.virt && other.virt,
        }
    }

    /// Whether [`grant`] is held at all, whatever its options.
    pub fn holds(&self, grant: Grant) -> bool {
        match grant {
            Grant::Shell => self.shell,
            Grant::SshTerminal => self.ssh_terminal,
            Grant::Files => self.files.is_some(),
            Grant::Connect => self.connect.is_some(),
            Grant::Listen => self.listen.is_some(),
            Grant::Virt => self.virt,
        }
    }

    /// What the switches in an agent's `config.toml` *effectively* granted
    /// every panel login before roles existed — the admin role's grants on an
    /// upgrade, so nobody's access changes by upgrading.
    ///
    /// Effectively, not literally: `full_access` only counted while the
    /// terminal was enabled, so `full_access = true` without
    /// `terminal.enabled` gave nothing and gives nothing here. [`full_access`]
    /// is the old switch already resolved the way the old agent resolved it
    /// (platform default, `SBM_FULL_ACCESS`).
    pub fn from_legacy(
        terminal_enabled: bool,
        full_access: bool,
        listen_public: bool,
        files_usable: bool,
    ) -> Self {
        let shell = terminal_enabled && full_access;
        Self {
            shell,
            ssh_terminal: terminal_enabled,
            files: files_usable.then_some(FilesGrant {
                mode: FilesMode::Write,
            }),
            connect: shell.then(ConnectGrant::default),
            listen: shell.then_some(ListenGrant {
                public: listen_public,
                ports: None,
            }),
            // Newer than every one of those switches. A shell reaches the
            // same hypervisors with the same credentials, so it comes with
            // one, as it does on a role upgraded by migration 011.
            virt: shell,
        }
    }

    /// Refuses what cannot be stored: an `allow` entry that does not parse, a
    /// port range that is empty or includes 0.
    pub fn validate(&self) -> Result<(), String> {
        if let Some(connect) = &self.connect {
            for entry in &connect.allow {
                entry
                    .parse::<AllowEntry>()
                    .map_err(|e| format!("connect.allow {entry:?}: {e}"))?;
            }
        }
        if let Some(ListenGrant {
            ports: Some([lo, hi]),
            ..
        }) = &self.listen
            && (*lo == 0 || lo > hi)
        {
            return Err(format!(
                "listen.ports [{lo}, {hi}] must be 1..=65535 with lo <= hi"
            ));
        }
        Ok(())
    }
}

/// A named set of grants. Every account holds exactly one.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Role {
    pub name: String,
    /// May manage accounts, roles and the agent's own configuration.
    #[serde(default)]
    pub admin: bool,
    /// `admin` and `viewer`: cannot be renamed or deleted. Ignored on input.
    #[serde(default)]
    pub builtin: bool,
    #[serde(default)]
    pub grants: Grants,
}

/// `[a-z0-9_-]{1,32}`.
pub fn valid_role_name(name: &str) -> bool {
    (1..=32).contains(&name.len())
        && name
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-')
}

/// What a fresh install starts with — the installer's `--permissions`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum InitPermissions {
    /// The first admin holds every grant.
    #[default]
    Full,
    /// The first admin can administer the agent and holds no grant; it turns
    /// them on from the app or the panel.
    Read,
}

impl InitPermissions {
    pub fn grants(self) -> Grants {
        match self {
            InitPermissions::Full => Grants::all(),
            InitPermissions::Read => Grants::none(),
        }
    }
}

impl FromStr for InitPermissions {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "full" => Ok(InitPermissions::Full),
            "read" => Ok(InitPermissions::Read),
            other => Err(format!("expected full or read, got {other:?}")),
        }
    }
}

/// One entry of [`ConnectGrant::allow`], parsed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AllowEntry {
    net: IpAddr,
    prefix: u8,
    ports: Option<(u16, u16)>,
}

impl AllowEntry {
    pub fn matches(&self, addr: SocketAddr) -> bool {
        // An IPv4 address reached as `::ffff:a.b.c.d` is that IPv4 address:
        // without this, an entry for `10.0.0.0/8` would not match the same
        // host dialled through a dual-stack resolver's answer.
        let ip = addr.ip().to_canonical();
        let in_net = match (self.net, ip) {
            (IpAddr::V4(net), IpAddr::V4(ip)) => {
                let mask = prefix_mask_u32(self.prefix);
                u32::from(net) & mask == u32::from(ip) & mask
            }
            (IpAddr::V6(net), IpAddr::V6(ip)) => {
                let mask = prefix_mask_u128(self.prefix);
                u128::from(net) & mask == u128::from(ip) & mask
            }
            _ => false,
        };
        in_net
            && self
                .ports
                .is_none_or(|(lo, hi)| (lo..=hi).contains(&addr.port()))
    }
}

fn prefix_mask_u32(prefix: u8) -> u32 {
    if prefix == 0 { 0 } else { u32::MAX << (32 - prefix) }
}

fn prefix_mask_u128(prefix: u8) -> u128 {
    if prefix == 0 { 0 } else { u128::MAX << (128 - prefix) }
}

impl FromStr for AllowEntry {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let s = s.trim();
        // `[addr or cidr]` with an optional `:ports`, for IPv6; otherwise an
        // IPv4 one with an optional `:ports`, or a bare IPv6 one with none —
        // a bare IPv6 address's own colons leave no way to tell a port apart.
        let (net, ports) = if let Some(rest) = s.strip_prefix('[') {
            let (inside, after) = rest.split_once(']').ok_or("unclosed '['")?;
            let ports = match after {
                "" => None,
                p => Some(p.strip_prefix(':').ok_or("expected ':' after ']'")?),
            };
            (inside, ports)
        } else if s.matches(':').count() == 1 {
            let (net, ports) = s.split_once(':').expect("one colon");
            (net, Some(ports))
        } else {
            (s, None)
        };

        let (addr, prefix) = match net.split_once('/') {
            Some((addr, prefix)) => (addr, Some(prefix)),
            None => (net, None),
        };
        let net: IpAddr = addr
            .parse()
            .map_err(|_| format!("{addr:?} is not an IP address"))?;
        let max = if net.is_ipv4() { 32 } else { 128 };
        let prefix = match prefix {
            None => max,
            Some(p) => p
                .parse::<u8>()
                .ok()
                .filter(|p| *p <= max)
                .ok_or_else(|| format!("prefix {p:?} must be 0..={max}"))?,
        };
        let ports = ports.map(parse_ports).transpose()?;
        Ok(Self { net, prefix, ports })
    }
}

fn parse_ports(spec: &str) -> Result<(u16, u16), String> {
    let port = |p: &str| {
        p.parse::<u16>()
            .ok()
            .filter(|p| *p != 0)
            .ok_or_else(|| format!("{p:?} is not a port"))
    };
    let (lo, hi) = match spec.split_once('-') {
        Some((lo, hi)) => (port(lo)?, port(hi)?),
        None => {
            let p = port(spec)?;
            (p, p)
        }
    };
    if lo > hi {
        return Err(format!("port range {lo}-{hi} is empty"));
    }
    Ok((lo, hi))
}

impl fmt::Display for InitPermissions {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            InitPermissions::Full => "full",
            InitPermissions::Read => "read",
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn addr(s: &str) -> SocketAddr {
        s.parse().unwrap()
    }

    fn connect(allow: &[&str]) -> ConnectGrant {
        ConnectGrant {
            allow: allow.iter().map(|s| s.to_string()).collect(),
        }
    }

    #[test]
    fn an_empty_allow_list_is_anywhere() {
        assert!(connect(&[]).permits(addr("203.0.113.7:22")));
    }

    #[test]
    fn an_address_matches_itself_on_any_port() {
        let grant = connect(&["127.0.0.1"]);
        assert!(grant.permits(addr("127.0.0.1:3389")));
        assert!(grant.permits(addr("127.0.0.1:22")));
        assert!(!grant.permits(addr("127.0.0.2:22")));
    }

    #[test]
    fn a_port_or_range_narrows_it() {
        let grant = connect(&["127.0.0.1:3389", "10.0.0.0/8:5900-5910"]);
        assert!(grant.permits(addr("127.0.0.1:3389")));
        assert!(!grant.permits(addr("127.0.0.1:22")));
        assert!(grant.permits(addr("10.1.2.3:5905")));
        assert!(!grant.permits(addr("10.1.2.3:5911")));
        assert!(!grant.permits(addr("11.0.0.1:5905")));
    }

    #[test]
    fn cidr_prefixes_mask_as_written() {
        let grant = connect(&["192.168.0.0/16", "0.0.0.0/0:443"]);
        assert!(grant.permits(addr("192.168.200.1:1")));
        assert!(grant.permits(addr("8.8.8.8:443")));
        assert!(!grant.permits(addr("8.8.8.8:80")));
    }

    #[test]
    fn ipv6_is_bracketed_with_a_port_and_bare_without() {
        let grant = connect(&["::1", "[fd00::/8]:443"]);
        assert!(grant.permits(addr("[::1]:22")));
        assert!(grant.permits(addr("[fd12::1]:443")));
        assert!(!grant.permits(addr("[fd12::1]:80")));
        assert!(!grant.permits(addr("[fe80::1]:443")));
    }

    #[test]
    fn an_ipv4_mapped_address_is_the_ipv4_one() {
        let grant = connect(&["10.0.0.0/8"]);
        assert!(grant.permits(addr("[::ffff:10.0.0.1]:22")));
    }

    #[test]
    fn families_do_not_match_each_other() {
        assert!(!connect(&["0.0.0.0/0"]).permits(addr("[::1]:22")));
        assert!(!connect(&["::/0"]).permits(addr("127.0.0.1:22")));
    }

    #[test]
    fn what_cannot_be_matched_is_refused_on_the_way_in() {
        for bad in [
            "localhost",
            "10.0.0.0/33",
            "[::1",
            "127.0.0.1:0",
            "127.0.0.1:80-22",
            "127.0.0.1:http",
        ] {
            let grants = Grants {
                connect: Some(connect(&[bad])),
                ..Grants::none()
            };
            assert!(grants.validate().is_err(), "{bad} should be refused");
        }
    }

    #[test]
    fn a_listen_range_is_inclusive_and_refuses_any_port() {
        let grant = ListenGrant {
            public: false,
            ports: Some([8000, 8100]),
        };
        assert!(grant.permits_port(8000));
        assert!(grant.permits_port(8100));
        assert!(!grant.permits_port(8101));
        assert!(!grant.permits_port(0));
        assert!(ListenGrant::default().permits_port(0));
    }

    #[test]
    fn an_empty_or_zero_listen_range_is_refused() {
        for ports in [[0, 10], [10, 9]] {
            let grants = Grants {
                listen: Some(ListenGrant {
                    public: false,
                    ports: Some(ports),
                }),
                ..Grants::none()
            };
            assert!(grants.validate().is_err());
        }
    }

    #[test]
    fn grants_read_and_write_the_documented_shape() {
        let json = r#"{"shell":false,"ssh_terminal":false,"files":null,
            "connect":{"allow":["127.0.0.1:3389"]},"listen":null,"virt":true}"#;
        let grants: Grants = serde_json::from_str(json).unwrap();
        assert_eq!(grants.connect.as_ref().unwrap().allow, ["127.0.0.1:3389"]);
        assert!(!grants.holds(Grant::Listen));
        assert!(grants.holds(Grant::Virt));
        let back = serde_json::to_value(&grants).unwrap();
        assert_eq!(back["files"], serde_json::Value::Null);
        assert_eq!(back["listen"], serde_json::Value::Null);
        // An empty object is nothing granted.
        assert_eq!(serde_json::from_str::<Grants>("{}").unwrap(), Grants::none());
        // A misspelt grant is an error, not a grant quietly left off.
        assert!(serde_json::from_str::<Grants>(r#"{"shel":true}"#).is_err());
    }

    #[test]
    fn the_legacy_switches_map_to_what_they_effectively_gave() {
        // full_access without the terminal never took effect.
        assert_eq!(
            Grants::from_legacy(false, true, false, false),
            Grants::none()
        );
        let both = Grants::from_legacy(true, true, true, true);
        assert!(both.shell && both.ssh_terminal && both.virt);
        assert_eq!(both.connect, Some(ConnectGrant::default()));
        assert_eq!(
            both.listen,
            Some(ListenGrant {
                public: true,
                ports: None
            })
        );
        assert_eq!(
            both.files,
            Some(FilesGrant {
                mode: FilesMode::Write
            })
        );
        let terminal_only = Grants::from_legacy(true, false, false, false);
        assert!(terminal_only.ssh_terminal && !terminal_only.shell && !terminal_only.virt);
        assert!(terminal_only.connect.is_none() && terminal_only.listen.is_none());
    }

    #[test]
    fn role_names_are_short_lowercase_slugs() {
        assert!(valid_role_name("desktop"));
        assert!(valid_role_name("ops_2-a"));
        assert!(!valid_role_name(""));
        assert!(!valid_role_name("Desktop"));
        assert!(!valid_role_name("a b"));
        assert!(!valid_role_name(&"a".repeat(33)));
    }

    #[test]
    fn init_permissions_parse() {
        assert_eq!("full".parse::<InitPermissions>(), Ok(InitPermissions::Full));
        assert_eq!(" READ ".parse::<InitPermissions>(), Ok(InitPermissions::Read));
        assert!("none".parse::<InitPermissions>().is_err());
    }
}
