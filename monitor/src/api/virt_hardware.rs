//! `/api/v1/virt` a guest's hardware, settings and cloud-init
//! (`sbm_virt::hardware`), whether this machine runs Proxmox VE or libvirt.
//!
//! - `POST /virt/hardware`: the guest's hardware as the next start gets it,
//!   with what the running guest has instead (`pending`) and the `revision`
//!   an edit is sent back with.
//! - `POST /virt/hardware/change`: one `sbm_virt::hardware::Change`, made
//!   from the read whose `revision` it carries.
//! - `POST /virt/hardware/revert`: every pending change dropped.
//! - `POST /virt/cloud-init`, `/virt/cloud-init/set`: a VM's cloud-init
//!   settings, never the password (PVE answers it masked; libvirt's seed
//!   holds its hash, which stays here).
//! - `POST /virt/host-devices`: the host's USB and PCI devices a guest can
//!   be given.
//!
//! **A change is checked against the guest as it is now** (`sbm_virt`'s
//! rules) and refused as `Detail::HardwareRefused`; one made from an older
//! read is `conflict` — PVE checks its `digest`, libvirt's revision is the
//! SHA-256 of the definition, compared with the one read for the change.
//!
//! `virt` to see and change, as for power. A host's failure is answered 200
//! with `error`, as in `api::virt`.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use sbm_virt::error::Error as VirtError;
use sbm_virt::hardware::{Change, CloudInitEdit, Listing, Outcome};
use sbm_virt::libvirt::{self, cloud_init as ci, hardware as lh, host as lv};
use sbm_virt::model::Guest;
use sbm_virt::resource::{Network, Pool, Volume};

use super::machine;
use super::server::AppState;
use super::virt::{Backend, PowerResponse, backend, guest_of, run_libvirt};
use super::virt_guests::Audit;
use super::virt_resources::{libvirt_networks, libvirt_storage, password, read_volumes};
use crate::core::permissions::Grant;

#[derive(Deserialize)]
pub struct GuestBody {
    guest: String,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct ChangeBody {
    guest: String,
    #[serde(default)]
    revision: Option<String>,
    change: Change,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct RevertBody {
    guest: String,
    #[serde(default)]
    revision: Option<String>,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct CloudInitBody {
    guest: String,
    edit: CloudInitEdit,
    #[serde(default)]
    password: Option<String>,
}

fn answer(value: serde_json::Value) -> Result<HttpResponse, web::Error> {
    Ok(HttpResponse::Ok().json(&value))
}

/// Gated by `virt`, the backend found and the guest read: what every read
/// here starts with.
async fn read_guest(req: &HttpRequest, state: &AppState, what: &str, guest: &str, pw: Option<&str>) -> Result<(Backend, Result<Guest, VirtError>), HttpResponse> {
    machine::gate(req, state, Grant::Virt, what).await?;
    let backend = backend(state).await?;
    let found = guest_of(state, &backend, guest, pw).await;
    Ok((backend, found))
}

pub async fn hardware(
    req: HttpRequest,
    body: web::types::Json<GuestBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let pw = password(&request.password);
    let (backend, guest) = match read_guest(&req, &state, "virt hardware", &request.guest, pw).await {
        Ok(r) => r,
        Err(refused) => return Ok(refused),
    };
    let read = match guest {
        Ok(guest) => match &backend {
            Backend::Pve(client) => client.hardware(&guest).await,
            Backend::Libvirt => libvirt_info(&state, pw, &guest).await.map(|info| lh::hardware_of(&info, Some(&guest.name))),
        },
        Err(e) => Err(e),
    };
    answer(match read {
        Ok(hw) => serde_json::json!({ "hardware": hw, "error": null }),
        Err(e) => serde_json::json!({ "hardware": null, "error": e }),
    })
}

pub async fn change(
    req: HttpRequest,
    body: web::types::Json<ChangeBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let what = format!("virt hardware {} {}", request.guest, request.change.describe());
    let audit = match Audit::start(&req, &state, what).await {
        Ok(a) => a,
        Err(refused) => return Ok(refused),
    };
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let pw = password(&request.password);
    let result = match guest_of(&state, &backend, &request.guest, pw).await {
        Ok(guest) => match &backend {
            Backend::Pve(client) => client.change_hardware(&guest, request.revision.as_deref(), &request.change).await,
            Backend::Libvirt => libvirt_change(&state, pw, &guest, request.revision.as_deref(), &request.change).await,
        },
        Err(e) => Err(e),
    };
    audit.end(&result).await;
    answer(match result {
        Ok(outcome) => serde_json::json!({ "outcome": outcome, "error": null }),
        Err(e) => serde_json::json!({ "outcome": null, "error": e }),
    })
}

pub async fn revert(
    req: HttpRequest,
    body: web::types::Json<RevertBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let audit = match Audit::start(&req, &state, format!("virt hardware {} revert pending", request.guest)).await {
        Ok(a) => a,
        Err(refused) => return Ok(refused),
    };
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let pw = password(&request.password);
    let result = match guest_of(&state, &backend, &request.guest, pw).await {
        Ok(guest) => match &backend {
            Backend::Pve(client) => client.revert_pending(&guest, request.revision.as_deref()).await,
            Backend::Libvirt => async {
                let info = libvirt_info(&state, pw, &guest).await?;
                let change = lh::revert_of(&info, request.revision.as_deref())?;
                run_change(&state, pw, &guest, true, &info, &change).await.map(|_| ())
            }
            .await,
        },
        Err(e) => Err(e),
    };
    audit.end(&result).await;
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

pub async fn cloud_init(
    req: HttpRequest,
    body: web::types::Json<GuestBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let pw = password(&request.password);
    let (backend, guest) = match read_guest(&req, &state, "virt cloud-init", &request.guest, pw).await {
        Ok(r) => r,
        Err(refused) => return Ok(refused),
    };
    let read = match guest {
        Ok(guest) => match &backend {
            Backend::Pve(client) => client.cloud_init(&guest).await,
            Backend::Libvirt => libvirt_seed(&state, pw, &guest).await.map(|(info, _, read)| lh::cloud_init_state_of(&read, &macs(&info))),
        },
        Err(e) => Err(e),
    };
    answer(match read {
        Ok(ci) => serde_json::json!({ "cloud_init": ci, "error": null }),
        Err(e) => serde_json::json!({ "cloud_init": null, "error": e }),
    })
}

pub async fn set_cloud_init(
    req: HttpRequest,
    body: web::types::Json<CloudInitBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    // The password, if one was typed, goes to the host only.
    let audit = match Audit::start(&req, &state, format!("virt cloud-init {}", request.guest)).await {
        Ok(a) => a,
        Err(refused) => return Ok(refused),
    };
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let pw = password(&request.password);
    let result = match guest_of(&state, &backend, &request.guest, pw).await {
        Ok(guest) => match &backend {
            Backend::Pve(client) => client.set_cloud_init(&guest, &request.edit).await,
            Backend::Libvirt => libvirt_set_cloud_init(&state, pw, &guest, &request.edit).await,
        },
        Err(e) => Err(e),
    };
    audit.end(&result).await;
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

pub async fn host_devices(
    req: HttpRequest,
    body: web::types::Json<GuestBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let pw = password(&request.password);
    let (backend, guest) = match read_guest(&req, &state, "virt host devices", &request.guest, pw).await {
        Ok(r) => r,
        Err(refused) => return Ok(refused),
    };
    let read = match guest {
        Ok(guest) => match &backend {
            Backend::Pve(client) => client.host_devices(&guest).await,
            Backend::Libvirt => run_libvirt(&state, &libvirt::host_devices_script(), pw, false, libvirt::parse_host_devices)
                .await
                .map(|d| lh::host_devices_of(&d)),
        },
        Err(e) => Err(e),
    };
    answer(match read {
        Ok(d) => serde_json::json!({ "devices": d, "error": null }),
        Err(e) => serde_json::json!({ "devices": null, "error": e }),
    })
}

// ---------------------------------------------------------------------------
// libvirt
// ---------------------------------------------------------------------------

async fn libvirt_info(state: &AppState, pw: Option<&str>, guest: &Guest) -> Result<libvirt::VirtHardwareInfo, VirtError> {
    run_libvirt(state, &libvirt::hardware_script(&guest.id), pw, false, libvirt::parse_hardware).await
}

fn macs(info: &libvirt::VirtHardwareInfo) -> Vec<String> {
    info.config.nics.iter().map(|n| n.mac.clone()).collect()
}

/// What `change` is checked against and made with: the host's pools, its
/// networks where a NIC is named, and the volume it names as its pool
/// lists it now.
async fn libvirt_listing(state: &AppState, pw: Option<&str>, change: &Change) -> Result<(Vec<Pool>, Vec<Network>, Vec<Volume>), VirtError> {
    let storage = libvirt_storage(state, pw).await?;
    let pools: Vec<Pool> = storage.pools.iter().map(lv::pool_of).collect();
    let networks = match change {
        Change::AddNic { .. } | Change::UpdateNic { .. } => libvirt_networks(state, pw).await?,
        _ => Vec::new(),
    };
    let named = match change {
        Change::AttachVolume { volume, .. } => Some(volume),
        Change::AddCdrom { media } | Change::SetMedia { media, .. } => media.as_ref(),
        _ => None,
    };
    let volumes = match named {
        Some(r) if pools.iter().any(|p| p.id == r.pool) => {
            read_volumes(state, pw, &storage, &r.pool).await?.0.into_iter().filter(|v| v.id == r.volume).collect()
        }
        _ => Vec::new(),
    };
    Ok((pools, networks, volumes))
}

async fn run_change(
    state: &AppState,
    pw: Option<&str>,
    guest: &Guest,
    running: bool,
    info: &libvirt::VirtHardwareInfo,
    change: &libvirt::VirtHwChange,
) -> Result<Outcome, VirtError> {
    let script = libvirt::hardware_change_script(&guest.id, running, Some(&info.config_xml), change).map_err(|e| lv::error_of(&e, true))?;
    let outcome = run_libvirt(state, &script, pw, true, libvirt::parse_hardware_change).await?;
    Ok(Outcome { live_error: outcome.live_error, volume_kept: outcome.volume_kept })
}

/// The definitions read again, the change checked against them and the
/// read it was made from, then made: to the persistent definition and,
/// where the domain runs, to the running one — the running half failing
/// leaves it for the next start.
async fn libvirt_change(state: &AppState, pw: Option<&str>, guest: &Guest, revision: Option<&str>, change: &Change) -> Result<Outcome, VirtError> {
    let info = libvirt_info(state, pw, guest).await?;
    let (pools, networks, volumes) = libvirt_listing(state, pw, change).await?;
    let list = Listing { pools: &pools, networks: &networks, volumes: &volumes };
    let made = lh::change_of(&info, &guest.name, revision, change, list)?;
    run_change(state, pw, guest, info.live.is_some(), &info, &made).await
}

/// The domain's own seed, read back from its volume.
async fn libvirt_seed(state: &AppState, pw: Option<&str>, guest: &Guest) -> Result<(libvirt::VirtHardwareInfo, String, ci::VirtSeedRead), VirtError> {
    let info = libvirt_info(state, pw, guest).await?;
    let Some(seed) = info.config.seed.clone() else {
        return Err(VirtError::msg(sbm_virt::error::ErrorKind::Unsupported, format!("{} has no cloud-init seed of this app", guest.name)));
    };
    let script = ci::seed_read_script(&seed).map_err(|e| lv::error_of(&e, false))?;
    let read = run_libvirt(state, &script, pw, false, ci::parse_seed_read).await?;
    Ok((info, seed, read))
}

/// A new seed in place of the old, on the same volume, made from the read
/// the edit was made from — refused as a conflict once the seed changed.
async fn libvirt_set_cloud_init(state: &AppState, pw: Option<&str>, guest: &Guest, edit: &CloudInitEdit) -> Result<(), VirtError> {
    let (info, seed, read) = libvirt_seed(state, pw, guest).await?;
    let new = lh::cloud_init_update(&read, &guest.name, &macs(&info), edit)?;
    let script = ci::seed_update_script(&seed, &read.revision, &new, ci::SEED_TOOLS).map_err(|e| lv::error_of(&e, true))?;
    run_libvirt(state, &script, pw, true, ci::parse_seed_update).await
}
