//! The status script the extended cycle runs (`sbm_parser::script`) and how
//! its commands are run: bounded in time and output, their process group
//! ended on a timeout.

use crate::utils::error::Result;
use sbm_parser::SystemType;
use std::process::Stdio;
use tokio::io::AsyncReadExt;
use tokio::process::{Child, Command as TokioCommand};
use tokio::time::{Duration, timeout, timeout_at};
use tracing::error;
use super::service::*;

/// CLI tools are optional and must not stop the core sampling loop when a
/// driver, disk, or network filesystem leaves one stuck in kernel I/O.
pub(super) const EXTERNAL_COMMAND_TIMEOUT: Duration = Duration::from_secs(30);
pub(super) const MAX_COMMAND_OUTPUT_BYTES: u64 = 1024 * 1024;
pub(super) const OUTPUT_DRAIN_MINIMUM: Duration = Duration::from_millis(10);

/// Build the status script shared with the app (`sbm_parser::script`). Only
/// the extended cycle runs it, for the shell functions in `EXTENDED_FUNCS` —
/// everything `sbm_native` covers no longer needs a generated script at all.
pub(super) fn build_status_script(system: SystemType) -> String {
    sbm_parser::script::build_script(
        system,
        &sbm_parser::script::ScriptOptions {
            disabled: monitor_script_disabled(system),
            build_number: env!("CARGO_PKG_VERSION").to_string(),
        },
    )
}

/// Manifest commands the monitor still needs from the shared script.
///
/// Core status is sampled by `sbm_native`, and NVIDIA has its own targeted
/// invocation above. Keeping every other manifest key disabled prevents an
/// extended cycle from collecting CPU/memory/disk/network a second time and,
/// on Windows, avoids the two one-second WMI samples for net and disk I/O.
/// Custom commands are not manifest entries; `SbStatus` continues to read and
/// run their directory even when every ordinary command in that function is
/// disabled.
pub(super) fn monitor_script_command_needed(system: SystemType, key: &str) -> bool {
    use sbm_parser::commands::{AMD, BATTERY, CONN, DISK_SMART, SENSORS};

    if !native_status_available(system) {
        return true;
    }
    match system {
        SystemType::Linux => matches!(key, AMD | BATTERY | DISK_SMART | SENSORS),
        SystemType::Bsd => matches!(key, DISK_SMART),
        SystemType::Windows => matches!(key, AMD | BATTERY | CONN | DISK_SMART | SENSORS),
    }
}

pub(super) fn monitor_script_disabled(system: SystemType) -> Vec<String> {
    let scope = match system {
        SystemType::Linux => "Linux",
        SystemType::Bsd => "BSD",
        SystemType::Windows => "Windows",
    };
    sbm_parser::commands::commands(system)
        .iter()
        .filter(|spec| !monitor_script_command_needed(system, spec.key))
        .map(|spec| format!("{scope}.{}", spec.key))
        .collect()
}

/// The command that runs [func] of this machine's status script — the same
/// script, and the same function, the app runs over SSH.
///
/// Writes the script first if it is missing or out of date, as each
/// monitoring cycle does: the temp directory can have been cleaned since.
pub fn local_script_command(func: sbm_parser::script::ShellFunc) -> std::io::Result<String> {
    let system = system_type();
    let path = script_path(system);
    ensure_script(&path, &build_status_script(system))?;
    Ok(sbm_parser::script::exec_command(
        system,
        &path.to_string_lossy(),
        func,
    ))
}

/// Script location in the temp dir. `.ps1` is mandatory for `powershell -File`
pub(super) fn script_path(system: SystemType) -> std::path::PathBuf {
    let name = match system {
        SystemType::Windows => "status.ps1",
        _ => "status.sh",
    };
    std::env::temp_dir().join("server_box_monitor").join(name)
}

/// Write the script if missing or outdated (tmp reapers / version upgrades);
/// checked every cycle before exec
pub(crate) fn ensure_script(path: &std::path::Path, content: &str) -> std::io::Result<()> {
    let up_to_date = std::fs::read_to_string(path).is_ok_and(|existing| existing == content);
    if up_to_date {
        return Ok(());
    }
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    std::fs::write(path, content)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755))?;
    }
    Ok(())
}

/// Shell functions the extended cycle runs. Both halves are needed because
/// SMART and AMD are in `SbStatusExt`, while sensors/battery, Windows conn and
/// custom commands live in `SbStatus`. `monitor_script_disabled` strips the
/// native-covered commands from both functions before this script is written.
pub(super) const EXTENDED_FUNCS: [sbm_parser::script::ShellFunc; 2] = [
    sbm_parser::script::ShellFunc::StatusExt,
    sbm_parser::script::ShellFunc::Status,
];
pub(super) const CORE_FUNCS: [sbm_parser::script::ShellFunc; 1] = [sbm_parser::script::ShellFunc::Status];

#[derive(Default)]
pub(super) struct ScriptExecution {
    pub(super) segments: Vec<(String, String)>,
    pub(super) status_succeeded: bool,
    pub(super) extended_succeeded: bool,
}

impl ScriptExecution {
    pub(super) fn record(&mut self, func: &sbm_parser::script::ShellFunc, succeeded: bool, stdout: &[u8]) {
        if !succeeded {
            return;
        }
        match func {
            sbm_parser::script::ShellFunc::Status => self.status_succeeded = true,
            sbm_parser::script::ShellFunc::StatusExt => self.extended_succeeded = true,
            _ => {}
        }
        self.segments
            .extend(sbm_parser::script::parse_script_segments(
                &String::from_utf8_lossy(stdout),
            ));
    }
}

/// Execute the generated status script and split its output by segment.
/// Failed commands inside the script yield empty segments (the script does
/// `exec 2>/dev/null`), matching the app's per-segment tolerance; per-command
/// stderr is not observable in this mode.
pub(super) async fn execute_commands(system: SystemType, include_extended: bool) -> Result<ScriptExecution> {
    let content = build_status_script(system);
    let path = script_path(system);

    ensure_script(&path, &content).map_err(|e| {
        crate::utils::error::MonitorError::Monitoring(format!("Status script error: {e}"))
    })?;
    let mut execution = ScriptExecution::default();
    let funcs = if include_extended {
        &EXTENDED_FUNCS[..]
    } else {
        &CORE_FUNCS[..]
    };
    for func in funcs {
        let command = if cfg!(target_os = "windows") {
            let mut command = TokioCommand::new("powershell");
            command
                .args(["-ExecutionPolicy", "Bypass", "-File"])
                .arg(&path)
                .arg(format!("-{}", func.flag()));
            command
        } else {
            let mut command = TokioCommand::new("sh");
            command.arg(&path).arg(format!("-{}", func.flag()));
            command
        };
        let Some(output) = command_output(command, func.name()).await.map_err(|e| {
            crate::utils::error::MonitorError::Monitoring(format!("Status script error: {e}"))
        })?
        else {
            continue;
        };
        let succeeded = output.status.success();
        if !succeeded {
            error!(
                "Status script {} exited with {}",
                func.name(),
                output.status
            );
        }
        execution.record(func, succeeded, &output.stdout);
    }
    Ok(execution)
}

/// Runs a CLI tool with bounded time and output collection.
///
/// `Child::wait_with_output` consumes the child, which makes it impossible to
/// signal it if its wait future expires. Read the pipes independently instead,
/// retaining the child so a timeout can stop it before awaiting the readers.
pub(super) async fn command_output(
    command: TokioCommand,
    label: &str,
) -> std::io::Result<Option<std::process::Output>> {
    command_output_with_timeout(command, label, EXTERNAL_COMMAND_TIMEOUT).await
}

pub(super) async fn command_output_with_timeout(
    mut command: TokioCommand,
    label: &str,
    command_timeout: Duration,
) -> std::io::Result<Option<std::process::Output>> {
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        // Its descendants inherit this group. On timeout, ending the group
        // prevents a shell child such as smartctl from outliving its script.
        command.as_std_mut().process_group(0);
    }
    command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);
    let deadline = tokio::time::Instant::now() + command_timeout;
    #[cfg(unix)]
    let mut child = command.spawn()?;
    #[cfg(unix)]
    let tree = Tree(child.id());
    #[cfg(windows)]
    let (mut child, job) = crate::utils::job::spawn(&mut command, 0)?;
    #[cfg(windows)]
    let tree = Tree(job);
    let stdout = child.stdout.take().expect("stdout was requested as piped");
    let stderr = child.stderr.take().expect("stderr was requested as piped");
    // Whichever pipe fills first says so, and the wait below stops waiting.
    // `take` ends the reader at the cap and leaves the pipe undrained, so a
    // child that keeps writing blocks on a full pipe and never exits: without
    // this, `child.wait()` ran to the full timeout and the segment was then
    // discarded as a timeout rather than reported as too much output. A wide
    // `smartctl` sweep or `nvidia-smi -q -x` on a many-GPU host reaches it.
    let (overflow_tx, overflow_rx) = tokio::sync::oneshot::channel::<()>();
    let overflow_tx = std::sync::Arc::new(std::sync::Mutex::new(Some(overflow_tx)));
    let announce = {
        let overflow_tx = overflow_tx.clone();
        move || {
            if let Ok(mut slot) = overflow_tx.lock()
                && let Some(tx) = slot.take()
            {
                let _ = tx.send(());
            }
        }
    };
    let stdout = tokio::spawn({
        let announce = announce.clone();
        async move {
            let mut bytes = Vec::new();
            let mut stdout = stdout.take(MAX_COMMAND_OUTPUT_BYTES + 1);
            let read = stdout.read_to_end(&mut bytes).await.map(|_| bytes);
            if read
                .as_ref()
                .is_ok_and(|b| b.len() as u64 > MAX_COMMAND_OUTPUT_BYTES)
            {
                announce();
            }
            read
        }
    });
    let stderr = tokio::spawn(async move {
        let mut bytes = Vec::new();
        let mut stderr = stderr.take(MAX_COMMAND_OUTPUT_BYTES + 1);
        let read = stderr.read_to_end(&mut bytes).await.map(|_| bytes);
        if read
            .as_ref()
            .is_ok_and(|b| b.len() as u64 > MAX_COMMAND_OUTPUT_BYTES)
        {
            announce();
        }
        read
    });
    let stdout_abort = stdout.abort_handle();
    let stderr_abort = stderr.abort_handle();

    let waited = tokio::select! {
        // Biased so a child that both overflowed and exited is reported as
        // overflow, which is the more useful of the two.
        biased;
        _ = overflow_rx => {
            tracing::warn!(
                "{label} produced more than {MAX_COMMAND_OUTPUT_BYTES} bytes and was terminated"
            );
            terminate_command(&mut child, &tree);
            stdout_abort.abort();
            stderr_abort.abort();
            tokio::spawn(async move { let _ = child.wait().await; });
            return Err(std::io::Error::other(format!(
                "{label} produced more than {MAX_COMMAND_OUTPUT_BYTES} bytes of output"
            )));
        }
        waited = timeout_at(deadline, child.wait()) => waited,
    };
    let status = match waited {
        Ok(status) => status?,
        Err(_) => {
            tracing::warn!(
                "{label} exceeded {} seconds and was terminated",
                command_timeout.as_secs()
            );
            terminate_command(&mut child, &tree);
            // A shell can leave descendants holding either pipe. Do not join
            // their readers after the deadline: a timed-out collection must
            // never turn into an unbounded wait on inherited handles.
            stdout_abort.abort();
            stderr_abort.abort();
            tokio::spawn(async move {
                // Reap the direct child eventually without holding up the
                // monitoring loop. Its process group was already signalled
                // above on Unix, and `start_kill` was requested elsewhere.
                let _ = child.wait().await;
            });
            return Ok(None);
        }
    };
    let remaining = deadline
        .saturating_duration_since(tokio::time::Instant::now())
        .max(OUTPUT_DRAIN_MINIMUM);
    let output = timeout(remaining, async {
        let stdout = stdout
            .await
            .map_err(|e| std::io::Error::other(format!("{label} stdout task failed: {e}")))??;
        let stderr = stderr
            .await
            .map_err(|e| std::io::Error::other(format!("{label} stderr task failed: {e}")))??;
        Ok::<_, std::io::Error>((stdout, stderr))
    })
    .await;
    let (stdout, stderr) = match output {
        Ok(output) => output?,
        Err(_) => {
            tracing::warn!("{label} left output pipes open after exit and was terminated");
            terminate_process_group(&tree);
            stdout_abort.abort();
            stderr_abort.abort();
            return Ok(None);
        }
    };
    if stdout.len() as u64 > MAX_COMMAND_OUTPUT_BYTES
        || stderr.len() as u64 > MAX_COMMAND_OUTPUT_BYTES
    {
        return Err(std::io::Error::other(format!(
            "{label} produced more than {MAX_COMMAND_OUTPUT_BYTES} bytes of output"
        )));
    }
    Ok(Some(std::process::Output {
        status,
        stdout,
        stderr,
    }))
}

/// What a command started, ended with it: the process group the direct
/// child leads on Unix, its job on Windows (`utils::job`).
pub(super) struct Tree(
    #[cfg(unix)] Option<u32>,
    #[cfg(windows)] crate::utils::job::Job,
);

pub(super) fn terminate_command(child: &mut Child, tree: &Tree) {
    if !terminate_process_group(tree) {
        let _ = child.start_kill();
    }
}

pub(super) fn terminate_process_group(tree: &Tree) -> bool {
    // `process_group(0)` above makes the direct child's PID its process
    // group ID. A negative PID is POSIX's "signal the group" form.
    #[cfg(unix)]
    return tree.0.is_some_and(|id| unsafe { kill_process_group(-(id as i32), 9) } == 0);
    #[cfg(windows)]
    return tree.0.kill();
}

#[cfg(unix)]
unsafe extern "C" {
    #[link_name = "kill"]
    fn kill_process_group(pid: i32, signal: i32) -> i32;
}
