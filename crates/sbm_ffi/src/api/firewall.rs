//! Firewall FFI (sbm_parser::firewall)
//!
//! ufw and firewalld by the rules the monitor agent's panel will use: the
//! scripts that read them and what they print, the commands that change them,
//! the checks on what is typed, and — before any change — whether it would
//! shut a way the app reaches the server ([`FirewallReach`]). The app runs the
//! scripts as root over its own connection and keeps the page's state; a
//! change it is about to make is judged here, with the zones or rules as they
//! would be passed in.
//!
//! The models are `sbm_parser`'s own, mirrored rather than copied.

use std::collections::HashMap;

use flutter_rust_bridge::frb;
pub use sbm_parser::firewall::firewalld::{
    FirewalldInputIssue, FirewalldItem, FirewalldPolicy, FirewalldPort, FirewalldRichRule, FirewalldSnapshot, FirewalldTarget, FirewalldZone,
};
pub use sbm_parser::firewall::ufw::{
    UfwAction, UfwApp, UfwAppPort, UfwChain, UfwDirection, UfwDraftIssue, UfwEndpoint, UfwIpVersion, UfwLog, UfwLogLevel, UfwPolicy, UfwRule,
    UfwRuleDraft, UfwSnapshot,
};
pub use sbm_parser::firewall::{FirewallAccess, FirewallAccessVia, FirewallKind, FirewallProbeResult, FirewallReach};
use sbm_parser::firewall::{self, firewalld, ufw};

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(FirewallKind))]
pub enum _FirewallKind {
    Ufw,
    Firewalld,
}

#[frb(mirror(FirewallAccessVia))]
pub enum _FirewallAccessVia {
    Ssh,
    Monitor,
}

#[frb(mirror(FirewallAccess))]
pub struct _FirewallAccess {
    pub via: FirewallAccessVia,
    pub port: u16,
    pub client: Option<String>,
    pub server: Option<String>,
}

#[frb(mirror(FirewallReach))]
pub enum _FirewallReach {
    Open,
    Limited,
    Unknown,
    Blocked,
}

#[frb(mirror(FirewallProbeResult))]
pub struct _FirewallProbeResult {
    pub ufw: Option<bool>,
    pub firewalld: Option<bool>,
    pub root: bool,
    pub ssh: Option<FirewallAccess>,
    pub ssh_interface: Option<String>,
}

#[frb(mirror(UfwAction))]
pub enum _UfwAction {
    Allow,
    Deny,
    Reject,
    Limit,
}

#[frb(mirror(UfwDirection))]
pub enum _UfwDirection {
    Incoming,
    Outgoing,
}

#[frb(mirror(UfwPolicy))]
pub enum _UfwPolicy {
    Allow,
    Deny,
    Reject,
}

#[frb(mirror(UfwChain))]
pub enum _UfwChain {
    Incoming,
    Outgoing,
    Routed,
}

#[frb(mirror(UfwLogLevel))]
pub enum _UfwLogLevel {
    Off,
    Low,
    Medium,
    High,
    Full,
}

#[frb(mirror(UfwIpVersion))]
pub enum _UfwIpVersion {
    V4,
    V6,
    Both,
}

#[frb(mirror(UfwLog))]
pub enum _UfwLog {
    Log,
    LogAll,
}

#[frb(mirror(UfwEndpoint))]
pub struct _UfwEndpoint {
    pub address: Option<String>,
    pub port: Option<String>,
    pub app: Option<String>,
}

#[frb(mirror(UfwRule))]
pub struct _UfwRule {
    pub action: UfwAction,
    pub direction: UfwDirection,
    pub routed: bool,
    pub log: Option<UfwLog>,
    pub protocol: Option<String>,
    pub to: UfwEndpoint,
    pub from: UfwEndpoint,
    pub interface_in: Option<String>,
    pub interface_out: Option<String>,
    pub comment: Option<String>,
    pub ip_version: UfwIpVersion,
    pub tuples: Vec<String>,
}

#[frb(mirror(UfwAppPort))]
pub struct _UfwAppPort {
    pub port: String,
    pub protocol: Option<String>,
}

#[frb(mirror(UfwApp))]
pub struct _UfwApp {
    pub name: String,
    pub ports: Vec<UfwAppPort>,
}

#[frb(mirror(UfwSnapshot))]
pub struct _UfwSnapshot {
    pub active: Option<bool>,
    pub status_line: Option<String>,
    pub version: Option<String>,
    pub log_level: Option<UfwLogLevel>,
    pub ipv6: bool,
    pub policies: HashMap<UfwChain, UfwPolicy>,
    pub rules: Vec<UfwRule>,
    pub apps: Vec<UfwApp>,
}

#[frb(mirror(UfwRuleDraft))]
pub struct _UfwRuleDraft {
    pub action: UfwAction,
    pub direction: UfwDirection,
    pub routed: bool,
    pub protocol: Option<String>,
    pub port: String,
    pub source_port: String,
    pub app: Option<String>,
    pub from: String,
    pub to: String,
    pub interface_in: String,
    pub interface_out: String,
    pub log: Option<UfwLog>,
    pub comment: String,
    pub prepend: bool,
}

#[frb(mirror(UfwDraftIssue))]
pub enum _UfwDraftIssue {
    NothingMatched,
    InvalidPort,
    TooManyPorts,
    PortsNeedProtocol,
    InvalidAddress,
    MixedIpVersions,
    InvalidInterface,
    InvalidComment,
}

#[frb(mirror(FirewalldTarget))]
pub enum _FirewalldTarget {
    DefaultTarget,
    Accept,
    Drop,
    Reject,
}

#[frb(mirror(FirewalldPort))]
pub struct _FirewalldPort {
    pub port: String,
    pub protocol: String,
}

#[frb(mirror(FirewalldRichRule))]
pub struct _FirewalldRichRule {
    pub raw: String,
    pub priority: i32,
    pub family: Option<String>,
    pub source: Option<String>,
    pub source_not: bool,
    pub source_other: bool,
    pub destination: Option<String>,
    pub destination_not: bool,
    pub element: Option<String>,
    pub service: Option<String>,
    pub port: Option<String>,
    pub protocol: Option<String>,
    pub action: Option<String>,
    pub limited: bool,
}

#[frb(mirror(FirewalldZone))]
pub struct _FirewalldZone {
    pub name: String,
    pub target: FirewalldTarget,
    pub active: bool,
    pub interfaces: Vec<String>,
    pub sources: Vec<String>,
    pub services: Vec<String>,
    pub ports: Vec<FirewalldPort>,
    pub protocols: Vec<String>,
    pub source_ports: Vec<FirewalldPort>,
    pub forward_ports: Vec<String>,
    pub rich_rules: Vec<FirewalldRichRule>,
    pub masquerade: bool,
}

#[frb(mirror(FirewalldPolicy))]
pub struct _FirewalldPolicy {
    pub name: String,
    pub target: String,
    pub egress_host: bool,
    pub decides: bool,
}

#[frb(mirror(FirewalldSnapshot))]
pub struct _FirewalldSnapshot {
    pub running: bool,
    pub version: Option<String>,
    pub default_zone: Option<String>,
    pub panic: bool,
    pub runtime: Option<Vec<FirewalldZone>>,
    pub permanent: Vec<FirewalldZone>,
    pub services: HashMap<String, Vec<FirewalldPort>>,
    pub service_names: Vec<String>,
    pub policies: Vec<FirewalldPolicy>,
}

#[frb(mirror(FirewalldInputIssue))]
pub enum _FirewalldInputIssue {
    InvalidPort,
    InvalidSource,
    InvalidInterface,
    InvalidRichRule,
    InvalidForwardPort,
}

#[frb(mirror(FirewalldItem))]
pub enum _FirewalldItem {
    Service,
    Port,
    RichRule,
    Source,
    ForwardPort,
}

// --- Both --------------------------------------------------------------------

/// Which firewalls the server has, and how the app reaches it; for `sh`,
/// never as root.
#[frb(sync)]
pub fn firewall_probe_script() -> String {
    firewall::PROBE_SCRIPT.to_owned()
}

#[frb(sync)]
pub fn firewall_parse_probe(output: String) -> FirewallProbeResult {
    firewall::parse_probe(&output)
}

/// The firewall to show first.
#[frb(sync)]
pub fn firewall_preferred(probe: FirewallProbeResult) -> Option<FirewallKind> {
    probe.preferred()
}

/// `commands` as one script, stopping at the first that fails, never
/// exiting 2.
#[frb(sync)]
pub fn firewall_script(commands: Vec<String>) -> String {
    firewall::script(&commands)
}

#[frb(sync)]
pub fn firewall_reach_admits(reach: FirewallReach) -> bool {
    reach.admits()
}

/// Whether `after` is a change for the worse from `before`.
#[frb(sync)]
pub fn firewall_reach_worse_than(after: FirewallReach, before: FirewallReach) -> bool {
    after.worse_than(before)
}

// --- ufw ---------------------------------------------------------------------

#[frb(sync)]
pub fn ufw_read_script() -> String {
    ufw::read_script()
}

#[frb(sync)]
pub fn ufw_parse(output: String) -> Result<UfwSnapshot, String> {
    ufw::parse(&output)
}

/// Whether a new connection like `access` gets through; `active`, `rules`
/// and `incoming` stand in for the snapshot's own.
#[frb(sync)]
pub fn ufw_reach(snapshot: UfwSnapshot, access: FirewallAccess, active: Option<bool>, rules: Option<Vec<UfwRule>>, incoming: Option<UfwPolicy>) -> FirewallReach {
    snapshot.reach(&access, active, rules.as_deref(), incoming)
}

/// The snapshot's rules with `added` first, or last.
#[frb(sync)]
pub fn ufw_with_rules(snapshot: UfwSnapshot, added: Vec<UfwRule>, prepend: bool) -> Vec<UfwRule> {
    snapshot.with_rules(&added, prepend)
}

/// The rules ufw would add for `draft`, with `apps` resolving a profile.
#[frb(sync)]
pub fn ufw_draft_rules(draft: UfwRuleDraft, apps: Vec<UfwApp>) -> Vec<UfwRule> {
    draft.as_rules(&apps)
}

#[frb(sync)]
pub fn ufw_validate_draft(draft: UfwRuleDraft) -> Option<UfwDraftIssue> {
    ufw::validate_draft(&draft)
}

/// The command adding `draft`; an error names the issue
/// [`ufw_validate_draft`] would have.
#[frb(sync)]
pub fn ufw_add_command(draft: UfwRuleDraft) -> Result<String, String> {
    ufw::add_command(&draft).map_err(|issue| format!("{issue:?}"))
}

#[frb(sync)]
pub fn ufw_delete_commands(rule: UfwRule) -> Vec<String> {
    ufw::delete_commands(&rule)
}

#[frb(sync)]
pub fn ufw_enable_command() -> String {
    ufw::ENABLE_COMMAND.to_owned()
}

#[frb(sync)]
pub fn ufw_disable_command() -> String {
    ufw::DISABLE_COMMAND.to_owned()
}

#[frb(sync)]
pub fn ufw_reload_command() -> String {
    ufw::RELOAD_COMMAND.to_owned()
}

#[frb(sync)]
pub fn ufw_policy_command(chain: UfwChain, policy: UfwPolicy) -> String {
    ufw::policy_command(chain, policy)
}

#[frb(sync)]
pub fn ufw_logging_command(level: UfwLogLevel) -> String {
    ufw::logging_command(level)
}

/// Lets TCP in to `port`, before every other rule.
#[frb(sync)]
pub fn ufw_allow_tcp_command(port: u16) -> String {
    ufw::allow_tcp_command(port)
}

/// `in`, `out`: the word ufw writes.
#[frb(sync)]
pub fn ufw_direction_token(direction: UfwDirection) -> String {
    direction.token().to_owned()
}

/// `log`, `log-all`: the word ufw writes.
#[frb(sync)]
pub fn ufw_log_token(log: UfwLog) -> String {
    log.token().to_owned()
}

// --- firewalld ---------------------------------------------------------------

#[frb(sync)]
pub fn firewalld_read_script() -> String {
    firewalld::read_script()
}

#[frb(sync)]
pub fn firewalld_parse(output: String) -> Result<FirewalldSnapshot, String> {
    firewalld::parse(&output)
}

/// What is in force: the runtime while running, else the permanent.
#[frb(sync)]
pub fn firewalld_zones(snapshot: FirewalldSnapshot) -> Vec<FirewalldZone> {
    snapshot.zones().to_vec()
}

#[frb(sync)]
pub fn firewalld_drifted(snapshot: FirewalldSnapshot) -> bool {
    snapshot.drifted()
}

/// The zones a connection like `access` may be handled by; `zones` and
/// `default_zone` stand in for the snapshot's own.
#[frb(sync)]
pub fn firewalld_zones_for(
    snapshot: FirewalldSnapshot,
    access: FirewallAccess,
    iface: Option<String>,
    zones: Option<Vec<FirewalldZone>>,
    default_zone: Option<String>,
) -> Vec<FirewalldZone> {
    snapshot.zones_for(&access, iface.as_deref(), zones.as_deref(), default_zone.as_deref())
}

/// Whether a new connection like `access` gets through; `running`, `panic`,
/// `zones` and `default_zone` stand in for the snapshot's own.
#[frb(sync)]
pub fn firewalld_reach(
    snapshot: FirewalldSnapshot,
    access: FirewallAccess,
    iface: Option<String>,
    running: Option<bool>,
    panic: Option<bool>,
    zones: Option<Vec<FirewalldZone>>,
    default_zone: Option<String>,
) -> FirewallReach {
    snapshot.reach(&access, iface.as_deref(), running, panic, zones.as_deref(), default_zone.as_deref())
}

#[frb(sync)]
pub fn firewalld_parse_rich_rule(raw: String) -> FirewalldRichRule {
    FirewalldRichRule::parse(&raw)
}

/// `8080/tcp`, as firewalld writes a port and takes it back.
#[frb(sync)]
pub fn firewalld_port_spec(port: FirewalldPort) -> String {
    port.to_string()
}

/// What `--set-target` takes: `%%REJECT%%` for `REJECT`.
#[frb(sync)]
pub fn firewalld_target_token(target: FirewalldTarget) -> String {
    target.token().to_owned()
}

/// Adds `value` to `zone`, or removes it; both configurations while
/// `running`.
#[frb(sync)]
pub fn firewalld_item_commands(running: bool, zone: String, item: FirewalldItem, value: String, add: bool) -> Vec<String> {
    firewalld::item_commands(running, &zone, item, &value, add)
}

#[frb(sync)]
pub fn firewalld_port_commands(running: bool, zone: String, port: FirewalldPort, add: bool) -> Vec<String> {
    firewalld::item_commands(running, &zone, FirewalldItem::Port, &port.to_string(), add)
}

/// A rich rule letting TCP in to `port` before anything in its zone.
#[frb(sync)]
pub fn firewalld_keep_open_rule(port: u16) -> String {
    firewalld::keep_open_rule(port)
}

#[frb(sync)]
pub fn firewalld_change_interface(running: bool, zone: String, iface: String) -> Vec<String> {
    firewalld::change_interface(running, &zone, &iface)
}

#[frb(sync)]
pub fn firewalld_remove_interface(running: bool, zone: String, iface: String) -> Vec<String> {
    firewalld::remove_interface(running, &zone, &iface)
}

#[frb(sync)]
pub fn firewalld_masquerade(running: bool, zone: String, add: bool) -> Vec<String> {
    firewalld::masquerade(running, &zone, add)
}

#[frb(sync)]
pub fn firewalld_target(running: bool, zone: String, target: FirewalldTarget) -> Vec<String> {
    firewalld::target(running, &zone, target)
}

#[frb(sync)]
pub fn firewalld_default_zone(running: bool, zone: String) -> String {
    firewalld::default_zone(running, &zone)
}

#[frb(sync)]
pub fn firewalld_reload_command() -> String {
    firewalld::RELOAD_COMMAND.to_owned()
}

#[frb(sync)]
pub fn firewalld_runtime_to_permanent_command() -> String {
    firewalld::RUNTIME_TO_PERMANENT_COMMAND.to_owned()
}

#[frb(sync)]
pub fn firewalld_panic_off_command() -> String {
    firewalld::PANIC_OFF_COMMAND.to_owned()
}

#[frb(sync)]
pub fn firewalld_start_command() -> String {
    firewalld::START_COMMAND.to_owned()
}

#[frb(sync)]
pub fn firewalld_stop_command() -> String {
    firewalld::STOP_COMMAND.to_owned()
}

/// A typed port as firewalld writes it, or None.
#[frb(sync)]
pub fn firewalld_parse_port(value: String) -> Option<FirewalldPort> {
    firewalld::parse_port(&value)
}

#[frb(sync)]
pub fn firewalld_check_source(value: String) -> Option<FirewalldInputIssue> {
    firewalld::check_source(&value)
}

#[frb(sync)]
pub fn firewalld_check_interface(value: String) -> Option<FirewalldInputIssue> {
    firewalld::check_interface(&value)
}

#[frb(sync)]
pub fn firewalld_check_rich_rule(value: String) -> Option<FirewalldInputIssue> {
    firewalld::check_rich_rule(&value)
}

#[frb(sync)]
pub fn firewalld_check_forward_port(value: String) -> Option<FirewalldInputIssue> {
    firewalld::check_forward_port(&value)
}
