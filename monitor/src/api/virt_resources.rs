//! `/api/v1/virt` storage and networks: this machine's pools, volumes and
//! networks (`sbm_virt::resource`), whether it runs Proxmox VE or libvirt,
//! and the changes to them.
//!
//! - `POST /virt/storage`: the pools (PVE: every online node's storages), with
//!   what a form offers for each (`rules`: the formats a new volume may have,
//!   whether one is grown on its own).
//! - `POST /virt/volumes`: one pool's volumes, with the guests using each and,
//!   on libvirt, the volumes made on each.
//! - `POST /virt/networks`: the networks (PVE: every node's interfaces) and,
//!   on PVE, each node's pending configuration.
//! - `POST /virt/manage`: one `sbm_virt::resource::Change`.
//!
//! **A change is checked against what the host lists at that moment**, never
//! against the page's copy: the target is named by id and resolved here, and
//! `sbm_virt::resource::issue` refuses it (in use, a name taken, PVE's
//! management interface) before anything is sent. On PVE the node is asked
//! which interfaces it is using (`sbm_virt::pve::net::LIVE_NET_SCRIPT`, run
//! here: the agent runs on the node it manages), so the one the operator is
//! connected through is never edited or applied over.
//!
//! `virt` to see and change, as for power. A host's failure is answered 200
//! with `error`, as in `api::virt`.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use sbm_virt::error::Error as VirtError;
use sbm_virt::libvirt::{self, host as lv};
use sbm_virt::model::HostKind;
use sbm_virt::pve::net::{LIVE_NET_SCRIPT, LiveNet, parse_live_net};
use sbm_virt::resource::{Change, Listing, Network, Pool, Volume};

use super::machine;
use super::server::AppState;
use super::virt::{Backend, PowerResponse, backend, run_libvirt};
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

#[derive(Deserialize, Default)]
pub struct HostRequest {
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct VolumesRequest {
    pool: String,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Deserialize)]
pub struct ManageRequest {
    change: Change,
    #[serde(default)]
    password: Option<String>,
}

pub(crate) fn password(p: &Option<String>) -> Option<&str> {
    p.as_deref().filter(|p| !p.is_empty())
}

fn answer(value: serde_json::Value) -> Result<HttpResponse, web::Error> {
    Ok(HttpResponse::Ok().json(&value))
}

pub async fn storage(
    req: HttpRequest,
    body: Option<web::types::Json<HostRequest>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt storage").await {
        return Ok(refused);
    }
    let request = body.map(|b| b.into_inner()).unwrap_or_default();
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let pools = match &backend {
        Backend::Pve(client) => client.storage_pools().await,
        Backend::Libvirt => libvirt_storage(&state, password(&request.password)).await.map(|s| s.pools.iter().map(lv::pool_of).collect()),
    };
    let host = match backend {
        Backend::Pve(_) => HostKind::Pve,
        Backend::Libvirt => HostKind::Libvirt,
    };
    answer(match pools {
        Ok(pools) => {
            // What a form offers per pool, decided where the rules are.
            let rules: serde_json::Map<String, serde_json::Value> = pools
                .iter()
                .map(|p| {
                    let rule = serde_json::json!({
                        "formats": sbm_virt::resource::volume_formats(p),
                        "resizable": host == HostKind::Libvirt && sbm_virt::resource::volume_resizable(p, host),
                    });
                    (p.id.clone(), rule)
                })
                .collect();
            serde_json::json!({ "pools": pools, "rules": rules, "error": null })
        }
        Err(e) => serde_json::json!({ "pools": null, "rules": null, "error": e }),
    })
}

pub async fn volumes(
    req: HttpRequest,
    body: web::types::Json<VolumesRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt volumes").await {
        return Ok(refused);
    }
    let request = body.into_inner();
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let volumes = match &backend {
        Backend::Pve(client) => match client.storage_pools().await {
            Ok(pools) => match pools.iter().find(|p| p.id == request.pool) {
                Some(pool) => client.volumes(pool).await,
                None => Err(not_found(&request.pool)),
            },
            Err(e) => Err(e),
        },
        Backend::Libvirt => libvirt_volumes(&state, password(&request.password), &request.pool).await,
    };
    answer(match volumes {
        Ok(volumes) => serde_json::json!({ "volumes": volumes, "error": null }),
        Err(e) => serde_json::json!({ "volumes": null, "error": e }),
    })
}

pub async fn networks(
    req: HttpRequest,
    body: Option<web::types::Json<HostRequest>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt networks").await {
        return Ok(refused);
    }
    let request = body.map(|b| b.into_inner()).unwrap_or_default();
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let read = match &backend {
        Backend::Pve(client) => {
            let live = live_net(&state).await;
            match client.networks(live.as_ref()).await {
                Ok(networks) => client.network_changes().await.map(|changes| (networks, changes)),
                Err(e) => Err(e),
            }
        }
        Backend::Libvirt => libvirt_networks(&state, password(&request.password)).await.map(|n| (n, Vec::new())),
    };
    answer(match read {
        Ok((networks, changes)) => serde_json::json!({ "networks": networks, "changes": changes, "error": null }),
        Err(e) => serde_json::json!({ "networks": null, "changes": null, "error": e }),
    })
}

pub async fn manage(
    req: HttpRequest,
    body: web::types::Json<ManageRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let what = format!("virt {}", request.change.describe());
    let gated = match machine::gate(&req, &state, Grant::Virt, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let record = |outcome, why: Option<&str>| {
        Event::new(Kind::Machine, if why.is_some() { Action::Close } else { Action::Open }, outcome)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip.clone())
            .detail(match why {
                Some(why) => format!("{what}: {why}"),
                None => what.clone(),
            })
    };
    record(Outcome::Ok, None).record(&state.db).await;
    let backend = match backend(&state).await {
        Ok(b) => b,
        Err(refused) => return Ok(refused),
    };
    let result = match &backend {
        Backend::Pve(client) => {
            let live = if request.change.is_network() { live_net(&state).await } else { None };
            client.manage(&request.change, live.as_ref()).await
        }
        Backend::Libvirt => libvirt_manage(&state, password(&request.password), &request.change).await,
    };
    if let Err(e) = &result {
        record(Outcome::Error, Some(&format!("{:?}", e.kind))).record(&state.db).await;
    }
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

fn not_found(id: &str) -> VirtError {
    let mut e = sbm_virt::resource::refusal(sbm_virt::resource::Issue::NotFound);
    e.message = Some(id.to_owned());
    e
}

/// What this machine says of the interfaces it is using; None where it
/// could not say, which protects every interface with an address.
async fn live_net(state: &AppState) -> Option<LiveNet> {
    match machine::as_self(LIVE_NET_SCRIPT, &state.remote_access.exec).await {
        Ok(out) => parse_live_net(&out.stdout),
        Err(e) => {
            tracing::info!("virt: live network probe: {e}");
            None
        }
    }
}

// ---------------------------------------------------------------------------
// libvirt
// ---------------------------------------------------------------------------

pub(crate) async fn libvirt_storage(state: &AppState, password: Option<&str>) -> Result<libvirt::VirtStorage, VirtError> {
    run_libvirt(state, &libvirt::storage_script(), password, false, libvirt::parse_storage).await
}

/// `pool`'s volumes as `storage` lists them, and whether one of them did not
/// read.
pub(crate) async fn read_volumes(
    state: &AppState,
    password: Option<&str>,
    storage: &libvirt::VirtStorage,
    pool: &str,
) -> Result<(Vec<Volume>, bool), VirtError> {
    let Some(listed) = storage.pools.iter().find(|p| p.name == pool).and_then(|p| p.volumes.as_ref()) else {
        return Ok((Vec::new(), false));
    };
    if listed.is_empty() {
        return Ok((Vec::new(), false));
    }
    let names: Vec<String> = listed.iter().map(|v| v.name.clone()).collect();
    let read = run_libvirt(state, &libvirt::volumes_script(pool, &names), password, false, libvirt::parse_volumes).await?;
    let volumes: Vec<Volume> = read.iter().map(|v| lv::volume_of(v, pool, &storage.disks)).collect();
    let missing = volumes.len() < listed.len();
    Ok((volumes, missing))
}

/// `pool`'s volumes with the guests using each and the volumes made on
/// each, in any active pool.
///
/// A volume libvirt lists but cannot read (its file removed behind
/// libvirt's back: `vol-list` answers from the pool's cache, `vol-dumpxml`
/// says "Storage volume not found") means the pool's list is stale: the pool
/// is refreshed (`pool-refresh`, what libvirt does at its own start) and read
/// again, once.
pub(crate) async fn libvirt_volumes(state: &AppState, password: Option<&str>, pool: &str) -> Result<Vec<Volume>, VirtError> {
    let mut storage = libvirt_storage(state, password).await?;
    let Some(active) = storage.pools.iter().find(|p| p.name == pool).map(|p| p.active) else {
        return Err(not_found(pool));
    };
    let (mut read, missing) = read_volumes(state, password, &storage, pool).await?;
    if missing && active {
        let refresh = libvirt::manage::VirtResourceOp::PoolRefresh { name: pool.to_owned() };
        let script = libvirt::manage::resource_script(&refresh).map_err(|e| lv::error_of(&e, true))?;
        run_libvirt(state, &script, password, true, libvirt::manage::parse_resource).await?;
        storage = libvirt_storage(state, password).await?;
        read = read_volumes(state, password, &storage, pool).await?.0;
    }
    let mut every = read.clone();
    for other in storage.pools.iter().filter(|p| p.active && p.name != pool) {
        every.extend(read_volumes(state, password, &storage, &other.name).await?.0);
    }
    Ok(lv::with_backs(read, &every))
}

pub(crate) async fn libvirt_networks(state: &AppState, password: Option<&str>) -> Result<Vec<Network>, VirtError> {
    let all = run_libvirt(state, &libvirt::networks_script(), password, false, libvirt::parse_networks).await?;
    Ok(all.networks.iter().map(|n| lv::network_of(n, &all)).collect())
}

async fn libvirt_manage(state: &AppState, password: Option<&str>, change: &Change) -> Result<(), VirtError> {
    let pools: Vec<Pool> = if change.is_network() {
        Vec::new()
    } else {
        libvirt_storage(state, password).await?.pools.iter().map(lv::pool_of).collect()
    };
    let volumes = match change {
        Change::PoolSetActive { pool, .. }
        | Change::PoolDelete { pool, .. }
        | Change::VolumeCreate { pool, .. }
        | Change::VolumeDelete { pool, .. }
        | Change::VolumeResize { pool, .. }
        | Change::VolumeClone { pool, .. }
            if pools.iter().any(|p| &p.id == pool) =>
        {
            libvirt_volumes(state, password, pool).await?
        }
        _ => Vec::new(),
    };
    let networks = if change.is_network() { libvirt_networks(state, password).await? } else { Vec::new() };
    let script = lv::resource_script(change, Listing { pools: &pools, networks: &networks, volumes: &volumes })?;
    let text = script.script().map_err(|e| lv::error_of(&e, true))?;
    run_libvirt(state, &text, password, true, |raw| script.parse(raw)).await?;
    Ok(())
}
