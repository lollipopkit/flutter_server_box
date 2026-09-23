//! `GET/PUT /api/v1/cron` — the scheduled tasks of the account the agent runs
//! as.
//!
//! # Why this is not `/exec`
//!
//! The whole feature is one crontab file: read it, change one line, write it
//! back. Sending [`sbm_parser::cron::LIST_SCRIPT`] and `crontab -` through
//! `/exec` would work, and it is what the app does over SSH — but the part that
//! decides *which line* a job is, what a disabled job looks like on disk and
//! what may not be written at all is a model, not a command, and three callers
//! would each reimplement it. It lives in
//! [`sbm_parser::cron`] instead, so the app and this endpoint read the same
//! file the same way.
//!
//! An edit is expressed as an operation on one line rather than as a whole
//! document, which is the second half of that: a client that round-tripped the
//! text would be the thing that decides how a disabled line is spelled, and a
//! client that got it slightly wrong would rewrite a file it does not own.
//! The read is redone at the moment of the write, so a save never writes back
//! a listing taken minutes ago — only the line index can be stale.
//!
//! # What this manages
//!
//! `crontab` itself: the account's own crontab, as the command means. Not
//! `/etc/cron.d`, not `-u` for another account, not systemd timers. Reading it
//! is the agent's own user's schedule, which the panel login may see, the same
//! as the custom commands — writing it is arranging for code to run on a timer
//! as that user, which is `full_access`.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::process::Command;

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::monitoring::system_type;
use crate::utils::command::{self, Limits};

/// The listing is one crontab, so this is generous; the cap is here so a
/// runaway `crontab` cannot make the agent buffer without bound.
const MAX_LIST_BYTES: u64 = 4 * 1024 * 1024;

#[derive(Serialize)]
struct CronListResponse {
    /// Whether the crontab could be read at all. `false` is a state of the
    /// machine — no `crontab(1)`, a platform that has none — not a failure of
    /// the caller, so it is a field rather than a status code, and the panel
    /// has one page to draw either way.
    available: bool,
    /// Which of the known reasons it was, so the panel phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something this endpoint does not classify, and `reason` is it.
    reason_kind: Option<CronReason>,
    /// What the machine said, verbatim. Never translated and never classified
    /// away: it is the only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// The account whose crontab this is, as the machine named it.
    user: Option<String>,
    /// The agent machine's wall clock when it was read, `YYYY-MM-DDTHH:MM`.
    ///
    /// Cron matches an expression against the server's own clock, and this is
    /// the one reading of it that came from the machine itself — a client that
    /// used its own would name a time the job will not run at.
    now: Option<String>,
    jobs: Vec<sbm_parser::cron::CronJobView>,
    /// Comments, environment assignments and anything else that is not a job.
    /// A client shows them so a crontab another tool manages does not look like
    /// it lost them.
    preserved: Vec<String>,
    /// Whether this caller may change the schedule. The editor asks so it can
    /// show a read-only view instead of failing on save; the answer is
    /// re-checked on the write itself, since a UI hint is not a boundary.
    editable: bool,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum CronReason {
    /// No `crontab(1)` on the machine.
    NotInstalled,
    /// Windows, where `crontab` does not exist and `sh` cannot run the listing.
    UnsupportedPlatform,
    /// The listing ran and its output was not the script's own.
    Unreadable,
}

/// One change to one line.
///
/// The line is addressed by index into the listing the client was given. What
/// is at that index is re-read here, so an index that no longer names a job is
/// refused rather than overwriting whatever moved into its place.
#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum CronEdit {
    /// Replaces the job at `line_index`, or appends when it is `null`.
    Upsert {
        #[serde(default)]
        line_index: Option<usize>,
        schedule: String,
        command: String,
        enabled: bool,
    },
    Remove {
        line_index: usize,
    },
    SetEnabled {
        line_index: usize,
        enabled: bool,
    },
}

impl CronEdit {
    /// What the audit row says about it. The schedule, never the command: a
    /// command is free text that may hold a token, and this column never
    /// does.
    fn subject(&self) -> String {
        match self {
            Self::Upsert {
                schedule,
                line_index,
                ..
            } => match line_index {
                Some(index) => format!("upsert line {index}: {schedule}"),
                None => format!("append: {schedule}"),
            },
            Self::Remove { line_index } => format!("remove line {line_index}"),
            Self::SetEnabled { line_index, enabled } => format!(
                "{} line {line_index}",
                if *enabled { "enable" } else { "disable" }
            ),
        }
    }
}

#[derive(Serialize)]
struct ErrorResponse {
    /// The [`sbm_parser::cron::CronValidation`] case, so the panel shows its
    /// own sentence rather than a server's English one.
    error: String,
}

/// Reads the crontab and reports it.
pub async fn list(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    Ok(HttpResponse::Ok().json(&read_crontab(editable).await))
}

/// Applies one change and answers with the listing as it now stands.
pub async fn edit(
    req: HttpRequest,
    body: web::types::Json<CronEdit>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    // Re-checked at the moment of use rather than trusted from the capabilities
    // the client was told earlier: that answer is a UI hint, and the UI is not
    // a boundary.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Cron, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let edit = body.into_inner();

    // Before the machine is touched at all. What a client sent is the client's
    // to get right, and a refusal that depended on whether this machine has a
    // `crontab(1)` would be two different answers to one mistake.
    if let CronEdit::Upsert {
        schedule, command, ..
    } = &edit
        && let Some(validation) = sbm_parser::cron::validate(schedule, command)
    {
        return Ok(HttpResponse::BadRequest().json(&ErrorResponse {
            error: validation.to_string(),
        }));
    }

    // Read before writing, so the edit lands on the file as it is now. A
    // client's listing can be minutes old, and writing back a document
    // assembled from it would revert whatever was added in between.
    let catalog = match read_document().await {
        Ok(catalog) => catalog,
        Err(unavailable) => {
            return Ok(HttpResponse::Ok().json(&CronListResponse::unavailable(unavailable, true)));
        }
    };

    let applied = match &edit {
        CronEdit::Upsert {
            line_index,
            schedule,
            command,
            enabled,
        } => catalog
            .document
            .upsert(*line_index, schedule, command, *enabled),
        CronEdit::Remove { line_index } => catalog.document.remove(*line_index),
        CronEdit::SetEnabled { line_index, enabled } => {
            catalog.document.set_enabled(*line_index, *enabled)
        }
    };
    let document = match applied {
        Ok(document) => document,
        // An index that no longer names a job: the listing moved under the
        // client. Refused rather than applied to whatever is there now.
        Err(validation) => {
            return Ok(HttpResponse::BadRequest().json(&ErrorResponse {
                error: validation.to_string(),
            }));
        }
    };

    // One row, written after the outcome is known rather than before it: the
    // change either landed or it did not, and a row announcing an attempt the
    // machine then refused would be the log's word against the crontab's.
    let written = write_document(&document.render()).await;
    match &written {
        Ok(()) => {
            Event::new(Kind::Cron, Action::Write, Outcome::Ok)
                .remote_ip(remote_ip)
                .subject(edit.subject())
                .record(&app_state.db)
                .await;
        }
        Err(unavailable) => {
            Event::new(Kind::Cron, Action::Write, Outcome::Error)
                .remote_ip(remote_ip)
                .subject(edit.subject())
                .detail(format!("write failed: {:?}", unavailable.kind))
                .record(&app_state.db)
                .await;
        }
    }
    if let Err(unavailable) = written {
        return Ok(HttpResponse::Ok().json(&CronListResponse::unavailable(unavailable, true)));
    }

    // Re-read rather than reusing `document`: what was just written is the
    // machine's now, and only the machine can say it took it. It also keeps one
    // shape for "here is the schedule" across both endpoints.
    Ok(HttpResponse::Ok().json(&read_crontab(true).await))
}

/// Why the crontab cannot be read or written, in a form the panel can phrase
/// itself and the text it can fall back to.
struct Unavailable {
    kind: CronReason,
    text: Option<String>,
}

impl CronListResponse {
    fn unavailable(reason: Unavailable, editable: bool) -> Self {
        Self {
            available: false,
            reason_kind: Some(reason.kind),
            reason: reason.text,
            user: None,
            now: None,
            jobs: Vec::new(),
            preserved: Vec::new(),
            editable,
        }
    }
}

/// The crontab as the machine has it, or why it has none to give.
async fn read_document() -> Result<sbm_parser::cron::CronCatalog, Unavailable> {
    let unreadable = |text: Option<String>| Unavailable {
        kind: CronReason::Unreadable,
        text,
    };
    if system_type() == sbm_parser::SystemType::Windows {
        // `crontab` is a Unix command and the listing runs under `sh`.
        return Err(Unavailable {
            kind: CronReason::UnsupportedPlatform,
            text: None,
        });
    }

    let mut command = Command::new("sh");
    command.arg("-c").arg(sbm_parser::cron::LIST_SCRIPT);
    let Some(output) = run(command, "crontab -l", None).await else {
        return Err(unreadable(Some("the listing timed out".to_owned())));
    };
    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
    let exit_code = output.status.code();

    if !output.status.success() {
        // A crontab that does not exist yet is the state of every server before
        // its first job, and it has to be an empty document the user can add
        // to, not an error — every implementation exits 1 for it, the same as
        // for a real failure.
        let no_crontab =
            exit_code == Some(1) && sbm_parser::cron::is_no_crontab(&stderr);
        if !no_crontab {
            if exit_code == Some(sbm_parser::cron::NOT_INSTALLED_EXIT) {
                return Err(Unavailable {
                    kind: CronReason::NotInstalled,
                    text: None,
                });
            }
            let detail = if stderr.trim().is_empty() {
                stdout.trim()
            } else {
                stderr.trim()
            };
            return Err(unreadable((!detail.is_empty()).then(|| detail.to_owned())));
        }
    }

    sbm_parser::cron::parse_list(&stdout).map_err(|e| unreadable(Some(e.to_string())))
}

/// The same read, as the response body both endpoints answer with.
async fn read_crontab(editable: bool) -> CronListResponse {
    let catalog = match read_document().await {
        Ok(catalog) => catalog,
        Err(unavailable) => return CronListResponse::unavailable(unavailable, editable),
    };
    // Absent when the machine's `date` could not say what its offset is — an
    // old agent, or a `date` without `%z`. The schedule still lists; only the
    // next run cannot be placed.
    let now = catalog.clock.map(|clock| clock.now_wall());
    CronListResponse {
        available: true,
        reason_kind: None,
        reason: None,
        user: Some(catalog.user),
        now: now.map(|at| at.to_iso()),
        jobs: catalog
            .document
            .jobs()
            .iter()
            .map(|job| job.view(now))
            .collect(),
        preserved: catalog
            .document
            .preserved()
            .into_iter()
            .map(str::to_owned)
            .collect(),
        editable,
    }
}

/// Replaces the account's crontab with `document`.
///
/// `crontab -` and not `crontab <file>`: the document goes in on stdin, so it
/// never lands in the machine's process list or in a temporary file, and there
/// is nothing to clean up if this does not finish.
async fn write_document(document: &str) -> Result<(), Unavailable> {
    let mut command = Command::new("crontab");
    command.arg("-");
    let Some(output) = run(command, "crontab -", Some(document.as_bytes())).await else {
        return Err(Unavailable {
            kind: CronReason::Unreadable,
            text: Some("the write timed out".to_owned()),
        });
    };
    if output.status.success() {
        return Ok(());
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let detail = if stderr.trim().is_empty() {
        stdout.trim()
    } else {
        stderr.trim()
    };
    Err(Unavailable {
        kind: CronReason::Unreadable,
        text: (!detail.is_empty()).then(|| detail.to_owned()),
    })
}

/// Runs a local command with a byte cap of its own.
///
/// `None` for a timeout, matching [`command::run`]. The overflow case is folded
/// into the same answer: either way there is no output to parse, and the caller
/// reports it as "could not read" rather than as a crash.
async fn run(
    command: Command,
    label: &str,
    stdin: Option<&[u8]>,
) -> Option<std::process::Output> {
    let limits = Limits {
        max_output_bytes: MAX_LIST_BYTES,
        ..Limits::DEFAULT
    };
    match command::run(command, label, limits, stdin).await {
        Ok(output) => output,
        Err(e) if command::is_output_overflow(&e) => None,
        Err(e) => {
            tracing::warn!("cron: {label}: {e}");
            None
        }
    }
}
