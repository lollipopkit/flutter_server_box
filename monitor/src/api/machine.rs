//! What the machine-management endpoints share: the panel's power, process,
//! service, cron and container pages (issue #1623).
//!
//! Each of them runs a command on the machine the agent is installed on,
//! built and parsed in Rust (`sbm_parser`) rather than sent through `/exec` by
//! the panel, so the command text lives in one place with the app's. What they
//! have in common is who may call them and what is written down when someone
//! may not: [`gate`] is that, and nothing else in these handlers decides it.

use std::collections::HashMap;

use ntex::http::StatusCode;

use sbm_parser::output::CommandOutput;

use super::exec::{ExecResponse, Limits, run};
use ntex::web::{HttpRequest, HttpResponse};

use super::authz::{self, Caller};
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::permissions::Grant;

/// The machine-management endpoints this agent serves, as `features` in
/// `/capabilities`. A panel shows a page only when its name is here, which is
/// how it tells an agent without the endpoint from one that refused.
pub const FEATURES: &[&str] = &["power", "process", "services"];

/// Who is asking, and from where, once [`gate`] let them through.
pub struct Gated {
    pub caller: Caller,
    pub remote_ip: Option<String>,
}

/// The caller, if their role holds [grant] over this link.
///
/// A refusal is recorded under [`Kind::Machine`] — the account as the
/// subject, [what] (the feature and verb, never anything the request carried)
/// and the reason as the detail — and answered
/// `403 {"error":"forbidden","message":<why>}`. Re-checked on every request
/// rather than trusted from `/capabilities`: that answer is a hint for the
/// UI, and the UI is not a boundary.
pub async fn gate(
    req: &HttpRequest,
    state: &AppState,
    grant: Grant,
    what: &str,
) -> Result<Gated, HttpResponse> {
    let caller = authz::jwt_caller(req, state).await?;
    let remote_ip = peer_ip(req);
    if let Err(why) = caller.check(grant, state, authz::is_secure(req, state)) {
        Event::new(Kind::Machine, Action::Denied, Outcome::Denied)
            .subject(&caller.username)
            .remote_ip(remote_ip)
            .detail(format!("{what}: {} {}", grant.as_str(), why.as_str()))
            .record(&state.db)
            .await;
        return Err(authz::error(StatusCode::FORBIDDEN, "forbidden", why.as_str()));
    }
    Ok(Gated { caller, remote_ip })
}

/// `/exec`'s bounds with the output cap raised to at least [min_bytes]: for a
/// command that describes a whole machine (a process table, every unit's
/// details), where `[remote_access.exec]`'s 1 MiB default is a few thousand
/// rows short and going over costs the reader the whole page.
pub(crate) fn at_least(exec: &Limits, min_bytes: usize) -> Limits {
    Limits {
        max_output_bytes: exec.max_output_bytes.max(min_bytes),
        ..exec.clone()
    }
}

/// What a command printed, in the shape `sbm_parser`'s parsers read.
///
/// One that did not finish — killed at the timeout, cut at the output cap, or
/// never started — is a failure carrying why, rather than a run that printed
/// nothing: a parser reading an empty `stderr` would report the machine as
/// having said nothing rather than as not having been heard.
pub(crate) fn command_output(out: std::io::Result<ExecResponse>) -> CommandOutput {
    match out {
        Ok(out) if out.timed_out => CommandOutput::failed("the command did not finish in time"),
        Ok(out) if out.truncated => {
            CommandOutput::failed("the command printed more than this agent reads")
        }
        Ok(out) => CommandOutput::new(out.stdout, out.stderr, out.exit_code == Some(0)),
        Err(e) => CommandOutput::failed(format!("the command could not be run: {e}")),
    }
}

/// Runs POSIX shell text as the agent's own account.
///
/// The text is `sh`'s standard input rather than a command line: what the
/// shared modules in `sbm_parser` build interpolates values that came over
/// HTTP or off the machine, and as input none of them is ever parsed as the
/// shell's own syntax. It is also how the app feeds the same text over SSH.
pub(crate) async fn as_self(text: &str, limits: &Limits) -> std::io::Result<ExecResponse> {
    run("sh", Some(text), None, limits).await
}

/// Runs POSIX shell text as root through `sudo`.
///
/// The script never shares a stream with the password. It reaches the root
/// shell as `sh -c "$SBM_ROOT_SCRIPT"`, expanded by the unprivileged shell as
/// one argument (sudo's `env_reset` would drop the variable itself), and
/// stdin carries the password line alone. Sharing the pipe would hand that
/// line to the script whenever sudo does not ask for it — root already, or
/// `NOPASSWD` — and the shell would run the password as a command and print
/// it back in its error. The password stays off every command line; the
/// script, which holds no secret, does not.
///
/// Without a password, `sudo -n`: a machine that wants one answers with a
/// failure that names the reason, rather than waiting on a read.
pub(crate) async fn as_root(
    text: &str,
    password: Option<&str>,
    limits: &Limits,
) -> std::io::Result<ExecResponse> {
    let (entry, stdin, env) = root_invocation(text, password);
    run(entry, stdin.as_deref(), Some(&env), limits).await
}

/// What [`as_root`] runs: the command, what goes on stdin, and the
/// environment the script travels in.
fn root_invocation(
    text: &str,
    password: Option<&str>,
) -> (&'static str, Option<String>, HashMap<String, String>) {
    let env = HashMap::from([(ROOT_SCRIPT_VAR.to_owned(), text.to_owned())]);
    match password {
        Some(password) => (
            r#"sudo -S -p '' sh -c "$SBM_ROOT_SCRIPT""#,
            Some(format!("{password}\n")),
            env,
        ),
        None => (r#"sudo -n sh -c "$SBM_ROOT_SCRIPT""#, None, env),
    }
}

const ROOT_SCRIPT_VAR: &str = "SBM_ROOT_SCRIPT";

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_password_is_the_only_thing_on_stdin() {
        let (cmd, stdin, env) = root_invocation("kill -s TERM 42", Some("hunter2"));
        assert_eq!(stdin.as_deref(), Some("hunter2\n"));
        assert!(!cmd.contains("hunter2"));
        assert!(cmd.contains(&format!("\"${ROOT_SCRIPT_VAR}\"")), "{cmd}");
        assert_eq!(env[ROOT_SCRIPT_VAR], "kill -s TERM 42");

        let (cmd, stdin, env) = root_invocation("kill -s TERM 42", None);
        assert!(cmd.starts_with("sudo -n "), "{cmd}");
        assert_eq!(stdin, None);
        assert_eq!(env[ROOT_SCRIPT_VAR], "kill -s TERM 42");
    }

    /// The case the separate streams exist for: when sudo does not read the
    /// password, nothing runs it. `sh -c` stands in for a sudo that let the
    /// command through without asking.
    #[cfg(unix)]
    #[tokio::test]
    async fn a_password_sudo_did_not_read_is_not_run_by_the_script() {
        let (_, stdin, env) = root_invocation("echo ran", Some("echo leaked"));
        let limits = Limits {
            timeout: std::time::Duration::from_secs(10),
            max_output_bytes: 4096,
            max_request_bytes: 4096,
        };
        let out = run(r#"sh -c "$SBM_ROOT_SCRIPT""#, stdin.as_deref(), Some(&env), &limits)
            .await
            .unwrap();
        assert_eq!(out.stdout, "ran\n");
        assert!(!out.stdout.contains("leaked") && !out.stderr.contains("leaked"));
    }
}
