//! Logs (`LogService`): the system's event log (SEL), the BMC's own logs.
//!
//! Which logs exist and what they are called is per vendor — OpenBMC has
//! `EventLog` under the system and `Journal` under the manager, iDRAC `Sel`
//! and `Lclog` under the manager, iLO `IML` under the system and `IEL` under
//! the manager — so they are listed, never named.

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::model::{Topology, collection_members, odata_id};
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
        let listing = match client.get(&collection).await {
            Ok(listing) => listing,
            Err(e) => {
                failure = Some(e);
                continue;
            }
        };
        read_any = true;
        for path in collection_members(&listing) {
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
/// it. One that lists oldest first and pages past [`MAX_LOG_PAGES`] is read
/// from its tail by `$skip`, or the newest would be the pages left unread.
/// Only the first page failing fails the read; a later one ends it with what
/// was read, said to be cut.
pub async fn log_entries<T: Transport>(client: &T, service: &LogService) -> Result<LogPage, Error> {
    let first_path = service
        .entries
        .as_deref()
        .ok_or_else(|| Error::with(Failure::NotSupported, "log has no entries"))?;
    let first = client.get(first_path).await?;
    let total = first.get("Members@odata.count").and_then(Value::as_u64);
    let head = members(&first);

    let tail = match tail_path(first_path, &head, next_link(&first).is_some(), total) {
        Some(tail) => client.get(&tail).await.ok().filter(|page| !members(page).is_empty()),
        None => None,
    };
    let read = match tail {
        Some(page) => follow(client, members(&page), next_link(&page)).await,
        None => follow(client, head, next_link(&first)).await,
    };

    let (mut entries, unread) = read;
    let count = entries.len();
    let unread = unread || total.is_some_and(|t| t as usize > count);
    // Stable: entries with no timestamp keep the service's order among them.
    entries.sort_by(|a, b| b.created.cmp(&a.created));
    entries.truncate(MAX_LOG_ENTRIES);
    Ok(LogPage {
        truncated: unread || entries.len() < count,
        entries,
        total,
    })
}

/// Where the newest [`MAX_LOG_ENTRIES`] of an oldest-first log start, when
/// reading from the start would stop at [`MAX_LOG_PAGES`] before them.
fn tail_path(first_path: &str, head: &[LogEntry], paged: bool, total: Option<u64>) -> Option<String> {
    let total = total? as usize;
    let oldest_first = match (head.first(), head.last()) {
        (Some(a), Some(b)) => a.created.is_some() && b.created.is_some() && a.created < b.created,
        _ => false,
    };
    let skip = total.saturating_sub(MAX_LOG_ENTRIES);
    (paged && oldest_first && !first_path.contains('?') && skip > 0 && total > head.len() * MAX_LOG_PAGES)
        .then(|| format!("{first_path}?$skip={skip}"))
}

/// Follows `next` from a page already read, up to [`MAX_LOG_PAGES`] in all;
/// whether pages were left unread.
async fn follow<T: Transport>(client: &T, mut entries: Vec<LogEntry>, mut next: Option<String>) -> (Vec<LogEntry>, bool) {
    let mut pages = 1;
    while let Some(path) = next.take() {
        if pages == MAX_LOG_PAGES {
            return (entries, true);
        }
        let Ok(page) = client.get(&path).await else {
            return (entries, true);
        };
        pages += 1;
        entries.extend(members(&page));
        next = next_link(&page);
    }
    (entries, false)
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
