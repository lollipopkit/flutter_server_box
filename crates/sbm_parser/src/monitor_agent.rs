//! The monitor agent as something installed on a machine: which release is
//! the newest, how it was put there, and upgrading one that
//! `monitor/install.sh` put there. The agent (its `/update`) and the app (an
//! agent too old to say) answer with the same functions.

use serde::{Deserialize, Serialize};

/// `monitor/install.sh` on the default branch: the address its own messages
/// give for running it again.
pub const INSTALLER_URL: &str =
    "https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh";

/// A shell command that upgrades the agent `install.sh` installed here, run as
/// the account that signs in.
///
/// One line a person can read and type: the installer's `upgrade`, given no
/// `--user` or `--system`, finds the form that is installed, runs itself again
/// through sudo where that needs root (sudo asks on the terminal), and changes
/// nothing where it finds none — an agent in a container, say.
pub fn upgrade_command() -> String {
    format!("curl -fsSL {INSTALLER_URL} | sh -s -- upgrade")
}

/// Where [start_update_script] writes, in the agent's working directory (its
/// data directory, for an agent `install.sh` installed). Read back by the
/// agent that comes up after the restart: [read_update_log].
pub const UPDATE_LOG: &str = "update.log";

const START_MARK: &str = "sbm-update-start ";
const EXIT_MARK: &str = "sbm-update-exit ";

/// [start_update_script]'s exit status when the update needs root and sudo
/// would not take the password on its stdin.
pub const SUDO_REFUSED_EXIT: i32 = 3;

/// Whether starting an update needs a sudo password: OpenRC has no services
/// of an account's own, so the installer needs root there, which an agent run
/// as an ordinary account (its default form) does not have. Under systemd
/// either the account's own manager restarts it or the agent is root.
pub fn update_needs_password(systemd: bool, root: bool) -> bool {
    !systemd && !root
}

/// Starts `install.sh upgrade` for the agent this runs beside (run as the
/// agent's account, in its working directory), so that it outlives the
/// agent: the upgrade restarts it, ending every child the agent has — a
/// terminal, a command, a connection.
///
/// Under systemd it is a transient service of its own (`systemd-run`, the
/// account's manager or the system's), outside the agent's cgroup, which a
/// restart empties; elsewhere a session of its own (`setsid`). Its output
/// goes to [UPDATE_LOG] between a start and an exit mark, so the agent that
/// comes back can say how it went. Where root is needed
/// ([update_needs_password]), the password is the first line of stdin, tried
/// before anything starts: [SUDO_REFUSED_EXIT] when sudo refuses it. Exits 0
/// once the update is under way, before it is done.
///
/// For a machine that cannot reach GitHub, the agent's environment may name a
/// local `install.sh` (`SBM_INSTALLER`) and package (`SBM_INSTALL_PKG`, which
/// the installer reads), as `install.sh` alone takes the second.
pub fn start_update_script() -> String {
    format!(
        r#"set -u
umask 077
log="$PWD/{UPDATE_LOG}"
installer=$(mktemp) && runner=$(mktemp) || exit 1
if [ -n "${{SBM_INSTALLER:-}}" ]; then
  cp "$SBM_INSTALLER" "$installer" || {{ rm -f "$installer" "$runner"; exit 1; }}
elif ! curl -fsSL '{INSTALLER_URL}' -o "$installer"; then
  echo "Download of {INSTALLER_URL} failed" >&2
  rm -f "$installer" "$runner"
  exit 1
fi
pkg=""
[ -n "${{SBM_INSTALL_PKG:-}}" ] && pkg="SBM_INSTALL_PKG='$SBM_INSTALL_PKG'"
cat > "$runner" <<RUNNER
if [ "\${{1:-}}" = sudo ]; then sudo -k -S -p '' env $pkg sh '$installer' upgrade; else env $pkg sh '$installer' upgrade </dev/null; fi
echo "{EXIT_MARK}\$?"
rm -f '$installer' '$runner'
RUNNER
echo "{START_MARK}$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$log"
if [ -d /run/systemd/system ]; then
  scope=--user
  [ "$(id -u)" -eq 0 ] && scope=--system
  systemd-run "$scope" --unit "server-box-monitor-update-$(date +%s)" --collect --quiet \
    -p "StandardOutput=append:$log" -p "StandardError=append:$log" sh "$runner" || exit 1
elif [ "$(id -u)" -eq 0 ]; then
  setsid sh "$runner" </dev/null >>"$log" 2>&1 &
else
  IFS= read -r pw || pw=""
  if ! printf '%s\n' "$pw" | sudo -k -S -p '' true 2>/dev/null; then
    rm -f "$installer" "$runner" "$log"
    exit {SUDO_REFUSED_EXIT}
  fi
  printf '%s\n' "$pw" | setsid sh "$runner" sudo >>"$log" 2>&1 &
fi
echo started
"#
    )
}

/// An update [start_update_script] started, as [UPDATE_LOG] tells it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct UpdateLog {
    /// When it started (RFC 3339, UTC).
    pub started_at: Option<String>,
    /// The installer's exit status; absent while it runs, or when it was cut
    /// short.
    pub exit: Option<i32>,
    /// What the installer said, the marks left out; the last [MAX_LOG_LINES].
    pub lines: Vec<String>,
}

/// The most lines of an update's output kept.
pub const MAX_LOG_LINES: usize = 200;

pub fn read_update_log(text: &str) -> UpdateLog {
    let mut log = UpdateLog { started_at: None, exit: None, lines: Vec::new() };
    for line in text.lines() {
        if let Some(at) = line.strip_prefix(START_MARK) {
            log.started_at = Some(at.trim().to_string());
        } else if let Some(code) = line.strip_prefix(EXIT_MARK) {
            log.exit = code.trim().parse().ok();
        } else {
            log.lines.push(line.to_string());
        }
    }
    let extra = log.lines.len().saturating_sub(MAX_LOG_LINES);
    log.lines.drain(..extra);
    log
}

/// This repository's releases, newest first, 100 to a page (the most GitHub
/// gives). `page` starts at 1.
pub fn releases_url(page: u32) -> String {
    format!("https://api.github.com/repos/lollipopkit/flutter_server_box/releases?per_page={PAGE_SIZE}&page={page}")
}

const PAGE_SIZE: usize = 100;

/// How many pages of releases are read for the agent's: what `install.sh`
/// walks too.
pub const MAX_PAGES: u32 = 10;

/// What one page of [releases_url] says about the agent's releases.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReleasePage {
    /// The highest `monitor-v*` version on it, drafts and prereleases left
    /// out.
    pub newest: Option<String>,
    /// Whether a further page may hold one: this one was full and had none.
    pub read_on: bool,
}

/// One page of a GitHub releases listing. The app publishes far more often
/// than the agent, so the agent's newest release can be pages down; the
/// listing is newest first, so the first page holding one holds the newest.
/// A page that is not a listing has none and ends the walk.
pub fn release_page(listing: &str) -> ReleasePage {
    #[derive(Deserialize)]
    struct Release {
        tag_name: Option<String>,
        #[serde(default)]
        draft: bool,
        #[serde(default)]
        prerelease: bool,
    }
    let Ok(releases) = serde_json::from_str::<Vec<Release>>(listing) else {
        return ReleasePage { newest: None, read_on: false };
    };
    let newest = releases
        .iter()
        .filter(|r| !r.draft && !r.prerelease)
        .filter_map(|r| r.tag_name.as_deref()?.strip_prefix("monitor-v"))
        .filter_map(|v| semver::Version::parse(v).ok())
        .max();
    ReleasePage { read_on: newest.is_none() && releases.len() >= PAGE_SIZE, newest: newest.map(|v| v.to_string()) }
}

/// Whether an agent reporting `running` is older than `latest`; false when
/// either does not read as a version (a development build, say).
pub fn outdated(running: &str, latest: &str) -> bool {
    match (semver::Version::parse(running), semver::Version::parse(latest)) {
        (Ok(running), Ok(latest)) => running < latest,
        _ => false,
    }
}

/// How the agent was put on the machine, which decides how it is updated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InstallKind {
    /// By `install.sh`: [upgrade_command] updates it.
    Script,
    /// In a container: a new image and a new container.
    Container,
    /// By the NixOS module: the system's configuration.
    Nix,
    /// Anything else: a binary run by hand, a development build.
    Other,
}

/// Which [InstallKind] an agent running `exe` is. `in_container` is whether
/// the machine is a container (`/.dockerenv`, `/run/.containerenv`).
///
/// `install.sh` keeps the binary at `<data dir>/server-box-monitor/` for both
/// forms (`/opt/…` for the system one, `~/.local/share/…` otherwise).
pub fn install_kind(exe: &str, in_container: bool) -> InstallKind {
    if in_container {
        return InstallKind::Container;
    }
    if exe.starts_with("/nix/store/") {
        return InstallKind::Nix;
    }
    let mut parts = exe.rsplit('/');
    match (parts.next(), parts.next()) {
        (Some("server_box_monitor"), Some("server-box-monitor")) => InstallKind::Script,
        _ => InstallKind::Other,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::process::Command;

    #[test]
    fn the_update_starter_is_valid_shell() {
        let out = Command::new("sh").args(["-n", "-c", &start_update_script()]).output().unwrap();
        assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
    }

    /// The starter and its runner, run for real with stand-ins for `curl` (an
    /// installer that says what it was asked) and `setsid`, on the branch for
    /// root without systemd: the log has the marks and what the installer
    /// said.
    #[cfg(unix)]
    #[test]
    fn the_runner_writes_what_the_log_reader_reads() {
        use std::os::unix::fs::PermissionsExt;

        let dir = tempfile::tempdir().unwrap();
        let bin = dir.path().join("bin");
        std::fs::create_dir(&bin).unwrap();
        let curl = bin.join("curl");
        std::fs::write(&curl, "#!/bin/sh\nprintf 'echo \"installer: $*\"\\n' > \"$4\"\n").unwrap();
        let setsid = bin.join("setsid");
        std::fs::write(&setsid, "#!/bin/sh\nexec \"$@\"\n").unwrap();
        for f in [&curl, &setsid] {
            std::fs::set_permissions(f, std::fs::Permissions::from_mode(0o755)).unwrap();
        }
        let path = format!("{}:{}", bin.display(), std::env::var("PATH").unwrap());
        let script = start_update_script()
            .replace("[ -d /run/systemd/system ]", "false")
            .replace("elif [ \"$(id -u)\" -eq 0 ]", "elif true");
        let out = Command::new("sh").args(["-c", &script]).current_dir(dir.path()).env("PATH", path).output().unwrap();
        assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
        assert_eq!(String::from_utf8_lossy(&out.stdout).trim(), "started");
        let mut log = read_update_log("");
        for _ in 0..50 {
            log = read_update_log(&std::fs::read_to_string(dir.path().join(UPDATE_LOG)).unwrap());
            if log.exit.is_some() {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        assert!(log.started_at.is_some(), "{log:?}");
        assert_eq!(log.exit, Some(0), "{log:?}");
        assert_eq!(log.lines, ["installer: upgrade"]);
    }

    #[test]
    fn the_log_says_how_far_it_got() {
        let running = read_update_log("sbm-update-start 2026-10-14T10:00:00Z\nDownloading x\n");
        assert_eq!(running.started_at.as_deref(), Some("2026-10-14T10:00:00Z"));
        assert_eq!(running.exit, None);
        assert_eq!(running.lines, ["Downloading x"]);
        let failed = read_update_log("sbm-update-start 2026-10-14T10:00:00Z\nDownload failed\nsbm-update-exit 1\n");
        assert_eq!(failed.exit, Some(1));
        assert_eq!(read_update_log(&"x\n".repeat(MAX_LOG_LINES + 5)).lines.len(), MAX_LOG_LINES);
    }

    #[test]
    fn only_openrc_without_root_asks_for_sudo() {
        assert!(update_needs_password(false, false));
        assert!(!update_needs_password(false, true));
        assert!(!update_needs_password(true, false));
    }

    #[test]
    fn the_newest_is_the_highest_monitor_tag() {
        let page = release_page(
            r#"[
                {"tag_name": "v1.0.1773"},
                {"tag_name": "monitor-v0.4.0", "draft": true},
                {"tag_name": "monitor-v0.3.1", "prerelease": true},
                {"tag_name": "monitor-v0.2.0"},
                {"tag_name": "monitor-v0.3.0"},
                {"tag_name": "monitor-vnext"}
            ]"#,
        );
        assert_eq!(page, ReleasePage { newest: Some("0.3.0".into()), read_on: false });
    }

    /// A full page of app releases sends the walk on; a short one or one
    /// that is no listing ends it.
    #[test]
    fn a_full_page_without_one_reads_on() {
        let full = format!("[{}]", vec![r#"{"tag_name":"v1.0.1"}"#; PAGE_SIZE].join(","));
        assert_eq!(release_page(&full), ReleasePage { newest: None, read_on: true });
        assert_eq!(release_page(r#"[{"tag_name":"v1.0.1"}]"#), ReleasePage { newest: None, read_on: false });
        assert_eq!(release_page(r#"{"message":"API rate limit exceeded"}"#), ReleasePage { newest: None, read_on: false });
    }

    #[test]
    fn behind_only_when_both_read() {
        assert!(outdated("0.2.0", "0.3.0"));
        assert!(!outdated("0.3.0", "0.3.0"));
        assert!(!outdated("0.3.1", "0.3.0"));
        assert!(!outdated("dev", "0.3.0"));
        assert!(!outdated("0.2.0", ""));
    }

    #[test]
    fn where_the_binary_is_says_how_it_was_installed() {
        assert_eq!(install_kind("/opt/server-box-monitor/server_box_monitor", false), InstallKind::Script);
        assert_eq!(install_kind("/home/a/.local/share/server-box-monitor/server_box_monitor", false), InstallKind::Script);
        assert_eq!(install_kind("/opt/server-box-monitor/server_box_monitor", true), InstallKind::Container);
        assert_eq!(install_kind("/nix/store/abc-server-box-monitor/bin/server_box_monitor", false), InstallKind::Nix);
        assert_eq!(install_kind("/home/a/proj/monitor/target/debug/server_box_monitor", false), InstallKind::Other);
    }

    #[test]
    fn the_command_is_valid_shell() {
        let out = Command::new("sh").args(["-n", "-c", &upgrade_command()]).output().unwrap();
        assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
    }

    /// No mode: the installer works out which form is there.
    #[test]
    fn it_leaves_the_form_to_the_installer() {
        let cmd = upgrade_command();
        assert!(cmd.ends_with("| sh -s -- upgrade"), "{cmd}");
        assert!(!cmd.contains("--system") && !cmd.contains("--user") && !cmd.contains("sudo"), "{cmd}");
    }
}
