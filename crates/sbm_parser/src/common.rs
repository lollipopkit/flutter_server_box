//! 平台通用的轻量文本解析(对照 Dart server_status_update_req.dart)

/// `uptime` 输出(Dart `_parseUpTime`):
/// "up 61 days, 18:16, 1 user, ..." → "61 days, 18:16";"up 34 min, ..." → "34 min"
pub fn parse_uptime(raw: &str) -> Option<String> {
    let mut parts = raw.splitn(2, "up ");
    let (_, uptime_part) = (parts.next()?, parts.next()?);
    // Dart split 语义:必须恰好一个 "up "
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

/// /etc/*-release 的 PRETTY_NAME 行(Dart `_parseSysVer`)
pub fn parse_sys_version(raw: &str) -> Option<String> {
    let parts: Vec<&str> = raw.split('=').collect();
    if parts.len() == 2 {
        Some(parts[1].replace('"', "").replacen('\n', "", 1))
    } else {
        None
    }
}

/// hostname 输出(Dart `_parseHostName`):trim 后非空
pub fn parse_hostname(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}
