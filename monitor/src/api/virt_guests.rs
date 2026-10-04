//! `/api/v1/virt` making, copying and deleting guests (`sbm_virt::create`),
//! whether this machine runs Proxmox VE or libvirt.
//!
//! - `POST /virt/create/form`: what a new guest of a kind (on a PVE node)
//!   can be given — where its disk goes, its NIC's networks, the install
//!   media or templates, the cloud images, the host's options and, on PVE,
//!   the VMID offered.
//! - `POST /virt/create`: one `sbm_virt::create::CreateSpec`.
//! - `POST /virt/delete`: a stopped guest, with its disks or (libvirt)
//!   without them.
//! - `POST /virt/clone/form`: where a copy's disks can go.
//! - `POST /virt/clone`: one `sbm_virt::create::CloneRequest`.
//! - `POST /virt/template`: a stopped PVE guest becomes a template.
//!
//! **Each request is checked against what the host lists at that moment**
//! (`sbm_virt::create`'s rules) before anything is sent; a refusal says
//! which rule (`Detail::CreateRefused`). A password a spec carries (a
//! container's root, cloud-init's account) goes in the request to the host
//! only: libvirt is given its SHA-512 crypt hash, PVE hashes it itself, and
//! neither the audit log nor a log line has it.
//!
//! `virt` to see and change, as for power. A host's failure is answered 200
//! with `error`, as in `api::virt`.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use sbm_virt::create::{self, CloneRequest, CreateSpec, Created, Issue};
use sbm_virt::error::Error as VirtError;
use sbm_virt::libvirt::{self, create as lc, host as lv};
use sbm_virt::model::{Guest, GuestKind, HostKind};
use sbm_virt::resource::{Pool, Volume};

use super::machine;
use super::server::AppState;
use super::virt::{Backend, PowerResponse, backend, guest_of, libvirt_chain, run_libvirt};
use super::virt_resources::{libvirt_networks, libvirt_storage, password, read_volumes};
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

#[derive(Deserialize)]
pub struct FormRequest {
    kind: GuestKind,
    /// PVE: the node the guest would be made on.
    #[serde(default)]
    node: Option<String>,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct CreateRequest {
    spec: CreateSpec,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct DeleteRequest {
    guest: String,
    /// libvirt: its disks, NVRAM and seed go with it. PVE deletes a guest's
    /// disks whatever is asked.
    #[serde(default = "yes")]
    remove_disks: bool,
    #[serde(default)]
    password: Option<String>,
}

fn yes() -> bool {
    true
}

#[derive(Deserialize)]
pub struct CloneBody {
    guest: String,
    request: CloneRequest,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct GuestBody {
    guest: String,
    #[serde(default)]
    password: Option<String>,
}

fn answer(value: serde_json::Value) -> Result<HttpResponse, web::Error> {
    Ok(HttpResponse::Ok().json(&value))
}

/// A change to the machine's guests, gated by `virt` and recorded before
/// it runs, as power is; a failure is recorded again with its kind.
pub(crate) struct Audit<'a> {
    state: &'a AppState,
    gated: machine::Gated,
    what: String,
}

impl<'a> Audit<'a> {
    pub(crate) async fn start(req: &HttpRequest, state: &'a AppState, what: String) -> Result<Self, HttpResponse> {
        let gated = machine::gate(req, state, Grant::Virt, &what).await?;
        let audit = Audit { state, gated, what };
        audit.event(Action::Open, Outcome::Ok, None).record(&state.db).await;
        Ok(audit)
    }

    fn event(&self, action: Action, outcome: Outcome, why: Option<&str>) -> Event {
        Event::new(Kind::Machine, action, outcome)
            .subject(&self.gated.caller.username)
            .remote_ip(self.gated.remote_ip.clone())
            .detail(match why {
                Some(why) => format!("{}: {why}", self.what),
                None => self.what.clone(),
            })
    }

    pub(crate) async fn end<T>(&self, result: &Result<T, VirtError>) {
        if let Err(e) = result {
            self.event(Action::Close, Outcome::Error, Some(&format!("{:?}", e.kind))).record(&self.state.db).await;
        }
    }
}

pub async fn create_form(
    req: HttpRequest,
    body: web::types::Json<FormRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt create form").await {
        return Ok(refused);
    }
    let request = body.into_inner();
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let form = match &backend {
        Backend::Pve(client) => match &request.node {
            Some(node) => client.create_form(request.kind, node).await,
            None => Err(create::refusal(Issue::Node)),
        },
        Backend::Libvirt => libvirt_form(&state, password(&request.password), request.kind).await,
    };
    answer(match form {
        Ok(form) => serde_json::json!({ "form": form, "error": null }),
        Err(e) => serde_json::json!({ "form": null, "error": e }),
    })
}

pub async fn create(
    req: HttpRequest,
    body: web::types::Json<CreateRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let audit = match Audit::start(&req, &state, format!("virt {}", request.spec.describe())).await {
        Ok(a) => a,
        Err(refused) => return Ok(refused),
    };
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let result = match &backend {
        Backend::Pve(client) => client.create(&request.spec).await,
        Backend::Libvirt => libvirt_create(&state, password(&request.password), &request.spec).await,
    };
    audit.end(&result).await;
    answer(match result {
        Ok(created) => serde_json::json!({ "created": created, "error": null }),
        Err(e) => serde_json::json!({ "created": null, "error": e }),
    })
}

pub async fn delete(
    req: HttpRequest,
    body: web::types::Json<DeleteRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let keep = if request.remove_disks { "" } else { " (disks kept)" };
    let audit = match Audit::start(&req, &state, format!("virt delete {}{keep}", request.guest)).await {
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
            Backend::Pve(client) => client.delete(&guest).await,
            Backend::Libvirt => libvirt_delete(&state, pw, &guest, request.remove_disks).await,
        },
        Err(e) => Err(e),
    };
    audit.end(&result).await;
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

pub async fn clone_form(
    req: HttpRequest,
    body: web::types::Json<GuestBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt clone form").await {
        return Ok(refused);
    }
    let request = body.into_inner();
    let pw = password(&request.password);
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let read = async {
        let guest = guest_of(&state, &backend, &request.guest, pw).await?;
        let (pools, host) = match &backend {
            Backend::Pve(client) => (client.storage_pools().await?, HostKind::Pve),
            Backend::Libvirt => {
                (libvirt_storage(&state, pw).await?.pools.iter().map(lv::pool_of).collect::<Vec<_>>(), HostKind::Libvirt)
            }
        };
        Ok::<_, VirtError>(create::clone_storages(&pools, host, &guest).into_iter().cloned().collect::<Vec<Pool>>())
    };
    answer(match read.await {
        Ok(storages) => serde_json::json!({ "storages": storages, "error": null }),
        Err(e) => serde_json::json!({ "storages": null, "error": e }),
    })
}

pub async fn clone(
    req: HttpRequest,
    body: web::types::Json<CloneBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let audit = match Audit::start(&req, &state, format!("virt clone {} as {}", request.guest, request.request.name)).await {
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
            Backend::Pve(client) => client.clone_guest(&guest, &request.request).await,
            Backend::Libvirt => libvirt_clone(&state, pw, &guest, &request.request).await,
        },
        Err(e) => Err(e),
    };
    audit.end(&result).await;
    answer(match result {
        Ok(id) => serde_json::json!({ "id": id, "error": null }),
        Err(e) => serde_json::json!({ "id": null, "error": e }),
    })
}

pub async fn template(
    req: HttpRequest,
    body: web::types::Json<GuestBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let audit = match Audit::start(&req, &state, format!("virt template {}", request.guest)).await {
        Ok(a) => a,
        Err(refused) => return Ok(refused),
    };
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let result = match &backend {
        Backend::Pve(client) => match guest_of(&state, &backend, &request.guest, None).await {
            Ok(guest) => client.make_template(&guest).await,
            Err(e) => Err(e),
        },
        Backend::Libvirt => Err(create::refusal(Issue::Unsupported)),
    };
    audit.end(&result).await;
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

// ---------------------------------------------------------------------------
// libvirt
// ---------------------------------------------------------------------------

/// What `domcapabilities` says of a new domain, and the firmware QEMU ships
/// (best effort: without it, Secure Boot is not offered).
async fn create_host(state: &AppState, password: Option<&str>) -> Result<(libvirt::VirtCreateHost, Vec<libvirt::FirmwareDescriptor>), VirtError> {
    let host = run_libvirt(state, &libvirt::create_host_script(), password, false, libvirt::parse_create_host).await?;
    let firmware = run_libvirt(state, &libvirt::firmware_script(), password, false, |raw| Ok(libvirt::parse_firmware_descriptors(raw)))
        .await
        .unwrap_or_else(|e| {
            tracing::info!("virt: firmware descriptors: {e}");
            Vec::new()
        });
    Ok((host, firmware))
}

async fn guests(state: &AppState, password: Option<&str>) -> Result<Vec<Guest>, VirtError> {
    let overview = run_libvirt(state, &libvirt::overview_script(), password, false, libvirt::parse_overview).await?;
    Ok(overview.domains.iter().map(lv::guest_of).collect())
}

async fn libvirt_form(state: &AppState, password: Option<&str>, kind: GuestKind) -> Result<create::CreateForm, VirtError> {
    let (host, firmware) = create_host(state, password).await?;
    let options = lc::options_of(&host, &firmware);
    let storage = libvirt_storage(state, password).await?;
    let pools: Vec<Pool> = storage.pools.iter().map(lv::pool_of).collect();
    let networks = libvirt_networks(state, password).await?;
    let mut volumes = Vec::new();
    for pool in create::form_pools(&pools, HostKind::Libvirt, kind, None, &options) {
        volumes.push((pool.id.clone(), read_volumes(state, password, &storage, &pool.id).await?.0));
    }
    Ok(create::create_form(kind, HostKind::Libvirt, None, options, None, &pools, &networks, &volumes))
}

/// Two steps on the host: the disk — empty, or a copy of a cloud image —
/// and a cloud-init seed, with their paths; then the domain on them,
/// defined and started when asked. A define the host refuses deletes the
/// volumes again.
async fn libvirt_create(state: &AppState, password: Option<&str>, spec: &CreateSpec) -> Result<Created, VirtError> {
    let (host, firmware) = create_host(state, password).await?;
    let guests = guests(state, password).await?;
    let storage = libvirt_storage(state, password).await?;
    let pools: Vec<Pool> = storage.pools.iter().map(lv::pool_of).collect();
    let networks = libvirt_networks(state, password).await?;
    let find = async |r: &Option<create::VolumeRef>| -> Result<Option<Volume>, VirtError> {
        let Some(r) = r else { return Ok(None) };
        if !pools.iter().any(|p| p.id == r.pool) {
            return Ok(None);
        }
        Ok(read_volumes(state, password, &storage, &r.pool).await?.0.into_iter().find(|v| v.id == r.volume))
    };
    let media = find(&spec.media).await?;
    let image = find(&spec.image).await?;
    let on = lc::CreateHost {
        host: &host,
        firmware: &firmware,
        guests: &guests,
        pools: &pools,
        networks: &networks,
        media: media.as_ref(),
        image: image.as_ref(),
    };
    let lv_spec = lc::spec_of(spec, on, None)?;
    let script = libvirt::create_volume_script(&lv_spec).map_err(|e| lv::error_of(&e, true))?;
    let made = run_libvirt(state, &script, password, true, libvirt::parse_create_volumes).await.map_err(lc::exists_or)?;
    let lv_spec = lc::with_volumes(lv_spec, &made);
    let script = libvirt::define_script(&lv_spec).map_err(|e| lv::error_of(&e, true))?;
    let created = run_libvirt(state, &script, password, true, libvirt::parse_create).await?;
    Ok(lc::created_of(&lv_spec, &made, created))
}

/// `undefine`, with what goes with the domain when its disks do
/// (`sbm_virt::libvirt::create::delete_plan`): read here first — the
/// definition, every domain's disks, every active pool's volumes, the
/// snapshots and, where external ones left files, the disks' chains.
async fn libvirt_delete(state: &AppState, password: Option<&str>, guest: &Guest, remove_disks: bool) -> Result<(), VirtError> {
    if let Some(issue) = create::delete_issue(guest) {
        return Err(create::refusal(issue));
    }
    let plan = if remove_disks {
        let detail = run_libvirt(state, &libvirt::domain_detail_script(&guest.id), password, false, libvirt::parse_domain_detail).await?;
        let storage = libvirt_storage(state, password).await?;
        let mut volumes = Vec::new();
        for pool in storage.pools.iter().filter(|p| p.active) {
            volumes.push((pool.name.clone(), read_volumes(state, password, &storage, &pool.name).await?.0));
        }
        let snapshots: Vec<_> = run_libvirt(state, &libvirt::snapshots_script(&guest.id), password, false, libvirt::parse_snapshots)
            .await?
            .iter()
            .map(lv::snapshot_of)
            .collect();
        let chain = if lc::delete_needs_chain(&snapshots) { Some(libvirt_chain(state, guest, password).await?) } else { None };
        let plan = lc::delete_plan(lc::DeleteInputs {
            id: &guest.id,
            name: &guest.name,
            xml: &detail.xml,
            disks: &storage.disks,
            pools: &storage.pools,
            volumes: &volumes,
            snapshots: &snapshots,
            chain: chain.as_ref(),
        });
        for kept in &plan.kept {
            tracing::warn!("virt: deleting {}: {kept}", guest.name);
        }
        plan
    } else {
        lc::DeletePlan::default()
    };
    let script = libvirt::undefine_script(&guest.id, &plan.targets, plan.seed.as_deref(), &plan.pools, &plan.files)
        .map_err(|e| lv::error_of(&e, true))?;
    run_libvirt(state, &script, password, true, libvirt::parse_undefine).await
}

/// Two steps, as creating is: each writable disk copied (or made empty),
/// then the copy defined on those volumes — a new UUID and MACs, its own
/// UEFI variables file. Either step failing deletes the volumes it made.
async fn libvirt_clone(state: &AppState, password: Option<&str>, guest: &Guest, request: &CloneRequest) -> Result<String, VirtError> {
    let info = run_libvirt(state, &libvirt::hardware_script(&guest.id), password, false, libvirt::parse_hardware).await?;
    let guests = guests(state, password).await?;
    let pools = libvirt_storage(state, password).await?.pools;
    let spec = lc::clone_spec_of(guest, &info.config, request, &guests, &pools)?;
    let script = libvirt::clone_volumes_script(&spec).map_err(|e| lv::error_of(&e, true))?;
    let paths = run_libvirt(state, &script, password, true, libvirt::parse_clone_volumes).await.map_err(lc::exists_or)?;
    let script = libvirt::clone_define_script(&info.config_xml, &request.name, &lc::clone_disks(&spec, &paths))
        .map_err(|e| lv::error_of(&e, true))?;
    let created = run_libvirt(state, &script, password, true, libvirt::parse_create).await?;
    Ok(created.uuid.unwrap_or_else(|| request.name.clone()))
}
