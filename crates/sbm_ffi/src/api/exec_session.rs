//! The session a command runs in over SSH (sbm_parser::exec_session): the
//! wrapper that prints it, the reader that finds it on stderr, the check that
//! it is this run's and the command that kills what is left in it.

use flutter_rust_bridge::frb;
use sbm_parser::exec_session as es;
pub use sbm_parser::exec_session::SessionMarker;
pub use sbm_parser::sudo::SudoEntry;

#[frb(mirror(SessionMarker))]
pub struct _SessionMarker {
    pub start: u32,
    pub end: u32,
    pub id: u32,
}

/// How a command reaches root (mirrors sbm_parser::sudo::SudoEntry).
#[frb(mirror(SudoEntry))]
pub enum _SudoEntry {
    /// As this account
    Direct,
    /// `sudo -n`
    SudoNoPassword,
    /// `sudo -S -p ''`, the password first on stdin
    SudoPassword,
}

/// [body], a command line, run the way [entry] says.
#[frb(sync)]
pub fn sudo_entry(entry: SudoEntry, body: String) -> String {
    entry.wrap(&body)
}

#[frb(sync)]
pub fn exec_session_env_name() -> String {
    es::ENV_NAME.to_owned()
}

#[frb(sync)]
pub fn exec_session_owned() -> String {
    es::OWNED.to_owned()
}

#[frb(sync)]
pub fn exec_session_gone() -> String {
    es::GONE.to_owned()
}

#[frb(sync)]
pub fn exec_session_wrap(command: String, nonce: String) -> String {
    es::wrap(&command, &nonce)
}

#[frb(sync)]
pub fn exec_session_kill_command(id: u32, entry: SudoEntry) -> String {
    es::kill_command(id, entry)
}

#[frb(sync)]
pub fn exec_session_owns_command(id: u32, nonce: String) -> String {
    es::owns_command(id, &nonce)
}

/// Where the marker is in what stderr has said so far, or `None` until it is
/// whole.
#[frb(sync)]
pub fn exec_session_find_marker(head: Vec<u8>) -> Option<SessionMarker> {
    es::find_marker(&head)
}

/// How much of what came before a chunk a marker split across chunks can
/// still need: search each chunk with this much in front of it.
#[frb(sync)]
pub fn exec_session_marker_max() -> u32 {
    es::MARKER_MAX
}
