//! Pending package updates, across the package managers a server may have.
//!
//! One command decides which manager is present and prints its own output
//! verbatim under a two-line header; this reads it back. The commands are in
//! [`crate::commands`] under the `pkg` key, and each of them is deliberately
//! **read-only, unprivileged and offline**:
//!
//! - No manager is asked to refresh its index. Refreshing needs root and the
//!   network, takes seconds to minutes, and is a thing an operator decides to
//!   do — not a side effect of opening a page.
//! - Which is why a stale index is a first-class answer. `apt` off a
//!   three-month-old cache reports zero updates and is not lying about what it
//!   knows, only about what is true. [`PkgUpdates::index_age_secs`] is what
//!   lets the app say so, and it is measured on the server rather than against
//!   the phone's clock.
//!
//! **A count this cannot establish is `None`, never zero.** Only `apt`, `apk`
//! and `zypper` name the archive an update comes from well enough to tell a
//! security update from an ordinary one; saying "0 security updates" on a
//! `dnf` box would be a reassurance nothing checked.

use serde::{Deserialize, Serialize};

/// One package that has a newer version available.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PkgUpdate {
    pub name: String,
    /// The installed version. `None` where the manager did not print one —
    /// `apt` omits it for a package being pulled in as a new dependency.
    pub from: Option<String>,
    pub to: String,
    /// Whether it comes from an archive that publishes security fixes.
    ///
    /// Only meaningful where [`PkgUpdates::security`] is `Some`.
    pub security: bool,
    /// The archive or repository it comes from, as the manager named it.
    pub repo: Option<String>,
}

/// What one server answered.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct PkgUpdates {
    /// `apt`, `dnf`, `yum`, `zypper`, `pacman`, `apk`, `pkg`, `brew`, or an
    /// empty string where the server has none this build knows.
    pub manager: String,
    pub items: Vec<PkgUpdate>,
    /// How many of [`items`](Self::items) are security updates, or `None`
    /// where this manager cannot say.
    pub security: Option<usize>,
    /// Seconds since the package index was last refreshed, measured on the
    /// server. `None` where the manager's index could not be found.
    pub index_age_secs: Option<u64>,
}

impl PkgUpdates {
    pub fn total(&self) -> usize {
        self.items.len()
    }

    /// Whether the server has a package manager this build can read at all.
    pub fn supported(&self) -> bool {
        !self.manager.is_empty()
    }
}

/// Reads the `pkg` segment.
///
/// Anything before the `mgr=` header is ignored, and so is a body line that
/// does not parse: every one of these commands prints notices, warnings and
/// column headers around the part that matters, and a manager that adds
/// another one in a future release should cost a line rather than the reading.
pub fn parse_pkg(raw: &str) -> PkgUpdates {
    let mut out = PkgUpdates::default();
    let mut body = String::new();

    for line in raw.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("mgr=") {
            out.manager = if rest == "none" { String::new() } else { rest.to_string() };
            continue;
        }
        if let Some(rest) = trimmed.strip_prefix("age=") {
            // A negative age means the server's clock moved backwards between
            // the index being written and this being asked. Dropped rather
            // than clamped to zero, which would read as "just refreshed".
            out.index_age_secs = rest.parse::<i64>().ok().filter(|v| *v >= 0).map(|v| v as u64);
            continue;
        }
        body.push_str(line);
        body.push('\n');
    }

    out.items = match out.manager.as_str() {
        "apt" => parse_apt(&body),
        "dnf" | "yum" => parse_dnf(&body),
        "zypper" => parse_zypper(&body),
        "pacman" => parse_pacman(&body),
        "apk" => parse_apk(&body),
        "pkg" => parse_freebsd_pkg(&body),
        "brew" => parse_brew(&body),
        _ => Vec::new(),
    };

    // Told apart only where the manager names the archive. See the module doc.
    out.security = match out.manager.as_str() {
        "apt" | "apk" | "zypper" => Some(out.items.iter().filter(|i| i.security).count()),
        _ => None,
    };
    out
}

/// Whether an archive name is one that publishes security fixes.
///
/// Matched on the name because that is all any of these managers offers
/// without a network round trip. Covers Debian's `Debian-Security` and
/// `stable-security`, Ubuntu's `jammy-security`, and Alpine's
/// `alpine/v3.19/community` — which never says security, so an Alpine update
/// is never marked one and Alpine's count is the honest zero.
fn is_security_archive(repo: &str) -> bool {
    let lower = repo.to_ascii_lowercase();
    lower.contains("security")
}

/// `apt-get -s upgrade`, whose `Inst` lines are the stable scripting interface.
///
/// ```text
/// Inst libssl3 [3.0.11-1] (3.0.13-1 Debian-Security:12/stable-security [amd64])
/// Inst base-files [12.4] (12.5 Debian:12.6/stable [amd64])
/// Inst newdep (1.0 Debian:12.6/stable [amd64])
/// ```
///
/// `Conf` lines name the same packages a second time and are skipped.
fn parse_apt(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    for line in body.lines() {
        let Some(rest) = line.trim().strip_prefix("Inst ") else {
            continue;
        };
        let mut rest = rest.trim();

        let Some(name_end) = rest.find(char::is_whitespace) else {
            continue;
        };
        let name = rest[..name_end].to_string();
        rest = rest[name_end..].trim_start();

        // The installed version, in brackets and absent for a new dependency.
        let from = if let Some(inner) = rest.strip_prefix('[') {
            let Some(close) = inner.find(']') else { continue };
            let value = inner[..close].to_string();
            rest = inner[close + 1..].trim_start();
            Some(value)
        } else {
            None
        };

        // `(<to> <origin> [<arch>])`, where the origin may itself be several
        // space-separated words on a package coming from more than one.
        let Some(inner) = rest.strip_prefix('(') else { continue };
        let Some(close) = inner.rfind(')') else { continue };
        let mut parts = inner[..close].split_whitespace();
        let Some(to) = parts.next() else { continue };
        let repo: Vec<&str> = parts.filter(|p| !p.starts_with('[')).collect();
        let repo = if repo.is_empty() { None } else { Some(repo.join(" ")) };

        out.push(PkgUpdate {
            name,
            from,
            to: to.to_string(),
            security: repo.as_deref().is_some_and(is_security_archive),
            repo,
        });
    }
    out
}

/// `dnf check-update`, three columns.
///
/// ```text
/// openssl.x86_64          1:3.0.7-27.el9      baseos
/// kernel-core.x86_64      5.14.0-427.el9      appstream
/// ```
///
/// The installed version is not in this output, so `from` is `None` — asking
/// for it is a second command per package. Stops at `Obsoleting Packages`,
/// whose rows have the same shape and are not updates.
fn parse_dnf(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    for line in body.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if trimmed.starts_with("Obsoleting Packages") {
            break;
        }
        // A wrapped row: dnf breaks a long package name onto its own line and
        // indents the rest. Both halves are skipped rather than guessed at.
        let cols: Vec<&str> = trimmed.split_whitespace().collect();
        if cols.len() != 3 {
            continue;
        }
        // `name.arch`, and a name with no arch is a heading rather than a row.
        let Some((name, _arch)) = cols[0].rsplit_once('.') else {
            continue;
        };
        if name.is_empty() {
            continue;
        }
        out.push(PkgUpdate {
            name: name.to_string(),
            from: None,
            to: cols[1].to_string(),
            security: false,
            repo: Some(cols[2].to_string()),
        });
    }
    out
}

/// `zypper list-updates`, a pipe-separated table after a `---+---` rule.
///
/// ```text
/// S | Repository | Name    | Current Version | Available Version | Arch
/// --+------------+---------+-----------------+-------------------+------
/// v | Update     | openssl | 3.0.11-1        | 3.0.13-1          | x86_64
/// ```
fn parse_zypper(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    let mut started = false;
    for line in body.lines() {
        if !started {
            // The rule under the header, which is the only line that is
            // nothing but dashes and pluses.
            let trimmed = line.trim();
            if !trimmed.is_empty() && trimmed.chars().all(|c| c == '-' || c == '+') {
                started = true;
            }
            continue;
        }
        let cols: Vec<&str> = line.split('|').map(str::trim).collect();
        if cols.len() < 5 {
            continue;
        }
        let repo = cols[1].to_string();
        out.push(PkgUpdate {
            name: cols[2].to_string(),
            from: Some(cols[3].to_string()),
            to: cols[4].to_string(),
            security: is_security_archive(&repo),
            repo: Some(repo),
        });
    }
    out
}

/// `pacman -Qu`: `name from -> to`.
fn parse_pacman(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    for line in body.lines() {
        let cols: Vec<&str> = line.split_whitespace().collect();
        // `[ignored]` is appended to a package held by `IgnorePkg`, which is
        // still an available update and is reported as one.
        if cols.len() < 4 || cols[2] != "->" {
            continue;
        }
        out.push(PkgUpdate {
            name: cols[0].to_string(),
            from: Some(cols[1].to_string()),
            to: cols[3].to_string(),
            security: false,
            repo: None,
        });
    }
    out
}

/// `apk version -l '<'`: `name-version < available`.
///
/// ```text
/// Installed:                Available:
/// busybox-1.36.1-r19      < 1.36.1-r29
/// ```
///
/// Splitting the name from the version is the whole difficulty: both may
/// contain dashes, and apk's rule is that the version is the last two
/// dash-separated components (`1.36.1-r19`).
fn parse_apk(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    for line in body.lines() {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 3 || cols[1] != "<" {
            continue;
        }
        let Some((head, release)) = cols[0].rsplit_once('-') else {
            continue;
        };
        // The release is `r<n>`; anything else means this was not a versioned
        // package name and the line is not a row.
        if !release.starts_with('r') || !release[1..].chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        let Some((name, version)) = head.rsplit_once('-') else {
            continue;
        };
        out.push(PkgUpdate {
            name: name.to_string(),
            from: Some(format!("{version}-{release}")),
            to: cols[2].to_string(),
            // apk names no archive here, so nothing is marked — and Alpine's
            // security count is an honest zero rather than a guess.
            security: false,
            repo: None,
        });
    }
    out
}

/// FreeBSD `pkg version -vIL=`.
///
/// ```text
/// curl-8.4.0          <   needs updating (index has 8.5.0)
/// ```
fn parse_freebsd_pkg(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    for line in body.lines() {
        let Some((left, right)) = line.split_once('<') else {
            continue;
        };
        let pkg = left.trim();
        if pkg.is_empty() {
            continue;
        }
        // `(index has 8.5.0)`, the only place the new version appears.
        let to = right
            .rsplit_once("has ")
            .and_then(|(_, v)| v.split(')').next())
            .map(|v| v.trim().to_string());
        let Some(to) = to.filter(|v| !v.is_empty()) else {
            continue;
        };
        let Some((name, version)) = pkg.rsplit_once('-') else {
            continue;
        };
        out.push(PkgUpdate {
            name: name.to_string(),
            from: Some(version.to_string()),
            to,
            security: false,
            repo: None,
        });
    }
    out
}

/// `brew outdated --verbose`: `name (from) < to`.
///
/// ```text
/// openssl@3 (3.0.11) < 3.0.13
/// node (20.10.0, 20.11.0) < 21.5.0
/// ```
fn parse_brew(body: &str) -> Vec<PkgUpdate> {
    let mut out = Vec::new();
    for line in body.lines() {
        let Some((left, to)) = line.rsplit_once('<') else {
            continue;
        };
        let to = to.trim();
        if to.is_empty() {
            continue;
        }
        let left = left.trim();
        let (name, from) = match left.split_once(" (") {
            // Several installed versions are listed comma-separated; the last
            // is the one an upgrade replaces.
            Some((name, rest)) => (
                name.trim(),
                rest.trim_end_matches(')')
                    .rsplit(',')
                    .next()
                    .map(|v| v.trim().to_string()),
            ),
            None => (left, None),
        };
        if name.is_empty() {
            continue;
        }
        out.push(PkgUpdate {
            name: name.to_string(),
            from,
            to: to.to_string(),
            security: false,
            repo: None,
        });
    }
    out
}
