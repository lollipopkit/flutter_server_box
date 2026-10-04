//! Backups and backup jobs FFI (sbm_virt::backup)
//!
//! The rules a schedule and a job are checked by. A job crosses as its
//! `sbm_virt` JSON; PVE's calls are [`super::pve::PveSession`]'s.

use sbm_virt::backup::{self, BackupJob};
use sbm_virt::error::{Error, ErrorKind};

use super::pve::PveError;

/// Why `schedule` cannot be a backup job's, as an `Issue`'s name
/// (`schedule_invalid`); None when it has the shape of one PVE takes.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_schedule_issue(schedule: String) -> Option<String> {
    backup::schedule_issue(&schedule).and_then(|i| serde_json::to_value(i).ok()).and_then(|v| v.as_str().map(str::to_owned))
}

/// Whether `job_json` (a `BackupJob`) takes `vmid` and no other guest: the
/// guest's own plan.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_backup_job_takes_only(job_json: String, vmid: Option<u32>) -> Result<bool, PveError> {
    let job: BackupJob = serde_json::from_str(&job_json).map_err(|e| PveError::from(Error::msg(ErrorKind::InvalidResponse, e.to_string())))?;
    Ok(job.takes_only(vmid))
}
