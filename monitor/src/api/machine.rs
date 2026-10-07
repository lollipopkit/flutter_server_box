//! What the machine-management endpoints share: the panel's power, process,
//! service, cron, container, benchmark, system user, snippet and desktop pages (issue
//! #1623).
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
pub const FEATURES: &[&str] = &[
    "power",
    "process",
    "services",
    "cron",
    "containers",
    // A shell inside a container, opened through the terminal's `target`. Not
    // a page: a panel offers the action only where an agent lists it, since an
    // older agent ignores the unknown `target` field and would open a host
    // shell instead.
    "container_exec",
    // An iperf client, opened through the terminal's `target` the same way and
    // listed for the same reason.
    "iperf",
    // A tmux session and the sessions themselves: the terminal's `target` and
    // the `/tmux` listing the page draws. Listed for the same reason as
    // `iperf` — an older agent ignores the unknown `target` field and would
    // open a plain host shell.
    "tmux",
    "benchmark",
    "system_users",
    "snippets",
    "desktop",
    "backup",
    "bmc",
    "virt",
    "firewall",
    // The panel's desk keeps its arrangement here (`api::desk`); without it
    // the panel keeps it in the browser.
    "desk",
    // Its preferences carry `background` (an older agent refuses the field).
    "desk_background",
    // `/desk/apps/{app}/storage`: what each desk app keeps for itself.
    "desk_storage",
];

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

/// [`as_root`] for text that holds a secret of its own — an account's new
/// password, which `sbm_parser::users` writes into a `chpasswd` heredoc.
///
/// [`as_root`] puts the script on the root shell's command line, which every
/// account on the machine can read with `ps`. Here the text goes into a file
/// only the agent's user can read (root can read anything), created fresh
/// under a random name so no one else's file or link is written through, and
/// the command line names only that file. The file is removed when the
/// command ends, however it ends.
#[cfg(unix)]
pub(crate) async fn as_root_private(
    text: &str,
    password: Option<&str>,
    limits: &Limits,
) -> std::io::Result<ExecResponse> {
    let file = PrivateScript::write(text)?;
    let path = file.path.to_string_lossy();
    as_root(&format!("sh '{}'", path.replace('\'', "'\\''")), password, limits).await
}

/// No `sudo` to run it through and no owner-only mode to give the file, so
/// nothing that holds a secret is run as root here. Unreached by the callers,
/// which refuse anything but Linux first; it exists so they build everywhere.
#[cfg(not(unix))]
pub(crate) async fn as_root_private(
    _text: &str,
    _password: Option<&str>,
    _limits: &Limits,
) -> std::io::Result<ExecResponse> {
    Err(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        "running a script that holds a secret as root needs a Unix host",
    ))
}

/// A script file readable by this process's user alone, removed on drop.
#[cfg(unix)]
struct PrivateScript {
    path: std::path::PathBuf,
}

#[cfg(unix)]
impl PrivateScript {
    fn write(text: &str) -> std::io::Result<Self> {
        use std::io::Write;
        use std::os::unix::fs::OpenOptionsExt;

        let suffix = crate::utils::secrets::random_hex(16).map_err(std::io::Error::other)?;
        let path = std::env::temp_dir().join(format!("sbm-root-{suffix}.sh"));
        // `create_new` refuses a path that exists, a link included, and the
        // mode is applied at creation: there is no moment at which the file
        // is readable by anyone else.
        let mut file = std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&path)?;
        let script = Self { path };
        file.write_all(text.as_bytes())?;
        Ok(script)
    }
}

#[cfg(unix)]
impl Drop for PrivateScript {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
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

    /// The secret is in a file only this user can read, the command line names
    /// the file and nothing else, and the file is gone once the command is.
    #[cfg(unix)]
    #[test]
    fn a_private_script_is_this_users_alone_and_does_not_outlive_its_command() {
        use std::os::unix::fs::PermissionsExt;
        let script = PrivateScript::write("chpasswd <<'X'\nme:hunter2\nX").unwrap();
        let path = script.path.clone();
        let meta = std::fs::metadata(&path).unwrap();
        assert_eq!(meta.permissions().mode() & 0o777, 0o600);
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "chpasswd <<'X'\nme:hunter2\nX");
        drop(script);
        assert!(!path.exists(), "the file outlived its command");
    }

    /// A private script runs as the text it holds. `sh` stands in for sudo,
    /// as below.
    #[cfg(unix)]
    #[tokio::test]
    async fn a_private_script_runs_its_text() {
        let script = PrivateScript::write("echo ran").unwrap();
        let limits = Limits {
            timeout: std::time::Duration::from_secs(10),
            max_output_bytes: 4096,
            max_request_bytes: 4096,
        };
        let command = format!("sh '{}'", script.path.to_string_lossy());
        assert!(!command.contains("echo ran"));
        let out = run(&command, None, None, &limits).await.unwrap();
        assert_eq!(out.stdout, "ran\n");
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
