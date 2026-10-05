//! firewalld: both of its configurations — what the daemon enforces now
//! (runtime) and what is written down (permanent) — its policies and its
//! services, and the commands that change it.
//!
//! Run as root, like ufw: firewalld answers an unprivileged caller only where
//! polkit says so, and changes nothing for one.

use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use regex::Regex;

use super::{decide, has_control, holds, port_spec_covers, valid_interface, FirewallAccess, FirewallReach, Judged, ENV};
use crate::script::shell_quote_unix as quote;

/// What a zone does with a packet nothing in it matched.
///
/// `default` rejects, and is what a zone has unless it says otherwise.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FirewalldTarget {
    DefaultTarget,
    Accept,
    Drop,
    Reject,
}

impl FirewalldTarget {
    const ALL: [FirewalldTarget; 4] = [Self::DefaultTarget, Self::Accept, Self::Drop, Self::Reject];

    /// What `--list-all` prints, and `--set-target` takes. `%%REJECT%%` is
    /// how firewalld writes `REJECT`.
    pub fn token(self) -> &'static str {
        match self {
            Self::DefaultTarget => "default",
            Self::Accept => "ACCEPT",
            Self::Drop => "DROP",
            Self::Reject => "%%REJECT%%",
        }
    }

    fn from_token(value: &str) -> Option<Self> {
        if value == "REJECT" {
            return Some(Self::Reject);
        }
        Self::ALL.into_iter().find(|t| t.token() == value)
    }
}

/// One port spec: `8080/tcp`, `6000-6010/udp`.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct FirewalldPort {
    pub port: String,
    pub protocol: String,
}

impl FirewalldPort {
    fn parse(spec: &str) -> Option<Self> {
        let (port, protocol) = spec.split_once('/')?;
        if port.is_empty() || protocol.is_empty() {
            return None;
        }
        Some(FirewalldPort { port: port.to_owned(), protocol: protocol.to_owned() })
    }

    fn covers(&self, port: u16, protocol: &str) -> bool {
        self.protocol == protocol && port_spec_covers(Some(&self.port), port)
    }
}

impl std::fmt::Display for FirewalldPort {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}/{}", self.port, self.protocol)
    }
}

/// A rich rule, read as far as it decides what reaches this host.
///
/// `raw` is what firewalld printed, and what removing it names.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct FirewalldRichRule {
    pub raw: String,
    pub priority: i32,
    /// `ipv4`, `ipv6`, or None for both.
    pub family: Option<String>,
    pub source: Option<String>,
    pub source_not: bool,
    /// A source by ipset or MAC, which an address cannot be tested against.
    pub source_other: bool,
    pub destination: Option<String>,
    pub destination_not: bool,
    /// `service`, `port`, `protocol`, `icmp-block`, `forward-port`, …; None
    /// for a rule about all traffic.
    pub element: Option<String>,
    pub service: Option<String>,
    /// With `protocol`: the `port` element's.
    pub port: Option<String>,
    /// The `port` element's protocol, or the `protocol` element's value.
    pub protocol: Option<String>,
    /// `accept`, `reject`, `drop`, `mark`; None for a rule that only logs.
    pub action: Option<String>,
    /// The action has a `limit`.
    pub limited: bool,
}

const ELEMENTS: [&str; 9] = ["service", "port", "protocol", "icmp-block", "icmp-type", "masquerade", "forward-port", "source-port", "tcp-mss-clamp"];
const ACTIONS: [&str; 4] = ["accept", "reject", "drop", "mark"];

impl FirewalldRichRule {
    pub fn parse(raw: &str) -> Self {
        static TOKEN: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"([A-Za-z0-9_-]+)="([^"]*)"|(\S+)"#).expect("static"));
        let mut rule = FirewalldRichRule {
            raw: raw.to_owned(),
            priority: 0,
            family: None,
            source: None,
            source_not: false,
            source_other: false,
            destination: None,
            destination_not: false,
            element: None,
            service: None,
            port: None,
            protocol: None,
            action: None,
            limited: false,
        };
        let mut context: Option<String> = None;
        for m in TOKEN.captures_iter(raw) {
            if let Some(word) = m.get(3).map(|w| w.as_str()) {
                if word == "not" {
                    match context.as_deref() {
                        Some("source") => rule.source_not = true,
                        Some("destination") => rule.destination_not = true,
                        _ => {}
                    }
                } else if word == "limit" {
                    if context.as_deref().is_some_and(|c| ACTIONS.contains(&c)) {
                        rule.limited = true;
                    }
                    context = Some("limit".into());
                } else {
                    context = Some(word.to_owned());
                    if ELEMENTS.contains(&word) {
                        rule.element = Some(word.to_owned());
                    }
                    if ACTIONS.contains(&word) {
                        rule.action = Some(word.to_owned());
                    }
                }
                continue;
            }
            let value = m[2].to_owned();
            match (context.as_deref(), &m[1]) {
                (Some("rule"), "priority") => rule.priority = value.parse().unwrap_or(0),
                (Some("rule"), "family") => rule.family = Some(value),
                (Some("source"), "address") => rule.source = Some(value),
                (Some("source"), "ipset" | "mac") => rule.source_other = true,
                (Some("destination"), "address") => rule.destination = Some(value),
                (Some("service"), "name") => rule.service = Some(value),
                (Some("port"), "port") => rule.port = Some(value),
                // `port`'s `protocol=` and `protocol`'s `value=` are both the
                // protocol.
                (Some("port"), "protocol") | (Some("protocol"), "value") => rule.protocol = Some(value),
                _ => {}
            }
        }
        rule
    }

    /// What this rule decides for a new TCP connection like `access`, and
    /// whether it surely applies; None when it surely does not, or decides
    /// nothing. `services` are the ports of each service by name.
    fn judge(&self, access: &FirewallAccess, services: &HashMap<String, Vec<FirewalldPort>>) -> Option<Judged> {
        let verdict = match self.action.as_deref() {
            Some("accept") if self.limited => FirewallReach::Limited,
            Some("accept") => FirewallReach::Open,
            Some("reject" | "drop") => FirewallReach::Blocked,
            _ => return None,
        };
        let mut sure = true;
        let client = access.client_ip();
        match (client, &self.family) {
            (Some(client), Some(family)) => {
                if family != if client.is_ipv6() { "ipv6" } else { "ipv4" } {
                    return None;
                }
            }
            (None, Some(_)) => sure = false,
            _ => {}
        }
        if self.source_other {
            sure = false;
        }
        for (network, address, not) in [(&self.source, client, self.source_not), (&self.destination, access.server_ip(), self.destination_not)] {
            let Some(network) = network else { continue };
            match holds(network, address) {
                None => sure = false,
                Some(contains) if contains == not => return None,
                Some(_) => {}
            }
        }
        match self.element.as_deref() {
            None => {}
            Some("service") => match self.service.as_ref().and_then(|s| services.get(s)) {
                None => sure = false,
                Some(ports) if !ports.iter().any(|p| p.covers(access.port, "tcp")) => return None,
                Some(_) => {}
            },
            Some("port") => {
                if self.protocol.as_deref() != Some("tcp") || !port_spec_covers(self.port.as_deref(), access.port) {
                    return None;
                }
            }
            Some("protocol") => {
                if self.protocol.as_deref() != Some("tcp") {
                    return None;
                }
            }
            Some("source-port") => sure = false,
            Some(_) => return None,
        }
        Some(Judged { verdict, sure })
    }
}

/// One zone, as one configuration — runtime or permanent — has it.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct FirewalldZone {
    pub name: String,
    pub target: FirewalldTarget,
    /// Has an interface or a source bound to it, so something reaches it.
    pub active: bool,
    pub interfaces: Vec<String>,
    pub sources: Vec<String>,
    pub services: Vec<String>,
    pub ports: Vec<FirewalldPort>,
    pub protocols: Vec<String>,
    pub source_ports: Vec<FirewalldPort>,
    /// `port=80:proto=tcp:toport=8080:toaddr=`, as firewalld writes them.
    pub forward_ports: Vec<String>,
    pub rich_rules: Vec<FirewalldRichRule>,
    pub masquerade: bool,
}

impl FirewalldZone {
    /// Whether a new connection like `access` that this zone handles gets
    /// through, in firewalld's order: rich rules below priority 0, then at 0
    /// the rejects and drops before everything that accepts, then rich rules
    /// above 0, then `target`. Forwarded ports come first of all: they
    /// rewrite the connection before any of it is asked.
    pub fn reach(&self, access: &FirewallAccess, services: &HashMap<String, Vec<FirewalldPort>>) -> FirewallReach {
        let mut checks: Vec<Judged> = Vec::new();
        for spec in &self.forward_ports {
            let fields: HashMap<&str, &str> = spec.split(':').filter_map(|part| part.split_once('=').filter(|(k, _)| !k.is_empty())).collect();
            if fields.get("proto") == Some(&"tcp") && port_spec_covers(fields.get("port").copied(), access.port) {
                // Sent somewhere else: whether that answers is not this
                // zone's to say.
                checks.push(Judged { verdict: FirewallReach::Blocked, sure: false });
            }
        }
        let mut rich: Vec<&FirewalldRichRule> = self.rich_rules.iter().collect();
        rich.sort_by_key(|r| r.priority);
        let judged = |pick: &dyn Fn(i32) -> bool| -> Vec<Judged> {
            rich.iter().filter(|r| pick(r.priority)).filter_map(|r| r.judge(access, services)).collect()
        };
        checks.extend(judged(&|p| p < 0));
        let at_zero = judged(&|p| p == 0);
        checks.extend(at_zero.iter().filter(|c| c.verdict == FirewallReach::Blocked));
        let admitted = self.protocols.iter().any(|p| p == "tcp")
            || self.ports.iter().any(|p| p.covers(access.port, "tcp"))
            || services.iter().any(|(name, ports)| self.services.contains(name) && ports.iter().any(|p| p.covers(access.port, "tcp")));
        if admitted {
            checks.push(Judged { verdict: FirewallReach::Open, sure: true });
        }
        // A service there is no definition of may be the one that admits it.
        if self.services.iter().any(|s| !services.contains_key(s)) {
            checks.push(Judged { verdict: FirewallReach::Open, sure: false });
        }
        if self.source_ports.iter().any(|p| p.protocol == "tcp") {
            checks.push(Judged { verdict: FirewallReach::Open, sure: false });
        }
        checks.extend(at_zero.iter().filter(|c| c.verdict != FirewallReach::Blocked));
        checks.extend(judged(&|p| p > 0));
        let fallback = if self.target == FirewalldTarget::Accept { FirewallReach::Open } else { FirewallReach::Blocked };
        decide(checks, fallback)
    }

    /// What decides what the zone does, interfaces left out: one
    /// NetworkManager put in a zone is runtime-only by nature, and not a
    /// difference anyone made.
    fn digest(&self) -> String {
        let sorted = |items: &[String]| {
            let mut v = items.to_vec();
            v.sort();
            v.join(" ")
        };
        let ports: Vec<String> = self.ports.iter().map(|p| p.to_string()).collect();
        let rules: Vec<String> = self.rich_rules.iter().map(|r| r.raw.clone()).collect();
        [
            self.target.token().to_owned(),
            sorted(&self.sources),
            sorted(&self.services),
            sorted(&ports),
            sorted(&self.protocols),
            sorted(&self.forward_ports),
            sorted(&rules),
            self.masquerade.to_string(),
        ]
        .join(" | ")
    }
}

/// A policy, as far as it can decide what reaches this host.
#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct FirewalldPolicy {
    pub name: String,
    pub target: String,
    /// Applies to traffic for this host itself.
    pub egress_host: bool,
    /// Has a target or an entry that accepts or refuses anything other than
    /// ICMP — the default `allow-host-ipv6` only lets ICMPv6 in.
    pub decides: bool,
}

/// What a server's firewalld is doing, as one read found it.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct FirewalldSnapshot {
    /// The daemon is up, and `runtime` is what it enforces.
    pub running: bool,
    pub version: Option<String>,
    pub default_zone: Option<String>,
    /// Every packet dropped: `--panic-on`.
    pub panic: bool,
    /// Zones as the daemon has them now; None when it is not running.
    pub runtime: Option<Vec<FirewalldZone>>,
    /// Zones as they are written down, and will be after a reload or a boot.
    pub permanent: Vec<FirewalldZone>,
    /// The TCP and UDP ports of each service, by name.
    pub services: HashMap<String, Vec<FirewalldPort>>,
    /// Every service a zone could name.
    pub service_names: Vec<String>,
    pub policies: Vec<FirewalldPolicy>,
}

impl FirewalldSnapshot {
    /// What is in force: `runtime` while running, else `permanent`.
    pub fn zones(&self) -> &[FirewalldZone] {
        self.runtime.as_deref().unwrap_or(&self.permanent)
    }

    pub fn zone(&self, name: &str, permanent: bool) -> Option<&FirewalldZone> {
        let zones = if permanent { &self.permanent[..] } else { self.zones() };
        zones.iter().find(|z| z.name == name)
    }

    /// The runtime differs from what is written down: a reload or a boot will
    /// change what the firewall does. A zone only one of them has is a
    /// difference too — one written down and not loaded yet.
    pub fn drifted(&self) -> bool {
        let Some(runtime) = &self.runtime else { return false };
        let saved: HashMap<&str, String> = self.permanent.iter().map(|z| (z.name.as_str(), z.digest())).collect();
        let loaded: HashSet<&str> = runtime.iter().map(|z| z.name.as_str()).collect();
        runtime.iter().any(|z| saved.get(z.name.as_str()) != Some(&z.digest()))
            || self.permanent.iter().any(|z| !loaded.contains(z.name.as_str()))
    }

    /// `access` gets in now and will not once the saved configuration is in
    /// force: at a reload, a restart or a boot.
    pub fn shut_by_reload(&self, access: &FirewallAccess) -> bool {
        self.drifted()
            && self.reach(access, None, None, None, None).admits()
            && !self.reach(access, Some(true), None, Some(&self.permanent), None).admits()
    }

    /// The zones a connection like `access` may be handled by: the one whose
    /// sources hold its address, else the one its interface
    /// ([`FirewallAccess::iface`], where known) is in, else the default zone.
    /// Where something is not known, every zone it could be.
    ///
    /// `zones` and `default_zone` stand in for this snapshot's own.
    pub fn zones_for(&self, access: &FirewallAccess, zones: Option<&[FirewalldZone]>, default_zone: Option<&str>) -> Vec<FirewalldZone> {
        let interface = access.iface.as_deref();
        let list = zones.unwrap_or_else(|| self.zones());
        let default_zone = default_zone.or(self.default_zone.as_deref());
        let fallback = list.iter().position(|z| Some(z.name.as_str()) == default_zone);
        let client = access.client_ip();
        let mut by_source = Vec::new();
        let mut source_unknown = false;
        for (i, zone) in list.iter().enumerate() {
            for source in &zone.sources {
                match holds(source, client) {
                    Some(true) => by_source.push(i),
                    None => source_unknown = true,
                    Some(false) => {}
                }
            }
        }
        let mut candidates: Vec<usize> = Vec::new();
        let mut add = |i: usize| {
            if !candidates.contains(&i) {
                candidates.push(i);
            }
        };
        if !by_source.is_empty() && !source_unknown {
            by_source.into_iter().for_each(&mut add);
            return candidates.into_iter().map(|i| list[i].clone()).collect();
        }
        let by_interface: Vec<usize> = list
            .iter()
            .enumerate()
            .filter(|(_, z)| match interface {
                None => !z.interfaces.is_empty(),
                Some(name) => z.interfaces.iter().any(|i| i == name),
            })
            .map(|(i, _)| i)
            .collect();
        by_source.iter().copied().for_each(&mut add);
        if source_unknown {
            list.iter().enumerate().filter(|(_, z)| !z.sources.is_empty()).for_each(|(i, _)| add(i));
        }
        by_interface.iter().copied().for_each(&mut add);
        // The default zone takes an interface no zone names — and, where the
        // interface is unknown, may be the one.
        if interface.is_none() || by_interface.is_empty() {
            fallback.into_iter().for_each(&mut add);
        }
        candidates.into_iter().map(|i| list[i].clone()).collect()
    }

    /// Whether a new connection like `access` gets through.
    ///
    /// `running`, `panic`, `zones` and `default_zone` stand in for this
    /// snapshot's own, to ask about a change before it is made.
    pub fn reach(
        &self,
        access: &FirewallAccess,
        running: Option<bool>,
        panic: Option<bool>,
        zones: Option<&[FirewalldZone]>,
        default_zone: Option<&str>,
    ) -> FirewallReach {
        if !running.unwrap_or(self.running) {
            return FirewallReach::Open;
        }
        if panic.unwrap_or(self.panic) {
            return FirewallReach::Blocked;
        }
        let candidates = self.zones_for(access, zones, default_zone);
        if candidates.is_empty() {
            return FirewallReach::Unknown;
        }
        let reaches: HashSet<FirewallReach> = candidates.iter().map(|z| z.reach(access, &self.services)).collect();
        let reach = if reaches.len() == 1 {
            *reaches.iter().next().expect("one")
        } else if reaches.iter().all(|r| r.admits()) {
            // Let in by every zone it may be in, some at a rate.
            FirewallReach::Limited
        } else {
            FirewallReach::Unknown
        };
        if reach.admits() && self.policies.iter().any(|p| p.egress_host && p.decides) {
            return FirewallReach::Unknown;
        }
        reach
    }
}

/// Why a value typed for firewalld cannot be used, said before it is asked.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FirewalldInputIssue {
    InvalidPort,
    InvalidSource,
    InvalidInterface,
    InvalidRichRule,
    InvalidForwardPort,
}

const RUNNING_MARKER: &str = "SrvBoxFwd.Running";
const VERSION_MARKER: &str = "SrvBoxFwd.Version\t";
const DEFAULT_MARKER: &str = "SrvBoxFwd.Default\t";
const PANIC_MARKER: &str = "SrvBoxFwd.Panic\t";
const RUNTIME_MARKER: &str = "SrvBoxFwd.Runtime";
const PERMANENT_MARKER: &str = "SrvBoxFwd.Permanent";
const POLICIES_MARKER: &str = "SrvBoxFwd.Policies";
const SERVICES_MARKER: &str = "SrvBoxFwd.Services";
const SERVICE_NAMES_MARKER: &str = "SrvBoxFwd.ServiceNames";
/// A listing failed: what was read of the zones or policies is not all of
/// them.
const INCOMPLETE_MARKER: &str = "SrvBoxFwd.Incomplete";
const SERVICE_DIRS: &str = "/usr/lib/firewalld/services /etc/firewalld/services";

/// Both configurations while the daemon runs; the written one through
/// `firewall-offline-cmd` while it does not, since `firewall-cmd` then
/// answers nothing but "not running".
///
/// Services are read from their files rather than asked of firewalld one by
/// one: `firewall-cmd` is a Python program that takes a third of a second to
/// start, and a zone names a dozen.
///
/// Section markers start a line; every line firewalld prints under a zone is
/// indented, so none can look like one. Never exits 2 — see
/// [`super::script`].
pub fn read_script() -> String {
    format!(
        "{ENV}\n\
         if firewall-cmd --state >/dev/null 2>&1; then\n\
         \x20 echo {RUNNING_MARKER}\n\
         \x20 printf '{VERSION_MARKER}%s\\n' \"$(firewall-cmd --version 2>/dev/null)\"\n\
         \x20 printf '{DEFAULT_MARKER}%s\\n' \"$(firewall-cmd --get-default-zone 2>/dev/null)\"\n\
         \x20 printf '{PANIC_MARKER}%s\\n' \"$(firewall-cmd --query-panic 2>/dev/null)\"\n\
         \x20 echo {RUNTIME_MARKER}\n\
         \x20 firewall-cmd --list-all-zones 2>/dev/null || echo {INCOMPLETE_MARKER}\n\
         \x20 echo {PERMANENT_MARKER}\n\
         \x20 firewall-cmd --permanent --list-all-zones 2>/dev/null || echo {INCOMPLETE_MARKER}\n\
         \x20 echo {POLICIES_MARKER}\n\
         \x20 firewall-cmd --list-all-policies 2>/dev/null || echo {INCOMPLETE_MARKER}\n\
         else\n\
         \x20 printf '{VERSION_MARKER}%s\\n' \"$(firewall-offline-cmd --version 2>/dev/null)\"\n\
         \x20 printf '{DEFAULT_MARKER}%s\\n' \"$(firewall-offline-cmd --get-default-zone 2>/dev/null)\"\n\
         \x20 echo {PERMANENT_MARKER}\n\
         \x20 firewall-offline-cmd --list-all-zones 2>/dev/null || echo {INCOMPLETE_MARKER}\n\
         fi\n\
         echo {SERVICES_MARKER}\n\
         grep -H -o -E '<(port|include) [^>]*>' $(for d in {SERVICE_DIRS}; do ls -d \"$d\"/*.xml 2>/dev/null; done) 2>/dev/null\n\
         echo {SERVICE_NAMES_MARKER}\n\
         for d in {SERVICE_DIRS}; do ls \"$d\" 2>/dev/null; done\n\
         exit 0\n"
    )
}

/// What [`read_script`] printed; an error when it has no zones, or a listing
/// of them or of the policies failed — what it left out would be judged as
/// not there. firewalld always has its built-in zones, so a listing with none
/// is one that was cut short.
pub fn parse(output: &str) -> Result<FirewalldSnapshot, String> {
    let markers = [RUNTIME_MARKER, PERMANENT_MARKER, POLICIES_MARKER, SERVICES_MARKER, SERVICE_NAMES_MARKER];
    let mut running = false;
    let mut version = None;
    let mut default_zone = None;
    let mut panic = false;
    let mut sections: HashMap<&str, Vec<String>> = HashMap::new();
    let mut section: Option<&str> = None;
    let normalized = output.replace("\r\n", "\n");
    for raw in normalized.split('\n') {
        let line = raw.trim_end();
        if line == INCOMPLETE_MARKER {
            return Err("firewalld did not list its zones and policies".to_owned());
        }
        if line == RUNNING_MARKER {
            running = true;
        } else if let Some(v) = line.strip_prefix(VERSION_MARKER) {
            version = Some(v.trim().to_owned());
        } else if let Some(v) = line.strip_prefix(DEFAULT_MARKER) {
            default_zone = Some(v.trim().to_owned());
        } else if let Some(v) = line.strip_prefix(PANIC_MARKER) {
            panic = v.trim() == "yes";
        } else if let Some(marker) = markers.iter().find(|m| **m == line) {
            section = Some(marker);
            sections.insert(marker, Vec::new());
        } else if let Some(s) = section {
            sections.get_mut(s).expect("opened").push(raw.replace('\r', ""));
        }
    }
    let permanent = sections.get(PERMANENT_MARKER).ok_or("Unable to read firewalld zones")?;
    let empty = Vec::new();
    let mut names: Vec<String> = sections
        .get(SERVICE_NAMES_MARKER)
        .unwrap_or(&empty)
        .iter()
        .filter_map(|line| line.trim().strip_suffix(".xml").map(str::to_owned))
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    names.sort();
    let permanent = parse_zones(permanent);
    let runtime = running.then(|| parse_zones(sections.get(RUNTIME_MARKER).unwrap_or(&empty)));
    if permanent.is_empty() || runtime.as_ref().is_some_and(Vec::is_empty) {
        return Err("Unable to read firewalld zones".to_owned());
    }
    Ok(FirewalldSnapshot {
        running,
        version: version.filter(|v| !v.is_empty()),
        default_zone: default_zone.filter(|z| !z.is_empty()),
        panic,
        runtime,
        permanent,
        policies: parse_policies(sections.get(POLICIES_MARKER).unwrap_or(&empty)),
        services: parse_services(sections.get(SERVICES_MARKER).unwrap_or(&empty)),
        service_names: names,
    })
}

/// One zone's or policy's lines: the words of each `key: value`, and the
/// tab-indented lines under a key, each one item whole.
struct Block {
    header: String,
    fields: HashMap<String, Vec<String>>,
    items: HashMap<String, Vec<String>>,
}

impl Block {
    fn first(&self, key: &str) -> Option<&str> {
        self.fields.get(key).and_then(|f| f.first()).map(String::as_str)
    }

    /// The words in parentheses after a block's name: `public (default,
    /// active)` has `default` and `active`. Never the name itself, which may
    /// hold any of them — a zone may be called `inactive`.
    fn flags(&self) -> HashSet<&str> {
        static FLAGS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^\S+\s+\(([^)]*)\)$").expect("static"));
        FLAGS
            .captures(&self.header)
            .map(|m| m.get(1).expect("group").as_str().split(',').map(str::trim).collect())
            .unwrap_or_default()
    }
}

fn blocks<S: AsRef<str>>(lines: &[S]) -> Vec<Block> {
    let mut blocks: Vec<Block> = Vec::new();
    let mut key: Option<String> = None;
    for line in lines {
        let line = line.as_ref();
        if line.trim().is_empty() {
            continue;
        }
        if line.starts_with('\t') {
            if let (Some(block), Some(key)) = (blocks.last_mut(), &key) {
                block.items.entry(key.clone()).or_default().push(line.trim().to_owned());
            }
        } else if line.starts_with(' ') {
            let (Some(block), Some(colon)) = (blocks.last_mut(), line.find(':')) else { continue };
            let k = line[..colon].trim().to_owned();
            let words = line[colon + 1..].trim().split(' ').filter(|w| !w.is_empty()).map(str::to_owned).collect();
            block.fields.insert(k.clone(), words);
            key = Some(k);
        } else {
            key = None;
            blocks.push(Block { header: line.trim().to_owned(), fields: HashMap::new(), items: HashMap::new() });
        }
    }
    blocks
}

/// `--list-all-zones`: a line per zone name, `(active)` after one in use,
/// then its `key: value` lines indented by two spaces, and the items of a
/// multi-line key — forward ports, rich rules — indented by a tab.
pub fn parse_zones<S: AsRef<str>>(lines: &[S]) -> Vec<FirewalldZone> {
    blocks(lines)
        .into_iter()
        .filter_map(|block| {
            let name = block.header.split(' ').next().unwrap_or_default().to_owned();
            if name.is_empty() {
                return None;
            }
            let list = |key: &str| block.fields.get(key).cloned().unwrap_or_default();
            let ports = |key: &str| block.fields.get(key).map(|f| f.iter().filter_map(|s| FirewalldPort::parse(s)).collect()).unwrap_or_default();
            Some(FirewalldZone {
                active: block.flags().contains("active"),
                target: block.first("target").and_then(FirewalldTarget::from_token).unwrap_or(FirewalldTarget::DefaultTarget),
                interfaces: list("interfaces"),
                sources: list("sources"),
                services: list("services"),
                ports: ports("ports"),
                protocols: list("protocols"),
                source_ports: ports("source-ports"),
                forward_ports: block.items.get("forward-ports").cloned().unwrap_or_default(),
                rich_rules: block.items.get("rich rules").map(|r| r.iter().map(|r| FirewalldRichRule::parse(r)).collect()).unwrap_or_default(),
                masquerade: block.first("masquerade") == Some("yes"),
                name,
            })
        })
        .collect()
}

/// Active policies, as far as they may decide what reaches this host.
pub fn parse_policies<S: AsRef<str>>(lines: &[S]) -> Vec<FirewalldPolicy> {
    blocks(lines)
        .into_iter()
        .filter(|block| block.flags().contains("active"))
        .map(|block| {
            let target = block.first("target").unwrap_or("CONTINUE").to_owned();
            let decides = target != "CONTINUE"
                || ["services", "ports", "protocols", "forward-ports"].iter().any(|k| block.fields.get(*k).is_some_and(|f| !f.is_empty()))
                || block.items.get("rich rules").is_some_and(|r| r.iter().any(|r| !r.contains("icmp-type")));
            FirewalldPolicy {
                name: block.header.split(' ').next().unwrap_or_default().to_owned(),
                egress_host: block.fields.get("egress-zones").is_some_and(|z| z.iter().any(|z| z == "HOST")),
                target,
                decides,
            }
        })
        .collect()
}

/// `grep -H` over the service files: `path:<port protocol=… port=…/>` and
/// `path:<include service=…/>`. A file under `/etc` replaces the one of the
/// same name under `/usr/lib`; an include brings the other service's ports.
pub fn parse_services<S: AsRef<str>>(lines: &[S]) -> HashMap<String, Vec<FirewalldPort>> {
    static PORT: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"protocol="([^"]*)"|port="([^"]*)""#).expect("static"));
    static INCLUDE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"service="([^"]*)""#).expect("static"));
    #[derive(Default, Clone)]
    struct Own {
        ports: Vec<FirewalldPort>,
        includes: Vec<String>,
    }
    let mut paths: Vec<String> = Vec::new();
    let mut by_file: HashMap<String, Own> = HashMap::new();
    for line in lines {
        let line = line.as_ref();
        let Some(tag) = line.find(":<") else { continue };
        let path = &line[..tag];
        if !by_file.contains_key(path) {
            paths.push(path.to_owned());
        }
        let entry = by_file.entry(path.to_owned()).or_default();
        let element = &line[tag + 1..];
        if element.starts_with("<include") {
            if let Some(m) = INCLUDE.captures(element) {
                entry.includes.push(m[1].to_owned());
            }
            continue;
        }
        let (mut protocol, mut port) = (None, None);
        for m in PORT.captures_iter(element) {
            protocol = protocol.or(m.get(1).map(|p| p.as_str()));
            port = port.or(m.get(2).map(|p| p.as_str()));
        }
        if let (Some(protocol), Some(port)) = (protocol, port.filter(|p| !p.is_empty())) {
            entry.ports.push(FirewalldPort { port: port.to_owned(), protocol: protocol.to_owned() });
        }
    }
    // `/usr/lib` first, so `/etc` is applied after it and wins.
    paths.sort_by_key(|p| p.starts_with("/etc/"));
    let mut own: HashMap<String, Own> = HashMap::new();
    for path in &paths {
        let file = path.rsplit('/').next().unwrap_or(path);
        let name = file.strip_suffix(".xml").unwrap_or(file);
        own.insert(name.to_owned(), by_file[path].clone());
    }
    fn resolve(own: &HashMap<String, Own>, name: &str, seen: &mut HashSet<String>) -> Vec<FirewalldPort> {
        let Some(entry) = own.get(name) else { return Vec::new() };
        if !seen.insert(name.to_owned()) {
            return Vec::new();
        }
        let mut ports = entry.ports.clone();
        for include in &entry.includes {
            ports.extend(resolve(own, include, seen));
        }
        ports
    }
    own.keys().map(|name| (name.clone(), resolve(&own, name, &mut HashSet::new()))).collect()
}

/// `args` applied to what is in force and to what is written down while the
/// daemon runs — a change only to the runtime is gone at the next reload, one
/// only to the permanent waits for it — and through `firewall-offline-cmd` to
/// the written one while it does not.
///
/// Adding what is there, or removing what is not, is a warning and exit 0 to
/// `firewall-cmd`, so the two halves are safe when they already differ.
fn both(running: bool, args: &str) -> Vec<String> {
    if running {
        vec![format!("firewall-cmd {args}"), format!("firewall-cmd --permanent {args}")]
    } else {
        vec![format!("firewall-offline-cmd {args}")]
    }
}

fn zone_arg(zone: &str) -> String {
    format!("--zone={}", quote(zone))
}

fn item(zone: &str, add: bool, kind: &str, value: &str) -> String {
    format!("{} --{}-{kind}={}", zone_arg(zone), if add { "add" } else { "remove" }, quote(value))
}

/// What can be added to a zone and removed from it, one value each.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FirewalldItem {
    Service,
    Port,
    RichRule,
    Source,
    ForwardPort,
}

impl FirewalldItem {
    fn kind(self) -> &'static str {
        match self {
            Self::Service => "service",
            Self::Port => "port",
            Self::RichRule => "rich-rule",
            Self::Source => "source",
            Self::ForwardPort => "forward-port",
        }
    }
}

/// Adds `value` to `zone`, or removes it.
pub fn item_commands(running: bool, zone: &str, item_kind: FirewalldItem, value: &str, add: bool) -> Vec<String> {
    both(running, &item(zone, add, item_kind.kind(), value))
}

/// A rich rule letting TCP in to `port` before anything in its zone can
/// refuse it: the lowest priority there is, below every other rich rule.
pub fn keep_open_rule(port: u16) -> String {
    format!(r#"rule priority="-32768" port port="{port}" protocol="tcp" accept"#)
}

/// Moves `interface` into `zone`, out of whichever had it.
pub fn change_interface(running: bool, zone: &str, interface: &str) -> Vec<String> {
    both(running, &format!("{} --change-interface={}", zone_arg(zone), quote(interface)))
}

pub fn remove_interface(running: bool, zone: &str, interface: &str) -> Vec<String> {
    both(running, &item(zone, false, "interface", interface))
}

pub fn masquerade(running: bool, zone: &str, add: bool) -> Vec<String> {
    both(running, &format!("{} --{}-masquerade", zone_arg(zone), if add { "add" } else { "remove" }))
}

/// A target can only be written down; the daemon takes it at a reload, which
/// also drops every change made only to the runtime.
pub fn target(running: bool, zone: &str, target: FirewalldTarget) -> Vec<String> {
    let set = format!("{} --set-target={}", zone_arg(zone), quote(target.token()));
    if running {
        vec![format!("firewall-cmd --permanent {set}"), RELOAD_COMMAND.to_owned()]
    } else {
        vec![format!("firewall-offline-cmd {set}")]
    }
}

/// Changes both configurations at once, running or not.
pub fn default_zone(running: bool, zone: &str) -> String {
    format!("{} --set-default-zone={}", if running { "firewall-cmd" } else { "firewall-offline-cmd" }, quote(zone))
}

pub const RELOAD_COMMAND: &str = "firewall-cmd --reload";
pub const RUNTIME_TO_PERMANENT_COMMAND: &str = "firewall-cmd --runtime-to-permanent";
pub const PANIC_OFF_COMMAND: &str = "firewall-cmd --panic-off";
/// Started now and at boot; stopped now and at boot — the way ufw's enable
/// and disable are. systemd's where it is the init, OpenRC's otherwise
/// (Alpine, Gentoo), which has no `systemctl`; `rc-update del` fails on a
/// service that was never added, which is no reason not to stop it.
pub const START_COMMAND: &str = "if [ -d /run/systemd/system ]; then systemctl enable --now firewalld; else rc-update add firewalld default && rc-service firewalld start; fi";
pub const STOP_COMMAND: &str = "if [ -d /run/systemd/system ]; then systemctl disable --now firewalld; else rc-update del firewalld default >/dev/null 2>&1 || true; rc-service firewalld stop; fi";

/// A typed port, written as firewalld writes it; None for anything else.
pub fn parse_port(value: &str) -> Option<FirewalldPort> {
    static PORT: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^([0-9]{1,5})(?:-([0-9]{1,5}))?/(tcp|udp|sctp|dccp)$").expect("static"));
    let m = PORT.captures(value.trim())?;
    let start: u32 = m[1].parse().ok()?;
    let end: Option<u32> = m.get(2).map(|e| e.as_str().parse().expect("digits"));
    if !(1..=65535).contains(&start) {
        return None;
    }
    if let Some(end) = end
        && (end <= start || end > 65535)
    {
        return None;
    }
    Some(FirewalldPort { port: end.map_or(start.to_string(), |end| format!("{start}-{end}")), protocol: m[3].to_owned() })
}

pub fn check_source(value: &str) -> Option<FirewalldInputIssue> {
    static MAC: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$").expect("static"));
    static IPSET: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^ipset:[A-Za-z0-9_.-]+$").expect("static"));
    let v = value.trim();
    if MAC.is_match(v) || IPSET.is_match(v) || super::family_of(v).is_some() {
        None
    } else {
        Some(FirewalldInputIssue::InvalidSource)
    }
}

pub fn check_interface(value: &str) -> Option<FirewalldInputIssue> {
    (!valid_interface(value.trim())).then_some(FirewalldInputIssue::InvalidInterface)
}

/// firewalld checks the grammar; this only keeps a script one line long.
pub fn check_rich_rule(value: &str) -> Option<FirewalldInputIssue> {
    let v = value.trim();
    (!v.starts_with("rule") || has_control(v)).then_some(FirewalldInputIssue::InvalidRichRule)
}

pub fn check_forward_port(value: &str) -> Option<FirewalldInputIssue> {
    static FORWARD: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^port=[0-9]{1,5}(-[0-9]{1,5})?:proto=(tcp|udp|sctp|dccp)(:toport=([0-9]{1,5}(-[0-9]{1,5})?)?)?(:toaddr=[0-9A-Fa-f.:]*)?$").expect("static")
    });
    let v = value.trim();
    // Somewhere to send it: another port, another host, or both.
    let somewhere = v.contains(":toport=") || v.contains(":toaddr=");
    (!FORWARD.is_match(v) || !somewhere).then_some(FirewalldInputIssue::InvalidForwardPort)
}
