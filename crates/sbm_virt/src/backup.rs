//! Backups and backup jobs (PVE `vzdump`): what a backup and a scheduled job
//! are, a backup to take now, the edit of a job or of one backup's own
//! fields, and the rules a schedule is checked by before the host is asked
//! ([`schedule_issue`]). libvirt keeps no backups of its own.
//!
//! PVE's calls are [`crate::pve::client::Client`]'s (`backups`,
//! `backup_jobs`, `edit_backup_job`, `backup`, `run_backup_job`,
//! `restore_backup`, …); its answers are read in [`crate::pve::backup`].
//! Ported from the app's `lib/data/model/virt/virt_backup.dart` and
//! `virt_backup_schedule.dart`.

use serde::{Deserialize, Serialize};

use crate::error::{Detail, Error, ErrorKind};
use crate::model::GuestKind;

fn yes() -> bool {
    true
}

/// One backup of a guest, as a backup storage lists it.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Backup {
    /// PVE's volid: `local:backup/vzdump-qemu-100-2026_09_24-02_00_00.vma.zst`.
    pub id: String,
    /// The storage it is on, and the node that lists it.
    pub storage: String,
    pub node: String,
    #[serde(default)]
    pub vmid: Option<u32>,
    /// Unix seconds.
    #[serde(default)]
    pub created_at: Option<i64>,
    /// Bytes.
    #[serde(default)]
    pub size: Option<u64>,
    /// `vma.zst`, `tar.zst`, … — what PVE calls the archive's format.
    #[serde(default)]
    pub format: Option<String>,
    #[serde(default)]
    pub notes: Option<String>,
    /// Kept from pruning and deletion until unprotected.
    #[serde(default)]
    pub protected: bool,
    /// `ok` or `failed`, where a verification job has run on it.
    #[serde(default)]
    pub verification: Option<String>,
    #[serde(default)]
    pub kind: Option<GuestKind>,
}

/// A scheduled backup job (`/cluster/backup`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackupJob {
    pub id: String,
    /// PVE's calendar event: `02:00`, `sat 03:00`, `daily`.
    #[serde(default)]
    pub schedule: Option<String>,
    #[serde(default)]
    pub storage: Option<String>,
    /// `snapshot`, `suspend` or `stop`.
    #[serde(default)]
    pub mode: Option<String>,
    /// `zstd`, `lzo`, `gzip`, or none.
    #[serde(default)]
    pub compress: Option<String>,
    #[serde(default = "yes")]
    pub enabled: bool,
    /// Every guest of the job's node (less `exclude`), the VMIDs it takes,
    /// or — with `pool` — the guests of that pool. Exclusive.
    #[serde(default)]
    pub all: bool,
    #[serde(default)]
    pub vmids: Vec<u32>,
    #[serde(default)]
    pub exclude: Vec<u32>,
    #[serde(default)]
    pub pool: Option<String>,
    /// The node it runs on; None: every node.
    #[serde(default)]
    pub node: Option<String>,
    #[serde(default)]
    pub comment: Option<String>,
    /// The notes every backup it makes carries (`notes-template`).
    #[serde(default)]
    pub notes_template: Option<String>,
    /// `always` or `failure` (PVE's `mailnotification`).
    #[serde(default)]
    pub mail_notification: Option<String>,
    /// The retention, as PVE's `prune-backups` property string:
    /// `keep-last=7,keep-daily=4`.
    #[serde(default)]
    pub prune: Option<String>,
}

impl BackupJob {
    /// Whether this job takes `vmid`, a guest on `node`. A job restricted
    /// to a node backs up only the guests there; which guests a pool holds
    /// is not in the listing, so a job by pool claims none.
    pub fn takes(&self, vmid: Option<u32>, node: Option<&str>) -> bool {
        let Some(vmid) = vmid else { return false };
        if let (Some(mine), Some(theirs)) = (self.node.as_deref(), node)
            && mine != theirs
        {
            return false;
        }
        if self.pool.is_some() {
            return false;
        }
        if self.all { !self.exclude.contains(&vmid) } else { self.vmids.contains(&vmid) }
    }

    /// Whether this job takes `vmid` and no other guest: the guest's own
    /// plan, which its Plan group edits.
    pub fn takes_only(&self, vmid: Option<u32>) -> bool {
        vmid.is_some_and(|v| !self.all && self.pool.is_none() && self.exclude.is_empty() && self.vmids == [v])
    }
}

/// A job made (`POST /cluster/backup`) or edited (`PUT`), in PVE's own
/// field names. `is_new` makes one: a new job may be named too, so the flag
/// is not `id == None`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackupJobEdit {
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default)]
    pub is_new: bool,
    #[serde(default)]
    pub node: Option<String>,
    pub storage: String,
    /// systemd calendar format, as PVE's `pve-calendar-event` takes it.
    pub schedule: String,
    #[serde(default = "snapshot")]
    pub mode: String,
    #[serde(default = "zstd")]
    pub compress: String,
    #[serde(default = "yes")]
    pub enabled: bool,
    #[serde(default)]
    pub all: bool,
    #[serde(default)]
    pub vmids: Vec<u32>,
    #[serde(default)]
    pub exclude: Vec<u32>,
    #[serde(default)]
    pub pool: Option<String>,
    #[serde(default)]
    pub comment: Option<String>,
    #[serde(default)]
    pub notes_template: Option<String>,
    #[serde(default)]
    pub mail_notification: Option<String>,
    #[serde(default)]
    pub prune: Option<String>,
}

fn snapshot() -> String {
    "snapshot".to_owned()
}

fn zstd() -> String {
    "zstd".to_owned()
}

/// A backup to take now.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackupRequest {
    /// A storage that holds backups, by name.
    pub storage: String,
    /// `snapshot` (a running guest keeps running), `suspend` or `stop`.
    #[serde(default = "snapshot")]
    pub mode: String,
    /// `zstd`, `lzo`, `gzip` or `0` for none.
    #[serde(default = "zstd")]
    pub compress: String,
    #[serde(default)]
    pub notes: Option<String>,
    #[serde(default)]
    pub protected: bool,
    /// Retention, PVE's `prune-backups` property string; None for the
    /// storage's or the node's own.
    #[serde(default)]
    pub prune: Option<String>,
}

/// What an existing backup's own fields can be changed to.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BackupEdit {
    pub notes: String,
    pub protected: bool,
}

/// What the host makes of a schedule: its refusal in its own words, or the
/// next few times it would run (Unix seconds, oldest first).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScheduleCheck {
    #[serde(default)]
    pub error: Option<String>,
    #[serde(default)]
    pub next: Vec<i64>,
}

/// Why a backup request cannot be sent. The first that applies wins.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Issue {
    ScheduleEmpty,
    /// Not a calendar event PVE takes.
    ScheduleInvalid,
    /// Not a storage of the node that holds backups.
    Storage,
    /// `snapshot`, `suspend` or `stop`; a compression PVE knows.
    Mode,
    Compress,
    /// A job's guests: a pool, all of them, or a list — and a list names
    /// some.
    Guests,
    /// The job's node is not online, or none is.
    NodeOffline,
    /// A restore over the guest itself: only while it is stopped.
    NotStopped,
    /// Not (or no longer) on the host.
    NotFound,
    /// libvirt keeps no backups.
    Unsupported,
}

/// `issue` as the error a client answers a refused request with.
pub fn refusal(issue: Issue) -> Error {
    Error::detail(ErrorKind::Unsupported, Detail::BackupRefused { issue })
}

/// The shorthands systemd and PVE both take as a whole schedule.
pub const SCHEDULE_SHORTHANDS: [&str; 9] =
    ["minutely", "hourly", "daily", "weekly", "monthly", "quarterly", "semiannually", "yearly", "annually"];

const DAYS: [&str; 7] = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

/// `mon`, `mon,wed`, `mon..fri`: a weekday list, or ranges of them.
fn is_day_list(s: &str) -> bool {
    s.split(',').all(|part| match part.split_once("..") {
        Some((a, b)) => DAYS.contains(&a) && DAYS.contains(&b),
        None => DAYS.contains(&part),
    })
}

/// A date part (`*-*-*`, `2026-10-01`, `*-1..7`). It always holds a `-`: a
/// bare `*` is a weekday list, and a weekday list is never `*`.
fn is_date(s: &str) -> bool {
    let Some((_, rest)) = s.split_once('-') else { return false };
    !rest.is_empty() && s.chars().all(|c| c.is_ascii_digit() || matches!(c, '*' | ',' | '.' | '/' | '-'))
}

/// A time field: `02:30`, `02:30:15`, `*:0/15`, `0/15`, `0,30`, `8..17`.
/// PVE's own bounds: each plain part at most 59 (`mon 59:59` taken, `mon
/// 60:00` and `mon 59:60` not; the hour is not range-checked further), an
/// interval's step 1..59.
fn is_time(s: &str) -> bool {
    let fields: Vec<&str> = s.split(':').collect();
    if fields.len() > 3 || fields.iter().any(|f| f.is_empty()) {
        return false;
    }
    let plain = fields.iter().all(|f| f.len() <= 3 && f.bytes().all(|b| b.is_ascii_digit()));
    if plain {
        return fields.iter().all(|f| f.parse::<u32>().is_ok_and(|n| n <= 59));
    }
    let field_ok = |f: &&str| *f == "*" || f.bytes().all(|b| b.is_ascii_digit() || matches!(b, b',' | b'/' | b'.' | b'-'));
    let bare_step = fields.len() == 1 && fields[0].strip_prefix("*/").is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()));
    if !bare_step && !fields.iter().all(field_ok) {
        return false;
    }
    // Every step a list or range carries: PVE refuses 0 and 60 and above.
    s.split('/').skip(1).all(|after| {
        let digits: String = after.chars().take_while(char::is_ascii_digit).collect();
        !digits.is_empty() && digits.parse::<u32>().is_ok_and(|n| (1..=59).contains(&n))
    })
}

/// Why `schedule` cannot be a backup job's schedule; None when it has the
/// shape of one PVE takes (`[WEEKDAY] [[YYYY-]MM-DD] [HH:MM[:SS]]`, each
/// part optional and in that order, or a shorthand). The host may still
/// refuse it; [`crate::pve::client::Client::check_schedule`] asks it.
pub fn schedule_issue(schedule: &str) -> Option<Issue> {
    let s = schedule.trim();
    if s.is_empty() {
        return Some(Issue::ScheduleEmpty);
    }
    if SCHEDULE_SHORTHANDS.contains(&s) {
        return None;
    }
    if s.contains([';', '\n', '\r']) {
        return Some(Issue::ScheduleInvalid);
    }
    let parts: Vec<&str> = s.split_whitespace().collect();
    let mut i = 0;
    if i < parts.len() && is_day_list(parts[i]) {
        i += 1;
    }
    if i < parts.len() && is_date(parts[i]) {
        i += 1;
    }
    if i < parts.len() && is_time(parts[i]) {
        i += 1;
    }
    (i != parts.len()).then_some(Issue::ScheduleInvalid)
}

const MODES: [&str; 3] = ["snapshot", "suspend", "stop"];
const COMPRESSIONS: [&str; 4] = ["0", "zstd", "lzo", "gzip"];

/// Why `edit` cannot be sent; None when it can. `storages` are the names of
/// the backup storages it may name.
pub fn job_issue(edit: &BackupJobEdit, storages: &[String]) -> Option<Issue> {
    if let Some(i) = schedule_issue(&edit.schedule) {
        return Some(i);
    }
    if !storages.contains(&edit.storage) {
        return Some(Issue::Storage);
    }
    if !MODES.contains(&edit.mode.as_str()) {
        return Some(Issue::Mode);
    }
    if !COMPRESSIONS.contains(&edit.compress.as_str()) {
        return Some(Issue::Compress);
    }
    if edit.pool.is_none() && !edit.all && edit.vmids.is_empty() {
        return Some(Issue::Guests);
    }
    None
}

/// Why `request` cannot be taken; None when it can.
pub fn request_issue(request: &BackupRequest, storages: &[String]) -> Option<Issue> {
    if !storages.contains(&request.storage) {
        return Some(Issue::Storage);
    }
    if !MODES.contains(&request.mode.as_str()) {
        return Some(Issue::Mode);
    }
    if !COMPRESSIONS.contains(&request.compress.as_str()) {
        return Some(Issue::Compress);
    }
    None
}
