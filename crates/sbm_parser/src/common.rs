//! Cross-platform lightweight text parsing (Dart reference: server_status_update_req.dart)

/// `uptime` output (Dart `_parseUpTime`):
/// "up 61 days, 18:16, 1 user, ..." → "61 days, 18:16";"up 34 min, ..." → "34 min"
pub fn parse_uptime(raw: &str) -> Option<String> {
    let mut parts = raw.splitn(2, "up ");
    let (_, uptime_part) = (parts.next()?, parts.next()?);
    // Dart split semantics: exactly one "up " required
    if uptime_part.contains("up ") {
        return None;
    }
    let segments: Vec<&str> = uptime_part.split(", ").collect();
    let first = segments.first()?.trim();

    if first.contains("day") {
        if let Some(time_part) = segments.get(1).map(|s| s.trim())
            && time_part.contains(':')
            && !time_part.contains("user")
            && !time_part.contains("load")
        {
            return Some(format!("{}, {}", first, time_part));
        }
        return Some(first.to_string());
    }
    Some(first.to_string())
}

/// One `KEY=value` line's value out of an os-release block, unquoted.
///
/// Key-based rather than "the only `=` in the input", which is what this used
/// to be: the `sys` command now prints `ID`, `ID_LIKE` and `PRETTY_NAME`
/// together, and a system whose `/etc/os-release` is a symlink to
/// `/usr/lib/os-release` prints each of them twice. The first wins, which is
/// also the precedence os-release itself specifies — `/etc` before `/usr/lib`.
///
/// The `=` is checked separately from the key so that `ID_LIKE=debian` is not
/// read as `ID` with the value `_LIKE=debian`.
fn os_release_value(raw: &str, key: &str) -> Option<String> {
    raw.lines()
        .map(str::trim)
        .find_map(|line| line.strip_prefix(key)?.strip_prefix('='))
        .map(unquote)
}

/// os-release quotes a value only when it has to, and either quote character
/// is allowed. Anything else in the line is part of the value.
///
/// A double-quoted value is shell-quoted, which os-release says in so many
/// words, so `PRETTY_NAME="Foo \"Bar\" Linux"` carries backslashes that are
/// not part of the name. They used to reach the status card as written. A
/// single-quoted value has no escapes in shell and gets none here.
fn unquote(value: &str) -> String {
    let value = value.trim();
    if let Some(inner) = value.strip_prefix('"').and_then(|v| v.strip_suffix('"')) {
        return unescape_double_quoted(inner);
    }
    if let Some(inner) = value.strip_prefix('\'').and_then(|v| v.strip_suffix('\'')) {
        return inner.to_string();
    }
    value.to_string()
}

/// The four characters a backslash escapes inside shell double quotes.
///
/// Every other `\x` keeps its backslash, which is what the shell does too — so
/// a Windows path in a value is left alone rather than quietly mangled.
fn unescape_double_quoted(value: &str) -> String {
    if !value.contains('\\') {
        return value.to_string();
    }
    let mut out = String::with_capacity(value.len());
    let mut chars = value.chars();
    while let Some(c) = chars.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }
        match chars.next() {
            Some(next @ ('"' | '\\' | '$' | '`')) => out.push(next),
            // A trailing backslash is not an escape of anything.
            Some(next) => {
                out.push('\\');
                out.push(next);
            }
            None => out.push('\\'),
        }
    }
    out
}

/// `PRETTY_NAME` — the line written for a person to read (Dart `_parseSysVer`).
///
/// This is what the status page's "system" card shows, so it stays prose and
/// keeps its capitalisation. [`parse_os_id`] is the half meant for matching.
pub fn parse_sys_version(raw: &str) -> Option<String> {
    os_release_value(raw, "PRETTY_NAME").filter(|v| !v.is_empty())
}

/// `ID` — os-release's machine-readable identifier for the distribution.
///
/// Lower-cased because the spec restricts it to lower-case already and a
/// caller matching against it should not have to trust that. Absent on a
/// remote with no `/etc/os-release` at all, where [`parse_sys_version`] is the
/// only thing to go on.
pub fn parse_os_id(raw: &str) -> Option<String> {
    os_release_value(raw, "ID")
        .map(|v| v.to_ascii_lowercase())
        .filter(|v| !v.is_empty())
}

/// `ID_LIKE` — the distributions this one is derived from, closest first.
///
/// Space-separated in the file. Useful as a last resort: a derivative nothing
/// here knows by name still says which base it is built on, and the base's
/// mark is a better answer than none.
pub fn parse_os_id_like(raw: &str) -> Vec<String> {
    os_release_value(raw, "ID_LIKE")
        .map(|v| v.to_ascii_lowercase().split_whitespace().map(str::to_string).collect())
        .unwrap_or_default()
}

/// hostname output (Dart `_parseHostName`): non-empty after trim
pub fn parse_hostname(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}
