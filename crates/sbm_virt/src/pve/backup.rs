//! PVE's backups and backup jobs as [`crate::backup`] has them, and the
//! requests a job's edit and its "Run now" send. Ported from the app's
//! `PveResources` (`parseBackups`, `parseBackupJobs`, `pruneString`,
//! `vzdumpOfJob`) and `PveBackend.editBackupJob`.

use serde_json::{Map, Value};

use super::resources::{int, str_of, uint};
use crate::backup::{Backup, BackupJob, BackupJobEdit};
use crate::model::GuestKind;

fn text(v: Option<&Value>) -> Option<String> {
    str_of(v).filter(|s| !s.is_empty())
}

/// `GET /nodes/{node}/storage/{storage}/content?content=backup`: the
/// backups on `storage`, newest first. `verification` is an object where a
/// verify job has looked at one.
pub fn parse_backups(node: &str, storage: &str, raw: &[Value]) -> Vec<Backup> {
    let mut out: Vec<Backup> = raw
        .iter()
        .filter_map(Value::as_object)
        .filter(|e| text(e.get("content")).as_deref().unwrap_or("backup") == "backup")
        .filter_map(|e| {
            Some(Backup {
                id: text(e.get("volid"))?,
                storage: storage.to_owned(),
                node: node.to_owned(),
                vmid: uint(e.get("vmid")).and_then(|v| u32::try_from(v).ok()),
                created_at: int(e.get("ctime")),
                size: uint(e.get("size")).filter(|s| *s > 0),
                format: text(e.get("format")),
                notes: text(e.get("notes")),
                protected: int(e.get("protected")) == Some(1),
                verification: e.get("verification").and_then(|v| text(v.get("state"))),
                kind: match text(e.get("subtype")).as_deref() {
                    Some("qemu") => Some(GuestKind::Qemu),
                    Some("lxc") => Some(GuestKind::Lxc),
                    _ => None,
                },
            })
        })
        .collect();
    out.sort_by_key(|b| std::cmp::Reverse(b.created_at.unwrap_or(0)));
    out
}

/// PVE's `prune-backups` as one property string: an object
/// (`{keep-last: "7"}`) or the string it is stored as.
pub fn prune_string(raw: Option<&Value>) -> Option<String> {
    match raw? {
        Value::Object(m) if !m.is_empty() => Some(property_string(m)),
        Value::String(s) if !s.is_empty() => Some(s.clone()),
        _ => None,
    }
}

fn property_string(m: &Map<String, Value>) -> String {
    m.iter().map(|(k, v)| format!("{k}={}", scalar(v))).collect::<Vec<_>>().join(",")
}

fn scalar(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}

/// A comma-separated list of VMIDs, as PVE stores `vmid` and `exclude`.
/// None and an empty string are both "none", `all` names no single guest,
/// and anything that is not a number is skipped.
fn int_list(raw: Option<&Value>) -> Vec<u32> {
    match raw {
        Some(Value::Array(l)) => l.iter().filter_map(|v| uint(Some(v)).and_then(|n| u32::try_from(n).ok())).collect(),
        Some(v) => match text(Some(v)) {
            Some(t) if t != "all" => t.split(',').filter_map(|p| p.trim().parse().ok()).collect(),
            _ => Vec::new(),
        },
        None => Vec::new(),
    }
}

/// `GET /cluster/backup`: the `vzdump` jobs.
pub fn parse_backup_jobs(raw: &[Value]) -> Vec<BackupJob> {
    raw.iter()
        .filter_map(Value::as_object)
        .filter(|e| text(e.get("type")).as_deref().unwrap_or("vzdump") == "vzdump")
        .filter_map(|e| {
            Some(BackupJob {
                id: text(e.get("id"))?,
                schedule: text(e.get("schedule")).or_else(|| text(e.get("starttime"))),
                storage: text(e.get("storage")),
                mode: text(e.get("mode")),
                compress: text(e.get("compress")),
                enabled: int(e.get("enabled")) != Some(0),
                all: int(e.get("all")) == Some(1),
                vmids: int_list(e.get("vmid")),
                exclude: int_list(e.get("exclude")),
                pool: text(e.get("pool")),
                node: text(e.get("node")),
                comment: text(e.get("comment")),
                notes_template: text(e.get("notes-template")),
                mail_notification: text(e.get("mailnotification")),
                prune: prune_string(e.get("prune-backups")),
            })
        })
        .collect()
}

/// The fields that describe a job's schedule rather than what it backs up.
const SCHEDULE_KEYS: [&str; 10] = ["enabled", "starttime", "dow", "id", "schedule", "type", "node", "comment", "next-run", "repeat-missed"];

/// The `vzdump` request a job's "Run now" sends, from the job as
/// `GET /cluster/backup/{id}` has it: what PVE's own web UI sends
/// (`run_backup_now`, pve-manager 9.2) — every field but the ones that
/// describe the schedule, `all` as `1`/`0`, and the fields PVE answers as
/// objects (`performance`, `prune-backups`, `fleecing`) as the property
/// strings `vzdump` takes.
pub fn vzdump_of_job(job: &Map<String, Value>) -> Vec<(String, String)> {
    job.iter()
        .filter(|(k, v)| !SCHEDULE_KEYS.contains(&k.as_str()) && !v.is_null())
        .map(|(k, v)| {
            let value = match v {
                _ if k == "all" => {
                    let on = matches!(v, Value::Bool(true)) || int(Some(v)) == Some(1);
                    (if on { "1" } else { "0" }).to_owned()
                }
                Value::Object(m) => property_string(m),
                other => scalar(other),
            };
            (k.clone(), value)
        })
        .collect()
}

/// Which guests a job takes, as `vzdump` and `/cluster/backup` name them: a
/// pool, all of them (less `exclude`), or a list — one of the three, the
/// pool first.
fn job_guests(edit: &BackupJobEdit) -> Vec<(&'static str, String)> {
    let join = |l: &[u32]| l.iter().map(u32::to_string).collect::<Vec<_>>().join(",");
    match &edit.pool {
        Some(pool) => vec![("pool", pool.clone())],
        None if edit.all => {
            let mut v = vec![("all", "1".to_owned())];
            if !edit.exclude.is_empty() {
                v.push(("exclude", join(&edit.exclude)));
            }
            v
        }
        None if !edit.vmids.is_empty() => vec![("vmid", join(&edit.vmids))],
        None => Vec::new(),
    }
}

/// The form a job's `POST` (new) or `PUT` sends. PVE's own `PUT` keeps what
/// it is not sent, so a field this edit does not set is named in `delete` —
/// what its web UI's `deleteEmpty` does per field; a create takes none.
pub fn job_fields(edit: &BackupJobEdit) -> Vec<(&'static str, String)> {
    let which = job_guests(edit);
    let mut f = vec![
        ("storage", edit.storage.clone()),
        ("schedule", edit.schedule.clone()),
        ("mode", edit.mode.clone()),
        ("compress", edit.compress.clone()),
        ("enabled", (if edit.enabled { "1" } else { "0" }).to_owned()),
    ];
    // Cleared unless `which` takes all guests, which sets it to 1.
    if !which.iter().any(|(k, _)| *k == "all") {
        f.push(("all", "0".to_owned()));
    }
    let mut deletes: Vec<&str> = ["vmid", "exclude", "pool"].into_iter().filter(|k| !which.iter().any(|(w, _)| w == k)).collect();
    f.extend(which);
    for (key, value) in [
        ("node", &edit.node),
        ("comment", &edit.comment),
        ("notes-template", &edit.notes_template),
        ("mailnotification", &edit.mail_notification),
        ("prune-backups", &edit.prune),
    ] {
        match value {
            Some(v) => f.push((key, v.clone())),
            // A notification setting not sent is kept, as before.
            None if key != "mailnotification" => deletes.push(key),
            None => {}
        }
    }
    if edit.is_new {
        if let Some(id) = &edit.id {
            f.insert(0, ("id", id.clone()));
        }
    } else if !deletes.is_empty() {
        f.push(("delete", deletes.join(",")));
    }
    f
}
