//! ufw: its rules read from the `### tuple ###` lines of its own rule files,
//! its settings from its config, and the commands that change it.
//!
//! Everything here needs root: ufw keeps its rule files `0640 root`, and
//! `ufw status` refuses anyone else.

use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use super::{decide, family_of, has_control, holds, port_spec_covers, valid_interface, FirewallAccess, FirewallReach, Judged, ENV};
use crate::script::shell_quote_unix as quote;

/// What a rule does with a packet it matches. Named as ufw names them, which
/// is also the word the rule is added with.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwAction {
    Allow,
    Deny,
    Reject,
    /// Allows, but denies an address that opened six or more connections in
    /// the last thirty seconds.
    Limit,
}

impl UfwAction {
    pub fn name(self) -> &'static str {
        match self {
            Self::Allow => "allow",
            Self::Deny => "deny",
            Self::Reject => "reject",
            Self::Limit => "limit",
        }
    }

    fn from_name(value: &str) -> Option<Self> {
        [Self::Allow, Self::Deny, Self::Reject, Self::Limit].into_iter().find(|a| a.name() == value)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwDirection {
    Incoming,
    Outgoing,
}

impl UfwDirection {
    /// The word ufw takes and writes: `in`, `out`.
    pub fn token(self) -> &'static str {
        match self {
            Self::Incoming => "in",
            Self::Outgoing => "out",
        }
    }

    fn from_token(value: &str) -> Option<Self> {
        [Self::Incoming, Self::Outgoing].into_iter().find(|d| d.token() == value)
    }
}

/// What ufw does with a packet no rule matched.
///
/// Stored in `/etc/default/ufw` under iptables' names (`ACCEPT`, `DROP`,
/// `REJECT`); set with ufw's (`ufw default deny incoming`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwPolicy {
    Allow,
    Deny,
    Reject,
}

impl UfwPolicy {
    fn name(self) -> &'static str {
        match self {
            Self::Allow => "allow",
            Self::Deny => "deny",
            Self::Reject => "reject",
        }
    }

    fn from_target(value: &str) -> Option<Self> {
        match value.to_ascii_uppercase().as_str() {
            "ACCEPT" => Some(Self::Allow),
            "DROP" => Some(Self::Deny),
            "REJECT" => Some(Self::Reject),
            _ => None,
        }
    }
}

/// The three chains a default policy is set for.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwChain {
    Incoming,
    Outgoing,
    Routed,
}

impl UfwChain {
    const ALL: [UfwChain; 3] = [Self::Incoming, Self::Outgoing, Self::Routed];

    fn name(self) -> &'static str {
        match self {
            Self::Incoming => "incoming",
            Self::Outgoing => "outgoing",
            Self::Routed => "routed",
        }
    }

    /// `DEFAULT_<key>_POLICY` in `/etc/default/ufw`.
    fn key(self) -> &'static str {
        match self {
            Self::Incoming => "INPUT",
            Self::Outgoing => "OUTPUT",
            Self::Routed => "FORWARD",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwLogLevel {
    Off,
    Low,
    Medium,
    High,
    Full,
}

impl UfwLogLevel {
    const ALL: [UfwLogLevel; 5] = [Self::Off, Self::Low, Self::Medium, Self::High, Self::Full];

    fn name(self) -> &'static str {
        match self {
            Self::Off => "off",
            Self::Low => "low",
            Self::Medium => "medium",
            Self::High => "high",
            Self::Full => "full",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwIpVersion {
    V4,
    V6,
    Both,
}

/// What a rule logs of its own, beyond ufw's logging level.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwLog {
    /// New connections the rule matches.
    Log,
    /// Every packet the rule matches.
    LogAll,
}

impl UfwLog {
    /// The word ufw takes and writes.
    pub fn token(self) -> &'static str {
        match self {
            Self::Log => "log",
            Self::LogAll => "log-all",
        }
    }

    fn from_token(value: &str) -> Option<Self> {
        [Self::Log, Self::LogAll].into_iter().find(|l| l.token() == value)
    }
}

/// One end of a rule: an address, and a port or an application profile.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Default, serde::Serialize, serde::Deserialize)]
pub struct UfwEndpoint {
    /// None for any address.
    pub address: Option<String>,
    /// As ufw writes it: `22`, `80,443`, `6000:6010`. None for any port.
    pub port: Option<String>,
    /// The application profile `port` came from, as the rule was added.
    pub app: Option<String>,
}

/// One rule, as ufw keeps it in `/etc/ufw/user.rules` and `user6.rules`.
///
/// Read from the `### tuple ###` lines of those files rather than from
/// `ufw status`. The status table is drawn for reading: its columns are padded
/// to a width a long rule overflows, its words are translated with the
/// server's locale, and an inactive firewall prints no rules at all. The
/// tuples are what ufw itself reloads its rules from.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct UfwRule {
    pub action: UfwAction,
    pub direction: UfwDirection,
    /// A `ufw route` rule, which matches forwarded packets rather than those
    /// addressed to this host.
    pub routed: bool,
    /// None when the rule logs nothing of its own.
    pub log: Option<UfwLog>,
    /// `tcp`, `udp`, another protocol name, or None for any.
    pub protocol: Option<String>,
    pub to: UfwEndpoint,
    pub from: UfwEndpoint,
    /// The interface a packet arrives on, for an incoming or routed rule.
    pub interface_in: Option<String>,
    /// The interface a packet leaves by, for an outgoing or routed rule.
    pub interface_out: Option<String>,
    pub comment: Option<String>,
    /// [`UfwIpVersion::Both`] where ufw added the same rule to both families,
    /// as it does for a rule naming no address; deleting it deletes both.
    pub ip_version: UfwIpVersion,
    /// The tuple lines this rule was read from, v4's first. Deletion names a
    /// rule by these, never by a position the list may have moved since.
    pub tuples: Vec<String>,
}

impl UfwRule {
    /// What this rule does to a new connection like `access`; None when it
    /// surely does not apply. "Might" is an address, a source port or an
    /// interface that cannot be known for the connection.
    fn judge(&self, access: &FirewallAccess) -> Option<Judged> {
        if self.routed || self.direction != UfwDirection::Incoming {
            return None;
        }
        if self.protocol.as_deref().is_some_and(|p| p != "tcp") {
            return None;
        }
        if !port_spec_covers(self.to.port.as_deref(), access.port) {
            return None;
        }
        let client = access.client_ip();
        if let Some(client) = client {
            let other = if client.is_ipv6() { UfwIpVersion::V4 } else { UfwIpVersion::V6 };
            if self.ip_version == other {
                return None;
            }
        }
        let mut sure = self.interface_in.is_none() && self.from.port.is_none();
        for (network, address) in [(&self.from.address, client), (&self.to.address, access.server_ip())] {
            let Some(network) = network else { continue };
            match holds(network, address) {
                Some(false) => return None,
                None => sure = false,
                Some(true) => {}
            }
        }
        let verdict = match self.action {
            UfwAction::Allow => FirewallReach::Open,
            UfwAction::Limit => FirewallReach::Limited,
            UfwAction::Deny | UfwAction::Reject => FirewallReach::Blocked,
        };
        Some(Judged { verdict, sure })
    }
}

/// One port spec of an application profile: `80,443/tcp`, `53`.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct UfwAppPort {
    pub port: String,
    /// None for both.
    pub protocol: Option<String>,
}

impl UfwAppPort {
    fn parse(spec: &str) -> Option<Self> {
        let value = spec.trim();
        if value.is_empty() {
            return None;
        }
        Some(match value.split_once('/') {
            Some((port, protocol)) => UfwAppPort { port: port.to_owned(), protocol: Some(protocol.to_owned()) },
            None => UfwAppPort { port: value.to_owned(), protocol: None },
        })
    }
}

/// An application profile: a name a rule can use for its ports.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct UfwApp {
    pub name: String,
    pub ports: Vec<UfwAppPort>,
}

/// What a server's ufw is doing, as one read found it.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct UfwSnapshot {
    /// Whether ufw's rules are loaded now; None when `ufw status` answered
    /// something other than a status, which `status_line` then holds.
    pub active: Option<bool>,
    pub status_line: Option<String>,
    /// `0.36.2`.
    pub version: Option<String>,
    pub log_level: Option<UfwLogLevel>,
    /// `IPV6=yes`. With it off ufw loads no v6 rule, so none is listed.
    pub ipv6: bool,
    pub policies: HashMap<UfwChain, UfwPolicy>,
    pub rules: Vec<UfwRule>,
    /// Application profiles a rule can name, from `ufw app info all`.
    pub apps: Vec<UfwApp>,
}

impl UfwSnapshot {
    /// Whether a new connection like `access` gets through, the way ufw
    /// decides it: the first rule that matches, else the incoming policy.
    ///
    /// `active`, `rules` and `incoming` stand in for this snapshot's own, to
    /// ask about a change before it is made.
    ///
    /// A rule that only might match makes the answer
    /// [`FirewallReach::Unknown`] where it would decide otherwise than the
    /// rule that surely matches after it.
    pub fn reach(&self, access: &FirewallAccess, active: Option<bool>, rules: Option<&[UfwRule]>, incoming: Option<UfwPolicy>) -> FirewallReach {
        // Only a ufw known to be off lets everything in; one whose status
        // could not be read is judged by its rules.
        if active.or(self.active) == Some(false) {
            return FirewallReach::Open;
        }
        // With IPv6 off ufw leaves ip6tables alone, whatever the rules say.
        if !self.ipv6 && access.client_ip().is_some_and(|c| c.is_ipv6()) {
            return FirewallReach::Open;
        }
        let rules = rules.unwrap_or(&self.rules);
        let fallback = match incoming.or_else(|| self.policies.get(&UfwChain::Incoming).copied()) {
            Some(UfwPolicy::Allow) => FirewallReach::Open,
            Some(UfwPolicy::Deny | UfwPolicy::Reject) => FirewallReach::Blocked,
            // A policy that could not be read decides nothing either way.
            None => FirewallReach::Unknown,
        };
        decide(rules.iter().filter_map(|r| r.judge(access)), fallback)
    }

    /// `rules` with `added` put where ufw puts a new rule: first, or last.
    pub fn with_rules(&self, added: &[UfwRule], prepend: bool) -> Vec<UfwRule> {
        if prepend {
            added.iter().chain(&self.rules).cloned().collect()
        } else {
            self.rules.iter().chain(added).cloned().collect()
        }
    }
}

/// A rule as the add form describes it.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct UfwRuleDraft {
    pub action: UfwAction,
    /// Which side of this host the rule is on. Not asked of a `routed` rule,
    /// whose interfaces say.
    pub direction: UfwDirection,
    /// A `ufw route` rule, for packets this host forwards.
    pub routed: bool,
    /// `tcp`, `udp` or None for both. Not offered with `app`, whose profile
    /// says.
    pub protocol: Option<String>,
    /// The destination port; empty for any.
    pub port: String,
    pub source_port: String,
    pub app: Option<String>,
    /// Empty for any address.
    pub from: String,
    pub to: String,
    /// The interface a packet arrives on: an incoming rule's, or a routed
    /// one's. An outgoing rule has none, and this is not read for it.
    pub interface_in: String,
    /// The interface a packet leaves by: an outgoing rule's, or a routed
    /// one's. An incoming rule has none, and this is not read for it.
    pub interface_out: String,
    pub log: Option<UfwLog>,
    pub comment: String,
    /// Put before every other rule, rather than after: ufw stops at the first
    /// rule that matches.
    pub prepend: bool,
}

impl UfwRuleDraft {
    /// A draft of `action` and `direction` with nothing else set.
    pub fn new(action: UfwAction, direction: UfwDirection) -> Self {
        UfwRuleDraft {
            action,
            direction,
            routed: false,
            protocol: None,
            port: String::new(),
            source_port: String::new(),
            app: None,
            from: String::new(),
            to: String::new(),
            interface_in: String::new(),
            interface_out: String::new(),
            log: None,
            comment: String::new(),
            prepend: false,
        }
    }

    /// `interface_in` where this rule has one, trimmed; empty otherwise.
    fn effective_interface_in(&self) -> &str {
        if self.routed || self.direction == UfwDirection::Incoming { self.interface_in.trim() } else { "" }
    }

    /// `interface_out` where this rule has one, trimmed; empty otherwise.
    fn effective_interface_out(&self) -> &str {
        if self.routed || self.direction == UfwDirection::Outgoing { self.interface_out.trim() } else { "" }
    }

    /// The rules ufw would add for this draft, as far as they decide what
    /// reaches this host: one per port spec of an application profile, which
    /// `apps` says. Without the profile there, none — nothing can be said of
    /// ports that are not known.
    pub fn as_rules(&self, apps: &[UfwApp]) -> Vec<UfwRule> {
        let or_none = |v: &str| (!v.trim().is_empty()).then(|| v.trim().to_owned());
        let ports = match &self.app {
            None => vec![UfwAppPort { port: self.port.trim().to_owned(), protocol: self.protocol.clone() }],
            Some(app) => apps.iter().find(|a| &a.name == app).map(|a| a.ports.clone()).unwrap_or_default(),
        };
        let family = if [&self.from, &self.to].iter().any(|a| a.contains(':')) {
            UfwIpVersion::V6
        } else if [&self.from, &self.to].iter().any(|a| !a.trim().is_empty()) {
            UfwIpVersion::V4
        } else {
            UfwIpVersion::Both
        };
        ports
            .into_iter()
            .map(|spec| UfwRule {
                action: self.action,
                direction: self.direction,
                routed: self.routed,
                log: None,
                protocol: spec.protocol,
                to: UfwEndpoint { address: or_none(&self.to), port: or_none(&spec.port), app: self.app.clone() },
                from: UfwEndpoint { address: or_none(&self.from), port: or_none(&self.source_port), app: None },
                interface_in: or_none(self.effective_interface_in()),
                interface_out: or_none(self.effective_interface_out()),
                comment: None,
                ip_version: family,
                tuples: Vec::new(),
            })
            .collect()
    }
}

/// Why a [`UfwRuleDraft`] cannot be added, said before ufw is asked.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UfwDraftIssue {
    NothingMatched,
    InvalidPort,
    TooManyPorts,
    PortsNeedProtocol,
    InvalidAddress,
    MixedIpVersions,
    InvalidInterface,
    InvalidComment,
    InvalidProtocol,
}

/// The protocols `ufw ... proto` takes.
const PROTOCOLS: [&str; 8] = ["tcp", "udp", "ah", "esp", "gre", "ipv6", "igmp", "vrrp"];

pub const VERSION_MARKER: &str = "SrvBoxUfw.Version\t";
pub const STATUS_MARKER: &str = "SrvBoxUfw.Status\t";
const DEFAULTS_MARKER: &str = "SrvBoxUfw.Defaults";
const CONF_MARKER: &str = "SrvBoxUfw.Conf";
const V4_MARKER: &str = "SrvBoxUfw.V4";
const V6_MARKER: &str = "SrvBoxUfw.V6";
const APPS_MARKER: &str = "SrvBoxUfw.Apps";
/// `grep` could not read the v6 file (exit 2), rather than found no rule.
const V6_UNREADABLE: &str = "SrvBoxUfw.V6Unreadable";

const RULES4: &str = "/etc/ufw/user.rules";
const RULES6: &str = "/etc/ufw/user6.rules";
const TUPLE_PREFIX: &str = "### tuple ### ";
const ANY4: &str = "0.0.0.0/0";
const ANY6: &str = "::/0";

/// Everything [`parse`] reads, in one script. Never exits 2: that is how the
/// app's `PrivilegedExec` says sudo refused the password, and `grep` exits 2
/// on a file it cannot open. An unreadable v4 file is an error of its own
/// rather than an empty rule list.
pub fn read_script() -> String {
    format!(
        "{ENV}\n\
         [ -r {RULES4} ] || {{ echo 'Cannot read {RULES4}' >&2; exit 1; }}\n\
         v=$(ufw version 2>/dev/null | head -n 1)\n\
         s=$(ufw status 2>&1 | grep -v '^WARN' | head -n 1)\n\
         printf '{VERSION_MARKER}%s\\n' \"$v\"\n\
         printf '{STATUS_MARKER}%s\\n' \"$s\"\n\
         echo {DEFAULTS_MARKER}\n\
         grep -E '^(IPV6|DEFAULT_[A-Z]+_POLICY)=' /etc/default/ufw 2>/dev/null\n\
         echo {CONF_MARKER}\n\
         grep -E '^LOGLEVEL=' /etc/ufw/ufw.conf 2>/dev/null\n\
         echo {V4_MARKER}\n\
         grep '^{TUPLE_PREFIX}' {RULES4} 2>/dev/null\n\
         echo {V6_MARKER}\n\
         grep '^{TUPLE_PREFIX}' {RULES6} 2>/dev/null; [ $? -le 1 ] || echo {V6_UNREADABLE}\n\
         echo {APPS_MARKER}\n\
         ufw app info all 2>/dev/null\n\
         exit 0\n"
    )
}

/// What [`read_script`] printed; an error when it has no status line, or the
/// v6 rules could not be read while IPv6 is on — a list missing them would
/// be judged as complete.
pub fn parse(output: &str) -> Result<UfwSnapshot, String> {
    let markers = [DEFAULTS_MARKER, CONF_MARKER, V4_MARKER, V6_MARKER, APPS_MARKER];
    let mut version = None;
    let mut status = None;
    let mut sections: HashMap<&str, Vec<String>> = HashMap::new();
    let mut section: Option<&str> = None;
    let mut v6_unreadable = false;
    let normalized = output.replace("\r\n", "\n");
    for raw in normalized.split('\n') {
        let line = raw.trim_end();
        if let Some(v) = line.strip_prefix(VERSION_MARKER) {
            version = Some(v.trim().to_owned());
            continue;
        }
        if let Some(s) = line.strip_prefix(STATUS_MARKER) {
            status = Some(s.trim().to_owned());
            continue;
        }
        if line == V6_UNREADABLE {
            v6_unreadable = true;
            continue;
        }
        if let Some(marker) = markers.iter().find(|m| **m == line) {
            section = Some(marker);
            sections.insert(marker, Vec::new());
            continue;
        }
        if let Some(s) = section
            && !line.is_empty()
        {
            sections.get_mut(s).expect("opened").push(line.to_owned());
        }
    }
    let status = status.ok_or("Unable to read the ufw status")?;
    let empty = Vec::new();
    let defaults = key_values(sections.get(DEFAULTS_MARKER).unwrap_or(&empty));
    let conf = key_values(sections.get(CONF_MARKER).unwrap_or(&empty));
    let ipv6 = defaults.get("IPV6").is_none_or(|v| !v.eq_ignore_ascii_case("no"));
    if ipv6 && v6_unreadable {
        return Err(format!("Cannot read {RULES6}"));
    }
    let policies = UfwChain::ALL
        .into_iter()
        .filter_map(|chain| {
            let policy = UfwPolicy::from_target(defaults.get(&format!("DEFAULT_{}_POLICY", chain.key()))?)?;
            Some((chain, policy))
        })
        .collect();
    let version_re = regex::Regex::new(r"^ufw\s+").expect("static");
    Ok(UfwSnapshot {
        active: match status.as_str() {
            "Status: active" => Some(true),
            "Status: inactive" => Some(false),
            _ => None,
        },
        status_line: Some(status),
        version: version.map(|v| version_re.replace(&v, "").into_owned()),
        log_level: conf.get("LOGLEVEL").and_then(|l| UfwLogLevel::ALL.into_iter().find(|v| v.name().eq_ignore_ascii_case(l))),
        ipv6,
        policies,
        rules: merge_rules(
            sections.get(V4_MARKER).unwrap_or(&empty),
            if ipv6 { sections.get(V6_MARKER).unwrap_or(&empty) } else { &empty },
        ),
        apps: parse_apps(sections.get(APPS_MARKER).unwrap_or(&empty)),
    })
}

/// `ufw app info all`: a `Profile:` line per profile, and under `Ports:`
/// (`Port:` for one) its specs, indented.
pub fn parse_apps<S: AsRef<str>>(lines: &[S]) -> Vec<UfwApp> {
    let mut apps = Vec::new();
    let mut current: Option<UfwApp> = None;
    let mut in_ports = false;
    for line in lines {
        let line = line.as_ref();
        if let Some(name) = line.strip_prefix("Profile: ") {
            apps.extend(current.take());
            current = Some(UfwApp { name: name.trim().to_owned(), ports: Vec::new() });
            in_ports = false;
        } else if line == "Ports:" || line == "Port:" {
            in_ports = true;
        } else if in_ports && line.starts_with(' ') {
            if let (Some(app), Some(port)) = (current.as_mut(), UfwAppPort::parse(line)) {
                app.ports.push(port);
            }
        } else {
            in_ports = false;
        }
    }
    apps.extend(current);
    apps
}

/// `KEY=value` lines, quotes stripped, as ufw reads its own config.
fn key_values(lines: &[String]) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for line in lines {
        let Some(eq) = line.find('=').filter(|eq| *eq > 0) else { continue };
        let value = line[eq + 1..].trim();
        let value = value.strip_prefix(['"', '\'']).unwrap_or(value);
        let value = value.strip_suffix(['"', '\'']).unwrap_or(value);
        map.insert(line[..eq].trim().to_owned(), value.to_owned());
    }
    map
}

/// The rules of both files in the order ufw numbers them — v4's, then v6's —
/// with a v6 rule that only repeats a v4 one folded into it.
///
/// A rule naming no address is added to both families at once, and
/// `ufw status` lists it twice. Listed once here, and deleted as one.
pub fn merge_rules<S: AsRef<str>>(v4: &[S], v6: &[S]) -> Vec<UfwRule> {
    let twins: HashMap<String, &str> = v6.iter().map(|t| (v4_twin(t.as_ref()), t.as_ref())).collect();
    let mut merged = HashSet::new();
    let mut rules = Vec::new();
    for tuple in v4 {
        let tuple = tuple.as_ref();
        let twin = twins.get(tuple).copied();
        let rule = match twin {
            Some(twin) => parse_tuple(&[tuple, twin], UfwIpVersion::Both),
            None => parse_tuple(&[tuple], UfwIpVersion::V4),
        };
        let Some(rule) = rule else { continue };
        merged.extend(twin);
        rules.push(rule);
    }
    for tuple in v6 {
        let tuple = tuple.as_ref();
        if merged.contains(tuple) {
            continue;
        }
        rules.extend(parse_tuple(&[tuple], UfwIpVersion::V6));
    }
    rules
}

/// `v6_tuple` with its any-addresses written as v4's, which is what the same
/// rule looks like in `user.rules`.
fn v4_twin(v6_tuple: &str) -> String {
    let Some(rest) = v6_tuple.strip_prefix(TUPLE_PREFIX) else { return v6_tuple.to_owned() };
    let mut fields: Vec<&str> = rest.split(' ').collect();
    if fields.len() < 7 {
        return v6_tuple.to_owned();
    }
    for i in [3, 5] {
        if fields[i] == ANY6 {
            fields[i] = ANY4;
        }
    }
    format!("{TUPLE_PREFIX}{}", fields.join(" "))
}

/// Reads one rule from its tuple lines, the first of which says what it is.
///
/// ```text
/// <action>[_<log>] <proto> <dport> <dst> <sport> <src> [<dapp> <sapp>]
///   <direction>[_<iface>][!out_<iface>] [comment=<hex>]
/// ```
///
/// with `route:` before the action of a routed rule. None for a line this
/// does not recognise, which is left out rather than guessed at.
pub fn parse_tuple(tuples: &[&str], ip_version: UfwIpVersion) -> Option<UfwRule> {
    let line = tuples.first()?;
    let rest = line.strip_prefix(TUPLE_PREFIX)?;
    let mut fields: Vec<&str> = rest.trim().split(' ').collect();
    let mut comment = None;
    if let Some(hex) = fields.last().and_then(|f| f.strip_prefix("comment=")) {
        comment = decode_comment(hex);
        fields.pop();
    }
    if fields.len() != 7 && fields.len() != 9 {
        return None;
    }

    let (routed, head) = match fields[0].strip_prefix("route:") {
        Some(head) => (true, head),
        None => (false, fields[0]),
    };
    let (action, log) = match head.split_once('_') {
        Some((action, log)) => (action, Some(log)),
        None => (head, None),
    };
    let action = UfwAction::from_name(action)?;
    // A logging suffix this does not know is a rule this does not know.
    let log = match log {
        Some(token) => Some(UfwLog::from_token(token)?),
        None => None,
    };

    let mut direction = None;
    let mut interface_in = None;
    let mut interface_out = None;
    for part in fields[fields.len() - 1].split('!') {
        // Split at the first `_` only: an interface may have one of its own.
        let (dir, interface) = match part.split_once('_') {
            Some((dir, interface)) => (dir, Some(interface.to_owned())),
            None => (part, None),
        };
        let dir = UfwDirection::from_token(dir)?;
        direction.get_or_insert(dir);
        match dir {
            UfwDirection::Incoming => interface_in = interface,
            UfwDirection::Outgoing => interface_out = interface,
        }
    }

    let apps = fields.len() == 9;
    let or_none = |v: &str| (v != "any").then(|| v.to_owned());
    let address = |v: &str| (v != ANY4 && v != ANY6).then(|| v.to_owned());
    // ufw writes a profile's spaces as `%20`, and `-` for none.
    let app = |v: &str| (v != "-").then(|| v.replace("%20", " "));
    Some(UfwRule {
        action,
        log,
        routed,
        direction: direction?,
        protocol: or_none(fields[1]),
        to: UfwEndpoint { port: or_none(fields[2]), address: address(fields[3]), app: if apps { app(fields[6]) } else { None } },
        from: UfwEndpoint { port: or_none(fields[4]), address: address(fields[5]), app: if apps { app(fields[7]) } else { None } },
        interface_in,
        interface_out,
        comment,
        ip_version,
        tuples: tuples.iter().map(|t| (*t).to_owned()).collect(),
    })
}

/// ufw keeps a comment hex-encoded, so that it is one field.
fn decode_comment(hex: &str) -> Option<String> {
    if hex.is_empty() || !hex.len().is_multiple_of(2) || !hex.is_ascii() {
        return None;
    }
    let bytes: Option<Vec<u8>> = (0..hex.len()).step_by(2).map(|i| u8::from_str_radix(&hex[i..i + 2], 16).ok()).collect();
    Some(String::from_utf8_lossy(&bytes?).into_owned())
}

/// `--force`: ufw otherwise stops to ask whether SSH may be cut off, on a
/// terminal nobody is reading. The page asks instead.
pub const ENABLE_COMMAND: &str = "ufw --force enable";
pub const DISABLE_COMMAND: &str = "ufw disable";
pub const RELOAD_COMMAND: &str = "ufw reload";

pub fn policy_command(chain: UfwChain, policy: UfwPolicy) -> String {
    format!("ufw default {} {}", policy.name(), chain.name())
}

pub fn logging_command(level: UfwLogLevel) -> String {
    format!("ufw logging {}", level.name())
}

/// Lets TCP in to `port`, before every other rule — what a change that would
/// shut the app out is preceded by. First, because ufw stops at the first
/// rule that matches: added last, it would come after the deny that made it
/// necessary.
pub fn allow_tcp_command(port: u16) -> String {
    format!("ufw prepend allow in proto tcp from any to any port {port}")
}

/// Deletes `rule` by the number ufw gives its tuples now, found on the server
/// as the script runs. A number taken from the page could name another rule
/// by then: one added or deleted since shifts every number after it.
///
/// The number is the tuple's line among the v4 file's, then the v6 file's —
/// ufw's own order. With IPv6 off ufw does not count the v6 ones, and a v6
/// tuple's line is past the last number it has: ufw refuses it rather than
/// deleting another rule. Exits 3 where a tuple is gone, never 2.
pub fn delete_commands(rule: &UfwRule) -> Vec<String> {
    rule.tuples
        .iter()
        .flat_map(|tuple| {
            [
                format!("t={}", quote(tuple)),
                format!("n=$(grep -h '^{TUPLE_PREFIX}' {RULES4} {RULES6} 2>/dev/null | grep -nxF -e \"$t\" | head -n 1 | cut -d: -f1)"),
                r#"[ -n "$n" ] || { echo "Rule not found: $t" >&2; exit 3; }"#.to_owned(),
                r#"ufw --force delete "$n""#.to_owned(),
            ]
        })
        .collect()
}

/// The command adding `draft`, in the order ufw's parser takes it:
///
/// ```text
/// ufw [route] [prepend] <action> [in on X] [out on Y] [log] [proto P]
///   from A [port P] to B [port P | app N] [comment C]
/// ```
pub fn add_command(draft: &UfwRuleDraft) -> Result<String, UfwDraftIssue> {
    if let Some(issue) = validate_draft(draft) {
        return Err(issue);
    }
    let port = draft.port.trim();
    let source_port = draft.source_port.trim();
    let from = draft.from.trim();
    let to = draft.to.trim();
    let interface_in = draft.effective_interface_in();
    let interface_out = draft.effective_interface_out();
    // A rule on this host has one side, so at most one of the two is set.
    let interface = if interface_in.is_empty() { interface_out } else { interface_in };
    let comment = draft.comment.trim();
    let mut words: Vec<String> = vec!["ufw".into()];
    if draft.routed {
        words.push("route".into());
    }
    if draft.prepend {
        words.push("prepend".into());
    }
    words.push(draft.action.name().into());
    // A routed rule names a side only with its interface; a rule on this host
    // always names its one side.
    if draft.routed {
        if !interface_in.is_empty() {
            words.extend(["in".into(), "on".into(), quote(interface_in)]);
        }
        if !interface_out.is_empty() {
            words.extend(["out".into(), "on".into(), quote(interface_out)]);
        }
    } else {
        words.push(draft.direction.token().into());
        if !interface.is_empty() {
            words.extend(["on".into(), quote(interface)]);
        }
    }
    if let Some(log) = draft.log {
        words.push(log.token().into());
    }
    if let (None, Some(protocol)) = (&draft.app, &draft.protocol) {
        // One of [`PROTOCOLS`], as validation checked.
        words.extend(["proto".into(), protocol.clone()]);
    }
    words.push("from".into());
    words.push(if from.is_empty() { "any".into() } else { quote(from) });
    if !source_port.is_empty() {
        words.extend(["port".into(), source_port.into()]);
    }
    words.push("to".into());
    words.push(if to.is_empty() { "any".into() } else { quote(to) });
    if let Some(app) = &draft.app {
        words.extend(["app".into(), quote(app)]);
    } else if !port.is_empty() {
        words.extend(["port".into(), port.into()]);
    }
    if !comment.is_empty() {
        words.extend(["comment".into(), quote(comment)]);
    }
    Ok(words.join(" "))
}

/// What ufw would refuse in `draft`, or None. ufw checks again; this says it
/// in the form, and in the user's language.
pub fn validate_draft(draft: &UfwRuleDraft) -> Option<UfwDraftIssue> {
    let port = if draft.app.is_none() { draft.port.trim() } else { "" };
    let source_port = draft.source_port.trim();
    let from = draft.from.trim();
    let to = draft.to.trim();
    // A rule may match all of an interface's traffic, and nothing else.
    if draft.app.is_none()
        && port.is_empty()
        && source_port.is_empty()
        && from.is_empty()
        && to.is_empty()
        && draft.effective_interface_in().is_empty()
        && draft.effective_interface_out().is_empty()
    {
        return Some(UfwDraftIssue::NothingMatched);
    }
    // A rule naming a profile takes its protocol from it, and ufw refuses
    // `proto` beside `app`: none is written.
    let protocol = if draft.app.is_none() { draft.protocol.as_deref() } else { None };
    if protocol.is_some_and(|p| !PROTOCOLS.contains(&p)) {
        return Some(UfwDraftIssue::InvalidProtocol);
    }
    for spec in [port, source_port] {
        if spec.is_empty() {
            continue;
        }
        if let Some(issue) = port_issue(spec, protocol) {
            return Some(issue);
        }
    }
    let from_family = (!from.is_empty()).then(|| family_of(from));
    let to_family = (!to.is_empty()).then(|| family_of(to));
    if from_family == Some(None) || to_family == Some(None) {
        return Some(UfwDraftIssue::InvalidAddress);
    }
    if let (Some(Some(a)), Some(Some(b))) = (from_family, to_family)
        && a != b
    {
        return Some(UfwDraftIssue::MixedIpVersions);
    }
    for name in [draft.effective_interface_in(), draft.effective_interface_out()] {
        if !name.is_empty() && !valid_interface(name) {
            return Some(UfwDraftIssue::InvalidInterface);
        }
    }
    // ufw refuses a quote in a comment as invalid syntax.
    if draft.comment.contains('\'') || has_control(&draft.comment) {
        return Some(UfwDraftIssue::InvalidComment);
    }
    None
}

/// What ufw would refuse in one side's port `spec`.
fn port_issue(spec: &str, protocol: Option<&str>) -> Option<UfwDraftIssue> {
    static ITEM: LazyLock<regex::Regex> = LazyLock::new(|| regex::Regex::new(r"^([0-9]{1,5})(?::([0-9]{1,5}))?$").expect("static"));
    // iptables' multiport takes 15 ports, a range counting as two.
    let mut weight = 0;
    for part in spec.split(',') {
        let Some(m) = ITEM.captures(part) else { return Some(UfwDraftIssue::InvalidPort) };
        let start: u32 = m[1].parse().expect("digits");
        let end: Option<u32> = m.get(2).map(|e| e.as_str().parse().expect("digits"));
        if !(1..=65535).contains(&start) {
            return Some(UfwDraftIssue::InvalidPort);
        }
        if let Some(end) = end
            && (end <= start || end > 65535)
        {
            return Some(UfwDraftIssue::InvalidPort);
        }
        weight += if end.is_none() { 1 } else { 2 };
    }
    if weight > 15 {
        return Some(UfwDraftIssue::TooManyPorts);
    }
    if weight > 1 && protocol.is_none() {
        return Some(UfwDraftIssue::PortsNeedProtocol);
    }
    None
}
