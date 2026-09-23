//! The machine's accounts — the passwd and group catalogs, one account's own
//! detail, and the commands that create, change and remove one.
//!
//! Ported from the app's `lib/data/service/user_manager.dart` and
//! `lib/data/model/server/system_user.dart`; the Dart implementation stays
//! until this one is asserted identical against the same cases
//! (`tests/user_compat.rs` is that assertion).
//!
//! Pure like the rest of this crate: a parser takes the text the machine's
//! commands printed and returns a value, and a command builder takes a
//! description and returns the text to run. Nothing here runs anything, so the
//! app reaches it over SSH and the agent reaches it over a local shell and both
//! read one implementation.
//!
//! ## Linux only
//!
//! The catalog is `/etc/passwd` and `/etc/group`, read through `getent` where
//! the machine has it. That is the account database on Linux and on nothing
//! else: macOS has `dscl` and a directory service behind it, and Windows has
//! neither the files nor the commands. A caller on another platform is told so
//! rather than shown a partial answer — `cat /etc/passwd` on macOS prints the
//! legacy file, which names no account anyone logs in with.
//!
//! ## What is deliberately not here
//!
//! **Privilege.** Every command here needs root, and none of them carries a
//! password: `sudo -S` reads one from stdin, which is the caller's business.
//! Written into a command line it would reach the agent's audit log and the
//! machine's process list.
//!
//! **The account's own password.** It is part of [`UserDraft`] and reaches
//! `chpasswd` on stdin, inside the script the caller runs — never as an
//! argument, for the same reason.
//!
//! **Reading an account is not an action on it.** [`detail_script`] runs
//! `getent shadow`, `passwd -S` and `sudo -nlU` as whatever account the caller
//! already is, and every one of them is allowed to fail. `/etc/shadow` and an
//! `authorized_keys` are root-only on a normal machine, so an unprivileged
//! session reads nothing — and every [`UserDetail`] field is nullable, where
//! `None` means "not readable from here", never "absent".
//!
//! **`useradd`, `usermod`, `userdel` dialects.** BusyBox has all three with a
//! subset of the flags, and its `useradd` has no `-M`. The flags used here are
//! the ones both accept, and a machine that refuses one says so in `stderr`,
//! which the caller reports verbatim.

use std::collections::HashMap;
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::common::single_quote;

/// The current account's name, on the catalog script's output.
pub const CURRENT_MARKER: &str = "SrvBoxUsers.Current\t";
/// The uid below which an account is a system account, from `/etc/login.defs`.
pub const UID_MIN_MARKER: &str = "SrvBoxUsers.UidMin\t";
pub const PASSWD_MARKER: &str = "SrvBoxUsers.Passwd";
pub const GROUP_MARKER: &str = "SrvBoxUsers.Group";

pub const DETAIL_SHADOW_MARKER: &str = "SrvBoxUserDetail.Shadow";
pub const DETAIL_STATUS_MARKER: &str = "SrvBoxUserDetail.Status";
pub const DETAIL_KEYS_MARKER: &str = "SrvBoxUserDetail.Keys";
pub const DETAIL_SUDO_MARKER: &str = "SrvBoxUserDetail.Sudo";

/// Written only when `authorized_keys` was actually read. Its absence is what
/// tells "could not read it" from "read it, there were none" — a distinction a
/// trailing `|| true` used to swallow, reporting an unreadable file as an
/// account with no keys at all.
pub const DETAIL_KEYS_READ_MARKER: &str = "SrvBoxUserDetail.KeysRead";

/// Prints the key-type token of each line and nothing else.
///
/// `authorized_keys` is written by whoever owns the account, and the section
/// markers above travel as plain text on the same stream. Passing its lines
/// through meant an unprivileged user could put `SrvBoxUserDetail.Sudo` in
/// their own file and fabricate the sudo rule their page then displayed. A
/// token matching this pattern cannot collide with a marker.
const KEY_TYPE_FILTER: &str = r"awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^(ssh-|ecdsa-|sk-)/) { print $i; break } }'";

/// Reads the current account, the system-account threshold and both catalogs.
///
/// Handed to `sh` rather than run as a command: the script has an `if`, and the
/// account's login shell — which is what runs a command given without an entry
/// — may be fish, which does not read one.
pub const LIST_SCRIPT: &str = r#"set -e
printf 'SrvBoxUsers.Current\t'
id -un
printf 'SrvBoxUsers.UidMin\t'
awk '$1 == "UID_MIN" { print $2; found=1; exit } END { if (!found) print 1000 }' /etc/login.defs 2>/dev/null || printf '1000\n'
printf 'SrvBoxUsers.Passwd\n'
if command -v getent >/dev/null 2>&1; then
  getent passwd
else
  cat /etc/passwd
fi
printf 'SrvBoxUsers.Group\n'
if command -v getent >/dev/null 2>&1; then
  getent group
elif [ -r /etc/group ]; then
  cat /etc/group
fi
"#;

/// One account, as `/etc/passwd` and `/etc/group` describe it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SystemUser {
    pub name: String,
    pub uid: u32,
    pub gid: u32,
    /// The gecos field. Everything up to the first comma is conventionally the
    /// full name, and it is left whole here: splitting it is a presentation
    /// decision, and the app shows it whole.
    pub comment: String,
    pub home: String,
    pub shell: String,
    /// `None` where no group carries this account's gid, which is a passwd
    /// entry with no matching group rather than an account with no group.
    pub primary_group: Option<String>,
    /// Every other group this account is a member of, without the primary one,
    /// sorted. An empty list means it is in none.
    pub supplementary_groups: Vec<String>,
}

impl SystemUser {
    pub fn is_root(&self) -> bool {
        self.uid == 0
    }

    /// Whether this is a system account by the machine's own threshold.
    ///
    /// The threshold is [`UserCatalog::uid_min`], read from `/etc/login.defs`
    /// rather than assumed to be 1000: a distribution that sets 500 and a
    /// machine whose administrator changed it both answer for themselves.
    pub fn is_system(&self, uid_min: u32) -> bool {
        self.uid < uid_min
    }

    /// Whether the account cannot be logged into with a password because its
    /// shell is `/usr/sbin/nologin` or `/bin/false`.
    ///
    /// About the shell only: a locked password is [`PasswordState::Locked`],
    /// and an account can have either without the other.
    pub fn login_disabled(&self) -> bool {
        let executable = self
            .shell
            .rsplit('/')
            .next()
            .unwrap_or_default()
            .to_lowercase();
        executable == "false" || executable == "nologin"
    }
}

/// The machine's accounts and the two facts the catalog carries about itself.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserCatalog {
    /// The account that ran the script.
    pub current_user: String,
    /// The uid below which an account is a system account.
    pub uid_min: u32,
    /// Sorted by uid, then by name.
    pub users: Vec<SystemUser>,
}

impl UserCatalog {
    pub fn find(&self, name: &str) -> Option<&SystemUser> {
        self.users.iter().find(|user| user.name == name)
    }
}

/// Whether an account can be logged into with a password.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PasswordState {
    /// A hash is stored, so a password login is possible.
    Set,
    /// No password login: `!`, `!!` or `*` in the shadow field.
    Locked,
    /// An empty shadow field, which is no password at all — not the same thing
    /// as locked, and the half that must not be guessed at.
    None,
}

/// What `/etc/shadow`, `authorized_keys` and sudoers say about one account.
///
/// Every field is an `Option` and `None` means "not readable from here", never
/// "absent": all three sources are root-only on a normal machine, and an
/// unprivileged session would otherwise report every account as having no
/// password and no keys.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UserDetail {
    pub password_state: Option<PasswordState>,
    /// Days since the epoch the password was last changed, as an instant.
    pub password_changed_millis: Option<i64>,
    /// `None` when shadow was unreadable; absent-from-the-record is
    /// [`Self::never_expires`].
    pub expires_millis: Option<i64>,
    pub never_expires: bool,
    /// Distinct key types in the account's `authorized_keys`, in file order. An
    /// empty list means the file was read and held none; `None` means it could
    /// not be read.
    pub ssh_key_types: Option<Vec<String>>,
    /// The right-hand side of the account's sudoers entry, e.g.
    /// `NOPASSWD: ALL`.
    pub sudo_rule: Option<String>,
}

impl UserDetail {
    /// Nothing was readable at all, which is what an unprivileged session gets.
    pub fn is_empty(&self) -> bool {
        self.password_state.is_none()
            && self.password_changed_millis.is_none()
            && self.expires_millis.is_none()
            && !self.never_expires
            && self.ssh_key_types.is_none()
            && self.sudo_rule.is_none()
    }
}

/// What a caller wants an account to be.
///
/// The same fields for a new account and for a change to one, because the two
/// forms ask for the same things; [`edit_command`] reads the difference against
/// the account as it is.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UserDraft {
    pub name: String,
    #[serde(default)]
    pub comment: String,
    #[serde(default)]
    pub home: String,
    #[serde(default)]
    pub shell: String,
    #[serde(default)]
    pub primary_group: String,
    #[serde(default)]
    pub supplementary_groups: Vec<String>,
    /// Whether a new account gets a home directory. Ignored when changing one,
    /// where [`Self::move_home`] is the question instead.
    #[serde(default)]
    pub create_home: bool,
    /// Whether an existing home directory is moved when [`Self::home`] changes.
    #[serde(default)]
    pub move_home: bool,
    /// A system account, with no aging and a uid below the machine's threshold.
    /// Only the create form offers it.
    #[serde(default)]
    pub system: bool,
    /// The password to set, when the caller is setting one. `None` and `Some("")`
    /// both mean "leave it alone", and it travels inside the script on stdin —
    /// see the module doc.
    #[serde(default)]
    pub password: Option<String>,
}

/// Why a draft, a name or a command was refused.
///
/// The case is what the caller is told, and the client phrases it: an agent
/// that answered with an English sentence would be one the panel could not
/// translate, and a rule added later would arrive as prose in whichever
/// language the agent was built in.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UserError {
    /// Not a name `useradd` accepts.
    InvalidName,
    /// A field that would break the line it is written on.
    LineBreak,
    InvalidPrimaryGroup,
    InvalidSupplementaryGroup,
    /// A password with a line break in it, which would be a second line of
    /// `chpasswd` input — a second `name:password` pair, and a second account's
    /// password changed.
    PasswordLineBreak,
    /// An account cannot be renamed: `usermod -l` leaves the home directory,
    /// the mail spool and every group membership naming the old login, and
    /// there is no command that moves them all.
    Renaming,
    RootNotDeletable,
    /// The catalog script did not print the account it ran as, so nothing about
    /// this output can be trusted to be about this machine.
    CurrentUserUnknown,
}

impl UserError {
    /// The stable name the client phrases. Changing one is a break in the
    /// contract, so they read as identifiers rather than as sentences.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::InvalidName => "invalidName",
            Self::LineBreak => "lineBreak",
            Self::InvalidPrimaryGroup => "invalidPrimaryGroup",
            Self::InvalidSupplementaryGroup => "invalidSupplementaryGroup",
            Self::PasswordLineBreak => "passwordLineBreak",
            Self::Renaming => "renaming",
            Self::RootNotDeletable => "rootNotDeletable",
            Self::CurrentUserUnknown => "currentUserUnknown",
        }
    }
}

impl std::fmt::Display for UserError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

// ---------------------------------------------------------------------------
// Reading the machine
// ---------------------------------------------------------------------------

/// Reads the catalogs out of the listing script's output.
///
/// `Err(CurrentUserUnknown)` is an output whose first line is missing, which is
/// a script that did not run rather than a machine with no accounts: everything
/// below it could not be trusted, and an empty list would read as "this machine
/// has no users".
pub fn parse_list(output: &str) -> Result<UserCatalog, UserError> {
    let mut current_user: Option<String> = None;
    let mut uid_min: u32 = 1000;
    let mut passwd: Vec<Vec<&str>> = Vec::new();
    let mut groups_by_gid: HashMap<u32, String> = HashMap::new();
    let mut supplementary: HashMap<String, Vec<String>> = HashMap::new();
    let mut section = "";

    // Bound to a local: every row below borrows from it.
    let normalized = output.replace("\r\n", "\n").replace('\r', "\n");
    for raw_line in normalized.split('\n') {
        let line = raw_line.trim_end();
        if let Some(rest) = line.strip_prefix(CURRENT_MARKER) {
            current_user = Some(rest.trim().to_string());
            continue;
        }
        if let Some(rest) = line.strip_prefix(UID_MIN_MARKER) {
            uid_min = rest.trim().parse().unwrap_or(1000);
            continue;
        }
        if line == PASSWD_MARKER {
            section = PASSWD_MARKER;
            continue;
        }
        if line == GROUP_MARKER {
            section = GROUP_MARKER;
            continue;
        }
        if line.is_empty() {
            continue;
        }

        if section == PASSWD_MARKER {
            let fields: Vec<&str> = line.split(':').collect();
            // The two numeric fields are what a row is worth reading for, and
            // a line without them is a comment, a blank or a file this is not.
            if fields.len() >= 7 && fields[2].parse::<u32>().is_ok() && fields[3].parse::<u32>().is_ok()
            {
                passwd.push(fields);
            }
        } else if section == GROUP_MARKER {
            let fields: Vec<&str> = line.split(':').collect();
            if fields.len() < 4 {
                continue;
            }
            let Ok(gid) = fields[2].parse::<u32>() else {
                continue;
            };
            groups_by_gid.insert(gid, fields[0].to_string());
            for member in fields[3].split(',') {
                let name = member.trim();
                if name.is_empty() {
                    continue;
                }
                supplementary
                    .entry(name.to_string())
                    .or_default()
                    .push(fields[0].to_string());
            }
        }
    }

    let Some(current_user) = current_user.filter(|name| !name.is_empty()) else {
        return Err(UserError::CurrentUserUnknown);
    };

    let mut users: Vec<SystemUser> = passwd
        .into_iter()
        .map(|fields| {
            let gid = fields[3].parse::<u32>().unwrap_or(0);
            let primary_group = groups_by_gid.get(&gid).cloned();
            let mut extra = supplementary.get(fields[0]).cloned().unwrap_or_default();
            // A group an account is in as its primary one is not also a
            // supplementary group, and `/etc/group` lists it either way.
            if let Some(primary) = &primary_group
                && let Some(index) = extra.iter().position(|group| group == primary)
            {
                extra.remove(index);
            }
            extra.sort();
            SystemUser {
                name: fields[0].to_string(),
                uid: fields[2].parse().unwrap_or(0),
                gid,
                comment: fields[4].to_string(),
                home: fields[5].to_string(),
                shell: fields[6].to_string(),
                primary_group,
                supplementary_groups: extra,
            }
        })
        .collect();
    users.sort_by(|a, b| a.uid.cmp(&b.uid).then_with(|| a.name.cmp(&b.name)));

    Ok(UserCatalog {
        current_user,
        uid_min,
        users,
    })
}

/// Reads what `/etc/shadow`, `authorized_keys` and sudoers hold for one
/// account.
///
/// `getent shadow` rather than `passwd -S` or `chage -l`, whose dates are
/// written in the machine's locale. Shadow's third and eighth fields are days
/// since the epoch, which need no rule that differs by language. `passwd -S` is
/// still read, as the fallback for a session that may read its own account but
/// not shadow.
pub fn detail_script(user: &SystemUser) -> Result<String, UserError> {
    if !valid_name(&user.name) {
        return Err(UserError::InvalidName);
    }
    let name = single_quote(&user.name);
    let keys = single_quote(&format!("{}/.ssh/authorized_keys", user.home));
    Ok([
        format!("printf '{DETAIL_SHADOW_MARKER}\\n'"),
        format!("getent shadow {name} 2>/dev/null || true"),
        format!("printf '{DETAIL_STATUS_MARKER}\\n'"),
        format!("passwd -S {name} 2>/dev/null || true"),
        format!("printf '{DETAIL_KEYS_MARKER}\\n'"),
        // `-r` rather than a trailing `|| true`: whether the file could be read
        // is the half that has to survive, so the read reports its own failure
        // and the marker below is what says it succeeded.
        format!("if [ -r {keys} ]; then"),
        format!("printf '{DETAIL_KEYS_READ_MARKER}\\n'"),
        format!("{KEY_TYPE_FILTER} {keys} 2>/dev/null"),
        "fi".to_string(),
        format!("printf '{DETAIL_SUDO_MARKER}\\n'"),
        format!("sudo -nlU {name} 2>/dev/null || true"),
        String::new(),
    ]
    .join("\n"))
}

/// Reads the detail script's output.
pub fn parse_detail(output: &str) -> UserDetail {
    const MARKERS: [&str; 4] = [
        DETAIL_SHADOW_MARKER,
        DETAIL_STATUS_MARKER,
        DETAIL_KEYS_MARKER,
        DETAIL_SUDO_MARKER,
    ];
    let mut sections: HashMap<&str, Vec<&str>> = HashMap::new();
    let mut section = "";
    // Bound to a local: every section below borrows from it.
    let normalized = output.replace("\r\n", "\n").replace('\r', "\n");
    for raw_line in normalized.split('\n') {
        let line = raw_line.trim_end();
        if let Some(marker) = MARKERS.iter().find(|marker| **marker == line) {
            section = marker;
            sections.insert(marker, Vec::new());
            continue;
        }
        if section.is_empty() {
            continue;
        }
        if let Some(lines) = sections.get_mut(section) {
            lines.push(line);
        }
    }

    let shadow = sections
        .get(DETAIL_SHADOW_MARKER)
        .and_then(|lines| lines.iter().find(|line| line.contains(':')));

    let mut detail = UserDetail {
        password_state: None,
        password_changed_millis: None,
        expires_millis: None,
        never_expires: false,
        ssh_key_types: None,
        sudo_rule: None,
    };

    match shadow {
        Some(shadow) => {
            let fields: Vec<&str> = shadow.split(':').collect();
            if fields.len() >= 2 {
                detail.password_state = password_state(fields[1]);
            }
            if fields.len() >= 3 {
                detail.password_changed_millis = days_to_millis(fields[2]);
            }
            if fields.len() >= 8 {
                let raw = fields[7].trim();
                // Empty is the only thing that means never. A field that will
                // not parse — zero, negative, garbage — means the record could
                // not be read, and "Never" is the wrong half of that to guess:
                // it is a claim about an account's expiry made from no
                // evidence.
                detail.never_expires = raw.is_empty();
                if !detail.never_expires {
                    detail.expires_millis = days_to_millis(raw);
                }
            }
        }
        None => {
            // `passwd -S` answers P / L / NP without the hash, and a session is
            // sometimes allowed it for its own account.
            detail.password_state = sections
                .get(DETAIL_STATUS_MARKER)
                .and_then(|lines| lines.iter().find(|line| !line.trim().is_empty()))
                .and_then(|status| {
                    let fields: Vec<&str> = status.split_whitespace().collect();
                    fields.get(1).and_then(|word| match word.to_uppercase().as_str() {
                        "P" => Some(PasswordState::Set),
                        "L" => Some(PasswordState::Locked),
                        "NP" => Some(PasswordState::None),
                        _ => None,
                    })
                });
        }
    }

    if let Some(lines) = sections.get(DETAIL_KEYS_MARKER)
        && lines.first().is_some_and(|line| line.trim() == DETAIL_KEYS_READ_MARKER)
    {
        let mut types: Vec<String> = Vec::new();
        for line in &lines[1..] {
            if let Some(key_type) = ssh_key_type(line)
                && !types.contains(&key_type)
            {
                types.push(key_type);
            }
        }
        detail.ssh_key_types = Some(types);
    }

    detail.sudo_rule = sections
        .get(DETAIL_SUDO_MARKER)
        .into_iter()
        .flatten()
        .find_map(|line| {
            SUDO_RULE
                .captures(line)
                .map(|captures| captures[2].trim().to_string())
        });

    detail
}

/// `!`, `!!` and `*` are the three ways a distribution writes "cannot log in
/// with a password". An empty field is no password at all, which is a very
/// different thing and must not read as locked.
fn password_state(hash: &str) -> Option<PasswordState> {
    let value = hash.trim();
    if value.is_empty() {
        return Some(PasswordState::None);
    }
    if value == "*" || value.starts_with('!') {
        return Some(PasswordState::Locked);
    }
    Some(PasswordState::Set)
}

/// Shadow's day count since the epoch, as an instant. Zero and anything that
/// will not parse are `None`: day zero is 1970, which no account was set in,
/// and it is what a field that could not be read holds.
fn days_to_millis(raw: &str) -> Option<i64> {
    let days: i64 = raw.trim().parse().ok()?;
    (days > 0).then(|| days * 86_400_000)
}

/// The type field of one `authorized_keys` line, skipping the options that may
/// precede it. Comments, blank lines and anything unrecognised answer `None`.
fn ssh_key_type(line: &str) -> Option<String> {
    let value = line.trim();
    if value.is_empty() || value.starts_with('#') {
        return None;
    }
    for token in value.split_whitespace() {
        let token = token.to_lowercase();
        if let Some(rest) = token.strip_prefix("sk-ssh-") {
            return Some(format!("sk-{rest}"));
        }
        if token.starts_with("sk-ecdsa-") {
            return Some("sk-ecdsa".to_string());
        }
        if let Some(rest) = token.strip_prefix("ssh-") {
            return Some(rest.to_string());
        }
        if token.starts_with("ecdsa-") {
            return Some("ecdsa".to_string());
        }
    }
    None
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/// `(ALL : ALL) NOPASSWD: ALL` — the command list, with the `(user : group)`
/// run-as part dropped. It is `ALL` on every entry an administrator writes and
/// says nothing about what the rule allows.
static SUDO_RULE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^\s*\(([^)]*)\)\s*(.+)$").expect("a literal pattern"));

/// A name `useradd` accepts: lowercase, starting with a letter or underscore,
/// optionally ending in `$` for a machine account.
///
/// Stricter than POSIX, and deliberately: this value reaches a command line and
/// a shell script, and a name that is merely unusual buys nothing.
static USER_NAME: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^[a-z_][a-z0-9_.-]*\$?$").expect("a literal pattern"));

pub fn valid_name(name: &str) -> bool {
    USER_NAME.is_match(name)
}

/// What is wrong with a draft, or `None`.
pub fn validate_draft(draft: &UserDraft) -> Option<UserError> {
    if !valid_name(&draft.name) {
        return Some(UserError::InvalidName);
    }
    if [
        &draft.comment,
        &draft.home,
        &draft.shell,
        &draft.primary_group,
    ]
    .iter()
    .any(|value| has_line_break(value))
    {
        return Some(UserError::LineBreak);
    }
    if !draft.primary_group.is_empty() && !valid_name(&draft.primary_group) {
        return Some(UserError::InvalidPrimaryGroup);
    }
    if draft
        .supplementary_groups
        .iter()
        .any(|group| !valid_name(group))
    {
        return Some(UserError::InvalidSupplementaryGroup);
    }
    if draft.password.as_deref().is_some_and(has_line_break) {
        return Some(UserError::PasswordLineBreak);
    }
    None
}

/// The command that creates an account, with the password — when there is one —
/// set as part of the same script.
pub fn create_command(draft: &UserDraft) -> Result<String, UserError> {
    if let Some(error) = validate_draft(draft) {
        return Err(error);
    }
    let mut args: Vec<String> = vec!["useradd".to_string()];
    if draft.system {
        args.push("-r".to_string());
    }
    args.push(if draft.create_home { "-m" } else { "-M" }.to_string());
    if !draft.comment.is_empty() {
        args.push("-c".to_string());
        args.push(single_quote(&draft.comment));
    }
    if !draft.home.is_empty() {
        args.push("-d".to_string());
        args.push(single_quote(&draft.home));
    }
    if !draft.shell.is_empty() {
        args.push("-s".to_string());
        args.push(single_quote(&draft.shell));
    }
    if !draft.primary_group.is_empty() {
        args.push("-g".to_string());
        args.push(single_quote(&draft.primary_group));
    }
    if !draft.supplementary_groups.is_empty() {
        args.push("-G".to_string());
        args.push(single_quote(&draft.supplementary_groups.join(",")));
    }
    args.push(single_quote(&draft.name));

    Ok(with_password(
        &args.join(" "),
        &draft.name,
        draft.password.as_deref(),
    ))
}

/// The command that changes an account, naming only the fields that differ from
/// [`original`].
///
/// The account as it is comes from a catalog this crate read, not from the
/// caller: a client that sent the whole account back would be the thing that
/// decides which fields changed, and one that sent a stale copy would revert
/// whatever was changed in between.
pub fn edit_command(original: &SystemUser, draft: &UserDraft) -> Result<String, UserError> {
    if let Some(error) = validate_draft(draft) {
        return Err(error);
    }
    if draft.name != original.name {
        return Err(UserError::Renaming);
    }

    let mut args: Vec<String> = vec!["usermod".to_string()];
    if draft.comment != original.comment {
        args.push("-c".to_string());
        args.push(single_quote(&draft.comment));
    }
    if !draft.home.is_empty() && draft.home != original.home {
        args.push("-d".to_string());
        args.push(single_quote(&draft.home));
        if draft.move_home {
            args.push("-m".to_string());
        }
    }
    if !draft.shell.is_empty() && draft.shell != original.shell {
        args.push("-s".to_string());
        args.push(single_quote(&draft.shell));
    }
    if !draft.primary_group.is_empty() && Some(&draft.primary_group) != original.primary_group.as_ref()
    {
        args.push("-g".to_string());
        args.push(single_quote(&draft.primary_group));
    }
    if draft.supplementary_groups != original.supplementary_groups {
        args.push("-G".to_string());
        args.push(single_quote(&draft.supplementary_groups.join(",")));
    }
    if args.len() > 1 {
        args.push(single_quote(&original.name));
    }

    // `:` where nothing but the password changed: `set -e` is already in front
    // of the script the password is appended to, and an empty one would not run
    // the `chpasswd` below it.
    let command = if args.len() == 1 {
        ":".to_string()
    } else {
        args.join(" ")
    };
    Ok(with_password(
        &command,
        &original.name,
        draft.password.as_deref(),
    ))
}

/// The command that removes an account.
pub fn delete_command(user: &SystemUser, remove_home: bool) -> Result<String, UserError> {
    if user.is_root() {
        return Err(UserError::RootNotDeletable);
    }
    if !valid_name(&user.name) {
        return Err(UserError::InvalidName);
    }
    let mut args = vec!["userdel".to_string()];
    if remove_home {
        args.push("-r".to_string());
    }
    args.push(single_quote(&user.name));
    Ok(args.join(" "))
}

/// [`command`], with the account's password set after it.
///
/// `chpasswd` reads `name:password` lines, so the value travels inside the
/// script the caller runs — the same pipe the `sudo` password goes down, and
/// never a command line. The heredoc is quoted, so nothing in the value is
/// expanded, and [`validate_draft`] has already refused a line break in it: a
/// second line would be a second `name:password` pair.
fn with_password(command: &str, user: &str, password: Option<&str>) -> String {
    match password {
        None | Some("") => command.to_string(),
        Some(password) => format!(
            "set -e\n{command}\nchpasswd <<'SrvBoxUserPassword'\n{user}:{password}\nSrvBoxUserPassword"
        ),
    }
}

fn has_line_break(value: &str) -> bool {
    value.contains('\n') || value.contains('\r') || value.contains('\0')
}
