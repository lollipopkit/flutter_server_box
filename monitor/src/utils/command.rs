//! Running an external command with bounded time and bounded output.
//!
//! Two callers, one implementation. The monitoring loop runs CLI tools
//! (`nvidia-smi`, `smartctl` through the generated script) whose driver can
//! leave them stuck in kernel I/O, and the admin endpoints run the commands
//! behind the panel's process, service, container, user and cron pages. Both
//! need the same guarantees — a command that hangs is killed, a command that
//! prints a gigabyte is stopped rather than buffered, and neither case is
//! allowed to leave a descendant holding the pipes — so they run through this
//! rather than each carrying its own copy of the same care.
//!
//! Not a general `sh -c` runner: the caller builds the [`TokioCommand`], which
//! is what lets a call site keep an argument out of a shell string.

use std::process::Stdio;
use std::time::Duration;

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::process::{Child, Command as TokioCommand};
use tokio::time::{timeout, timeout_at};

/// CLI tools are optional and must not stop the core sampling loop when a
/// driver, disk, or network filesystem leaves one stuck in kernel I/O.
pub const EXTERNAL_COMMAND_TIMEOUT: Duration = Duration::from_secs(30);
pub const MAX_COMMAND_OUTPUT_BYTES: u64 = 1024 * 1024;

/// Floor on how long the output pipes are still drained after the child has
/// exited. A process can exit with bytes still in flight, and reading nothing
/// because the wait returned first would truncate a short answer.
const OUTPUT_DRAIN_MINIMUM: Duration = Duration::from_millis(10);

/// The child printed past the cap and was terminated.
///
/// Its own kind rather than [`std::io::ErrorKind::Other`] so a caller that
/// reports it as a field — "this is a prefix" — can ask a typed question
/// instead of reading the message, which is a sentence this file is free to
/// reword.
fn output_overflow(message: String) -> std::io::Error {
    std::io::Error::new(std::io::ErrorKind::InvalidData, message)
}

/// Whether an error from [`run`] is the output cap rather than a spawn or pipe
/// failure.
pub fn is_output_overflow(error: &std::io::Error) -> bool {
    error.kind() == std::io::ErrorKind::InvalidData
}

/// How long one command may run and how much of what it printed is kept.
#[derive(Debug, Clone, Copy)]
pub struct Limits {
    pub timeout: Duration,
    pub max_output_bytes: u64,
}

impl Limits {
    pub const DEFAULT: Limits = Limits {
        timeout: EXTERNAL_COMMAND_TIMEOUT,
        max_output_bytes: MAX_COMMAND_OUTPUT_BYTES,
    };

    pub const fn with_timeout(timeout: Duration) -> Limits {
        Limits {
            timeout,
            max_output_bytes: MAX_COMMAND_OUTPUT_BYTES,
        }
    }
}

/// Run `command`, returning its output, or `None` if it was killed for
/// exceeding [`Limits::timeout`].
///
/// `stdin` is written to the command's own standard input and the pipe is then
/// closed — how a `sudo -S` password gets in without a terminal to type it
/// into. It is a byte slice rather than a `String` so a caller cannot be
/// tempted to interpolate it into a command line, where it would land in the
/// machine's process list.
///
/// An error means the output cap was reached (the child is terminated) or the
/// spawn or the pipes failed; [`is_output_overflow`] tells the two apart.
pub async fn run(
    mut command: TokioCommand,
    label: &str,
    limits: Limits,
    stdin: Option<&[u8]>,
) -> std::io::Result<Option<std::process::Output>> {
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        // Its descendants inherit this group. On timeout, ending the group
        // prevents a shell child such as smartctl from outliving its script.
        command.as_std_mut().process_group(0);
    }
    command
        .stdin(if stdin.is_some() {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);
    let deadline = tokio::time::Instant::now() + limits.timeout;
    let mut child = command.spawn()?;
    let process_group = child.id();

    // Written and then dropped, so the child sees EOF rather than waiting for
    // input that will never come. A command that exits without reading its
    // stdin (`reboot` past the point of no return) closes the pipe first, and
    // the resulting `EPIPE` is the expected outcome rather than a failure.
    let writing = stdin.map(|data| {
        let mut pipe = child.stdin.take().expect("stdin was requested as piped");
        let data = data.to_vec();
        tokio::spawn(async move {
            let _ = pipe.write_all(&data).await;
            let _ = pipe.shutdown().await;
        })
    });
    let writing_abort = writing.as_ref().map(|handle| handle.abort_handle());

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
    let cap = limits.max_output_bytes;
    let stdout = tokio::spawn({
        let announce = announce.clone();
        async move {
            let mut bytes = Vec::new();
            let mut stdout = stdout.take(cap + 1);
            let read = stdout.read_to_end(&mut bytes).await.map(|_| bytes);
            if read.as_ref().is_ok_and(|b| b.len() as u64 > cap) {
                announce();
            }
            read
        }
    });
    let stderr = tokio::spawn(async move {
        let mut bytes = Vec::new();
        let mut stderr = stderr.take(cap + 1);
        let read = stderr.read_to_end(&mut bytes).await.map(|_| bytes);
        if read.as_ref().is_ok_and(|b| b.len() as u64 > cap) {
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
                "{label} produced more than {cap} bytes and was terminated"
            );
            terminate_command(&mut child, process_group).await?;
            stdout_abort.abort();
            stderr_abort.abort();
            if let Some(abort) = writing_abort { abort.abort(); }
            tokio::spawn(async move { let _ = child.wait().await; });
            return Err(output_overflow(format!(
                "{label} produced more than {cap} bytes of output"
            )));
        }
        waited = timeout_at(deadline, child.wait()) => waited,
    };
    let status = match waited {
        Ok(status) => status?,
        Err(_) => {
            tracing::warn!(
                "{label} exceeded {} seconds and was terminated",
                limits.timeout.as_secs()
            );
            terminate_command(&mut child, process_group).await?;
            // A shell can leave descendants holding either pipe. Do not join
            // their readers after the deadline: a timed-out collection must
            // never turn into an unbounded wait on inherited handles.
            stdout_abort.abort();
            stderr_abort.abort();
            if let Some(abort) = writing_abort { abort.abort(); }
            tokio::spawn(async move {
                // Reap the direct child eventually without holding up the
                // caller. Its process group was already signalled above on
                // Unix, and `start_kill` was requested elsewhere.
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
            terminate_process_group(process_group);
            stdout_abort.abort();
            stderr_abort.abort();
            if let Some(abort) = writing_abort { abort.abort(); }
            return Ok(None);
        }
    };
    if stdout.len() as u64 > cap || stderr.len() as u64 > cap {
        return Err(output_overflow(format!(
            "{label} produced more than {cap} bytes of output"
        )));
    }
    Ok(Some(std::process::Output {
        status,
        stdout,
        stderr,
    }))
}

async fn terminate_command(child: &mut Child, process_group: Option<u32>) -> std::io::Result<()> {
    if terminate_process_group(process_group) {
        return Ok(());
    }

    #[cfg(windows)]
    if let Some(pid) = child.id() {
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        if TokioCommand::new("taskkill")
            .args(["/PID", &pid.to_string(), "/T", "/F"])
            .creation_flags(CREATE_NO_WINDOW)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .await
            .is_ok_and(|status| status.success())
        {
            return Ok(());
        }
    }

    child.start_kill()
}

fn terminate_process_group(_process_group: Option<u32>) -> bool {
    #[cfg(unix)]
    if let Some(id) = _process_group
        // `process_group(0)` above makes the direct child's PID its process
        // group ID. A negative PID is POSIX's "signal the group" form.
        && unsafe { kill_process_group(-(id as i32), 9) } == 0
    {
        return true;
    }
    // Windows has no group to signal, and `start_kill` — which is all this
    // used to fall back to — ends the process that was spawned and nothing it
    // spawned in turn. A `powershell -File` running the status script leaves
    // whatever it started (smartctl, a battery query) alive and holding the
    // pipes it inherited, so the reader that timed out cannot finish and the
    // next extended cycle starts another one beside it. `taskkill /T` walks
    // the tree by parent PID, which is the relationship Windows does keep.
    //
    // Not awaited, and still answers `false`: this runs on a path where the
    // caller has stopped reading, and `terminate_command`'s own `start_kill`
    // stays as the guarantee about the direct child.
    #[cfg(windows)]
    if let Some(id) = _process_group {
        let _ = std::process::Command::new("taskkill")
            .args(["/T", "/F", "/PID", &id.to_string()])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
    }
    false
}

#[cfg(unix)]
unsafe extern "C" {
    #[link_name = "kill"]
    fn kill_process_group(pid: i32, signal: i32) -> i32;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn a_stuck_external_command_is_terminated() {
        let command = if cfg!(windows) {
            let mut command = TokioCommand::new("powershell");
            command.args(["-NoProfile", "-Command", "Start-Sleep -Seconds 2"]);
            command
        } else {
            let mut command = TokioCommand::new("sh");
            command.args(["-c", "sleep 2"]);
            command
        };
        let started = std::time::Instant::now();
        let output = run(
            command,
            "test sleep",
            Limits::with_timeout(Duration::from_millis(100)),
            None,
        )
        .await
        .unwrap();

        assert!(output.is_none());
        assert!(started.elapsed() < Duration::from_secs(1));
    }

    /// The password reaches the command and the pipe is closed behind it, so a
    /// command that reads until EOF finishes instead of waiting for input that
    /// will never come.
    #[cfg(unix)]
    #[tokio::test]
    async fn stdin_is_delivered_and_then_closed() {
        let mut command = TokioCommand::new("sh");
        command.args(["-c", "cat; echo done"]);
        let output = run(
            command,
            "test stdin",
            Limits::with_timeout(Duration::from_secs(5)),
            Some(b"secret\n"),
        )
        .await
        .unwrap()
        .unwrap();

        assert_eq!(String::from_utf8_lossy(&output.stdout), "secret\ndone\n");
    }

    #[cfg(windows)]
    #[tokio::test]
    async fn a_timed_out_windows_command_cannot_leave_a_descendant() {
        let dir = tempfile::tempdir().unwrap();
        let marker = dir.path().join("survived");
        let child_path = dir.path().join("child.ps1");
        let marker_arg = marker.to_string_lossy().replace('\'', "''");
        std::fs::write(
            &child_path,
            format!("Start-Sleep -Seconds 2; Set-Content -LiteralPath '{marker_arg}' -Value alive"),
        )
        .unwrap();
        let child_arg = child_path.to_string_lossy().replace('\'', "''");
        let parent_script = format!(
            "$q = '\"' + '{child_arg}' + '\"'; Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$q); Start-Sleep -Seconds 30"
        );
        let mut command = TokioCommand::new("powershell");
        command.args(["-NoProfile", "-Command", &parent_script]);

        let output = run(
            command,
            "test process tree",
            Limits::with_timeout(Duration::from_millis(200)),
            None,
        )
        .await
        .unwrap();
        assert!(output.is_none());
        tokio::time::sleep(Duration::from_secs(3)).await;
        assert!(!marker.exists());
    }

    #[tokio::test]
    async fn an_external_command_cannot_silently_truncate_output() {
        // Comfortably over the cap rather than one byte over it. At exactly
        // `MAX + 1` the reader reaches its `take` limit in the same moment the
        // child finishes writing and exits, so the two things this races —
        // the overflow and the wait — become ready together, and the test
        // stops being about either. Well over, the reader hits the cap while
        // the child is still writing and then blocks on a full pipe, which is
        // the case the announcement exists for.
        const OVER_CAP: usize = 4 * 1024 * 1024;
        let ps_write = format!(
            "$out = [Console]::OpenStandardOutput(); $bytes = New-Object byte[] {OVER_CAP}; $out.Write($bytes, 0, $bytes.Length)"
        );

        let command = if cfg!(windows) {
            let mut command = TokioCommand::new("powershell");
            command.args(["-NoProfile", "-Command", &ps_write]);
            command
        } else {
            let mut command = TokioCommand::new("sh");
            command.args(["-c", &format!("head -c {OVER_CAP} /dev/zero")]);
            command
        };

        // Generous, because the number is not the subject. What is asserted is
        // that too much output is *reported* as too much; how long this
        // machine takes to start a process and move four megabytes is the CI
        // runner's business. Measured at 179 ms on an idle Windows box against
        // a 5-second budget, which windows-latest still exceeded often enough
        // to fail three of five runs — and which 70 runs here, twelve of them
        // concurrent, never reproduced. Detection that is actually broken
        // fails this just the same, only later.
        //
        // Says what it got instead of `unwrap_err`, which reported only
        // "Ok value: None" and did not separate a child that wrote nothing
        // from one that wrote enough and was never noticed.
        let error = match run(
            command,
            "test output",
            Limits::with_timeout(Duration::from_secs(30)),
            None,
        )
        .await
        {
            Err(error) => error,
            Ok(output) => panic!(
                "expected an overflow error, got {:?}",
                output.map(|o| (o.status, o.stdout.len(), o.stderr.len()))
            ),
        };
        assert!(error.to_string().contains("bytes of output"));
    }
}
