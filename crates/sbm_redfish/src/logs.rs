//! Logs (`LogService`): the system's event log (SEL), the BMC's own logs.
//!
//! Which logs exist and what they are called is per vendor — OpenBMC has
//! `EventLog` under the system and `Journal` under the manager, iDRAC `Sel`
//! and `Lclog` under the manager, iLO `IML` under the system and `IEL` under
//! the manager — so they are listed, never named.

use std::cmp::Reverse;

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::model::{Topology, collection_paths, odata_id};
use crate::{Error, Failure, Outcome, Transport};

/// How many entries one read keeps: a BMC's journal holds thousands, and the
/// newest are the ones anyone opens a log for.
pub const MAX_LOG_ENTRIES: usize = 200;

/// How many pages a read follows, so a service that pages by ten cannot make
/// one read a hundred requests.
const MAX_LOG_PAGES: usize = 20;

/// Whose a log is: the machine's, or the BMC's own.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LogScope {
    System,
    Manager,
}

/// One log a service keeps.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LogService {
    pub path: String,
    pub id: Option<String>,
    pub name: Option<String>,
    pub description: Option<String>,
    pub scope: LogScope,
    /// `LogEntryType`: `Event`, `SEL`, `Multiple`, `OEM` — absent on many.
    pub entry_type: Option<String>,
    pub entries: Option<String>,
    /// Where `ClearLog` is posted, when the log can be cleared.
    pub clear_target: Option<String>,
}

impl LogService {
    pub fn from_json(path: &str, json: &Value, scope: LogScope) -> Self {
        let text = |key: &str| json.get(key).and_then(Value::as_str).map(str::to_string);
        Self {
            path: path.to_string(),
            id: text("Id"),
            name: text("Name"),
            description: text("Description"),
            scope,
            entry_type: text("LogEntryType"),
            entries: json.get("Entries").and_then(odata_id).map(str::to_string),
            clear_target: json
                .get("Actions")
                .and_then(|a| a.get("#LogService.ClearLog"))
                .and_then(|c| c.get("target"))
                .and_then(Value::as_str)
                .map(str::to_string),
        }
    }

    /// Whether this is the machine's event log rather than one of the BMC's
    /// own diagnostics: what a list puts first.
    pub fn is_event_log(&self) -> bool {
        self.scope == LogScope::System
            || matches!(self.entry_type.as_deref(), Some("SEL" | "Event"))
            || self.id.as_deref().is_some_and(|id| id.eq_ignore_ascii_case("sel"))
    }
}

/// One entry.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LogEntry {
    pub id: Option<String>,
    /// ISO 8601, as the service wrote it.
    pub created: Option<String>,
    /// `OK`, `Warning` or `Critical`.
    pub severity: Option<String>,
    pub message: Option<String>,
    pub message_id: Option<String>,
    pub entry_type: Option<String>,
    pub sensor_type: Option<String>,
}

impl LogEntry {
    pub fn from_json(json: &Value) -> Self {
        let text = |key: &str| json.get(key).and_then(Value::as_str).map(str::to_string);
        Self {
            id: text("Id"),
            created: text("Created"),
            severity: text("Severity"),
            message: text("Message"),
            message_id: text("MessageId"),
            entry_type: text("EntryType"),
            sensor_type: text("SensorType"),
        }
    }
}

/// The newest entries of a log, newest first.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LogPage {
    pub entries: Vec<LogEntry>,
    /// `Members@odata.count`, where the service states it.
    pub total: Option<u64>,
    /// More entries were there than were kept.
    pub truncated: bool,
}

/// Every log the system and its BMC keep, the machine's event logs first.
/// A collection that cannot be read leaves the other, and a log that cannot
/// be read is left out; only when every collection fails is that the answer.
pub async fn log_services<T: Transport>(client: &T, topology: &Topology) -> Result<Vec<LogService>, Error> {
    let system = topology.system.as_ref().and_then(|s| s.log_services.clone());
    let manager = topology.manager.as_ref().and_then(|m| m.log_services.clone());
    let mut services = Vec::new();
    let mut failure = None;
    let mut read_any = false;
    for (collection, scope) in [(system, LogScope::System), (manager, LogScope::Manager)] {
        let Some(collection) = collection else { continue };
        let paths = match collection_paths(client, &collection).await {
            Ok((paths, _)) => paths,
            Err(e) => {
                failure = Some(e);
                continue;
            }
        };
        read_any = true;
        for path in paths {
            if let Ok(json) = client.get(&path).await {
                services.push(LogService::from_json(&path, &json, scope));
            }
        }
    }
    if let Some(e) = failure.filter(|_| !read_any) {
        return Err(e);
    }
    services.sort_by_key(|s| !s.is_event_log());
    Ok(services)
}

/// The newest [`MAX_LOG_ENTRIES`] entries of `service`, newest first.
///
/// Services list oldest first (bmcweb) or newest first (iDRAC), so only the
/// whole of what was read can be ordered, by `Created` where entries carry
/// it: an oldest-first log longer than the pages this reads is read from its
/// tail instead, or what came back would be its oldest entries. Only the
/// first page failing fails the read; a later one ends it with what was read,
/// said to be cut.
pub async fn log_entries<T: Transport>(client: &T, service: &LogService) -> Result<LogPage, Error> {
    let first_path = service
        .entries
        .as_deref()
        .ok_or_else(|| Error::with(Failure::NotSupported, "log has no entries"))?;
    let first = client.get(first_path).await?;
    let total = first.get("Members@odata.count").and_then(Value::as_u64);
    let mut entries = members(&first);
    let mut next = next_link(&first);
    let mut pages = 1;
    let mut unread = false;

    // One entry says nothing about which way the log runs; the page after it
    // does, and knowing that is worth one request.
    if entries.len() < 2 {
        match next.take() {
            Some(path) if pages < MAX_LOG_PAGES => match client.get(&path).await {
                Ok(page) => {
                    pages += 1;
                    entries.extend(members(&page));
                    next = next_link(&page);
                }
                Err(_) => unread = true,
            },
            Some(_) => unread = true,
            None => {}
        }
    }

    let mut read = Read { entries, unread };
    if let (Some(total), true) = (total, is_oldest_first(&read.entries))
        && total as usize > MAX_LOG_ENTRIES
        && !first_path.contains('?')
        && let Some((tail, more)) = read_tail(client, first_path, total as usize).await
    {
        read = Read { entries: tail, unread: more };
        next = None;
    }

    while let Some(path) = next.take() {
        if pages == MAX_LOG_PAGES {
            read.unread = true;
            break;
        }
        let Ok(page) = client.get(&path).await else {
            read.unread = true;
            break;
        };
        pages += 1;
        read.entries.extend(members(&page));
        next = next_link(&page);
    }

    let count = read.entries.len();
    let unread = read.unread || total.is_some_and(|t| t as usize > count);
    let mut entries = read.entries;
    // Stable, so entries with no timestamp keep the service's order among
    // themselves; those with none at all go last.
    entries.sort_by_key(|e| Reverse(instant(e.created.as_deref())));
    entries.truncate(MAX_LOG_ENTRIES);
    Ok(LogPage {
        truncated: unread || entries.len() < count,
        entries,
        total,
    })
}

struct Read {
    entries: Vec<LogEntry>,
    /// More was left unread.
    unread: bool,
}

/// Whether `entries` runs oldest first, from the ends of what it holds: one
/// entry, or one without a timestamp, says nothing.
fn is_oldest_first(entries: &[LogEntry]) -> bool {
    if entries.len() < 2 {
        return false;
    }
    let first = entries.first().and_then(|e| instant(e.created.as_deref()));
    let last = entries.last().and_then(|e| instant(e.created.as_deref()));
    matches!((first, last), (Some(a), Some(b)) if a < b)
}

/// The last [`MAX_LOG_ENTRIES`] entries of an oldest-first log, by `$skip` a
/// page at a time, and whether more was left; `None` for a service that takes
/// no `$skip` or answers as though it had not.
async fn read_tail<T: Transport>(client: &T, path: &str, total: usize) -> Option<(Vec<LogEntry>, bool)> {
    let mut at = total.saturating_sub(MAX_LOG_ENTRIES);
    let mut entries: Vec<LogEntry> = Vec::new();
    // `$top` makes the window one request where the service takes it; the
    // ones that do not are read a page at a time.
    let mut with_top = true;
    for _ in 0..MAX_LOG_PAGES {
        if at >= total || entries.len() >= MAX_LOG_ENTRIES {
            break;
        }
        let want = MAX_LOG_ENTRIES - entries.len();
        let page = match with_top {
            true => match client.get(&format!("{path}?$skip={at}&$top={want}")).await {
                Ok(page) => page,
                Err(_) => {
                    with_top = false;
                    client.get(&format!("{path}?$skip={at}")).await.ok()?
                }
            },
            false => client.get(&format!("{path}?$skip={at}")).await.ok()?,
        };
        let got = members(&page);
        if got.is_empty() {
            break;
        }
        // A service that ignores `$skip` answers with the same first page;
        // reading on would only collect it again.
        let repeats = match (entries.last().and_then(|e| e.id.as_ref()), got.first().and_then(|e| e.id.as_ref())) {
            (Some(last), Some(first)) => last == first,
            _ => false,
        };
        if repeats {
            return None;
        }
        at += got.len();
        entries.extend(got);
    }
    Some((entries, at < total))
}

/// `Created` as seconds and nanoseconds since the epoch, when it reads as ISO
/// 8601: what orders entries across time-zone offsets and fractional-second
/// precision, which comparing the text does not.
fn instant(created: Option<&str>) -> Option<(i64, u32)> {
    let text = created?;
    let bytes = text.as_bytes();
    if bytes.len() < 19
        || bytes[4] != b'-'
        || bytes[7] != b'-'
        || !matches!(bytes[10], b'T' | b't' | b' ')
        || bytes[13] != b':'
        || bytes[16] != b':'
    {
        return None;
    }
    let num = |range: std::ops::Range<usize>| text.get(range)?.parse::<i64>().ok();
    let (year, month, day) = (num(0..4)?, num(5..7)?, num(8..10)?);
    let (hour, minute, second) = (num(11..13)?, num(14..16)?, num(17..19)?);
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) || hour > 23 || minute > 59 || second > 60 {
        return None;
    }

    let mut rest = &text[19..];
    let mut nanos = 0u32;
    if let Some(after) = rest.strip_prefix('.') {
        let digits = after.bytes().take_while(u8::is_ascii_digit).count();
        if digits == 0 {
            return None;
        }
        nanos = format!("{:0<9}", &after[..digits.min(9)])[..9].parse().ok()?;
        rest = &after[digits..];
    }
    let offset = match rest {
        "Z" | "z" | "" => 0,
        _ if rest.len() == 6 && (rest.starts_with('+') || rest.starts_with('-')) => {
            let (h, m) = (rest[1..3].parse::<i64>().ok()?, rest[4..6].parse::<i64>().ok()?);
            let seconds = h * 3600 + m * 60;
            if rest.starts_with('-') { -seconds } else { seconds }
        }
        _ => return None,
    };
    let days = days_from_civil(year, month, day);
    Some((days * 86_400 + hour * 3600 + minute * 60 + second - offset, nanos))
}

/// Days since 1970-01-01 of a proleptic Gregorian date (Hinnant's algorithm).
fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let yoe = year - era * 400;
    let mp = (month + 9) % 12;
    let doy = (153 * mp + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn members(page: &Value) -> Vec<LogEntry> {
    page.get("Members")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter(|m| m.is_object())
        .map(LogEntry::from_json)
        .collect()
}

fn next_link(page: &Value) -> Option<String> {
    page.get("Members@odata.nextLink").and_then(Value::as_str).map(str::to_string)
}

/// Empties `service`. Nothing is sent to a log that offers no `ClearLog`.
pub async fn clear_log<T: Transport>(client: &T, service: &LogService) -> Result<Outcome, Error> {
    let target = service
        .clear_target
        .as_deref()
        .ok_or_else(|| Error::with(Failure::NotSupported, "log cannot be cleared"))?;
    client.post(target, json!({})).await
}
