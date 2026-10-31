//! `/api/v1/monitor-backup*`: backups of this monitor's settings to a WebDAV
//! folder (`monitor_backup`). Changing where they go, the passphrase, and
//! restoring re-ask the password.
//!
//! - `GET /monitor-backup`: the settings (never the password) and how the last
//!   backup went.
//! - `PUT /monitor-backup`: `{url, username, password?, allow_insecure,
//!   enabled, keep, current_password}`; `DELETE` (password) stops backing up.
//! - `POST /monitor-backup/test`: `{url, username, password?, allow_insecure}`
//!   lists the folder.
//! - `PUT /monitor-backup/key`: `{passphrase, current_password}`, a new key.
//! - `POST /monitor-backup/run`: a backup now (202; `GET` says when it is done).
//! - `GET /monitor-backup/list`: the backups in the folder, newest first.
//! - `POST /monitor-backup/restore`: `{name, passphrase, current_password}`.

use crate::api::WebError;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;

use super::admin::{audit, reauth};
use super::authz;
use super::server::AppState;
use super::ws::audit::Action;
use crate::monitor_backup::{self, SetSettings, Target};
use crate::stacks::Refusal;

fn refused(r: Refusal) -> HttpResponse {
    super::respond::error_u16(r.status, r.error)
}

pub async fn get(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    Ok(HttpResponse::Ok().json(&monitor_backup::view(&state).await))
}

#[derive(Deserialize)]
pub struct SettingsBody {
    #[serde(flatten)]
    settings: SetSettings,
    current_password: Option<String>,
}

pub async fn put(
    req: HttpRequest,
    body: web::types::Json<SettingsBody>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match monitor_backup::set_settings(&state, body.settings).await {
        Ok(view) => {
            let host = view.url.as_deref().and_then(|u| url::Url::parse(u).ok()).and_then(|u| u.host_str().map(String::from)).unwrap_or_default();
            audit(&req, &state, Action::Write, format!("monitor backup to {host}")).await;
            Ok(HttpResponse::Ok().json(&view))
        }
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize, Default)]
pub struct PasswordBody {
    current_password: Option<String>,
}

pub async fn remove(
    req: HttpRequest,
    body: Option<web::types::Json<PasswordBody>>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.map(|b| b.into_inner()).unwrap_or_default();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match monitor_backup::remove_settings(&state).await {
        Ok(()) => {
            audit(&req, &state, Action::Write, "monitor backup off".into()).await;
            Ok(HttpResponse::NoContent().build())
        }
        Err(r) => Ok(refused(r)),
    }
}

pub async fn test(
    req: HttpRequest,
    body: web::types::Json<Target>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    match monitor_backup::test(&state, &body).await {
        Ok(probe) => Ok(HttpResponse::Ok().json(&probe)),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize)]
pub struct KeyBody {
    passphrase: String,
    current_password: Option<String>,
}

pub async fn put_key(
    req: HttpRequest,
    body: web::types::Json<KeyBody>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match monitor_backup::set_key(&state, &body.passphrase).await {
        Ok(view) => {
            audit(&req, &state, Action::Write, format!("monitor backup key {}", view.key_id.as_deref().unwrap_or(""))).await;
            Ok(HttpResponse::Ok().json(&view))
        }
        Err(r) => Ok(refused(r)),
    }
}

pub async fn run(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    let view = monitor_backup::view(&state).await;
    if !view.configured || view.key_id.is_none() {
        return Ok(super::respond::error_u16(409, "notReady"));
    }
    // Turned off, the loop backs up nothing, asked or not.
    if !view.enabled {
        return Ok(super::respond::error_u16(409, "disabled"));
    }
    state.monitor_backup.request_now();
    Ok(HttpResponse::Accepted().json(&view))
}

pub async fn list(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    match monitor_backup::list(&state).await {
        Ok(backups) => Ok(HttpResponse::Ok().json(&json!({ "backups": backups }))),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize)]
pub struct RestoreBody {
    name: String,
    passphrase: String,
    current_password: Option<String>,
}

pub async fn restore(
    req: HttpRequest,
    body: web::types::Json<RestoreBody>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match monitor_backup::restore(&state, &body.name, &body.passphrase).await {
        Ok((restored, restart)) => {
            audit(&req, &state, Action::Write, format!("monitor settings restored from {}", body.name)).await;
            Ok(HttpResponse::Ok().json(&json!({ "restored": restored, "restart": restart })))
        }
        Err(r) => Ok(refused(r)),
    }
}
