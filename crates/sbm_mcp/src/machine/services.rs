//! The service units of a machine, and the start, stop, restart, enable or
//! disable of one.
//!
//! Which manager a machine runs, how each manager's listing is assembled and
//! parsed and what may be done to a unit in a given state is one model, in
//! [`sbm_parser::service`]; this is the order it is asked in.
//!
//! # The unit is resolved against a listing, never taken from the caller
//!
//! A request names a unit by [`ServiceUnit::key`] and nothing else — not its
//! scope, not its type, not whether it needs root. The machine is listed and
//! the key found in that listing, so an action runs against a unit that would
//! itself have been shown, and whether it gets sudo is
//! [`ServiceManagerType::needs_root`]'s answer rather than the caller's. A key
//! not in the current listing is [`ServiceReason::NoSuchUnit`]: a unit removed
//! between the row being drawn and the click.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use super::{Machine, Ran, Run, Stage, change, command_output};
use sbm_parser::SystemType;
use sbm_parser::output::CommandOutput;
use sbm_parser::service::{
    DETECT_SCRIPT, ServiceAction, ServiceListing, ServiceListingNotice, ServiceLog, ServiceManagerProbe,
    ServiceManagerType, ServiceUnit, parse_probe,
};

/// The details sweep describes every unit at once, so its output is the whole
/// machine's service configuration rather than one command's page. A 1 MiB cap
/// is a few thousand units short on a large machine, and going over would cost
/// the reader the whole page rather than one row.
const SWEEP_BYTES: usize = 4 * 1024 * 1024;

/// How many lines of a unit's log are read. A page shows a screenful; the
/// whole journal is what a terminal is for.
const LOG_LINES: u32 = 50;

/// Which of a unit's own files a request wants. The listing is the default;
/// the other three are about one unit and need its key.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ServicePart {
    /// The units themselves.
    #[default]
    List,
    /// The last lines of the unit's log.
    Logs,
    /// The unit's definition, as the manager prints it.
    Definition,
    /// What the manager itself says about the unit. For OpenRC this is the only
    /// thing a unit has to read: it keeps no log by name.
    Status,
}

impl ServicePart {
    /// Whether this part needs a key to be answered at all.
    pub fn needs_key(self) -> bool {
        self != Self::List
    }
}

#[derive(Debug, Serialize)]
pub struct ServiceListResponse {
    /// Which of the four this answers. Echoed because a client keeps one
    /// object per part and a response is read beside a request that may have
    /// been made minutes ago.
    part: ServicePart,
    /// Whether the machine runs a manager that could be listed. `false` is a
    /// state of the machine, not a failure of the caller.
    available: bool,
    /// Which of the known reasons it was, so a client phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something not classified here, and `reason` is it.
    reason_kind: Option<ServiceReason>,
    /// What the machine said, verbatim. Never translated and never classified
    /// away: it is the only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// Which manager answered, once one did.
    manager: Option<ServiceManagerView>,
    /// Whether the machine has a second account scope (systemd's `--user`).
    supports_user_scope: bool,
    units: Vec<ServiceRow>,
    /// A part of the listing that is missing while the rest is readable.
    notice: Option<ServiceListingNotice>,
    /// What the machine said about that notice, verbatim.
    detail: Option<String>,
    /// The machine's own clock at the moment the listing was read, for the
    /// timestamps in it. See `sbm_parser::service`'s note on the clock shift.
    sampled_at_millis: Option<i64>,
    /// The unit's log, for [`ServicePart::Logs`].
    log: Option<ServiceLog>,
    /// The unit's definition or the manager's own status, for
    /// [`ServicePart::Definition`] and [`ServicePart::Status`].
    text: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ServiceReason {
    /// A service manager that cannot be listed — runit, s6, upstart, launchd
    /// or plain sysvinit. `reason` is the name it reported.
    UnsupportedManager,
    /// Windows, which has no service manager these commands reach.
    UnsupportedPlatform,
    /// The manager is there and its command failed, or printed something that
    /// could not be read.
    Unreadable,
    /// The unit named is not in the current listing.
    NoSuchUnit,
    /// The manager keeps no log a unit can be read back by name — OpenRC hands
    /// a service's output to whatever it was configured to log to.
    NoLog,
}

#[derive(Debug, Serialize)]
struct ServiceManagerView {
    /// The manager talked to. `None` for one that is not, which is the
    /// `UnsupportedManager` case and has no listing to go with it.
    #[serde(rename = "type")]
    manager_type: Option<ServiceManagerType>,
    /// What the machine called it.
    detected_name: String,
    /// `systemd (Debian GNU/Linux)`, or the OS name alone.
    description: String,
}

/// One unit as a client draws it.
#[derive(Debug, Serialize)]
struct ServiceRow {
    #[serde(flatten)]
    unit: ServiceUnit,
    /// The name a client sends back to ask about this unit or to act on it,
    /// derived here so the listing and the requests that address a unit
    /// cannot spell it differently.
    key: String,
    /// `unit_file_state` where the manager has one, `enabled`/`disabled` in the
    /// same words where it does not, from [`ServiceUnit::startup`].
    startup: Option<String>,
}

impl ServiceRow {
    fn of(unit: &ServiceUnit) -> Self {
        Self {
            key: unit.key(),
            startup: unit.startup().map(str::to_string),
            unit: unit.clone(),
        }
    }
}

impl ServiceListResponse {
    pub fn reason_kind(&self) -> Option<ServiceReason> {
        self.reason_kind
    }

    pub fn available(&self) -> bool {
        self.available
    }
}

/// The units, or one unit's own files.
pub async fn listing(m: &dyn Machine, part: ServicePart, key: Option<&str>) -> ServiceListResponse {
    if part.needs_key() && key.is_none_or(str::is_empty) {
        return empty_response(part, &parse_probe(""), ServiceReason::NoSuchUnit, None);
    }
    // Windows has no shell for these commands and no manager behind them —
    // asked before the detector, which would only fail for want of `sh` and
    // be reported as an unknown manager.
    if m.system() == SystemType::Windows {
        return empty_response(part, &parse_probe(""), ServiceReason::UnsupportedPlatform, None);
    }
    let (probe, unreadable) = probe(m).await;
    let Some(manager) = probe.manager_type else {
        return empty_response(part, &probe, ServiceReason::UnsupportedManager, unreadable);
    };

    let read = read_listing(m, manager).await;
    let mut response = base_response(part, &probe, manager, read);
    // A listing that could not be read has no unit to look for.
    if part == ServicePart::List || !response.available {
        return response;
    }

    // Resolved against the listing rather than rebuilt from the request: the
    // scope, the type and whether the command needs root are all the listing's
    // answers.
    let key = key.unwrap_or_default();
    let Some(unit) = response.units.iter().map(|row| &row.unit).find(|unit| unit.key() == key).cloned() else {
        let mut missing = empty_response(part, &probe, ServiceReason::NoSuchUnit, Some(key.to_string()));
        missing.manager = response.manager;
        return missing;
    };

    match part {
        ServicePart::Logs => fill_log(m, &mut response, manager, &unit).await,
        ServicePart::Definition | ServicePart::Status => {
            let text = if part == ServicePart::Definition {
                manager.definition_command(&unit)
            } else {
                manager.unit_status_command(&unit)
            };
            // Both streams, in the order a terminal would have shown them:
            // `rc-service status` prints "stopped" on stdout with a non-zero
            // exit, and half of `systemctl status` is on stderr. A command that
            // did not finish is no text.
            let raw = m.run(Run::Sh(&text), 0).await;
            if let Some(why) = unfinished(&raw) {
                response.available = false;
                response.reason_kind = Some(ServiceReason::Unreadable);
                response.reason = Some(why);
                return response;
            }
            response.text = Some(command_output(raw).combined().trim().to_string());
        }
        ServicePart::List => {}
    }
    response
}

/// One action on one unit, named by the key its listing gave it.
#[derive(Debug, Deserialize)]
pub struct ServiceActRequest {
    /// [`ServiceUnit::key`] — the scope and the unit's full name.
    pub key: String,
    pub action: ServiceAction,
    /// The `sudo` password, when the caller has one. Its own field so it never
    /// reaches a command line.
    #[serde(default)]
    pub password: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ServiceActResponse {
    /// Whether the manager's command exited zero. What the machine said about
    /// it is in `stderr`.
    pub succeeded: bool,
    /// `sudo` refused the password that was sent, or was not given one and
    /// needed it: the caller's next move is to ask for a password and send the
    /// same request again.
    pub sudo_rejected: bool,
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
}

/// Why a service action did not run.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ServiceRefused {
    /// Windows, or no manager that is talked to.
    Unsupported,
    /// A key the current listing does not have.
    NoSuchUnit,
    /// The listing the key is resolved against could not be read.
    Unreadable,
}

/// Runs one action on one unit, recording it.
pub async fn perform(m: &dyn Machine, request: ServiceActRequest) -> Result<ServiceActResponse, ServiceRefused> {
    let what = format!("service {} {}", request.action.as_str(), request.key);
    if m.system() == SystemType::Windows {
        change(m, Stage::Refused, &what, Some("unsupported platform")).await;
        return Err(ServiceRefused::Unsupported);
    }
    let (probe, _) = probe(m).await;
    let Some(manager) = probe.manager_type else {
        change(m, Stage::Refused, &what, Some("unsupported manager")).await;
        return Err(ServiceRefused::Unsupported);
    };

    // Resolved against a listing read now, so a unit the machine no longer has
    // cannot be acted on through a stale key.
    let listing = match read_listing(m, manager).await {
        Ok(listing) => listing,
        Err(_) => {
            change(m, Stage::Refused, &what, Some("listing unreadable")).await;
            return Err(ServiceRefused::Unreadable);
        }
    };
    let Some(unit) = listing.units.into_iter().find(|unit| unit.key() == request.key) else {
        change(m, Stage::Refused, &what, Some("no such unit")).await;
        return Err(ServiceRefused::NoSuchUnit);
    };

    change(m, Stage::Started, &what, None).await;
    let text = manager.command_for(&unit, request.action);
    let out = if manager.needs_root(&unit) {
        m.run(Run::Root { text: &text, password: request.password.as_deref() }, 0).await
    } else {
        m.run(Run::Sh(&text), 0).await
    };
    let sudo_rejected = out.as_ref().is_ok_and(|out| sbm_parser::script::sudo_password_rejected(&out.stderr));
    let succeeded = out.as_ref().is_ok_and(|out| out.exit_code == Some(0) && !out.timed_out);
    if !succeeded {
        let why = if sudo_rejected { "sudo password rejected" } else { "command failed" };
        change(m, Stage::Failed, &what, Some(why)).await;
    }
    let (stdout, stderr, exit_code) = match out {
        Ok(out) => (out.stdout, out.stderr, out.exit_code),
        Err(e) => (String::new(), e, None),
    };
    Ok(ServiceActResponse { succeeded, sudo_rejected, exit_code, stdout, stderr })
}

/// Why [raw] is no answer to read: a command that could not be run, was
/// stopped, or was cut short.
fn unfinished(raw: &Result<Ran, String>) -> Option<String> {
    match raw {
        Err(_) => Some("the command could not be run".to_string()),
        Ok(out) if out.timed_out => Some("the command did not finish in time".to_string()),
        Ok(out) if out.truncated => Some("the command printed more than is read".to_string()),
        Ok(_) => None,
    }
}

/// Asks the machine which manager it runs. `None` beside the probe is a
/// detector that could not be run at all, which is not the same answer as a
/// machine whose shell said nothing about itself.
async fn probe(m: &dyn Machine) -> (ServiceManagerProbe, Option<String>) {
    match m.run(Run::Sh(DETECT_SCRIPT), 0).await {
        Ok(out) if !out.timed_out => (parse_probe(&out.stdout), None),
        _ => (parse_probe(""), Some("the detector could not be run".to_string())),
    }
}

/// Runs the manager's own commands, concurrently — on systemd there are four,
/// independent of each other — and reads the units out of them.
///
/// `Err` is a listing that could not be read at all, carrying what the machine
/// said. A partial listing is an `Ok` with a notice: a machine with no user
/// session has no user units, and every other unit is still there to show.
async fn read_listing(m: &dyn Machine, manager: ServiceManagerType) -> Result<ServiceListing, String> {
    let commands = sbm_parser::service::listing_commands(manager);
    let outputs = futures::future::join_all(commands.into_iter().map(|(name, command)| async move {
        let output = match command {
            Some(command) => command_output(m.run(Run::Sh(&command), SWEEP_BYTES).await),
            None => CommandOutput::failed("no such command for this manager"),
        };
        (name.to_string(), output)
    }))
    .await;
    let outputs: HashMap<String, CommandOutput> = outputs.into_iter().collect();
    sbm_parser::service::parse_listing(manager, &outputs).map_err(|error| error.detail)
}

/// A response with no units and a reason, which is what every "this machine
/// cannot be listed" answer is.
fn empty_response(
    part: ServicePart,
    probe: &ServiceManagerProbe,
    reason_kind: ServiceReason,
    reason: Option<String>,
) -> ServiceListResponse {
    ServiceListResponse {
        part,
        available: false,
        reason_kind: Some(reason_kind),
        reason,
        manager: Some(manager_view(probe)),
        supports_user_scope: probe.manager_type.is_some_and(ServiceManagerType::supports_user_scope),
        units: Vec::new(),
        notice: None,
        detail: None,
        sampled_at_millis: None,
        log: None,
        text: None,
    }
}

fn manager_view(probe: &ServiceManagerProbe) -> ServiceManagerView {
    ServiceManagerView {
        manager_type: probe.manager_type,
        detected_name: probe.detected_name.clone(),
        description: probe.description(),
    }
}

/// The response a listing produces, before any part-specific half is filled in.
fn base_response(
    part: ServicePart,
    probe: &ServiceManagerProbe,
    manager: ServiceManagerType,
    listing: Result<ServiceListing, String>,
) -> ServiceListResponse {
    // A listing that could not be read is still `available`: the machine does
    // have a manager that is talked to, and it is the manager's own command
    // that did not answer.
    let (listing, reason) = match listing {
        Ok(listing) => (listing, None),
        Err(detail) => (
            ServiceListing { units: Vec::new(), notice: None, detail: None, sampled_at_millis: None },
            Some(detail),
        ),
    };
    ServiceListResponse {
        part,
        available: reason.is_none(),
        reason_kind: reason.as_ref().map(|_| ServiceReason::Unreadable),
        reason,
        manager: Some(manager_view(probe)),
        supports_user_scope: manager.supports_user_scope(),
        units: listing.units.iter().map(ServiceRow::of).collect(),
        notice: listing.notice,
        detail: listing.detail,
        sampled_at_millis: listing.sampled_at_millis,
        log: None,
        text: None,
    }
}

/// Fills in one unit's log, or says why there is none to fill in.
async fn fill_log(m: &dyn Machine, response: &mut ServiceListResponse, manager: ServiceManagerType, unit: &ServiceUnit) {
    let Some(command) = manager.recent_log_command(unit, LOG_LINES) else {
        response.available = false;
        response.reason_kind = Some(ServiceReason::NoLog);
        return;
    };
    // Read as this account and never through sudo: this runs when a unit is
    // opened rather than because anyone asked for a change, and a password
    // prompt belongs to an action.
    let raw: Result<Ran, String> = m.run(Run::Sh(&command), 0).await;
    if let Some(why) = unfinished(&raw) {
        response.available = false;
        response.reason_kind = Some(ServiceReason::Unreadable);
        response.reason = Some(why);
        return;
    }
    let output = command_output(raw);
    match sbm_parser::service::parse_recent_log(manager, &output) {
        Some(log) => response.log = Some(log),
        // `logread` absent is a machine with no log to read, which is the
        // same answer as OpenRC's and not an empty log.
        None => {
            response.available = false;
            response.reason_kind = Some(ServiceReason::NoLog);
            response.reason = output.detail();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::super::fake::{Fake, failed, ok};
    use super::*;

    #[tokio::test]
    async fn windows_and_an_unknown_manager_are_answered_without_a_listing() {
        let windows = Fake::new(SystemType::Windows, vec![]);
        let answer = listing(&windows, ServicePart::List, None).await;
        assert_eq!(answer.reason_kind, Some(ServiceReason::UnsupportedPlatform));
        assert!(windows.asked.lock().unwrap().is_empty());

        let runit = Fake::new(SystemType::Linux, vec![("", failed("", 1))]);
        let answer = listing(&runit, ServicePart::List, None).await;
        assert_eq!(answer.reason_kind, Some(ServiceReason::UnsupportedManager));
    }

    #[tokio::test]
    async fn a_part_about_one_unit_needs_its_key() {
        let m = Fake::new(SystemType::Linux, vec![]);
        let answer = listing(&m, ServicePart::Logs, Some("")).await;
        assert_eq!(answer.reason_kind, Some(ServiceReason::NoSuchUnit));
        assert!(m.asked.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn an_action_on_a_windows_machine_is_refused_and_recorded() {
        let m = Fake::new(SystemType::Windows, vec![]);
        let request = ServiceActRequest { key: "system:a.service".into(), action: ServiceAction::Restart, password: None };
        assert_eq!(perform(&m, request).await.unwrap_err(), ServiceRefused::Unsupported);
        let audits = m.audits.lock().unwrap();
        assert_eq!(audits.len(), 1);
        assert!(audits[0].contains("Refused") && audits[0].contains("unsupported platform"), "{audits:?}");
    }

    #[tokio::test]
    async fn a_listing_that_cannot_be_read_is_not_a_missing_unit() {
        let m = Fake::new(SystemType::Linux, vec![("pid1=", ok("openrc\t"))]);
        let answer = listing(&m, ServicePart::Logs, Some("system:sshd")).await;
        assert_eq!(answer.reason_kind, Some(ServiceReason::Unreadable));
        let request = ServiceActRequest { key: "system:sshd".into(), action: ServiceAction::Restart, password: None };
        assert_eq!(perform(&m, request).await.unwrap_err(), ServiceRefused::Unreadable);
        assert!(m.asked.lock().unwrap().iter().all(|c| !c.contains("restart")));
    }
}
