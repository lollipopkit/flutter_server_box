//! A filesystem through nothing but a POSIX shell: the commands the app's file
//! browser runs where SFTP cannot, and the reader for what they print.
//!
//! Two backends need it. SFTP escalates a refused operation through `sudo`,
//! where the protocol is no longer in play and only a command will do. SCP has
//! no protocol for metadata at all — it moves file *contents* — so this is its
//! normal path.
//!
//! A listing is five NUL-terminated fields per entry: `name`, `perm`, `type`,
//! `size`, `mtime`. NUL rather than a separator anybody types, because a
//! filename may contain everything else, newlines included. `find` and
//! `stat -c` rather than `ls -l`, whose output is meant for people, varies by
//! implementation and carries a locale-dependent date; both are in busybox and
//! toybox as well as coreutils, which matters — the machines that reach this
//! are the ones too small to run an SFTP subsystem.
//!
//! Every command with shell syntax of its own is handed to `sh` ([`posix`]):
//! SCP runs it in the account's login shell, and fish refuses `path=...` and
//! `if ...; then ...; fi` outright.

use crate::bench::posix;
use crate::script::shell_quote_unix as quote;

/// `path` as an operand no command reads as an option: a relative path that
/// begins with `-` is spelled `./-…`. For the commands here that take no `--`
/// (`find`, `mktemp`, `scp`) or are not given one.
fn operand(path: &str) -> String {
    if path.starts_with('-') { format!("./{path}") } else { path.to_owned() }
}

/// One directory level. `-exec … {} +` hands the whole batch to one shell
/// rather than starting one per file.
pub fn list_command(path: &str) -> String {
    format!(
        "find {} -mindepth 1 -maxdepth 1 -exec sh -c 'for path do {}done' sh {{}} +",
        quote(&operand(path)),
        // A file gone by the time its metadata is read is not reported: `find`
        // names what was there a moment ago, and /proc and /tmp churn.
        emit_record("path", "continue")
    )
}

/// What [`stat_command`] prints when there is nothing at the path. Compared
/// against the whole of stdout, so not a word a filename could be.
pub const STAT_ABSENT_MARK: &str = "__sb_absent__";
/// What [`stat_command`] prints when a directory on the way is not searchable,
/// so whether anything is there cannot be answered.
pub const STAT_DENIED_MARK: &str = "__sb_denied__";
pub const STAT_ABSENT_EXIT: i32 = 44;
pub const STAT_DENIED_EXIT: i32 = 13;

/// One path, or a marker saying why not.
///
/// "Nothing there" invites creating something and "you may not look" does
/// not, and `stat` fails alike for both, so the parent is tested separately:
/// only a parent this user can search makes an absence an absence. Each is
/// said on stdout and as an exit code, since a host that closes the channel
/// without an exit status leaves the code unsaid.
pub fn stat_command(path: &str) -> String {
    let quoted = quote(&operand(without_trailing_slash(path)));
    let vanished = format!("printf \"%s\" {STAT_ABSENT_MARK}; exit {STAT_ABSENT_EXIT}");
    posix(&format!(
        "path={quoted}; \
         dir=${{path%/*}}; [ -z \"$dir\" ] && dir=/; \
         if [ -e \"$path\" ] || [ -L \"$path\" ]; then {}\
         elif [ ! -d \"$dir\" ] || [ -x \"$dir\" ]; then \
         printf \"%s\" {STAT_ABSENT_MARK}; exit {STAT_ABSENT_EXIT}; \
         else printf \"%s\" {STAT_DENIED_MARK}; exit {STAT_DENIED_EXIT}; fi",
        emit_record("path", &vanished)
    ))
}

/// `${path##*/}` expands to nothing for `/dir/`, so a trailing separator
/// would leave the entry without a name. The root keeps its one slash, and is
/// named `/` by [`emit_record`].
fn without_trailing_slash(path: &str) -> &str {
    let mut end = path.len();
    while end > 1 && path.as_bytes()[end - 1] == b'/' {
        end -= 1;
    }
    &path[..end]
}

/// The five fields for the path in shell variable `variable`, shared so a
/// listing and a stat cannot drift apart.
///
/// Anything still there whose metadata could not be read fails the whole
/// command: a directory readable but not searchable lists every name and stats
/// none, and a failure is what offers the user sudo. `on_vanished` runs when
/// the path is gone, which neither caller counts as an error.
fn emit_record(variable: &str, on_vanished: &str) -> String {
    let r = format!("\"${variable}\"");
    format!(
        "name=${{{variable}##*/}}; [ -n \"$name\" ] || name=/; \
         if meta=$(stat -c \"%a %s %Y\" {r}); then \
         perm=${{meta%% *}}; rest=${{meta#* }}; \
         size=${{rest%% *}}; mtime=${{rest##* }}; \
         type=u; \
         [ -d {r} ] && type=d; \
         [ -f {r} ] && type=f; \
         [ -L {r} ] && type=l; \
         printf \"%s\\0%s\\0%s\\0%s\\0%s\\0\" \"$name\" \"$perm\" \"$type\" \"$size\" \"$mtime\"; \
         elif [ -e {r} ] || [ -L {r} ]; then exit 1; \
         else {on_vanished}; fi; "
    )
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileKind {
    Dir,
    Link,
    File,
    /// A socket, a fifo, a device.
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileRecord {
    pub name: String,
    pub kind: FileKind,
    /// Files only: a directory's size is not the size of what is in it.
    pub size: Option<i64>,
    /// Seconds since the epoch.
    pub mtime: Option<i64>,
    pub mode: Option<u32>,
}

/// Every entry [`list_command`] or [`stat_command`] printed.
///
/// Fails closed. A record cut short means the listing was, and a short listing
/// that reads as complete is what a caller reports as empty or deletes into; a
/// field that is not what the command prints means the output is not its. The
/// commands never print an empty name (the root is `/`), so one is refused.
pub fn parse_records(output: &str) -> Result<Vec<FileRecord>, String> {
    let mut parts: Vec<&str> = output.split('\0').collect();
    // The command's own trailing NUL leaves one empty string. Split rather than
    // filtered: an empty field is still a field.
    if parts.last() == Some(&"") {
        parts.pop();
    }
    if !parts.len().is_multiple_of(5) {
        return Err("the listing ended mid-record".to_owned());
    }
    parts
        .chunks(5)
        .map(|f| {
            if f[0].is_empty() {
                return Err("an entry with no name".to_owned());
            }
            let kind = match f[2] {
                "d" => FileKind::Dir,
                "l" => FileKind::Link,
                "f" => FileKind::File,
                "u" => FileKind::Other,
                other => return Err(format!("unknown entry type \"{other}\"")),
            };
            let size = number(f[3], 10, false, "size")?;
            // `stat -c %a` prints the permission bits and nothing wider: a
            // value past them is not its output, and would not survive a cast.
            let mode = number(f[1], 8, false, "mode")?;
            if mode.is_some_and(|m| !(0..=0o7777).contains(&m)) {
                return Err(format!("unreadable mode \"{}\"", f[1]));
            }
            Ok(FileRecord {
                name: f[0].to_owned(),
                kind,
                size: if kind == FileKind::File { size } else { None },
                // Before 1970 is a time `stat` can print; nothing else here is.
                mtime: number(f[4], 10, true, "mtime")?,
                mode: mode.map(|m| m as u32),
            })
        })
        .collect()
}

/// Empty is a field the far side left blank; anything else that is not the
/// digits `stat` prints — a sign, a space, a letter — is not this command's
/// output. A `-` only where `negative` allows one.
fn number(field: &str, radix: u32, negative: bool, what: &str) -> Result<Option<i64>, String> {
    if field.is_empty() {
        return Ok(None);
    }
    let digits = if negative { field.strip_prefix('-').unwrap_or(field) } else { field };
    let unreadable = || format!("unreadable {what} \"{field}\"");
    if digits.is_empty() || !digits.chars().all(|c| c.is_digit(radix)) {
        return Err(unreadable());
    }
    i64::from_str_radix(field, radix).map(Some).map_err(|_| unreadable())
}

/// `mv`, refusing a destination that is a directory: `mv a b` moves `a` into
/// `b` when it is one, where SFTP's own rename refuses. The path reaches
/// `printf` as its argument, never inside a double-quoted string.
pub fn rename_command(from: &str, to: &str) -> String {
    let target = quote(to);
    posix(&format!(
        "if [ -d {target} ]; then printf \"%s: is a directory\\n\" {target} >&2; exit 1; fi; mv -- {} {target}",
        quote(from)
    ))
}

/// `mkdir`, with `-p` where a second attempt after a partial failure is worth
/// more than refusing a directory that is already there.
pub fn mkdir_command(path: &str, parents: bool) -> String {
    let flag = if parents { " -p" } else { "" };
    format!("mkdir{flag} -- {}", quote(path))
}

/// Removes `path`. `is_dir` is what a stat said, or `None` where it could not
/// be asked, in which case the shell decides — keeping the caller's choice of
/// recursion, since a stat this account was refused is not consent for `rm -r`.
/// A link to a directory is unlinked, never handed to `rmdir`.
///
/// `force` is `rm -f` wherever the path may be a file. A directory a stat has
/// already confirmed is removed without it, so a failure inside the tree is
/// reported rather than silenced.
pub fn remove_command(path: &str, is_dir: Option<bool>, recursive: bool, force: bool) -> String {
    let q = quote(path);
    let rm = if force { "rm -f" } else { "rm" };
    match (is_dir, recursive) {
        (Some(true), true) => format!("rm -r -- {q}"),
        (Some(true), false) => format!("rmdir -- {q}"),
        (Some(false), _) => format!("{rm} -- {q}"),
        (None, true) => format!("{} -- {q}", if force { "rm -rf" } else { "rm -r" }),
        (None, false) => posix(&format!("if [ -d {q} ] && [ ! -L {q} ]; then rmdir -- {q}; else {rm} -- {q}; fi")),
    }
}

pub fn chmod_command(path: &str, mode: u32) -> String {
    format!("chmod {mode:o} -- {}", quote(path))
}

/// The file's size in bytes, read by [`parse_size`].
pub fn size_command(path: &str) -> String {
    format!("wc -c < {}", quote(path))
}

pub fn parse_size(output: &str) -> Option<i64> {
    output.trim().parse().ok()
}

pub fn read_command(path: &str) -> String {
    format!("cat {}", quote(&operand(path)))
}

/// Writes base64 `data` to `path` through `tee`, so it works under `sudo`
/// where a redirection would be the unprivileged shell's.
pub fn write_base64_command(data: &str, path: &str) -> String {
    format!("printf '%s' {} | base64 -d | tee {} > /dev/null", quote(data), quote(path))
}

/// `inner` run as root, the password on `sudo -S`'s stdin through `printf`, a
/// shell builtin, so it never becomes a process argument.
pub fn sudo_command(inner: &str, password: &str) -> String {
    format!(
        "printf '%s\\n' {} | sudo -S -- sh -c {}",
        quote(password),
        quote(&format!("({inner}) 2>&1"))
    )
}

/// The account's `passwd` line, read by [`parse_home`].
pub fn home_command(user: &str) -> String {
    format!("getent passwd -- {}", quote(user))
}

/// The home directory field, when it is an absolute path.
pub fn parse_home(output: &str) -> Option<String> {
    let home = output.trim().split(':').nth(5)?.trim();
    home.starts_with('/').then(|| home.to_owned())
}

/// Where a user's home usually is, for a server that would not say.
pub fn fallback_home(user: &str) -> String {
    if user == "root" {
        "/root".to_owned()
    } else {
        format!("/home/{user}")
    }
}

/// Exits 0 when this user may write into `dir`.
pub fn writable_command(dir: &str) -> String {
    format!("test -w {}", quote(dir))
}

/// `command` in `dir`, for a terminal opened there.
pub fn in_dir_command(dir: &str, command: &str) -> String {
    format!("cd {} && {command}", quote(dir))
}

/// The user's configured editor on `path`. The editor is a command line the
/// user wrote, so it goes in as written.
pub fn editor_command(editor: &str, path: &str, sudo: bool) -> String {
    let sudo = if sudo { "sudo " } else { "" };
    format!("{sudo}{editor} {}", quote(&operand(path)))
}

/// From oh-my-zsh's `extract` plugin. Order matters: the first suffix that
/// matches wins, so `tar.gz` is listed before `gz`.
const EXTRACT: &[(&str, &str)] = &[
    ("tar.gz", "tar zxvf FILE"),
    ("tgz", "tar zxvf FILE"),
    ("tar.bz2", "tar jxvf FILE"),
    ("tbz2", "tar jxvf FILE"),
    ("tar.xz", "tar --xz -xvf FILE"),
    ("txz", "tar --xz -xvf FILE"),
    ("tar.lzma", "tar --lzma -xvf FILE"),
    ("tlz", "tar --lzma -xvf FILE"),
    ("tar.zst", "tar --zstd -xvf FILE"),
    ("tzst", "tar --zstd -xvf FILE"),
    ("tar", "tar xvf FILE"),
    ("tar.lz", "tar xvf FILE"),
    ("tar.lz4", "lz4 -c -d FILE | tar xvf - "),
    ("gz", "gunzip FILE"),
    ("bz2", "bunzip2 FILE"),
    ("xz", "unxz FILE"),
    ("lzma", "unlzma FILE"),
    ("z", "uncompress FILE"),
    ("zip", "unzip FILE"),
    ("war", "unzip FILE"),
    ("jar", "unzip FILE"),
    ("ear", "unzip FILE"),
    ("sublime-package", "unzip FILE"),
    ("ipa", "unzip FILE"),
    ("ipsw", "unzip FILE"),
    ("apk", "unzip FILE"),
    ("xpi", "unzip FILE"),
    ("aar", "unzip FILE"),
    ("whl", "unzip FILE"),
    ("rar", "unrar x -ad FILE"),
    ("rpm", "rpm2cpio FILE | cpio --quiet -id"),
    ("7z", "7za x FILE"),
    ("zst", "unzstd FILE"),
    ("cab", "cabextract FILE"),
    ("exe", "cabextract FILE"),
    ("cpio", "cpio -idmvF FILE"),
    ("obscpio", "cpio -idmvF FILE"),
    ("zpaq", "zpaq x FILE"),
];

/// The command that unpacks `path` where it is, or `None` for a file this does
/// not know how to unpack.
pub fn extract_command(path: &str) -> Option<String> {
    EXTRACT
        .iter()
        .find(|(ext, _)| path.ends_with(&format!(".{ext}")))
        .map(|(_, command)| command.replace("FILE", &quote(&operand(path))))
}

/// The far side of an SCP download: `scp -f` sends `path` over the channel.
pub fn scp_source_command(path: &str) -> String {
    format!("scp -f {}", quote(&operand(path)))
}

/// The far side of an SCP upload: `scp -t` receives into `path`.
pub fn scp_sink_command(path: &str) -> String {
    format!("scp -t {}", quote(&operand(path)))
}

/// [`capped_read_command`]'s exit code for a path that is a directory.
pub const READ_IS_DIR_EXIT: i32 = 45;
/// [`capped_read_command`]'s exit code for nothing at the path.
pub const READ_MISSING_EXIT: i32 = 44;

/// The size of `path` on one line, then its first `max_bytes` bytes as
/// base64, read by [`parse_capped_read`]. A directory and a missing path have
/// exit codes of their own: a directory is not "no such file", and telling a
/// caller so would invite it to create a path that already exists.
pub fn capped_read_command(path: &str, max_bytes: u64) -> String {
    format!(
        "set -e\np={}\nif [ -d \"$p\" ]; then exit {READ_IS_DIR_EXIT}; fi\nif [ ! -f \"$p\" ]; then exit {READ_MISSING_EXIT}; fi\nsize=$(wc -c < \"$p\") || exit\nprintf '%s\\n' \"$size\"\nhead -c {max_bytes} \"$p\" | base64 | tr -d \"\\n\"",
        quote(&operand(path))
    )
}

/// The file's whole size and the bytes [`capped_read_command`] sent with the
/// same `max_bytes`. Fewer bytes than the size and the cap allow is a reply cut
/// short, even where what arrived still decodes, and is refused.
pub fn parse_capped_read(output: &str, max_bytes: u64) -> Result<(u64, Vec<u8>), String> {
    use base64::Engine;
    let (size, encoded) = output
        .split_once('\n')
        .filter(|(size, _)| !size.is_empty())
        .ok_or("malformed file data")?;
    let size: u64 = size.trim().parse().map_err(|_| "an invalid file size")?;
    let encoded: String = encoded.chars().filter(|c| !c.is_whitespace()).collect();
    let data = base64::engine::general_purpose::STANDARD
        .decode(encoded)
        .map_err(|_| "malformed file data")?;
    if data.len() as u64 != size.min(max_bytes) {
        return Err("truncated file data".to_owned());
    }
    Ok((size, data))
}

/// Replaces `path` with the base64 on stdin, atomically: written beside it and
/// moved onto it, so a write that fails halfway leaves the original. A
/// directory is refused rather than having the copy filed inside it.
///
/// The staged copy is `mktemp`'s: created exclusively under a name nobody can
/// predict, so nothing planted beside the target — a symlink to another file —
/// is opened in its place. It starts `0600`, so it then takes the existing
/// file's mode, or for a new file the one the umask gives (best effort: the
/// bytes are written either way).
pub fn atomic_write_command(path: &str) -> String {
    format!(
        "set -e\np={}\nif [ -d \"$p\" ]; then printf '%s: is a directory\\n' \"$p\" >&2; exit 1; fi\ntmp=$(mktemp \"$p.XXXXXX\")\ntrap 'rm -f -- \"$tmp\"' EXIT HUP INT TERM\nbase64 -d > \"$tmp\"\nif [ -f \"$p\" ]; then\n  mode=$(stat -c %a \"$p\" 2>/dev/null) || mode=\nelse\n  mode=$(printf '%o' $(( 0666 & ~0$(umask) ))) || mode=\nfi\nif [ -n \"$mode\" ]; then chmod \"$mode\" \"$tmp\" || :; fi\nmv -f -- \"$tmp\" \"$p\"\ntrap - EXIT HUP INT TERM",
        // `mktemp`'s template and `stat`'s and `chmod`'s operands begin as
        // the path does.
        quote(&operand(path))
    )
}
