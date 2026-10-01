//! `/api/v1/containers` — the containers on the machine the agent runs on.
//!
//! # Why this is not `/exec`
//!
//! Every command here is a fixed string this agent composes, and every answer
//! is parsed. Sending `docker ps` through `/exec` and parsing it in the panel
//! would work — it is what the app does over SSH — but the choice of *which*
//! fields to ask for, how to tell Podman from Docker, how a container's state
//! is read out of either one's wording and what a prune is allowed to remove is
//! a model, not a command. It lives in [`sbm_parser::container`], so the app,
//! this endpoint and the panel read one machine the same way.
//!
//! The panel also never composes a command line. A start, a stop, a removal is
//! a [`ContainerAction`] on the wire, serialized as a tagged object, and an
//! action this build does not implement is refused while deserializing rather
//! than reaching a shell.
//!
//! # Runtime detection
//!
//! The agent asks `docker` first and `podman` second, and honours the client
//! that lies about its name: Podman prints `Emulate Docker CLI using podman` on
//! stderr and otherwise answers every Docker command exactly, so a machine where
//! `/usr/bin/docker` is a Podman symlink would otherwise be reported as Docker
//! and silently show Podman's dialect.
//!
//! There is no way for the caller to name the runtime or the socket. A remote
//! `DOCKER_HOST` is a real case the app supports and this endpoint does not yet
//! — TODO: an agent-side setting, alongside the container type, edited through
//! `MonitorSettingsPage` the way the rest of the agent's own configuration is.
//!
//! # Privilege
//!
//! The `shell` grant for both halves (`api::machine::gate`): changing a
//! container is running code, and a container's log and its command line are
//! where a secret it was started with shows.
//!
//! A runtime the agent's user is not a member of answers `permission denied`,
//! which is reported as its own [`ContainerReason`] rather than as a failure of
//! the request: the remedy is on the machine (`usermod -aG docker <user>`), not
//! in the panel, and a page that showed the shell's words would say neither
//! which group nor which user. TODO: run through `machine::as_root` with a
//! password from the body, as `/process` and `/services` do, for a runtime
//! only root may reach.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::exec::{ExecResponse, Limits, run};
use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;
use crate::monitoring::system_type;
use sbm_parser::container::{
    Container, ContainerAction, ContainerCmd, ContainerImage, ContainerStats, ContainerType,
    DiskUsage, SEPARATOR_PREFIX,
};

/// A container listing plus one stats sample, on a host with many containers,
/// is the largest thing this endpoint asks for. The cap is here so a runtime
/// that prints without end cannot make the agent buffer without bound; going
/// over is reported like any other unreadable answer rather than as a crash.
const MAX_OUTPUT_BYTES: usize = 8 * 1024 * 1024;

/// Which of the four things the panel is asking for.
///
/// One route rather than four, because the four share a runtime probe, a reason
/// vocabulary, and four handlers would be four copies
/// of that. They are *not* fetched together: `system df` walks the whole image
/// store, which on a host with many images is hundreds of milliseconds that a
/// page refreshing every few seconds must not pay.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContainerPart {
    /// The container list, with a stats sample for each running one.
    #[default]
    Containers,
    /// The images.
    Images,
    /// How much space a prune would reclaim.
    Usage,
    /// The last lines of one container's log, named by `id`.
    ///
    /// Its own part rather than an `/exec` call from the panel: what it prints
    /// is the runtime's own text, the command is one this endpoint already
    /// builds for the app, and the panel never composes a command line. It is
    /// a bounded read — the app's log view follows the output, and a request
    /// that did would never answer.
    Logs,
}

impl ContainerPart {
    /// The part's own name, for the marker that tells its answers apart.
    fn as_str(self) -> &'static str {
        match self {
            Self::Containers => "containers",
            Self::Images => "images",
            Self::Usage => "usage",
            Self::Logs => "logs",
        }
    }

    /// Whether this part needs `id` to be answered at all.
    fn needs_id(self) -> bool {
        matches!(self, Self::Logs)
    }
}

#[derive(Serialize)]
struct ContainerListResponse {
    /// Which of the four this answers. Echoed because a response is read
    /// beside a request that may have been made minutes ago, and the panel
    /// keeps one object per part.
    part: ContainerPart,
    /// Whether the machine has a runtime this endpoint could talk to. `false`
    /// is a state of the machine, not a failure of the caller, so it is a field
    /// rather than a status code and the panel draws one page either way.
    available: bool,
    /// Which of the known reasons it was, so the panel phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something this endpoint does not classify, and `reason` is it.
    reason_kind: Option<ContainerReason>,
    /// What the machine said, verbatim, with this endpoint's own scaffolding
    /// dropped out of it. Never translated and never classified away: it is the
    /// only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// Which runtime answered, once one did.
    runtime: Option<RuntimeView>,
    containers: Vec<ContainerRow>,
    images: Vec<ContainerImage>,
    usage: Option<DiskUsage>,
    /// The container's log, for [`ContainerPart::Logs`]. `None` elsewhere, and
    /// `None` for a log the runtime refused to print — the reason says which.
    logs: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum ContainerReason {
    /// Neither `docker` nor `podman` is on the machine.
    NotInstalled,
    /// Windows, where neither the runtime nor `sh -c` behind it exists.
    UnsupportedPlatform,
    /// The runtime is there and the agent's user may not talk to it.
    PermissionDenied,
    /// It ran and its output was not something this build could read.
    Unreadable,
}

#[derive(Serialize)]
struct RuntimeView {
    /// `docker` or `podman`, as the name the commands are built from.
    kind: ContainerType,
    /// The *client's* version, or `None` when the machine did not report one.
    /// It is the client that reads the socket, so it is the client's version
    /// that decides how a stats row is shaped.
    version: Option<String>,
}

/// One container as the panel draws it: the listing's fields plus the sample.
///
/// The sample is merged in by id here rather than handed over as a side table,
/// because the matched id is the answer to a question the panel would otherwise
/// have to ask again — and one that [`sbm_parser::container::find_stats_row`]
/// answers with a rule (a shared twelve-character prefix) that is not obvious
/// from the outside.
#[derive(Serialize)]
struct ContainerRow {
    #[serde(flatten)]
    container: Container,
    /// Absent for a container that is not running, and for one the runtime did
    /// not answer for — a stopped container has no sample to give.
    stats: Option<ContainerStats>,
    /// Which actions this container's state is offered under, from
    /// [`sbm_parser::container::menu_items`].
    ///
    /// Sent rather than derived by the client: "an unrecognised state is
    /// grouped with a stopped one, and a container that will not start is
    /// exactly the one whose logs are wanted" is a rule, and a second
    /// implementation of it would be the one that drifts.
    actions: Vec<sbm_parser::container::ContainerActionKind>,
}

/// Reads one part of the machine's container state.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<ContainerQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "containers list").await {
        return Ok(refused);
    }
    let exec = &state.remote_access.exec;
    let part = query.part.unwrap_or_default();
    let id = query.id.as_deref();
    // A part that is about one container and was not told which is a request
    // that cannot be answered, not one to guess a default for. Refused before
    // the runtime is run, so a malformed request costs nothing on the machine.
    if part.needs_id() && id.is_none_or(str::is_empty) {
        return Ok(HttpResponse::BadRequest().finish());
    }
    Ok(HttpResponse::Ok().json(&read(part, id, exec).await))
}

#[derive(Debug, Deserialize)]
pub struct ContainerQuery {
    part: Option<ContainerPart>,
    /// Which container a part about one is about. Ignored by the parts that are
    /// about the machine, so a client may carry it along without harm.
    id: Option<String>,
}

/// Performs one change and reports how the machine answered.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<ContainerAction>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let action = body.into_inner();
    let what = format!("containers {}", action_subject(&action));
    let gated = match machine::gate(&req, &state, Grant::Shell, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let exec = &state.remote_access.exec;
    let Some(runtime) = detect_runtime(exec).await else {
        return Ok(HttpResponse::Ok().json(&read(ContainerPart::Containers, None, exec).await));
    };

    // Recorded before it runs; the subject is the account, the detail the
    // action and the container it named — never a command line.
    Event::new(Kind::Machine, Action::Open, Outcome::Ok)
        .subject(&gated.caller.username)
        .remote_ip(gated.remote_ip.clone())
        .detail(&what)
        .record(&state.db)
        .await;
    let result = run_local(&action.exec(runtime), exec).await;
    let failed = match &result {
        Some(output) if output.exit_code == Some(0) => None,
        Some(output) => Some(format!("exit {:?}", output.exit_code)),
        None => Some("did not finish".to_owned()),
    };
    if let Some(why) = failed {
        Event::new(Kind::Machine, Action::Close, Outcome::Error)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip)
            .detail(format!("{what}: {why}"))
            .record(&state.db)
            .await;
    }

    // The refreshed listing comes back with the answer, in one round trip: a
    // caller that had to ask again would be asking about a machine that has
    // since moved, and the page has one object to update either way.
    let mut response =
        serde_json::to_value(read(ContainerPart::Containers, None, exec).await).unwrap_or_default();
    if let Some(output) = result
        && let Some(object) = response.as_object_mut()
    {
        object.insert("exit_code".to_owned(), output.exit_code.into());
        object.insert(
            "output".to_owned(),
            sbm_parser::container::user_facing_output(&output.stderr, &output.stdout).into(),
        );
    }
    Ok(HttpResponse::Ok().json(&response))
}

/// What the audit row says. The action and the container, never a command
/// line: the id reaches this agent from a machine listing, and the row that
/// records a change should not be the place a shell string is kept.
fn action_subject(action: &ContainerAction) -> String {
    match action {
        ContainerAction::Start { id } => format!("start {id}"),
        ContainerAction::Stop { id } => format!("stop {id}"),
        ContainerAction::Restart { id } => format!("restart {id}"),
        ContainerAction::Remove { id, force } => {
            format!("remove{} {id}", if *force { " -f" } else { "" })
        }
        ContainerAction::PruneContainers => "prune containers".to_owned(),
        ContainerAction::PruneVolumes => "prune volumes".to_owned(),
    }
}

/// Everything this endpoint can answer, gathered per part.
async fn read(part: ContainerPart, id: Option<&str>, exec: &Limits) -> ContainerListResponse {
    let empty = |kind: Option<ContainerReason>, reason: Option<String>| ContainerListResponse {
        part,
        available: false,
        reason_kind: kind,
        reason,
        runtime: None,
        containers: Vec::new(),
        images: Vec::new(),
        usage: None,
        logs: None,
    };

    if system_type() == sbm_parser::SystemType::Windows {
        return empty(Some(ContainerReason::UnsupportedPlatform), None);
    }

    // Both runtimes are tried, and the answer of each is reported as itself:
    // this is what tells "no docker" from "no docker *and* no podman", which
    // are two different things to say to a user.
    let mut last: Option<Probe> = None;
    for ty in [ContainerType::Docker, ContainerType::Podman] {
        let probe = probe(ty, part, id, exec).await;
        match probe {
            Probe::NotInstalled { .. } => {
                last = Some(probe);
                continue;
            }
            probe => return finish(part, probe).await,
        }
    }

    match last {
        // The runtime's own words for "not installed", when it said any: on
        // Podman that is a sentence rather than an exit code, and it is what
        // the user has to see to know which binary to install.
        Some(Probe::NotInstalled { reason }) => {
            empty(Some(ContainerReason::NotInstalled), reason)
        }
        _ => empty(Some(ContainerReason::NotInstalled), None),
    }
}

/// What one batch against one runtime came back as.
enum Probe {
    /// The batch ran and printed answers to split. The runtime is the one that
    /// *answered*, which is not always the one that was asked: a `docker` that
    /// is a `podman` symlink answers as Podman.
    Answered {
        ty: ContainerType,
        segments: Vec<String>,
    },
    /// The runtime is not on this machine.
    NotInstalled { reason: Option<String> },
    /// It is, and this user may not talk to it.
    PermissionDenied {
        ty: ContainerType,
        reason: Option<String>,
    },
    /// It is, and it said something this build could not read.
    Unreadable {
        ty: ContainerType,
        reason: Option<String>,
    },
}

/// Runs the commands one part needs, in one shell.
///
/// The separator carries a timestamp and a counter of its own: a marker reused
/// across calls would let a stale answer be split against commands it was not
/// an answer to, and the split is by *position*, so a short answer would attach
/// one command's output to another command's name.
async fn probe(ty: ContainerType, part: ContainerPart, id: Option<&str>, exec: &Limits) -> Probe {
    let mut cmds = vec![ContainerCmd::Version.exec(ty)];
    cmds.extend(match part {
        ContainerPart::Containers => [ContainerCmd::Ps, ContainerCmd::Stats]
            .map(|cmd| cmd.exec(ty))
            .to_vec(),
        ContainerPart::Images => vec![ContainerCmd::Images.exec(ty)],
        ContainerPart::Usage => vec![ContainerCmd::Df.exec(ty)],
        // `read` refuses this part without an id, so an empty one here is the
        // path that never runs rather than a container named "".
        ContainerPart::Logs => vec![sbm_parser::container::logs_tail_command(
            ty,
            id.unwrap_or_default(),
            sbm_parser::container::LOG_TAIL,
        )],
    });

    let separator = format!(
        "{SEPARATOR_PREFIX}_{}_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|elapsed| elapsed.as_micros())
            .unwrap_or_default(),
        part.as_str()
    );
    let command_text = sbm_parser::container::join_commands(&cmds, &separator);
    let command_text = sbm_parser::container::build_runtime_command(&command_text, ty, None, false);

    let Some(output) = run_local(&command_text, exec).await else {
        return Probe::Unreadable {
            ty,
            reason: Some("the command did not finish".to_owned()),
        };
    };
    let ExecResponse {
        stdout,
        stderr,
        exit_code,
        ..
    } = output;
    let exit_code = exit_code.unwrap_or(-1);
    let reason = || sbm_parser::container::user_facing_output(&stderr, &stdout);

    if sbm_parser::container::is_not_installed(ty, &stdout, &stderr, exit_code) {
        return Probe::NotInstalled { reason: reason() };
    }
    // Checked before parsing rather than after: a client emulating another
    // runtime answers every command *successfully*, so nothing downstream
    // notices, and every container would be reported by a runtime the user did
    // not pick. It is not "not installed" — Podman is there, wearing a name its
    // own commands do not use.
    let ty = if sbm_parser::container::is_podman_emulation(&stderr) && ty == ContainerType::Docker {
        ContainerType::Podman
    } else {
        ty
    };
    // A runtime that refuses this user answers `permission denied` and nothing
    // else, so this is reported as itself rather than folded into "unreadable":
    // the two have different remedies and only one of them is on the machine.
    if needs_permission(&stdout, &stderr) {
        return Probe::PermissionDenied {
            ty,
            reason: reason(),
        };
    }

    let segments = sbm_parser::container::split_segments(&stdout, &separator);
    // One segment per command — the marker is written *between* them, so the
    // first command's output is the first segment. A count that does not match
    // is not something to guess at: a missing segment cannot be matched to the
    // command it belonged to, and attaching one command's output to another's
    // name is worse than saying so.
    if segments.len() != cmds.len() {
        return Probe::Unreadable {
            ty,
            reason: reason(),
        };
    }
    Probe::Answered { ty, segments }
}

/// Whether the runtime is there but would not talk to this user.
fn needs_permission(stdout: &str, stderr: &str) -> bool {
    let denied = |text: &str| {
        let lower = text.to_lowercase();
        lower.contains("permission denied")
            || lower.contains("access denied")
            || lower.contains("got permission denied while trying to connect")
    };
    denied(stderr) || denied(stdout)
}

/// Turns one batch's answers into the response body.
///
/// The three failure shapes share their body and differ in the reason and in
/// whether a runtime is named: a machine with no runtime has none to report,
/// and the two failures on a machine that has one do — the user needs to know
/// which binary to look at.
async fn finish(part: ContainerPart, probe: Probe) -> ContainerListResponse {
    let unavailable = |ty: Option<ContainerType>, kind: ContainerReason, reason: Option<String>| {
        ContainerListResponse {
            part,
            available: false,
            reason_kind: Some(kind),
            reason,
            runtime: ty.map(|kind| RuntimeView {
                kind,
                version: None,
            }),
            containers: Vec::new(),
            images: Vec::new(),
            usage: None,
            logs: None,
        }
    };

    let (ty, segments) = match probe {
        Probe::Answered { ty, segments } => (ty, segments),
        Probe::Unreadable { ty, reason } => {
            return unavailable(Some(ty), ContainerReason::Unreadable, reason);
        }
        Probe::PermissionDenied { ty, reason } => {
            return unavailable(Some(ty), ContainerReason::PermissionDenied, reason);
        }
        // Not reached from `read`, which needs no runtime to answer it.
        Probe::NotInstalled { reason } => {
            return unavailable(None, ContainerReason::NotInstalled, reason);
        }
    };

    let version = sbm_parser::container::parse_version(&segments[0]);
    let version_text = version.as_deref();

    let mut containers = Vec::new();
    let mut images = Vec::new();
    let mut usage = None;
    let mut logs = None;

    match part {
        ContainerPart::Containers => {
            let listed = sbm_parser::container::parse_docker_ps(&segments[1]);
            let stats_rows = sbm_parser::container::parse_stats_rows(&segments[2]);
            containers = listed
                .into_iter()
                .map(|container| ContainerRow {
                    stats: sbm_parser::container::find_stats_row(&stats_rows, container.id.as_deref())
                        .and_then(|raw| sbm_parser::container::parse_stats(ty, raw, version_text)),
                    actions: sbm_parser::container::menu_items(container.status),
                    container,
                })
                .collect();
        }
        ContainerPart::Images => {
            images = sbm_parser::container::parse_images(&segments[1], ty);
        }
        ContainerPart::Usage => {
            usage = sbm_parser::container::parse_disk_usage(&segments[1]);
        }
        // The runtime's own text, passed through as it printed it: it is the
        // container's output, and a client that reformatted it would be drawing
        // something the container did not write.
        ContainerPart::Logs => logs = Some(segments[1].trim_matches('\n').to_owned()),
    }

    ContainerListResponse {
        part,
        available: true,
        reason_kind: None,
        reason: None,
        runtime: Some(RuntimeView {
            kind: ty,
            version,
        }),
        containers,
        images,
        usage,
        logs,
    }
}

/// Which runtime this machine has, for the write path.
///
/// `docker version` and nothing else: a write needs only to know what to
/// prefix the action with, and running a listing or a `system df` to find that
/// out would fetch a table to throw away. A refusal to talk to this user is
/// *not* a reason to try the other runtime — the runtime is there, and the
/// command the user asked for should fail with the machine's own words about
/// why rather than with the other runtime's absence.
async fn detect_runtime(exec: &Limits) -> Option<ContainerType> {
    if system_type() == sbm_parser::SystemType::Windows {
        return None;
    }
    for ty in [ContainerType::Docker, ContainerType::Podman] {
        let command_text = ContainerCmd::Version.exec(ty);
        let command_text =
            sbm_parser::container::build_runtime_command(&command_text, ty, None, false);
        let Some(output) = run_local(&command_text, exec).await else {
            continue;
        };
        let (stdout, stderr) = (&output.stdout, &output.stderr);
        let exit_code = output.exit_code.unwrap_or(-1);
        if sbm_parser::container::is_not_installed(ty, stdout, stderr, exit_code)
            || (ty == ContainerType::Docker && sbm_parser::container::is_podman_emulation(stderr))
        {
            // A `docker` that is Podman answers as Podman in the second
            // iteration, which is the runtime whose commands the action
            // actually needs.
            continue;
        }
        return Some(ty);
    }
    None
}

/// Runs one local command with this endpoint's own bounds.
///
/// `None` for a timeout, an output past the cap or a spawn that failed:
/// either way there is nothing to parse, and the caller reports it as "could
/// not read" rather than as a crash.
async fn run_local(command_text: &str, exec: &Limits) -> Option<ExecResponse> {
    match run(command_text, None, None, &machine::at_least(exec, MAX_OUTPUT_BYTES)).await {
        Ok(output) if !output.timed_out && !output.truncated => Some(output),
        Ok(_) => None,
        Err(e) => {
            tracing::warn!("containers: {e}");
            None
        }
    }
}
