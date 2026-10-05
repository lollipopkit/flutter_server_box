//! `/api/v1/firewall` — the machine's firewall, ufw or firewalld, read and
//! changed through `sbm_parser::firewall`, the module the app's firewall page
//! uses over FFI.
//!
//! # A change is planned before it runs
//!
//! `POST /firewall/plan` answers what a change would run and what it would do
//! to each way into this machine ([`sbm_parser::firewall::change::Plan`]): the
//! panel's connection to this agent and the machine's SSH port. The panel
//! shows that and asks; `POST /firewall/act` then reads the firewall again,
//! makes the same plan from what it finds, and runs it — the keep-open rules
//! first where the caller ticked them. Nothing the client sends is a command,
//! and no plan it was shown decides what runs.
//!
//! A plan carries an id, a digest of the plan itself. A fresh plan that asks
//! for confirmation runs only when the request names its id — the one the
//! user confirmed — so a firewall that changed between the two requests is
//! answered with the new plan to show instead of running what nobody saw.
//!
//! # Privilege
//!
//! `shell`: reading a firewall needs root (ufw keeps its rule files `0640`,
//! firewalld answers root), and changing one can shut the machine off the
//! network. Reads and changes go through `sudo` unless the agent is root; the
//! `sudo` password is a request field written to its stdin
//! (`machine::as_root`). The probe that finds which firewall there is never
//! asks for root.
//!
//! # Linux only
//!
//! ufw and firewalld exist nowhere else.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use sbm_parser::SystemType;
use sbm_parser::firewall::change::{ChangeError, FirewalldChange, Plan, UfwChange, firewalld_plan, ufw_plan};
use sbm_parser::firewall::firewalld::{self, FirewalldSnapshot};
use sbm_parser::firewall::ufw::{self, UfwSnapshot};
use sbm_parser::firewall::{self, FirewallAccess, FirewallAccessVia, FirewallKind, FirewallProbeResult, FirewallReach};

use super::exec::Limits;
use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;
use crate::monitoring::system_type;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Which {
    Ufw,
    Firewalld,
}

impl From<FirewallKind> for Which {
    fn from(kind: FirewallKind) -> Self {
        match kind {
            FirewallKind::Ufw => Self::Ufw,
            FirewallKind::Firewalld => Self::Firewalld,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ReadRequest {
    /// Which firewall; the one [`FirewallProbeResult::preferred`] names when
    /// absent.
    #[serde(default)]
    kind: Option<Which>,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum Reason {
    UnsupportedPlatform,
    NoneInstalled,
    /// The read failed; `reason` holds what the machine said.
    Unreadable,
}

/// One firewall as the panel draws it.
#[derive(Serialize, Default)]
struct ReadResponse {
    available: bool,
    reason_kind: Option<Reason>,
    reason: Option<String>,
    /// `sudo` wants a password, or refused the one sent: ask and send the
    /// same request again.
    sudo_required: bool,
    /// Each firewall found, and whether it is on.
    ufw_installed: Option<bool>,
    firewalld_installed: Option<bool>,
    kind: Option<Which>,
    /// The ways in every change is checked against, with what reaches each
    /// now.
    accesses: Vec<AccessNow>,
    /// The panel reaches this agent through a proxy on this machine: its
    /// connection is on loopback, which no firewall rule here decides, and
    /// the port the proxy listens on is not known.
    proxied: bool,
    ufw: Option<UfwSnapshot>,
    firewalld: Option<FirewalldView>,
}

#[derive(Serialize)]
struct AccessNow {
    #[serde(flatten)]
    access: FirewallAccess,
    reach: FirewallReach,
    /// firewalld: it gets in now and will not after a reload or a boot.
    shut_by_reload: bool,
}

/// firewalld's snapshot with what the panel would otherwise work out.
#[derive(Serialize)]
struct FirewalldView {
    #[serde(flatten)]
    snapshot: FirewalldSnapshot,
    /// A reload or a boot would change what is in force.
    drifted: bool,
    /// The zones each way in surely lands in, by access, where it is one.
    access_zones: Vec<Option<String>>,
}

/// Reads the firewall.
pub async fn read(
    req: HttpRequest,
    body: web::types::Json<ReadRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "firewall read").await {
        return Ok(refused);
    }
    let request = body.into_inner();
    let (accesses, proxied) = accesses(&req, &state);
    let mut response = ReadResponse { proxied, ..Default::default() };
    match load(&state.remote_access.exec, request.kind, request.password.as_deref()).await {
        Err(Loaded::Unsupported) => response.reason_kind = Some(Reason::UnsupportedPlatform),
        Err(Loaded::NoneInstalled(probe)) => {
            response.reason_kind = Some(Reason::NoneInstalled);
            response.ufw_installed = probe.ufw;
            response.firewalld_installed = probe.firewalld;
        }
        Err(Loaded::SudoRequired(probe)) => {
            response.sudo_required = true;
            response.ufw_installed = probe.ufw;
            response.firewalld_installed = probe.firewalld;
        }
        Err(Loaded::Unreadable(probe, why)) => {
            response.reason_kind = Some(Reason::Unreadable);
            response.reason = why;
            response.ufw_installed = probe.ufw;
            response.firewalld_installed = probe.firewalld;
        }
        Ok(loaded) => {
            response.available = true;
            response.ufw_installed = loaded.probe.ufw;
            response.firewalld_installed = loaded.probe.firewalld;
            match loaded.state {
                Read::Ufw(s) => {
                    response.kind = Some(Which::Ufw);
                    response.accesses = accesses
                        .iter()
                        .map(|a| AccessNow { access: a.clone(), reach: s.reach(a, None, None, None), shut_by_reload: false })
                        .collect();
                    response.ufw = Some(s);
                }
                Read::Firewalld(s) => {
                    response.kind = Some(Which::Firewalld);
                    response.accesses = accesses
                        .iter()
                        .map(|a| AccessNow { access: a.clone(), reach: s.reach(a, None, None, None, None), shut_by_reload: s.shut_by_reload(a) })
                        .collect();
                    let access_zones = accesses
                        .iter()
                        .map(|a| match &s.zones_for(a, None, None)[..] {
                            [one] => Some(one.name.clone()),
                            _ => None,
                        })
                        .collect();
                    response.firewalld = Some(FirewalldView { drifted: s.drifted(), access_zones, snapshot: s });
                }
            }
        }
    }
    Ok(HttpResponse::Ok().json(&response))
}

/// A change, as the panel names it.
#[derive(Debug, Deserialize)]
#[serde(tag = "kind", content = "change", rename_all = "snake_case")]
pub enum Change {
    Ufw(UfwChange),
    Firewalld(FirewalldChange),
}

impl Change {
    fn which(&self) -> Which {
        match self {
            Self::Ufw(_) => Which::Ufw,
            Self::Firewalld(_) => Which::Firewalld,
        }
    }

    /// The change without what was typed, for the audit row.
    fn verb(&self) -> String {
        let name = |v: &dyn std::fmt::Debug| {
            let text = format!("{v:?}");
            text.split([' ', '{', '(']).next().unwrap_or_default().to_owned()
        };
        match self {
            Self::Ufw(c) => format!("ufw {}", name(c)),
            Self::Firewalld(c) => format!("firewalld {}", name(c)),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct PlanRequest {
    #[serde(flatten)]
    change: Change,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ActRequest {
    #[serde(flatten)]
    change: Change,
    /// Run the plan's keep-open rules first.
    #[serde(default)]
    keep_open: bool,
    /// The id of the plan the user confirmed; needed when the fresh plan asks.
    #[serde(default)]
    plan_id: Option<String>,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct PlanResponse {
    sudo_required: bool,
    plan: Option<Plan>,
    plan_id: Option<String>,
}

/// What names `plan`: a digest of all of it, so any difference in what would
/// run or what it would do is a different id, and nothing is kept here.
fn plan_id(plan: &Plan) -> String {
    let json = serde_json::to_vec(plan).unwrap_or_default();
    hex::encode(Sha256::digest(&json))
}

/// What a change would run and do.
pub async fn plan(
    req: HttpRequest,
    body: web::types::Json<PlanRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let what = format!("firewall plan {}", request.change.verb());
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, &what).await {
        return Ok(refused);
    }
    let (accesses, _) = accesses(&req, &state);
    match planned(&state.remote_access.exec, &request.change, request.password.as_deref(), &accesses).await {
        Ok((plan, _)) => {
            let id = plan_id(&plan);
            Ok(HttpResponse::Ok().json(&PlanResponse { sudo_required: false, plan: Some(plan), plan_id: Some(id) }))
        }
        Err(Planned::SudoRequired) => Ok(HttpResponse::Ok().json(&PlanResponse { sudo_required: true, plan: None, plan_id: None })),
        Err(refused) => Ok(refused.http()),
    }
}

#[derive(Serialize, Default)]
struct ActResponse {
    succeeded: bool,
    sudo_rejected: bool,
    exit_code: Option<i32>,
    stderr: String,
    /// Nothing ran: the fresh plan asks, and is not the one confirmed. Show
    /// `plan` and send its `plan_id` back once the user agrees.
    confirm_required: bool,
    plan: Option<Plan>,
    plan_id: Option<String>,
}

/// Makes a change: planned again from a fresh read, then run.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<ActRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let what = format!("firewall {}", request.change.verb());
    let gated = match machine::gate(&req, &state, Grant::Shell, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let record = |action, outcome, detail: Option<&str>| {
        Event::new(Kind::Machine, action, outcome)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip.clone())
            .detail(match detail {
                Some(detail) => format!("{what}: {detail}"),
                None => what.clone(),
            })
    };
    let exec = &state.remote_access.exec;
    let (accesses, _) = accesses(&req, &state);
    let password = request.password.as_deref();
    let (plan, root) = match planned(exec, &request.change, password, &accesses).await {
        Ok(planned) => planned,
        Err(Planned::SudoRequired) => {
            return Ok(HttpResponse::Ok().json(&ActResponse { sudo_rejected: true, ..Default::default() }));
        }
        Err(refused) => {
            record(Action::Denied, Outcome::Denied, Some(refused.code())).record(&state.db).await;
            return Ok(refused.http());
        }
    };
    if plan.confirm {
        let id = plan_id(&plan);
        if request.plan_id.as_deref() != Some(id.as_str()) {
            return Ok(HttpResponse::Ok().json(&ActResponse { confirm_required: true, plan: Some(plan), plan_id: Some(id), ..Default::default() }));
        }
    }
    let script = firewall::script(&plan.script_commands(request.keep_open));
    // Recorded before it runs: what was asked of the machine is on file
    // whatever happens next.
    record(Action::Open, Outcome::Ok, request.keep_open.then_some("with keep-open rules")).record(&state.db).await;
    let out = if root { machine::as_self(&script, exec).await } else { machine::as_root(&script, password, exec).await };
    let sudo_rejected = out.as_ref().is_ok_and(|out| sbm_parser::script::sudo_password_rejected(&out.stderr));
    let succeeded = out.as_ref().is_ok_and(|out| out.exit_code == Some(0) && !out.timed_out);
    if !succeeded {
        let why = if sudo_rejected { "sudo password rejected" } else { "command failed" };
        record(Action::Close, Outcome::Error, Some(why)).record(&state.db).await;
    }
    let (stderr, exit_code) = match out {
        Ok(out) => (out.stderr, out.exit_code),
        Err(e) => (e.to_string(), None),
    };
    Ok(HttpResponse::Ok().json(&ActResponse { succeeded, sudo_rejected, exit_code, stderr, ..Default::default() }))
}

// ---------------------------------------------------------------------------
// The machine
// ---------------------------------------------------------------------------

/// The ways into this machine a change is checked against: the panel's
/// connection to this agent, unless it comes through a proxy here, and the
/// machine's SSH port. Neither knows the interface it arrives on, nor SSH who
/// connects from where.
fn accesses(req: &HttpRequest, state: &AppState) -> (Vec<FirewallAccess>, bool) {
    let mut out = Vec::new();
    let peer = req.peer_addr();
    let proxied = peer.is_some_and(|p| p.ip().is_loopback());
    if !proxied {
        out.push(FirewallAccess {
            via: FirewallAccessVia::Monitor,
            port: state.config.get_server().port,
            client: peer.map(|p| p.ip().to_string()),
            server: None,
            iface: None,
        });
    }
    let ssh_port = state
        .remote_access
        .ssh_addr
        .rsplit_once(':')
        .and_then(|(_, port)| port.parse().ok())
        .unwrap_or(22);
    out.push(FirewallAccess { via: FirewallAccessVia::Ssh, port: ssh_port, client: None, server: None, iface: None });
    (out, proxied)
}

enum Read {
    Ufw(UfwSnapshot),
    Firewalld(FirewalldSnapshot),
}

struct LoadedFirewall {
    probe: FirewallProbeResult,
    state: Read,
}

enum Loaded {
    Unsupported,
    NoneInstalled(FirewallProbeResult),
    SudoRequired(FirewallProbeResult),
    Unreadable(FirewallProbeResult, Option<String>),
}

/// The probe, then `kind` (or the preferred one) read as root.
async fn load(exec: &Limits, kind: Option<Which>, password: Option<&str>) -> Result<LoadedFirewall, Loaded> {
    if system_type() != SystemType::Linux {
        return Err(Loaded::Unsupported);
    }
    let probed = machine::command_output(machine::as_self(firewall::PROBE_SCRIPT, exec).await);
    let probe = firewall::parse_probe(&probed.stdout);
    let which = match kind {
        Some(which) => which,
        None => match probe.preferred() {
            Some(kind) => kind.into(),
            None => return Err(Loaded::NoneInstalled(probe)),
        },
    };
    let installed = match which {
        Which::Ufw => probe.ufw.is_some(),
        Which::Firewalld => probe.firewalld.is_some(),
    };
    if !installed {
        return Err(Loaded::NoneInstalled(probe));
    }
    let script = match which {
        Which::Ufw => ufw::read_script(),
        Which::Firewalld => firewalld::read_script(),
    };
    let out = if probe.root { machine::as_self(&script, exec).await } else { machine::as_root(&script, password, exec).await };
    if out.as_ref().is_ok_and(|out| sbm_parser::script::sudo_password_rejected(&out.stderr)) {
        return Err(Loaded::SudoRequired(probe));
    }
    let output = machine::command_output(out);
    if !output.succeeded {
        return Err(Loaded::Unreadable(probe, output.detail()));
    }
    let state = match which {
        Which::Ufw => ufw::parse(&output.stdout).map(Read::Ufw),
        Which::Firewalld => firewalld::parse(&output.stdout).map(Read::Firewalld),
    };
    match state {
        Ok(state) => Ok(LoadedFirewall { probe, state }),
        Err(why) => Err(Loaded::Unreadable(probe, Some(why))),
    }
}

/// Why a change was not planned.
enum Planned {
    SudoRequired,
    Unreadable,
    /// The kind the change is for is not what this machine has.
    WrongKind,
    Refused(ChangeError),
}

impl Planned {
    fn code(&self) -> &'static str {
        match self {
            Self::SudoRequired => "sudoRequired",
            Self::Unreadable => "unreadable",
            Self::WrongKind => "notInstalled",
            Self::Refused(ChangeError::Unchanged) => "unchanged",
            Self::Refused(ChangeError::Draft(_)) => "invalidRule",
            Self::Refused(ChangeError::Input(_)) => "invalidInput",
            Self::Refused(ChangeError::NoSuchRule) => "noSuchRule",
            Self::Refused(ChangeError::NoSuchZone) => "noSuchZone",
        }
    }

    fn http(&self) -> HttpResponse {
        #[derive(Serialize)]
        struct Body<'a> {
            error: &'static str,
            /// The draft or input issue, for the panel to phrase.
            issue: Option<&'a ChangeError>,
        }
        let issue = match self {
            Self::Refused(e @ (ChangeError::Draft(_) | ChangeError::Input(_))) => Some(e),
            _ => None,
        };
        let mut builder = match self {
            Self::Unreadable => HttpResponse::BadGateway(),
            Self::Refused(ChangeError::NoSuchRule | ChangeError::NoSuchZone) => HttpResponse::NotFound(),
            _ => HttpResponse::BadRequest(),
        };
        builder.json(&Body { error: self.code(), issue })
    }
}

/// `change` planned against the firewall as it is now, and whether the agent
/// runs as root (so the plan runs without `sudo`).
async fn planned(exec: &Limits, change: &Change, password: Option<&str>, accesses: &[FirewallAccess]) -> Result<(Plan, bool), Planned> {
    let loaded = match load(exec, Some(change.which()), password).await {
        Ok(loaded) => loaded,
        Err(Loaded::SudoRequired(_)) => return Err(Planned::SudoRequired),
        Err(Loaded::NoneInstalled(_) | Loaded::Unsupported) => return Err(Planned::WrongKind),
        Err(Loaded::Unreadable(..)) => return Err(Planned::Unreadable),
    };
    let plan = match (&loaded.state, change) {
        (Read::Ufw(s), Change::Ufw(c)) => ufw_plan(s, c, accesses).map_err(Planned::Refused)?,
        (Read::Firewalld(s), Change::Firewalld(c)) => firewalld_plan(s, c, accesses).map_err(Planned::Refused)?,
        _ => return Err(Planned::WrongKind),
    };
    Ok((plan, loaded.probe.root))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_change_is_read_from_the_panels_json() {
        let c: PlanRequest = serde_json::from_str(r#"{"kind":"ufw","change":{"type":"policy","chain":"incoming","policy":"deny"},"password":"x"}"#).unwrap();
        assert!(matches!(c.change, Change::Ufw(UfwChange::Policy { .. })));
        let c: ActRequest = serde_json::from_str(
            r#"{"kind":"firewalld","change":{"type":"add","zone":"public","item":"rich_rule","value":"rule drop"},"keep_open":true}"#,
        )
        .unwrap();
        assert!(c.keep_open);
        assert!(matches!(c.change, Change::Firewalld(FirewalldChange::Add { .. })));
    }

    /// The same plan is the same id; any difference in it is another.
    #[test]
    fn a_plan_id_names_exactly_one_plan() {
        let s = ufw::parse(include_str!("../../../crates/sbm_parser/tests/fixtures/ufw/active.txt")).unwrap();
        let ssh = [FirewallAccess { via: FirewallAccessVia::Ssh, port: 22, client: None, server: None, iface: None }];
        let a = ufw_plan(&s, &UfwChange::Enable, &ssh).unwrap();
        assert_eq!(plan_id(&a), plan_id(&a.clone()));
        let b = ufw_plan(&s, &UfwChange::Disable, &ssh).unwrap();
        assert_ne!(plan_id(&a), plan_id(&b));
        let mut c = a.clone();
        c.effects[0].after = FirewallReach::Blocked;
        c.effects[0].before = FirewallReach::Open;
        assert_ne!(plan_id(&a), plan_id(&c));
    }

    /// The audit row names the change, never what was typed into it.
    #[test]
    fn the_audit_names_the_verb_alone() {
        let c: PlanRequest = serde_json::from_str(
            r#"{"kind":"firewalld","change":{"type":"add","zone":"public","item":"source","value":"10.9.8.7/32"}}"#,
        )
        .unwrap();
        assert_eq!(c.change.verb(), "firewalld Add");
        assert!(!c.change.verb().contains("10.9.8.7"));
    }
}
