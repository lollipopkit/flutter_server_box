//! `POST /api/v1/exec` — run one command and hand back what it printed.
//!
//! The pages that list processes, units and containers, and the ones that run
//! a snippet or power the machine down, all want the same thing: a command
//! goes out, its output comes back. Over SSH that is a second channel on an
//! existing connection; here it is a request, which is the shape those callers
//! wanted anyway — none of them streams, and none of them types.
//!
//! Not the terminal endpoint with an `exec` message bolted on. A PTY is one
//! stream shared with whatever the user is typing, so a command written into
//! it lands in their shell and its output is indistinguishable from theirs.
//! That is why `terminal.rs` refuses an `exec` frame, and why this is a
//! separate door rather than a wider one.
//!
//! Gated on `remote_access.full_access`, the same grant the shell needs and
//! for the same reason: anyone who can open a shell can run anything in it, so
//! there is one decision here, not two.

use std::collections::HashMap;
use std::process::Stdio;
use std::sync::Arc;
use std::time::Duration;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use super::server::verify_auth;
use super::ws;

/// Long enough for a package listing on a slow disk, short enough that a
/// command waiting on input nobody will type does not hold a worker forever.
const TIMEOUT: Duration = Duration::from_secs(60);

/// The largest request body accepted, which is `stdin` plus the command.
///
/// Generous next to what the app sends — a password, or a status script of a
/// few KiB — and bounded, so one caller cannot make the agent buffer whatever
/// it likes before the command has even started.
pub const MAX_REQUEST: usize = 1024 * 1024;

/// What is kept of each stream. A caller parsing `ps` output does not need
/// more, and an unbounded read is a way for one command to exhaust memory.
const MAX_OUTPUT: usize = 1024 * 1024;

#[derive(Deserialize)]
pub struct ExecRequest {
    /// Handed to a shell as the command to run, so it may be a pipeline or
    /// several lines. This is what the audit log records.
    cmd: String,
    /// Written to the command's own stdin — how a sudo password gets in
    /// without a terminal to type it into.
    ///
    /// Never logged, which is the point of it being a separate field: a
    /// password written into [`ExecRequest::cmd`] would land in the audit row
    /// below and in the machine's process list.
    #[serde(default)]
    stdin: Option<String>,
    /// Added to the command's environment. A field rather than `export` lines
    /// the caller prepends, so a value with a quote or a newline in it does
    /// not have to survive a round of shell quoting.
    #[serde(default)]
    env: Option<HashMap<String, String>>,
}

#[derive(Serialize)]
struct ExecResponse {
    /// Null when the process was killed rather than exiting.
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
    /// Whether either stream hit [`MAX_OUTPUT`], so a caller knows the output
    /// it is parsing is a prefix.
    truncated: bool,
    /// Whether [`TIMEOUT`] elapsed. The process is killed and both streams
    /// come back empty: they are read as one future together with the wait, so
    /// abandoning it abandons what was buffered too. A caller gets the fact
    /// that it timed out rather than a partial answer it might parse.
    timed_out: bool,
}

pub async fn exec(
    req: HttpRequest,
    body: web::types::Json<ExecRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);

    // Re-checked here rather than trusted from the capabilities the client was
    // told earlier: that answer is a UI hint, and the UI is not a boundary.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Exec, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let cmd = body.cmd.clone();
    if cmd.trim().is_empty() {
        return Ok(HttpResponse::BadRequest().finish());
    }

    // Logged before it runs and by what it was asked to do, not by what it
    // did: a command that hangs or kills the agent still has to appear here.
    Event::new(Kind::Exec, Action::Open, Outcome::Ok)
        .remote_ip(remote_ip.clone())
        .subject(first_line(&cmd))
        .record(&app_state.db)
        .await;

    match run(&cmd, body.stdin.as_deref(), body.env.as_ref()).await {
        Ok(resp) => Ok(HttpResponse::Ok().json(&resp)),
        Err(e) => {
            Event::new(Kind::Exec, Action::Close, Outcome::Error)
                .remote_ip(remote_ip)
                .detail(e.to_string())
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::InternalServerError().finish())
        }
    }
}

/// The first line, capped — an audit row records which command ran, not a
/// script's entire body.
///
/// Reads the command rather than the input it was given, so nothing a caller
/// sends as a credential is ever quoted here.
fn first_line(cmd: &str) -> String {
    let line = cmd.lines().next().unwrap_or("").trim();
    if line.len() <= 200 {
        return line.to_string();
    }
    let mut end = 200;
    while !line.is_char_boundary(end) {
        end -= 1;
    }
    format!("{}…", &line[..end])
}

async fn run(
    cmd: &str,
    stdin: Option<&str>,
    env: Option<&HashMap<String, String>>,
) -> std::io::Result<ExecResponse> {
    let (shell, flag) = shell();
    let mut command = Command::new(shell);
    command
        .arg(flag)
        .arg(cmd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);
    // Added to the agent's own environment rather than replacing it: the
    // command still needs a `PATH`, and the caller is naming a few variables,
    // not describing the whole environment it wants.
    if let Some(env) = env {
        command.envs(env);
    }
    let mut child = command.spawn()?;

    let pipe = child.stdin.take();
    let feed = async move {
        if let Some(mut pipe) = pipe {
            if let Some(data) = stdin {
                // A command that exits without reading closes the pipe, and
                // writing to a closed pipe is that command's answer, not a
                // failure of this request: the output it did produce is still
                // worth returning.
                if let Err(e) = pipe.write_all(data.as_bytes()).await {
                    if e.kind() != std::io::ErrorKind::BrokenPipe {
                        tracing::debug!("exec stdin: {e}");
                    }
                }
            }
            // Closed either way: a command reading stdin would otherwise wait
            // for input that is never coming, and take the timeout to find out.
            drop(pipe);
        }
    };

    // Inside the timeout with the wait, not before it. A command that never
    // reads its stdin leaves a write of more than a pipe buffer — 64 KiB on
    // Linux, and the status script is larger than that — blocked forever, and
    // nothing above was bounding it.
    let output = match tokio::time::timeout(TIMEOUT, async {
        feed.await;
        child.wait_with_output().await
    })
    .await
    {
        Ok(result) => result?,
        Err(_) => {
            // `kill_on_drop` handles the process; what is lost is whatever it
            // had buffered, which is the price of not waiting forever.
            return Ok(ExecResponse {
                exit_code: None,
                stdout: String::new(),
                stderr: String::new(),
                truncated: false,
                timed_out: true,
            });
        }
    };

    let (stdout, out_cut) = cap(output.stdout);
    let (stderr, err_cut) = cap(output.stderr);
    Ok(ExecResponse {
        exit_code: output.status.code(),
        stdout,
        stderr,
        truncated: out_cut || err_cut,
        timed_out: false,
    })
}

/// Lossy on purpose: a command's output is bytes, and refusing to report
/// anything because one of them is not UTF-8 helps nobody.
fn cap(bytes: Vec<u8>) -> (String, bool) {
    if bytes.len() <= MAX_OUTPUT {
        return (String::from_utf8_lossy(&bytes).into_owned(), false);
    }
    let mut end = MAX_OUTPUT;
    while end > 0 && (bytes[end] & 0b1100_0000) == 0b1000_0000 {
        end -= 1;
    }
    (String::from_utf8_lossy(&bytes[..end]).into_owned(), true)
}

/// The shell to hand the command to, and the switch that means "this is the
/// command" — `cmd.exe` spells it `/C`, and given `-c` it looks for a file by
/// that name and fails without running anything.
///
/// `/bin/sh` rather than the account's login shell: this runs one command and
/// reads its output, so what matters is that the syntax is the one callers
/// write, not that it matches an interactive session.
fn shell() -> (&'static str, &'static str) {
    if cfg!(windows) {
        ("cmd", "/C")
    } else {
        ("/bin/sh", "-c")
    }
}
