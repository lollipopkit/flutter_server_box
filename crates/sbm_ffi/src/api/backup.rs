//! Backups and backup jobs FFI (sbm_virt::backup)
//!
//! The rules a schedule and a job are checked by; the models are
//! `sbm_virt::backup`'s, mirrored ([`super::virt_model`]). PVE's calls are
//! [`super::pve::PveSession`]'s.

use flutter_rust_bridge::frb;
use sbm_virt::backup;

use super::virt_model::{BackupIssue, BackupJob};

/// Why `schedule` cannot be a backup job's; None when it has the shape of
/// one PVE takes.
#[frb(sync)]
pub fn virt_schedule_issue(schedule: String) -> Option<BackupIssue> {
    backup::schedule_issue(&schedule)
}

/// Whether `job` takes `vmid` and no other guest: the guest's own plan.
#[frb(sync)]
pub fn virt_backup_job_takes_only(job: BackupJob, vmid: Option<u32>) -> bool {
    job.takes_only(vmid)
}
