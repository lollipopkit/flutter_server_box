//! `GET/PUT /settings` and the dashboard's card order.

use crate::{
    api::authz,
    core::config_file,
    monitoring::LiveSettings,
    utils::error::Result,
};
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use super::*;

/// Whitelisted, writable subset of `Config` the settings page exposes.
/// Deliberately excludes `jwt_secret`/`database_url`/`push` (secrets, or
/// need their own dedicated design for session-invalidation-on-rotation) —
/// see the settings-page plan for why those are out of scope.
#[derive(Serialize, Deserialize)]
pub(super) struct SettingsPayload {
    interval_seconds: u64,
    /// `null` = `interval_seconds * 10`, with a 120-second floor
    extended_interval_secs: Option<u64>,
    idle_pause_enabled: bool,
    /// `null` = `interval_seconds * 4`
    idle_pause_threshold_secs: Option<u64>,
    rules: Vec<crate::core::config::MonitoringRule>,
    data_retention: Option<crate::core::config::DataRetentionConfig>,
    cors_allowed_origins: Vec<String>,
    /// Always present in a GET. Absent from a PUT keeps what is stored, so a
    /// panel or app from before the field cannot turn it off by saving.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    disk_counts_network: Option<bool>,
}

/// GET-only wrapper: which fields take effect immediately vs. need a
/// restart, so the settings UI can label fields honestly instead of
/// guessing. A separate type from `SettingsPayload` (rather than an
/// `Option<Vec<&'static str>>` field on it) because a `'static` field breaks
/// deriving `Deserialize`, which `SettingsPayload` also needs for PUT.
#[derive(Serialize)]
pub(super) struct SettingsView {
    #[serde(flatten)]
    settings: SettingsPayload,
    live_fields: &'static [&'static str],
    /// What `data_retention` should become when an editor offers to switch it
    /// on. `null` there means *no cleanup runs at all* — `cli.rs` only starts
    /// the scheduler when the section is present — rather than "the defaults
    /// apply", so an editor cannot express turning it on without values to put
    /// in it. They belong here rather than copied into each editor, where they
    /// would drift from `DataRetentionConfig::default` unnoticed.
    data_retention_defaults: crate::core::config::DataRetentionConfig,
}

pub(super) const SETTINGS_LIVE_FIELDS: &[&str] = &[
    "extended_interval_secs",
    "idle_pause_enabled",
    "idle_pause_threshold_secs",
    "disk_counts_network",
];

pub(super) async fn get_settings(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    require_acting!(&req, &app_state);

    let file_config = match config_file::read_async().await {
        Ok(c) => c,
        Err(e) => return Ok(crate::api::respond::config_unreadable(&e)),
    };
    let monitoring = file_config.get_monitoring();
    let live = app_state.live_settings.read().await.clone();

    Ok(HttpResponse::Ok().json(&SettingsView {
        settings: SettingsPayload {
            interval_seconds: monitoring.interval_seconds,
            extended_interval_secs: monitoring.extended.interval_secs,
            idle_pause_enabled: live.idle_pause_enabled,
            idle_pause_threshold_secs: monitoring.extended.idle_pause.threshold_secs,
            rules: monitoring.rules,
            data_retention: monitoring.data_retention,
            cors_allowed_origins: file_config.get_server().cors_allowed_origins,
            disk_counts_network: Some(live.disk_counts_network),
        },
        live_fields: SETTINGS_LIVE_FIELDS,
        data_retention_defaults: crate::core::config::DataRetentionConfig::default(),
    }))
}

/// Kept beside the settings endpoint so file and API validation cannot drift.
pub(super) fn validate_threshold_format(threshold: &str) -> std::result::Result<(), String> {
    let re = regex::Regex::new(r"^(>=|<=|>|<|==|!=)(\d+(?:\.\d+)?)([%KMGTB]*)(/s)?$").unwrap();
    if re.is_match(threshold) {
        Ok(())
    } else {
        Err(format!("Invalid threshold format: {threshold}"))
    }
}

pub(super) async fn update_settings(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<SettingsPayload>,
) -> Result<HttpResponse> {
    require_acting!(&req, &app_state);
    let payload = payload.into_inner();

    if payload.interval_seconds < 1 {
        return Ok(HttpResponse::BadRequest()
            .json(&ErrorResponse { error: "interval_seconds must be at least 1".to_string() }));
    }
    if let Some(retention) = &payload.data_retention
        && let Err(error) = retention.validate()
    {
        return Ok(HttpResponse::BadRequest().json(&ErrorResponse { error }));
    }
    for rule in &payload.rules {
        if let Err(e) = validate_threshold_format(&rule.threshold) {
            return Ok(HttpResponse::BadRequest().json(&ErrorResponse {
                error: format!("Rule '{}': {e}", rule.name),
            }));
        }
    }

    // Held across the whole read-modify-write so a concurrent PUT can't read
    // the same starting state and drop this change on its own save.
    let _config_guard = app_state.config_write.lock().await;

    let mut config = match config_file::read_async().await {
        Ok(c) => c,
        Err(e) => return Ok(crate::api::respond::config_unreadable(&e)),
    };

    let mut monitoring = config.get_monitoring();
    monitoring.interval_seconds = payload.interval_seconds;
    monitoring.extended.interval_secs = payload.extended_interval_secs;
    monitoring.extended.idle_pause.enabled = payload.idle_pause_enabled;
    monitoring.extended.idle_pause.threshold_secs = payload.idle_pause_threshold_secs;
    monitoring.rules = payload.rules;
    monitoring.data_retention = payload.data_retention;
    if let Some(counts) = payload.disk_counts_network {
        monitoring.disk_counts_network = counts;
    }
    config.monitoring = Some(monitoring.clone());

    let mut server_config = config.get_server();
    server_config.cors_allowed_origins = payload.cors_allowed_origins;
    config.server = Some(server_config);

    // Writes atomically and keeps a bounded set of timestamped backups as a
    // manual undo path — see `config_file`
    if let Err(e) = config_file::write_async(&config).await {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: e.to_string() }));
    }

    // The live-reloadable subset takes effect immediately; everything else
    // needs a restart (the settings UI must say so — this response doesn't
    // repeat itself here, see SETTINGS_LIVE_FIELDS via GET)
    *app_state.live_settings.write().await = LiveSettings::from_config(&monitoring);

    tracing::info!("Settings saved via PUT /api/v1/settings");
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "ok" })))
}

/// Home-grid card order — split out from `SettingsPayload`/`PUT /settings`
/// deliberately: reordering cards by drag-and-drop happens far more often
/// than editing rules/CORS, and routing it through the full settings payload
/// would mean read-modify-write races against whatever the settings page has
/// open, risking clobbering an in-progress edit there. No restart-required
/// concept applies — this is never read by the backend, only stored for sync.
#[derive(Serialize, Deserialize)]
pub(super) struct CardOrderPayload {
    card_order: Vec<String>,
}

pub(super) async fn get_card_order(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    require_read_access!(&req, &app_state);
    let file_config = match config_file::read_async().await {
        Ok(c) => c,
        Err(e) => return Ok(crate::api::respond::config_unreadable(&e)),
    };
    Ok(HttpResponse::Ok().json(&CardOrderPayload { card_order: file_config.get_server().card_order }))
}

pub(super) async fn update_card_order(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<CardOrderPayload>,
) -> Result<HttpResponse> {
    require_acting!(&req, &app_state);
    let _config_guard = app_state.config_write.lock().await;

    let mut config = match config_file::read_async().await {
        Ok(c) => c,
        Err(e) => return Ok(crate::api::respond::config_unreadable(&e)),
    };
    let mut server_config = config.get_server();
    server_config.card_order = payload.into_inner().card_order;
    config.server = Some(server_config);

    if let Err(e) = config_file::write_async(&config).await {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: e.to_string() }));
    }
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "ok" })))
}
