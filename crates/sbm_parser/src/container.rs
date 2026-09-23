//! Container runtimes — Docker and Podman — as a command line, a model and a set
//! of parsers.
//!
//! Pure like the rest of this crate: every function takes the text a runtime
//! printed and returns a value, or takes a description and returns a command.
//! Nothing here runs anything, so the app reaches it over SSH and the agent
//! reaches it over a local shell and both read one implementation.
//!
//! The two runtimes are one feature with two dialects rather than two features:
//! they share the verbs (`ps`, `stats`, `image ls`, `system df`, `stop`,
//! `prune`), and differ in what those verbs print. [`ContainerType`] is
//! therefore threaded through the command builders and the parsers, and the
//! model ([`Container`], [`ContainerImage`], [`DiskUsage`]) is what both
//! dialects reduce to.
//!
//! ## What is deliberately not here
//!
//! **Localised text.** The Dart implementation builds display strings such as
//! `↓ 1 MB / ↑ 2 MB` and `read 1 MB / write 2 MB` inside its parsers, which
//! welds a locale to the parse. This module returns the parts
//! ([`ContainerStats::net_down`] and friends) and leaves the sentence to the
//! client. Same for a status label: [`ContainerStatus`] is a case, not a word.
//!
//! **Privilege.** [`build_runtime_command`] can wrap a command in `sudo -S`,
//! but no password travels in it — `sudo -S` reads one from stdin, which is the
//! caller's business. Written into the command line it would reach the agent's
//! audit log and the machine's process list.
//!
//! **`docker compose`.** The app never runs a compose subcommand. Compose
//! appears only as two labels read off a container ([`Container::project`],
//! [`Container::working_dir`]) so the list can be grouped by stack.

use std::collections::HashSet;
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

/// Kept at this path because it was public here, and one argument-quoting rule
/// for the whole crate is the point — see [`crate::common::single_quote`].
pub use crate::common::single_quote;

/// The prefix of the marker line this module's caller echoes between batched
/// commands, so their outputs can be told apart.
///
/// The prefix and not the whole marker: the caller appends a timestamp and a
/// generation, and [`user_facing_output`] has to recognise every marker ever
/// written in order to drop one out of an error message.
pub const SEPARATOR_PREFIX: &str = "SrvBoxContainerSep";

/// `--format "{{json .}}"`, the one template every runtime answers in JSON.
const JSON_FORMAT: &str = "--format \"{{json .}}\"";

/// The Docker `ps` template, verbatim.
///
/// Raw so the two-character sequences reach the shell as written: `\t` is
/// Docker's own tab escape inside the format string, and `\"` is what lets a
/// label name sit inside the shell's double-quoted argument.
const DOCKER_PS_FORMAT: &str = r#"{{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}\t{{.Label \"com.docker.compose.project\"}}\t{{.Label \"com.docker.compose.project.working_dir\"}}\t{{.Ports}}"#;

/// `podman: not found`, which Podman's absence says instead of exit 127.
const PODMAN_NOT_FOUND: &str = "podman: not found";

/// Emitted on stderr when a `podman` binary is standing in for `docker`.
const PODMAN_EMULATION: &str = "Emulate Docker CLI using podman";

static DOCKER_NOT_FOUND: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"command not found|Unknown command|Command '\w+' not found").expect("valid regex")
});

static DOCKER_PUBLISHED_PORT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(?:.*:)?(\d+)->(\d+)(?:/\w+)?$").expect("valid regex"));

static DOCKER_EXPOSED_PORT: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^(\d+)(?:/\w+)?$").expect("valid regex"));

static HUMAN_SIZE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^([\d.]+)\s*([kKMGTP]?i?)B").expect("valid regex"));

static IMAGE_ID: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[a-fA-F0-9]{12,64}$").expect("valid regex"));

/// Which runtime's dialect a command or a parse is for.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ContainerType {
    Docker,
    Podman,
}

impl ContainerType {
    /// The executable's name, which is also the prefix of every command.
    pub fn name(self) -> &'static str {
        match self {
            Self::Docker => "docker",
            Self::Podman => "podman",
        }
    }

    /// The environment variable that points the client at a runtime socket.
    ///
    /// Different per runtime, and both are read by the client rather than by
    /// the daemon, which is why it is exported on the command line.
    fn host_var(self) -> &'static str {
        match self {
            Self::Docker => "DOCKER_HOST",
            Self::Podman => "CONTAINER_HOST",
        }
    }
}

/// One round trip to the runtime.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ContainerCmd {
    /// Asks the client its version. Answered `{"Client":{"Version":..}}`.
    Version,
    /// Every container, running or not.
    Ps,
    /// A one-shot sample of each running container's resource use.
    Stats,
    /// Every image, digests included.
    Images,
    /// How much space a prune would reclaim.
    Df,
}

impl ContainerCmd {
    pub fn exec(self, ty: ContainerType) -> String {
        let name = ty.name();
        match self {
            Self::Version => format!("{name} version {JSON_FORMAT}"),
            Self::Ps => match ty {
                ContainerType::Docker => format!("{name} ps -a --format \"{DOCKER_PS_FORMAT}\""),
                ContainerType::Podman => format!("{name} ps -a --format \"{{{{json .}}}}\\t{{{{.Status}}}}\""),
            },
            Self::Stats => format!("{name} stats --no-stream {JSON_FORMAT}"),
            Self::Images => format!("{name} image ls --digests {JSON_FORMAT}"),
            Self::Df => format!("{name} system df {JSON_FORMAT}"),
        }
    }

    /// Several commands as one, their outputs told apart by `separator`.
    ///
    /// Privilege is not this function's business: the caller wraps the result
    /// with [`build_runtime_command`], and a password reaches `sudo -S` on
    /// stdin.
    ///
    /// The separator is the caller's because it carries the caller's own
    /// freshness marker — a marker reused across refreshes would let an
    /// answer to the previous one be read as an answer to this one.
    pub fn exec_selected(cmds: &[Self], ty: ContainerType, separator: &str) -> String {
        let commands: Vec<String> = cmds.iter().map(|cmd| cmd.exec(ty)).collect();
        join_commands(&commands, separator)
    }
}

/// Several command lines as one shell invocation, told apart by `separator`.
///
/// The strings are joined rather than built from [`ContainerCmd`]s because one
/// command this module builds is not one of them: a log read is about a
/// container, so it carries an id, and [`ContainerCmd`] is `Copy` precisely
/// because every one of its cases is the same for every machine.
///
/// The separator is written *between* the commands, so N commands produce N
/// segments when the answer is split — not N+1, and not a leading marker that
/// someone has to remember to skip.
pub fn join_commands(commands: &[String], separator: &str) -> String {
    let joined = commands.join(&format!("\necho {separator}\n"));
    format!("sh -c '{}'", joined.replace('\'', "'\\''"))
}

/// Split a batched answer back into one segment per command.
///
/// A segment count that does not match the command count is the caller's to
/// refuse: a short answer cannot be matched to commands safely, and guessing
/// which one is missing would attach one command's output to another's name.
pub fn split_segments(raw: &str, separator: &str) -> Vec<String> {
    raw.split(separator).map(str::to_string).collect()
}

/// What the shell said when the runtime is not installed.
pub fn is_not_installed(ty: ContainerType, stdout: &str, stderr: &str, exit_code: i32) -> bool {
    if exit_code == 127 {
        return true;
    }
    if DOCKER_NOT_FOUND.is_match(stderr) || DOCKER_NOT_FOUND.is_match(stdout) {
        return true;
    }
    ty == ContainerType::Podman
        && (stderr.contains(PODMAN_NOT_FOUND) || stdout.contains(PODMAN_NOT_FOUND))
}

/// Whether the `docker` that answered is a `podman` wearing its name.
///
/// Read off stderr alone, and checked before parsing rather than after: a
/// client emulating Docker answers every command successfully, so nothing
/// downstream would notice, and every container would be reported by a runtime
/// the user did not pick.
pub fn is_podman_emulation(stderr: &str) -> bool {
    stderr.contains(PODMAN_EMULATION)
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

/// The command line for one runtime call, with the runtime's environment.
///
/// The runtime host travels as an environment variable rather than a flag
/// because that is how both clients read it, and under `sudo` it travels
/// through `env` rather than as an `export` — a `sudo -S export …` sets the
/// variable in the shell that is about to be replaced.
pub fn build_runtime_command(
    command: &str,
    ty: ContainerType,
    container_host: Option<&str>,
    sudo: bool,
) -> String {
    let mut environment = vec!["LANG=en_US.UTF-8".to_string()];
    if let Some(host) = container_host.filter(|host| !host.is_empty()) {
        environment.push(format!("{}={}", ty.host_var(), single_quote(host)));
    }
    if sudo {
        return format!("sudo -S env {} {command}", environment.join(" "));
    }
    let exports = environment
        .iter()
        .map(|value| format!("export {value}"))
        .collect::<Vec<_>>()
        .join(" && ");
    format!("{exports} && {command}")
}

/// `docker run`, with every user-typed part quoted.
pub fn build_run_cmd(image: &str, name: &str, extra_args: &[String]) -> String {
    let image_arg = single_quote(image);
    let args = extra_args
        .iter()
        .map(|arg| single_quote(arg))
        .collect::<Vec<_>>()
        .join(" ");
    let suffix = if args.is_empty() {
        image_arg
    } else {
        format!("{args} {image_arg}")
    };
    let name_arg = if name.is_empty() {
        String::new()
    } else {
        format!(" --name {}", single_quote(name))
    };
    format!("run -itd{name_arg} {suffix}")
}

/// Split a `docker run` argument list into argv, the way a shell would.
///
/// A shell rather than a `split_whitespace`, because the value of `-e` is
/// routinely a sentence with spaces in it and `-v` routinely has a path with
/// one. The quoting rules are the shell's, so what comes back is what the
/// shell would have handed the command — and what [`build_run_cmd`] then
/// quotes again for the remote shell.
///
/// Note that this is the *parsing* half of a shell, never the evaluating half:
/// `$(…)`, `;` and `|` come back as ordinary characters and become ordinary
/// arguments, which is what keeps a pasted `; touch /tmp/x` inert.
pub fn parse_run_args(raw: &str) -> Result<Vec<String>, RunArgsError> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut quote: Option<char> = None;
    let mut escaping = false;
    let mut escaping_in_double = false;
    let mut token_started = false;

    let mut finish_token = |current: &mut String, token_started: &mut bool| {
        if !*token_started {
            return;
        }
        args.push(std::mem::take(current));
        *token_started = false;
    };

    for ch in raw.chars() {
        if escaping {
            // A backslash inside double quotes is only an escape before a
            // character the shell would otherwise give a meaning to; before
            // anything else it is itself, which is why `"C:\work"` keeps its
            // backslash and `"\ "` does not.
            if escaping_in_double && !matches!(ch, '$' | '`' | '"' | '\\' | '\n') {
                current.push('\\');
            }
            if ch != '\n' || !escaping_in_double {
                current.push(ch);
            }
            token_started = true;
            escaping = false;
            escaping_in_double = false;
            continue;
        }
        if let Some(active) = quote {
            if ch == active {
                quote = None;
            } else if ch == '\\' && active == '"' {
                escaping = true;
                escaping_in_double = true;
            } else {
                current.push(ch);
            }
            token_started = true;
            continue;
        }
        if ch == '\'' || ch == '"' {
            quote = Some(ch);
            token_started = true;
        } else if ch == '\\' {
            escaping = true;
            token_started = true;
        } else if ch.is_whitespace() {
            finish_token(&mut current, &mut token_started);
        } else {
            current.push(ch);
            token_started = true;
        }
    }
    if quote.is_some() || escaping {
        return Err(RunArgsError::UnterminatedQuote);
    }
    finish_token(&mut current, &mut token_started);
    Ok(args)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RunArgsError {
    /// A quote or a trailing backslash with nothing to close it.
    UnterminatedQuote,
}

impl std::fmt::Display for RunArgsError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnterminatedQuote => f.write_str("Unterminated quoted container argument"),
        }
    }
}

impl std::error::Error for RunArgsError {}

/// A non-interactive image prune.
///
/// Without `all_unused` only dangling images go. `-f` is always there because
/// the confirmation cannot be answered through a remote execution.
pub fn build_image_prune_cmd(all_unused: bool) -> String {
    let flags = if all_unused { "-a -f" } else { "-f" };
    format!("image prune {flags}")
}

/// A non-interactive system prune with an explicit scope.
pub fn build_system_prune_cmd(all_unused_images: bool, include_volumes: bool) -> String {
    let mut flags = Vec::new();
    if all_unused_images {
        flags.push("-a");
    }
    if include_volumes {
        flags.push("--volumes");
    }
    flags.push("-f");
    format!("system prune {}", flags.join(" "))
}

/// Something to *do* to a container, as opposed to read off one.
///
/// The container is carried in the variant rather than passed beside it,
/// because the two terminal actions and the two prunes are the same
/// enumeration in `ContainerMenu.items` and a caller that had to know which
/// ones take an id would be re-deriving that split at every call site.
///
/// Serialised as a tagged object (`{"action":"stop","id":"abc"}`) so the agent
/// can take one off the wire and the panel cannot send a variant this build
/// does not implement.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum ContainerAction {
    Start { id: String },
    Stop { id: String },
    Restart { id: String },
    /// Without `force` this refuses to remove a running container, which is
    /// what the runtime does and what the user is being asked about.
    Remove { id: String, force: bool },
    PruneContainers,
    PruneVolumes,
}

impl ContainerAction {
    /// The command line that performs it, with the runtime named.
    ///
    /// The id is quoted here rather than by the caller: it reaches this
    /// function from a container listing, which is to say from whatever a
    /// container's name happens to be, and a name is a string that can be
    /// made to contain a shell.
    pub fn exec(&self, ty: ContainerType) -> String {
        let name = ty.name();
        match self {
            Self::Start { id } => format!("{name} start {}", single_quote(id)),
            Self::Stop { id } => format!("{name} stop {}", single_quote(id)),
            Self::Restart { id } => format!("{name} restart {}", single_quote(id)),
            Self::Remove { id, force } => {
                let flag = if *force { " -f" } else { "" };
                format!("{name} rm{flag} {}", single_quote(id))
            }
            Self::PruneContainers => format!("{name} container prune -f"),
            Self::PruneVolumes => format!("{name} volume prune -f"),
        }
    }
}

/// The lifecycle actions a container in this state is offered.
///
/// Mirrors `ContainerMenu.items`. The rule worth keeping in one place is that
/// an unrecognised state is grouped with a stopped one — `unknown` is not
/// evidence that nothing is running, and a Start offered for a container that
/// is already up is a no-op the user has to undo — and that `logs` is offered
/// in every state, since a container that will not start is exactly the one
/// whose logs are wanted.
pub fn menu_items(status: ContainerStatus) -> Vec<ContainerActionKind> {
    use ContainerActionKind::{Logs, Remove, Restart, Start, Stop, Terminal};
    if status.is_running() {
        return vec![Stop, Restart, Remove, Logs, Terminal];
    }
    if status.is_stopped() || status == ContainerStatus::Unknown {
        return vec![Start, Remove, Logs];
    }
    // Paused, restarting, removing, dead: the runtime is already moving it, so
    // only the two that are always safe are offered. A shell is left out with
    // the rest — `exec` against a container that is restarting is a coin flip.
    vec![Remove, Logs]
}

/// Which action, without which container — what [`menu_items`] answers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ContainerActionKind {
    Start,
    Stop,
    Restart,
    Remove,
    Logs,
    Terminal,
}

/// Follow a container's output in a terminal.
///
/// `-f` because a log view that does not follow is a snapshot of something
/// that is still happening; `--tail 100` so opening it on a container that has
/// been up for a year does not send a year of lines.
pub fn logs_command(ty: ContainerType, id: &str) -> String {
    format!(
        "{} logs -f --tail {} {}",
        ty.name(),
        LOG_TAIL,
        single_quote(id)
    )
}

/// The last [`LOG_TAIL`] lines of a container's log, as one bounded read.
///
/// Not [`logs_command`] without its `-f`: a caller that asked for a stream
/// holds a connection open for as long as the container writes, and one that
/// asked for this holds it for as long as the runtime takes to print. The count
/// is a `u32` rather than text so it cannot carry a shell metacharacter, and the
/// id goes through [`single_quote`] like every other caller-supplied value.
pub fn logs_tail_command(ty: ContainerType, id: &str, tail: u32) -> String {
    format!(
        "{} logs --tail {} {}",
        ty.name(),
        tail,
        single_quote(id)
    )
}

/// How many log lines a bounded read asks for. Long enough to cover a container
/// that failed at startup, short enough to fit one request's response.
pub const LOG_TAIL: u32 = 100;

/// Open a shell inside a container.
///
/// The shell is chosen on the machine rather than asked for here: a container
/// built from `alpine` or `busybox` has no bash, and one built from anything
/// else usually has no ash, so the command tries them in order and falls back
/// to `sh`, which POSIX requires.
pub fn shell_command(ty: ContainerType, id: &str) -> String {
    format!(
        "{} exec -it {} sh -c \"command -v bash && exec bash || command -v ash && exec ash || exec sh\"",
        ty.name(),
        single_quote(id)
    )
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

/// A normalised container state, from either runtime's own words.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ContainerStatus {
    Running,
    Exited,
    Created,
    Paused,
    Restarting,
    Removing,
    Dead,
    Unknown,
}

impl ContainerStatus {
    pub fn is_running(self) -> bool {
        self == Self::Running
    }

    /// Whether nothing is going to happen until someone starts it again.
    ///
    /// `unknown` is not stopped: a state this build does not recognise is not
    /// evidence that the container is down, and offering Start for a running
    /// container is a no-op the user has to undo.
    pub fn is_stopped(self) -> bool {
        matches!(self, Self::Exited | Self::Created | Self::Dead)
    }

    /// Read Docker's `STATUS` column, or Podman's equivalent text.
    ///
    /// The order of the tests is the whole of it: Docker writes
    /// `Up 5 minutes (Paused)`, which contains both "up" and "paused", and
    /// `Exited (0) 5 minutes ago`, which contains neither "up" nor "running".
    /// Matching "up" first would call a paused container running.
    pub fn from_text(state: Option<&str>) -> Self {
        let Some(state) = state.map(str::trim).filter(|state| !state.is_empty()) else {
            return Self::Unknown;
        };
        let lower = state.to_lowercase();
        // "removal in progress" is not a superset of "removing" — Docker
        // spells one of the two and the other is what a client reading its
        // own list sees.
        if lower.contains("exited") {
            return Self::Exited;
        }
        if lower.contains("created") {
            return Self::Created;
        }
        if lower.contains("paused") {
            return Self::Paused;
        }
        if lower.contains("restarting") {
            return Self::Restarting;
        }
        if lower.contains("removing") || lower.contains("removal in progress") {
            return Self::Removing;
        }
        if lower.contains("dead") {
            return Self::Dead;
        }
        if lower == "running" || lower.starts_with("up") {
            return Self::Running;
        }
        Self::Unknown
    }

    /// Podman's text, falling back to its legacy `exited` boolean.
    ///
    /// The text leads because the boolean cannot express `paused`: a paused
    /// container has not exited, so the flag says it is running.
    pub fn from_podman(exited: Option<bool>, raw_status: Option<&str>) -> Self {
        let parsed = Self::from_text(raw_status);
        if parsed != Self::Unknown {
            return parsed;
        }
        match exited {
            Some(true) => Self::Exited,
            Some(false) => Self::Running,
            None => Self::Unknown,
        }
    }
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// One container, from either runtime.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Container {
    pub id: Option<String>,
    pub name: Option<String>,
    pub image: Option<String>,
    /// The compose project this container belongs to, when it was started by
    /// one. Also the key the list is grouped by.
    pub project: Option<String>,
    /// The compose project's directory on the host.
    ///
    /// Parsed but not drawn: nothing in either client shows it, and it is here
    /// because the row that carries it carries nothing else this struct wants,
    /// so dropping it would mean a second parse of the same line later. TODO:
    /// give it a reader or drop it with the row that reads it.
    pub working_dir: Option<String>,
    /// Published ports condensed to `host→container`; `None` when none.
    pub ports: Option<String>,
    /// The runtime's own lifecycle text, verbatim.
    pub raw_status: Option<String>,
    pub status: ContainerStatus,
}

impl Container {
    /// Whether this container's image reference matches the image's own.
    ///
    /// `docker ps` prints the reference the container was created from, which
    /// is not always a tag — a container started from an id carries the id.
    /// Only used to confirm usage, never to deny it.
    pub fn image_reference(&self) -> Option<&str> {
        self.image.as_deref()
    }
}

/// One sample of a running container's resource use.
///
/// Every field is the runtime's own rendering of a quantity, kept as text
/// because both runtimes print two quantities in one field (`1.2MiB / 7.6GiB`)
/// and neither is a number this side can recompute. The pair is split so the
/// client can lay it out; nothing here is a sentence, so nothing here has a
/// locale.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
pub struct ContainerStats {
    /// `0.15%`.
    pub cpu: Option<String>,
    /// Podman's average over the sample window, `0.5%`. Docker reports none.
    pub cpu_avg: Option<String>,
    /// `1.2MiB / 7.6GiB`.
    pub mem: Option<String>,
    pub net_down: Option<String>,
    pub net_up: Option<String>,
    pub disk_read: Option<String>,
    pub disk_write: Option<String>,
}

/// One image, from either runtime.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ContainerImage {
    /// Always present: a runtime that names no repository has `<none>`.
    pub repository: String,
    pub tag: Option<String>,
    pub id: Option<String>,
    pub digest: Option<String>,
    /// The runtime's own size string, or one derived from the byte count
    /// Podman reports instead.
    pub size: Option<String>,
    /// How many containers use this image.
    ///
    /// `None` is *unknown*, never zero: some Docker versions answer `N/A`, and
    /// reading that as zero is how a prune dialog comes to offer an image that
    /// is in use. See [`count_unused_tagged_images`].
    pub containers: Option<i64>,
    /// The runtime's own creation text, passed through unparsed: Docker's
    /// `CreatedAt` is an absolute timestamp on current versions and relative
    /// text (`2 weeks ago`) on older ones, and Podman prints the relative form.
    pub created_at: Option<String>,
    /// Podman's creation time in Unix seconds.
    pub created: Option<i64>,
}

impl ContainerImage {
    /// Whether the image has no name to lose — `<none>:<none>`.
    pub fn is_dangling(&self) -> bool {
        let repository = self.repository.trim();
        let tag = self.tag.as_deref().unwrap_or("").trim();
        repository.is_empty()
            || repository == "<none>"
            || tag.is_empty()
            || tag == "<none>"
    }

    /// Whether this image is known to have nothing referencing it.
    pub fn is_unused(&self) -> bool {
        if self.is_dangling() {
            return true;
        }
        self.containers == Some(0)
    }
}

/// How much space the runtime holds, and how much a prune would give back.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct DiskUsage {
    /// Total images, active and dangling alike. `None` when the runtime did not
    /// report an `Images` row.
    pub image_count: Option<i64>,
    /// Summed over every type the runtime reported — images, stopped
    /// containers, unused volumes, build cache — because that is what the
    /// prune actions between them reclaim.
    pub reclaimable_bytes: Option<i64>,
}

// ---------------------------------------------------------------------------
// Parsers — Docker
// ---------------------------------------------------------------------------

/// Docker's `ps` table, one container per line.
///
/// The header is dropped by name rather than by position, and rows that do not
/// parse are skipped: a container this build cannot read is not a reason to
/// show an empty list.
pub fn parse_docker_ps(raw: &str) -> Vec<Container> {
    let mut lines: Vec<&str> = raw.split('\n').collect();
    if let Some(index) = lines
        .iter()
        .position(|line| line.trim_start().starts_with("CONTAINER ID"))
    {
        lines.remove(index);
    }
    lines
        .into_iter()
        .filter(|line| !line.is_empty())
        .filter_map(|line| parse_docker_ps_row(line).ok())
        .collect()
}

/// One row of Docker's `ps` table.
///
/// `CONTAINER ID\tSTATUS\tNAMES\tIMAGE\tPROJECT\tWORKING_DIR\tPORTS`
///
/// Read by position, and every field past the fourth is optional: a build
/// whose format string was shorter still prints a row this understands.
pub fn parse_docker_ps_row(raw: &str) -> Result<Container, ContainerParseError> {
    let parts: Vec<&str> = raw.split('\t').collect();
    if parts.len() < 4 {
        return Err(ContainerParseError::TooFewFields(parts.len()));
    }
    let non_empty = |value: &str| {
        let trimmed = value.trim();
        (!trimmed.is_empty()).then(|| trimmed.to_string())
    };
    let raw_status = non_empty(parts[1]);
    Ok(Container {
        id: non_empty(parts[0]),
        name: non_empty(parts[2]),
        image: non_empty(parts[3]),
        project: parts.get(4).and_then(|value| non_empty(value)),
        working_dir: parts.get(5).and_then(|value| non_empty(value)),
        ports: parts.get(6).and_then(|value| format_docker_ports(value)),
        status: ContainerStatus::from_text(raw_status.as_deref()),
        raw_status,
    })
}

/// Docker's `stats`, one JSON object per line.
///
/// Matching a stats row to a container is by id, with a shared ≥12-character
/// prefix allowed: Docker truncates the id in some of its own output, and the
/// prefix is long enough that two containers agreeing on it is a collision the
/// runtime's own id space makes impossible.
pub fn parse_stats_rows(raw: &str) -> Vec<(String, String)> {
    raw.split('\n')
        .filter(|row| !row.trim().is_empty())
        .filter_map(|row| {
            let value: serde_json::Value = serde_json::from_str(row).ok()?;
            let id = value
                .get("ID")
                .or_else(|| value.get("Id"))
                .or_else(|| value.get("ContainerID"))?
                .as_str()?
                .trim()
                .to_string();
            (!id.is_empty()).then(|| (id, row.to_string()))
        })
        .collect()
}

/// The stats row for a container, if one was reported.
pub fn find_stats_row<'a>(rows: &'a [(String, String)], container_id: Option<&str>) -> Option<&'a str> {
    let id = container_id.map(str::trim).filter(|id| !id.is_empty())?;
    rows.iter()
        .find(|(row_id, _)| {
            let prefix_match = id.len() >= 12
                && row_id.len() >= 12
                && (id.starts_with(row_id.as_str()) || row_id.starts_with(id));
            id == row_id || prefix_match
        })
        .map(|(_, raw)| raw.as_str())
}

/// Fill a container's stats from its runtime's own fields.
pub fn parse_stats(ty: ContainerType, raw: &str, version: Option<&str>) -> Option<ContainerStats> {
    let value: serde_json::Value = serde_json::from_str(raw).ok()?;
    match ty {
        ContainerType::Docker => Some(parse_docker_stats(&value)),
        ContainerType::Podman => Some(parse_podman_stats(&value, version)),
    }
}

fn parse_docker_stats(value: &serde_json::Value) -> ContainerStats {
    let text = |key: &str| value.get(key).and_then(|v| v.as_str()).map(str::to_string);
    // Both IO fields are one string holding two quantities, and a runtime
    // that reported neither still reports the field as `0B / 0B` — so the
    // default applies to the whole field, not to a missing half.
    let pair = |key: &str| {
        let raw = text(key).unwrap_or_else(|| "0B / 0B".to_string());
        let mut parts = raw.split(" / ");
        let first = parts.next().unwrap_or("0B").to_string();
        let second = parts.next().unwrap_or("0B").to_string();
        (first, second)
    };
    let (net_down, net_up) = pair("NetIO");
    let (disk_read, disk_write) = pair("BlockIO");
    ContainerStats {
        cpu: text("CPUPerc"),
        cpu_avg: None,
        mem: text("MemUsage"),
        net_down: Some(net_down),
        net_up: Some(net_up),
        disk_read: Some(disk_read),
        disk_write: Some(disk_write),
    }
}

fn parse_podman_stats(value: &serde_json::Value, version: Option<&str>) -> ContainerStats {
    let number = |key: &str| value.get(key).map(as_f64).unwrap_or(0.0);
    let bytes = |key: &str| value.get(key).map(as_i64).unwrap_or(0);

    let mem_usage = human_bytes(bytes("MemUsage"));
    let mem_limit = human_bytes(bytes("MemLimit"));

    // Podman 4 and earlier report both counters at the top level; 5 moved to
    // one set per interface when it changed network backend. The version is
    // what tells them apart, and an unreadable version is read as the older
    // shape, which is also the shape 5 falls back to when no interface
    // carried a counter.
    let major = version
        .and_then(|version| version.split('.').next())
        .and_then(|major| major.parse::<i64>().ok());
    let (mut net_in, mut net_out) = (0i64, 0i64);
    let nested = match major {
        Some(major) if major >= 5 => value.get("Network").and_then(|v| v.as_object()),
        _ => None,
    };
    match nested {
        Some(interfaces) => {
            let mut saw_counter = false;
            for interface in interfaces.values() {
                let Some(interface) = interface.as_object() else {
                    continue;
                };
                saw_counter |= interface.contains_key("RxBytes") || interface.contains_key("TxBytes");
                net_in += interface.get("RxBytes").map(as_i64).unwrap_or(0);
                net_out += interface.get("TxBytes").map(as_i64).unwrap_or(0);
            }
            if !saw_counter {
                net_in = bytes("NetInput");
                net_out = bytes("NetOutput");
            }
        }
        None => {
            net_in = bytes("NetInput");
            net_out = bytes("NetOutput");
        }
    }

    ContainerStats {
        cpu: Some(format!("{}%", fixed1(number("CPU")))),
        cpu_avg: Some(format!("{}%", fixed1(number("AvgCPU")))),
        mem: Some(format!("{mem_usage} / {mem_limit}")),
        net_down: Some(human_bytes(net_in)),
        net_up: Some(human_bytes(net_out)),
        disk_read: Some(human_bytes(bytes("BlockInput"))),
        disk_write: Some(human_bytes(bytes("BlockOutput"))),
    }
}

/// Docker's `image ls`, one JSON object per line — or one JSON array, or a
/// truncated array, both of which have been seen in the wild.
pub fn parse_images(raw: &str, ty: ContainerType) -> Vec<ContainerImage> {
    image_rows(raw)
        .into_iter()
        .filter(|row| !row.trim().is_empty())
        .filter_map(|row| {
            let value: serde_json::Value = serde_json::from_str(&row).ok()?;
            Some(match ty {
                ContainerType::Docker => parse_docker_image(&value),
                ContainerType::Podman => parse_podman_image(&value),
            })
        })
        .collect()
}

/// The rows of an image listing, however it was framed.
fn image_rows(raw: &str) -> Vec<String> {
    let trimmed = raw.trim();
    if !trimmed.starts_with('[') {
        return trimmed.split('\n').map(str::to_string).collect();
    }
    if let Ok(serde_json::Value::Array(rows)) = serde_json::from_str::<serde_json::Value>(trimmed) {
        return rows.into_iter().map(|row| row.to_string()).collect();
    }
    // An array that will not decode is one whose tail was cut off — by a
    // timeout, or by an output cap — so the objects that did arrive whole are
    // recovered rather than thrown away with the last one.
    complete_json_objects(trimmed)
}

/// Every complete `{…}` in a document, brace by brace, ignoring braces inside
/// strings.
fn complete_json_objects(raw: &str) -> Vec<String> {
    let mut rows = Vec::new();
    let mut start: Option<usize> = None;
    let mut depth = 0usize;
    let mut in_string = false;
    let mut escaping = false;
    for (index, ch) in raw.char_indices() {
        if in_string {
            if escaping {
                escaping = false;
            } else if ch == '\\' {
                escaping = true;
            } else if ch == '"' {
                in_string = false;
            }
            continue;
        }
        match ch {
            '"' => in_string = true,
            '{' => {
                if depth == 0 {
                    start = Some(index);
                }
                depth += 1;
            }
            '}' if depth > 0 => {
                depth -= 1;
                if depth == 0 && let Some(begin) = start.take() {
                    rows.push(raw[begin..=index].to_string());
                }
            }
            _ => {}
        }
    }
    rows
}

fn parse_docker_image(value: &serde_json::Value) -> ContainerImage {
    // `Repository` is what a tagged image is listed under, but a build that
    // could not name one prints an empty field and leaves the name in `Names`.
    let repository = non_empty_owned(as_text(value.get("Repository")))
        .or_else(|| non_empty_owned(as_text(value.get("Names"))))
        .unwrap_or_else(|| "<none>".to_string());
    ContainerImage {
        repository,
        tag: non_empty_owned(as_text(value.get("Tag"))),
        id: non_empty_owned(as_text(value.get("ID").or_else(|| value.get("Id")))),
        digest: non_empty_owned(as_text(value.get("Digest"))),
        size: match value.get("Size") {
            Some(serde_json::Value::String(size)) => Some(size.clone()),
            // A byte count rather than a rendered string: rendered here so the
            // client has one shape to read.
            Some(serde_json::Value::Number(number)) => {
                Some(human_bytes(number.as_i64().unwrap_or(0)))
            }
            _ => None,
        },
        containers: value.get("Containers").and_then(as_container_count),
        created_at: non_empty_owned(as_text(value.get("CreatedAt"))),
        created: None,
    }
}

fn parse_podman_image(value: &serde_json::Value) -> ContainerImage {
    // Podman 5 answers `Names: ["docker.io/library/nginx:latest"]` and 4
    // answered `repository`/`tag` separately, so the reference is split when
    // the named fields are absent.
    let named = non_empty_owned(as_text(value.get("Names")));
    let split = named.as_deref().map(split_image_reference);
    let repository = [
        non_empty_owned(as_text(value.get("repository"))),
        non_empty_owned(as_text(value.get("Repository"))),
        split.as_ref().and_then(|(repository, _)| repository.clone()),
    ]
    .into_iter()
    .flatten()
    .next()
    .unwrap_or_else(|| "<none>".to_string());
    let tag = [
        non_empty_owned(as_text(value.get("tag"))),
        non_empty_owned(as_text(value.get("Tag"))),
        split.and_then(|(_, tag)| tag),
    ]
    .into_iter()
    .flatten()
    .next();
    ContainerImage {
        repository,
        tag,
        id: non_empty_owned(as_text(value.get("Id").or_else(|| value.get("ID")))),
        digest: non_empty_owned(as_text(value.get("Digest").or_else(|| value.get("digest")))),
        size: value
            .get("Size")
            .filter(|size| !size.is_null())
            .map(|size| human_bytes(as_i64(size))),
        containers: value.get("Containers").map(as_i64),
        created_at: None,
        created: value.get("Created").map(as_i64),
    }
}

/// `redis:7` → `("redis", Some("7"))`, and `registry:5000/api` → the whole
/// thing as repository because the colon belongs to the port.
fn split_image_reference(raw: &str) -> (Option<String>, Option<String>) {
    let last_slash = raw.rfind('/');
    let last_colon = raw.rfind(':');
    match (last_slash, last_colon) {
        (slash, Some(colon)) if slash.is_none_or(|slash| colon > slash) => (
            non_empty_owned(Some(raw[..colon].to_string())),
            non_empty_owned(Some(raw[colon + 1..].to_string())),
        ),
        _ => (non_empty_owned(Some(raw.to_string())), None),
    }
}

/// Docker answers `"N/A"` where Podman answers a number, and `N/A` is
/// *unknown* — a prune dialog that read it as zero would offer an image that
/// is in use.
fn as_container_count(value: &serde_json::Value) -> Option<i64> {
    match value {
        serde_json::Value::Number(number) => number.as_i64(),
        serde_json::Value::String(text) => text.trim().parse().ok(),
        _ => None,
    }
}

/// Count the tagged images known to have nothing referencing them.
///
/// `None` when at least one tagged image's usage could not be confirmed: an
/// unknown rendered as a number is a count that is wrong by however many are
/// in use, and the number is what a prune dialog decides on. Confirming one
/// means matching its reference against the container list, which is why the
/// list is an argument.
pub fn count_unused_tagged_images(
    images: &[ContainerImage],
    container_image_refs: &[String],
) -> Option<i64> {
    let used = reference_markers(container_image_refs.iter().map(String::as_str));
    let mut unused = 0i64;
    let mut has_unknown = false;
    for image in images {
        if image.is_dangling() {
            continue;
        }
        match image.containers {
            Some(0) => unused += 1,
            Some(_) => {}
            None => {
                if !image_markers(image).iter().any(|marker| used.contains(marker)) {
                    has_unknown = true;
                }
            }
        }
    }
    (!has_unknown).then_some(unused)
}

/// The set of names an image answers to, so a container's reference can be
/// matched against it without either side having to be canonical.
fn image_markers(image: &ContainerImage) -> HashSet<String> {
    let mut markers = HashSet::new();
    add_image_id(&mut markers, image.id.as_deref());
    let repository = image.repository.trim();
    if repository.is_empty() || repository == "<none>" {
        return markers;
    }
    let tag = image.tag.as_deref().map(str::trim);
    let tag = tag.filter(|tag| !tag.is_empty() && *tag != "<none>");
    add_repository_markers(&mut markers, repository, tag);
    add_digest_markers(&mut markers, repository, image.digest.as_deref());
    markers
}

fn reference_markers<'a>(references: impl Iterator<Item = &'a str>) -> HashSet<String> {
    let mut markers = HashSet::new();
    for reference in references {
        add_reference_markers(&mut markers, reference);
    }
    markers
}

/// A container's image reference — a tag, an id, or a digest-pinned name.
fn add_reference_markers(markers: &mut HashSet<String>, raw: &str) {
    let value = raw.trim();
    if value.is_empty() {
        return;
    }
    if let Some(separator) = value.rfind('@').filter(|separator| *separator > 0) {
        let repository = value[..separator].trim();
        let digest = value[separator + 1..].trim();
        add_digest_markers(markers, repository, Some(digest));
        add_image_id(markers, Some(digest));
        return;
    }
    if value.starts_with("sha256:") {
        add_image_id(markers, Some(value));
        return;
    }
    // A bare hex string is a repository name here, not an id: `docker ps`
    // prints an id only with the `sha256:` prefix, and treating a 12-character
    // repository as an id would match an image that merely shares a prefix.
    let (repository, tag) = split_image_reference(value);
    if let Some(repository) = repository {
        add_repository_markers(markers, &repository, tag.as_deref());
    }
}

fn add_image_id(markers: &mut HashSet<String>, raw: Option<&str>) {
    let Some(value) = raw.map(str::trim).filter(|value| !value.is_empty()) else {
        return;
    };
    let bare = value.strip_prefix("sha256:").unwrap_or(value);
    if !IMAGE_ID.is_match(bare) {
        return;
    }
    markers.insert(format!("id:{bare}"));
    markers.insert(format!("id:{}", &bare[..12]));
}

fn add_digest_markers(markers: &mut HashSet<String>, repository: &str, raw_digest: Option<&str>) {
    let Some(digest) = raw_digest
        .map(str::trim)
        .filter(|digest| !digest.is_empty() && *digest != "<none>")
    else {
        return;
    };
    for alias in repository_aliases(repository) {
        markers.insert(format!("digest:{alias}@{digest}"));
    }
}

fn add_repository_markers(markers: &mut HashSet<String>, repository: &str, tag: Option<&str>) {
    let effective = tag.filter(|tag| !tag.is_empty()).unwrap_or("latest");
    for alias in repository_aliases(repository) {
        markers.insert(format!("ref:{alias}:{effective}"));
        if effective == "latest" {
            // An untagged reference and a `:latest` one are the same image,
            // and one side is often written without the tag.
            markers.insert(format!("ref:{alias}"));
        }
    }
}

/// A repository and its short form, for `docker.io/library/nginx` marked
/// against a container that says `nginx`.
fn repository_aliases(repository: &str) -> Vec<&str> {
    const DOCKER_LIBRARY: &str = "docker.io/library/";
    let mut aliases = vec![repository];
    if let Some(short) = repository.strip_prefix(DOCKER_LIBRARY) {
        aliases.push(short);
    }
    aliases
}

/// `0.0.0.0:8080->80/tcp, :::8080->80/tcp` becomes `8080→80`.
///
/// Docker prints one entry per address family, so a single published port
/// arrives twice and a container with four of them overruns any row it is put
/// in. The bind address is dropped with them: it is almost always the
/// wildcard, and where it is not, the page that can act on it is the port
/// forward editor rather than this list.
///
/// An entry in a shape this does not recognise is kept verbatim rather than
/// dropped — being unable to condense it is not a reason to claim the
/// container publishes nothing.
pub fn format_docker_ports(raw: &str) -> Option<String> {
    let value = raw.trim();
    if value.is_empty() {
        return None;
    }
    let mut condensed: Vec<String> = Vec::new();
    for entry in value.split(',') {
        let part = entry.trim();
        if part.is_empty() {
            continue;
        }
        let condensed_entry = if let Some(captures) = DOCKER_PUBLISHED_PORT.captures(part) {
            format!("{}→{}", &captures[1], &captures[2])
        } else if let Some(captures) = DOCKER_EXPOSED_PORT.captures(part) {
            captures[1].to_string()
        } else {
            part.to_string()
        };
        if !condensed.contains(&condensed_entry) {
            condensed.push(condensed_entry);
        }
    }
    (!condensed.is_empty()).then(|| condensed.join(", "))
}

/// Podman answers `Ports` as structured entries rather than Docker's string.
pub fn format_podman_ports(raw: &serde_json::Value) -> Option<String> {
    let entries = raw.as_array()?;
    let mut condensed: Vec<String> = Vec::new();
    for entry in entries {
        let container_port = entry
            .get("container_port")
            .map(as_i64)
            .unwrap_or(0);
        if container_port == 0 {
            continue;
        }
        let host_port = entry.get("host_port").map(as_i64).unwrap_or(0);
        let rendered = if host_port == 0 {
            container_port.to_string()
        } else {
            format!("{host_port}→{container_port}")
        };
        if !condensed.contains(&rendered) {
            condensed.push(rendered);
        }
    }
    (!condensed.is_empty()).then(|| condensed.join(", "))
}

// ---------------------------------------------------------------------------
// Parsers — Podman
// ---------------------------------------------------------------------------

/// Podman's `ps`, whose rows are a JSON object each with the human-readable
/// status appended after a tab.
///
/// The tab is looked for from the right because the JSON carries no tab, and
/// the appended field is the only one that can contain one.
pub fn parse_podman_ps(raw: &str) -> Vec<Container> {
    raw.split('\n')
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| {
            let separator = line.rfind('\t');
            let (json_part, status_part) = match separator {
                Some(index) => (&line[..index], Some(&line[index + 1..])),
                None => (line, None),
            };
            let value: serde_json::Value = serde_json::from_str(json_part.trim()).ok()?;
            let value = value.as_object()?;
            Some(parse_podman_ps_row(value, status_part))
        })
        .collect()
}

fn parse_podman_ps_row(
    value: &serde_json::Map<String, serde_json::Value>,
    appended_status: Option<&str>,
) -> Container {
    let text = |key: &str| non_empty_owned(as_text(value.get(key)));
    // The human-readable status is what carries `(Paused)` and `(Unhealthy)`,
    // so the appended column wins over the JSON's own `Status`/`State`.
    let raw_status = non_empty_owned(appended_status.map(str::to_string))
        .or_else(|| text("ServerBoxStatus"))
        .or_else(|| text("Status"))
        .or_else(|| text("State"));
    let exited = value.get("Exited").and_then(|value| value.as_bool());
    let labels = value.get("Labels");
    let label = |key: &str| {
        labels
            .and_then(|labels| labels.get(key))
            .and_then(|label| label.as_str())
            .map(str::trim)
            .filter(|label| !label.is_empty())
            .map(str::to_string)
    };
    Container {
        id: text("Id"),
        name: value
            .get("Names")
            .and_then(|names| names.as_array())
            .and_then(|names| names.iter().find_map(|name| non_empty_owned(as_text(Some(name))))),
        image: text("Image"),
        project: label("com.docker.compose.project"),
        working_dir: label("com.docker.compose.project.working_dir"),
        ports: value.get("Ports").and_then(format_podman_ports),
        status: ContainerStatus::from_podman(exited, raw_status.as_deref()),
        raw_status,
    }
}

/// `docker system df`, as a container's worth of reclaimable space.
///
/// Fetched on its own rather than with `ps`/`stats`: on a host with many
/// images the command walks the whole image store, which is several hundred
/// milliseconds it would otherwise add to every poll.
///
/// Every field is a human-readable string on at least one of the two runtimes
/// (`"12"`, `"809MB (56%)"`), so nothing here assumes a number.
pub fn parse_disk_usage(raw: &str) -> Option<DiskUsage> {
    let rows = disk_usage_rows(raw);
    if rows.is_empty() {
        return None;
    }
    let mut image_count = None;
    let mut reclaimable = None;
    for row in &rows {
        let kind = row.get("Type").and_then(|value| value.as_str()).map(str::to_lowercase);
        if kind.as_deref() == Some("images") {
            image_count = row
                .get("TotalCount")
                .or_else(|| row.get("Total"))
                .and_then(as_container_count);
        }
        if let Some(bytes) = row
            .get("Reclaimable")
            .and_then(|value| value.as_str())
            .and_then(parse_human_bytes)
        {
            reclaimable = Some(reclaimable.unwrap_or(0) + bytes);
        }
    }
    let usage = DiskUsage {
        image_count,
        reclaimable_bytes: reclaimable,
    };
    (usage != DiskUsage { image_count: None, reclaimable_bytes: None }).then_some(usage)
}

fn disk_usage_rows(raw: &str) -> Vec<serde_json::Map<String, serde_json::Value>> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    // Podman answers one array; Docker answers one object per line.
    match serde_json::from_str::<serde_json::Value>(trimmed) {
        Ok(serde_json::Value::Array(rows)) => {
            return rows
                .into_iter()
                .filter_map(|row| row.as_object().cloned())
                .collect();
        }
        Ok(serde_json::Value::Object(row)) => return vec![row],
        _ => {}
    }
    trimmed
        .split('\n')
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| {
            serde_json::from_str::<serde_json::Value>(line.trim())
                .ok()?
                .as_object()
                .cloned()
        })
        .collect()
}

/// `809MB (56%)` → `809000000`. `None` for anything unparseable, which is how
/// a runtime that reported nothing stays distinguishable from one that
/// reported zero.
///
/// Both runtimes print decimal units (`kB`, `MB`) through Go's
/// `units.HumanSize`, so a plain unit is 1000-based and only the `i` forms are
/// 1024-based. Reading one as the other misreports reclaimable space by 7% per
/// order of magnitude.
pub fn parse_human_bytes(raw: &str) -> Option<i64> {
    let value = raw.trim();
    let captures = HUMAN_SIZE.captures(value)?;
    let amount: f64 = captures[1].parse().ok()?;
    let unit = captures.get(2).map(|unit| unit.as_str()).unwrap_or("");
    let base: f64 = if unit.ends_with('i') { 1024.0 } else { 1000.0 };
    let exponent = match unit.chars().next().map(|c| c.to_ascii_uppercase()) {
        Some('K') => 1,
        Some('M') => 2,
        Some('G') => 3,
        Some('T') => 4,
        Some('P') => 5,
        _ => 0,
    };
    Some((amount * base.powi(exponent)).round() as i64)
}

// ---------------------------------------------------------------------------
// Version and output
// ---------------------------------------------------------------------------

/// `docker version`'s answer: the client's own version.
///
/// The client's rather than the server's, because it is the client that reads
/// the socket and prints the fields this module parses.
pub fn parse_version(raw: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(raw.trim()).ok()?;
    value
        .get("Client")?
        .get("Version")?
        .as_str()
        .map(str::to_string)
}

/// What the machine said, for a user reading why a page is empty.
///
/// stderr first, since that is where a shell puts the reason. The markers the
/// caller echoes between its commands are dropped: they are scaffolding, and a
/// page whose whole explanation was `SrvBoxContainerSep_1786614816321254_0`
/// twice over told the user nothing. Identical lines are collapsed for the
/// same reason — three commands batched into one call say `sh: docker: not
/// found` three times, which is one problem, not three.
pub fn user_facing_output(stderr: &str, stdout: &str) -> Option<String> {
    for stream in [stderr, stdout] {
        let mut lines: Vec<&str> = Vec::new();
        let mut seen = HashSet::new();
        for line in stream.split('\n') {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with(SEPARATOR_PREFIX) {
                continue;
            }
            if !seen.insert(trimmed) {
                continue;
            }
            lines.push(trimmed);
        }
        if !lines.is_empty() {
            return Some(lines.join("\n"));
        }
    }
    None
}

// ---------------------------------------------------------------------------
// Small shared helpers
// ---------------------------------------------------------------------------

/// Human-readable byte count, e.g. `1.9 KB`.
///
/// Steps while the quotient is `>= 1`, not `> 1`: an exact power of 1024
/// divides to exactly 1, and a strict comparison stopped one unit short —
/// 1048576 rendered as `1024 KB`, and 1024 as `1024 B`. Kept equal to the
/// Dart `bytes2Str` this module ports, because the same number is drawn on the
/// same row by both clients.
fn human_bytes(bytes: i64) -> String {
    const SUFFIX: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut value = bytes as f64;
    let mut steps = 0;
    while value / 1024.0 >= 1.0 && steps < SUFFIX.len() - 1 {
        value /= 1024.0;
        steps += 1;
    }
    format!("{} {}", trim_trailing_zero(fixed1(value)), SUFFIX[steps])
}

/// One decimal place, rounded half away from zero — the convention Dart's
/// `toStringAsFixed` uses, which `format!`'s own rounding does not.
fn fixed1(value: f64) -> String {
    let rounded = (value * 10.0).round() / 10.0;
    format!("{rounded:.1}")
}

fn trim_trailing_zero(value: String) -> String {
    match value.strip_suffix(".0") {
        Some(trimmed) => trimmed.to_string(),
        None => value,
    }
}

fn as_text(value: Option<&serde_json::Value>) -> Option<String> {
    match value? {
        serde_json::Value::String(text) => Some(text.clone()),
        serde_json::Value::Null => None,
        // A list's first non-empty entry, and anything else stringified: a
        // runtime that answered a number here meant that number as the name.
        serde_json::Value::Array(entries) => entries
            .iter()
            .find_map(|entry| non_empty_owned(as_text(Some(entry)))),
        other => Some(other.to_string()),
    }
}

fn non_empty_owned(value: Option<String>) -> Option<String> {
    value
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

/// The numeric value of a JSON field, read leniently: Podman answers some
/// counters as numbers and others as strings of numbers.
fn as_i64(value: &serde_json::Value) -> i64 {
    match value {
        serde_json::Value::Number(number) => number.as_i64().unwrap_or(0),
        serde_json::Value::String(text) => text.trim().parse().unwrap_or(0),
        _ => 0,
    }
}

fn as_f64(value: &serde_json::Value) -> f64 {
    match value {
        serde_json::Value::Number(number) => number.as_f64().unwrap_or(0.0),
        serde_json::Value::String(text) => text.trim().parse().unwrap_or(0.0),
        _ => 0.0,
    }
}

/// Why one row could not be read.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContainerParseError {
    /// Fewer tab-separated fields than a row cannot do without.
    TooFewFields(usize),
}

impl std::fmt::Display for ContainerParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::TooFewFields(count) => write!(
                f,
                "Docker ps row has {count} fields, expected at least 4"
            ),
        }
    }
}

impl std::error::Error for ContainerParseError {}

#[cfg(test)]
mod tests {
    //! Ported from `test/unit/server/container_test.dart`.
    //!
    //! Every fixture here is the Dart suite's, byte for byte where it could be
    //! — a parse that agrees with itself proves nothing, and this module's
    //! whole claim is that it reads what the Dart one reads while the two
    //! implementations exist side by side.
    //!
    //! Two things are asserted differently, both deliberately:
    //!
    //! - The Dart parsers build display strings (`↓ 512 B / ↑ 256 B`) and
    //!   assert on those. This module returns the parts, so the assertions are
    //!   on [`ContainerStats::net_down`] and its neighbours, and the arrow the
    //!   client draws is the client's.
    //! - Cases the Dart suite expresses through a constructor
    //!   (`DockerPs(id: 'test', state: null)`) are expressed here through the
    //!   function that reads that field, since [`Container`] has no constructor
    //!   the parser does not go through.

    use super::*;
    use serde_json::json;

    // -----------------------------------------------------------------------
    // Quoting and command construction
    // -----------------------------------------------------------------------

    #[test]
    fn build_run_cmd_quotes_every_untrusted_argument() {
        assert_eq!(
            build_run_cmd(
                "safe; touch /tmp/image-pwned; #",
                "safe; touch /tmp/name-pwned; #",
                &parse_run_args("-p 8080:80").unwrap(),
            ),
            "run -itd --name 'safe; touch /tmp/name-pwned; #' \
             '-p' '8080:80' 'safe; touch /tmp/image-pwned; #'"
        );
    }

    #[test]
    fn parse_run_args_preserves_quoted_values() {
        assert_eq!(
            parse_run_args(r#"-e "GREETING=hello world" -v '/host path:/container path' '' "#)
                .unwrap(),
            vec!["-e", "GREETING=hello world", "-v", "/host path:/container path", ""]
        );
    }

    #[test]
    fn double_quotes_preserve_non_special_backslashes() {
        assert_eq!(
            parse_run_args(r#"--label "path=C:\work\data" "a\qb""#).unwrap(),
            vec!["--label", r"path=C:\work\data", r"a\qb"]
        );
    }

    #[test]
    fn double_quoted_backslash_newline_is_a_continuation() {
        assert_eq!(
            parse_run_args("--label \"hello\\\nworld\"").unwrap(),
            vec!["--label", "helloworld"]
        );
    }

    #[test]
    fn container_run_shell_operators_remain_quoted_arguments() {
        let cmd = build_run_cmd(
            "alpine",
            "",
            &parse_run_args(r"--label x=$(touch /tmp/pwned) ; echo owned").unwrap(),
        );
        assert_eq!(
            cmd,
            r"run -itd '--label' 'x=$(touch' '/tmp/pwned)' ';' 'echo' 'owned' 'alpine'"
        );
    }

    #[test]
    fn parse_run_args_rejects_unterminated_quoting() {
        assert_eq!(
            parse_run_args(r#"-e "unfinished"#),
            Err(RunArgsError::UnterminatedQuote)
        );
    }

    #[test]
    fn build_image_prune_cmd_keeps_remote_execution_non_interactive() {
        assert_eq!(build_image_prune_cmd(false), "image prune -f");
        assert_eq!(build_image_prune_cmd(true), "image prune -a -f");
    }

    #[test]
    fn build_system_prune_cmd_reflects_each_optional_scope() {
        assert_eq!(build_system_prune_cmd(false, false), "system prune -f");
        assert_eq!(build_system_prune_cmd(true, false), "system prune -a -f");
        assert_eq!(build_system_prune_cmd(false, true), "system prune --volumes -f");
        assert_eq!(
            build_system_prune_cmd(true, true),
            "system prune -a --volumes -f"
        );
    }

    #[test]
    fn sudo_runtime_command_keeps_the_remote_host_inside_sudo_env() {
        let command = build_runtime_command(
            "docker ps",
            ContainerType::Docker,
            Some("ssh://docker.example/run.sock"),
            true,
        );
        assert!(command.contains(
            "sudo -S env LANG=en_US.UTF-8 DOCKER_HOST='ssh://docker.example/run.sock' docker ps"
        ));
        assert!(!command.contains("export DOCKER_HOST"));
    }

    #[test]
    fn an_unprivileged_runtime_command_exports_its_environment() {
        assert_eq!(
            build_runtime_command("docker ps", ContainerType::Docker, None, false),
            "export LANG=en_US.UTF-8 && docker ps"
        );
        assert_eq!(
            build_runtime_command("podman ps", ContainerType::Podman, None, false),
            "export LANG=en_US.UTF-8 && podman ps"
        );
    }

    // -----------------------------------------------------------------------
    // The command line itself
    // -----------------------------------------------------------------------

    #[test]
    fn docker_ps_command_uses_human_readable_status_with_compose_project() {
        assert_eq!(
            ContainerCmd::Ps.exec(ContainerType::Docker),
            "docker ps -a --format \"{{.ID}}\\t{{.Status}}\\t{{.Names}}\\t{{.Image}}\\t\
             {{.Label \\\"com.docker.compose.project\\\"}}\\t\
             {{.Label \\\"com.docker.compose.project.working_dir\\\"}}\\t{{.Ports}}\""
        );
    }

    #[test]
    fn podman_ps_command_requests_detailed_human_readable_status() {
        assert_eq!(
            ContainerCmd::Ps.exec(ContainerType::Podman),
            "podman ps -a --format \"{{json .}}\\t{{.Status}}\""
        );
    }

    #[test]
    fn container_refresh_command_excludes_image_listing() {
        let cmd = ContainerCmd::exec_selected(
            &[ContainerCmd::Ps, ContainerCmd::Stats],
            ContainerType::Docker,
            "SrvBoxContainerSep_1_0",
        );
        assert!(cmd.contains("docker ps -a"));
        assert!(cmd.contains("docker stats --no-stream"));
        assert!(!cmd.contains("docker image ls"));
    }

    #[test]
    fn image_refresh_command_excludes_containers_and_stats() {
        let cmd = ContainerCmd::exec_selected(
            &[ContainerCmd::Images],
            ContainerType::Podman,
            "SrvBoxContainerSep_1_0",
        );
        assert!(cmd.contains("podman image ls"));
        assert!(cmd.contains("--digests"));
        assert!(!cmd.contains("podman ps -a"));
        assert!(!cmd.contains("podman stats"));
    }

    #[test]
    fn a_batched_command_is_split_back_on_its_own_separator() {
        let cmd = ContainerCmd::exec_selected(
            &[ContainerCmd::Ps, ContainerCmd::Stats],
            ContainerType::Docker,
            "SrvBoxContainerSep_1_0",
        );
        assert!(cmd.starts_with("sh -c '"));
        assert!(cmd.ends_with('\''));
        assert!(cmd.contains("\necho SrvBoxContainerSep_1_0\n"));
        // The separator is the caller's, so one refresh's answer cannot be
        // matched against another's commands.
        assert_eq!(
            split_segments("a\nSrvBoxContainerSep_1_0\nb", "SrvBoxContainerSep_1_0"),
            vec!["a\n", "\nb"]
        );
    }

    #[test]
    fn docker_version_is_read_from_the_client_that_printed_the_rest() {
        assert_eq!(
            parse_version(r#"{"Client":{"Version":"5.0.0"},"Server":{"Version":"27.0"}}"#),
            Some("5.0.0".to_string())
        );
        assert_eq!(parse_version("not json"), None);
    }

    #[test]
    fn each_runtime_is_recognised_as_missing_in_its_own_words() {
        assert!(is_not_installed(
            ContainerType::Docker,
            "",
            "sh: docker: not found",
            127
        ));
        assert!(is_not_installed(
            ContainerType::Docker,
            "Command 'docker' not found",
            "",
            1
        ));
        assert!(is_not_installed(
            ContainerType::Podman,
            "",
            "sh: podman: not found\npodman: not found",
            1
        ));
        assert!(!is_not_installed(
            ContainerType::Docker,
            "",
            "permission denied",
            1
        ));
        // Podman's phrase is not Docker's: a Docker that says it is missing.
        assert!(!is_not_installed(
            ContainerType::Podman,
            "",
            "sh: docker: not found",
            1
        ));
    }

    #[test]
    fn a_podman_wearing_dockers_name_is_recognised_before_parsing() {
        assert!(is_podman_emulation(
            "Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg."
        ));
        assert!(!is_podman_emulation(""));
    }

    // -----------------------------------------------------------------------
    // Docker ps
    // -----------------------------------------------------------------------

    #[test]
    fn docker_ps_parse() {
        let raw = "CONTAINER ID\tSTATUS\tNAMES\tIMAGE\n\
                   0e9e2ef860d2\tUp 2 hours\thbbs\trustdesk/rustdesk-server:latest\n\
                   9a4df3ed340c\tUp 41 minutes\thbbr\trustdesk/rustdesk-server:latest\n\
                   fa1215b4be74\tUp 12 hours\tfirefly\tuusec/firefly:latest\n";
        let ids = ["0e9e2ef860d2", "9a4df3ed340c", "fa1215b4be74"];
        let names = ["hbbs", "hbbr", "firefly"];
        let images = [
            "rustdesk/rustdesk-server:latest",
            "rustdesk/rustdesk-server:latest",
            "uusec/firefly:latest",
        ];
        let states = ["Up 2 hours", "Up 41 minutes", "Up 12 hours"];

        let parsed = parse_docker_ps(raw);
        assert_eq!(parsed.len(), 3);
        for (index, item) in parsed.iter().enumerate() {
            assert_eq!(item.id.as_deref(), Some(ids[index]));
            assert_eq!(item.name.as_deref(), Some(names[index]));
            assert_eq!(item.image.as_deref(), Some(images[index]));
            assert_eq!(item.raw_status.as_deref(), Some(states[index]));
            assert_eq!(item.status, ContainerStatus::Running);
            assert!(item.status.is_running());
        }
    }

    #[test]
    fn docker_ps_parse_extracts_compose_project_and_working_dir() {
        let item = parse_docker_ps_row("0e9e2ef860d2\tUp 2 hours\tcmp-web\tnginx:alpine\tnginx\t/opt/nginx")
            .unwrap();
        assert_eq!(item.project.as_deref(), Some("nginx"));
        assert_eq!(item.working_dir.as_deref(), Some("/opt/nginx"));
    }

    #[test]
    fn docker_ps_parse_handles_empty_compose_project_and_working_dir() {
        let item =
            parse_docker_ps_row("0e9e2ef860d2\tUp 2 hours\tcmp-standalone\talpine\t\t").unwrap();
        assert_eq!(item.project, None);
        assert_eq!(item.working_dir, None);
    }

    #[test]
    fn docker_ps_parse_stays_backward_compatible_without_project_field() {
        let item = parse_docker_ps_row("0e9e2ef860d2\tUp 2 hours\tcmp-standalone\talpine").unwrap();
        assert_eq!(item.project, None);
        assert_eq!(item.working_dir, None);
    }

    #[test]
    fn docker_ps_parse_handles_long_swarm_container_names() {
        let name = "apps-all-stack_komari-agent.zdngp1z1t23llz9l30s86tq3g.fjmkg9amn0u76tbln96mmzlq2";
        let image = "registry.example.com/team/komari-agent:2026.07.10";
        let item =
            parse_docker_ps_row(&format!("0e9e2ef860d2\tUp 2 hours\t{name}\t{image}")).unwrap();

        assert!(name.len() > 50);
        assert_eq!(item.id.as_deref(), Some("0e9e2ef860d2"));
        assert_eq!(item.raw_status.as_deref(), Some("Up 2 hours"));
        assert_eq!(item.name.as_deref(), Some(name));
        assert_eq!(item.image.as_deref(), Some(image));
    }

    #[test]
    fn docker_ps_parse_reports_malformed_rows() {
        let error = parse_docker_ps_row("0e9e2ef860d2\tUp 2 hours\thbbs").unwrap_err();
        let message = error.to_string();
        assert!(message.contains("Docker ps row"), "{message}");
        assert!(message.contains("expected at least 4"), "{message}");
    }

    #[test]
    fn docker_ps_status_detection() {
        let cases: [(Option<&str>, ContainerStatus); 14] = [
            (Some("Up 2 minutes"), ContainerStatus::Running),
            (Some("Up 1 hour"), ContainerStatus::Running),
            // Case insensitive.
            (Some("UP 30 seconds"), ContainerStatus::Running),
            (Some("up 5 days"), ContainerStatus::Running),
            (Some("Exited (0) 5 minutes ago"), ContainerStatus::Exited),
            (Some("Created"), ContainerStatus::Created),
            (Some("Paused"), ContainerStatus::Paused),
            (Some("Up 5 minutes (Paused)"), ContainerStatus::Paused),
            (Some("Restarting"), ContainerStatus::Restarting),
            (Some("Removing"), ContainerStatus::Removing),
            (Some("Removal In Progress"), ContainerStatus::Removing),
            (Some("Dead"), ContainerStatus::Dead),
            (None, ContainerStatus::Unknown),
            (Some("Some Unknown Status"), ContainerStatus::Unknown),
        ];
        for (state, expected) in cases {
            let status = ContainerStatus::from_text(state);
            assert_eq!(status, expected, "state {state:?}");
            assert_eq!(
                status.is_running(),
                expected.is_running(),
                "state {state:?} is_running"
            );
        }
        // The empty string is a state the runtime printed and this build did
        // not recognise, which is the same answer as a state it never got.
        assert_eq!(ContainerStatus::from_text(Some("")), ContainerStatus::Unknown);
    }

    #[test]
    fn podman_ps_status_detection() {
        let cases: [(Option<bool>, ContainerStatus); 3] = [
            (Some(false), ContainerStatus::Running),
            (Some(true), ContainerStatus::Exited),
            (None, ContainerStatus::Unknown),
        ];
        for (exited, expected) in cases {
            let status = ContainerStatus::from_podman(exited, None);
            assert_eq!(status, expected, "exited {exited:?}");
            assert_eq!(
                status.is_running(),
                expected.is_running(),
                "exited {exited:?} is_running"
            );
        }
    }

    #[test]
    fn container_status_utility_methods() {
        assert!(ContainerStatus::Running.is_running());
        assert!(!ContainerStatus::Exited.is_running());
        assert!(!ContainerStatus::Created.is_running());
        assert!(ContainerStatus::Exited.is_stopped());
        assert!(!ContainerStatus::Unknown.is_stopped());
    }

    #[test]
    fn container_menu_items_follow_the_state() {
        use ContainerActionKind::{Logs, Remove, Restart, Start, Stop, Terminal};
        assert_eq!(
            menu_items(ContainerStatus::Running),
            vec![Stop, Restart, Remove, Logs, Terminal]
        );
        assert_eq!(
            menu_items(ContainerStatus::Exited),
            vec![Start, Remove, Logs]
        );
        // `dead` is a removal that failed, which is a state to start again
        // from; the Dart groups it with stopped and this port keeps that.
        assert_eq!(
            menu_items(ContainerStatus::Dead),
            vec![Start, Remove, Logs]
        );
        // An unrecognised state is not evidence that nothing is running.
        assert_eq!(
            menu_items(ContainerStatus::Unknown),
            vec![Start, Remove, Logs]
        );
        // Paused, restarting and removing are the runtime's own business.
        for status in [
            ContainerStatus::Paused,
            ContainerStatus::Restarting,
            ContainerStatus::Removing,
        ] {
            assert_eq!(menu_items(status), vec![Remove, Logs], "state {status:?}");
        }
    }

    #[test]
    fn container_actions_name_the_runtime_and_quote_the_container() {
        let cases = [
            (
                ContainerAction::Start { id: "abc".into() },
                "docker start 'abc'",
            ),
            (
                ContainerAction::Stop { id: "abc".into() },
                "docker stop 'abc'",
            ),
            (
                ContainerAction::Restart { id: "abc".into() },
                "docker restart 'abc'",
            ),
            (
                ContainerAction::Remove {
                    id: "abc".into(),
                    force: false,
                },
                "docker rm 'abc'",
            ),
            (
                ContainerAction::Remove {
                    id: "abc".into(),
                    force: true,
                },
                "docker rm -f 'abc'",
            ),
            (ContainerAction::PruneContainers, "docker container prune -f"),
            (ContainerAction::PruneVolumes, "docker volume prune -f"),
        ];
        for (action, expected) in cases {
            assert_eq!(action.exec(ContainerType::Docker), expected);
        }
        assert_eq!(
            ContainerAction::Stop { id: "abc".into() }.exec(ContainerType::Podman),
            "podman stop 'abc'"
        );
    }

    #[test]
    fn a_container_identifier_cannot_escape_its_quoting() {
        // A container's name is not something this app chose.
        let action = ContainerAction::Stop {
            id: "abc'; touch /tmp/pwned; echo '".into(),
        };
        assert_eq!(
            action.exec(ContainerType::Docker),
            r#"docker stop 'abc'\''; touch /tmp/pwned; echo '\'''"#
        );
    }

    #[test]
    fn container_actions_round_trip_through_the_wire() {
        // The agent takes one of these off a request body, so the tag and the
        // field names are a contract rather than a detail.
        let action: ContainerAction =
            serde_json::from_str(r#"{"action":"remove","id":"abc","force":true}"#).unwrap();
        assert_eq!(
            action,
            ContainerAction::Remove {
                id: "abc".into(),
                force: true
            }
        );
        assert_eq!(
            serde_json::to_string(&ContainerAction::PruneVolumes).unwrap(),
            r#"{"action":"prune_volumes"}"#
        );
        // A variant this build does not implement is refused here rather than
        // reaching `exec`, which has no arm for it.
        assert!(serde_json::from_str::<ContainerAction>(r#"{"action":"pause","id":"abc"}"#).is_err());
    }

    #[test]
    fn a_terminal_command_follows_output_and_finds_a_shell() {
        assert_eq!(
            logs_command(ContainerType::Docker, "abc"),
            "docker logs -f --tail 100 'abc'"
        );
        assert_eq!(
            shell_command(ContainerType::Podman, "abc"),
            "podman exec -it 'abc' sh -c \"command -v bash && exec bash || command -v ash && exec ash || exec sh\""
        );
    }

    #[test]
    fn a_bounded_log_read_does_not_follow() {
        // The difference from `logs_command` is the whole point: a caller that
        // asked for this one gets an answer and a closed connection.
        assert_eq!(
            logs_tail_command(ContainerType::Docker, "abc", 100),
            "docker logs --tail 100 'abc'"
        );
        assert!(!logs_tail_command(ContainerType::Docker, "abc", 100).contains(" -f "));
        assert_eq!(
            logs_tail_command(ContainerType::Podman, "abc", 5),
            "podman logs --tail 5 'abc'"
        );
    }

    #[test]
    fn a_log_read_quotes_the_id_it_was_given() {
        assert_eq!(
            logs_tail_command(ContainerType::Docker, "a'; rm -rf /; echo '", 10),
            r#"docker logs --tail 10 'a'\''; rm -rf /; echo '\'''"#
        );
    }

    #[test]
    fn batched_commands_are_joined_and_quoted_once() {
        let commands = vec![
            ContainerCmd::Version.exec(ContainerType::Docker),
            logs_tail_command(ContainerType::Docker, "it's", 10),
        ];
        let cmd = join_commands(&commands, "SEP");
        assert!(cmd.starts_with("sh -c '"));
        assert!(cmd.ends_with('\''));
        assert!(cmd.contains("\necho SEP\n"));
        // The inner single quote is escaped for the outer `sh -c` as well as by
        // the id's own quoting, and there is exactly one escaping pass over the
        // whole batch — a second would double it.
        assert!(cmd.contains(r"'\''"), "{cmd}");
        assert_eq!(
            sbm_parser_marker_count(&cmd, "SEP"),
            1,
            "one marker between two commands: {cmd}"
        );
    }

    fn sbm_parser_marker_count(cmd: &str, separator: &str) -> usize {
        cmd.matches(&format!("echo {separator}")).count()
    }

    #[test]
    fn podman_status_text_overrides_the_legacy_exited_flag() {
        // A paused container has not exited, so the flag says it is running.
        assert_eq!(
            ContainerStatus::from_podman(Some(false), Some("Paused")),
            ContainerStatus::Paused
        );
        assert!(!ContainerStatus::from_podman(Some(false), Some("Paused")).is_running());
    }

    // -----------------------------------------------------------------------
    // Podman ps
    // -----------------------------------------------------------------------

    #[test]
    fn podman_ps_extracts_compose_project_and_working_dir_from_labels() {
        let raw = json!({
            "Id": "0e9e2ef860d2",
            "Exited": false,
            "Status": "Up 3 hours",
            "Image": "nginx:alpine",
            "Names": ["cmp-web"],
            "Labels": {
                "com.docker.compose.project": "nginx",
                "com.docker.compose.project.working_dir": "/opt/nginx",
                "other": "x",
            },
        })
        .to_string();

        let items = parse_podman_ps(&raw);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].project.as_deref(), Some("nginx"));
        assert_eq!(items[0].working_dir.as_deref(), Some("/opt/nginx"));
        assert_eq!(items[0].raw_status.as_deref(), Some("Up 3 hours"));
    }

    #[test]
    fn podman_ps_status_falls_back_to_state_on_older_output() {
        let raw = json!({
            "Id": "0e9e2ef860d2",
            "Exited": true,
            "State": "exited",
            "Image": "alpine",
            "Names": ["worker"],
        })
        .to_string();

        let items = parse_podman_ps(&raw);
        assert_eq!(items[0].raw_status.as_deref(), Some("exited"));
        assert_eq!(items[0].status, ContainerStatus::Exited);
    }

    #[test]
    fn podman_ps_output_reads_detailed_status_from_the_same_row() {
        let raw = "{\"Id\":\"abc123\",\"Exited\":false,\"Image\":\"alpine\",\
                   \"Names\":[\"worker\"],\"Status\":\"running\"}\tUp 3 hours\n\
                   {\"Id\":\"def456\",\"Exited\":true,\"Image\":\"redis\",\
                   \"Names\":[\"cache\"],\"Status\":\"exited\"}\tExited (0) 7 seconds ago\n";

        let items = parse_podman_ps(raw);
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].raw_status.as_deref(), Some("Up 3 hours"));
        assert_eq!(items[1].raw_status.as_deref(), Some("Exited (0) 7 seconds ago"));
    }

    #[test]
    fn podman_ps_output_skips_only_malformed_rows() {
        let raw = "{\"Id\":\"abc123\",\"Exited\":false,\"Image\":\"alpine\",\"Names\":[\"worker\"]}\tUp 3 hours\n\
                   {\"Id\":\n\
                   {\"Id\":\"def456\",\"Exited\":true,\"Image\":\"redis\",\"Names\":[\"cache\"]}\tExited (0) 7 seconds ago\n";

        let ids: Vec<Option<String>> = parse_podman_ps(raw)
            .into_iter()
            .map(|item| item.id)
            .collect();
        assert_eq!(ids, vec![Some("abc123".to_string()), Some("def456".to_string())]);
    }

    #[test]
    fn podman_ps_parse_handles_missing_labels() {
        let raw = json!({
            "Id": "0e9e2ef860d2",
            "Exited": false,
            "Image": "alpine",
            "Names": ["cmp-standalone"],
        })
        .to_string();

        let items = parse_podman_ps(&raw);
        assert_eq!(items[0].project, None);
        assert_eq!(items[0].working_dir, None);
    }

    #[test]
    fn podman_ps_ports_come_from_the_structured_field() {
        let raw = json!({
            "Id": "abc123",
            "Exited": false,
            "Image": "nginx",
            "Names": ["web"],
            "Ports": [
                {"container_port": 80, "host_port": 8080, "protocol": "tcp"},
                {"container_port": 5432, "host_port": 0, "protocol": "tcp"},
            ],
        })
        .to_string();

        let items = parse_podman_ps(&raw);
        assert_eq!(items[0].ports.as_deref(), Some("8080→80, 5432"));
    }

    // -----------------------------------------------------------------------
    // Stats
    // -----------------------------------------------------------------------

    #[test]
    fn stats_rows_match_exact_container_ids_instead_of_short_substrings() {
        let rows = [
            r#"{"ID":"abcde1111111","CPUPerc":"1%"}"#.to_string(),
            r#"{"ID":"abcde2222222","CPUPerc":"2%"}"#.to_string(),
        ];
        let parsed = parse_stats_rows(&rows.join("\n"));

        assert_eq!(find_stats_row(&parsed, Some("abcde2222222")), Some(rows[1].as_str()));
        assert_eq!(find_stats_row(&parsed, Some("abcde2")), None);
    }

    #[test]
    fn docker_stats_are_split_out_of_their_paired_fields() {
        let stats = parse_stats(
            ContainerType::Docker,
            r#"{"ID":"abc","CPUPerc":"0.15%","MemUsage":"1.2MiB / 7.6GiB","NetIO":"1.2kB / 3.4kB","BlockIO":"5kB / 6kB"}"#,
            None,
        )
        .unwrap();

        assert_eq!(stats.cpu.as_deref(), Some("0.15%"));
        assert_eq!(stats.cpu_avg, None);
        assert_eq!(stats.mem.as_deref(), Some("1.2MiB / 7.6GiB"));
        assert_eq!(stats.net_down.as_deref(), Some("1.2kB"));
        assert_eq!(stats.net_up.as_deref(), Some("3.4kB"));
        assert_eq!(stats.disk_read.as_deref(), Some("5kB"));
        assert_eq!(stats.disk_write.as_deref(), Some("6kB"));
    }

    #[test]
    fn podman_stats_accept_json_integer_values_for_numeric_fields() {
        let stats = parse_stats(
            ContainerType::Podman,
            r#"{"CPU":1,"AvgCPU":0,"MemLimit":1073741824,"MemUsage":1,"NetInput":0,"NetOutput":0,"BlockInput":0,"BlockOutput":0}"#,
            Some("5.0.0"),
        )
        .unwrap();

        assert_eq!(stats.cpu.as_deref(), Some("1.0%"));
        assert_eq!(stats.cpu_avg.as_deref(), Some("0.0%"));
        assert_eq!(stats.mem.as_deref(), Some("1 B / 1 GB"));
        assert_eq!(stats.net_down.as_deref(), Some("0 B"));
        assert_eq!(stats.disk_read.as_deref(), Some("0 B"));
    }

    #[test]
    fn podman_stats_handle_missing_interfaces_and_non_int_counters() {
        let stats = parse_stats(
            ContainerType::Podman,
            r#"{"CPU":1.5,"AvgCPU":0.5,"MemLimit":1073741824,"MemUsage":1,"Network":{"eth0":{"RxBytes":1024,"TxBytes":"2048"},"nulliface":null},"BlockInput":0,"BlockOutput":0}"#,
            Some("5.0.0"),
        )
        .unwrap();

        assert_eq!(stats.cpu.as_deref(), Some("1.5%"));
        assert_eq!(stats.cpu_avg.as_deref(), Some("0.5%"));
        assert_eq!(stats.net_down.as_deref(), Some("1 KB"));
        assert_eq!(stats.net_up.as_deref(), Some("2 KB"));
    }

    #[test]
    fn podman_stats_use_top_level_network_fields_when_version_is_missing() {
        let stats = parse_stats(
            ContainerType::Podman,
            r#"{"CPU":1,"AvgCPU":0,"MemLimit":1073741824,"MemUsage":1,"NetInput":512,"NetOutput":256,"BlockInput":0,"BlockOutput":0}"#,
            None,
        )
        .unwrap();

        assert_eq!(stats.net_down.as_deref(), Some("512 B"));
        assert_eq!(stats.net_up.as_deref(), Some("256 B"));
    }

    #[test]
    fn podman_stats_fall_back_to_top_level_network_fields_for_podman_5() {
        let stats = parse_stats(
            ContainerType::Podman,
            r#"{"CPU":1,"AvgCPU":0,"MemLimit":1073741824,"MemUsage":1,"NetInput":512,"NetOutput":256,"BlockInput":0,"BlockOutput":0}"#,
            Some("5.0.0"),
        )
        .unwrap();

        assert_eq!(stats.net_down.as_deref(), Some("512 B"));
        assert_eq!(stats.net_up.as_deref(), Some("256 B"));
    }

    #[test]
    fn podman_5_network_counters_are_summed_across_interfaces() {
        let stats = parse_stats(
            ContainerType::Podman,
            r#"{"CPU":1,"AvgCPU":0,"MemLimit":1073741824,"MemUsage":1,"Network":{"eth0":{"RxBytes":1024,"TxBytes":2048},"eth1":{"RxBytes":1024,"TxBytes":2048}},"BlockInput":0,"BlockOutput":0}"#,
            Some("5.1.0"),
        )
        .unwrap();

        assert_eq!(stats.net_down.as_deref(), Some("2 KB"));
        assert_eq!(stats.net_up.as_deref(), Some("4 KB"));
    }

    #[test]
    fn an_unreadable_podman_version_reads_the_older_network_shape() {
        let stats = parse_stats(
            ContainerType::Podman,
            r#"{"NetInput":512,"NetOutput":256,"Network":{"eth0":{"RxBytes":9999}}}"#,
            Some("unknown"),
        )
        .unwrap();

        assert_eq!(stats.net_down.as_deref(), Some("512 B"));
    }

    // -----------------------------------------------------------------------
    // Images
    // -----------------------------------------------------------------------

    fn docker_image(id: &str, repository: &str, tag: &str, containers: &str) -> ContainerImage {
        docker_image_with_digest(id, repository, tag, containers, None)
    }

    fn docker_image_with_digest(
        id: &str,
        repository: &str,
        tag: &str,
        containers: &str,
        digest: Option<&str>,
    ) -> ContainerImage {
        let mut raw = json!({
            "ID": id,
            "Repository": repository,
            "Tag": tag,
            "Size": "80 MB",
            "CreatedAt": "now",
            "Containers": containers,
        });
        if let Some(digest) = digest {
            raw["Digest"] = json!(digest);
        }
        parse_images(&raw.to_string(), ContainerType::Docker)
            .into_iter()
            .next()
            .expect("one image")
    }

    #[test]
    fn a_normal_tagged_image_in_use_is_neither_unused_nor_dangling() {
        let image = docker_image("abc123", "nginx", "alpine", "2");
        assert!(!image.is_dangling());
        assert!(!image.is_unused());
    }

    #[test]
    fn a_tagged_image_with_an_unknown_count_is_not_marked_unused() {
        let image = docker_image("def456", "redis", "7-alpine", "N/A");
        assert!(!image.is_dangling());
        assert_eq!(image.containers, None);
        assert!(!image.is_unused());
    }

    #[test]
    fn a_dangling_image_is_unused_and_dangling() {
        let image = docker_image("b771e9afbece", "<none>", "<none>", "N/A");
        assert!(image.is_dangling());
        assert!(image.is_unused());
    }

    #[test]
    fn counts_known_unused_tagged_images() {
        let images = vec![
            docker_image("aaaaaaaaaaaa", "example/worker", "old", "0"),
            docker_image("bbbbbbbbbbbb", "example/api", "latest", "1"),
        ];
        assert_eq!(count_unused_tagged_images(&images, &[]), Some(1));
    }

    #[test]
    fn matches_unknown_usage_by_exact_repository_and_implicit_latest() {
        let image = docker_image("aaaaaaaaaaaa", "registry.example.com/team/api", "latest", "N/A");

        assert_eq!(
            count_unused_tagged_images(std::slice::from_ref(&image), &["api".to_string()]),
            None
        );
        assert_eq!(
            count_unused_tagged_images(
                std::slice::from_ref(&image),
                &["registry.example.com/team/api:latest".to_string()],
            ),
            Some(0)
        );
    }

    #[test]
    fn matches_unknown_usage_by_explicit_image_id() {
        let id = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        let image = docker_image(id, "example/api", "stable", "N/A");

        assert_eq!(
            count_unused_tagged_images(std::slice::from_ref(&image), &[id.to_string()]),
            Some(0)
        );
    }

    #[test]
    fn returns_unknown_when_an_image_reference_cannot_be_confirmed() {
        let image = docker_image("aaaaaaaaaaaa", "example/api", "stable", "N/A");
        assert_eq!(
            count_unused_tagged_images(
                std::slice::from_ref(&image),
                &["example/worker".to_string()],
            ),
            None
        );
    }

    #[test]
    fn mixed_confirmed_unused_and_unresolved_images_stay_unknown() {
        let images = vec![
            docker_image("aaaaaaaaaaaa", "example/old", "stable", "0"),
            docker_image("bbbbbbbbbbbb", "example/current", "stable", "N/A"),
        ];
        assert_eq!(
            count_unused_tagged_images(&images, &["example/other".to_string()]),
            None
        );
    }

    #[test]
    fn does_not_match_repositories_across_registry_boundaries() {
        let image = docker_image("aaaaaaaaaaaa", "registry-a.example/team/api", "latest", "N/A");
        assert_eq!(
            count_unused_tagged_images(
                std::slice::from_ref(&image),
                &["registry-b.example/other/api:latest".to_string()],
            ),
            None
        );
    }

    #[test]
    fn does_not_treat_an_ambiguous_hex_repository_as_an_image_id() {
        let image = docker_image(
            "0123456789abffffffffffffffffffffffffffffffffffffffffffff",
            "example/api",
            "stable",
            "N/A",
        );
        assert_eq!(
            count_unused_tagged_images(
                std::slice::from_ref(&image),
                &["0123456789ab".to_string()],
            ),
            None
        );
    }

    #[test]
    fn matches_digest_pinned_references_without_assuming_latest() {
        let digest = format!("sha256:{}", "a".repeat(64));
        let image = docker_image_with_digest(
            "bbbbbbbbbbbb",
            "registry.example/team/api",
            "stable",
            "N/A",
            Some(&digest),
        );

        assert_eq!(
            count_unused_tagged_images(
                std::slice::from_ref(&image),
                &[format!("registry.example/team/api@{digest}")],
            ),
            Some(0)
        );
        assert_eq!(
            count_unused_tagged_images(
                std::slice::from_ref(&image),
                &[format!("registry.example/team/api@sha256:{}", "c".repeat(64))],
            ),
            None
        );
    }

    #[test]
    fn a_docker_image_repository_falls_back_to_its_names_field() {
        let raw = json!({
            "ID": "abc123",
            "Repository": "",
            "Names": ["nginx"],
            "Tag": "latest",
            "Size": "63.7MB",
            "CreatedAt": "2 weeks ago",
            "Containers": "2",
        });
        let image = parse_images(&raw.to_string(), ContainerType::Docker).remove(0);
        assert_eq!(image.repository, "nginx");
        assert!(!image.is_dangling());
    }

    #[test]
    fn an_empty_names_list_does_not_produce_a_literal_null_repository() {
        let raw = json!({
            "ID": "abc123",
            "Repository": "",
            "Names": [],
            "Tag": "latest",
            "Size": "63.7MB",
            "CreatedAt": "2 weeks ago",
            "Containers": "2",
        });
        let image = parse_images(&raw.to_string(), ContainerType::Docker).remove(0);
        assert_ne!(image.repository, "null");
        assert!(!image.repository.is_empty());
    }

    #[test]
    fn whitespace_leading_names_entries_fall_through_to_a_valid_name() {
        let raw = json!({
            "ID": "abc123",
            "Repository": "",
            "Names": ["", "   ", "nginx"],
            "Tag": "latest",
            "Size": "63.7MB",
            "CreatedAt": "2 weeks ago",
            "Containers": "2",
        });
        let image = parse_images(&raw.to_string(), ContainerType::Docker).remove(0);
        assert_eq!(image.repository, "nginx");
        assert_ne!(image.repository, "<none>");
        assert!(!image.is_dangling());
    }

    #[test]
    fn all_empty_names_entries_fall_back_to_none() {
        let raw = json!({
            "ID": "abc123",
            "Repository": "",
            "Names": ["", "   "],
            "Tag": "latest",
            "Size": "63.7MB",
            "CreatedAt": "2 weeks ago",
            "Containers": "2",
        });
        let image = parse_images(&raw.to_string(), ContainerType::Docker).remove(0);
        assert_eq!(image.repository, "<none>");
        assert!(image.is_dangling());
    }

    #[test]
    fn image_output_skips_malformed_rows_without_losing_valid_images() {
        let raw = "{\"ID\":\"abc123\",\"Repository\":\"nginx\",\"Tag\":\"latest\",\
                   \"Size\":\"10MB\",\"CreatedAt\":\"now\",\"Containers\":\"1\"}\n\
                   not-json\n\
                   {\"ID\":\"def456\",\"Repository\":\"redis\",\"Tag\":\"7\",\
                   \"Size\":\"20MB\",\"CreatedAt\":\"now\",\"Containers\":\"0\"}\n";

        let ids: Vec<Option<String>> = parse_images(raw, ContainerType::Docker)
            .into_iter()
            .map(|image| image.id)
            .collect();
        assert_eq!(ids, vec![Some("abc123".to_string()), Some("def456".to_string())]);
    }

    #[test]
    fn image_output_recovers_complete_rows_from_a_truncated_json_array() {
        let raw = "[\n\
                   {\"ID\":\"abc123\",\"Repository\":\"nginx\",\"Tag\":\"latest\",\
                   \"Size\":\"10MB\",\"CreatedAt\":\"now\",\"Containers\":\"1\"},\n\
                   {\"ID\":\"truncated\"";

        let ids: Vec<Option<String>> = parse_images(raw, ContainerType::Docker)
            .into_iter()
            .map(|image| image.id)
            .collect();
        assert_eq!(ids, vec![Some("abc123".to_string())]);
    }

    // -----------------------------------------------------------------------
    // Podman images
    // -----------------------------------------------------------------------

    fn podman_image(raw: serde_json::Value) -> ContainerImage {
        parse_images(&raw.to_string(), ContainerType::Podman)
            .into_iter()
            .next()
            .expect("one image")
    }

    #[test]
    fn a_normal_podman_image_in_use_is_neither_unused_nor_dangling() {
        let image = podman_image(json!({
            "Id": "abc123",
            "repository": "nginx",
            "tag": "alpine",
            "Size": 63700000,
            "Created": 1720000000,
            "Containers": 2,
        }));
        assert!(!image.is_dangling());
        assert!(!image.is_unused());
    }

    #[test]
    fn a_podman_image_with_no_containers_is_unused_but_not_dangling() {
        let image = podman_image(json!({
            "Id": "def456",
            "repository": "redis",
            "tag": "7-alpine",
            "Size": 39900000,
            "Created": 1721000000,
            "Containers": 0,
        }));
        assert!(!image.is_dangling());
        assert!(image.is_unused());
    }

    #[test]
    fn a_dangling_podman_image_is_unused_and_dangling() {
        let image = podman_image(json!({
            "Id": "b771e9afbece",
            "repository": "<none>",
            "tag": "<none>",
            "Size": 648000000,
            "Created": 1710000000,
            "Containers": 0,
        }));
        assert!(image.is_dangling());
        assert!(image.is_unused());
    }

    #[test]
    fn podman_image_falls_back_to_names_when_repository_and_tag_are_missing() {
        let image = podman_image(json!({
            "Id": "abc123",
            "Names": ["docker.io/library/nginx:latest"],
            "Size": 63700000,
            "Created": 1720000000,
            "Containers": 2,
        }));
        assert_eq!(image.repository, "docker.io/library/nginx");
        assert_eq!(image.tag.as_deref(), Some("latest"));
        assert!(!image.is_dangling());
    }

    #[test]
    fn podman_image_accepts_capitalized_template_fields() {
        let image = podman_image(json!({
            "ID": "abc123",
            "Repository": "quay.io/example/api",
            "Tag": "stable",
            "Size": 63700000,
            "Created": 1720000000,
            "Containers": 2,
        }));
        assert_eq!(image.repository, "quay.io/example/api");
        assert_eq!(image.tag.as_deref(), Some("stable"));
        assert!(!image.is_dangling());
    }

    #[test]
    fn podman_image_handles_missing_optional_numeric_fields() {
        let image = podman_image(json!({
            "Id": "abc123",
            "repository": "nginx",
            "tag": "alpine",
        }));
        assert_eq!(image.size, None);
        assert_eq!(image.created, None);
        assert_eq!(image.containers, None);
        assert!(!image.is_dangling());
        assert!(!image.is_unused());
    }

    #[test]
    fn a_podman_image_size_is_rendered_from_its_byte_count() {
        let image = podman_image(json!({
            "Id": "abc123",
            "repository": "nginx",
            "tag": "alpine",
            "Size": 63700000,
        }));
        assert_eq!(image.size.as_deref(), Some("60.7 MB"));
    }

    // -----------------------------------------------------------------------
    // Ports
    // -----------------------------------------------------------------------

    #[test]
    fn docker_collapses_one_mapping_repeated_per_address_family() {
        assert_eq!(
            format_docker_ports("0.0.0.0:8080->80/tcp, :::8080->80/tcp").as_deref(),
            Some("8080→80")
        );
    }

    #[test]
    fn docker_keeps_distinct_mappings_and_drops_the_bind_address() {
        assert_eq!(
            format_docker_ports("0.0.0.0:443->443/tcp, :::443->443/tcp, 0.0.0.0:80->80/tcp")
                .as_deref(),
            Some("443→443, 80→80")
        );
    }

    #[test]
    fn docker_reports_an_exposed_only_port_as_the_port_alone() {
        assert_eq!(format_docker_ports("5432/tcp").as_deref(), Some("5432"));
    }

    #[test]
    fn docker_keeps_a_shape_it_cannot_condense() {
        assert_eq!(format_docker_ports("weird-entry").as_deref(), Some("weird-entry"));
    }

    #[test]
    fn docker_reports_no_ports_as_none_not_an_empty_string() {
        assert_eq!(format_docker_ports(""), None);
        assert_eq!(format_docker_ports("   "), None);
    }

    #[test]
    fn podman_reads_structured_port_entries() {
        let ports = json!([
            {"container_port": 80, "host_port": 8080, "protocol": "tcp"},
            {"container_port": 5432, "host_port": 0, "protocol": "tcp"},
        ]);
        assert_eq!(format_podman_ports(&ports).as_deref(), Some("8080→80, 5432"));
    }

    #[test]
    fn podman_ignores_entries_with_no_container_port() {
        assert_eq!(format_podman_ports(&json!([{"host_port": 8080}])), None);
        assert_eq!(format_podman_ports(&serde_json::Value::Null), None);
    }

    #[test]
    fn a_docker_ps_row_carries_ports_through() {
        let item = parse_docker_ps_row(
            "abc\tUp 2 days\tweb\tnginx:alpine\tstack\t/opt/stack\t\
             0.0.0.0:8080->80/tcp, :::8080->80/tcp",
        )
        .unwrap();
        assert_eq!(item.ports.as_deref(), Some("8080→80"));
    }

    #[test]
    fn a_ps_row_written_without_the_ports_field_still_parses() {
        let item =
            parse_docker_ps_row("abc\tUp 2 days\tweb\tnginx:alpine\tstack\t/opt/stack").unwrap();
        assert_eq!(item.ports, None);
        assert_eq!(item.name.as_deref(), Some("web"));
    }

    // -----------------------------------------------------------------------
    // Disk usage
    // -----------------------------------------------------------------------

    #[test]
    fn reads_docker_newline_delimited_rows_and_sums_every_type() {
        let raw = "{\"Type\":\"Images\",\"TotalCount\":\"12\",\"Active\":\"3\",\"Size\":\"1.4GB\",\
                   \"Reclaimable\":\"809MB (56%)\"}\n\
                   {\"Type\":\"Containers\",\"TotalCount\":\"4\",\"Active\":\"3\",\"Size\":\"0B\",\
                   \"Reclaimable\":\"0B\"}\n\
                   {\"Type\":\"Local Volumes\",\"TotalCount\":\"2\",\"Active\":\"1\",\"Size\":\"200MB\",\
                   \"Reclaimable\":\"100MB (50%)\"}";

        let usage = parse_disk_usage(raw).unwrap();
        assert_eq!(usage.image_count, Some(12));
        assert_eq!(usage.reclaimable_bytes, Some(909_000_000));
    }

    #[test]
    fn reads_a_podman_json_array_with_numeric_totals() {
        let raw = "[{\"Type\":\"Images\",\"Total\":7,\"Active\":2,\"Size\":\"1GB\",\
                   \"Reclaimable\":\"512MB (50%)\"}]";

        let usage = parse_disk_usage(raw).unwrap();
        assert_eq!(usage.image_count, Some(7));
        assert_eq!(usage.reclaimable_bytes, Some(512_000_000));
    }

    #[test]
    fn a_row_it_cannot_read_is_skipped_rather_than_failing_the_rest() {
        let raw = "not json\n{\"Type\":\"Images\",\"TotalCount\":\"3\",\"Reclaimable\":\"1MB\"}";

        let usage = parse_disk_usage(raw).unwrap();
        assert_eq!(usage.image_count, Some(3));
        assert_eq!(usage.reclaimable_bytes, Some(1_000_000));
    }

    #[test]
    fn nothing_readable_answers_none_not_a_zeroed_record() {
        assert_eq!(parse_disk_usage(""), None);
        assert_eq!(parse_disk_usage("garbage"), None);
    }

    #[test]
    fn decimal_and_binary_units_are_told_apart() {
        assert_eq!(parse_human_bytes("809MB (56%)"), Some(809_000_000));
        assert_eq!(parse_human_bytes("1.5GiB"), Some(1_610_612_736));
        assert_eq!(parse_human_bytes("2kB"), Some(2000));
        assert_eq!(parse_human_bytes("512B"), Some(512));
        assert_eq!(parse_human_bytes("0B"), Some(0));
    }

    #[test]
    fn an_unreadable_size_is_none_which_is_not_zero() {
        assert_eq!(parse_human_bytes("N/A"), None);
        assert_eq!(parse_human_bytes(""), None);
    }

    // -----------------------------------------------------------------------
    // Output and formatting
    // -----------------------------------------------------------------------

    #[test]
    fn user_facing_output_prefers_what_stderr_said() {
        assert_eq!(
            user_facing_output("sh: docker: not found", "SrvBoxContainerSep_1_0").as_deref(),
            Some("sh: docker: not found")
        );
    }

    #[test]
    fn user_facing_output_drops_the_separators_the_script_echoes() {
        // The whole explanation a user got used to be exactly this and nothing
        // else, which named neither the command nor the reason.
        assert_eq!(
            user_facing_output(
                "",
                "SrvBoxContainerSep_1786614816321254_0\nSrvBoxContainerSep_1786614816321254_0"
            ),
            None
        );
    }

    #[test]
    fn user_facing_output_keeps_real_stdout_when_stderr_is_empty() {
        assert_eq!(
            user_facing_output("", "SrvBoxContainerSep_1_0\npermission denied\n").as_deref(),
            Some("permission denied")
        );
    }

    #[test]
    fn nothing_said_at_all_is_none_not_an_empty_line() {
        assert_eq!(user_facing_output("  ", "\n\n"), None);
    }

    #[test]
    fn one_missing_runtime_is_one_line_not_one_per_batched_command() {
        // ps, stats and images go out in a single call, so a shell with no
        // docker says the same thing three times.
        assert_eq!(
            user_facing_output(
                "sh: docker: not found\nsh: docker: not found\nsh: docker: not found",
                ""
            )
            .as_deref(),
            Some("sh: docker: not found")
        );
    }

    #[test]
    fn human_bytes_divides_at_a_whole_unit() {
        // The step is `>= 1`, not `> 1`: a strict comparison stopped one unit
        // short and rendered an exact mebibyte as `1024 KB`.
        assert_eq!(human_bytes(0), "0 B");
        assert_eq!(human_bytes(1024), "1 KB");
        assert_eq!(human_bytes(1_048_576), "1 MB");
        assert_eq!(human_bytes(1_073_741_824), "1 GB");
        assert_eq!(human_bytes(1_099_511_627_776), "1 TB");
        assert_eq!(human_bytes(1_099_511_627_776 * 1024), "1024 TB");
        assert_eq!(human_bytes(1536), "1.5 KB");
    }

    #[test]
    fn a_rounded_quantity_is_rounded_half_away_from_zero() {
        assert_eq!(fixed1(0.0), "0.0");
        assert_eq!(fixed1(1.25), "1.3");
        assert_eq!(fixed1(-1.25), "-1.3");
        assert_eq!(trim_trailing_zero(fixed1(2.0)), "2");
    }
}
