//! The containers on a machine, and the changes to them.
//!
//! Every command is a fixed string composed here from [`sbm_parser::container`]
//! and every answer is parsed: which fields to ask for, how to tell Podman
//! from Docker, how a container's state is read out of either one's wording
//! and what a prune may remove is a model, not a command. A change is a
//! [`ContainerAction`], refused while deserializing when this build does not
//! implement it; a `run`'s extra arguments are split by
//! [`sbm_parser::container::parse_run_args`], never by the caller.
//!
//! # Runtime detection
//!
//! `docker` first and `podman` second, honouring the client that lies about
//! its name: Podman prints `Emulate Docker CLI using podman` on stderr and
//! otherwise answers every Docker command exactly, so a `docker` that is a
//! Podman symlink would otherwise show Podman's dialect as Docker's.
//!
//! A runtime the account may not talk to answers `permission denied`, which
//! is its own [`ContainerReason`]: the remedy is on the machine
//! (`usermod -aG docker <user>`), not in the client.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::{Machine, Ran, Run, Stage, change};
use sbm_parser::SystemType;
use sbm_parser::container::{
    Container, ContainerAction, ContainerActionError, ContainerCmd, ContainerImage, ContainerStats, ContainerType,
    DiskUsage, SEPARATOR_PREFIX,
};

/// A container listing plus one stats sample, on a host with many containers,
/// is the largest thing read here. The cap is here so a runtime that prints
/// without end cannot be buffered without bound; going over is reported like
/// any other unreadable answer.
const MAX_OUTPUT_BYTES: usize = 8 * 1024 * 1024;

/// Which of the four things is asked for.
///
/// They share a runtime probe and a reason vocabulary, and are *not* fetched
/// together: `system df` walks the whole image store, which on a host with
/// many images is hundreds of milliseconds a page refreshing every few seconds
/// must not pay.
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
    /// The last lines of one container's log, named by `id`. A bounded read:
    /// a request that followed the output would never answer.
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
    pub fn needs_id(self) -> bool {
        matches!(self, Self::Logs)
    }
}

#[derive(Debug, Serialize)]
pub struct ContainerListResponse {
    /// Which of the four this answers.
    part: ContainerPart,
    /// Whether the machine has a runtime that could be talked to. `false` is a
    /// state of the machine, not a failure of the caller.
    available: bool,
    /// Which of the known reasons it was. `None` alongside `available: false`
    /// means the machine said something not classified here, and `reason` is it.
    reason_kind: Option<ContainerReason>,
    /// What the machine said, verbatim. Never translated and never classified
    /// away.
    reason: Option<String>,
    /// Which runtime answered, once one did.
    runtime: Option<RuntimeView>,
    containers: Vec<ContainerRow>,
    images: Vec<ImageRow>,
    /// Tagged images nothing uses, for an image prune's confirmation. `None`
    /// when the count could not be confirmed (see
    /// [`sbm_parser::container::count_unused_tagged_images`]) and for every
    /// part but [`ContainerPart::Images`].
    unused_tagged: Option<i64>,
    usage: Option<DiskUsage>,
    /// The container's log, for [`ContainerPart::Logs`]; `None` for a log the
    /// runtime refused to print — the reason says which.
    logs: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ContainerReason {
    /// Neither `docker` nor `podman` is on the machine.
    NotInstalled,
    /// Windows, where neither the runtime nor `sh -c` behind it exists.
    UnsupportedPlatform,
    /// The runtime is there and the account may not talk to it.
    PermissionDenied,
    /// It ran and its output was not something this build could read.
    Unreadable,
}

#[derive(Debug, Serialize)]
struct RuntimeView {
    /// `docker` or `podman`, as the name the commands are built from.
    kind: ContainerType,
    /// The *client's* version, which decides how a stats row is shaped.
    version: Option<String>,
}

/// One container: the listing's fields plus the sample, merged by id here
/// with [`sbm_parser::container::find_stats_row`]'s rule.
#[derive(Debug, Serialize)]
struct ContainerRow {
    #[serde(flatten)]
    container: Container,
    /// Absent for a container that is not running, and for one the runtime did
    /// not answer for.
    stats: Option<ContainerStats>,
    /// Which actions this container's state is offered under, from
    /// [`sbm_parser::container::menu_items`].
    actions: Vec<sbm_parser::container::ContainerActionKind>,
}

/// One image: the parsed image plus [`ContainerImage::is_dangling`] and
/// [`ContainerImage::reference`], which a client would otherwise re-derive.
#[derive(Debug, Serialize)]
struct ImageRow {
    #[serde(flatten)]
    image: ContainerImage,
    dangling: bool,
    reference: String,
}

impl ContainerListResponse {
    pub fn reason_kind(&self) -> Option<ContainerReason> {
        self.reason_kind
    }
}

/// One part of the machine's container state.
pub async fn listing(
    m: &dyn Machine,
    part: ContainerPart,
    id: Option<&str>,
) -> Result<ContainerListResponse, ContainerActionError> {
    if part.needs_id() {
        let id = id.ok_or(ContainerActionError::Empty)?;
        sbm_parser::container::validate_identifier(id)?;
    }
    Ok(read(m, part, id, None).await)
}

/// Performs one container action and answers the refreshed listing, with the
/// action's own `exit_code` and `output` when it ran.
pub async fn apply(m: &dyn Machine, action: ContainerAction) -> Result<Value, ContainerActionError> {
    let what = format!("containers {}", action_subject(&action));
    // Refused before the runtime is probed, let alone run: a value that could
    // never be answered costs the machine nothing.
    if let Err(issue) = action.validate() {
        change(m, Stage::Refused, &what, Some(issue.code())).await;
        return Err(issue);
    }
    let Some(runtime) = detect_runtime(m).await else {
        let part = refresh_part(&action);
        return Ok(serde_json::to_value(read(m, part, None, None).await).unwrap_or_default());
    };
    let command = action.exec(runtime)?;

    // The subject is the action and the container it named — never a command
    // line.
    change(m, Stage::Started, &what, None).await;
    // A pull or a run fetches image layers and is bounded like every other
    // command, by the host's own limit.
    // TODO: start a pull detached and poll it, so a large image does not need
    // the limit raised.
    let result = m.run(Run::Line(&command), MAX_OUTPUT_BYTES).await;
    // A command stopped or never heard from may have changed the machine
    // anyway: its outcome is unknown, and said so.
    let interrupted = match &result {
        Ok(output) if output.timed_out => Some("the action did not finish in time".to_owned()),
        Ok(output) if output.truncated => Some("the action printed more than is read".to_owned()),
        Ok(_) => None,
        Err(e) => Some(e.clone()),
    };
    let failed = match (&result, &interrupted) {
        (_, Some(_)) => Some("did not finish".to_owned()),
        (Ok(output), None) if output.exit_code != Some(0) => Some(format!("exit {:?}", output.exit_code)),
        _ => None,
    };
    if let Some(why) = failed {
        change(m, Stage::Failed, &what, Some(&why)).await;
    }

    // The refreshed listing comes back with the answer, in one round trip:
    // the part the change was about, from the runtime the change was made on.
    let part = refresh_part(&action);
    let mut response = serde_json::to_value(read(m, part, None, Some(runtime)).await).unwrap_or_default();
    if let Some(object) = response.as_object_mut() {
        match (result, interrupted) {
            (_, Some(why)) => {
                object.insert("exit_code".to_owned(), Value::Null);
                object.insert("outcome_unknown".to_owned(), why.into());
            }
            (Ok(output), None) => {
                object.insert("exit_code".to_owned(), output.exit_code.into());
                object.insert(
                    "output".to_owned(),
                    sbm_parser::container::user_facing_output(&output.stderr, &output.stdout).into(),
                );
            }
            (Err(_), None) => {}
        }
    }
    Ok(response)
}

/// Which listing a change leaves stale.
fn refresh_part(action: &ContainerAction) -> ContainerPart {
    match action {
        ContainerAction::RemoveImage { .. } | ContainerAction::PullImage { .. } | ContainerAction::PruneImages { .. } => {
            ContainerPart::Images
        }
        // `system prune` removes stopped containers and `run` makes one.
        _ => ContainerPart::Containers,
    }
}

/// What the audit row says: the action and the container, never a command
/// line.
pub fn action_subject(action: &ContainerAction) -> String {
    match action {
        ContainerAction::Start { id } => format!("start {id}"),
        ContainerAction::Stop { id } => format!("stop {id}"),
        ContainerAction::Restart { id } => format!("restart {id}"),
        ContainerAction::Remove { id, force } => format!("remove{} {id}", if *force { " -f" } else { "" }),
        ContainerAction::PruneContainers => "prune containers".to_owned(),
        ContainerAction::PruneVolumes => "prune volumes".to_owned(),
        ContainerAction::RemoveImage { id } => format!("remove image {id}"),
        ContainerAction::PullImage { reference } => format!("pull {reference}"),
        ContainerAction::PruneImages { all_unused } => format!("prune images{}", if *all_unused { " -a" } else { "" }),
        ContainerAction::PruneSystem { .. } => "prune system".to_owned(),
        ContainerAction::Run { image, name, .. } => {
            if name.is_empty() {
                format!("run {image}")
            } else {
                format!("run {name} from {image}")
            }
        }
    }
}

/// Everything there is to answer, gathered per part: from [only] when given,
/// else from whichever runtime answers first.
async fn read(
    m: &dyn Machine,
    part: ContainerPart,
    id: Option<&str>,
    only: Option<ContainerType>,
) -> ContainerListResponse {
    let empty = |kind: ContainerReason, reason: Option<String>| ContainerListResponse {
        part,
        available: false,
        reason_kind: Some(kind),
        reason,
        runtime: None,
        containers: Vec::new(),
        images: Vec::new(),
        unused_tagged: None,
        usage: None,
        logs: None,
    };
    if m.system() == SystemType::Windows {
        return empty(ContainerReason::UnsupportedPlatform, None);
    }
    // Both runtimes are tried, and the answer of each is reported as itself:
    // "no docker" and "no docker *and* no podman" are two different things to
    // say to a user.
    let mut last = None;
    let runtimes = match only {
        Some(ty) => vec![ty],
        None => vec![ContainerType::Docker, ContainerType::Podman],
    };
    for ty in runtimes {
        match probe(m, ty, part, id).await {
            Probe::NotInstalled { reason } => last = reason,
            probe => return finish(part, probe),
        }
    }
    // The runtime's own words for "not installed", when it said any: on Podman
    // that is a sentence rather than an exit code.
    empty(ContainerReason::NotInstalled, last)
}

/// What one batch against one runtime came back as.
enum Probe {
    /// The batch ran and printed answers to split. The runtime is the one that
    /// *answered*: a `docker` that is a `podman` symlink answers as Podman.
    Answered { ty: ContainerType, segments: Vec<String> },
    NotInstalled { reason: Option<String> },
    PermissionDenied { ty: ContainerType, reason: Option<String> },
    Unreadable { ty: ContainerType, reason: Option<String> },
}

/// Runs the commands one part needs, in one shell.
///
/// The separator carries a timestamp and the part: a marker reused across
/// calls would let a stale answer be split against commands it was not an
/// answer to, and the split is by *position*.
async fn probe(m: &dyn Machine, ty: ContainerType, part: ContainerPart, id: Option<&str>) -> Probe {
    let mut cmds = vec![ContainerCmd::Version.exec(ty)];
    cmds.extend(match part {
        ContainerPart::Containers => [ContainerCmd::Ps, ContainerCmd::Stats].map(|cmd| cmd.exec(ty)).to_vec(),
        // `ps` rides along for one number the image prune shows: whether a
        // tagged image is in use, when the runtime did not say.
        ContainerPart::Images => vec![ContainerCmd::Images.exec(ty), ContainerCmd::Ps.exec(ty)],
        ContainerPart::Usage => vec![ContainerCmd::Df.exec(ty)],
        // `2>&1`: the runtime replays the container's own stderr on its
        // stderr. Merged into this segment it is part of the log, and stays
        // out of the stream the runtime's refusals are read from.
        ContainerPart::Logs => vec![format!(
            "{} 2>&1",
            sbm_parser::container::logs_tail_command(ty, id.unwrap_or_default(), sbm_parser::container::LOG_TAIL)
        )],
    });
    let separator = format!("{SEPARATOR_PREFIX}_{}_{}", super::now_millis(), part.as_str());
    let text = sbm_parser::container::join_commands(&cmds, &separator);
    let text = sbm_parser::container::build_runtime_command(&text, ty, None, false);

    let Some(Ran { stdout, stderr, exit_code, .. }) = run_bounded(m, &text).await else {
        return Probe::Unreadable { ty, reason: Some("the command did not finish".to_owned()) };
    };
    let exit_code = exit_code.unwrap_or(-1);
    let reason = || sbm_parser::container::user_facing_output(&stderr, &stdout);

    // stderr only: the shell's "not found" is written there, and stdout
    // carries what the containers put in it.
    if sbm_parser::container::is_not_installed(ty, "", &stderr, exit_code) {
        return Probe::NotInstalled { reason: reason() };
    }
    // Checked before parsing: a client emulating another runtime answers every
    // command *successfully*.
    let ty = if sbm_parser::container::is_podman_emulation(&stderr) && ty == ContainerType::Docker {
        ContainerType::Podman
    } else {
        ty
    };
    if needs_permission(&stderr) {
        return Probe::PermissionDenied { ty, reason: reason() };
    }
    let segments = sbm_parser::container::split_segments(&stdout, &separator, Some(exit_code));
    // One segment per command. A count that does not match is not something to
    // guess at: attaching one command's output to another's name is worse than
    // saying so.
    if segments.len() != cmds.len() {
        return Probe::Unreadable { ty, reason: reason() };
    }
    // A read that failed is not an empty one. `version` and `stats` are
    // extras: the client's version and a sample the rows go on without.
    let optional = |i: usize| i == 0 || (part == ContainerPart::Containers && i == 2);
    if segments.iter().enumerate().any(|(i, s)| !optional(i) && s.exit_code != Some(0)) {
        return Probe::Unreadable { ty, reason: reason() };
    }
    Probe::Answered { ty, segments: segments.into_iter().map(|s| s.output).collect() }
}

/// Whether the runtime is there but would not talk to this account. Read from
/// stderr alone: stdout is the containers' own text, and a container that
/// printed "permission denied" is not a runtime refusing anyone.
fn needs_permission(stderr: &str) -> bool {
    let lower = stderr.to_lowercase();
    lower.contains("permission denied")
        || lower.contains("access denied")
        || lower.contains("got permission denied while trying to connect")
}

/// Turns one batch's answers into the response body.
fn finish(part: ContainerPart, probe: Probe) -> ContainerListResponse {
    let unavailable = |ty: Option<ContainerType>, kind: ContainerReason, reason: Option<String>| ContainerListResponse {
        part,
        available: false,
        reason_kind: Some(kind),
        reason,
        runtime: ty.map(|kind| RuntimeView { kind, version: None }),
        containers: Vec::new(),
        images: Vec::new(),
        unused_tagged: None,
        usage: None,
        logs: None,
    };
    let (ty, segments) = match probe {
        Probe::Answered { ty, segments } => (ty, segments),
        Probe::Unreadable { ty, reason } => return unavailable(Some(ty), ContainerReason::Unreadable, reason),
        Probe::PermissionDenied { ty, reason } => {
            return unavailable(Some(ty), ContainerReason::PermissionDenied, reason);
        }
        Probe::NotInstalled { reason } => return unavailable(None, ContainerReason::NotInstalled, reason),
    };

    let version = sbm_parser::container::parse_version(&segments[0]);
    let mut containers = Vec::new();
    let mut images = Vec::new();
    let mut unused_tagged = None;
    let mut usage = None;
    let mut logs = None;
    match part {
        ContainerPart::Containers => {
            let stats_rows = sbm_parser::container::parse_stats_rows(&segments[2]);
            containers = parse_ps(ty, &segments[1])
                .into_iter()
                .map(|container| ContainerRow {
                    stats: sbm_parser::container::find_stats_row(&stats_rows, container.id.as_deref())
                        .and_then(|raw| sbm_parser::container::parse_stats(ty, raw, version.as_deref())),
                    actions: sbm_parser::container::menu_items(container.status),
                    container,
                })
                .collect();
        }
        ContainerPart::Images => {
            let parsed = sbm_parser::container::parse_images(&segments[1], ty);
            let references: Vec<String> =
                parse_ps(ty, &segments[2]).into_iter().filter_map(|container| container.image).collect();
            unused_tagged = sbm_parser::container::count_unused_tagged_images(&parsed, &references);
            images = parsed
                .into_iter()
                .map(|image| ImageRow { dangling: image.is_dangling(), reference: image.reference(), image })
                .collect();
        }
        ContainerPart::Usage => usage = sbm_parser::container::parse_disk_usage(&segments[1]),
        // The runtime's own text, as it printed it.
        ContainerPart::Logs => logs = Some(segments[1].trim_matches('\n').to_owned()),
    }
    ContainerListResponse {
        part,
        available: true,
        reason_kind: None,
        reason: None,
        runtime: Some(RuntimeView { kind: ty, version }),
        containers,
        images,
        unused_tagged,
        usage,
        logs,
    }
}

/// `ps` in the dialect of the runtime that answered: Docker a tab-separated
/// table, Podman one JSON object per line.
fn parse_ps(ty: ContainerType, raw: &str) -> Vec<Container> {
    match ty {
        ContainerType::Docker => sbm_parser::container::parse_docker_ps(raw),
        ContainerType::Podman => sbm_parser::container::parse_podman_ps(raw),
    }
}

/// Which runtime this machine has, for a change.
///
/// `version` and nothing else: a change needs only to know what to prefix the
/// action with. A refusal to talk to this account is *not* a reason to try the
/// other runtime — the command asked for should fail with the machine's own
/// words about why.
pub async fn detect_runtime(m: &dyn Machine) -> Option<ContainerType> {
    if m.system() == SystemType::Windows {
        return None;
    }
    for ty in [ContainerType::Docker, ContainerType::Podman] {
        let text = sbm_parser::container::build_runtime_command(&ContainerCmd::Version.exec(ty), ty, None, false);
        let Some(output) = run_bounded(m, &text).await else {
            continue;
        };
        let exit_code = output.exit_code.unwrap_or(-1);
        if sbm_parser::container::is_not_installed(ty, &output.stdout, &output.stderr, exit_code)
            || (ty == ContainerType::Docker && sbm_parser::container::is_podman_emulation(&output.stderr))
        {
            continue;
        }
        return Some(ty);
    }
    None
}

/// Runs one command line. `None` for a timeout, an output past the cap or a
/// command that could not be run: there is nothing to parse either way.
async fn run_bounded(m: &dyn Machine, text: &str) -> Option<Ran> {
    match m.run(Run::Line(text), MAX_OUTPUT_BYTES).await {
        Ok(output) if !output.timed_out && !output.truncated => Some(output),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::super::fake::{Fake, failed, ok};
    use super::*;

    #[test]
    fn a_refusal_is_read_from_stderr_only() {
        assert!(needs_permission(
            "permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock"
        ));
        assert!(!needs_permission(""));
    }

    #[tokio::test]
    async fn no_runtime_is_answered_as_not_installed() {
        let m = Fake::new(SystemType::Linux, vec![("", failed("sh: docker: not found", 127))]);
        let answer = read(&m, ContainerPart::Containers, None, None).await;
        assert_eq!(answer.reason_kind, Some(ContainerReason::NotInstalled));
        assert_eq!(m.asked.lock().unwrap().len(), 2);
    }

    #[tokio::test]
    async fn an_invalid_action_is_refused_before_anything_runs() {
        let m = Fake::new(SystemType::Linux, vec![]);
        let action: ContainerAction = serde_json::from_value(serde_json::json!({ "action": "stop", "id": "-rf" })).unwrap();
        assert!(apply(&m, action).await.is_err());
        assert!(m.asked.lock().unwrap().is_empty());
        assert_eq!(m.audits.lock().unwrap().len(), 1);
    }

    #[tokio::test]
    async fn an_action_that_did_not_finish_has_an_unknown_outcome() {
        let m = Fake::new(
            SystemType::Linux,
            vec![
                (" stop ", Ran { timed_out: true, ..Default::default() }),
                ("version", ok("{}")),
            ],
        );
        let action: ContainerAction = serde_json::from_value(serde_json::json!({ "action": "stop", "id": "web" })).unwrap();
        let answer = apply(&m, action).await.unwrap();
        assert!(answer["outcome_unknown"].is_string(), "{answer}");
        assert_eq!(answer["exit_code"], Value::Null);
    }
}
