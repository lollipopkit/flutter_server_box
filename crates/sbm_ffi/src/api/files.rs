//! File browser shell commands FFI (sbm_parser::files)
//!
//! What the SCP backend runs for metadata and the SFTP backend runs when it
//! escalates through `sudo`, and the reader for their listings. The app runs
//! them over its own connection.

use sbm_parser::files::{self, FileKind};

/// One entry of a listing. `kind` is `dir`, `link`, `file` or `other`.
pub struct ShellFileRecord {
    pub name: String,
    pub kind: String,
    pub size: Option<i64>,
    /// Seconds since the epoch.
    pub mtime: Option<i64>,
    pub mode: Option<u32>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_list_command(path: String) -> String {
    files::list_command(&path)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_stat_command(path: String) -> String {
    files::stat_command(&path)
}

/// `(mark, exit code)` for "nothing there" and for "could not look".
#[flutter_rust_bridge::frb(sync)]
pub fn files_stat_markers() -> FilesStatMarkers {
    FilesStatMarkers {
        absent_mark: files::STAT_ABSENT_MARK.to_owned(),
        absent_exit: files::STAT_ABSENT_EXIT,
        denied_mark: files::STAT_DENIED_MARK.to_owned(),
        denied_exit: files::STAT_DENIED_EXIT,
    }
}

pub struct FilesStatMarkers {
    pub absent_mark: String,
    pub absent_exit: i32,
    pub denied_mark: String,
    pub denied_exit: i32,
}

/// `Err` is output that is not a listing: cut short, or not this command's.
#[flutter_rust_bridge::frb(sync)]
pub fn files_parse_records(output: String) -> Result<Vec<ShellFileRecord>, String> {
    Ok(files::parse_records(&output)?
        .into_iter()
        .map(|r| ShellFileRecord {
            name: r.name,
            kind: match r.kind {
                FileKind::Dir => "dir",
                FileKind::Link => "link",
                FileKind::File => "file",
                FileKind::Other => "other",
            }
            .to_owned(),
            size: r.size,
            mtime: r.mtime,
            mode: r.mode,
        })
        .collect())
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_rename_command(from: String, to: String) -> String {
    files::rename_command(&from, &to)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_mkdir_command(path: String, parents: bool) -> String {
    files::mkdir_command(&path, parents)
}

/// `is_dir` is what a stat said, `None` where it could not be asked.
#[flutter_rust_bridge::frb(sync)]
pub fn files_remove_command(path: String, is_dir: Option<bool>, recursive: bool, force: bool) -> String {
    files::remove_command(&path, is_dir, recursive, force)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_chmod_command(path: String, mode: u32) -> String {
    files::chmod_command(&path, mode)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_size_command(path: String) -> String {
    files::size_command(&path)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_parse_size(output: String) -> Option<i64> {
    files::parse_size(&output)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_read_command(path: String) -> String {
    files::read_command(&path)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_write_base64_command(data: String, path: String) -> String {
    files::write_base64_command(&data, &path)
}

/// `inner` as root, the password on `sudo -S`'s stdin. Sent to a shell over
/// stdin, never as a process argument.
#[flutter_rust_bridge::frb(sync)]
pub fn files_sudo_command(inner: String, password: String) -> String {
    files::sudo_command(&inner, &password)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_home_command(user: String) -> String {
    files::home_command(&user)
}

/// The home directory `passwd` names, else the usual one for `user`.
#[flutter_rust_bridge::frb(sync)]
pub fn files_home_from(output: Option<String>, user: String) -> String {
    output
        .as_deref()
        .and_then(files::parse_home)
        .unwrap_or_else(|| files::fallback_home(&user))
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_writable_command(dir: String) -> String {
    files::writable_command(&dir)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_in_dir_command(dir: String, command: String) -> String {
    files::in_dir_command(&dir, &command)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_editor_command(editor: String, path: String, sudo: bool) -> String {
    files::editor_command(&editor, &path, sudo)
}

/// `None` for a file this does not know how to unpack.
#[flutter_rust_bridge::frb(sync)]
pub fn files_extract_command(path: String) -> Option<String> {
    files::extract_command(&path)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_scp_source_command(path: String) -> String {
    files::scp_source_command(&path)
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_scp_sink_command(path: String) -> String {
    files::scp_sink_command(&path)
}

/// What [`files_capped_read_command`] answered.
pub struct CappedRead {
    /// The whole file's size, which may exceed `data`.
    pub size: i64,
    pub data: Vec<u8>,
}

/// `(is a directory, nothing there)` exit codes of [`files_capped_read_command`].
#[flutter_rust_bridge::frb(sync)]
pub fn files_capped_read_exits() -> Vec<i32> {
    vec![files::READ_IS_DIR_EXIT, files::READ_MISSING_EXIT]
}

#[flutter_rust_bridge::frb(sync)]
pub fn files_capped_read_command(path: String, max_bytes: u32) -> String {
    files::capped_read_command(&path, u64::from(max_bytes))
}

/// `Err` is output that is not this command's.
#[flutter_rust_bridge::frb(sync)]
pub fn files_parse_capped_read(output: String, max_bytes: u32) -> Result<CappedRead, String> {
    let (size, data) = files::parse_capped_read(&output, u64::from(max_bytes))?;
    Ok(CappedRead { size: i64::try_from(size).map_err(|_| "an invalid file size")?, data })
}

/// Replaces `path` with the base64 on stdin, staged under `suffix`.
#[flutter_rust_bridge::frb(sync)]
pub fn files_atomic_write_command(path: String, suffix: String) -> String {
    files::atomic_write_command(&path, &suffix)
}
