//! Where a terminal's shell is, for one that never prints OSC 7
//! (sbm_parser::shell_cwd)

use sbm_parser::shell_cwd;

/// Run on an exec channel of the terminal's own SSH connection, as `sh`.
#[flutter_rust_bridge::frb(sync)]
pub fn shell_cwd_script() -> String {
    shell_cwd::SCRIPT.to_owned()
}

/// [`shell_cwd_script`]'s output → the directory of the shell behind a
/// terminal of `cols` × `rows`, or `None` when that is not one shell.
#[flutter_rust_bridge::frb(sync)]
pub fn shell_cwd_pick(raw: String, cols: u16, rows: u16) -> Option<String> {
    shell_cwd::pick(&shell_cwd::parse(&raw), cols, rows).map(str::to_owned)
}

/// A path as one word for a terminal's command line.
#[flutter_rust_bridge::frb(sync)]
pub fn shell_word(path: String) -> String {
    shell_cwd::shell_word(&path)
}
