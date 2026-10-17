//! `/api/v1/proxy*`: the machine's reverse proxies (nginx, Caddy, Traefik)
//! and their sites, as `sbm_parser::proxy` reads and writes them. Linux only.
//!
//! - `GET /proxy`: each server, installed and running or not, its sites
//!   (ServerBox's, which it changes, and the others, shown).
//! - `PUT /proxy/{server}/sites`: `{sites, sudo_password}`, every site
//!   ServerBox keeps for that server: its file written, checked by the
//!   server and the previous one back on refusal (`refused`).
//! - `POST /proxy/{server}/install`: `{acme_email?, sudo_password}`, the
//!   server installed as a job (`GET /proxy/job`).

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::stacks::job::{JobKind, JobState};
use sbm_parser::proxy::{self as px, Server, Site};

async fn read(state: &AppState) -> Option<px::ProxyView> {
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    match super::exec::run(px::READ_COMMAND, None, None, &limits).await {
        Ok(out) if !out.timed_out => Some(px::parse(&out.stdout)),
        Ok(_) => None,
        Err(e) => {
            tracing::warn!("proxy: reading did not run: {e}");
            None
        }
    }
}

fn server_of(id: &str) -> Result<Server, HttpResponse> {
    Server::from_id(id).ok_or_else(|| super::respond::error_u16(404, "unknownServer"))
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let Some(view) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    let mut body = serde_json::to_value(view).unwrap_or_default();
    body["job"] = state.proxy.current().map(|j| serde_json::to_value(j.view(0)).unwrap_or_default()).unwrap_or_default();
    Ok(HttpResponse::Ok().json(&body))
}

#[derive(Deserialize)]
pub struct SitesBody {
    sites: Vec<Site>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn set_sites(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<SitesBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let server = match server_of(&id) {
        Ok(s) => s,
        Err(r) => return Ok(r),
    };
    let SitesBody { sites, sudo_password } = body.into_inner();
    let Some(now) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    let found = now.servers.iter().find(|s| s.server == server).expect("every server is read");
    if !found.installed {
        return Ok(super::respond::error_u16(409, "notInstalled"));
    }
    if !found.writable {
        return Ok(super::respond::error_u16(409, "notWritable"));
    }
    // A site behind the firewall needs its rules written first: nginx would
    // refuse the file it names, Traefik route to a middleware not there.
    if sites.iter().any(|s| s.waf) {
        let waf = super::waf::read(&state).await;
        let set = waf.is_some_and(|w| if server == Server::Nginx { w.nginx.settings.is_some() } else { w.traefik.settings.is_some() });
        if !set {
            return Ok(super::respond::error_u16(409, "wafNotSet"));
        }
    }
    let script = match px::write_script(server, &sites, found.tls_resolver) {
        Ok(s) => s,
        Err(e) => return Ok(HttpResponse::BadRequest().json(&e)),
    };
    require!(as_root(&state, &script, sudo_password.as_deref().filter(|p| !p.is_empty()), false).await);
    let names: Vec<&str> = sites.iter().map(|s| s.name.as_str()).collect();
    record(&req, &state, format!("proxy {id} sites: {}", names.join(", "))).await;
    let Some(view) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    Ok(HttpResponse::Ok().json(&view))
}

#[derive(Deserialize)]
pub struct InstallBody {
    #[serde(default)]
    acme_email: Option<String>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn install(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<InstallBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let server = match server_of(&id) {
        Ok(s) => s,
        Err(r) => return Ok(r),
    };
    let InstallBody { acme_email, sudo_password } = body.into_inner();
    let script = match px::install_script(server, acme_email.as_deref().filter(|e| !e.is_empty())) {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::error_u16(400, e)),
    };
    let password = sudo_password.unwrap_or_default();
    // Tried first, so a wrong password is said here rather than in a log.
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.proxy.begin(JobKind::Install) else { return Ok(super::respond::error_u16(409, "busy")) };
    record(&req, &state, format!("proxy install {id}")).await;
    let job2 = job.clone();
    tokio::spawn(async move {
        match job2.run_root(&script, &password).await {
            Ok(()) => job2.finish(JobState::Succeeded, None),
            Err(e) => {
                job2.push(format!("✕ {e}"));
                job2.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e));
            }
        }
    });
    Ok(HttpResponse::Accepted().json(&job.view(0)))
}

#[derive(Deserialize)]
pub struct JobQuery {
    #[serde(default)]
    since: u64,
}

pub async fn job(req: HttpRequest, query: web::types::Query<JobQuery>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match state.proxy.current() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(super::respond::error_u16(404, "notFound")),
    }
}
