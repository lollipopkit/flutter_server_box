//! Services FFI (sbm_parser::service)
//!
//! What the monitor agent's panel runs and reads for a machine's units, for
//! the app's services page: which manager it is, the commands a listing is
//! read from and the listing they make, a unit's actions, log and
//! definition. The app runs the commands over its own connection. The models
//! are `sbm_parser::service`'s own, mirrored.

use std::collections::HashMap;

use flutter_rust_bridge::frb;
use sbm_parser::output::CommandOutput;
use sbm_parser::service;
pub use sbm_parser::service::{
    ServiceAction, ServiceListing, ServiceListingNotice, ServiceLog, ServiceLogLine, ServiceManagerType, ServiceScope, ServiceState, ServiceUnit,
    ServiceUnitType,
};

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(ServiceManagerType))]
pub enum _ServiceManagerType {
    Systemd,
    Procd,
    Openrc,
}

#[frb(mirror(ServiceUnitType))]
pub enum _ServiceUnitType {
    Service,
    Socket,
    Mount,
    Timer,
}

#[frb(mirror(ServiceScope))]
pub enum _ServiceScope {
    System,
    User,
}

#[frb(mirror(ServiceState))]
pub enum _ServiceState {
    Running,
    Stopped,
    Failed,
    Starting,
    Stopping,
    Unknown,
}

#[frb(mirror(ServiceAction))]
pub enum _ServiceAction {
    Start,
    Stop,
    Restart,
    Enable,
    Disable,
}

#[frb(mirror(ServiceUnit))]
pub struct _ServiceUnit {
    pub name: String,
    pub full_name: String,
    pub unit_type: ServiceUnitType,
    pub scope: ServiceScope,
    pub state: ServiceState,
    pub description: Option<String>,
    pub enabled: Option<bool>,
    pub unit_file_state: Option<String>,
    pub sub_state: Option<String>,
    pub result: Option<String>,
    pub exit_status: Option<i32>,
    pub memory_bytes: Option<i64>,
    pub since_millis: Option<i64>,
    pub next_elapse_millis: Option<i64>,
    pub actions: Vec<ServiceAction>,
    pub needs_attention: bool,
}

#[frb(mirror(ServiceListingNotice))]
pub enum _ServiceListingNotice {
    UserScopeUnavailable,
    DetailsUnavailable,
}

#[frb(mirror(ServiceListing))]
pub struct _ServiceListing {
    pub units: Vec<ServiceUnit>,
    pub notice: Option<ServiceListingNotice>,
    pub detail: Option<String>,
    pub sampled_at_millis: Option<i64>,
}

#[frb(mirror(ServiceLogLine))]
pub struct _ServiceLogLine {
    pub time: Option<String>,
    pub text: String,
}

#[frb(mirror(ServiceLog))]
pub struct _ServiceLog {
    pub lines: Vec<ServiceLogLine>,
    pub unreadable: bool,
}

// --- Types of this layer -----------------------------------------------------

/// Which manager the machine runs, from [`service_detect_script`]'s output.
pub struct ServiceProbe {
    /// `None` for one this build cannot list.
    pub manager: Option<ServiceManagerType>,
    /// What the machine called it, with its OS: `systemd (Debian GNU/Linux)`.
    pub description: String,
}

/// One command a listing is read from, by the name its output goes back
/// under ([`service_parse_listing`]). `None`: none for this manager.
pub struct ServiceCommand {
    pub name: String,
    pub command: Option<String>,
}

/// What one of those commands printed. A command that could not be run at
/// all is `succeeded: false` with why in `stderr`.
pub struct ServiceCommandOutput {
    pub name: String,
    pub stdout: String,
    pub stderr: String,
    pub succeeded: bool,
}

// --- Functions ---------------------------------------------------------------

/// POSIX `sh`, for `CommandExec.run(script, entry: 'sh')`.
#[frb(sync)]
pub fn service_detect_script() -> String {
    service::DETECT_SCRIPT.to_owned()
}

#[frb(sync)]
pub fn service_parse_probe(raw: String) -> ServiceProbe {
    let probe = service::parse_probe(&raw);
    ServiceProbe {
        manager: probe.manager_type,
        description: probe.description(),
    }
}

/// The commands one listing of `manager` is read from. They are independent
/// of each other: run them at once.
#[frb(sync)]
pub fn service_listing_commands(manager: ServiceManagerType) -> Vec<ServiceCommand> {
    service::listing_commands(manager)
        .into_iter()
        .map(|(name, command)| ServiceCommand { name: name.to_owned(), command })
        .collect()
}

/// The listing those commands' outputs make, its times moved from the
/// machine's clock onto this device's: by the difference between
/// `now_millis` (this device's clock as the answers arrived) and the
/// listing's `sampled_at_millis`, which is then `None`. `sbm_parser` leaves
/// the shift to its caller, whose clock it is. `Err` is a listing that could
/// not be read at all, in the machine's words.
pub fn service_parse_listing(manager: ServiceManagerType, outputs: Vec<ServiceCommandOutput>, now_millis: i64) -> Result<ServiceListing, String> {
    let outputs: HashMap<String, CommandOutput> = outputs
        .into_iter()
        .map(|o| (o.name, CommandOutput { stdout: o.stdout, stderr: o.stderr, succeeded: o.succeeded }))
        .collect();
    let mut listing = service::parse_listing(manager, &outputs).map_err(|e| e.detail)?;
    if let Some(at) = listing.sampled_at_millis.take() {
        let skew = now_millis - at;
        for unit in &mut listing.units {
            unit.since_millis = unit.since_millis.map(|t| t + skew);
            unit.next_elapse_millis = unit.next_elapse_millis.map(|t| t + skew);
        }
    }
    Ok(listing)
}

/// The command for `action` on the unit, without `sudo`: whether it needs
/// root is [`service_needs_root`].
#[frb(sync)]
pub fn service_command(manager: ServiceManagerType, unit: ServiceUnit, action: ServiceAction) -> String {
    manager.command_for(&unit, action)
}

/// A systemd user unit is the one that must not: `sudo systemctl --user`
/// talks to root's user manager, not this account's.
#[frb(sync)]
pub fn service_needs_root(manager: ServiceManagerType, unit: ServiceUnit) -> bool {
    manager.needs_root(&unit)
}

/// The unit's last `lines` of log; `None` where the manager keeps none by
/// unit. Read by [`service_parse_recent_log`].
#[frb(sync)]
pub fn service_recent_log_command(manager: ServiceManagerType, unit: ServiceUnit, lines: u32) -> Option<String> {
    manager.recent_log_command(&unit, lines)
}

/// What [`service_recent_log_command`] printed, or `None` where the machine
/// has no log to ask for by unit.
#[frb(sync)]
pub fn service_parse_recent_log(manager: ServiceManagerType, stdout: String, stderr: String, succeeded: bool) -> Option<ServiceLog> {
    service::parse_recent_log(manager, &CommandOutput { stdout, stderr, succeeded })
}

/// The whole log, for a terminal; `None` with no such log.
#[frb(sync)]
pub fn service_log_command(manager: ServiceManagerType, unit: ServiceUnit) -> Option<String> {
    manager.log_command(&unit)
}

/// What prints the unit's definition, for a terminal.
#[frb(sync)]
pub fn service_definition_command(manager: ServiceManagerType, unit: ServiceUnit) -> String {
    manager.definition_command(&unit)
}

/// What the manager itself says about the unit, for a terminal.
#[frb(sync)]
pub fn service_unit_status_command(manager: ServiceManagerType, unit: ServiceUnit) -> String {
    manager.unit_status_command(&unit)
}

/// `command` as typed into a terminal: `sudo` in front where it needs root
/// and the account is not root, so the terminal asks for the password.
#[frb(sync)]
pub fn service_terminal_command(command: String, needs_root: bool, is_root: bool) -> String {
    service::terminal_command(&command, needs_root, is_root)
}

/// What may be done to a unit in `state` with startup registration
/// `enabled`: the rule every listing's `actions` is.
#[frb(sync)]
pub fn service_actions(state: ServiceState, enabled: Option<bool>) -> Vec<ServiceAction> {
    service::service_actions(state, enabled)
}

/// Whether a unit in `state` is listed first: the rule every listing's
/// `needs_attention` is.
#[frb(sync)]
pub fn service_needs_attention(state: ServiceState) -> bool {
    state.needs_attention()
}
