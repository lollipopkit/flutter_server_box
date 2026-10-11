//! What the Storage app keeps doing while nobody looks (Linux):
//!
//! - **The maintenance schedule** (`storage_maintenance`, migration 028):
//!   pools scrubbed and md arrays checked, SMART self-tests, weekly or
//!   monthly. Run without a password (`storage::UNATTENDED`): as root, or
//!   through a sudoers rule; a run sudo refuses records `sudoNeedsPassword`.
//! - **The watch**: every few minutes the arrays (`/proc/mdstat`) and pools
//!   (`zpool list`), and hourly every disk's SMART (unattended, or the last
//!   reading the panel made with a password). One that turns bad is said on
//!   the desk (`Source::Storage`) and through the push channels; one that is
//!   back, on the desk.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::{Duration, Instant};

use sbm_parser::storage::{self as st, DiskHealth, Maintenance};
use serde::{Deserialize, Serialize};

use crate::api::desk::{Level, Source};
use crate::api::server::AppState;
use crate::stacks::Refusal;

const WATCH_EVERY: Duration = Duration::from_secs(300);
const SMART_EVERY: Duration = Duration::from_secs(3600);

fn refusal(status: u16, error: &'static str) -> Refusal {
    Refusal { status, error, field: None }
}

// -----------------------------------------------------------------------------
// The schedule
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Task {
    /// `scrub`, `smartShort`, `smartLong` (`storage::Maintenance`).
    pub task: String,
    /// `weekly` | `monthly`.
    pub every: String,
    /// `HH:MM`, the machine's time.
    pub at: String,
    /// Weekly: 0 Monday … 6 Sunday. Monthly: 1 … 28.
    pub day: u8,
    pub last_run: Option<String>,
    pub last_error: Option<String>,
}

pub async fn tasks(db: &sqlx::SqlitePool) -> Vec<Task> {
    type Row = (String, String, String, i64, Option<String>, Option<String>);
    let rows: Vec<Row> = sqlx::query_as("SELECT task, every, at, day, last_run, last_error FROM storage_maintenance ORDER BY task")
        .fetch_all(db)
        .await
        .unwrap_or_default();
    rows.into_iter()
        .map(|(task, every, at, day, last_run, last_error)| Task { task, every, at, day: day.clamp(0, 28) as u8, last_run, last_error })
        .collect()
}

#[derive(Debug, Clone, Deserialize)]
pub struct SetTask {
    pub task: String,
    /// `weekly` | `monthly`; none turns it off.
    pub every: Option<String>,
    #[serde(default)]
    pub at: String,
    #[serde(default)]
    pub day: u8,
}

pub async fn set_task(state: &AppState, username: &str, next: SetTask) -> Result<Vec<Task>, Refusal> {
    if Maintenance::from_name(&next.task).is_none() {
        return Err(refusal(400, "invalidTask"));
    }
    let db_error = |e: sqlx::Error| {
        tracing::error!("storage maintenance: {e}");
        refusal(500, "internal")
    };
    match next.every.as_deref() {
        None => {
            sqlx::query("DELETE FROM storage_maintenance WHERE task = ?").bind(&next.task).execute(&state.db).await.map_err(db_error)?;
        }
        Some(every) => {
            let day_ok = match every {
                "weekly" => next.day <= 6,
                "monthly" => (1..=28).contains(&next.day),
                _ => false,
            };
            if !day_ok || !crate::container_backups::time_ok(&next.at) {
                return Err(refusal(400, "invalidSchedule"));
            }
            sqlx::query(
                "INSERT INTO storage_maintenance (task, every, at, day, updated_by, updated_at) VALUES (?, ?, ?, ?, ?, ?) \
                 ON CONFLICT(task) DO UPDATE SET every = excluded.every, at = excluded.at, day = excluded.day, \
                 updated_by = excluded.updated_by, updated_at = excluded.updated_at",
            )
            .bind(&next.task)
            .bind(every)
            .bind(&next.at)
            .bind(i64::from(next.day))
            .bind(username)
            .bind(chrono::Utc::now().to_rfc3339())
            .execute(&state.db)
            .await
            .map_err(db_error)?;
        }
    }
    Ok(tasks(&state.db).await)
}

/// The slot [t] last fell due at, before or at [now] (local).
fn due_since(t: &Task, now: chrono::DateTime<chrono::Local>) -> Option<chrono::DateTime<chrono::Local>> {
    use chrono::{Datelike, Duration as D, NaiveTime, TimeZone};
    let time = NaiveTime::parse_from_str(&t.at, "%H:%M").ok()?;
    let mut day = now.date_naive();
    for _ in 0..32 {
        let on = match t.every.as_str() {
            "weekly" => day.weekday().num_days_from_monday() == u32::from(t.day),
            _ => day.day() == u32::from(t.day),
        };
        if on
            && let Some(at) = chrono::Local.from_local_datetime(&day.and_time(time)).earliest()
            && at <= now
        {
            return Some(at);
        }
        day -= D::days(1);
    }
    None
}

/// Runs [task] now, unattended, and records how it went.
pub async fn run_task(state: &Arc<AppState>, task: Maintenance) -> Result<(), String> {
    let result = run_unattended(state, task).await;
    let _ = sqlx::query("UPDATE storage_maintenance SET last_run = ?, last_error = ? WHERE task = ?")
        .bind(chrono::Local::now().to_rfc3339())
        .bind(result.as_ref().err())
        .bind(task.name())
        .execute(&state.db)
        .await;
    if let Err(e) = &result {
        tracing::warn!("storage maintenance {}: {e}", task.name());
        notify(
            state,
            Level::Warning,
            &format!("maintenance:{}", task.name()),
            &format!("Storage maintenance did not run: {}", task.name()),
            e,
            "storage.maintenanceFailed",
            serde_json::json!({ "task": task.name(), "error": e }),
            true,
        )
        .await;
    }
    result
}

async fn run_unattended(state: &Arc<AppState>, task: Maintenance) -> Result<(), String> {
    let disks: Vec<String> = match task {
        Maintenance::Scrub => Vec::new(),
        Maintenance::SmartShort | Maintenance::SmartLong => {
            let reading = read_health(state).await?;
            reading.iter().filter(|d| d.supported && d.testing.is_none()).map(|d| d.device.clone()).collect()
        }
    };
    if task != Maintenance::Scrub && disks.is_empty() {
        return Ok(());
    }
    let script = task.script(&disks).map_err(|e| e.code().to_string())?;
    let out = run(state, &script).await?;
    if out.exit_code == Some(0) {
        return Ok(());
    }
    Err(failure(&out.stderr))
}

/// What a failed unattended run says: sudo wanting a password, or its last
/// line.
fn failure(stderr: &str) -> String {
    if sbm_parser::script::sudo_password_rejected(stderr) {
        return "sudoNeedsPassword".into();
    }
    let line = stderr.lines().rev().find(|l| !l.trim().is_empty()).unwrap_or("failed").trim();
    line.chars().take(200).collect()
}

async fn run(state: &AppState, script: &str) -> Result<crate::api::exec::ExecResponse, String> {
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 16 << 20);
    match crate::api::exec::run(script, None, None, &limits).await {
        Ok(out) if out.timed_out => Err("timedOut".into()),
        Ok(out) => Ok(out),
        Err(e) => Err(e.to_string()),
    }
}

/// Every disk's SMART, unattended, kept for the page as a reading made from
/// it would be.
async fn read_health(state: &AppState) -> Result<Vec<DiskHealth>, String> {
    let out = run(state, st::HEALTH_COMMAND).await?;
    if sbm_parser::script::sudo_password_rejected(&out.stderr) {
        return Err("sudoNeedsPassword".into());
    }
    Ok(state.storage.keep_health(st::parse_health(&out.stdout)).disks)
}

async fn run_due(state: &Arc<AppState>) {
    let now = chrono::Local::now();
    for t in tasks(&state.db).await {
        let Some(task) = Maintenance::from_name(&t.task) else { continue };
        let Some(slot) = due_since(&t, now) else { continue };
        let ran = t.last_run.as_deref().and_then(|r| chrono::DateTime::parse_from_rfc3339(r).ok());
        if ran.is_some_and(|r| r >= slot) {
            continue;
        }
        let _ = run_task(state, task).await;
    }
}

// -----------------------------------------------------------------------------
// The watch
// -----------------------------------------------------------------------------

/// What the watch saw last: what was bad, each disk's bad sectors, when SMART
/// was read.
#[derive(Default)]
pub struct Seen {
    bad: HashSet<String>,
    sectors: HashMap<String, i64>,
    smart_read: Option<Instant>,
    /// The panel's reading last looked at (`HealthReading::at`).
    reading_at: u64,
}

/// One look at what can go bad, as `(key, bad, subject, body, kind, params)`
/// for each array and pool.
fn arrays_and_pools(arrays: &[st::MdArray], pools: &[st::Pool]) -> Vec<(String, bool, serde_json::Value)> {
    let mut out = Vec::new();
    for a in arrays.iter().filter(|a| a.state.starts_with("active")) {
        let bad = a.degraded() || a.members.iter().any(|m| m.faulty);
        out.push((format!("md:{}", a.name), bad, serde_json::json!({ "array": a.name })));
    }
    for p in pools {
        out.push((format!("pool:{}", p.name), p.health != "ONLINE", serde_json::json!({ "pool": p.name, "health": p.health })));
    }
    out
}

/// What changed for the disks since [seen]: `(key, kind, params)` to say.
fn disk_changes(seen: &mut Seen, disks: &[DiskHealth]) -> Vec<(String, &'static str, serde_json::Value)> {
    let mut out = Vec::new();
    for d in disks.iter().filter(|d| d.supported) {
        let key = format!("disk:{}", d.device);
        let failing = d.passed == Some(false) || d.last_test.as_ref().is_some_and(|t| t.outcome == "failed");
        if failing && seen.bad.insert(key.clone()) {
            out.push((key.clone(), "storage.diskFailing", serde_json::json!({ "device": d.device })));
        } else if !failing {
            seen.bad.remove(&key);
        }
        if let Some(now) = d.bad_sectors {
            let was = seen.sectors.insert(d.device.clone(), now);
            if now > was.unwrap_or(0) {
                out.push((format!("sectors:{}", d.device), "storage.diskSectors", serde_json::json!({ "device": d.device, "count": now, "was": was.unwrap_or(0) })));
            }
        }
    }
    out
}

pub async fn check(state: &Arc<AppState>) {
    let (arrays, pools) = crate::api::storage::arrays_and_pools(state).await;
    let looked = arrays_and_pools(&arrays, &pools);
    let changes: Vec<(String, bool, serde_json::Value)> = {
        let mut seen = state.storage.seen();
        looked
            .into_iter()
            .filter(|(key, bad, _)| if *bad { seen.bad.insert(key.clone()) } else { seen.bad.remove(key) })
            .collect()
    };
    for (key, bad, params) in changes {
        let (kind, level, subject, body) = match (key.starts_with("md:"), bad) {
            (true, true) => ("storage.arrayDegraded", Level::Critical, format!("/dev/{} is degraded", params["array"].as_str().unwrap_or("")), "A member failed or is missing; the array runs without its redundancy.".to_string()),
            (true, false) => ("storage.arrayBack", Level::Info, format!("/dev/{} is healthy again", params["array"].as_str().unwrap_or("")), "Every member is working.".to_string()),
            (false, true) => ("storage.poolUnhealthy", Level::Critical, format!("Pool {} is {}", params["pool"].as_str().unwrap_or(""), params["health"].as_str().unwrap_or("")), "Open Storage to see which device.".to_string()),
            (false, false) => ("storage.poolBack", Level::Info, format!("Pool {} is online again", params["pool"].as_str().unwrap_or("")), "Every device is working.".to_string()),
        };
        notify(state, level, &key, &subject, &body, kind, params, bad).await;
    }

    // SMART: read hourly where sudo lets it; else the panel's last reading,
    // once.
    let due = state.storage.seen().smart_read.is_none_or(|t| t.elapsed() >= SMART_EVERY);
    let disks = if due {
        state.storage.seen().smart_read = Some(Instant::now());
        read_health(state).await.ok()
    } else {
        None
    };
    let disks = disks.or_else(|| {
        let reading = state.storage.health()?;
        let mut seen = state.storage.seen();
        (reading.at > seen.reading_at).then(|| {
            seen.reading_at = reading.at;
            reading.disks
        })
    });
    let Some(disks) = disks else { return };
    let said = disk_changes(&mut state.storage.seen(), &disks);
    for (key, kind, params) in said {
        let device = params["device"].as_str().unwrap_or("").to_string();
        let (level, subject, body) = if kind == "storage.diskFailing" {
            (Level::Critical, format!("{device} is failing"), "Its SMART check or self-test failed: copy what it holds elsewhere and replace it.".to_string())
        } else {
            (Level::Warning, format!("{device} has {} bad sectors", params["count"]), format!("It had {}. A disk losing sectors often fails soon.", params["was"]))
        };
        notify(state, level, &key, &subject, &body, kind, params, true).await;
    }
}

/// Said on the desk, and when [push], through the push channels.
#[allow(clippy::too_many_arguments)]
async fn notify(state: &AppState, level: Level, key: &str, subject: &str, body: &str, kind: &str, params: serde_json::Value, push: bool) {
    if let Err(e) = state.desk.notify(&state.db, level, Source::Storage(key.to_string()), subject, body, Some((kind, &params))).await {
        tracing::error!("storage {key}: notifying: {e}");
    }
    if push {
        crate::monitoring::push::push_all(&state.config, &format!("{subject}: {body}")).await;
    }
}

/// The schedule and the watch, until the agent stops.
pub async fn start(state: Arc<AppState>) {
    if !cfg!(target_os = "linux") {
        return;
    }
    tokio::time::sleep(Duration::from_secs(60)).await;
    let mut tick = tokio::time::interval(Duration::from_secs(60));
    let mut watched: Option<Instant> = None;
    loop {
        tick.tick().await;
        run_due(&state).await;
        if watched.is_none_or(|w| w.elapsed() >= WATCH_EVERY) {
            watched = Some(Instant::now());
            check(&state).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn task(every: &str, day: u8) -> Task {
        Task { task: "scrub".into(), every: every.into(), at: "03:00".into(), day, last_run: None, last_error: None }
    }

    #[test]
    fn a_task_falls_due_on_its_day() {
        // Wednesday 2026-10-14 10:00.
        let now = chrono::Local.with_ymd_and_hms(2026, 10, 14, 10, 0, 0).unwrap();
        let at = |y, m, d| chrono::Local.with_ymd_and_hms(y, m, d, 3, 0, 0).unwrap();
        assert_eq!(due_since(&task("weekly", 6), now), Some(at(2026, 10, 11)), "the Sunday before");
        assert_eq!(due_since(&task("weekly", 2), now), Some(at(2026, 10, 14)), "today, past 03:00");
        assert_eq!(due_since(&task("monthly", 1), now), Some(at(2026, 10, 1)));
        assert_eq!(due_since(&task("monthly", 20), now), Some(at(2026, 9, 20)), "last month's");
    }

    fn disk(device: &str, passed: bool, bad_sectors: i64) -> DiskHealth {
        DiskHealth { device: device.into(), supported: true, asleep: false, passed: Some(passed), temperature: None, power_on_hours: None, bad_sectors: Some(bad_sectors), testing: None, last_test: None, attributes: vec![], tests: vec![] }
    }

    #[test]
    fn a_disk_is_said_once_when_it_turns_bad_and_when_it_loses_more() {
        let mut seen = Seen::default();
        assert!(disk_changes(&mut seen, &[disk("/dev/sda", true, 0)]).is_empty());
        let said = disk_changes(&mut seen, &[disk("/dev/sda", false, 8)]);
        assert_eq!(said.iter().map(|(_, k, _)| *k).collect::<Vec<_>>(), ["storage.diskFailing", "storage.diskSectors"]);
        assert!(disk_changes(&mut seen, &[disk("/dev/sda", false, 8)]).is_empty(), "nothing new");
        let said = disk_changes(&mut seen, &[disk("/dev/sda", false, 12)]);
        assert_eq!(said[0].2["was"], 8);
        assert!(disk_changes(&mut seen, &[DiskHealth { supported: false, ..disk("/dev/sdb", false, 0) }]).is_empty(), "no SMART, nothing said");
    }

    #[test]
    fn arrays_and_pools_are_judged() {
        let arrays = st::parse_mdstat("Personalities : [raid1]\nmd0 : active raid1 sdc[1] sdb[0](F)\n      100 blocks [2/1] [U_]\n\nunused devices: <none>\n");
        let pools = st::parse_zpool_list("tank\t100\t10\t90\tDEGRADED\n");
        let looked = arrays_and_pools(&arrays, &pools);
        assert_eq!(looked.iter().map(|(k, bad, _)| (k.as_str(), *bad)).collect::<Vec<_>>(), [("md:md0", true), ("pool:tank", true)]);
    }
}
