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

/// PRETTY_NAME line of /etc/*-release (Dart `_parseSysVer`)
pub fn parse_sys_version(raw: &str) -> Option<String> {
    let parts: Vec<&str> = raw.split('=').collect();
    if parts.len() == 2 {
        Some(parts[1].replace('"', "").replacen('\n', "", 1))
    } else {
        None
    }
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
