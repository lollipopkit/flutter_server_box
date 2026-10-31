//! Whether something starts this monitor again when it exits, asked of the
//! supervisor itself rather than guessed from the environment: variables
//! such as `INVOCATION_ID` or `RC_SVCNAME` are inherited by everything a
//! service starts, a shell a person runs the monitor from included.
//!
//! - systemd: the unit this process's cgroup names has this process as its
//!   `MainPID` and a `Restart=` other than `no`;
//! - OpenRC: the parent process is `supervise-daemon`.
//!
//! A container's restart policy cannot be read from inside it, so a
//! container is not taken as supervised.

/// What the monitor exits with to be restarted: not 0, which
/// `Restart=on-failure` would leave stopped (`EX_TEMPFAIL`).
pub const EXIT_CODE: i32 = 75;

/// Whether this process is restarted after it exits with [EXIT_CODE]. Blocking (it may run
/// `systemctl`).
pub fn restarts_on_exit() -> bool {
    #[cfg(target_os = "linux")]
    {
        let pid = std::process::id();
        openrc_supervised() || systemd_restarts(pid)
    }
    #[cfg(not(target_os = "linux"))]
    {
        false
    }
}

#[cfg(target_os = "linux")]
fn openrc_supervised() -> bool {
    let Ok(stat) = std::fs::read_to_string("/proc/self/stat") else { return false };
    let Some(ppid) = parent_pid(&stat) else { return false };
    std::fs::read_to_string(format!("/proc/{ppid}/comm")).is_ok_and(|c| c.trim() == "supervise-daemon")
}

#[cfg(target_os = "linux")]
fn systemd_restarts(pid: u32) -> bool {
    let Ok(cgroup) = std::fs::read_to_string("/proc/self/cgroup") else { return false };
    let Some((unit, user)) = unit_of(&cgroup) else { return false };
    let mut cmd = std::process::Command::new("systemctl");
    if user {
        cmd.arg("--user");
    }
    let Ok(out) = cmd.args(["show", "-p", "MainPID", "-p", "Restart", "--", &unit]).output() else { return false };
    out.status.success() && restarts(&String::from_utf8_lossy(&out.stdout), pid)
}

/// The parent's pid in `/proc/<pid>/stat`: the field after the command,
/// which is in parentheses and may hold anything, spaces and `)` included.
#[cfg(any(target_os = "linux", test))]
fn parent_pid(stat: &str) -> Option<u32> {
    let rest = &stat[stat.rfind(')')? + 1..];
    rest.split_whitespace().nth(1)?.parse().ok()
}

/// The service unit a cgroup v2 (`0::/…/x.service`) or v1 (`…:name=systemd:/…`)
/// line names, and whether it is the user manager's.
#[cfg(any(target_os = "linux", test))]
fn unit_of(cgroup: &str) -> Option<(String, bool)> {
    let path = cgroup
        .lines()
        .find_map(|l| l.strip_prefix("0::").or_else(|| l.split_once(":name=systemd:").map(|(_, p)| p)))?;
    let unit = path.split('/').rev().find(|s| s.ends_with(".service"))?;
    Some((unit.to_string(), path.contains("/user@")))
}

/// Whether `systemctl show -p MainPID -p Restart` says [pid] is the unit's
/// main process and it is restarted after an [EXIT_CODE] exit (`always`,
/// `on-failure`; `on-abnormal` and the rest are not).
#[cfg(any(target_os = "linux", test))]
fn restarts(show: &str, pid: u32) -> bool {
    let value = |key: &str| show.lines().find_map(|l| l.strip_prefix(key)?.strip_prefix('='));
    value("MainPID").and_then(|p| p.trim().parse::<u32>().ok()) == Some(pid)
        && value("Restart").is_some_and(|r| matches!(r.trim(), "always" | "on-failure"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_parent_follows_the_command_whatever_it_holds() {
        assert_eq!(parent_pid("42 (server_box_mon) S 7 42 42 0 -1"), Some(7));
        assert_eq!(parent_pid("42 (a) b) c) S 9 42"), Some(9));
        assert_eq!(parent_pid("garbage"), None);
    }

    #[test]
    fn the_unit_is_read_from_either_cgroup_layout() {
        assert_eq!(
            unit_of("0::/user.slice/user-1000.slice/user@1000.service/app.slice/server-box-monitor.service\n"),
            Some(("server-box-monitor.service".into(), true))
        );
        assert_eq!(unit_of("0::/system.slice/server-box-monitor.service\n"), Some(("server-box-monitor.service".into(), false)));
        assert_eq!(unit_of("12:cpu:/\n1:name=systemd:/system.slice/sbm.service\n"), Some(("sbm.service".into(), false)));
        // A shell in a terminal's scope: no service of its own.
        assert_eq!(unit_of("0::/user.slice/user-1000.slice/session-3.scope\n"), None);
    }

    #[test]
    fn only_the_main_process_of_a_restarting_unit_is_restarted() {
        assert!(restarts("MainPID=42\nRestart=always\n", 42));
        assert!(restarts("Restart=on-failure\nMainPID=42\n", 42));
        assert!(!restarts("MainPID=42\nRestart=no\n", 42));
        assert!(!restarts("MainPID=42\nRestart=on-abnormal\n", 42));
        // A shell the unit started, running the monitor by hand.
        assert!(!restarts("MainPID=41\nRestart=always\n", 42));
        assert!(!restarts("", 42));
    }
}

/// Run by systemd for real (Linux, a user manager):
///
///     SBM_E2E_SUPERVISOR=1 cargo test -p server_box_monitor --lib supervisor_e2e -- --ignored --nocapture
///
/// The test binary is started as a transient unit with each `Restart=`, as
/// its main process and as a child of it, and asked each time.
#[cfg(all(test, target_os = "linux"))]
mod e2e {
    use std::process::Command;

    /// What the copy started in a unit answers.
    const ASKED: &str = "SBM_E2E_SUPERVISOR_ASKED";

    #[test]
    #[ignore]
    fn supervisor_e2e() {
        if let Ok(expected) = std::env::var(ASKED) {
            // Inside the unit: say what this process is, through the exit code.
            let restarts = super::restarts_on_exit();
            std::process::exit(if restarts.to_string() == expected { 0 } else { 1 });
        }
        if std::env::var_os("SBM_E2E_SUPERVISOR").is_none() {
            eprintln!("SBM_E2E_SUPERVISOR is not set");
            return;
        }
        let me = std::env::current_exe().unwrap();
        let me = me.to_str().unwrap();
        let args = ["--exact", "utils::supervisor::e2e::supervisor_e2e", "--ignored", "--nocapture"];
        let run = |restart: &str, through_shell: bool, expected: bool| {
            let unit = format!("sbm-supervisor-e2e-{}-{}", std::process::id(), restart);
            let mut cmd = Command::new("systemd-run");
            cmd.args(["--user", "--wait", "--quiet", "--collect", &format!("--unit={unit}"), &format!("--property=Restart={restart}")]);
            cmd.arg(format!("--setenv={ASKED}={expected}"));
            if through_shell {
                // A shell the unit runs, starting the monitor by hand: it
                // inherits INVOCATION_ID but is not the main process.
                cmd.args(["sh", "-c", "\"$0\" \"$@\"; exit $?", me]).args(args);
            } else {
                cmd.arg(me).args(args);
            }
            let status = cmd.status().unwrap();
            // With Restart=always a unit whose process exits is started
            // again; stop it after the first answer.
            let _ = Command::new("systemctl").args(["--user", "stop", &unit]).status();
            assert!(status.success(), "Restart={restart}, through a shell: {through_shell}, expected {expected}");
        };
        run("on-failure", false, true);
        run("no", false, false);
        run("on-abnormal", false, false);
        run("on-failure", true, false);
        // Not under any unit of its own (this test, run from a shell).
        assert!(!super::restarts_on_exit());
    }
}
