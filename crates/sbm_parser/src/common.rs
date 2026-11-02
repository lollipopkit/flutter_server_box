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
            && is_uptime_remainder(time_part)
        {
            return Some(format!("{}, {}", first, time_part));
        }
        return Some(first.to_string());
    }
    Some(first.to_string())
}

/// [text] with every line ending a `\n`: Windows' `\r\n` and a lone `\r`
/// alike, before it is split into lines.
pub fn normalize_newlines(text: &str) -> String {
    text.replace("\r\n", "\n").replace('\r', "\n")
}

/// The seconds a [`parse_uptime`] string (or the monitor agent's
/// `format_uptime`, the same shape) says the machine has been up: an
/// optional day count, then `H:MM` or one unit (`min[s]`, `hr[s]`,
/// `sec[s]`). `None` for anything else: a sort puts an unknown last rather
/// than guessing a number for it.
pub fn uptime_seconds(formatted: &str) -> Option<u64> {
    const DAY: u64 = 86_400;
    let rest = formatted.trim();
    let (days, rest) = match rest.split_once(' ') {
        Some((n, after)) if n.bytes().all(|b| b.is_ascii_digit()) && !n.is_empty() => {
            let after = after.trim_start();
            match after.strip_prefix("days").or_else(|| after.strip_prefix("day")) {
                Some("") => return n.parse::<u64>().ok().map(|d| d * DAY),
                // A day count followed by anything but `, <time>` is not read.
                Some(tail) => (n.parse::<u64>().ok()?, tail.strip_prefix(',')?.trim_start()),
                None => (0, rest),
            }
        }
        _ => (0, rest),
    };
    let digits = |s: &str| !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit());
    if let Some((h, m)) = rest.split_once(':') {
        if !(digits(h) && digits(m) && m.len() == 2) {
            return None;
        }
        return Some(days * DAY + h.parse::<u64>().ok()? * 3600 + m.parse::<u64>().ok()? * 60);
    }
    let split = rest.find(|c: char| !c.is_ascii_digit())?;
    let (count, unit) = rest.split_at(split);
    let per = match unit.trim_start() {
        "hr" | "hrs" => 3600,
        "min" | "mins" => 60,
        "sec" | "secs" => 1,
        _ => return None,
    };
    if !digits(count) {
        return None;
    }
    Some(days * DAY + count.parse::<u64>().ok()? * per)
}

/// What `uptime(1)` prints after the day count: `H:MM`, or a single unit when
/// the other is zero — `10 min` (procps, busybox), `3 hrs` / `14 mins` /
/// `30 secs` (BSD and macOS `w.c`). Dropping the unit form lost the hours and
/// minutes of any machine whose uptime had a zero in one of them.
fn is_uptime_remainder(part: &str) -> bool {
    if part.contains(':') {
        return !part.contains("user") && !part.contains("load");
    }
    let Some((count, unit)) = part.split_once(' ') else {
        return false;
    };
    !count.is_empty()
        && count.bytes().all(|b| b.is_ascii_digit())
        && matches!(unit, "min" | "mins" | "hr" | "hrs" | "sec" | "secs")
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

/// Every address a machine printed about its own interfaces.
///
/// **Tolerant on purpose.** Three commands on three platforms produce three
/// unrelated formats — `inet 1.2.3.4/24 brd ...`, `inet 1.2.3.4 netmask
/// 0xffffff00`, a bare column — and a parser per format is three things to
/// keep right for one question. This pulls out anything shaped like an address
/// and keeps whatever actually parses as one, in the order it appeared.
///
/// **Public/private is not decided here.** The caller classifies: the app has
/// one careful table of the fifteen ranges that count as private
/// (`isPrivateHost`), and a second, looser copy on this side would be a second
/// answer to a question with one right answer. So a netmask that reads as
/// `255.255.255.0` and a loopback address both survive this function and are
/// discarded a layer up.
///
/// A MAC address needs no special handling: six groups of two hex digits is
/// not an IPv6 address and `IpAddr` refuses it.
pub fn parse_ips(raw: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for token in ip_tokens(raw) {
        // A zone index is not part of the address — `fe80::1%en0`. A prefix
        // length is not either, but `/` is absent from the token charset, so
        // `1.2.3.4/24` has already arrived here as two separate tokens.
        let text = token.split('%').next().unwrap_or("");
        let Ok(addr) = text.parse::<std::net::IpAddr>() else {
            continue;
        };
        let normalised = addr.to_string();
        if !out.contains(&normalised) {
            out.push(normalised);
        }
    }
    out
}

/// Substrings of [`parse_ips`]'s input that could be an address.
///
/// Hand-rolled rather than a regex: `sbm_parser` has no regex dependency and
/// adding one for this would be the largest thing in the crate. A candidate is
/// a maximal run of characters an address can contain, which is then handed to
/// `IpAddr` — the only judge of whether it is one.
fn ip_tokens(raw: &str) -> Vec<&str> {
    let is_part = |c: char| c.is_ascii_hexdigit() || c == '.' || c == ':' || c == '%';
    let mut tokens = Vec::new();
    let mut start: Option<usize> = None;
    for (i, c) in raw.char_indices() {
        match (is_part(c), start) {
            (true, None) => start = Some(i),
            (false, Some(from)) => {
                tokens.push(&raw[from..i]);
                start = None;
            }
            _ => {}
        }
    }
    if let Some(from) = start {
        tokens.push(&raw[from..]);
    }
    tokens
}

#[cfg(test)]
mod ip_tests {
    use super::parse_ips;

    #[test]
    fn iproute2_with_prefixes() {
        let out = parse_ips(
            "2: eth0    inet 45.32.10.20/23 brd 45.32.11.255 scope global eth0",
        );
        // The prefix is not an address, and the broadcast is - discarding it
        // is the caller's job, and it answers the same place anyway.
        assert_eq!(out, vec!["45.32.10.20", "45.32.11.255"]);
    }

    #[test]
    fn ifconfig_keeps_netmasks_and_drops_macs() {
        let out = parse_ips(
            "en0: flags=8863<UP,BROADCAST> mtu 1500
             	ether ac:de:48:00:11:22
             	inet 192.168.1.42 netmask 0xffffff00 broadcast 192.168.1.255
             	inet6 fe80::1cde:48ff:fe00:1122%en0 prefixlen 64 scopeid 0x6
             	inet6 2606:4700:4700::1111 prefixlen 64
",
        );
        // A MAC is six groups of two hex digits and is not an IPv6 address, so
        // it never reaches the caller. A dotted netmask *does*, and is
        // discarded there as reserved space - see this function's docs.
        assert_eq!(
            out,
            vec![
                "192.168.1.42",
                "192.168.1.255",
                "fe80::1cde:48ff:fe00:1122",
                "2606:4700:4700::1111",
            ]
        );
    }

    #[test]
    fn powershell_one_per_line() {
        let out = parse_ips("127.0.0.1
::1
fe80::9c1f%12
10.0.0.7
45.32.10.20
");
        assert_eq!(out, vec!["127.0.0.1", "::1", "fe80::9c1f", "10.0.0.7", "45.32.10.20"]);
    }

    #[test]
    fn the_same_address_twice_is_one() {
        let out = parse_ips("inet 45.32.10.20/23 eth0
inet 45.32.10.20/23 eth0:1");
        assert_eq!(out, vec!["45.32.10.20"]);
    }

    #[test]
    fn nothing_shaped_like_an_address_is_nothing() {
        assert!(parse_ips("").is_empty());
        assert!(parse_ips("sh: ip: not found").is_empty());
        // Words made only of hex letters are candidates and must still fail.
        assert!(parse_ips("deadbeef cafe face").is_empty());
    }
}

#[cfg(test)]
mod uptime_tests {
    use super::*;

    /// Moved from the app's sort (`ServerSortOrder.uptimeSeconds`), which
    /// read the same strings in Dart.
    #[test]
    fn uptime_seconds_reads_every_shape_parse_uptime_keeps() {
        let (day, hour, minute) = (86_400, 3600, 60);
        assert_eq!(uptime_seconds("61 days, 18:16"), Some(61 * day + 18 * hour + 16 * minute));
        assert_eq!(uptime_seconds("1 day, 2:34"), Some(day + 2 * hour + 34 * minute));
        assert_eq!(uptime_seconds("5 days"), Some(5 * day));
        assert_eq!(uptime_seconds("2:34"), Some(2 * hour + 34 * minute));
        assert_eq!(uptime_seconds("34 min"), Some(34 * minute));
        // A zero hour or minute prints a unit instead of H:MM: procps and
        // busybox `min`, BSD and macOS `hr[s]`, `min[s]` and `sec[s]`.
        assert_eq!(uptime_seconds("5 days, 10 min"), Some(5 * day + 10 * minute));
        assert_eq!(uptime_seconds("2 days, 3 hrs"), Some(2 * day + 3 * hour));
        assert_eq!(uptime_seconds("1 day, 1 hr"), Some(day + hour));
        assert_eq!(uptime_seconds("3 days, 14 mins"), Some(3 * day + 14 * minute));
        assert_eq!(uptime_seconds("14 mins"), Some(14 * minute));
        assert_eq!(uptime_seconds("30 secs"), Some(30));
        assert_eq!(uptime_seconds("1 sec"), Some(1));
        // The monitor agent's `format_uptime`, which pluralises every count.
        assert_eq!(uptime_seconds("1 days, 1:00"), Some(day + hour));
        // What `parse_uptime` gives for real lines.
        assert_eq!(uptime_seconds(&parse_uptime(" 10:00:00 up 61 days, 18:16,  1 user,  load average: 0.1").unwrap()), Some(61 * day + 18 * hour + 16 * minute));
    }

    #[test]
    fn uptime_seconds_refuses_what_it_cannot_read() {
        for raw in ["invalid uptime format", "", "   ", "18:16:30", "5 days, garbled", "5 days, 3 weeks", "2:3", "days"] {
            assert_eq!(uptime_seconds(raw), None, "{raw}");
        }
    }
}
