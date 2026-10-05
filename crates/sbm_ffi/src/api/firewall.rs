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
pub use sbm_parser::firewall::change::{ChangeError, Effect, FirewalldChange, Plan, PlanNote, UfwChange};
pub use sbm_parser::firewall::{FirewallAccess, FirewallAccessVia, FirewallKind, FirewallProbeResult, FirewallReach};
use sbm_parser::firewall::{self, change, firewalld, ufw};

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
    pub iface: Option<String>,
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
    InvalidProtocol,
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

#[frb(mirror(UfwChange))]
pub enum _UfwChange {
    Enable,
    Disable,
    Reload,
    Policy { chain: UfwChain, policy: UfwPolicy },
    Logging { level: UfwLogLevel },
    AddRule { draft: UfwRuleDraft },
    DeleteRule { tuples: Vec<String> },
}

#[frb(mirror(FirewalldChange))]
pub enum _FirewalldChange {
    Start,
    Stop,
    Reload,
    RuntimeToPermanent,
    PanicOff,
    DefaultZone { zone: String },
    Target { zone: String, target: FirewalldTarget },
    Masquerade { zone: String, enabled: bool },
    Add { zone: String, item: FirewalldItem, value: String },
    Remove { zone: String, item: FirewalldItem, value: String },
    ChangeInterface { zone: String, iface: String },
    RemoveInterface { zone: String, iface: String },
}

#[frb(mirror(Effect))]
pub struct _Effect {
    pub access: FirewallAccess,
    pub before: FirewallReach,
    pub after: FirewallReach,
    pub later: bool,
    pub worse: bool,
}

#[frb(mirror(PlanNote))]
pub enum _PlanNote {
    ReloadLoses,
}

#[frb(mirror(Plan))]
pub struct _Plan {
    pub commands: Vec<String>,
    pub effects: Vec<Effect>,
    pub notes: Vec<PlanNote>,
    pub destructive: bool,
    pub confirm: bool,
    pub keep_open: Vec<String>,
    pub keep_open_default: bool,
    pub countdown: bool,
}

/// Why a change cannot be planned. Thrown by [`ufw_plan`] and
/// [`firewalld_plan`].
#[frb(mirror(ChangeError))]
pub enum _ChangeError {
    Unchanged,
    Draft(UfwDraftIssue),
    Input(FirewalldInputIssue),
    NoSuchRule,
    NoSuchZone,
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

// --- ufw ---------------------------------------------------------------------

#[frb(sync)]
pub fn ufw_read_script() -> String {
    ufw::read_script()
}

#[frb(sync)]
pub fn ufw_parse(output: String) -> Result<UfwSnapshot, String> {
    ufw::parse(&output)
}

#[frb(sync)]
pub fn ufw_validate_draft(draft: UfwRuleDraft) -> Option<UfwDraftIssue> {
    ufw::validate_draft(&draft)
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

#[frb(sync)]
pub fn firewalld_drifted(snapshot: FirewalldSnapshot) -> bool {
    snapshot.drifted()
}

/// `access` gets in now and will not once the saved configuration is in
/// force.
#[frb(sync)]
pub fn firewalld_shut_by_reload(snapshot: FirewalldSnapshot, access: FirewallAccess) -> bool {
    snapshot.shut_by_reload(&access)
}

/// The zones a connection like `access` may be handled by; `zones` and
/// `default_zone` stand in for the snapshot's own.
#[frb(sync)]
pub fn firewalld_zones_for(snapshot: FirewalldSnapshot, access: FirewallAccess, zones: Option<Vec<FirewalldZone>>, default_zone: Option<String>) -> Vec<FirewalldZone> {
    snapshot.zones_for(&access, zones.as_deref(), default_zone.as_deref())
}

// --- Changes -----------------------------------------------------------------

/// What `change` to ufw would run and do to each of `accesses`.
#[frb(sync)]
pub fn ufw_plan(snapshot: UfwSnapshot, change: UfwChange, accesses: Vec<FirewallAccess>) -> Result<Plan, ChangeError> {
    change::ufw_plan(&snapshot, &change, &accesses)
}

/// What `change` to firewalld would run and do to each of `accesses`.
#[frb(sync)]
pub fn firewalld_plan(snapshot: FirewalldSnapshot, change: FirewalldChange, accesses: Vec<FirewallAccess>) -> Result<Plan, ChangeError> {
    change::firewalld_plan(&snapshot, &change, &accesses)
}

/// What runs when `plan` is confirmed, its keep-open rules first or not.
#[frb(sync)]
pub fn firewall_plan_commands(plan: Plan, keep_open: bool) -> Vec<String> {
    plan.script_commands(keep_open)
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

