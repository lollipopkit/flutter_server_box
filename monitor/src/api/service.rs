//! `/api/v1/services` — the service units of the machine the agent runs on,
//! and the start, stop, restart, enable or disable of one.
//!
//! # Why this is not `/exec`
//!
//! Which manager a machine runs, whether it has a per-account scope, how each
//! manager's listing is assembled and parsed, which of the three words for a
//! state means what, and what may be done to a unit in a given state — all of
//! that is one model, and it lives in [`sbm_parser::service`]. The app reads
//! the same units over SSH through the same module, so the panel and the app
//! draw one machine the same way and the panel composes no command line and
//! parses nothing.
//!
//! # The unit is resolved against a listing, never taken from the client
//!
//! A request names a unit by [`ServiceUnit::key`] and nothing else — not its
//! scope, not its type, not whether it needs root. The agent lists the machine
//! and finds the key in that listing, so an action runs against a unit this
//! agent would itself have shown, and the mount of sudo it gets is
//! [`ServiceManagerType::needs_root`]'s answer rather than the caller's. A key
//! that is not in the current listing is refused as [`ServiceReason::NoSuchUnit`]
//! — which is a unit removed between the panel drawing the row and the click,
//! and is not a failure the caller can fix by trying again.
//!
//! # Privilege
//!
//! Reading needs only the panel login, the same as the crontab and the process
//! table: the listing commands are read-only and run as the agent's own user.
//! **Every action is `full_access`**, the same grant as the shell and `/exec` —
//! anyone who can open a shell can run `systemctl` in it, so a switch of its
//! own would withhold nothing. A `sudo -S` password travels in the body, never
//! in a command line, and a refusal comes back as a field (`sudo_rejected`)
//! rather than as a failed request, since the caller's next move is to ask for
//! a different one.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::privileged;
use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::monitoring::system_type;
use crate::utils::command::Limits;
use sbm_parser::SystemType;
use sbm_parser::output::CommandOutput;
use sbm_parser::service::{
    OpenRcOutputs, ProcdOutputs, ServiceAction, ServiceListing, ServiceListingNotice, ServiceLog,
    ServiceManagerProbe, ServiceManagerType, ServiceScope, ServiceUnit, SystemdOutputs,
    parse_openrc_listing, parse_probe, parse_procd_listing, parse_systemd_listing,
};

/// The details sweep describes every unit at once, so its output is the whole
/// machine's service configuration rather than one command's page — the same
/// reason `/process` sizes its own. The 1 MiB default is a few thousand units
/// short on a large machine, and going over would cost the reader the whole
/// page rather than one row.
const SWEEP_LIMITS: Limits = Limits {
    max_output_bytes: 4 * 1024 * 1024,
    ..Limits::DEFAULT
};

/// Which of a unit's own files a request wants. The listing is the default;
/// the other three are about one unit and need [`ServiceQuery::key`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum ServicePart {
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
    /// Whether this part needs `key` to be answered at all.
    fn needs_key(self) -> bool {
        self != Self::List
    }
}

/// How many lines of a unit's log the panel asks for. A page shows a screenful;
/// the whole journal is what the terminal is for.
const LOG_LINES: u32 = 50;

#[derive(Serialize)]
struct ServiceListResponse {
    /// Which of the four this answers. Echoed because the panel keeps one
    /// object per part and a response is read beside a request that may have
    /// been made minutes ago.
    part: ServicePart,
    /// Whether the machine runs a manager this endpoint could list. `false` is
    /// a state of the machine, not a failure of the caller, so it is a field
    /// rather than a status code and the panel draws one page either way.
    available: bool,
    /// Which of the known reasons it was, so the panel phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something this endpoint does not classify, and `reason` is it.
    reason_kind: Option<ServiceReason>,
    /// What the machine said, verbatim, with this endpoint's own scaffolding
    /// dropped out of it. Never translated and never classified away: it is the
    /// only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// Which manager answered, once one did.
    manager: Option<ServiceManagerView>,
    /// Whether this caller may change anything. The page asks so it can draw a
    /// read-only view instead of failing on a click; the answer is re-checked
    /// on the write itself, since a UI hint is not a boundary.
    editable: bool,
    /// Whether the machine has a second account scope (systemd's `--user`).
    /// Reported so the page can name the scope of a unit it draws without
    /// knowing which managers have one.
    supports_user_scope: bool,
    units: Vec<ServiceRow>,
    /// A part of the listing that is missing while the rest is readable.
    notice: Option<ServiceListingNotice>,
    /// What the machine said about that notice, verbatim.
    detail: Option<String>,
    /// The machine's own clock at the moment the listing was read, for the
    /// timestamps in it. See `sbm_parser::service`'s note on the clock shift:
    /// the consumer differences against the clock it has.
    sampled_at_millis: Option<i64>,
    /// The unit's log, for [`ServicePart::Logs`].
    log: Option<ServiceLog>,
    /// The unit's definition or the manager's own status, for
    /// [`ServicePart::Definition`] and [`ServicePart::Status`].
    text: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum ServiceReason {
    /// The machine runs a service manager this build cannot list — runit, s6,
    /// upstart, launchd or plain sysvinit. `reason` is the name it reported.
    UnsupportedManager,
    /// Windows, which has no service manager these commands reach.
    UnsupportedPlatform,
    /// The manager is there and its command failed, or printed something this
    /// build could not read.
    Unreadable,
    /// The unit named is not in the current listing. A unit removed between the
    /// page being drawn and the click, and nothing the caller can retry.
    NoSuchUnit,
    /// The manager keeps no log a unit can be read back by name — OpenRC hands
    /// a service's output to whatever it was configured to log to.
    NoLog,
}

#[derive(Serialize)]
struct ServiceManagerView {
    /// The manager this build talks to. `None` for one it does not, which is
    /// the `UnsupportedManager` case and has no listing to go with it.
    #[serde(rename = "type")]
    manager_type: Option<ServiceManagerType>,
    /// What the machine called it.
    detected_name: String,
    /// `systemd (Debian GNU/Linux)`, or the OS name alone.
    description: String,
}

/// One unit as the panel draws it.
#[derive(Serialize)]
struct ServiceRow {
    #[serde(flatten)]
    unit: ServiceUnit,
    /// The name the client sends back to ask about this unit or to act on it.
    ///
    /// Derived here rather than in the panel so that the listing and the two
    /// requests that address a unit cannot spell it differently — a second
    /// spelling would be a unit that is in the listing and not found by key.
    key: String,
    /// `unit_file_state` where the manager has one, `enabled`/`disabled` in the
    /// same words where it does not, from [`ServiceUnit::startup`].
    ///
    /// Sent because `enabled` cannot say `static` or `masked`, and a client
    /// that spelled this itself would be a second implementation of the rule
    /// that those are neither.
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

/// Reads the machine's units, or one unit's own files.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<ServiceQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    let part = query.part.unwrap_or_default();
    let key = query.key.as_deref();
    // A part that is about one unit and was not told which is a request that
    // cannot be answered, not one to guess a default for. Refused before
    // anything runs, so a malformed request costs nothing on the machine.
    if part.needs_key() && key.is_none_or(str::is_empty) {
        return Ok(HttpResponse::BadRequest().finish());
    }

    let (probe, unreadable) = probe().await;
    let Some(manager) = probe.manager_type else {
        return Ok(HttpResponse::Ok().json(&empty_response(
            part,
            editable,
            &probe,
            ServiceReason::UnsupportedManager,
            unreadable,
        )));
    };
    // Windows has no shell for these commands and no manager behind them.
    if system_type() == SystemType::Windows {
        return Ok(HttpResponse::Ok().json(&empty_response(
            part,
            editable,
            &probe,
            ServiceReason::UnsupportedPlatform,
            None,
        )));
    }

    let listing = read_listing(manager).await;
    let mut response = base_response(part, editable, &probe, manager, listing);

    if part == ServicePart::List {
        return Ok(HttpResponse::Ok().json(&response));
    }

    // Resolved against the listing rather than rebuilt from the request: the
    // scope, the type and whether the command needs root are all the listing's
    // answers, and a unit that is not in it is not one to run a command about.
    let key = key.unwrap_or_default();
    let Some(unit) = response
        .units
        .iter()
        .map(|row| &row.unit)
        .find(|unit| unit.key() == key)
        .cloned()
    else {
        let mut missing = empty_response(
            part,
            editable,
            &probe,
            ServiceReason::NoSuchUnit,
            Some(key.to_string()),
        );
        missing.manager = response.manager;
        return Ok(HttpResponse::Ok().json(&missing));
    };

    match part {
        ServicePart::Logs => fill_log(&mut response, manager, &unit).await,
        ServicePart::Definition | ServicePart::Status => {
            let text = if part == ServicePart::Definition {
                manager.definition_command(&unit)
            } else {
                manager.unit_status_command(&unit)
            };
            let label = if part == ServicePart::Definition {
                "service definition"
            } else {
                "service status"
            };
            response.text = privileged::as_self(&text, label, Limits::DEFAULT)
                .await
                .map(|output| {
                    // Both streams, in the order a terminal would have shown
                    // them: `rc-service status` prints "stopped" on stdout with
                    // a non-zero exit, and half of `systemctl status` is on
                    // stderr.
                    privileged::read(Some(&output), "").combined().trim().to_string()
                });
        }
        ServicePart::List => {}
    }

    Ok(HttpResponse::Ok().json(&response))
}

/// Runs one action on one unit.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<ServiceActRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    // Re-checked at the moment of use rather than trusted from the `editable`
    // the client was told earlier: that answer is a UI hint, and the UI is not
    // a boundary.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Service, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let subject = format!("{} {}", request.action.as_str(), request.key);
    let deny = |detail: &'static str| {
        Event::new(Kind::Service, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .subject(subject.clone())
            .detail(detail)
    };

    let (probe, _) = probe().await;
    let Some(manager) = probe.manager_type else {
        deny("unsupported manager").record(&app_state.db).await;
        return Ok(HttpResponse::BadRequest().finish());
    };
    if system_type() == SystemType::Windows {
        deny("unsupported platform").record(&app_state.db).await;
        return Ok(HttpResponse::BadRequest().finish());
    }

    // The listing this action is resolved against is run here, so a unit that
    // the machine no longer has cannot be acted on through a stale key.
    let unit = match read_listing(manager)
        .await
        .ok()
        .and_then(|listing| listing.units.into_iter().find(|unit| unit.key() == request.key))
    {
        Some(unit) => unit,
        None => {
            deny("no such unit").record(&app_state.db).await;
            return Ok(HttpResponse::NotFound().finish());
        }
    };

    let command_text = manager.command_for(&unit, request.action);
    let needs_root = manager.needs_root(&unit);
    let output = if needs_root {
        privileged::as_root(
            &command_text,
            "service act",
            Limits::DEFAULT,
            request.password.as_deref(),
        )
        .await
    } else {
        privileged::as_self(&command_text, "service act", Limits::DEFAULT).await
    };
    let sudo_rejected = privileged::sudo_rejected(output.as_ref());
    let succeeded = output
        .as_ref()
        .is_some_and(|output| output.status.success());

    // One row per action, written after the outcome is known. A listing is not
    // recorded at all, so a row here is always a change.
    let (action, result, detail) = match (succeeded, sudo_rejected) {
        (true, _) => (Action::Write, Outcome::Ok, None),
        (false, true) => (Action::Write, Outcome::Error, Some("sudo password rejected")),
        (false, false) => (Action::Write, Outcome::Error, Some("command failed")),
    };
    let mut event = Event::new(Kind::Service, action, result)
        .remote_ip(remote_ip)
        .subject(subject);
    if let Some(detail) = detail {
        event = event.detail(detail);
    }
    event.record(&app_state.db).await;

    let (stdout, stderr, exit_code) = match &output {
        Some(output) => (
            String::from_utf8_lossy(&output.stdout).into_owned(),
            String::from_utf8_lossy(&output.stderr).into_owned(),
            output.status.code(),
        ),
        None => (String::new(), String::new(), None),
    };
    Ok(HttpResponse::Ok().json(&ServiceActResponse {
        succeeded,
        sudo_rejected,
        exit_code,
        stdout,
        stderr,
    }))
}

/// One action on one unit, named by the key its listing gave it.
#[derive(Debug, Deserialize)]
pub struct ServiceActRequest {
    /// [`ServiceUnit::key`] — the scope and the unit's full name.
    key: String,
    action: ServiceAction,
    /// The `sudo` password, when the caller has one. Its own field so it never
    /// reaches a command line: see `api::privileged`.
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct ServiceActResponse {
    /// Whether the manager's command exited zero. What the machine said about
    /// it is in `stderr`, and it is the only thing that distinguishes one
    /// failure from another.
    succeeded: bool,
    /// `sudo` refused the password that was sent, or was not given one and
    /// needed it. Told apart from any other failure because the caller's next
    /// move is to ask for a password and send the same request again.
    sudo_rejected: bool,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
}

#[derive(Debug, Deserialize)]
pub struct ServiceQuery {
    /// Which part of the machine's service state to read. Defaults to the
    /// units themselves.
    part: Option<ServicePart>,
    /// [`ServiceUnit::key`] for the parts that are about one unit.
    key: Option<String>,
}

// ---------------------------------------------------------------------------
// Reading the machine
// ---------------------------------------------------------------------------

/// Asks the machine which manager it runs.
///
/// `None` beside the probe is a detector that could not be run at all, which is
/// not the same answer as a machine whose shell said nothing about itself.
async fn probe() -> (ServiceManagerProbe, Option<String>) {
    let output = privileged::as_self(
        sbm_parser::service::DETECT_SCRIPT,
        "service probe",
        Limits::DEFAULT,
    )
    .await;
    match output {
        Some(output) => (parse_probe(&String::from_utf8_lossy(&output.stdout)), None),
        None => (
            parse_probe(""),
            Some("the detector could not be run".to_string()),
        ),
    }
}

/// Runs the manager's own commands and reads the units out of them.
///
/// The commands are run concurrently: on systemd there are four, and they are
/// independent of each other — running them one after another would make the
/// panel's first paint wait for the sum of them rather than the longest.
///
/// `Err` is a listing that could not be read at all, carrying what the machine
/// said. A partial listing is an `Ok` with a notice rather than an error: a
/// machine with no user session has no user units, and every other unit is
/// still there to show.
async fn read_listing(manager: ServiceManagerType) -> Result<ServiceListing, String> {
    match manager {
        ServiceManagerType::Systemd => {
            let (system_list, system_details, user_list, user_details) = tokio::join!(
                run(manager.list_command(ServiceScope::System)),
                run(manager.details_command(ServiceScope::System)),
                run(manager.list_command(ServiceScope::User)),
                run(manager.details_command(ServiceScope::User)),
            );
            parse_systemd_listing(&SystemdOutputs {
                system_list: &system_list,
                system_details: &system_details,
                user_list: &user_list,
                user_details: &user_details,
            })
            .map_err(|error| error.detail)
        }
        ServiceManagerType::Procd => {
            let (catalog, status) = tokio::join!(
                run(Some(sbm_parser::service::PROCD_CATALOG_SCRIPT.to_string())),
                run(Some(sbm_parser::service::PROCD_STATUS_COMMAND.to_string())),
            );
            parse_procd_listing(&ProcdOutputs {
                catalog: &catalog,
                status: &status,
            })
            .map_err(|error| error.detail)
        }
        ServiceManagerType::Openrc => {
            let (catalog, status, startup) = tokio::join!(
                run(Some(sbm_parser::service::OPENRC_CATALOG_SCRIPT.to_string())),
                run(Some(sbm_parser::service::OPENRC_STATUS_COMMAND.to_string())),
                run(Some(sbm_parser::service::OPENRC_STARTUP_COMMAND.to_string())),
            );
            parse_openrc_listing(&OpenRcOutputs {
                catalog: &catalog,
                status: &status,
                startup: &startup,
            })
            .map_err(|error| error.detail)
        }
    }
}

/// Runs one of the listing's commands as this account. `None` is a command
/// this build does not have for that manager, which is a mismatch between the
/// caller and the manager rather than anything the machine said.
async fn run(command: Option<String>) -> CommandOutput {
    let Some(command) = command else {
        return CommandOutput::failed("no such command for this manager");
    };
    let output = privileged::as_self(&command, "service read", SWEEP_LIMITS).await;
    privileged::read(output.as_ref(), "the command could not be run")
}

/// A response with no units and a reason, which is what every "this machine
/// cannot be listed" answer is.
fn empty_response(
    part: ServicePart,
    editable: bool,
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
        editable,
        supports_user_scope: probe
            .manager_type
            .is_some_and(ServiceManagerType::supports_user_scope),
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
    editable: bool,
    probe: &ServiceManagerProbe,
    manager: ServiceManagerType,
    listing: Result<ServiceListing, String>,
) -> ServiceListResponse {
    // A listing that could not be read is still `available`: the machine does
    // have a manager this build talks to, and it is the manager's own command
    // that did not answer. `UnsupportedManager` would be a claim about the
    // machine rather than about the answer.
    let (listing, reason) = match listing {
        Ok(listing) => (listing, None),
        Err(detail) => (
            ServiceListing {
                units: Vec::new(),
                notice: None,
                detail: None,
            },
            Some(detail),
        ),
    };
    ServiceListResponse {
        part,
        available: reason.is_none(),
        reason_kind: reason.as_ref().map(|_| ServiceReason::Unreadable),
        reason,
        manager: Some(manager_view(probe)),
        editable,
        supports_user_scope: manager.supports_user_scope(),
        units: listing.units.iter().map(ServiceRow::of).collect(),
        notice: listing.notice,
        detail: listing.detail,
        sampled_at_millis: None,
        log: None,
        text: None,
    }
}

/// Fills in one unit's log, or says why there is none to fill in.
async fn fill_log(
    response: &mut ServiceListResponse,
    manager: ServiceManagerType,
    unit: &ServiceUnit,
) {
    let Some(command) = manager.recent_log_command(unit, LOG_LINES) else {
        // Not a failure: OpenRC hands a service's output to whatever it was
        // configured to log to, and there is no one place to read it back from.
        response.available = false;
        response.reason_kind = Some(ServiceReason::NoLog);
        return;
    };
    // Read as this account and never through sudo: this runs when a unit is
    // opened rather than because the user asked for anything, and a password
    // prompt belongs to an action the user took.
    let Some(raw) = privileged::as_self(&command, "service log", Limits::DEFAULT).await else {
        response.available = false;
        response.reason_kind = Some(ServiceReason::Unreadable);
        response.reason = Some("the command could not be run".to_string());
        return;
    };
    let output = privileged::read(Some(&raw), "the command could not be run");

    match manager {
        ServiceManagerType::Systemd => {
            response.log = Some(sbm_parser::service::parse_journal(
                &output.stdout,
                &output.stderr,
            ));
        }
        ServiceManagerType::Procd => {
            // `logread` absent is a machine with no log to read, which is the
            // same answer as OpenRC's and not an empty log: a unit that has
            // written nothing is a different thing from one whose log the
            // machine cannot be asked for.
            if !output.succeeded && output.stdout.trim().is_empty() {
                response.available = false;
                response.reason_kind = Some(ServiceReason::NoLog);
                response.reason = output.detail();
            } else {
                response.log = Some(ServiceLog {
                    lines: sbm_parser::service::parse_logread(&output.stdout),
                    unreadable: false,
                });
            }
        }
        // Answered by the `NoLog` above; OpenRC keeps no log by service name.
        ServiceManagerType::Openrc => {}
    }
}
