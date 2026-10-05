//! tmux discovery FFI (sbm_parser::tmux)
//!
//! Finding tmux, listing sessions and windows, and the command the terminal's
//! control-mode client attaches with. The live control-mode protocol after it
//! is the app's own.

use sbm_parser::tmux;

pub struct TmuxSessionItem {
    /// `$` and digits.
    pub id: String,
    pub name: String,
    pub windows: i64,
    pub attached: bool,
    pub created: Option<String>,
    pub last_attached: Option<String>,
    pub activity: Option<String>,
}

pub struct TmuxWindowItem {
    pub index: i64,
    pub name: String,
    pub active: bool,
    pub panes: i64,
    pub activity: Option<String>,
}

pub struct TmuxSessionListingItem {
    pub sessions: Vec<TmuxSessionItem>,
    /// Lines that did not read as a session.
    pub unreadable: u32,
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_find_command() -> String {
    tmux::FIND_COMMAND.to_owned()
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_parse_find(output: String, succeeded: bool) -> Option<String> {
    tmux::parse_find(&output, succeeded)
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_list_sessions_command(bin: String) -> String {
    tmux::list_sessions_command(&bin)
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_list_windows_command(bin: String, session: String) -> String {
    tmux::list_windows_command(&bin, &session)
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_attach_session_command(bin: String, session: String) -> String {
    tmux::attach_session_command(&bin, &session)
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_attach_window_command(bin: String, session: String, window: i64) -> String {
    tmux::attach_window_command(&bin, &session, window)
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_new_session_or_attach_command(bin: String, name: String) -> String {
    tmux::new_session_or_attach_command(&bin, &name)
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_parse_sessions(output: String) -> TmuxSessionListingItem {
    let listing = tmux::parse_sessions(&output);
    TmuxSessionListingItem {
        unreadable: listing.unreadable as u32,
        sessions: listing
            .sessions
            .into_iter()
            .map(|s| TmuxSessionItem {
                id: s.id,
                name: s.name,
                windows: s.windows,
                attached: s.attached,
                created: s.created,
                last_attached: s.last_attached,
                activity: s.activity,
            })
            .collect(),
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn tmux_parse_windows(output: String) -> Vec<TmuxWindowItem> {
    tmux::parse_windows(&output)
        .into_iter()
        .map(|w| TmuxWindowItem {
            index: w.index,
            name: w.name,
            active: w.active,
            panes: w.panes,
            activity: w.activity,
        })
        .collect()
}
