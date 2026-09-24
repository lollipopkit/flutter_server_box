//! `/api/v1/benchmark` — the benchmark runs this agent has started, and the
//! commands that watch, stop and clean up after them.
//!
//! # Why this is not `/exec`
//!
//! A benchmark is not one command. It is a launcher written into a directory on
//! the machine, started detached, left to write an exit code and a result while
//! nobody is watching, and stopped by killing a process group. `/exec` can
//! carry any one of those commands and knows nothing about the other three;
//! every caller would then keep its own record of which directory is which run,
//! and two of them would disagree. That record is a table here instead, and
//! everything that reads it goes through the shared command layer in
//! [`sbm_parser::bench`] — the same strings the app sends over SSH.
//!
//! # Why the agent owns the run rather than the browser
//!
//! yabs takes ten to twenty minutes. A browser closes its tab, a laptop sleeps,
//! a phone locks its screen, and a panel that owned the run would have to
//! reconstruct it from nothing on the next visit. The agent is the party that is
//! resident, so it is the one that watches: the row is written *before* the run
//! starts, and a poller carries it to a terminal state whether or not anyone is
//! looking. A page reopened tomorrow finds the result.
//!
//! # Authority
//!
//! Reading is the panel login: a run is a record of what this machine measured
//! about itself, and the app has always shown that to whoever asked. Starting,
//! stopping and removing need `full_access`, the same grant the shell, `/exec`
//! and `/power` need — a benchmark writes gigabytes to a disk and saturates a
//! link, and anyone who can open a shell can run one anyway.
//!
//! # One run at a time
//!
//! Enforced by a partial unique index on `benchmark_run` rather than by a check
//! in this file, because two concurrent starts would both pass a check. It is
//! also the shape the command layer assumes: the run directory is fixed per
//! working directory, so a second run there would overwrite the first's pid,
//! exit code and output.

use std::sync::Arc;
use std::time::Duration;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, SqlitePool};

use sbm_parser::bench::{self, BenchOptions, BenchPollState};

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::utils::command::{self, Limits};

/// The vendored yabs script, exactly as `assets/yabs.b64` holds it.
///
/// Base64 for the reason the app's copy gives: a bundled asset that reads as
/// executable code — a script suffix, or a leading `#!` — is treated by App
/// Store validation as a nested code object needing its own signature, which
/// fails the upload. Nothing reads this file as code here either, and one copy
/// in the repository is what keeps the agent and the app sending the same
/// program. [`bench::decode_asset`] is the decoder both use.
pub const SCRIPT_ASSET_B64: &str = include_str!("../../../assets/yabs.b64");

/// How many runs the history keeps.
///
/// The app's `BenchmarkStore.historyLimit`, and the same rule: a `running` row
/// is never pruned, whatever its age. It names a directory on this machine with
/// a live process in it, and losing the row is losing the only way to reach
/// either.
pub const HISTORY_LIMIT: i64 = 50;

/// How long one poll may take.
///
/// A directory listing and a process table, run on a machine that is by
/// definition under load — fio is filling the page cache and iperf3 is
/// saturating the link while this runs. A timeout here answers as "the agent
/// did not answer", which the panel retries, so the cost of being generous is
/// latency on a page nobody is watching and the cost of being strict is a run
/// that reads as gone while it is going.
const POLL_TIMEOUT: Duration = Duration::from_secs(20);

/// What one poll may read. `poll_command` prints the run's log, which is the
/// only unbounded part of its answer, and the runner's 1 MiB default is a
/// benchmark's whole output rather than a page's worth of it.
///
/// Reaching this is not a state a real run gets into — it would take a log of
/// several million bytes — and the answer if it happens is "ask again" rather
/// than a truncated read the panel would mistake for a run that ended.
const POLL_MAX_OUTPUT: u64 = 8 * 1024 * 1024;

/// What a stored log is cut to.
///
/// Both ends are kept, because they carry different things: yabs says why it is
/// about to skip a phase *before* skipping it ("less than 2GB of space
/// available"), and what it measured afterwards. A log long enough to need this
/// is one that repeated itself for a while, which is the middle.
const LOG_STORE_BYTES: usize = 512 * 1024;

/// How much of the log one poll returns to a client.
///
/// The row keeps everything that was read; what travels to a panel every couple
/// of seconds is the end of it, which is the part a page draws a progress view
/// from.
const LOG_TAIL_BYTES: usize = 64 * 1024;

/// How often the resident poller looks at a run that is going.
///
/// Short enough that a run ending is recorded promptly, long enough that the
/// shell this spawns per tick is invisible. Only spent while a `running` row
/// exists.
const POLL_INTERVAL: Duration = Duration::from_secs(2);

/// The longest working directory accepted. It is a path rather than a
/// paragraph, and it is the one user-typed value that reaches a command line —
/// quoted, but bounded here so a client cannot make the agent build an
/// arbitrarily large command from a query string.
const MAX_WORK_DIR: usize = 4096;

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

fn bad_request(error: impl Into<String>) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error: error.into() })
}

fn internal_error(error: impl Into<String>) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse { error: error.into() })
}

// --- The row ---

/// One row of `benchmark_run` — see migration `010_benchmark_run.sql`.
#[derive(Debug, Clone, FromRow)]
struct RunRow {
    id: String,
    started_at: String,
    finished_at: Option<String>,
    /// `running` | `completed` | `failed` | `cancelled`.
    status: String,
    /// [`BenchOptions`] as JSON.
    options: String,
    run_dir: String,
    result_json: Option<String>,
    log: String,
    exit_code: Option<i32>,
    /// Why a run that ended badly ended badly, as a stable code this agent's
    /// clients phrase in their own language — the same convention as a request
    /// refusal. `launcher_failed`, `nonzero_exit`, `no_exit_code`, or empty.
    error: String,
}

/// Every column of `benchmark_run`, spelled once.
///
/// A macro rather than a `const` interpolated with `format!`: sqlx refuses a
/// query assembled at runtime — it cannot tell a column list that is a
/// constant from one a caller built — and `concat!` takes literals only, so
/// this is where "once" can live.
macro_rules! select_run {
    ($tail:literal) => {
        concat!(
            "SELECT id, started_at, finished_at, status, options, run_dir, \
             result_json, log, exit_code, error FROM benchmark_run ",
            $tail
        )
    };
}

/// A run as a list row shows it: everything but the two large text columns.
#[derive(Serialize)]
struct RunView {
    id: String,
    started_at: String,
    finished_at: Option<String>,
    status: String,
    options: serde_json::Value,
    run_dir: String,
    exit_code: Option<i32>,
    error: String,
    /// Whether a result and a log are stored on this row, so a client knows
    /// whether opening it is worth a second request.
    has_result: bool,
}

impl From<RunRow> for RunView {
    fn from(row: RunRow) -> Self {
        RunView {
            has_result: row.result_json.is_some() || !row.log.is_empty(),
            id: row.id,
            started_at: row.started_at,
            finished_at: row.finished_at,
            status: row.status,
            // Tolerated rather than fatal, like the app's own reader: a row
            // whose options will not parse is still a run that happened, and
            // `{}` reads as "what it ran is not known", which is true.
            options: serde_json::from_str(&row.options).unwrap_or(serde_json::json!({})),
            run_dir: row.run_dir,
            exit_code: row.exit_code,
            error: row.error,
        }
    }
}

/// One run in full, including what it measured and what it printed.
#[derive(Serialize)]
struct RunDetail {
    #[serde(flatten)]
    run: RunView,
    /// yabs' `-w` output, verbatim and **as a string**.
    ///
    /// Not parsed here on purpose. yabs assembles it with `+=` on a shell
    /// string, so a field it could not collect arrives as an empty slot and a
    /// distro name containing a quote produces a document no parser accepts —
    /// and the client that draws it is the one that knows which fields it can
    /// live without. What the agent owes it is the document.
    result_json: Option<String>,
    log: String,
}

/// The live state of a run that is still going, polled for this request.
#[derive(Serialize)]
struct LiveView {
    id: String,
    /// Whether this is an answer at all. False means ask again — see
    /// [`BenchPollState::answered`], which this is the whole reason for.
    answered: bool,
    /// The answer was too large to read in one piece. Reported so a client can
    /// say that rather than showing a page that never changes.
    truncated: bool,
    alive: bool,
    dir_exists: bool,
    exit_code: Option<i32>,
    /// The end of the log. See [`LOG_TAIL_BYTES`].
    log: String,
    /// What the run has running, one process per line — its whole process
    /// group, which is what is actually doing the work.
    processes: String,
    result_json: Option<String>,
}

impl LiveView {
    fn of(id: &str, polled: &Polled) -> Self {
        let state = &polled.state;
        LiveView {
            id: id.to_string(),
            answered: state.answered,
            truncated: polled.truncated,
            alive: state.alive,
            dir_exists: state.dir_exists,
            exit_code: state.exit_code,
            log: log_tail(&state.log).to_string(),
            processes: state.processes.clone(),
            result_json: state.result_json.clone(),
        }
    }
}

#[derive(Serialize)]
struct ListResponse {
    runs: Vec<RunView>,
    /// The run that is going, with its state as of this request, or absent when
    /// there is none.
    #[serde(skip_serializing_if = "Option::is_none")]
    live: Option<LiveView>,
    /// Whether this caller may start one, stop one or remove one. A hint: every
    /// write re-checks the grant at the moment of use.
    editable: bool,
    /// Whether a benchmark can run on this machine at all. yabs is a shell
    /// script written for Linux and reads procfs; the agent still answers this
    /// endpoint elsewhere, so a client is told rather than left to infer it
    /// from a refusal.
    supported: bool,
}

// --- Reading ---

/// The one optional selector: a run id, for opening one run rather than the
/// list.
#[derive(Deserialize)]
pub struct GetQuery {
    /// One run in full. Absent asks for the list.
    #[serde(default)]
    run: Option<String>,
}

pub async fn get(
    req: HttpRequest,
    query: web::types::Query<GetQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let id = query.run.clone().filter(|id| !id.is_empty());
    match id {
        Some(id) => Ok(detail(&app_state, &id).await),
        None => Ok(list(&req, &app_state).await),
    }
}

/// The history, plus the run that is going if there is one.
///
/// The live state is polled here rather than left to the resident poller, so a
/// run that has just ended is reported as ended on the very request that
/// notices, rather than up to [`POLL_INTERVAL`] later. Both writers record the
/// end and only one of them wins — see [`poll_and_finalize`].
async fn list(req: &HttpRequest, app_state: &AppState) -> HttpResponse {
    let secure = ws::is_secure_transport(req, app_state.tls_active);
    let rows = match sqlx::query_as::<_, RunRow>(select_run!(
        "ORDER BY started_at DESC LIMIT ?"
    ))
    .bind(HISTORY_LIMIT)
    .fetch_all(&app_state.db)
    .await
    {
        Ok(rows) => rows,
        Err(e) => {
            tracing::warn!("benchmark: could not read the history: {e}");
            return internal_error("history_unavailable");
        }
    };

    // At most one by the partial unique index, and the loop is how that is read
    // rather than an assumption about it.
    let running = rows.iter().find(|row| row.status == "running");
    let live = match running {
        Some(row) => Some(LiveView::of(&row.id, &poll_and_finalize(app_state, row).await)),
        None => None,
    };

    HttpResponse::Ok().json(&ListResponse {
        runs: rows.into_iter().map(RunView::from).collect(),
        live,
        editable: app_state.full_access_allowed(secure),
        supported: supports_benchmark(),
    })
}

async fn detail(app_state: &AppState, id: &str) -> HttpResponse {
    let row = match sqlx::query_as::<_, RunRow>(select_run!("WHERE id = ?"))
        .bind(id)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(row)) => row,
        Ok(None) => return HttpResponse::NotFound().json(&ErrorResponse { error: "no_such_run".into() }),
        Err(e) => {
            tracing::warn!("benchmark: could not read run {id}: {e}");
            return internal_error("history_unavailable");
        }
    };
    HttpResponse::Ok().json(&RunDetail {
        run: RunView::from(row.clone()),
        result_json: row.result_json,
        log: row.log,
    })
}

// --- Writing ---

#[derive(Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum BenchAction {
    Start {
        #[serde(default)]
        options: BenchOptions,
    },
    Cancel,
    /// What a set of options would cost, for a form to show before anyone
    /// commits to it.
    ///
    /// An action rather than a route of its own because the answer is a
    /// function of the body, and because the alternative — the options in a
    /// query string — is a JSON document in a URL.
    Estimate {
        #[serde(default)]
        options: BenchOptions,
    },
}

#[derive(Serialize)]
struct StartedResponse {
    run: RunView,
}

#[derive(Serialize)]
struct EstimateResponse {
    estimate: bench::BenchEstimate,
    /// Whether this set of options asks for anything at all: everything off
    /// still collects the system information header, which takes seconds and is
    /// a legitimate thing to want.
    system_info_only: bool,
}

#[derive(Serialize)]
struct CancelResponse {
    /// Whether a run was there to stop. False is not an error: the caller
    /// asked, and the answer is that there was nothing.
    cancelled: bool,
}

pub async fn act(
    req: HttpRequest,
    body: web::types::Json<BenchAction>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let action = body.into_inner();

    // The estimate changes nothing and needs no grant beyond the login that
    // already got this far, so it is answered before the gate below.
    if let BenchAction::Estimate { options } = &action {
        return Ok(HttpResponse::Ok().json(&EstimateResponse {
            estimate: bench::estimate(options),
            system_info_only: options.is_system_info_only(),
        }));
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    // Re-checked at the moment of use rather than trusted from the `editable`
    // the client was told earlier: that answer is a UI hint, and the UI is not
    // a boundary.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Benchmark, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    match action {
        BenchAction::Start { options } => start(&app_state, options, remote_ip).await,
        BenchAction::Cancel => cancel(&app_state, remote_ip).await,
        // Answered above.
        BenchAction::Estimate { .. } => unreachable!("handled before the grant check"),
    }
}

async fn start(
    app_state: &AppState,
    options: BenchOptions,
    remote_ip: Option<String>,
) -> Result<HttpResponse, web::Error> {
    if !supports_benchmark() {
        return Ok(bad_request("unsupported_platform"));
    }
    if options.work_dir.len() > MAX_WORK_DIR {
        return Ok(bad_request("work_dir_too_long"));
    }

    let Some(script_path) = script_path_on_disk() else {
        // No `HOME`. The command layer would send a literal `$HOME` and every
        // command would operate on a directory of that name, which is why this
        // is refused here rather than attempted.
        return Ok(internal_error("no_home_directory"));
    };
    let Some(body) = bench::decode_asset(SCRIPT_ASSET_B64) else {
        // A packaging mistake rather than a runtime one. Reported rather than
        // run: what it would otherwise send is a shell script of replacement
        // characters.
        tracing::error!("benchmark: the embedded yabs asset did not decode");
        return Ok(internal_error("asset_unreadable"));
    };

    let run_id = match crate::utils::secrets::random_hex(8) {
        Ok(suffix) => format!(
            "bench_{}_{suffix}",
            chrono::Utc::now().format("%Y%m%d%H%M%S")
        ),
        Err(e) => {
            tracing::error!("benchmark: no entropy for a run id: {e}");
            return Ok(internal_error("no_entropy"));
        }
    };
    let run_dir = bench::run_dir(&options.work_dir);

    // The script is written before the run is recorded, because a row naming a
    // directory is a claim that something is going to be in it.
    if let Err(e) = crate::monitoring::ensure_script(&script_path, &body) {
        tracing::error!("benchmark: could not write {}: {e}", script_path.display());
        return Ok(internal_error("script_not_writable"));
    }

    let options_json = serde_json::to_string(&options).unwrap_or_else(|_| "{}".into());
    let insert = sqlx::query(
        "INSERT INTO benchmark_run (id, started_at, finished_at, status, options, run_dir) \
         VALUES (?, ?, NULL, 'running', ?, ?)",
    )
    .bind(&run_id)
    .bind(chrono::Utc::now())
    .bind(&options_json)
    .bind(&run_dir)
    .execute(&app_state.db)
    .await;

    if let Err(e) = insert {
        // A run is already going. The partial unique index is what says so, and
        // it says it once rather than in a check two concurrent starts would
        // both have passed.
        if is_unique_violation(&e) {
            return Ok(HttpResponse::Conflict().json(&ErrorResponse {
                error: "already_running".into(),
            }));
        }
        tracing::error!("benchmark: could not record a run: {e}");
        return Ok(internal_error("history_unavailable"));
    }

    // The launcher arrives on stdin, so nothing about the run — the flags, the
    // paths, the working directory — is on a command line, and the command
    // layer's own quoting is the only thing between a typed path and the shell.
    //
    // `start_entry` is already wrapped by `bench::posix`, which exists because
    // the app reaches a machine through a login shell that may be fish or csh.
    // Here the shell is spawned by name, so the wrapper is one `sh` more than
    // this needs — and it stays, because the string sent is then the exact
    // string the app sends, and a second unwrapped accessor would be a second
    // thing to keep in step.
    let mut command = tokio::process::Command::new("sh");
    command
        .arg("-c")
        .arg(bench::start_entry(&options, &run_id))
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    let started = command::run(
        command,
        "benchmark start",
        Limits::with_timeout(Duration::from_secs(30)),
        Some(bench::launcher(&options).as_bytes()),
    )
    .await;

    let confirmed = matches!(
        &started,
        Ok(Some(output))
            if output.status.success()
                && String::from_utf8_lossy(&output.stdout).contains(bench::STARTED)
    );
    if !confirmed {
        // The row is what blocks the next start by the unique index, so a start
        // that did not happen has to leave it terminal rather than running.
        let reason = match &started {
            Ok(Some(output)) => format!("exit {:?}", output.status.code()),
            Ok(None) => "timed out".to_string(),
            Err(e) => e.to_string(),
        };
        let _ = sqlx::query(
            "UPDATE benchmark_run SET status = 'failed', finished_at = ?, error = ? \
             WHERE id = ? AND status = 'running'",
        )
        .bind(chrono::Utc::now())
        .bind(RunError::LauncherFailed.as_str())
        .bind(&run_id)
        .execute(&app_state.db)
        .await;
        Event::new(Kind::Benchmark, Action::Open, Outcome::Error)
            .remote_ip(remote_ip)
            .subject(&run_id)
            .detail(format!("launcher did not start: {reason}"))
            .record(&app_state.db)
            .await;
        return Ok(internal_error("start_failed"));
    }

    Event::new(Kind::Benchmark, Action::Open, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(&run_id)
        .record(&app_state.db)
        .await;

    match sqlx::query_as::<_, RunRow>(select_run!("WHERE id = ?"))
        .bind(&run_id)
        .fetch_one(&app_state.db)
        .await
    {
        Ok(row) => Ok(HttpResponse::Ok().json(&StartedResponse { run: RunView::from(row) })),
        Err(e) => {
            tracing::warn!("benchmark: started {run_id} but could not read it back: {e}");
            Ok(internal_error("history_unavailable"))
        }
    }
}

async fn cancel(
    app_state: &AppState,
    remote_ip: Option<String>,
) -> Result<HttpResponse, web::Error> {
    let Some(row) = running_row(&app_state.db).await else {
        return Ok(HttpResponse::Ok().json(&CancelResponse { cancelled: false }));
    };

    // A `sleep 2` sits between the TERM and the KILL, so this is slower than
    // the other commands here and the timeout allows for it.
    let mut command = tokio::process::Command::new("sh");
    command
        .arg("-c")
        .arg(bench::cancel_command(&row.run_dir));
    let result = command::run(
        command,
        "benchmark cancel",
        Limits::with_timeout(Duration::from_secs(30)),
        None,
    )
    .await;
    let stopped = matches!(
        &result,
        Ok(Some(output)) if String::from_utf8_lossy(&output.stdout).contains(bench::CANCELLED)
    );

    // The row is not written here. The cancel command writes the run's exit
    // file, and the state comes from a poll like any other — an exit code the
    // agent asserted would be its word rather than the machine's.
    if stopped {
        // Polled once so the caller's next read already has the end of it,
        // rather than a page that shows a run going for another two seconds.
        poll_and_finalize(app_state, &row).await;
    }

    Event::new(
        Kind::Benchmark,
        Action::Close,
        if stopped { Outcome::Ok } else { Outcome::Error },
    )
    .remote_ip(remote_ip)
    .subject(&row.id)
    .detail(if stopped { "stopped" } else { "could not stop" })
    .record(&app_state.db)
    .await;

    Ok(HttpResponse::Ok().json(&CancelResponse { cancelled: stopped }))
}

#[derive(Deserialize)]
pub struct RemoveQuery {
    run: String,
}

pub async fn remove(
    req: HttpRequest,
    query: web::types::Query<RemoveQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Benchmark, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let id = &query.run;
    let Some(row) = row_by_id(&app_state.db, id).await else {
        return Ok(HttpResponse::NotFound().json(&ErrorResponse { error: "no_such_run".into() }));
    };
    if row.status == "running" {
        // Removing the record would lose the only handle on a live process.
        // Cancelling is the way to end it, and it is one request away.
        return Ok(bad_request("run_in_progress"));
    }

    if let Err(e) = sqlx::query("DELETE FROM benchmark_run WHERE id = ?")
        .bind(id)
        .execute(&app_state.db)
        .await
    {
        tracing::warn!("benchmark: could not remove run {id}: {e}");
        return Ok(internal_error("history_unavailable"));
    }
    // Best effort, and after the row: the record is what a user asked to be rid
    // of. A directory that survives this is one the run already cleaned up, or
    // one whose marker does not match — which the command refuses rather than
    // removing.
    cleanup(&row.run_dir, id).await;

    Event::new(Kind::Benchmark, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(id)
        .record(&app_state.db)
        .await;

    Ok(HttpResponse::Ok().finish())
}

// --- Watching ---

/// Starts the poller that carries a run to a terminal state on its own.
///
/// The reason it exists is that a browser is not resident and the agent is: a
/// run started from a panel, with the tab closed a minute later, still has to
/// end up recorded — otherwise the row stays `running` for good, and the
/// partial unique index that keeps one run at a time would refuse every future
/// start with nothing to explain it.
pub fn start_poller(app_state: Arc<AppState>) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(POLL_INTERVAL);
        loop {
            interval.tick().await;
            // The query is what makes this cost nothing while no run is going:
            // it is a lookup on an index over `status`, and the shell the poll
            // spawns happens only when it finds something.
            let Some(row) = running_row(&app_state.db).await else {
                continue;
            };
            let polled = poll_and_finalize(&app_state, &row).await;
            if !polled.state.answered {
                tracing::debug!(
                    "benchmark: no answer for {} — the machine may be busy",
                    row.id
                );
            }
        }
    });
}

/// A poll, and what it could not do.
struct Polled {
    state: BenchPollState,
    /// The answer was too large to read in one piece.
    truncated: bool,
}

/// Runs one poll on this machine.
async fn poll(run_dir: &str) -> Polled {
    let mut command = tokio::process::Command::new("sh");
    command.arg("-c").arg(bench::poll_command(run_dir));
    let limits = Limits {
        timeout: POLL_TIMEOUT,
        max_output_bytes: POLL_MAX_OUTPUT,
    };
    match command::run(command, "benchmark poll", limits, None).await {
        Ok(Some(output)) => Polled {
            state: BenchPollState::parse(&String::from_utf8_lossy(&output.stdout)),
            truncated: false,
        },
        // A timeout and a spawn failure both answer "not answered", which is
        // the same thing to a caller: ask again. An output past the cap is
        // told apart because a page that never changes should be able to say
        // why.
        Err(e) if command::is_output_overflow(&e) => Polled {
            state: BenchPollState::default(),
            truncated: true,
        },
        Ok(None) => Polled {
            state: BenchPollState::default(),
            truncated: false,
        },
        Err(e) => {
            tracing::debug!("benchmark: poll of {run_dir} failed: {e}");
            Polled {
                state: BenchPollState::default(),
                truncated: false,
            }
        }
    }
}

/// Polls one run and, if it has ended, records that and cleans up after it.
///
/// Called from two places — a panel's read and the resident poller — and the
/// write is conditional on the row still being `running`, so whichever of the
/// two notices first is the one that records it and removes the directory; the
/// other's update matches no row and does nothing. That is what makes a read
/// safe to have a side effect at all.
async fn poll_and_finalize(app_state: &AppState, row: &RunRow) -> Polled {
    let polled = poll(&row.run_dir).await;
    let Some(ended) = terminal_of(&polled.state) else {
        return polled;
    };

    let written = sqlx::query(
        "UPDATE benchmark_run SET status = ?, finished_at = ?, exit_code = ?, \
         result_json = ?, log = ?, error = ? WHERE id = ? AND status = 'running'",
    )
    .bind(ended.status)
    .bind(chrono::Utc::now())
    .bind(polled.state.exit_code)
    .bind(polled.state.result_json.as_deref())
    .bind(stored_log(&polled.state.log))
    .bind(ended.error.map(RunError::as_str))
    .bind(&row.id)
    .execute(&app_state.db)
    .await;

    match written {
        Ok(done) if done.rows_affected() == 1 => {
            // After the result is stored, never before: the bytes are what the
            // user waited fifteen minutes for, and a `rm` that failed must not
            // be what withholds them.
            cleanup(&row.run_dir, &row.id).await;
            prune(&app_state.db).await;
        }
        Ok(_) => {}
        Err(e) => tracing::warn!("benchmark: could not record the end of {}: {e}", row.id),
    }

    polled
}

/// How a run that has ended is recorded, or `None` while it is still going.
struct Ended {
    status: &'static str,
    error: Option<RunError>,
}

/// Why a run ended badly, as the code its client phrases in its own language.
///
/// A closed set rather than a sentence this agent writes: the row is drawn in a
/// fifteen-language panel, and the same treatment as a request refusal is what
/// keeps English out of it. The exit code itself is in its own column; this
/// says only what the code alone cannot.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum RunError {
    /// The start command ran, and the launcher it wrote did not.
    LauncherFailed,
    /// Exited with a code that is neither zero nor the cancellation code.
    NonzeroExit,
    /// The process went away and wrote no exit code, which is what the OOM
    /// killer looks like from here.
    NoExitCode,
}

impl RunError {
    const fn as_str(self) -> &'static str {
        match self {
            RunError::LauncherFailed => "launcher_failed",
            RunError::NonzeroExit => "nonzero_exit",
            RunError::NoExitCode => "no_exit_code",
        }
    }
}

fn terminal_of(state: &BenchPollState) -> Option<Ended> {
    // Without an answer there is nothing to conclude. Reading the all-zero
    // state `BenchPollState::default` produces as "the run is gone" is exactly
    // what `answered` exists to prevent.
    if !state.answered {
        return None;
    }
    if let Some(code) = state.exit_code {
        return Some(match code {
            0 => Ended {
                status: "completed",
                error: None,
            },
            bench::CANCELLED_EXIT_CODE => Ended {
                status: "cancelled",
                error: None,
            },
            // The code is in its own column; this says only that the run ended
            // badly, which is what a list row has room for.
            _ => Ended {
                status: "failed",
                error: Some(RunError::NonzeroExit),
            },
        });
    }
    if state.died_without_reporting() {
        return Some(Ended {
            status: "failed",
            // What an out-of-memory kill looks like from here, and the OOM
            // killer is the ordinary way a benchmark on a small VPS ends this
            // way — Geekbench is the usual cause.
            error: Some(RunError::NoExitCode),
        });
    }
    None
}

/// Removes a run's directory, best effort.
///
/// The command refuses a directory whose `owner` marker is not this run's, so a
/// path built from a working directory the user typed cannot become an `rm -rf`
/// of somebody else's directory — including the live run's, which shares the
/// run directory name whenever the working directory is the same.
///
/// A failure is logged and nothing else: what is left behind is a 2 GB fio file
/// when the run was cancelled mid-disk-test, and nothing else in the agent
/// would mention it.
async fn cleanup(run_dir: &str, run_id: &str) {
    let Some(command_text) = bench::cleanup_command(run_dir, run_id) else {
        return;
    };
    let mut command = tokio::process::Command::new("sh");
    command.arg("-c").arg(command_text);
    if let Err(e) = command::run(
        command,
        "benchmark cleanup",
        Limits::with_timeout(Duration::from_secs(30)),
        None,
    )
    .await
    {
        tracing::warn!("benchmark: cleanup of {run_dir} failed: {e}");
    }
}

/// Drops the oldest runs past [`HISTORY_LIMIT`].
async fn prune(pool: &SqlitePool) {
    let deleted = sqlx::query(
        "DELETE FROM benchmark_run WHERE id IN ( \
           SELECT id FROM benchmark_run WHERE status != 'running' \
           ORDER BY started_at DESC LIMIT -1 OFFSET ? \
         )",
    )
    .bind(HISTORY_LIMIT)
    .execute(pool)
    .await;
    if let Err(e) = deleted {
        tracing::warn!("benchmark: could not prune the history: {e}");
    }
}

// --- Small helpers ---

async fn running_row(pool: &SqlitePool) -> Option<RunRow> {
    sqlx::query_as::<_, RunRow>(select_run!("WHERE status = 'running' LIMIT 1"))
        .fetch_optional(pool)
    .await
    .unwrap_or_else(|e| {
        tracing::warn!("benchmark: could not look for a running run: {e}");
        None
    })
}

async fn row_by_id(pool: &SqlitePool, id: &str) -> Option<RunRow> {
    sqlx::query_as::<_, RunRow>(select_run!("WHERE id = ?"))
        .bind(id)
        .fetch_optional(pool)
        .await
        .unwrap_or_else(|e| {
            tracing::warn!("benchmark: could not read run {id}: {e}");
            None
        })
}

/// Whether yabs can run on this machine.
///
/// Linux only. yabs is a `#!/bin/bash` script that reads `/proc` and installs
/// Debian packages; the Windows and BSD paths this crate carries for status
/// collection have nothing to do with it, and a client told `true` would offer
/// a Run button whose only outcome is a confusing refusal.
///
/// Answered to the client as the listing's `supported`, not as
/// `remote_access.benchmark`: the endpoint is served on every platform, and it
/// is the page that says why a run cannot happen here.
fn supports_benchmark() -> bool {
    matches!(crate::monitoring::system_type(), sbm_parser::SystemType::Linux)
}

/// The script's path on this machine, resolved rather than left to a shell.
///
/// [`bench::script_path`] carries a literal `$HOME` so a *caller* can hand it to
/// a shell; here the agent is writing the file itself and needs a real path.
/// Both resolve against the same environment: the shell commands below are
/// spawned by this process and inherit its `HOME`, so the file written here is
/// the file the launcher executes.
fn script_path_on_disk() -> Option<std::path::PathBuf> {
    let home = std::env::var_os("HOME")?;
    Some(std::path::PathBuf::from(home).join(bench::BASE_DIR_RELATIVE).join(bench::script_file_name()))
}

fn is_unique_violation(error: &sqlx::Error) -> bool {
    matches!(error, sqlx::Error::Database(e) if e.is_unique_violation())
}

/// The largest byte index at or below `index` that is a character boundary.
fn floor_boundary(text: &str, index: usize) -> usize {
    let mut end = index.min(text.len());
    while end > 0 && !text.is_char_boundary(end) {
        end -= 1;
    }
    end
}

/// The smallest byte index at or above `index` that is a character boundary.
fn ceil_boundary(text: &str, index: usize) -> usize {
    let mut start = index.min(text.len());
    while start < text.len() && !text.is_char_boundary(start) {
        start += 1;
    }
    start
}

/// The end of a log, up to [`LOG_TAIL_BYTES`], cut at a character boundary so a
/// multi-byte character is never split.
fn log_tail(log: &str) -> &str {
    &log[ceil_boundary(log, log.len().saturating_sub(LOG_TAIL_BYTES))..]
}

/// What a row keeps of a log. See [`LOG_STORE_BYTES`].
fn stored_log(log: &str) -> String {
    if log.len() <= LOG_STORE_BYTES {
        return log.to_string();
    }
    let half = LOG_STORE_BYTES / 2;
    let head = floor_boundary(log, half);
    let tail_start = ceil_boundary(log, log.len() - half);
    format!(
        "{}\n\n... {} bytes omitted ...\n\n{}",
        &log[..head],
        tail_start - head,
        &log[tail_start..]
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ended(exit_code: Option<i32>, alive: bool, dir_exists: bool, launcher_started: bool) -> BenchPollState {
        BenchPollState {
            answered: true,
            exit_code,
            alive,
            dir_exists,
            launcher_started,
            ..Default::default()
        }
    }

    #[test]
    fn an_unanswered_poll_concludes_nothing() {
        // What a transport's own timeout produces. Reading this as a finished
        // run would fail a benchmark that is going fine.
        assert!(terminal_of(&BenchPollState::default()).is_none());
    }

    #[test]
    fn the_exit_code_decides_the_status() {
        let completed = terminal_of(&ended(Some(0), false, true, true)).unwrap();
        assert_eq!(completed.status, "completed");
        assert!(completed.error.is_none());

        let cancelled = terminal_of(&ended(Some(bench::CANCELLED_EXIT_CODE), false, true, true)).unwrap();
        assert_eq!(cancelled.status, "cancelled");

        let failed = terminal_of(&ended(Some(1), false, true, true)).unwrap();
        assert_eq!(failed.status, "failed");
        // The code itself lives in its own column.
        assert_eq!(failed.error, Some(RunError::NonzeroExit));
    }

    /// The three codes are a contract with a client in another language — the
    /// panel spells each of them into a sentence. A rename here is a row that
    /// client can only show as the code itself, so it is pinned rather than
    /// left to the enum's shape.
    #[test]
    fn a_run_that_ended_badly_records_a_phraseable_code() {
        assert_eq!(RunError::LauncherFailed.as_str(), "launcher_failed");
        assert_eq!(RunError::NonzeroExit.as_str(), "nonzero_exit");
        assert_eq!(RunError::NoExitCode.as_str(), "no_exit_code");
    }

    #[test]
    fn a_run_that_vanished_without_an_exit_code_failed() {
        let died = terminal_of(&ended(None, false, true, true)).unwrap();
        assert_eq!(died.status, "failed");

        // The window between the start command returning and the launcher
        // running its first line. A directory, no process, no exit code — and
        // not a failure.
        assert!(terminal_of(&ended(None, false, true, false)).is_none());
        // A directory that was never here at all, which is what a cleaned-up
        // run looks like from a poll that arrives afterwards.
        assert!(terminal_of(&ended(None, false, false, false)).is_none());
        // Still going.
        assert!(terminal_of(&ended(None, true, true, true)).is_none());
    }

    #[test]
    fn a_long_log_keeps_both_ends_of_it() {
        // The beginning says why a phase was skipped, the end says what was
        // measured. A cut that kept one would lose a fact the log is kept for.
        let head = "LESS THAN 2GB AVAILABLE\n";
        let middle = "x".repeat(LOG_STORE_BYTES * 2);
        let tail = "\nEND OF RUN\n";
        let stored = stored_log(&format!("{head}{middle}{tail}"));

        assert!(stored.starts_with(head), "the head was dropped");
        assert!(stored.ends_with(tail), "the tail was dropped");
        assert!(stored.contains("bytes omitted"));
        assert!(stored.len() < LOG_STORE_BYTES + 128);
    }

    #[test]
    fn a_short_log_is_stored_whole() {
        let log = "everything yabs printed";
        assert_eq!(stored_log(log), log);
    }

    #[test]
    fn a_tail_never_splits_a_character() {
        // Each of these is three bytes, so a cut at a fixed offset would land
        // inside one — and `&log[..]` on a non-boundary panics.
        let log = "中".repeat(LOG_TAIL_BYTES);
        let tail = log_tail(&log);
        assert!(tail.len() <= LOG_TAIL_BYTES);
        assert!(log.ends_with(tail));

        let stored = stored_log(&log);
        assert!(stored.starts_with('中') && stored.ends_with('中'));
    }

}
