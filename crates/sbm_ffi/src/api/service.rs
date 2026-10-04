//! Services FFI (sbm_parser::service)
//!
//! What the monitor agent's panel runs and reads for a machine's units, for
//! the app's services page: which manager it is, the commands a listing is
//! read from and the listing they make, a unit's actions, log and
//! definition. The app runs the commands over its own connection; units
//! cross as `sbm_parser::service::ServiceUnit` JSON, and go back the same
//! way to name the unit a command is for.

use std::collections::HashMap;

use sbm_parser::output::CommandOutput;
use sbm_parser::service::{self, ServiceAction, ServiceManagerType, ServiceUnit};

fn manager(name: &str) -> Result<ServiceManagerType, String> {
    serde_json::from_value(serde_json::Value::String(name.to_owned())).map_err(|_| format!("unknown manager: {name}"))
}

fn unit(json: &str) -> Result<ServiceUnit, String> {
    serde_json::from_str(json).map_err(|e| e.to_string())
}

/// Which manager the machine runs, from [`service_detect_script`]'s output.
pub struct ServiceProbe {
    /// `systemd`, `procd` or `openrc`; `None` for one this build cannot list.
    pub manager: Option<String>,
    /// What the machine called it, with its OS: `systemd (Debian GNU/Linux)`.
    pub description: String,
}

/// One command a listing is read from, by the name its output goes back
/// under ([`service_parse_listing_json`]). `None`: none for this manager.
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

/// POSIX `sh`, for `ServerExec.run(script, entry: 'sh')`.
#[flutter_rust_bridge::frb(sync)]
pub fn service_detect_script() -> String {
    service::DETECT_SCRIPT.to_owned()
}

#[flutter_rust_bridge::frb(sync)]
pub fn service_parse_probe(raw: String) -> ServiceProbe {
    let probe = service::parse_probe(&raw);
    ServiceProbe {
        manager: probe.manager_type.and_then(|m| serde_json::to_value(m).ok()).and_then(|v| v.as_str().map(str::to_owned)),
        description: probe.description(),
    }
}

/// The commands one listing of `manager` is read from. They are independent
/// of each other: run them at once.
#[flutter_rust_bridge::frb(sync)]
pub fn service_listing_commands(manager_name: String) -> Result<Vec<ServiceCommand>, String> {
    Ok(service::listing_commands(manager(&manager_name)?)
        .into_iter()
        .map(|(name, command)| ServiceCommand { name: name.to_owned(), command })
        .collect())
}

/// The listing those commands' outputs make → `ServiceListing` JSON. `Err`
/// is a listing that could not be read at all, in the machine's words.
pub fn service_parse_listing_json(manager_name: String, outputs: Vec<ServiceCommandOutput>) -> Result<String, String> {
    let outputs: HashMap<String, CommandOutput> = outputs
        .into_iter()
        .map(|o| (o.name, CommandOutput { stdout: o.stdout, stderr: o.stderr, succeeded: o.succeeded }))
        .collect();
    let listing = service::parse_listing(manager(&manager_name)?, &outputs).map_err(|e| e.detail)?;
    serde_json::to_string(&listing).map_err(|e| e.to_string())
}

/// The command for `action` (`start`, `stop`, `restart`, `enable`,
/// `disable`) on the unit, without `sudo`: whether it needs root is
/// [`service_needs_root`].
#[flutter_rust_bridge::frb(sync)]
pub fn service_command(manager_name: String, unit_json: String, action: String) -> Result<String, String> {
    let action: ServiceAction =
        serde_json::from_value(serde_json::Value::String(action.clone())).map_err(|_| format!("unknown action: {action}"))?;
    Ok(manager(&manager_name)?.command_for(&unit(&unit_json)?, action))
}

/// A systemd user unit is the one that must not: `sudo systemctl --user`
/// talks to root's user manager, not this account's.
#[flutter_rust_bridge::frb(sync)]
pub fn service_needs_root(manager_name: String, unit_json: String) -> Result<bool, String> {
    Ok(manager(&manager_name)?.needs_root(&unit(&unit_json)?))
}

/// The unit's last `lines` of log; `None` where the manager keeps none by
/// unit. Read by [`service_parse_recent_log_json`].
#[flutter_rust_bridge::frb(sync)]
pub fn service_recent_log_command(manager_name: String, unit_json: String, lines: u32) -> Result<Option<String>, String> {
    Ok(manager(&manager_name)?.recent_log_command(&unit(&unit_json)?, lines))
}

/// What [`service_recent_log_command`] printed → `ServiceLog` JSON, or
/// `None` where the machine has no log to ask for by unit.
#[flutter_rust_bridge::frb(sync)]
pub fn service_parse_recent_log_json(manager_name: String, stdout: String, stderr: String, succeeded: bool) -> Result<Option<String>, String> {
    let output = CommandOutput { stdout, stderr, succeeded };
    service::parse_recent_log(manager(&manager_name)?, &output)
        .map(|log| serde_json::to_string(&log).map_err(|e| e.to_string()))
        .transpose()
}

/// The whole log, for a terminal; `None` with no such log.
#[flutter_rust_bridge::frb(sync)]
pub fn service_log_command(manager_name: String, unit_json: String) -> Result<Option<String>, String> {
    Ok(manager(&manager_name)?.log_command(&unit(&unit_json)?))
}

/// What prints the unit's definition, for a terminal.
#[flutter_rust_bridge::frb(sync)]
pub fn service_definition_command(manager_name: String, unit_json: String) -> Result<String, String> {
    Ok(manager(&manager_name)?.definition_command(&unit(&unit_json)?))
}

/// What the manager itself says about the unit, for a terminal.
#[flutter_rust_bridge::frb(sync)]
pub fn service_unit_status_command(manager_name: String, unit_json: String) -> Result<String, String> {
    Ok(manager(&manager_name)?.unit_status_command(&unit(&unit_json)?))
}

/// `command` as typed into a terminal: `sudo` in front where it needs root
/// and the account is not root, so the terminal asks for the password.
#[flutter_rust_bridge::frb(sync)]
pub fn service_terminal_command(command: String, needs_root: bool, is_root: bool) -> String {
    service::terminal_command(&command, needs_root, is_root)
}

/// What may be done to a unit in `state` (`running`, `stopped`, ...) with
/// startup registration `enabled`: the rule every listing's `actions` is.
#[flutter_rust_bridge::frb(sync)]
pub fn service_actions(state: String, enabled: Option<bool>) -> Result<Vec<String>, String> {
    let state: sbm_parser::service::ServiceState =
        serde_json::from_value(serde_json::Value::String(state.clone())).map_err(|_| format!("unknown state: {state}"))?;
    Ok(service::service_actions(state, enabled).into_iter().map(|a| a.as_str().to_owned()).collect())
}
