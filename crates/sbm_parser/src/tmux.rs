//! tmux discovery: finding tmux, listing its sessions and a session's windows,
//! and the commands that attach a terminal.
//!
//! Two clients attach: the app's, which speaks tmux's control mode (`-CC`) and
//! renders the result itself, and the panel's, which cannot and so gets tmux's
//! own UI. Both are one-shot commands run before the terminal takes over; the
//! control-mode protocol the app then speaks is not a command and its output
//! and so is not here.
//!
//! Session ids and new-session names are validated here as well as accepted
//! quoted, because both are read by tmux itself: an id is a `$`-prefixed
//! number, and a name may not carry a `:` or `.` (target separators) or start
//! with `-` (which tmux would read as an option).

use serde::{Deserialize, Serialize};

use crate::script::shell_quote_unix as quote;

/// Locates tmux, including an installation added to `PATH` by `.bashrc`. The
/// direct probes are the fallback where an interactive bash is unavailable.
pub const FIND_COMMAND: &str =
    "bash -i -c 'command -v tmux' 2>/dev/null || command -v tmux 2>/dev/null || which tmux 2>/dev/null";

/// A tab produced by the remote shell rather than written into the command:
/// portable across `sh`, `bash`, `zsh` and `dash`, while tmux still receives a
/// real tab in its format argument.
const SHELL_TAB: &str = "$(printf '\\t')";

/// The prefix of a plain client: tmux's own UI, no control mode. The panel's
/// xterm.js needs this one, since it cannot decode control mode the way the
/// app's client does.
///
/// `-u` is not only about rendering: in a non-UTF-8 locale tmux can replace
/// the tab separators of formatted output with `_`, which breaks the parsers
/// below. An exec shell often has no locale at all.
fn plain_client(bin: &str) -> String {
    format!("{} -u", quote(bin))
}

/// The prefix of a discovery command: the plain client, whose formatted output
/// the parsers below read.
fn discovery(bin: &str) -> String {
    plain_client(bin)
}

/// The prefix of the terminal's client: `-CC` is control mode, which the app
/// decodes and renders itself instead of showing tmux's own UI.
fn client(bin: &str) -> String {
    format!("{} -u -CC", quote(bin))
}

/// The path [`FIND_COMMAND`] printed, or `None` when it found none.
///
/// The last line that is an absolute path to a `tmux`: an interactive bash
/// runs `.bashrc`, whose banner or greeting lands on the same stdout, and only
/// the answer to `command -v tmux` names an executable called that.
pub fn parse_find(output: &str, succeeded: bool) -> Option<String> {
    if !succeeded {
        return None;
    }
    output
        .lines()
        .map(str::trim)
        .rfind(|line| line.starts_with('/') && line.ends_with("/tmux"))
        .map(str::to_owned)
}

/// Every session: id, `q:`-escaped name, window count, attached clients and
/// three times, tab-separated. The id leads and the name is escaped, so `|`
/// and `:` are valid parts of a name rather than delimiters.
///
/// The times are the raw epoch variables. tmux dropped the `*_string`
/// variables they replace (3.6a has none of them), so a listing built on those
/// comes back with three empty fields on every current version.
pub fn list_sessions_command(bin: &str) -> String {
    let t = SHELL_TAB;
    format!(
        "{} list-sessions -F \"#{{session_id}}{t}#{{q:session_name}}{t}#{{session_windows}}{t}#{{session_attached}}{t}#{{session_created}}{t}#{{session_last_attached}}{t}#{{session_activity}}\"",
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
        "{} list-windows -t {} -F \"#{{window_index}}{t}#{{q:window_name}}{t}#{{window_active}}{t}#{{window_panes}}{t}#{{window_activity}}\"",
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

/// Attach the panel's plain client to a session.
///
/// [session_id] is a `$` id and never a name: a name may contain `:` or `.`,
/// which tmux reads as target separators. Validate it with
/// [`validate_session_id`] first — this only quotes it, so a caller that skips
/// the check cannot reach a shell, but the target could still be misread.
pub fn attach_session_plain_command(bin: &str, session_id: &str) -> String {
    format!(
        "{} attach-session -t {}",
        plain_client(bin),
        quote(session_id)
    )
}

/// Attach the panel's plain client to `name`, creating it when it does not
/// exist.
///
/// [name] is the value [`normalize_session_name`] returned, not what a user
/// typed: trimming and the character rules belong there, so the command and
/// the check agree on one value.
pub fn new_session_plain_command(bin: &str, name: &str) -> String {
    format!("{} new-session -A -s {}", plain_client(bin), quote(name))
}

/// Why a session id or a new session's name could not be used.
///
/// The rules are tmux's own, not a shell's: both values are quoted before they
/// reach a command, so this is about what tmux would read them as.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TmuxError {
    /// Not `$` followed by digits.
    InvalidSessionId,
    /// Empty once trimmed.
    EmptyName,
    /// Longer than 64 characters.
    NameTooLong,
    /// A control or invisible formatting character, which a terminal would act
    /// on — or hide, leaving a name that reads as something else.
    NameControlChar,
    /// A `:` or `.`, which tmux reads as a session/window separator.
    NameSeparator,
    /// A leading `-`, which tmux would read as an option.
    NameLeadingDash,
}

impl TmuxError {
    /// The wire code, also what a refusal is recorded under.
    pub fn code(self) -> &'static str {
        match self {
            Self::InvalidSessionId => "invalid_session_id",
            Self::EmptyName => "empty_name",
            Self::NameTooLong => "name_too_long",
            Self::NameControlChar => "name_control_char",
            Self::NameSeparator => "name_separator",
            Self::NameLeadingDash => "name_leading_dash",
        }
    }
}

impl std::fmt::Display for TmuxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::InvalidSessionId => "the session id is not a tmux id",
            Self::EmptyName => "the session name is empty",
            Self::NameTooLong => "the session name is longer than 64 characters",
            Self::NameControlChar => {
                "the session name contains a control or invisible formatting character"
            }
            Self::NameSeparator => "the session name contains ':' or '.'",
            Self::NameLeadingDash => "the session name starts with '-'",
        })
    }
}

impl std::error::Error for TmuxError {}

/// The longest a session name may be.
const MAX_NAME_LEN: usize = 64;

/// A tmux session id: `$` and at least one digit, nothing else.
pub fn validate_session_id(id: &str) -> Result<(), TmuxError> {
    if is_id(id, '$') {
        Ok(())
    } else {
        Err(TmuxError::InvalidSessionId)
    }
}

/// The name to hand to [`new_session_plain_command`], or why it cannot be one.
///
/// The value returned is the trimmed one, so a caller validates and uses the
/// same string rather than one that only happens to look like it.
pub fn normalize_session_name(raw: &str) -> Result<String, TmuxError> {
    let name = raw.trim();
    if name.is_empty() {
        return Err(TmuxError::EmptyName);
    }
    if name.starts_with('-') {
        return Err(TmuxError::NameLeadingDash);
    }
    if name.chars().count() > MAX_NAME_LEN {
        return Err(TmuxError::NameTooLong);
    }
    if name.chars().any(|c| c.is_control() || is_format_char(c)) {
        return Err(TmuxError::NameControlChar);
    }
    if name.contains(':') || name.contains('.') {
        return Err(TmuxError::NameSeparator);
    }
    Ok(name.to_owned())
}

/// Unicode format characters (general category Cf), which the same rule keeps
/// out of a name.
///
/// They are invisible or reorder what surrounds them, so a name carrying one
/// is not the name it appears to be: a bidi override turns it into something
/// else on screen, a zero-width or tag character makes two names look
/// identical, and a directory of such names is `ls` output nobody can tell
/// apart. Rust's std has no general-category API — `char::is_control` is Cc
/// only — so this is the whole of Cf as of Unicode 16.0, listed.
fn is_format_char(c: char) -> bool {
    matches!(
        c,
        '\u{00AD}' // soft hyphen
        | '\u{0600}'..='\u{0605}' // Arabic number signs
        | '\u{061C}' // Arabic letter mark
        | '\u{06DD}' // Arabic end of ayah
        | '\u{070F}' // Syriac abbreviation mark
        | '\u{0890}'..='\u{0891}' // Arabic pound / piastre mark above
        | '\u{08E2}' // Arabic disputed end of ayah
        | '\u{180E}' // Mongolian vowel separator
        | '\u{200B}'..='\u{200F}' // zero-width space..right-to-left mark
        | '\u{202A}'..='\u{202E}' // bidi embedding/override
        | '\u{2060}'..='\u{2064}' // word joiner..invisible plus
        | '\u{2066}'..='\u{206F}' // bidi isolates, deprecated format controls
        | '\u{FEFF}' // zero-width no-break space
        | '\u{FFF9}'..='\u{FFFB}' // interlinear annotation
        | '\u{110BD}' // Kaithi number sign
        | '\u{110CD}' // Kaithi number sign above
        | '\u{13430}'..='\u{1343F}' // Egyptian hieroglyph format controls
        | '\u{1BCA0}'..='\u{1BCA3}' // shorthand format controls
        | '\u{1D173}'..='\u{1D17A}' // musical symbol format controls
        | '\u{E0001}' // language tag
        | '\u{E0020}'..='\u{E007F}' // tag characters
    )
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TmuxSession {
    /// `$` and digits.
    pub id: String,
    pub name: String,
    pub windows: i64,
    pub attached: bool,
    /// Seconds since the epoch, as tmux printed them. `None` where the field
    /// was empty or `0` — a session nobody has attached to has no
    /// `last_attached` — and where the command came from a caller that sent no
    /// such field at all.
    pub created: Option<i64>,
    pub last_attached: Option<i64>,
    pub activity: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TmuxWindow {
    pub index: i64,
    pub name: String,
    pub active: bool,
    pub panes: i64,
    /// Seconds since the epoch; `None` for a window that never saw output.
    pub activity: Option<i64>,
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
    let optional = |i: usize| epoch_field(fields.get(i));
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

/// One of the listing's time fields, as epoch seconds.
///
/// An absent, empty, non-numeric or zero field is `None`: tmux prints an empty
/// `session_last_attached` for a session nobody has attached to, and `0` for
/// one that never saw output. A `0` that survives to a view is a date in 1970
/// presented as when something happened.
fn epoch_field(value: Option<&String>) -> Option<i64> {
    let raw = unescape_field(value?);
    let seconds: i64 = raw.trim().parse().ok()?;
    (seconds > 0).then_some(seconds)
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
                activity: epoch_field(fields.get(4)),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_plain_client_commands_are_exact() {
        assert_eq!(
            attach_session_plain_command("/usr/bin/tmux", "$3"),
            "'/usr/bin/tmux' -u attach-session -t '$3'"
        );
        assert_eq!(
            new_session_plain_command("/usr/bin/tmux", "work"),
            "'/usr/bin/tmux' -u new-session -A -s 'work'"
        );
        // No control mode: the panel's renderer is xterm.js, which cannot
        // decode it.
        assert!(!attach_session_plain_command("/usr/bin/tmux", "$3").contains("-CC"));
    }

    #[test]
    fn a_session_id_is_a_dollar_and_digits() {
        for id in ["$0", "$12", "$1234567890"] {
            assert_eq!(validate_session_id(id), Ok(()), "{id:?}");
        }
        for id in ["", "3", "$", "$$3", "$3a", "3$", "$-1", "name", "$1;rm -rf /", "$ 3"] {
            assert_eq!(
                validate_session_id(id),
                Err(TmuxError::InvalidSessionId),
                "{id:?}"
            );
        }
    }

    #[test]
    fn a_new_name_is_trimmed_and_checked() {
        assert_eq!(normalize_session_name("  work  "), Ok("work".to_owned()));
        assert_eq!(normalize_session_name("lab mine"), Ok("lab mine".to_owned()));

        assert_eq!(normalize_session_name("   "), Err(TmuxError::EmptyName));
        assert_eq!(
            normalize_session_name(&"a".repeat(65)),
            Err(TmuxError::NameTooLong)
        );
        assert_eq!(normalize_session_name("a\nb"), Err(TmuxError::NameControlChar));
        assert_eq!(normalize_session_name("a\tb"), Err(TmuxError::NameControlChar));
        assert_eq!(normalize_session_name("a:b"), Err(TmuxError::NameSeparator));
        assert_eq!(normalize_session_name("a.b"), Err(TmuxError::NameSeparator));
        assert_eq!(normalize_session_name("-x"), Err(TmuxError::NameLeadingDash));
    }

    /// Invisible formatting characters are refused with the control ones: a
    /// name carrying a bidi override or a zero-width character does not read
    /// as what it is.
    #[test]
    fn a_name_with_an_invisible_character_is_refused() {
        for name in [
            "a\u{00AD}b", // soft hyphen
            "a\u{061C}b", // Arabic letter mark
            "a\u{180E}b", // Mongolian vowel separator
            "a\u{200B}b", // zero-width space
            "a\u{200C}b", // zero-width non-joiner
            "a\u{200D}b", // zero-width joiner
            "a\u{200E}b", // left-to-right mark
            "a\u{200F}b", // right-to-left mark
            "a\u{202A}b", // bidi embedding
            "a\u{202E}b", // bidi override
            "a\u{2060}b", // word joiner
            "a\u{2064}b", // invisible plus
            "a\u{2066}b", // bidi isolate
            "a\u{2069}b", // bidi pop isolate
            "a\u{FEFF}b", // zero-width no-break space
            "a\u{0600}b", // Arabic number sign
            "a\u{206F}b", // nominal digit shapes
            "a\u{FFF9}b", // interlinear annotation anchor
            "a\u{1D173}b", // musical format control
            "a\u{E0001}b", // language tag
            "a\u{E0041}b", // tag latin capital A
            "a\u{E007F}b", // cancel tag
        ] {
            assert_eq!(
                normalize_session_name(name),
                Err(TmuxError::NameControlChar),
                "{name:?}"
            );
        }
        // Ordinary text is not caught by any of those ranges.
        assert_eq!(
            normalize_session_name("lab-1_wörk ✓"),
            Ok("lab-1_wörk ✓".to_owned())
        );
    }

    /// A name is quoted, so a shell metacharacter is an ordinary character;
    /// the rules above are tmux's, not the shell's.
    #[test]
    fn a_name_with_a_shell_metacharacter_is_quoted() {
        assert_eq!(
            new_session_plain_command("/usr/bin/tmux", "a;b"),
            "'/usr/bin/tmux' -u new-session -A -s 'a;b'"
        );
        assert_eq!(
            new_session_plain_command("/usr/bin/tmux", "it's"),
            r"'/usr/bin/tmux' -u new-session -A -s 'it'\''s'"
        );
        // `$` is quoted too, so a name cannot expand in the shell.
        assert_eq!(
            new_session_plain_command("/usr/bin/tmux", "$HOME"),
            "'/usr/bin/tmux' -u new-session -A -s '$HOME'"
        );
    }

    #[test]
    fn the_error_codes_are_what_the_wire_carries() {
        assert_eq!(TmuxError::InvalidSessionId.code(), "invalid_session_id");
        assert_eq!(TmuxError::EmptyName.code(), "empty_name");
        assert_eq!(TmuxError::NameTooLong.code(), "name_too_long");
        assert_eq!(TmuxError::NameControlChar.code(), "name_control_char");
        assert_eq!(TmuxError::NameSeparator.code(), "name_separator");
        assert_eq!(TmuxError::NameLeadingDash.code(), "name_leading_dash");
        assert_eq!(
            serde_json::to_string(&TmuxError::NameSeparator).unwrap(),
            r#""name_separator""#
        );
    }

    /// The listing the panel's `/tmux` serializes, as `parse_sessions` reads
    /// it — `TmuxSession` is `Serialize` for that endpoint.
    #[test]
    fn a_session_serializes_for_the_panel() {
        let listing = parse_sessions("$1\twork\t2\t0\t1767225600\t1767312000\t1767398400\n");
        assert_eq!(listing.sessions.len(), 1);
        let json = serde_json::to_value(&listing.sessions[0]).unwrap();
        assert_eq!(json["id"], "$1");
        assert_eq!(json["name"], "work");
        assert_eq!(json["windows"], 2);
        assert_eq!(json["attached"], false);
        assert_eq!(json["created"], 1767225600);
        assert_eq!(json["last_attached"], 1767312000);
        assert_eq!(json["activity"], 1767398400);
    }

    /// The times are epoch seconds, and a field that is not one is no time at
    /// all: tmux prints an empty `session_last_attached` for a session nobody
    /// has attached to and `0` for one that never saw output, and the
    /// `*_string` variables current versions dropped printed nothing.
    #[test]
    fn an_empty_or_zero_time_is_none() {
        let listing = parse_sessions("$1\twork\t1\t0\t1767225600\t\t0\n");
        let session = &listing.sessions[0];
        assert_eq!(session.created, Some(1767225600));
        assert_eq!(session.last_attached, None);
        assert_eq!(session.activity, None);

        // A field a caller did not send at all, and ones that are not a
        // positive number.
        let short = &parse_sessions("$1\twork\t1\t0\n").sessions[0];
        assert_eq!(
            (short.created, short.last_attached, short.activity),
            (None, None, None)
        );
        let odd = &parse_sessions("$1\twork\t1\t0\tx\t-3\t2026-01-03\n").sessions[0];
        assert_eq!((odd.created, odd.last_attached, odd.activity), (None, None, None));

        let windows = parse_windows("0\tsh\t1\t1\t1767398400\n1\tsh\t0\t1\t0\n");
        assert_eq!(windows[0].activity, Some(1767398400));
        assert_eq!(windows[1].activity, None);
    }
}
