//! tmux discovery: finding tmux, listing its sessions and a session's windows,
//! and the command that attaches the terminal's control-mode client.
//!
//! Only the one-shot commands run before a terminal attaches. Once attached,
//! the app's control-mode client speaks tmux's live protocol itself, which is
//! not a command and its output and so is not here.

use crate::script::shell_quote_unix as quote;

/// Locates tmux, including an installation added to `PATH` by `.bashrc`. The
/// direct probes are the fallback where an interactive bash is unavailable.
pub const FIND_COMMAND: &str =
    "bash -i -c 'command -v tmux' 2>/dev/null || command -v tmux 2>/dev/null || which tmux 2>/dev/null";

/// A tab produced by the remote shell rather than written into the command:
/// portable across `sh`, `bash`, `zsh` and `dash`, while tmux still receives a
/// real tab in its format argument.
const SHELL_TAB: &str = "$(printf '\\t')";

/// The prefix of a discovery command.
///
/// `-u` is not only about rendering: in a non-UTF-8 locale tmux can replace
/// the tab separators of formatted output with `_`, which breaks the parsers
/// below. An exec shell often has no locale at all.
fn discovery(bin: &str) -> String {
    format!("{} -u", quote(bin))
}

/// The prefix of the terminal's client: `-CC` is control mode, which the app
/// decodes and renders itself instead of showing tmux's own UI.
fn client(bin: &str) -> String {
    format!("{} -u -CC", quote(bin))
}

/// The first path [`FIND_COMMAND`] printed, or `None` when it found none.
pub fn parse_find(output: &str, succeeded: bool) -> Option<String> {
    if !succeeded {
        return None;
    }
    let path = output.trim();
    (!path.is_empty()).then(|| path.to_owned())
}

/// Every session: id, `q:`-escaped name, window count, attached clients and
/// three times, tab-separated. The id leads and the name is escaped, so `|`
/// and `:` are valid parts of a name rather than delimiters.
pub fn list_sessions_command(bin: &str) -> String {
    let t = SHELL_TAB;
    format!(
        "{} list-sessions -F \"#{{session_id}}{t}#{{q:session_name}}{t}#{{session_windows}}{t}#{{session_attached}}{t}#{{session_created_string}}{t}#{{session_last_attached_string}}{t}#{{session_activity_string}}\"",
        discovery(bin)
    )
}

/// A session's windows, used only to check a restored window before attaching.
///
/// Tab-separated with the name escaped, as sessions are. It used `|`, which a
/// window name may contain, and such a name was cut short at it.
pub fn list_windows_command(bin: &str, session: &str) -> String {
    let t = SHELL_TAB;
    format!(
        "{} list-windows -t {} -F \"#{{window_index}}{t}#{{q:window_name}}{t}#{{window_active}}{t}#{{window_panes}}{t}#{{window_activity_string}}\"",
        discovery(bin),
        quote(session)
    )
}

/// Attach to a session. A stable `$id` target is preferred: `:` in a name
/// would be read as a session/window divider.
pub fn attach_session_command(bin: &str, session: &str) -> String {
    format!("{} attach-session -t {}", client(bin), quote(session))
}

pub fn attach_window_command(bin: &str, session: &str, window: i64) -> String {
    format!(
        "{} attach-session -t {}",
        client(bin),
        quote(&format!("{session}:{window}"))
    )
}

/// Attach to `name`, creating it when it does not exist.
pub fn new_session_or_attach_command(bin: &str, name: &str) -> String {
    format!("{} new-session -A -s {}", client(bin), quote(name))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TmuxSession {
    /// `$` and digits.
    pub id: String,
    pub name: String,
    pub windows: i64,
    pub attached: bool,
    pub created: Option<String>,
    pub last_attached: Option<String>,
    pub activity: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TmuxWindow {
    pub index: i64,
    pub name: String,
    pub active: bool,
    pub panes: i64,
    pub activity: Option<String>,
}

/// What [`list_sessions_command`] printed.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TmuxSessionListing {
    pub sessions: Vec<TmuxSession>,
    /// Lines that did not read as a session. Every line failing is a broken
    /// discovery contract rather than "no sessions", and worth a log line.
    pub unreadable: usize,
}

pub fn parse_sessions(output: &str) -> TmuxSessionListing {
    let mut listing = TmuxSessionListing::default();
    for line in output.split('\n').filter(|l| !l.trim().is_empty()) {
        match parse_session(line) {
            Some(session) => listing.sessions.push(session),
            None => listing.unreadable += 1,
        }
    }
    listing
}

fn parse_session(line: &str) -> Option<TmuxSession> {
    let fields = split_fields(line);
    if fields.len() < 4 {
        return None;
    }
    let id = unescape_field(&fields[0]);
    let name = unescape_field(&fields[1]);
    let windows: i64 = unescape_field(&fields[2]).parse().ok()?;
    let attached: i64 = unescape_field(&fields[3]).parse().ok()?;
    if !is_id(&id, '$') || name.is_empty() {
        return None;
    }
    let optional = |i: usize| fields.get(i).map(|f| unescape_field(f));
    Some(TmuxSession {
        id,
        name,
        windows,
        attached: attached > 0,
        created: optional(4),
        last_attached: optional(5),
        activity: optional(6),
    })
}

/// What [`list_windows_command`] printed; lines that do not read are skipped.
pub fn parse_windows(output: &str) -> Vec<TmuxWindow> {
    output
        .split('\n')
        .filter(|l| !l.trim().is_empty())
        .filter_map(|line| {
            let fields = split_fields(line);
            let index: i64 = unescape_field(fields.first()?).parse().ok()?;
            let field = |i: usize| fields.get(i).map(|f| unescape_field(f));
            Some(TmuxWindow {
                index,
                name: field(1).unwrap_or_default(),
                active: field(2).as_deref() == Some("1"),
                panes: field(3).and_then(|p| p.parse().ok()).unwrap_or(1),
                activity: field(4),
            })
        })
        .collect()
}

/// A tmux id: `prefix` and at least one digit, nothing else. Ids are
/// interpolated into commands, so nothing else is accepted as one.
fn is_id(value: &str, prefix: char) -> bool {
    value
        .strip_prefix(prefix)
        .is_some_and(|digits| !digits.is_empty() && digits.bytes().all(|b| b.is_ascii_digit()))
}

/// Splits a formatted line on unescaped tabs, leaving escapes in place.
pub fn split_fields(line: &str) -> Vec<String> {
    let mut fields = Vec::new();
    let mut current = String::new();
    let mut chars = line.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => {
                current.push(c);
                if let Some(next) = chars.next() {
                    current.push(next);
                }
            }
            '\t' => fields.push(std::mem::take(&mut current)),
            _ => current.push(c),
        }
    }
    fields.push(current);
    fields
}

/// Reverses tmux's `q:` escaping: `\x` is `x`, and runs of `\ooo` octal bytes
/// are UTF-8.
pub fn unescape_field(value: &str) -> String {
    let chars: Vec<char> = value.chars().collect();
    if chars.len() < 2 {
        return value.to_owned();
    }
    let mut out = String::new();
    let mut bytes: Vec<u8> = Vec::new();
    let flush = |bytes: &mut Vec<u8>, out: &mut String| {
        if !bytes.is_empty() {
            out.push_str(&String::from_utf8_lossy(bytes));
            bytes.clear();
        }
    };
    let mut i = 0;
    while i < chars.len() {
        if chars[i] != '\\' || i + 1 >= chars.len() {
            flush(&mut bytes, &mut out);
            out.push(chars[i]);
            i += 1;
            continue;
        }
        i += 1;
        if i + 2 < chars.len() {
            let octal: String = chars[i..i + 3].iter().collect();
            if octal.bytes().all(|b| (b'0'..=b'7').contains(&b))
                && let Ok(byte) = u8::from_str_radix(&octal, 8)
            {
                bytes.push(byte);
                i += 3;
                continue;
            }
        }
        flush(&mut bytes, &mut out);
        out.push(chars[i]);
        i += 1;
    }
    flush(&mut bytes, &mut out);
    out
}
