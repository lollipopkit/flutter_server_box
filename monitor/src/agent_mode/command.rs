//! Runs one command for a task: in a shell, as the agent's user (through
//! `sudo` when asked, the password on stdin), its output line by line as it
//! comes so a page can show it, and the whole process group stopped when the
//! task is.
//!
//! The shell is `/bin/sh` on Unix and Windows PowerShell on Windows, where
//! there is no `sudo` and the process tree is ended with `taskkill /T`.

use std::process::Stdio;
use std::time::{Duration, Instant};

use fl_pi_llm::host::Cancel;
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command;
use tokio::sync::mpsc;

/// The longest line kept; the rest of it is dropped.
const MAX_LINE: usize = 8 << 10;

/// Which stream a line came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stream {
    Out,
    Err,
}

#[derive(Debug)]
pub struct Finished {
    /// `None` when it was killed.
    pub exit_code: Option<i32>,
    pub timed_out: bool,
    pub cancelled: bool,
    pub duration: Duration,
}

/// What [`run`] runs.
pub struct Spec<'a> {
    pub command: &'a str,
    /// Through `sudo -S` with this password on stdin.
    pub sudo_password: Option<&'a str>,
    pub timeout: Duration,
}

/// Runs [spec], sending each line to [lines] as it is read. Ends when the
/// command does, when [timeout] passes or when [cancel] fires; the latter two
/// stop the whole process group.
pub async fn run(spec: Spec<'_>, lines: mpsc::UnboundedSender<(Stream, String)>, cancel: &Cancel) -> std::io::Result<Finished> {
    let started = Instant::now();
    #[cfg(windows)]
    let mut command = match spec.sudo_password {
        Some(_) => return Err(std::io::Error::new(std::io::ErrorKind::Unsupported, "sudo does not exist on Windows")),
        None => powershell(spec.command),
    };
    #[cfg(not(windows))]
    let mut command = match spec.sudo_password {
        // `-k`: the password is checked now, never a cached credential; `-p ''`:
        // no prompt in the output; `--`: the rest is the command. The password
        // is sudo's stdin and never the command's: when sudo does not ask
        // (`NOPASSWD`), the line would otherwise be there for the command to
        // read and print, which is to say for the model.
        Some(_) => {
            let mut c = Command::new("sudo");
            c.args(["-S", "-k", "-p", "", "--", "/bin/sh", "-c"]).arg(format!("exec </dev/null\n{}", spec.command));
            c
        }
        None => {
            let mut c = Command::new("/bin/sh");
            c.args(["-c", spec.command]);
            c
        }
    };
    command
        // Only sudo reads stdin; a command reading it gets end of file.
        .stdin(if spec.sudo_password.is_some() { Stdio::piped() } else { Stdio::null() })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        // Non-interactive: a command waiting on a terminal would wait out the
        // timeout. `DEBIAN_FRONTEND` keeps apt from asking.
        .env("DEBIAN_FRONTEND", "noninteractive")
        .env("TERM", "dumb")
        .kill_on_drop(true);
    #[cfg(unix)]
    command.process_group(0);
    let mut child = command.spawn()?;
    let pid = child.id();

    let stdin = child.stdin.take();
    let password = spec.sudo_password.map(|p| format!("{p}\n"));
    let feed = async move {
        if let (Some(mut stdin), Some(p)) = (stdin, password) {
            let _ = stdin.write_all(p.as_bytes()).await;
        }
    };
    let out = pump(child.stdout.take().expect("piped stdout"), Stream::Out, lines.clone());
    let err = pump(child.stderr.take().expect("piped stderr"), Stream::Err, lines);

    let work = async {
        feed.await;
        let (_, _, status) = tokio::join!(out, err, child.wait());
        status
    };
    tokio::select! {
        status = work => {
            let status = status?;
            Ok(Finished { exit_code: status.code(), timed_out: false, cancelled: false, duration: started.elapsed() })
        }
        _ = tokio::time::sleep(spec.timeout) => {
            stop(pid).await;
            Ok(Finished { exit_code: None, timed_out: true, cancelled: false, duration: started.elapsed() })
        }
        _ = cancel.cancelled() => {
            stop(pid).await;
            Ok(Finished { exit_code: None, timed_out: false, cancelled: true, duration: started.elapsed() })
        }
    }
}

/// Windows PowerShell running [script]: as `-EncodedCommand` (UTF-16LE,
/// base64), so no quoting reaches a command line; output as UTF-8, not the
/// console code page; no window. Like `sh`, the last statement decides the
/// exit code: a native command's own, 1 for a failed cmdlet, else 0. The
/// script runs as written, not in a block, or `$?` would only say whether
/// the block ran.
#[cfg(windows)]
fn powershell(script: &str) -> Command {
    use base64::Engine;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    let wrapped = format!(
        "$ProgressPreference = 'SilentlyContinue'\n\
         [Console]::OutputEncoding = [Text.Encoding]::UTF8\n\
         $OutputEncoding = [Text.Encoding]::UTF8\n\
         $LASTEXITCODE = 0\n\
         {script}\n\
         if (-not $?) {{ if ($LASTEXITCODE) {{ exit $LASTEXITCODE }} else {{ exit 1 }} }}\n\
         exit 0"
    );
    let utf16: Vec<u8> = wrapped.encode_utf16().flat_map(u16::to_le_bytes).collect();
    let mut c = Command::new("powershell.exe");
    c.args(["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-EncodedCommand"])
        .arg(base64::engine::general_purpose::STANDARD.encode(utf16))
        .creation_flags(CREATE_NO_WINDOW);
    c
}

/// Ends the process group [pid] leads: what the shell started goes with it.
async fn stop(pid: Option<u32>) {
    #[cfg(unix)]
    if let Some(pid) = pid {
        // SAFETY: a signal to a process group this process created.
        unsafe {
            libc::kill(-(pid as i32), libc::SIGTERM);
        }
        let pid = pid as i32;
        tokio::spawn(async move {
            tokio::time::sleep(Duration::from_secs(3)).await;
            // SAFETY: as above; a group already gone answers ESRCH.
            unsafe {
                libc::kill(-pid, libc::SIGKILL);
            }
        });
    }
    // The tree under PowerShell: Windows has no process groups to signal.
    // Waited for: the tree is found through its root, which `kill_on_drop`
    // ends as soon as this returns.
    #[cfg(windows)]
    if let Some(pid) = pid {
        let _ = Command::new("taskkill")
            .args(["/T", "/F", "/PID", &pid.to_string()])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .await;
    }
    #[cfg(not(any(unix, windows)))]
    let _ = pid;
}

async fn pump(reader: impl AsyncRead + Unpin, stream: Stream, tx: mpsc::UnboundedSender<(Stream, String)>) {
    let mut reader = BufReader::new(reader);
    let mut buf = Vec::new();
    loop {
        buf.clear();
        // Bounded: a line without an end is cut, not held whole.
        let mut taken = (&mut reader).take(MAX_LINE as u64 + 1);
        match taken.read_until(b'\n', &mut buf).await {
            Ok(0) | Err(_) => return,
            Ok(_) => {}
        }
        let ended = buf.last() == Some(&b'\n');
        if !ended && buf.len() > MAX_LINE {
            // Drop the rest of an overlong line.
            let mut rest = Vec::new();
            if reader.read_until(b'\n', &mut rest).await.is_err() {
                return;
            }
        }
        let text = String::from_utf8_lossy(&buf[..buf.len().min(MAX_LINE)]);
        let text = text.trim_end_matches(['\n', '\r']);
        // A carriage return redraws a line (a progress bar): its last state.
        let text = text.rsplit('\r').next().unwrap_or_default();
        if tx.send((stream, text.to_string())).is_err() {
            return;
        }
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;

    async fn collect(command: &str, timeout: Duration, cancel: &Cancel) -> (Finished, Vec<(Stream, String)>) {
        let (tx, mut rx) = mpsc::unbounded_channel();
        let done = run(Spec { command, sudo_password: None, timeout }, tx, cancel).await.unwrap();
        let mut lines = Vec::new();
        while let Ok(l) = rx.try_recv() {
            lines.push(l);
        }
        (done, lines)
    }

    #[tokio::test]
    async fn lines_come_tagged_by_stream() {
        let (done, lines) = collect("echo out; echo err >&2; printf 'a\\rb\\n'; exit 3", Duration::from_secs(10), &Cancel::new()).await;
        assert_eq!(done.exit_code, Some(3));
        assert!(lines.contains(&(Stream::Out, "out".into())));
        assert!(lines.contains(&(Stream::Err, "err".into())));
        assert!(lines.contains(&(Stream::Out, "b".into())), "{lines:?}");
    }

    #[tokio::test]
    async fn a_timeout_stops_the_whole_group() {
        let marker = std::env::temp_dir().join(format!("sbm-agent-cmd-{}", std::process::id()));
        let cmd = format!("(sleep 2; touch {}) & sleep 30", marker.display());
        let (done, _) = collect(&cmd, Duration::from_millis(300), &Cancel::new()).await;
        assert!(done.timed_out);
        tokio::time::sleep(Duration::from_secs(3)).await;
        assert!(!marker.exists(), "the background child was left running");
    }

    #[tokio::test]
    async fn cancelling_stops_it() {
        let cancel = Cancel::new();
        let c = cancel.clone();
        tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(200)).await;
            c.cancel();
        });
        let (done, _) = collect("sleep 30", Duration::from_secs(60), &cancel).await;
        assert!(done.cancelled);
        assert!(done.duration < Duration::from_secs(5));
    }

    #[tokio::test]
    async fn stdin_is_closed() {
        let (done, _) = collect("cat", Duration::from_secs(5), &Cancel::new()).await;
        assert_eq!(done.exit_code, Some(0));
    }
}

#[cfg(all(test, windows))]
mod windows_tests {
    use super::*;

    async fn collect(command: &str, timeout: Duration) -> (Finished, Vec<(Stream, String)>) {
        let (tx, mut rx) = mpsc::unbounded_channel();
        let done = run(Spec { command, sudo_password: None, timeout }, tx, &Cancel::new()).await.unwrap();
        let mut lines = Vec::new();
        while let Ok(l) = rx.try_recv() {
            lines.push(l);
        }
        (done, lines)
    }

    #[tokio::test]
    async fn powershell_runs_it_and_says_how_it_ended() {
        let (done, lines) = collect("Write-Output 'out'; [Console]::Error.WriteLine('err'); Write-Output '中文'; cmd /c exit 3", Duration::from_secs(60)).await;
        assert_eq!(done.exit_code, Some(3));
        assert!(lines.contains(&(Stream::Out, "out".into())), "{lines:?}");
        assert!(lines.contains(&(Stream::Err, "err".into())), "{lines:?}");
        assert!(lines.contains(&(Stream::Out, "中文".into())), "{lines:?}");
        let (done, _) = collect("Get-Item C:\\does-not-exist-sbm", Duration::from_secs(60)).await;
        assert_eq!(done.exit_code, Some(1));
    }

    #[tokio::test]
    async fn a_timeout_ends_the_whole_tree() {
        let marker = std::env::temp_dir().join(format!("sbm-tree-{}", std::process::id()));
        let script = format!("Start-Process -NoNewWindow -FilePath powershell.exe -ArgumentList '-NoProfile','-Command','Start-Sleep 30; New-Item {}'; Start-Sleep 30", marker.display());
        let (done, _) = collect(&script, Duration::from_secs(5)).await;
        assert!(done.timed_out);
        tokio::time::sleep(Duration::from_secs(30)).await;
        assert!(!marker.exists(), "a child outlived the task");
    }

    #[tokio::test]
    async fn sudo_is_refused() {
        let (tx, _rx) = mpsc::unbounded_channel();
        let r = run(Spec { command: "whoami", sudo_password: Some("x"), timeout: Duration::from_secs(5) }, tx, &Cancel::new()).await;
        assert_eq!(r.unwrap_err().kind(), std::io::ErrorKind::Unsupported);
    }
}
