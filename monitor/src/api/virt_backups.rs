//! `/api/v1/virt` backups and backup jobs (`sbm_virt::backup`), Proxmox VE
//! only: libvirt keeps no backups of its own, and is answered `unsupported`.
//!
//! - `POST /virt/backups`: a guest's backups, the jobs that take it, and the
//!   storages of its node that hold backups.
//! - `POST /virt/backup`: one taken now. `/virt/backup/restore` (over the
//!   guest, stopped, or as a new VMID), `/virt/backup/edit` (its notes and
//!   protection), `/virt/backup/delete`.
//! - `POST /virt/backup-jobs`: the datacenter's jobs and every node's backup
//!   storages. `/virt/backup-jobs/edit` (made, edited or removed),
//!   `/virt/backup-jobs/run` ("Run now"), `/virt/backup-jobs/schedule` (what
//!   the host makes of a schedule: its next runs, or its refusal).
//!
//! A request is checked first (`sbm_virt::backup`'s rules) and refused as
//! `Detail::BackupRefused`. `virt` to see and change, as for power; a host's
//! failure is answered 200 with `error`, as in `api::virt`.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use sbm_virt::backup::{self, Backup, BackupEdit, BackupJobEdit, BackupRequest, Issue};
use sbm_virt::error::Error as VirtError;
use sbm_virt::pve::Client;

use super::machine;
use super::server::AppState;
use super::virt::{Backend, PowerResponse, backend, guest_of};
use super::virt_guests::Audit;
use crate::core::permissions::Grant;

#[derive(Deserialize)]
pub struct GuestBody {
    guest: String,
}

#[derive(Deserialize)]
pub struct BackupBody {
    guest: String,
    request: BackupRequest,
}

#[derive(Deserialize)]
pub struct RestoreBody {
    guest: String,
    backup: String,
    #[serde(default)]
    vmid: Option<u32>,
    #[serde(default)]
    storage: Option<String>,
}

#[derive(Deserialize)]
pub struct EditBody {
    guest: String,
    backup: String,
    edit: BackupEdit,
}

#[derive(Deserialize)]
pub struct DeleteBody {
    guest: String,
    backup: String,
}

#[derive(Deserialize)]
pub struct JobEditBody {
    edit: BackupJobEdit,
    #[serde(default)]
    remove: bool,
}

#[derive(Deserialize)]
pub struct JobRunBody {
    id: String,
}

#[derive(Deserialize)]
pub struct ScheduleBody {
    schedule: String,
}

fn answer(value: serde_json::Value) -> Result<HttpResponse, web::Error> {
    Ok(HttpResponse::Ok().json(&value))
}

/// The PVE session, or libvirt's refusal.
fn pve(backend: &Backend) -> Result<&Arc<Client>, VirtError> {
    match backend {
        Backend::Pve(client) => Ok(client),
        Backend::Libvirt => Err(backup::refusal(Issue::Unsupported)),
    }
}

/// `id` among `guest`'s backups as the host lists them now.
async fn backup_of(client: &Client, guest: &sbm_virt::model::Guest, id: &str) -> Result<Backup, VirtError> {
    client.backups(guest).await?.into_iter().find(|b| b.id == id).ok_or_else(|| backup::refusal(Issue::NotFound))
}

pub async fn backups(
    req: HttpRequest,
    body: web::types::Json<GuestBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt backups").await {
        return Ok(refused);
    }
    let request = body.into_inner();
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let read = async {
        let client = pve(&backend)?;
        let guest = guest_of(&state, &backend, &request.guest, None).await?;
        let backups = client.backups(&guest).await?;
        let jobs = client.backup_jobs(&guest).await?;
        let storages = client.backup_storages(guest.node.as_deref().unwrap_or_default()).await?;
        Ok::<_, VirtError>(serde_json::json!({ "backups": backups, "jobs": jobs, "storages": storages, "error": null }))
    };
    answer(read.await.unwrap_or_else(|e| serde_json::json!({ "backups": null, "jobs": null, "storages": null, "error": e })))
}

/// Gated and recorded; `run` is made with the PVE session.
async fn audited(
    req: &HttpRequest,
    state: &AppState,
    what: String,
    run: impl AsyncFnOnce(&Arc<Client>, &Backend) -> Result<(), VirtError>,
) -> Result<HttpResponse, web::Error> {
    let audit = match Audit::start(req, state, what).await {
        Ok(a) => a,
        Err(refused) => return Ok(refused),
    };
    let backend = match backend(state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let result = match pve(&backend) {
        Ok(client) => run(client, &backend).await,
        Err(e) => Err(e),
    };
    audit.end(&result).await;
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

pub async fn backup(
    req: HttpRequest,
    body: web::types::Json<BackupBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let r = body.into_inner();
    let what = format!("virt backup {} to {}", r.guest, r.request.storage);
    audited(&req, &state, what, async |client, backend| {
        let guest = guest_of(&state, backend, &r.guest, None).await?;
        client.backup(&guest, &r.request).await
    })
    .await
}

pub async fn restore(
    req: HttpRequest,
    body: web::types::Json<RestoreBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let r = body.into_inner();
    let to = r.vmid.map_or_else(|| "over it".to_owned(), |v| format!("as {v}"));
    let what = format!("virt backup restore {} {} {to}", r.guest, r.backup);
    audited(&req, &state, what, async |client, backend| {
        let guest = guest_of(&state, backend, &r.guest, None).await?;
        client.restore_backup(&guest, &r.backup, r.vmid, r.storage.as_deref()).await
    })
    .await
}

pub async fn edit(
    req: HttpRequest,
    body: web::types::Json<EditBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let r = body.into_inner();
    let what = format!("virt backup edit {}", r.backup);
    audited(&req, &state, what, async |client, backend| {
        let guest = guest_of(&state, backend, &r.guest, None).await?;
        let found = backup_of(client, &guest, &r.backup).await?;
        client.edit_backup(&found, &r.edit).await
    })
    .await
}

pub async fn delete(
    req: HttpRequest,
    body: web::types::Json<DeleteBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let r = body.into_inner();
    let what = format!("virt backup delete {}", r.backup);
    audited(&req, &state, what, async |client, backend| {
        let guest = guest_of(&state, backend, &r.guest, None).await?;
        let found = backup_of(client, &guest, &r.backup).await?;
        client.delete_backup(&found).await
    })
    .await
}

/// Takes no fields, but reads the body the POST carries: a handler that
/// leaves it unread has ntex close the connection after its answer, which a
/// client still sending the body sees as a disconnect.
pub async fn jobs(
    req: HttpRequest,
    _body: Option<web::types::Json<serde_json::Value>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt backup jobs").await {
        return Ok(refused);
    }
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let read = async {
        let client = pve(&backend)?;
        let jobs = client.all_backup_jobs().await?;
        let storages = client.all_backup_storages().await?;
        Ok::<_, VirtError>(serde_json::json!({ "jobs": jobs, "storages": storages, "error": null }))
    };
    answer(read.await.unwrap_or_else(|e| serde_json::json!({ "jobs": null, "storages": null, "error": e })))
}

pub async fn edit_job(
    req: HttpRequest,
    body: web::types::Json<JobEditBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let r = body.into_inner();
    let verb = if r.remove {
        "remove"
    } else if r.edit.is_new {
        "create"
    } else {
        "edit"
    };
    let what = format!("virt backup job {verb} {}", r.edit.id.as_deref().unwrap_or("(new)"));
    audited(&req, &state, what, async |client, _| client.edit_backup_job(&r.edit, r.remove).await).await
}

pub async fn run_job(
    req: HttpRequest,
    body: web::types::Json<JobRunBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let r = body.into_inner();
    let what = format!("virt backup job run {}", r.id);
    audited(&req, &state, what, async |client, _| client.run_backup_job(&r.id).await).await
}

pub async fn schedule(
    req: HttpRequest,
    body: web::types::Json<ScheduleBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt backup schedule").await {
        return Ok(refused);
    }
    let r = body.into_inner();
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let read = match pve(&backend) {
        Ok(client) => client.check_schedule(&r.schedule).await,
        Err(e) => Err(e),
    };
    answer(match read {
        Ok(check) => serde_json::json!({ "check": check, "error": null }),
        Err(e) => serde_json::json!({ "check": null, "error": e }),
    })
}
