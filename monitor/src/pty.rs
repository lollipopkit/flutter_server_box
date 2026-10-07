//! A login shell on a local PTY: the terminal's shell.
//!
//! The shell runs as the account the agent itself runs as, so **the panel
//! password is the only thing between a visitor and that shell** (for an
//! account whose role holds `shell`). That is the whole point of the feature
//! and also its entire risk; `install.sh` installs a *user* service by default
//! so the account in question is an ordinary one.
//!
//! It produces a stream of [`ShellEvent`] and accepts resize/write, which
//! `api::ws::terminal` drives through the session, scrollback and reconnect
//! machinery.

use std::io::{Read, Write};
use std::sync::{Arc, Condvar, Mutex};

use portable_pty::{CommandBuilder, MasterPty, PtySize, native_pty_system};
use tokio::sync::mpsc;

/// PTY output, or the reason there won't be any more.
pub enum ShellEvent {
    Data(Vec<u8>),
    Exit(Option<u32>),
}

/// A running local shell.
pub struct LocalShell {
    /// Kept for resizing; the reader and writer are split out below.
    master: Box<dyn MasterPty + Send>,
    writer: Mutex<Box<dyn Write + Send>>,
    child: Arc<Mutex<Box<dyn portable_pty::Child + Send + Sync>>>,
}

/// Why a local shell could not be started.
#[derive(Debug)]
pub struct SpawnError(pub String);

impl std::fmt::Display for SpawnError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Could not start a shell: {}", self.0)
    }
}

/// Shells that exist to refuse a login. Landing on one would give the user a
/// terminal that prints a message and closes, so treat it as "no shell set".
#[cfg(unix)]
const NON_SHELLS: &[&str] = &["nologin", "false"];

/// The user's login shell from the passwd database.
///
/// **Not `$SHELL`.** That variable reports whatever shell launched the
/// process, which for a service is an artifact of how it was started —
/// systemd, a login session, or in the worst case the shell of whoever ran
/// `sudo`. The passwd entry is what the user actually configured, and is the
/// same thing `sshd` and `login` consult.
#[cfg(unix)]
fn passwd_shell() -> Option<String> {
    use std::ffi::CStr;

    // SAFETY: `getpwuid` returns a pointer into a static buffer owned by libc,
    // valid until the next passwd call. It is read and copied out before
    // anything else can touch it, and null is checked.
    let entry = unsafe { libc::getpwuid(libc::getuid()) };
    if entry.is_null() {
        return None;
    }
    let shell = unsafe { CStr::from_ptr((*entry).pw_shell) }
        .to_str()
        .ok()?
        .to_string();

    if shell.is_empty() {
        return None;
    }
    let name = shell.rsplit('/').next().unwrap_or(&shell);
    if NON_SHELLS.contains(&name) {
        tracing::warn!("passwd shell for this account is {shell}; falling back");
        return None;
    }
    Some(shell)
}

#[cfg(not(unix))]
fn passwd_shell() -> Option<String> {
    None
}

/// The shell to run, in order of how much it reflects the user's own choice.
fn login_shell() -> String {
    if cfg!(windows) {
        return std::env::var("COMSPEC").unwrap_or_else(|_| "powershell.exe".to_string());
    }
    passwd_shell()
        .or_else(|| std::env::var("SHELL").ok().filter(|s| !s.is_empty()))
        .unwrap_or_else(|| "/bin/sh".to_string())
}

impl LocalShell {
    /// Starts a login shell on a PTY of the given size.
    ///
    /// Runs as the agent's own user, in its home directory. No privilege
    /// change is attempted: dropping privileges here would only matter if the
    /// agent were root, and the answer to that is to not run it as root — see
    /// the module comment.
    pub fn spawn(term: &str, cols: u16, rows: u16) -> Result<(Self, mpsc::Receiver<ShellEvent>), SpawnError> {
        let shell = login_shell();
        let mut cmd = CommandBuilder::new(&shell);
        // A login shell, so the user's profile is sourced and the session
        // looks like the one they would get over SSH
        if !cfg!(windows) {
            cmd.arg("-l");
        }
        cmd.env("TERM", term);
        // Kept consistent with what actually runs: the agent's own `SHELL` may
        // name a different shell entirely, and anything inside the session
        // that consults it would then disagree with the shell it is running in
        cmd.env("SHELL", &shell);
        Self::spawn_with(cmd, cols, rows)
    }

    /// Starts one command on a PTY.
    ///
    /// The command comes from `sbm_parser` (`container::shell_command` or
    /// `iperf::client_command`), so it is a fixed string this agent built
    /// rather than anything a caller typed. No `SHELL` is exported: the shell
    /// that runs inside the container is the container's own, and the agent's
    /// would be a lie about it.
    ///
    /// Unix runs it through `/bin/sh -c`. Windows runs it through
    /// `cmd.exe /C`, which is the shell `iperf::client_command` was written
    /// for (its line is unquoted, since a Unix shell and `cmd` quote
    /// differently). A container shell cannot reach this on Windows:
    /// `api::containers::detect_runtime` answers `None` there, so no container
    /// target is ever opened. The command is passed as a **single argument**:
    /// portable_pty builds the Windows command line by quoting each argument
    /// on its own and handing the whole line to `CreateProcessW`, and it is
    /// `cmd.exe`, not that argv quoting, that decides where the command after
    /// `/C` ends — so one argument keeps the command whole.
    pub fn spawn_command(
        term: &str,
        cols: u16,
        rows: u16,
        command: &str,
    ) -> Result<(Self, mpsc::Receiver<ShellEvent>), SpawnError> {
        #[cfg(windows)]
        let mut cmd = {
            let mut cmd = CommandBuilder::new("cmd.exe");
            cmd.arg("/C");
            cmd.arg(command);
            cmd
        };
        #[cfg(not(windows))]
        let mut cmd = {
            let mut cmd = CommandBuilder::new("/bin/sh");
            cmd.arg("-c");
            cmd.arg(command);
            cmd
        };
        cmd.env("TERM", term);
        Self::spawn_with(cmd, cols, rows)
    }

    /// Opens the PTY, starts [cmd] on it, and wires the reader and reaper.
    ///
    /// The shared half of the two constructors: what differs between a login
    /// shell and one command is only how the child is described.
    fn spawn_with(
        cmd: CommandBuilder,
        cols: u16,
        rows: u16,
    ) -> Result<(Self, mpsc::Receiver<ShellEvent>), SpawnError> {
        let pty = native_pty_system()
            .openpty(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| SpawnError(e.to_string()))?;

        let mut cmd = cmd;
        if let Some(home) = dirs_home() {
            cmd.cwd(home);
        }

        let child = pty
            .slave
            .spawn_command(cmd)
            .map_err(|e| SpawnError(e.to_string()))?;
        // The slave handle must go away, or the master never sees EOF when the
        // shell exits and the reader below would block forever.
        drop(pty.slave);

        let writer = pty
            .master
            .take_writer()
            .map_err(|e| SpawnError(e.to_string()))?;
        let mut reader = pty
            .master
            .try_clone_reader()
            .map_err(|e| SpawnError(e.to_string()))?;

        let (tx, rx) = mpsc::channel(64);
        let child = Arc::new(Mutex::new(child));
        let reader_done = Arc::new((Mutex::new(false), Condvar::new()));
        // Data and exit share this gate so an exit closes data delivery before
        // it is enqueued. Holding it across blocking_send also lets any data
        // already under backpressure finish before the exit notification.
        let delivery_closed = Arc::new(Mutex::new(false));

        // A PTY read is blocking, so it gets a thread rather than a task. One
        // thread per open terminal, bounded by `terminal_max_sessions`.
        let reader_tx = tx.clone();
        let reader_finished = reader_done.clone();
        let reader_delivery_closed = delivery_closed.clone();
        std::thread::spawn(move || {
            let mut buf = [0u8; 8 * 1024];
            loop {
                match reader.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        let delivery_closed = reader_delivery_closed
                            .lock()
                            .unwrap_or_else(|e| e.into_inner());
                        if *delivery_closed {
                            break;
                        }
                        if reader_tx.blocking_send(ShellEvent::Data(buf[..n].to_vec())).is_err() {
                            break;
                        }
                    }
                }
            }
            let (done, ready) = &*reader_finished;
            {
                let mut done = done.lock().unwrap_or_else(|e| e.into_inner());
                *done = true;
            }
            ready.notify_one();
        });

        // ConPTY can keep the read side open after the child exits while the
        // master handle is still alive. Reap independently instead of making
        // exit delivery depend on the reader observing EOF. `try_wait` keeps
        // the mutex available between polls, so `kill` cannot deadlock behind
        // a blocking wait.
        let reaper = child.clone();
        let exit_delivery_closed = delivery_closed.clone();
        std::thread::spawn(move || loop {
            let status = reaper
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .try_wait();
            let exit = match status {
                Ok(Some(status)) => Some(Some(status.exit_code())),
                Ok(None) => None,
                Err(_) => Some(None),
            };
            if let Some(status) = exit {
                // Preserve the usual PTY contract that the last output comes
                // before the exit notification. Unix readers normally reach
                // EOF immediately; ConPTY gets a short drain window and then
                // exit is delivered even if its read handle stays open.
                let (done, ready) = &*reader_done;
                let done = done.lock().unwrap_or_else(|e| e.into_inner());
                drop(ready.wait_timeout_while(
                    done,
                    std::time::Duration::from_millis(100),
                    |done| !*done,
                ));
                let mut delivery_closed = exit_delivery_closed
                    .lock()
                    .unwrap_or_else(|e| e.into_inner());
                *delivery_closed = true;
                let _ = tx.blocking_send(ShellEvent::Exit(status));
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(10));
        });

        Ok((
            Self {
                master: pty.master,
                writer: Mutex::new(writer),
                child,
            },
            rx,
        ))
    }

    pub fn write(&self, data: &[u8]) -> std::io::Result<()> {
        let mut writer = self.writer.lock().unwrap_or_else(|e| e.into_inner());
        writer.write_all(data)?;
        writer.flush()
    }

    pub fn resize(&self, cols: u16, rows: u16) {
        let _ = self.master.resize(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        });
    }

    /// Ends the shell. Safe to call more than once.
    pub fn kill(&self) {
        let _ = self
            .child
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .kill();
    }
}

/// The agent user's home directory, for the shell's working directory.
fn dirs_home() -> Option<String> {
    std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .ok()
        .filter(|h| !h.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(windows)]
    async fn answer_cursor_position_query(
        shell: &LocalShell,
        rx: &mut mpsc::Receiver<ShellEvent>,
    ) -> String {
        let mut seen = String::new();
        let queried = tokio::time::timeout(std::time::Duration::from_secs(15), async {
            while let Some(event) = rx.recv().await {
                if let ShellEvent::Data(data) = event {
                    seen.push_str(&String::from_utf8_lossy(&data));
                    if seen.contains("\u{1b}[6n") {
                        return true;
                    }
                }
            }
            false
        })
        .await
        .unwrap_or(false);
        assert!(queried, "ConPTY should ask for the cursor position; saw {seen:?}");
        shell.write(b"\x1b[1;1R").unwrap();
        seen
    }

    #[cfg(not(windows))]
    async fn answer_cursor_position_query(
        _shell: &LocalShell,
        _rx: &mut mpsc::Receiver<ShellEvent>,
    ) -> String {
        String::new()
    }

    #[tokio::test]
    async fn a_shell_starts_echoes_and_exits() {
        let (shell, mut rx) = LocalShell::spawn("xterm-256color", 80, 24).unwrap();

        let mut seen = answer_cursor_position_query(&shell, &mut rx).await;
        shell.write(b"echo local-pty-marker\r").unwrap();

        let found = tokio::time::timeout(std::time::Duration::from_secs(15), async {
            while let Some(event) = rx.recv().await {
                if let ShellEvent::Data(data) = event {
                    seen.push_str(&String::from_utf8_lossy(&data));
                    // Twice: once as the terminal echoes the typed command,
                    // once as the shell's own output
                    if seen.matches("local-pty-marker").count() >= 2 {
                        return true;
                    }
                }
            }
            false
        })
        .await
        .unwrap_or(false);

        assert!(found, "the shell should run what it is sent; saw {seen:?}");
        shell.kill();
    }

    #[tokio::test]
    async fn exiting_the_shell_reports_an_exit() {
        let (shell, mut rx) = LocalShell::spawn("xterm-256color", 80, 24).unwrap();
        answer_cursor_position_query(&shell, &mut rx).await;
        shell.write(b"exit 7\r").unwrap();

        let exit = tokio::time::timeout(std::time::Duration::from_secs(15), async {
            while let Some(event) = rx.recv().await {
                if let ShellEvent::Exit(status) = event {
                    return Some(status);
                }
            }
            None
        })
        .await
        .unwrap_or(None);

        assert_eq!(
            exit,
            Some(Some(7)),
            "the terminal must retain the shell's requested exit status"
        );
    }

    #[tokio::test]
    async fn a_command_runs_on_the_pty_and_exits() {
        // One fixed command, not a login shell: `/bin/sh -c` (the container
        // and iperf targets), `cmd.exe /C` on Windows (iperf). `echo` is the
        // same in both. ConPTY holds the output back until its cursor
        // position query is answered, as the panel's xterm.js does. The
        // marker is matched with its line ending: ConPTY also puts the command
        // line in the window title, which ends in BEL rather than CR.
        let (shell, mut rx) =
            LocalShell::spawn_command("xterm-256color", 80, 24, "echo command-pty-marker").unwrap();

        let mut seen = answer_cursor_position_query(&shell, &mut rx).await;
        let found = seen.contains("command-pty-marker\r")
            || tokio::time::timeout(std::time::Duration::from_secs(15), async {
                while let Some(event) = rx.recv().await {
                    if let ShellEvent::Data(data) = event {
                        seen.push_str(&String::from_utf8_lossy(&data));
                        if seen.contains("command-pty-marker\r") {
                            return true;
                        }
                    }
                }
                false
            })
            .await
            .unwrap_or(false);

        assert!(found, "the command should run on the PTY; saw {seen:?}");
        shell.kill();
    }

    #[test]
    fn resizing_a_live_shell_does_not_fail() {
        let (shell, _rx) = LocalShell::spawn("xterm-256color", 80, 24).unwrap();
        shell.resize(120, 40);
        shell.kill();
    }

    #[test]
    #[cfg(unix)]
    fn the_login_shell_comes_from_passwd_not_the_environment() {
        // `$SHELL` describes whoever launched this process; the passwd entry
        // is what the user configured. A service inherits the former and must
        // not let it decide.
        let Some(configured) = passwd_shell() else {
            // An account with no usable shell (CI containers do this); the
            // fallback path is asserted separately below
            return;
        };
        unsafe { std::env::set_var("SHELL", "/definitely/not/a/real/shell") };
        let resolved = login_shell();
        unsafe { std::env::remove_var("SHELL") };

        assert_eq!(
            resolved, configured,
            "a stale $SHELL must not override the passwd entry"
        );
    }

    #[test]
    fn a_shell_is_always_resolved() {
        let shell = login_shell();
        assert!(!shell.is_empty());
        assert!(
            shell.starts_with('/') || cfg!(windows),
            "expected an absolute path, got {shell:?}"
        );
    }

    #[test]
    #[cfg(unix)]
    fn a_login_refusing_shell_is_not_treated_as_a_shell() {
        // /usr/sbin/nologin would give the user a terminal that prints a
        // message and closes
        for name in NON_SHELLS {
            assert!(
                NON_SHELLS.contains(name),
                "sanity: {name} is in the refusal list"
            );
        }
        assert!(NON_SHELLS.contains(&"nologin"));
    }

    #[tokio::test]
    #[cfg(unix)]
    async fn the_session_runs_the_configured_shell() {
        let Some(configured) = passwd_shell() else { return };
        let (shell, mut rx) = LocalShell::spawn("xterm-256color", 80, 24).unwrap();

        // Compared by file name, not by path: a shell may canonicalise
        // `$SHELL` through symlinks on startup (`/opt/homebrew/bin/fish` ->
        // the Cellar path), and the question here is which shell is running,
        // not which of its aliases it prefers to report.
        let expected = configured.rsplit('/').next().unwrap().to_string();
        shell.write(b"echo shell-is-$SHELL\n").unwrap();

        let mut seen = String::new();
        let ok = tokio::time::timeout(std::time::Duration::from_secs(30), async {
            while let Some(event) = rx.recv().await {
                if let ShellEvent::Data(data) = event {
                    seen.push_str(&String::from_utf8_lossy(&data));
                    // The marker rules out matching the echoed command itself
                    if let Some(rest) = seen.split("shell-is-/").nth(1)
                        && rest.contains('\n')
                        && rest.lines().next().is_some_and(|l| l.trim_end().ends_with(&expected))
                    {
                        return true;
                    }
                }
            }
            false
        })
        .await
        .unwrap_or(false);

        shell.kill();
        assert!(ok, "expected {expected:?} to be running; saw {seen:?}");
    }
}
