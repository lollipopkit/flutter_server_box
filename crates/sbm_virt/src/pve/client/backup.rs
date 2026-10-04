//! A PVE host's backups and backup jobs: what each storage holds of a
//! guest, the datacenter's jobs, a backup taken now, a job made, edited,
//! removed or run now, a backup restored, edited or deleted.
//!
//! Each request is checked first ([`crate::backup`]'s rules) against what
//! the host lists then; the job list needs `Sys.Audit` (an account without
//! it sees none), editing it `Sys.Modify` on `/` and `Datastore.Allocate`
//! on the job's storage.

use futures_util::future::try_join_all;
use serde_json::Value;

use super::Client;
use crate::backup::{self, Backup, BackupEdit, BackupJob, BackupJobEdit, BackupRequest, Issue, ScheduleCheck};
use crate::error::{Detail, Error, ErrorKind, Result};
use crate::model::{Guest, GuestKind, GuestState};
use crate::pve::backup::{job_fields, parse_backup_jobs, parse_backups, vzdump_of_job};
use crate::pve::http::{Body, Method};
use crate::pve::{form, resources, seg};
use crate::resource::Pool;

fn body(fields: &[(String, String)]) -> Body {
    let pairs: Vec<(&str, &str)> = fields.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect();
    Body::form(form(&pairs))
}

/// PVE's answer for a job id it no longer has, as the refusal a client
/// knows: `id: No such job '<id>'` (9.2.2: a 400 on read, the same text
/// inside a 500 on delete) or `no such vzdump job` (a 500 on update).
fn job_gone(e: Error) -> Error {
    if !e.message.as_deref().is_some_and(|m| m.to_ascii_lowercase().contains("no such") && m.to_ascii_lowercase().contains("job")) {
        return e;
    }
    let mut gone = backup::refusal(Issue::NotFound);
    gone.message = e.message;
    gone
}

fn owned(fields: Vec<(&str, String)>) -> Vec<(String, String)> {
    fields.into_iter().map(|(k, v)| (k.to_owned(), v)).collect()
}

impl Client {
    /// `node`'s enabled, active storages that hold backups.
    pub async fn backup_storages(&self, node: &str) -> Result<Vec<Pool>> {
        let path = format!("/nodes/{}/storage?content=backup&enabled=1", seg(node));
        let Value::Array(list) = self.call(Method::Get, &path, None, false).await? else { return Ok(Vec::new()) };
        Ok(resources::parse_storages(node, &list, &[])
            .into_iter()
            .filter(|p| p.active && p.content.iter().any(|c| c == "backup"))
            .collect())
    }

    /// Every online node's backup storages, one per `node/storage` (a
    /// shared storage is listed by each node that sees it), by name then
    /// node.
    pub async fn all_backup_storages(&self) -> Result<Vec<Pool>> {
        let mut out: Vec<Pool> = Vec::new();
        for node in self.online_nodes().await? {
            for p in self.backup_storages(&node).await? {
                if !out.iter().any(|o| o.id == p.id) {
                    out.push(p);
                }
            }
        }
        out.sort_by(|a, b| a.name.cmp(&b.name).then_with(|| a.node.cmp(&b.node)));
        Ok(out)
    }

    /// Every backup of `guest` on its node's backup storages, newest first.
    pub async fn backups(&self, guest: &Guest) -> Result<Vec<Backup>> {
        let node = guest.node.clone().unwrap_or_default();
        let vmid = guest.vmid.unwrap_or_default();
        let mut out = Vec::new();
        for storage in self.backup_storages(&node).await? {
            let path = format!("/nodes/{}/storage/{}/content?content=backup&vmid={vmid}", seg(&node), seg(&storage.name));
            if let Value::Array(list) = self.call(Method::Get, &path, None, false).await? {
                out.extend(parse_backups(&node, &storage.name, &list));
            }
        }
        out.sort_by_key(|b| std::cmp::Reverse(b.created_at.unwrap_or(0)));
        Ok(out)
    }

    /// The datacenter's jobs (`/cluster/backup`). It needs `Sys.Audit`: an
    /// account without it sees no jobs rather than an error.
    pub async fn all_backup_jobs(&self) -> Result<Vec<BackupJob>> {
        match self.call(Method::Get, "/cluster/backup", None, false).await {
            Ok(Value::Array(list)) => Ok(parse_backup_jobs(&list)),
            Ok(_) => Ok(Vec::new()),
            Err(e) if e.kind == ErrorKind::AuthFailed && e.status == Some(403) => Ok(Vec::new()),
            Err(e) => Err(e),
        }
    }

    /// The jobs that take `guest`.
    pub async fn backup_jobs(&self, guest: &Guest) -> Result<Vec<BackupJob>> {
        Ok(self.all_backup_jobs().await?.into_iter().filter(|j| j.takes(guest.vmid, guest.node.as_deref())).collect())
    }

    /// `POST /cluster/backup` (a new job), `PUT /cluster/backup/{id}`, or —
    /// with `remove` — `DELETE`. Checked first: the schedule's shape, a
    /// storage that holds backups, the guests it takes.
    pub async fn edit_backup_job(&self, edit: &BackupJobEdit, remove: bool) -> Result<()> {
        let run = async {
            if remove {
                let id = edit.id.as_deref().filter(|i| !i.is_empty()).ok_or_else(|| backup::refusal(Issue::NotFound))?;
                self.call(Method::Delete, &format!("/cluster/backup/{}", seg(id)), None, true).await.map_err(job_gone)?;
                return Ok(());
            }
            let names: Vec<String> = self.all_backup_storages().await?.into_iter().map(|p| p.name).collect();
            if let Some(issue) = backup::job_issue(edit, &names) {
                return Err(backup::refusal(issue));
            }
            let fields = owned(job_fields(edit));
            if edit.is_new {
                self.call(Method::Post, "/cluster/backup", Some(body(&fields)), true).await?;
            } else {
                let id = edit.id.as_deref().filter(|i| !i.is_empty()).ok_or_else(|| backup::refusal(Issue::NotFound))?;
                self.call(Method::Put, &format!("/cluster/backup/{}", seg(id)), Some(body(&fields)), true).await.map_err(job_gone)?;
            }
            Ok(())
        };
        run.await.map_err(|e| self.manage_err(e))
    }

    /// `GET /cluster/jobs/schedule-analyze`, what PVE's job editor's
    /// "Simulate" calls (any account may): the next three runs, or PVE's
    /// refusal in its own words. A value of the wrong shape is not sent.
    pub async fn check_schedule(&self, schedule: &str) -> Result<ScheduleCheck> {
        if backup::schedule_issue(schedule).is_some() {
            return Ok(ScheduleCheck { error: Some(format!("invalid calendar event '{}'", schedule.trim())), next: Vec::new() });
        }
        let path = format!("/cluster/jobs/schedule-analyze?schedule={}&iterations=3", seg(schedule.trim()));
        match self.call(Method::Get, &path, None, true).await {
            Ok(Value::Array(items)) => {
                Ok(ScheduleCheck { error: None, next: items.iter().filter_map(|i| i.get("timestamp").and_then(Value::as_i64)).collect() })
            }
            Ok(_) => Ok(ScheduleCheck::default()),
            // A refused schedule is a 400 with PVE's parse error: the form
            // shows it under the field, not as a failed request.
            Err(e) if e.kind == ErrorKind::ActionFailed && e.status == Some(400) => {
                Ok(ScheduleCheck { error: Some(e.message.unwrap_or_else(|| "HTTP 400".to_owned())), next: Vec::new() })
            }
            Err(e) => Err(e),
        }
    }

    /// `POST /nodes/{node}/vzdump` for the one guest, waited for.
    pub async fn backup(&self, guest: &Guest, request: &BackupRequest) -> Result<()> {
        let node = guest.node.clone().unwrap_or_default();
        let names: Vec<String> = self.backup_storages(&node).await?.into_iter().map(|p| p.name).collect();
        if let Some(issue) = backup::request_issue(request, &names) {
            return Err(backup::refusal(issue));
        }
        let mut f = vec![
            ("vmid".to_owned(), guest.vmid.unwrap_or_default().to_string()),
            ("storage".to_owned(), request.storage.clone()),
            ("mode".to_owned(), request.mode.clone()),
            ("compress".to_owned(), request.compress.clone()),
        ];
        if let Some(notes) = request.notes.as_deref().map(str::trim).filter(|n| !n.is_empty()) {
            f.push(("notes-template".to_owned(), notes.to_owned()));
        }
        if request.protected {
            f.push(("protected".to_owned(), "1".to_owned()));
        }
        if let Some(p) = &request.prune {
            f.push(("prune-backups".to_owned(), p.clone()));
        }
        self.vzdump(&node, &f).await.map_err(|e| self.manage_err(e))
    }

    /// One `vzdump` request on `node`, its task waited for.
    async fn vzdump(&self, node: &str, fields: &[(String, String)]) -> Result<()> {
        self.node_task(node, Method::Post, &format!("/nodes/{}/vzdump", seg(node)), Some(body(fields))).await
    }

    /// A job's "Run now", as PVE's own web UI does it (`run_backup_now`):
    /// the job read again — it carries what only PVE's editor sets
    /// (`bwlimit`, `performance`, `fleecing`, …), which a run keeps — and
    /// its fields less the schedule's posted to `vzdump` on the job's node,
    /// refused when it is not online, or on every online node for a job with
    /// none: `vzdump` takes only the guests of the node it runs on.
    pub async fn run_backup_job(&self, id: &str) -> Result<()> {
        let read = self.call(Method::Get, &format!("/cluster/backup/{}", seg(id)), None, false).await.map_err(job_gone)?;
        let Value::Object(raw) = read else {
            return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
        };
        let online = self.online_nodes().await?;
        let nodes = match raw.get("node").and_then(Value::as_str).filter(|n| !n.is_empty()) {
            None => online,
            Some(n) if online.iter().any(|o| o == n) => vec![n.to_owned()],
            Some(n) => {
                let mut e = backup::refusal(Issue::NodeOffline);
                e.message = Some(n.to_owned());
                return Err(e);
            }
        };
        if nodes.is_empty() {
            return Err(backup::refusal(Issue::NodeOffline));
        }
        let fields = vzdump_of_job(&raw);
        try_join_all(nodes.iter().map(|n| self.vzdump(n, &fields))).await.map_err(|e| self.manage_err(e))?;
        Ok(())
    }

    /// `backup` restored: over `guest` itself (`force=1`, only while it is
    /// stopped), or as a new guest `vmid`. A VM's is `POST .../qemu` with
    /// `archive`, a container's `.../lxc` with `ostemplate` and `restore=1`.
    /// `storage` is where the restored disks land; None leaves each volume
    /// where the archive says.
    pub async fn restore_backup(&self, guest: &Guest, backup_id: &str, vmid: Option<u32>, storage: Option<&str>) -> Result<()> {
        let (guest, guests, _) = self.fresh(guest).await?;
        let node = guest.node.clone().unwrap_or_default();
        let found = self.backups(&guest).await?.into_iter().find(|b| b.id == backup_id).ok_or_else(|| backup::refusal(Issue::NotFound))?;
        let over = vmid.is_none();
        if over && guest.state != GuestState::Stopped {
            return Err(backup::refusal(Issue::NotStopped));
        }
        if let Some(v) = vmid {
            if !(crate::create::VMID_MIN..=crate::create::VMID_MAX).contains(&v) {
                return Err(crate::create::refusal(crate::create::Issue::VmidInvalid));
            }
            if guests.iter().any(|g| g.vmid == Some(v)) {
                return Err(crate::create::refusal(crate::create::Issue::VmidTaken));
            }
        }
        let lxc = found.kind.unwrap_or(guest.kind) == GuestKind::Lxc;
        let mut f = vec![("vmid".to_owned(), vmid.or(guest.vmid).unwrap_or_default().to_string())];
        if lxc {
            f.push(("ostemplate".to_owned(), found.id.clone()));
            f.push(("restore".to_owned(), "1".to_owned()));
        } else {
            f.push(("archive".to_owned(), found.id.clone()));
        }
        if over {
            f.push(("force".to_owned(), "1".to_owned()));
        }
        if let Some(s) = storage {
            f.push(("storage".to_owned(), s.to_owned()));
        }
        let path = format!("/nodes/{}/{}", seg(&node), if lxc { "lxc" } else { "qemu" });
        self.node_task(&node, Method::Post, &path, Some(body(&f))).await.map_err(|e| self.manage_err(e))
    }

    fn content_path(backup: &Backup) -> String {
        format!("/nodes/{}/storage/{}/content/{}", seg(&backup.node), seg(&backup.storage), seg(&backup.id))
    }

    /// A backup's own notes and protection. Both are sent every time: PVE
    /// keeps what is not sent, so an empty note is written as one.
    pub async fn edit_backup(&self, backup: &Backup, edit: &BackupEdit) -> Result<()> {
        let f = vec![("notes".to_owned(), edit.notes.clone()), ("protected".to_owned(), (if edit.protected { "1" } else { "0" }).to_owned())];
        self.call(Method::Put, &Self::content_path(backup), Some(body(&f)), true).await.map(|_| ()).map_err(|e| self.manage_err(e))
    }

    /// Deletes a backup, its task waited for.
    pub async fn delete_backup(&self, backup: &Backup) -> Result<()> {
        self.node_task(&backup.node, Method::Delete, &Self::content_path(backup), None).await.map_err(|e| self.manage_err(e))
    }
}
