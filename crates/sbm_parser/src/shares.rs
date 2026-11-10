//! File shares a NAS serves on Linux: SMB (Samba) and NFS.
//!
//! ServerBox keeps the shares it makes in files of its own and rewrites them
//! whole: [`SMB_FILE`] (included at the end of `smb.conf`, so its sections
//! come after the operator's) and [`NFS_FILE`] (`/etc/exports.d`, which
//! `exportfs` reads besides `/etc/exports`). Shares defined anywhere else are
//! listed and left alone ([`SmbShare::managed`], [`NfsExport::managed`]).
//!
//! Every value written is checked here first ([`render_smb`],
//! [`render_nfs`]): none holds a line break, so none can start a section or
//! an export of its own. A change is checked before it takes effect
//! (`testparm`, `exportfs -ra`) and the previous file put back when it fails.

use serde::{Deserialize, Serialize};

use crate::script::shell_quote_unix as q;

pub const SMB_FILE: &str = "/etc/samba/serverbox.conf";
pub const NFS_FILE: &str = "/etc/exports.d/serverbox.exports";

/// The line that makes `smb.conf` read [`SMB_FILE`].
const SMB_INCLUDE: &str = "include = /etc/samba/serverbox.conf";

/// What is installed and running, every share, which are ServerBox's: one
/// section per `### <name>` line, read by [`parse`]. Readable without root
/// (`smb.conf` and the exports are world-readable).
pub const READ_COMMAND: &str = r####"echo '### tools'; for t in smbd testparm smbpasswd exportfs; do command -v $t >/dev/null 2>&1 && echo $t; done
echo '### active'; for s in smbd smb nfs-server nfs-kernel-server; do [ "$(systemctl is-active $s 2>/dev/null)" = active ] && echo $s; done
echo '### smb'; command -v testparm >/dev/null 2>&1 && testparm -s 2>/dev/null
echo '### smbManaged'; cat /etc/samba/serverbox.conf 2>/dev/null
echo '### nfs'; cat /etc/exports 2>/dev/null; for f in /etc/exports.d/*.exports; do [ "$f" = /etc/exports.d/serverbox.exports ] || cat "$f" 2>/dev/null; done
echo '### nfsManaged'; cat /etc/exports.d/serverbox.exports 2>/dev/null
true"####;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmbShare {
    pub name: String,
    pub path: String,
    #[serde(default)]
    pub comment: Option<String>,
    #[serde(default)]
    pub read_only: bool,
    /// Anyone on the network, without an account.
    #[serde(default)]
    pub guest: bool,
    /// The accounts allowed in; none is every account with an SMB password.
    #[serde(default)]
    pub users: Vec<String>,
    /// A Mac backs up here with Time Machine (Samba's `fruit`).
    #[serde(default)]
    pub time_machine: bool,
    /// Deleted files go to `.recycle` in the share first (`vfs_recycle`).
    #[serde(default)]
    pub recycle: bool,
    /// In [`SMB_FILE`]: ServerBox's to change.
    #[serde(default)]
    pub managed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NfsExport {
    pub path: String,
    pub clients: Vec<NfsClient>,
    #[serde(default)]
    pub managed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NfsClient {
    /// `*`, a host name, an address or a network (`192.168.1.0/24`).
    pub host: String,
    #[serde(default)]
    pub read_only: bool,
    /// `root` (the default: root on the client is nobody here), `all`
    /// (everyone is), `none`.
    #[serde(default = "root_squash")]
    pub squash: String,
    /// The other options as written, for an export ServerBox did not make.
    #[serde(default)]
    pub options: Vec<String>,
}

fn root_squash() -> String {
    "root".into()
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Shares {
    /// `smbd`, `testparm`, `smbpasswd`, `exportfs`.
    pub tools: Vec<String>,
    pub smb_active: bool,
    pub nfs_active: bool,
    pub smb: Vec<SmbShare>,
    pub nfs: Vec<NfsExport>,
}

/// Reads [`READ_COMMAND`]'s output.
pub fn parse(stdout: &str) -> Shares {
    let mut sections: Vec<(&str, String)> = Vec::new();
    for line in stdout.lines() {
        if let Some(name) = line.strip_prefix("### ") {
            sections.push((name.trim(), String::new()));
        } else if let Some((_, text)) = sections.last_mut() {
            text.push_str(line);
            text.push('\n');
        }
    }
    let section = |name: &str| sections.iter().find(|(n, _)| *n == name).map(|(_, t)| t.as_str()).unwrap_or("");
    let active: Vec<&str> = section("active").lines().map(str::trim).collect();
    let managed_smb: Vec<String> = parse_smb(section("smbManaged")).into_iter().map(|s| s.name).collect();
    let mut smb = parse_smb(section("smb"));
    for s in &mut smb {
        s.managed = managed_smb.iter().any(|m| m.eq_ignore_ascii_case(&s.name));
    }
    let mut nfs: Vec<NfsExport> = parse_exports(section("nfs"));
    nfs.extend(parse_exports(section("nfsManaged")).into_iter().map(|e| NfsExport { managed: true, ..e }));
    Shares {
        tools: section("tools").lines().map(str::trim).filter(|l| !l.is_empty()).map(String::from).collect(),
        smb_active: active.iter().any(|s| matches!(*s, "smbd" | "smb")),
        nfs_active: active.iter().any(|s| matches!(*s, "nfs-server" | "nfs-kernel-server")),
        smb,
        nfs,
    }
}

/// The shares in Samba configuration text (`testparm -s`'s, or a file of
/// sections): every section but `global`, `homes`, `printers`, `print$`.
pub fn parse_smb(text: &str) -> Vec<SmbShare> {
    let mut out: Vec<SmbShare> = Vec::new();
    let mut current: Option<SmbShare> = None;
    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        if let Some(name) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
            out.extend(current.take());
            let reserved = ["global", "homes", "printers", "print$"].iter().any(|r| name.eq_ignore_ascii_case(r));
            current = (!reserved).then(|| SmbShare {
                name: name.to_string(),
                path: String::new(),
                comment: None,
                read_only: true,
                guest: false,
                users: Vec::new(),
                time_machine: false,
                recycle: false,
                managed: false,
            });
            continue;
        }
        let (Some(share), Some((key, value))) = (current.as_mut(), line.split_once('=')) else { continue };
        let key = key.trim().to_ascii_lowercase().replace(' ', "");
        let value = value.trim();
        let yes = matches!(value.to_ascii_lowercase().as_str(), "yes" | "true" | "1");
        match key.as_str() {
            "path" => share.path = value.to_string(),
            "comment" => share.comment = Some(value.to_string()).filter(|c| !c.is_empty()),
            "readonly" => share.read_only = yes,
            "writeable" | "writable" => share.read_only = !yes,
            "guestok" | "public" => share.guest = yes,
            "validusers" => share.users = value.split([',', ' ']).filter(|u| !u.is_empty()).map(String::from).collect(),
            "fruit:timemachine" => share.time_machine = yes,
            "vfsobjects" => share.recycle = value.split_whitespace().any(|o| o == "recycle"),
            _ => {}
        }
    }
    out.extend(current);
    out
}

/// The exports in `/etc/exports` text: `path client(options) …`, a
/// backslash continuing a line, `#` starting a comment.
pub fn parse_exports(text: &str) -> Vec<NfsExport> {
    let joined = text.replace("\\\n", " ");
    let mut out = Vec::new();
    for raw in joined.lines() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        let (path, rest) = if let Some(quoted) = line.strip_prefix('"') {
            match quoted.split_once('"') {
                Some((p, rest)) => (p.to_string(), rest),
                None => continue,
            }
        } else {
            match line.split_once(char::is_whitespace) {
                Some((p, rest)) => (p.to_string(), rest),
                None => (line.to_string(), ""),
            }
        };
        let clients = rest
            .split_whitespace()
            .map(|c| {
                let (host, opts) = match c.split_once('(') {
                    Some((h, o)) => (h, o.trim_end_matches(')')),
                    None => (c, ""),
                };
                let mut client = NfsClient { host: if host.is_empty() { "*".into() } else { host.into() }, read_only: true, squash: root_squash(), options: Vec::new() };
                for o in opts.split(',').filter(|o| !o.is_empty()) {
                    match o {
                        "rw" => client.read_only = false,
                        "ro" => client.read_only = true,
                        "root_squash" => client.squash = "root".into(),
                        "all_squash" => client.squash = "all".into(),
                        "no_root_squash" => client.squash = "none".into(),
                        "sync" | "no_subtree_check" => {}
                        other => client.options.push(other.into()),
                    }
                }
                client
            })
            .collect();
        out.push(NfsExport { path, clients, managed: false });
    }
    out
}

/// Who is connected: Samba's sessions and shares in use (`smbstatus`, root)
/// and the NFS clients with a connection open (`ss`), each after a `### <name>`
/// line; read by [`parse_connections`].
pub const CONNECTIONS_COMMAND: &str = r####"echo '### smb'; command -v smbstatus >/dev/null 2>&1 && smbstatus -j 2>/dev/null
echo '### nfs'; ss -Htn state established '( sport = :2049 )' 2>/dev/null
true"####;

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Connections {
    pub smb: Vec<SmbConnection>,
    /// Client addresses with an NFS connection open.
    pub nfs: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmbConnection {
    pub share: String,
    pub user: Option<String>,
    /// The client's address.
    pub machine: String,
    /// As Samba prints it.
    pub since: Option<String>,
}

/// Reads [`CONNECTIONS_COMMAND`]'s output.
pub fn parse_connections(stdout: &str) -> Connections {
    let (smb, nfs) = match stdout.split_once("### nfs") {
        Some((smb, nfs)) => (smb.trim_start_matches("### smb").trim(), nfs),
        None => (stdout.trim_start_matches("### smb").trim(), ""),
    };
    let mut out = Connections::default();
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(smb) {
        let sessions = v["sessions"].as_object();
        for tcon in v["tcons"].as_object().into_iter().flat_map(|t| t.values()) {
            let Some(share) = tcon["service"].as_str() else { continue };
            if share.eq_ignore_ascii_case("IPC$") {
                continue;
            }
            let session = tcon["session_id"].as_str().and_then(|id| sessions?.get(id));
            out.smb.push(SmbConnection {
                share: share.to_string(),
                user: session.and_then(|s| s["username"].as_str()).map(String::from),
                machine: tcon["machine"].as_str().or_else(|| session.and_then(|s| s["remote_machine"].as_str())).unwrap_or("").to_string(),
                since: tcon["connected_at"].as_str().map(String::from),
            });
        }
    }
    for line in nfs.lines() {
        // `0 0 10.0.0.5:2049 10.0.0.9:876`: the peer is the last field.
        let Some(peer) = line.split_whitespace().last() else { continue };
        let host = peer.rsplit_once(':').map_or(peer, |(h, _)| h).trim_matches(['[', ']']);
        if !host.is_empty() && !out.nfs.iter().any(|h| h == host) {
            out.nfs.push(host.to_string());
        }
    }
    out
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShareError {
    InvalidName,
    InvalidPath,
    InvalidComment,
    InvalidUser,
    InvalidClient,
    InvalidSquash,
    Duplicate,
    InvalidPassword,
}

impl ShareError {
    pub fn code(self) -> &'static str {
        match self {
            Self::InvalidName => "invalidName",
            Self::InvalidPath => "invalidPath",
            Self::InvalidComment => "invalidComment",
            Self::InvalidUser => "invalidUser",
            Self::InvalidClient => "invalidClient",
            Self::InvalidSquash => "invalidSquash",
            Self::Duplicate => "duplicate",
            Self::InvalidPassword => "invalidPassword",
        }
    }
}

fn plain(value: &str) -> bool {
    !value.chars().any(char::is_control)
}

/// An absolute folder, not the root, without `..`, a line break, a quote or
/// a backslash (an exports line quotes it; Samba reads it to the line's end).
fn path_ok(path: &str) -> Result<(), ShareError> {
    let ok = path.starts_with('/')
        && path.len() > 1
        && path.len() <= 4096
        && plain(path)
        && !path.contains(['"', '\\'])
        && !path.split('/').any(|p| p == "..");
    if ok { Ok(()) } else { Err(ShareError::InvalidPath) }
}

fn user_ok(user: &str) -> bool {
    crate::users::valid_name(user) && !user.ends_with('$')
}

/// Every share in [`SMB_FILE`]'s text, checked; [shares] are ServerBox's.
pub fn render_smb(shares: &[SmbShare]) -> Result<String, ShareError> {
    let mut seen: Vec<String> = Vec::new();
    let mut out = String::from("# Shares made in ServerBox. Rewritten by it: changes here are lost.\n");
    for s in shares {
        let name_ok = (1..=32).contains(&s.name.len())
            && s.name.bytes().all(|b| b.is_ascii_alphanumeric() || b"_.-".contains(&b))
            && !["global", "homes", "printers", "ipc$"].iter().any(|r| s.name.eq_ignore_ascii_case(r));
        if !name_ok {
            return Err(ShareError::InvalidName);
        }
        if seen.iter().any(|n| n.eq_ignore_ascii_case(&s.name)) {
            return Err(ShareError::Duplicate);
        }
        seen.push(s.name.clone());
        path_ok(&s.path)?;
        if s.comment.as_ref().is_some_and(|c| c.len() > 128 || !plain(c)) {
            return Err(ShareError::InvalidComment);
        }
        if !s.users.iter().all(|u| user_ok(u)) {
            return Err(ShareError::InvalidUser);
        }
        out.push_str(&format!("\n[{}]\n   path = {}\n", s.name, s.path));
        if let Some(c) = s.comment.as_deref().filter(|c| !c.trim().is_empty()) {
            out.push_str(&format!("   comment = {}\n", c.trim()));
        }
        out.push_str(&format!("   read only = {}\n", if s.read_only { "yes" } else { "no" }));
        out.push_str(&format!("   guest ok = {}\n", if s.guest { "yes" } else { "no" }));
        if !s.users.is_empty() {
            out.push_str(&format!("   valid users = {}\n", s.users.join(" ")));
        }
        let mut vfs = Vec::new();
        if s.time_machine {
            vfs.extend(["catia", "fruit", "streams_xattr"]);
        }
        if s.recycle {
            vfs.push("recycle");
        }
        if !vfs.is_empty() {
            out.push_str(&format!("   vfs objects = {}\n", vfs.join(" ")));
        }
        if s.time_machine {
            out.push_str("   fruit:time machine = yes\n   fruit:metadata = stream\n");
        }
        if s.recycle {
            out.push_str("   recycle:repository = .recycle\n   recycle:keeptree = yes\n   recycle:versions = yes\n");
        }
        out.push_str("   browseable = yes\n");
    }
    Ok(out)
}

/// Every export in [`NFS_FILE`]'s text, checked.
pub fn render_nfs(exports: &[NfsExport]) -> Result<String, ShareError> {
    let mut out = String::from("# Exports made in ServerBox. Rewritten by it: changes here are lost.\n");
    let mut seen: Vec<&str> = Vec::new();
    for e in exports {
        path_ok(&e.path)?;
        if seen.contains(&e.path.as_str()) {
            return Err(ShareError::Duplicate);
        }
        seen.push(&e.path);
        if e.clients.is_empty() {
            return Err(ShareError::InvalidClient);
        }
        let mut line = format!("\"{}\"", e.path);
        for c in &e.clients {
            let host_ok = (1..=253).contains(&c.host.len()) && c.host.bytes().all(|b| b.is_ascii_alphanumeric() || b".-*:/_[]".contains(&b));
            if !host_ok {
                return Err(ShareError::InvalidClient);
            }
            let squash = match c.squash.as_str() {
                "root" => "root_squash",
                "all" => "all_squash",
                "none" => "no_root_squash",
                _ => return Err(ShareError::InvalidSquash),
            };
            line.push_str(&format!(" {}({},sync,no_subtree_check,{squash})", c.host, if c.read_only { "ro" } else { "rw" }));
        }
        out.push_str(&line);
        out.push('\n');
    }
    Ok(out)
}

/// Exit codes of the scripts below, beside 0: a path is not a folder; the
/// new configuration was refused and the previous one put back.
pub const EXIT_NOT_A_FOLDER: i32 = 3;
pub const EXIT_REFUSED: i32 = 4;

/// Stops a script ([`EXIT_NOT_A_FOLDER`]) unless every one of [paths] is a
/// folder; the first that is not is said on stderr.
fn folders(paths: &[&str]) -> String {
    if paths.is_empty() {
        return String::new();
    }
    let list: Vec<String> = paths.iter().map(|p| q(p)).collect();
    format!("for p in {}; do [ -d \"$p\" ] || {{ echo \"$p\" >&2; exit {EXIT_NOT_A_FOLDER}; }}; done\n", list.join(" "))
}

fn replace_script(file: &str, content: &str, check: &str) -> String {
    crate::script::replace_file_script(file, content, check, "SrvBoxShares", EXIT_REFUSED)
}

/// Root's script that makes [shares] ServerBox's SMB shares: the file
/// written and checked (`testparm`), `smb.conf` told to include it once,
/// Samba reloaded (started when it was not running).
pub fn smb_script(shares: &[SmbShare]) -> Result<String, ShareError> {
    let content = render_smb(shares)?;
    let check = "testparm -s >/dev/null 2>&1";
    let paths: Vec<&str> = shares.iter().map(|s| s.path.as_str()).collect();
    Ok(format!(
        "{}{}\nconf=/etc/samba/smb.conf; grep -qxF '{SMB_INCLUDE}' \"$conf\" || printf '\\n# ServerBox shares (%s)\\n{SMB_INCLUDE}\\n' {SMB_FILE} >> \"$conf\"; \
         {check} || {{ echo 'smb.conf does not check' >&2; exit 1; }}; \
         for s in smbd smb; do systemctl list-unit-files \"$s.service\" >/dev/null 2>&1 || continue; \
         if systemctl is-active -q \"$s\"; then systemctl reload \"$s\" || systemctl restart \"$s\"; else systemctl enable --now \"$s\"; fi; break; done",
        folders(&paths),
        replace_script(SMB_FILE, &content, check)
    ))
}

/// Root's script that makes [exports] ServerBox's NFS exports: the file
/// written, `exportfs -ra` (the previous file back if it refuses), the
/// server started when it was not running.
pub fn nfs_script(exports: &[NfsExport]) -> Result<String, ShareError> {
    let content = render_nfs(exports)?;
    let paths: Vec<&str> = exports.iter().map(|e| e.path.as_str()).collect();
    Ok(format!(
        "{}for s in nfs-server nfs-kernel-server; do systemctl list-unit-files \"$s.service\" >/dev/null 2>&1 || continue; \
         systemctl is-active -q \"$s\" || systemctl enable --now \"$s\"; break; done\n{}",
        folders(&paths),
        replace_script(NFS_FILE, &content, "exportfs -ra")
    ))
}

/// Root's script that sets [user]'s SMB password (Samba keeps its own),
/// adding them to Samba's accounts if new. Run with `as_root_private`: the
/// password is in its text.
pub fn smb_password_script(user: &str, password: &str) -> Result<String, ShareError> {
    if !user_ok(user) {
        return Err(ShareError::InvalidUser);
    }
    if password.is_empty() || password.len() > 256 || !plain(password) || password == "SrvBoxSmbPassword" {
        return Err(ShareError::InvalidPassword);
    }
    Ok(format!(
        "set -e; id -u {u} >/dev/null; smbpasswd -s -a {u} <<'SrvBoxSmbPassword'\n{password}\n{password}\nSrvBoxSmbPassword",
        u = q(user)
    ))
}

/// Root's script that installs Samba or the NFS server with the machine's
/// package manager.
pub fn install_script(nfs: bool) -> String {
    let (apt, dnf, apk) = if nfs { ("nfs-kernel-server", "nfs-utils", "nfs-utils") } else { ("samba", "samba", "samba") };
    format!(
        "if command -v apt-get >/dev/null; then DEBIAN_FRONTEND=noninteractive apt-get install -y {apt}; \
         elif command -v dnf >/dev/null; then dnf install -y {dnf}; \
         elif command -v apk >/dev/null; then apk add {apk}; \
         else echo 'no package manager this knows (apt, dnf, apk)' >&2; exit 1; fi"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    const READ: &str = "### tools\nsmbd\ntestparm\nexportfs\n### active\nsmbd\n### smb\n\
# Global parameters\n[global]\n\tserver role = standalone server\n\n[homes]\n\tread only = No\n\n\
[media]\n\tcomment = Films\n\tpath = /srv/media\n\tguest ok = Yes\n\n[backup]\n\tpath = /mnt/backup\n\tread only = No\n\tvalid users = alice bob\n\
### smbManaged\n[backup]\n   path = /mnt/backup\n\
### nfs\n# /etc/exports\n/srv/media 192.168.1.0/24(ro,sync,no_subtree_check) \\\n    10.0.0.5(rw,no_root_squash,insecure)\n\
### nfsManaged\n\"/mnt/backup\" *(rw,sync,no_subtree_check,all_squash)\n";

    #[test]
    fn shares_read_with_whose_they_are() {
        let s = parse(READ);
        assert_eq!(s.tools, ["smbd", "testparm", "exportfs"]);
        assert!(s.smb_active && !s.nfs_active);
        assert_eq!(s.smb.iter().map(|x| (x.name.as_str(), x.managed)).collect::<Vec<_>>(), [("media", false), ("backup", true)]);
        assert_eq!((s.smb[0].guest, s.smb[0].read_only, s.smb[0].comment.as_deref()), (true, true, Some("Films")));
        assert_eq!((s.smb[1].read_only, s.smb[1].users.clone()), (false, vec!["alice".to_string(), "bob".to_string()]));

        assert_eq!(s.nfs.len(), 2);
        let media = &s.nfs[0];
        assert_eq!((media.path.as_str(), media.managed, media.clients.len()), ("/srv/media", false, 2));
        assert_eq!((media.clients[1].read_only, media.clients[1].squash.as_str(), media.clients[1].options.clone()), (false, "none", vec!["insecure".to_string()]));
        assert_eq!((s.nfs[1].path.as_str(), s.nfs[1].managed, s.nfs[1].clients[0].squash.as_str()), ("/mnt/backup", true, "all"));
        assert_eq!(parse(""), Shares::default());
    }

    fn share(name: &str, path: &str) -> SmbShare {
        SmbShare { name: name.into(), path: path.into(), comment: None, read_only: false, guest: false, users: vec![], time_machine: false, recycle: false, managed: true }
    }

    #[test]
    fn time_machine_and_recycle_are_written_and_read_back() {
        let text = render_smb(&[SmbShare { time_machine: true, recycle: true, ..share("mac", "/srv/mac") }]).unwrap();
        assert!(text.contains("   vfs objects = catia fruit streams_xattr recycle\n   fruit:time machine = yes\n"), "{text}");
        assert!(text.contains("recycle:repository = .recycle"), "{text}");
        let back = &parse_smb(&text)[0];
        assert!(back.time_machine && back.recycle);
        let plain = &parse_smb(&render_smb(&[share("x", "/srv/x")]).unwrap())[0];
        assert!(!plain.time_machine && !plain.recycle);
    }

    #[test]
    fn connections_are_read() {
        let out = "### smb\n{\"sessions\": {\"3\": {\"session_id\": \"3\", \"username\": \"alice\", \"remote_machine\": \"10.0.0.9\"}},\n \"tcons\": {\"1\": {\"service\": \"media\", \"session_id\": \"3\", \"machine\": \"10.0.0.9\", \"connected_at\": \"2026-10-11T10:00:00+0000\"}, \"2\": {\"service\": \"IPC$\", \"session_id\": \"3\", \"machine\": \"10.0.0.9\"}}}\n### nfs\n0 0 10.0.0.5:2049 10.0.0.7:876\n0 0 10.0.0.5:2049 10.0.0.7:877\n0 0 [fd00::5]:2049 [fd00::8]:900\n";
        let c = parse_connections(out);
        assert_eq!(c.smb, [SmbConnection { share: "media".into(), user: Some("alice".into()), machine: "10.0.0.9".into(), since: Some("2026-10-11T10:00:00+0000".into()) }]);
        assert_eq!(c.nfs, ["10.0.0.7", "fd00::8"]);
        assert_eq!(parse_connections("### smb\n### nfs\n"), Connections::default());
    }

    #[test]
    fn what_is_written_is_checked() {
        let text = render_smb(&[SmbShare { comment: Some("Family photos".into()), users: vec!["alice".into()], ..share("photos", "/mnt/data/photos") }]).unwrap();
        assert!(text.contains("[photos]\n   path = /mnt/data/photos\n   comment = Family photos\n   read only = no\n   guest ok = no\n   valid users = alice\n"), "{text}");
        assert_eq!(parse_smb(&text)[0].users, ["alice"]);

        assert_eq!(render_smb(&[share("global", "/srv")]), Err(ShareError::InvalidName));
        assert_eq!(render_smb(&[share("a]b", "/srv")]), Err(ShareError::InvalidName));
        assert_eq!(render_smb(&[share("x", "/srv\n[evil]")]), Err(ShareError::InvalidPath));
        assert_eq!(render_smb(&[share("x", "/srv/../etc")]), Err(ShareError::InvalidPath));
        assert_eq!(render_smb(&[share("x", "/")]), Err(ShareError::InvalidPath));
        assert_eq!(render_smb(&[SmbShare { comment: Some("a\nb".into()), ..share("x", "/srv") }]), Err(ShareError::InvalidComment));
        assert_eq!(render_smb(&[SmbShare { users: vec!["root; id".into()], ..share("x", "/srv") }]), Err(ShareError::InvalidUser));
        assert_eq!(render_smb(&[share("x", "/a"), share("X", "/b")]), Err(ShareError::Duplicate));

        let client = |host: &str, squash: &str| NfsClient { host: host.into(), read_only: false, squash: squash.into(), options: vec![] };
        let nfs = render_nfs(&[NfsExport { path: "/mnt/my data".into(), clients: vec![client("192.168.1.0/24", "root"), client("*", "all")], managed: true }]).unwrap();
        assert!(nfs.ends_with("\"/mnt/my data\" 192.168.1.0/24(rw,sync,no_subtree_check,root_squash) *(rw,sync,no_subtree_check,all_squash)\n"), "{nfs}");
        assert_eq!(parse_exports(&nfs)[0].path, "/mnt/my data");
        assert_eq!(render_nfs(&[NfsExport { path: "/srv".into(), clients: vec![client("a(rw)", "root")], managed: true }]), Err(ShareError::InvalidClient));
        assert_eq!(render_nfs(&[NfsExport { path: "/srv".into(), clients: vec![client("*", "some")], managed: true }]), Err(ShareError::InvalidSquash));
        assert_eq!(render_nfs(&[NfsExport { path: "/srv".into(), clients: vec![], managed: true }]), Err(ShareError::InvalidClient));
    }

    #[test]
    fn scripts_check_before_they_keep_a_change() {
        let smb = smb_script(&[share("photos", "/mnt/photos")]).unwrap();
        assert!(smb.contains("cat > \"$f.new\" <<'SrvBoxShares'\n# Shares made in ServerBox"), "{smb}");
        assert!(smb.starts_with("for p in '/mnt/photos'; do [ -d \"$p\" ] || { echo \"$p\" >&2; exit 3; }; done\n"), "{smb}");
        assert!(smb.contains("testparm -s") && smb.contains("include = /etc/samba/serverbox.conf") && smb.contains("systemctl reload"), "{smb}");
        let nfs = nfs_script(&[]).unwrap();
        assert!(nfs.contains("exportfs -ra") && nfs.contains("/etc/exports.d/serverbox.exports"), "{nfs}");

        let pw = smb_password_script("alice", "s3cret word").unwrap();
        assert!(pw.contains("smbpasswd -s -a 'alice' <<'SrvBoxSmbPassword'\ns3cret word\ns3cret word\nSrvBoxSmbPassword"), "{pw}");
        assert_eq!(smb_password_script("alice", "a\nb"), Err(ShareError::InvalidPassword));
        assert_eq!(smb_password_script("alice", "SrvBoxSmbPassword"), Err(ShareError::InvalidPassword));
        assert_eq!(smb_password_script("-o", "x"), Err(ShareError::InvalidUser));
        assert!(install_script(true).contains("nfs-kernel-server"));
    }
}
