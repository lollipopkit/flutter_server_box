//! `/api/v1/process` — the process table of the machine the agent runs on, and
//! the signal that stops one process.
//!
//! # Why this is not `/exec`
//!
//! Both halves are a model rather than a command. The table is read out of
//! `ps` on Unix and out of PowerShell's JSON on Windows, by column name where
//! the platform printed a header and by position where it did not, and which
//! of those columns exist is what decides which orders the page may offer and
//! which columns it can draw. The stop is a script that checks the PID's start
//! identity before signalling it, and a `sudo` retry for a process this account
//! does not own — a retry that has to keep the script away from sudo's password
//! read. Both live in [`sbm_parser::proc`], so the app over SSH and this
//! endpoint read and stop one machine the same way, and the panel composes no
//! command line and parses no `ps` output.
//!
//! The table is [`sbm_parser::script::ShellFunc::Process`], run locally: the
//! same text the app uploads and calls with `-p` over SSH, so a change to it
//! reaches both.
//!
//! # The reading is kept between requests
//!
//! A read/write speed is a difference against the previous reading, so one has
//! to be kept somewhere. The app keeps it on the page, and it dies with the
//! page; here it is kept here, for as long as [`BASELINE_MAX_AGE`] allows. A
//! request inside [`REUSE_WINDOW`] of that reading is answered with it rather
//! than with a new one, so a request that is not asking for fresh numbers —
//! the page reordering the table — does not turn an interval of a few
//! milliseconds into a speed.
//!
//! # Privilege
//!
//! Reading needs only the panel login, the same as the crontab and the
//! container list: `ps` shows the agent's own user the table `top` would show
//! it. **Signalling is `full_access`**, the same grant as the shell and
//! `/exec` — anyone who can open a shell can run `kill` in it, so a switch of
//! its own would withhold nothing.

use std::sync::Arc;
use std::time::Duration;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::process::Command as TokioCommand;

use super::privileged;
use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::monitoring::{run_local_shell_func, system_type};
use crate::utils::command::{self, Limits};
use crate::utils::error::MonitorError;
use sbm_parser::SystemType;
use sbm_parser::proc::{
    Proc, ProcKillOutcome, ProcLoad, ProcSignal, ProcSortMode, PsParseIssue, PsResult,
};

/// One row per process, and a busy host has thousands. Its own cap rather than
/// the 1 MiB default one, which a machine with a few thousand processes
/// exceeds — and going over is reported as "the table is larger than this agent
/// reads", which is a sentence that costs the reader the whole page.
const MAX_OUTPUT_BYTES: u64 = 8 * 1024 * 1024;

/// The bounds the table is read under. The timeout is the default one: `ps` on
/// a machine so loaded that it takes longer than this has no table to give.
const TABLE_LIMITS: Limits = Limits {
    max_output_bytes: MAX_OUTPUT_BYTES,
    ..Limits::DEFAULT
};

/// How long a reading answers further requests for it.
///
/// A page that reorders the table, or a caller that refreshes twice, asks a
/// question the last reading already answers. Running the command again would
/// answer it with read/write speeds differenced over that few-hundred-
/// millisecond gap — a spike, not a rate — so the reading stands and only its
/// order changes. Shorter than any poll interval the page uses, so an ordinary
/// refresh is never served a reading it already has.
const REUSE_WINDOW: Duration = Duration::from_millis(2000);

/// How old a reading may be and still be what a speed is differenced against.
///
/// Past this the counters moved an unknown number of times, and dividing that
/// by the whole gap reports an average over a period nobody was looking at.
/// The reading is dropped instead, exactly as it is on a page that has just
/// been opened: the first answer has no speeds, and the second one has real
/// ones.
const BASELINE_MAX_AGE: Duration = Duration::from_secs(30);

/// The last reading, so the next one has something to difference against.
///
/// Held on the agent rather than on the caller because the agent is one
/// machine: two browsers looking at the same server are looking at the same
/// interval, and the second one's request is as good an answer as the first's.
pub struct ProcessSample {
    /// When the reading was taken, by this process's clock.
    pub sampled_at_millis: i64,
    pub result: Arc<PsResult>,
}

#[derive(Debug, Deserialize)]
pub struct ProcessQuery {
    /// Which order the caller wants. Omitted is the table's own default, and a
    /// mode this table cannot answer falls back to it rather than ordering
    /// everything by a column of nulls.
    sort: Option<ProcSortMode>,
    /// Which way round. Omitted is that mode's own default — see
    /// [`ProcSortMode::default_ascending`].
    ascending: Option<bool>,
}

#[derive(Serialize)]
struct ProcessResponse {
    /// Whether the machine gave a table at all. `false` is a state of the
    /// machine, not a failure of the caller, so the page draws one screen
    /// either way.
    available: bool,
    /// Which of the known reasons it was, so the page phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something this endpoint does not classify, and `reason` is it.
    reason_kind: Option<ProcessReason>,
    /// What the machine said, verbatim. Never translated and never classified
    /// away: it is the only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// Whether this caller may signal a process. The page asks so it can draw
    /// the buttons read-only instead of failing on a click; the answer is
    /// re-checked on the signal itself, since a UI hint is not a boundary.
    editable: bool,
    procs: Vec<ProcRow>,
    /// Rows the parser had to drop. The rest of the table is still here: a
    /// table with one bad row is a table with one bad row, not an empty page.
    issue: Option<PsParseIssue>,
    /// The 1, 5 and 15 minute load averages, where the machine reports them.
    load: Option<ProcLoad>,
    /// The instant this reading was taken, in Unix milliseconds. Older than
    /// the request when the reading was reused — see [`REUSE_WINDOW`].
    sampled_at_millis: i64,
    /// Which columns the machine reported, which is what the page draws.
    columns: ProcessColumns,
    /// The orders this table can answer, in the order the page draws them.
    sorts: Vec<ProcSortMode>,
    /// What this answer is ordered by, after the fallbacks above.
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
    /// The signals this platform offers, empty where it has none implemented.
    /// The page offers no stop button at all when it is empty.
    signals: Vec<ProcSignal>,
}

/// Which of the machine's columns carried a value.
///
/// Answered over the table rather than derived from the platform: a `ps` that
/// prints no `%CPU` and a machine whose processes all report none look the
/// same in the rows, and the page has one thing to ask either way. `read` and
/// `write` are the cumulative counters; their speeds are what a sort can use,
/// and the two are not the same question — a first reading has the counters
/// and no speeds.
#[derive(Serialize, Default)]
struct ProcessColumns {
    user: bool,
    cpu: bool,
    mem: bool,
    rss: bool,
    read: bool,
    write: bool,
    read_speed: bool,
    write_speed: bool,
}

impl ProcessColumns {
    fn of(procs: &[Proc]) -> Self {
        let mut columns = Self::default();
        for proc in procs {
            columns.user |= proc.user.as_ref().is_some_and(|user| !user.is_empty());
            columns.cpu |= proc.cpu.is_some();
            columns.mem |= proc.mem.is_some();
            columns.rss |= proc.rss_kb().is_some();
            columns.read |= proc.read_bytes.is_some();
            columns.write |= proc.write_bytes.is_some();
            columns.read_speed |= proc.read_speed.is_some();
            columns.write_speed |= proc.write_speed.is_some();
        }
        columns
    }

    /// The orders this table can answer, in the order the app draws its chips:
    /// the four worth one tap first, then the rest.
    fn sorts(&self) -> Vec<ProcSortMode> {
        let offered = [
            (ProcSortMode::Cpu, self.cpu),
            (ProcSortMode::Mem, self.mem),
            (ProcSortMode::Rss, self.rss),
            // A PID is always there and always sortable.
            (ProcSortMode::Pid, true),
            (ProcSortMode::User, self.user),
            (ProcSortMode::Name, true),
            (ProcSortMode::Read, self.read_speed),
            (ProcSortMode::Write, self.write_speed),
        ];
        offered
            .into_iter()
            .filter_map(|(mode, supported)| supported.then_some(mode))
            .collect()
    }

    /// The order to open on: the first resource column the machine reported,
    /// and the PID where it reported none. A process list is read to find what
    /// is using the machine, so an alphabetical one would be the one order
    /// that answers nothing.
    fn default_sort(&self) -> ProcSortMode {
        [ProcSortMode::Cpu, ProcSortMode::Mem, ProcSortMode::Rss, ProcSortMode::Read, ProcSortMode::Write]
            .into_iter()
            .find(|mode| self.sorts().contains(mode))
            .unwrap_or(ProcSortMode::Pid)
    }
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum ProcessReason {
    /// The command was killed for exceeding its time limit, or could not be
    /// started at all.
    DidNotFinish,
    /// It printed more than this endpoint reads — a machine with tens of
    /// thousands of processes. Reported as itself because what a caller can do
    /// about it is not what it can do about a timeout.
    TooLarge,
    /// It ran and printed nothing.
    Empty,
}

/// One process as the page draws it: the row's own fields plus what the row's
/// *strings* mean.
#[derive(Serialize)]
struct ProcRow {
    #[serde(flatten)]
    proc: Proc,
    /// What to call the process where its whole command line does not fit.
    ///
    /// Sent rather than derived by the client: "the last path component of the
    /// executable, minus the colon a process that rewrites its title leaves
    /// behind, and a kernel thread's bracketed name as it stands" is a rule,
    /// and a second implementation of it would be the one that drifts.
    name: String,
    /// `RSS` in KiB as a number. The column is a string because the two `ps`
    /// dialects print different things into it, and `-` is not a measurement
    /// of zero.
    rss_kb: Option<i64>,
    /// `kthreadd` or one of its children. Hidden by default — see the page.
    is_kernel_thread: bool,
    /// Whether this row may be signalled at all: a PID whose start identity
    /// the machine did not report cannot be checked before the signal, and
    /// signalling the wrong process is worse than not being able to signal
    /// this one.
    killable: bool,
}

impl ProcRow {
    fn of(proc: &Proc, system: SystemType) -> Self {
        Self {
            name: proc.name(),
            rss_kb: proc.rss_kb(),
            is_kernel_thread: proc.is_kernel_thread(),
            killable: sbm_parser::proc::kill_supported(proc.pid, proc.start_id.as_deref(), system),
            proc: proc.clone(),
        }
    }
}

/// Reads the process table.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<ProcessQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    let system = system_type();
    let now = now_millis();

    // Copied out rather than held: the branch below runs a command, and
    // holding the lock across it would put every caller on this machine's one
    // `ps` in a queue behind whoever asked first. The reading itself stays in
    // the slot — a request that reorders the table does not change it, and the
    // interval the next reading is differenced over is still the one it
    // started.
    let stored = app_state
        .process_sample
        .lock()
        .await
        .as_ref()
        .map(|sample| (now - sample.sampled_at_millis, sample.result.clone()));

    if let Some((age, result)) = &stored
        && *age < REUSE_WINDOW.as_millis() as i64
    {
        let (sort, ascending) = resolve_sort(result, query.sort, query.ascending);
        return Ok(HttpResponse::Ok().json(&respond(
            &result.sorted_by(sort, Some(ascending)),
            editable,
            system,
            Some(sort),
            Some(ascending),
        )));
    }

    // What this reading's speeds are differenced against. An expired one is
    // left in the slot rather than taken out: it is replaced below if this
    // read succeeds, and if it does not, the next caller still finds it and
    // still ignores it for being too old.
    let baseline = stored
        .as_ref()
        .filter(|(age, _)| *age <= BASELINE_MAX_AGE.as_millis() as i64)
        .map(|(_, result)| &**result);

    let output = match run_local_shell_func(sbm_parser::script::ShellFunc::Process, None, TABLE_LIMITS)
        .await
    {
        Ok(output) => output,
        Err(MonitorError::Io(error)) if command::is_output_overflow(&error) => {
            return Ok(HttpResponse::Ok().json(&unavailable(
                editable,
                system,
                ProcessReason::TooLarge,
                None,
            )));
        }
        Err(error) => {
            tracing::warn!("process: the table command failed: {error}");
            return Ok(HttpResponse::Ok().json(&unavailable(
                editable,
                system,
                ProcessReason::DidNotFinish,
                Some(error.to_string()),
            )));
        }
    };
    let Some(output) = output else {
        return Ok(HttpResponse::Ok().json(&unavailable(
            editable,
            system,
            ProcessReason::DidNotFinish,
            None,
        )));
    };

    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr);
    if stdout.trim().is_empty() {
        // What the machine said is the whole of the answer here: `ps` missing
        // from a minimal image prints to stderr and exits non-zero, and a page
        // that showed only "empty" would send its reader looking at the wrong
        // thing.
        let reason = stderr.trim();
        return Ok(HttpResponse::Ok().json(&unavailable(
            editable,
            system,
            ProcessReason::Empty,
            (!reason.is_empty()).then(|| reason.to_owned()),
        )));
    }

    // Parsed before it is ordered: which order a table can answer is a
    // property of the columns the machine printed, and those are only known
    // once it has been read. The pass this costs is a sort of rows already in
    // memory.
    let parsed = PsResult::parse(
        &stdout,
        ProcSortMode::Cpu,
        Some(false),
        baseline,
        now_millis(),
    );
    let (sort, ascending) = resolve_sort(&parsed, query.sort, query.ascending);
    let result = Arc::new(parsed.sorted_by(sort, Some(ascending)));

    let response = respond(&result, editable, system, Some(sort), Some(ascending));
    *app_state.process_sample.lock().await = Some(ProcessSample {
        sampled_at_millis: result.sampled_at_millis,
        result,
    });
    Ok(HttpResponse::Ok().json(&response))
}

/// Which of what the caller asked for this table can answer.
///
/// A mode whose column the machine never filled would order the whole table by
/// nulls, which is a table in no order at all — so it is answered with the
/// default instead, and the response says which one that was.
fn resolve_sort(
    result: &PsResult,
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
) -> (ProcSortMode, bool) {
    let columns = ProcessColumns::of(&result.procs);
    let mode = sort
        .filter(|mode| columns.sorts().contains(mode))
        .unwrap_or_else(|| columns.default_sort());
    (mode, ascending.unwrap_or_else(|| mode.default_ascending()))
}

/// The body for a machine that gave no table, or none this build could read.
fn unavailable(
    editable: bool,
    system: SystemType,
    kind: ProcessReason,
    reason: Option<String>,
) -> ProcessResponse {
    ProcessResponse {
        available: false,
        reason_kind: Some(kind),
        reason,
        editable,
        procs: Vec::new(),
        issue: None,
        load: None,
        sampled_at_millis: now_millis(),
        columns: ProcessColumns::default(),
        sorts: Vec::new(),
        sort: None,
        ascending: None,
        signals: signals(system),
    }
}

/// The body for a table that was read.
fn respond(
    result: &PsResult,
    editable: bool,
    system: SystemType,
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
) -> ProcessResponse {
    let columns = ProcessColumns::of(&result.procs);
    ProcessResponse {
        available: true,
        reason_kind: None,
        reason: None,
        editable,
        procs: result
            .procs
            .iter()
            .map(|proc| ProcRow::of(proc, system))
            .collect(),
        issue: result.issue.clone(),
        load: result.load,
        sampled_at_millis: result.sampled_at_millis,
        sorts: columns.sorts(),
        columns,
        sort,
        ascending,
        signals: signals(system),
    }
}

/// The signals this platform offers, as a list the response can hold.
fn signals(system: SystemType) -> Vec<ProcSignal> {
    sbm_parser::proc::signals_for(system).to_vec()
}

/// What the page sends to stop one process.
#[derive(Deserialize)]
pub struct KillRequest {
    pid: i64,
    /// The identity the listing reported for that PID, checked against the
    /// process's own start time before the signal is sent — see
    /// [`sbm_parser::proc::kill_command`]. A number the kernel has since handed
    /// to something else is refused rather than signalled.
    #[serde(default)]
    start_id: Option<String>,
    signal: ProcSignal,
    /// For `sudo -S`, when the process belongs to another account. Never
    /// logged, and never written into a command line.
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct KillResponse {
    /// What happened, told apart from a non-zero exit because the caller's
    /// next move differs for each: `denied` is a process this account does not
    /// own, `target_changed` is a table that has moved on.
    outcome: ProcKillOutcome,
    exit_code: Option<i32>,
    /// The machine's own words, both streams. The markers this endpoint's
    /// script prints its verdict with are in here; `outcome` is the answer and
    /// this is what to show when there is no clean one.
    stdout: String,
    stderr: String,
    /// `sudo` refused the password that was sent, or was not given one. Told
    /// apart from any other failure because the caller's next move is to ask
    /// the user for a password and send the same request again.
    sudo_rejected: bool,
}

/// Stops one process.
pub async fn kill(
    req: HttpRequest,
    body: web::types::Json<KillRequest>,
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
        Event::new(Kind::Process, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let system = system_type();
    let subject = format!("{} {}", request.signal.name(), request.pid);
    // A request that names something this build cannot do on this platform —
    // BSD, or a row with no start identity to check the PID against. Refused
    // before anything runs, so a malformed request costs nothing on the
    // machine.
    let Some(command_text) =
        sbm_parser::proc::kill_command(request.pid, request.start_id.as_deref(), system, request.signal)
    else {
        Event::new(Kind::Process, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .subject(subject)
            .detail("no way to stop this process safely")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::BadRequest().finish());
    };

    let mut output = run_plain(&command_text, system).await;
    let mut sudo_rejected = false;
    // A process this account does not own is asked for again as root, the way
    // a user would with `sudo kill`, rather than reported as a failure they
    // can do nothing about. Windows has no equivalent and no polite request
    // either.
    if system != SystemType::Windows && outcome_of(&output) == Some(ProcKillOutcome::Denied) {
        output = run_sudo(&command_text, request.password.as_deref()).await;
        sudo_rejected = privileged::sudo_rejected(output.as_ref());
    }

    let outcome = outcome_of(&output).unwrap_or(ProcKillOutcome::Failed);
    // One row, written after the outcome is known rather than before it. The
    // subject is the signal and the PID, which reached this agent from a table
    // this agent wrote — a row naming it is the only record of which process
    // was signalled, since the number may belong to something else by the time
    // the row is read.
    let (action, result, detail) = match outcome {
        ProcKillOutcome::Succeeded => (Action::Write, Outcome::Ok, None),
        ProcKillOutcome::Denied => (Action::Denied, Outcome::Denied, Some("permission denied")),
        ProcKillOutcome::TargetChanged => (Action::Write, Outcome::Error, Some("target changed")),
        ProcKillOutcome::Failed => {
            let detail = if sudo_rejected {
                "sudo password rejected"
            } else {
                "command failed"
            };
            (Action::Write, Outcome::Error, Some(detail))
        }
    };
    let mut event = Event::new(Kind::Process, action, result)
        .remote_ip(remote_ip.clone())
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
    Ok(HttpResponse::Ok().json(&KillResponse {
        outcome,
        exit_code,
        stdout,
        stderr,
        sudo_rejected,
    }))
}

/// What the machine answered, where it answered at all.
fn outcome_of(output: &Option<std::process::Output>) -> Option<ProcKillOutcome> {
    let output = output.as_ref()?;
    Some(sbm_parser::proc::kill_outcome(&String::from_utf8_lossy(&output.stdout)))
}

/// Runs the stop script as the agent's own account.
///
/// The Unix text is POSIX shell and is handed to `sh` as its standard input,
/// which is the shape [`sbm_parser::proc::kill_command`] documents and the same
/// one the app feeds it over SSH — [`privileged::as_self`]. The Windows text is
/// a complete command line — `powershell.exe -EncodedCommand <base64>` — so it
/// is run as one: it holds nothing a command interpreter would read as syntax,
/// since every value in it is a PID or base64. That branch is this endpoint's
/// own; it is the only caller whose text is not shell.
async fn run_plain(command_text: &str, system: SystemType) -> Option<std::process::Output> {
    if system != SystemType::Windows {
        return privileged::as_self(command_text, "process kill", Limits::DEFAULT).await;
    }
    let mut command = TokioCommand::new("cmd");
    command.args(["/C", command_text]);
    command::run(command, "process kill", Limits::DEFAULT, None)
        .await
        .unwrap_or_else(|error| {
            tracing::warn!("process kill: {error}");
            None
        })
}

/// Runs the stop script as root, [`privileged::as_root`].
async fn run_sudo(command_text: &str, password: Option<&str>) -> Option<std::process::Output> {
    privileged::as_root(command_text, "process kill", Limits::DEFAULT, password).await
}

fn now_millis() -> i64 {
    chrono::Utc::now().timestamp_millis()
}
