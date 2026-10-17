//! `/api/v1/waf*`: the web application firewall in front of the reverse
//! proxies' sites (`sbm_parser::waf`; a site turns it on in `/proxy`).
//! Linux only, like `/proxy`, whose job slot it shares.
//!
//! - `GET /waf`: nginx's and Traefik's firewall, ready or not, and the
//!   settings ServerBox wrote.
//! - `PUT /waf/{server}`: `{settings, sudo_password}`: the rules written,
//!   checked by nginx (the previous ones back on refusal) and reloaded.
//! - `POST /waf/{server}/install`: `{sudo_password}`: nginx's module and the
//!   Core Rule Set, for Traefik also nginx as its engine and the plugin, as a
//!   job (`GET /proxy/job`).
//! - `POST /waf/{server}/events`: `{sudo_password}`: what the firewall
//!   detected and refused lately (its audit log is root's).

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::stacks::job::JobState;
use sbm_parser::proxy::Server;
use sbm_parser::waf::{self as waf, Settings};

pub(crate) async fn read(state: &AppState) -> Option<waf::WafView> {
    let limits = super::machine::at_least(&state.remote_access.exec, 1 << 20);
    match super::exec::run(waf::READ_COMMAND, None, None, &limits).await {
        Ok(out) if !out.timed_out => Some(waf::parse(&out.stdout)),
        _ => None,
    }
}

fn server_of(id: &str) -> Result<Server, HttpResponse> {
    match Server::from_id(id) {
        Some(Server::Caddy) => Err(super::respond::error_u16(409, "unsupported")),
        Some(s) => Ok(s),
        None => Err(super::respond::error_u16(404, "unknownServer")),
    }
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    match read(&state).await {
        Some(v) => Ok(HttpResponse::Ok().json(&v)),
        None => Ok(super::respond::error_u16(502, "unreadable")),
    }
}

#[derive(Deserialize)]
pub struct SetBody {
    settings: Settings,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn set(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<SetBody>,
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
    let SetBody { settings, sudo_password } = body.into_inner();
    let Some(now) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    let ready = if server == Server::Nginx { now.nginx.ready } else { now.traefik.ready };
    if !ready {
        return Ok(super::respond::error_u16(409, "notReady"));
    }
    let script = match waf::write_script(server, &settings) {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::error_u16(400, e)),
    };
    require!(as_root(&state, &script, sudo_password.as_deref().filter(|p| !p.is_empty()), false).await);
    record(&req, &state, format!("waf {id}: {:?}, paranoia {}, {} rules left out", settings.mode, settings.paranoia, settings.exclusions.len()).to_lowercase()).await;
    match read(&state).await {
        Some(v) => Ok(HttpResponse::Ok().json(&v)),
        None => Ok(super::respond::error_u16(502, "unreadable")),
    }
}

#[derive(Deserialize, Default)]
pub struct PasswordBody {
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn install(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<PasswordBody>,
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
    let script = match waf::install_script(server) {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::error_u16(400, e)),
    };
    let password = body.into_inner().sudo_password.unwrap_or_default();
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.proxy.begin(crate::stacks::job::JobKind::Install) else { return Ok(super::respond::error_u16(409, "busy")) };
    record(&req, &state, format!("waf install {id}")).await;
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

pub async fn events(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<PasswordBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let command = match server_of(&id).map(waf::events_command) {
        Ok(Ok(c)) => c,
        Ok(Err(e)) => return Ok(super::respond::error_u16(400, e)),
        Err(r) => return Ok(r),
    };
    let password = body.into_inner().sudo_password.filter(|p| !p.is_empty());
    let limits = super::machine::at_least(&state.remote_access.exec, 8 << 20);
    match super::machine::as_root(&command, password.as_deref(), &limits).await {
        Ok(out) if out.exit_code == Some(0) => Ok(HttpResponse::Ok().json(&serde_json::json!({ "events": waf::parse_events(&out.stdout) }))),
        Ok(out) if sbm_parser::script::sudo_password_rejected(&out.stderr) => Ok(super::respond::error_u16(403, "sudo_rejected")),
        _ => Ok(super::respond::error_u16(403, "sudo_unavailable")),
    }
}
