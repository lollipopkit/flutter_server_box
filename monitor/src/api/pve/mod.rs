//! `/api/v1/pve/*` — the Proxmox VE cluster this agent proxies for the panel.
//!
//! # Why the proxy is here and not in the browser
//!
//! The app reaches a PVE node by forwarding a local socket through SSH and
//! completing the TLS handshake itself (`lib/data/provider/pve.dart`). A
//! monitor-only server has no sshd to forward through, so that route does not
//! exist for it — and a browser cannot take it either: PVE is not a CORS API,
//! and its credential would have to be handed to the page. Here the agent
//! dials the cluster with the account it was given, and the panel sends a node
//! name and an action.
//!
//! **The credential never leaves this machine.** It is stored in
//! `config.toml` under `[pve]`, is written through `PUT /pve/settings` and is
//! answered back by nothing: the GET reports `secret_set`, a boolean. That is
//! `api::ai`'s convention, and it holds for both kinds — a password and an API
//! token are both write-only, and a token's id, which is not a secret, is the
//! one part read back.
//!
//! # Authority
//!
//! Reading the resources needs only the panel login, like the benchmark history
//! or a crontab: it is a listing of the cluster, and the agent's credential is
//! what it is read with. **Saving the settings and acting on a guest need
//! `full_access`.**
//!
//! Saving is gated for a reason that is easy to miss: a `PUT` that sends
//! `secret: null` keeps whatever is stored, so a write that only changes `url`
//! would hand the *existing* credential to the new address. Anyone who could do
//! that could point this agent at a cluster they run and read the secret out of
//! the login it then makes. What a caller may save and what a caller may act
//! with are therefore the same grant.
//!
//! # One login per request
//!
//! Nothing is cached — see `client`'s header. A page refresh is a login and two
//! requests, and a control press is a login and one.
//!
//! # The wire
//!
//! - `GET /pve/settings` — the stored configuration, with `secret` always
//!   `null` and `secret_set` saying whether one is held. `editable` is whether
//!   this caller may save.
//! - `PUT /pve/settings` — the whole section. `secret: null` (or absent) keeps
//!   the stored one, `""` clears it, anything else replaces it, which is the
//!   push convention.
//! - `GET /pve/resources` — the cluster's resources, sorted, with the release
//!   beside them. `editable` is whether this caller may act on them.
//! - `POST /pve/control` — one action on one guest: `{"node": "pve", "kind":
//!   "qemu", "vmid": 101, "action": "start"}`.
//!
//! A refusal is a stable code, phrased by the client in the viewer's language:
//! `notConfigured`, `invalidUrl`, `missingUsername`, `missingRealm`,
//! `missingTokenId`, `invalidKind`, `invalidAction`, `unreachable`,
//! `loginFailed`, `needTfa`, `forbidden`, `invalidResponse`, `upstream` — plus
//! `invalidNode` and `invalidVmid` from `sbm_parser::pve`.
//!
//! **No upstream status is ever answered as itself.** PVE answering 401 does
//! not make this endpoint answer 401: `frontend/src/lib/api.ts` logs the
//! operator out on that status, and what failed here is the agent's credential
//! to a machine the operator is not signed in to. A failure of the credential
//! is `loginFailed` at 400, and one of the transport is a 502.

pub mod client;

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use sbm_parser::pve::{PveAction, PveGuestKind, PveResource, control_path};

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};

use self::client::{PveClient, PveFailure, validate_url};
use crate::core::config::{Config, PveAuthKind, PveConfig};
use crate::core::config_file;

#[derive(Serialize)]
struct ErrorResponse {
    error: &'static str,
    /// PVE's own words about what it refused, when it gave any. Never the body
    /// and never anything this agent stored.
    #[serde(skip_serializing_if = "Option::is_none")]
    detail: Option<String>,
}

fn bad_request(error: &'static str, detail: Option<String>) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error, detail })
}

fn internal_error(error: &'static str) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse {
        error,
        detail: None,
    })
}

/// A failure as a status and a code. The one place that decides which is which:
/// a transport failure is a 502 (the agent could not reach the cluster), and
/// everything else is a 400 — the caller's request or the stored credential,
/// which the operator can act on.
fn failure(error: PveFailure) -> HttpResponse {
    let body = ErrorResponse {
        error: error.code(),
        detail: error.detail().map(str::to_string),
    };
    if error.is_transport() {
        HttpResponse::BadGateway().json(&body)
    } else {
        HttpResponse::BadRequest().json(&body)
    }
}

/// The stored section, off disk rather than off `AppState.config`, which is a
/// startup snapshot — `/push`'s reason: a GET right after a save has to show
/// what was saved.
async fn read_config() -> Result<Config, HttpResponse> {
    match config_file::read() {
        Ok(config) => Ok(config),
        Err(e) => {
            tracing::warn!("pve: could not read the config: {e}");
            Err(internal_error("config_unavailable"))
        }
    }
}

// --- Settings ---

#[derive(Serialize)]
struct SettingsView {
    /// Somewhere to send a request and an account to send it as. What a client
    /// checks before offering the page.
    configured: bool,
    url: String,
    auth: &'static str,
    username: String,
    realm: String,
    /// Not a secret, and the part of a token credential a page has to show.
    token_id: String,
    /// Always `null`. The secret is write-only: this field exists so that a
    /// client round-tripping this view hands back a `null` that means "keep
    /// what is stored" rather than omitting a field it never saw.
    secret: Option<String>,
    /// Whether one is held. The one bit that separates "leave this blank to
    /// keep it" from "there is none".
    secret_set: bool,
    ignore_cert: bool,
    /// Whether this caller may save.
    editable: bool,
}

impl SettingsView {
    fn of(pve: &PveConfig, editable: bool) -> Self {
        Self {
            configured: pve.is_configured(),
            url: pve.url.clone(),
            auth: pve.auth.as_str(),
            username: pve.username.clone(),
            realm: pve.realm.clone(),
            token_id: pve.token_id.clone(),
            secret: None,
            secret_set: pve.secret.as_deref().is_some_and(|s| !s.is_empty()),
            ignore_cert: pve.ignore_cert,
            editable,
        }
    }
}

pub async fn get_settings(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    match read_config().await {
        Ok(config) => Ok(HttpResponse::Ok().json(&SettingsView::of(&config.get_pve(), editable))),
        Err(response) => Ok(response),
    }
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    /// Absent means the section is cleared to its default, which is also what
    /// an operator emptying the address means.
    #[serde(default)]
    url: String,
    /// `password` or `token`. A string rather than the enum, for
    /// [`ControlRequest::kind`]'s reason: an unknown one is a code a client can
    /// phrase rather than ntex's own deserialization error.
    #[serde(default)]
    auth: String,
    #[serde(default)]
    username: String,
    #[serde(default)]
    realm: String,
    #[serde(default)]
    token_id: String,
    /// `null` (or absent) keeps what is stored, an empty string clears it,
    /// anything else replaces it — the push convention, one field wide.
    #[serde(default)]
    secret: Option<String>,
    #[serde(default)]
    ignore_cert: bool,
}

/// The fields a stored section must carry if a request is ever to be sent, and
/// the credential kind it names.
///
/// Checked here rather than left to `is_configured`, which answers the same
/// question but only as a boolean on a later GET: an operator who saved a blank
/// username should be told at the save, and by which field.
fn validate(request: &ReplaceRequest) -> Result<PveAuthKind, &'static str> {
    let auth = PveAuthKind::parse(&request.auth).ok_or("invalidAuth")?;
    if request.url.trim().is_empty() {
        // An empty address is how a section is cleared, and is not a mistake.
        return Ok(auth);
    }
    validate_url(&request.url)?;
    if request.username.trim().is_empty() {
        return Err("missingUsername");
    }
    // The realm is half of the account name for both kinds: the header a token
    // is presented as is `PVEAPIToken=<user>@<realm>!<id>=<secret>`.
    if request.realm.trim().is_empty() {
        return Err("missingRealm");
    }
    if auth == PveAuthKind::Token && request.token_id.trim().is_empty() {
        return Err("missingTokenId");
    }
    Ok(auth)
}

pub async fn replace_settings(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Pve, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let auth = match validate(&request) {
        Ok(auth) => auth,
        Err(code) => return Ok(bad_request(code, None)),
    };

    // The file's own lock, not one of this module's: this reads and rewrites
    // `config.toml`, which `/settings`, `/push`, `/desktop` and `/ai/settings`
    // also do.
    let _config_guard = app_state.config_write.lock().await;
    let mut config = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let stored = config.get_pve();
    let secret = match request.secret {
        // Absent or `null`: keep. Matching push's rule, which exists so that a
        // client that cannot read a credential cannot clear it by accident.
        None => stored.secret.clone(),
        Some(secret) if secret.is_empty() => None,
        Some(secret) => Some(secret),
    };
    let pve = PveConfig {
        url: request.url.trim().trim_end_matches('/').to_string(),
        auth,
        username: request.username.trim().to_string(),
        realm: request.realm.trim().to_string(),
        token_id: request.token_id.trim().to_string(),
        secret,
        ignore_cert: request.ignore_cert,
    };
    config.pve = Some(pve.clone());
    if let Err(e) = config_file::write(&config) {
        tracing::warn!("pve: could not write the config: {e}");
        return Ok(internal_error("config_unavailable"));
    }

    // The address is this agent's own cluster and the account is a name PVE
    // prints itself; the secret is not in the row and neither is anything
    // derived from it.
    Event::new(Kind::Pve, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject("settings")
        .detail(format!(
            "auth={} account={} secret={}",
            pve.auth.as_str(),
            pve.account(),
            if pve.secret.is_some() { "set" } else { "none" }
        ))
        .record(&app_state.db)
        .await;

    Ok(HttpResponse::Ok().json(&SettingsView::of(&pve, true)))
}

// --- Reading the cluster ---

#[derive(Serialize)]
struct ResourcesResponse {
    /// PVE's own release string, e.g. `8.2.4`, when it gave one. Absent rather
    /// than an error: a label is not worth failing a listing over.
    #[serde(skip_serializing_if = "Option::is_none")]
    release: Option<String>,
    /// Sorted by `sbm_parser::pve`, so two refreshes of one page show the same
    /// rows in the same places whatever order the cluster answered in.
    resources: Vec<PveResource>,
    /// Whether this caller may act on a guest.
    editable: bool,
}

/// A configured cluster and a credential for it, or the refusal to answer with.
///
/// The one place both read handlers go through, so the `notConfigured` refusal
/// and the client's construction are written once.
async fn connect() -> Result<(PveClient, client::Credential), HttpResponse> {
    let config = read_config().await?;
    let pve = config.get_pve();
    if !pve.is_configured() {
        return Err(bad_request("notConfigured", None));
    }
    let client = PveClient::new(&pve).map_err(failure)?;
    let credential = match client.authenticate().await {
        Ok(credential) => credential,
        Err(error) => {
            // Its own line in the log: a refused credential is the one failure
            // an operator has to change something to fix.
            tracing::warn!("pve: authentication failed: {}", error.code());
            return Err(failure(error));
        }
    };
    Ok((client, credential))
}

pub async fn resources(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);

    let (client, credential) = match connect().await {
        Ok(connected) => connected,
        Err(response) => return Ok(response),
    };
    let resources = match client.resources(&credential).await {
        Ok(resources) => resources,
        Err(error) => {
            tracing::warn!("pve: could not read the cluster: {}", error.code());
            return Ok(failure(error));
        }
    };
    // A second request with the same credential, and its failure is not the
    // listing's: the release is a label on a page drawn from the resources.
    let release = match client.version(&credential).await {
        Ok(release) => release,
        Err(error) => {
            tracing::debug!("pve: no release from this cluster: {}", error.code());
            None
        }
    };

    Ok(HttpResponse::Ok().json(&ResourcesResponse {
        release,
        resources,
        editable,
    }))
}

// --- Acting on a guest ---

#[derive(Deserialize)]
pub struct ControlRequest {
    node: String,
    /// `qemu` or `lxc`. A string rather than an enum: a caller that misspells
    /// one gets `invalidKind` rather than a deserialization error ntex answers
    /// itself, which the panel could not phrase.
    kind: String,
    vmid: u32,
    action: String,
}

pub async fn control(
    req: HttpRequest,
    body: web::types::Json<ControlRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Pve, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let Some(kind) = PveGuestKind::parse(&request.kind) else {
        return Ok(bad_request("invalidKind", None));
    };
    let Some(action) = PveAction::parse(&request.action) else {
        return Ok(bad_request("invalidAction", None));
    };
    let subject = format!("{} {}/{}", action.as_str(), kind.as_str(), request.vmid);

    // Composed and validated before the cluster is dialed: a node name this
    // agent would not put in a path, or a vmid outside PVE's range, is the
    // caller's mistake, and a login spent on it is a request PVE never needed
    // to see.
    let path = match control_path(&request.node, kind, request.vmid, action) {
        Ok(path) => path,
        Err(error) => return Ok(bad_request(error.as_str(), None)),
    };

    let (client, credential) = match connect().await {
        Ok(connected) => connected,
        Err(response) => return Ok(response),
    };
    let outcome = client.control(&credential, &path).await;

    // The node is what makes the row readable in a cluster, and the code is
    // what says a refused action was refused rather than never asked.
    match outcome {
        Ok(upid) => {
            Event::new(Kind::Pve, Action::Write, Outcome::Ok)
                .remote_ip(remote_ip)
                .subject(subject)
                .detail(format!("node={} upid={}", request.node, upid.as_deref().unwrap_or("-")))
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::Ok().json(&ControlResponse { upid }))
        }
        Err(error) => {
            tracing::warn!("pve: {} failed: {}", subject, error.code());
            Event::new(Kind::Pve, Action::Write, Outcome::Error)
                .remote_ip(remote_ip)
                .subject(subject)
                .detail(format!("node={} error={}", request.node, error.code()))
                .record(&app_state.db)
                .await;
            Ok(failure(error))
        }
    }
}

#[derive(Serialize)]
struct ControlResponse {
    /// PVE's task id for the change, when it gave one. A client may show it and
    /// nothing depends on it.
    #[serde(skip_serializing_if = "Option::is_none")]
    upid: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `auth` is a string on the wire, so it is one here: a test that passed
    /// the enum would not exercise the misspelling the refusal exists for.
    fn request(url: &str, auth: &str, username: &str, realm: &str, token: &str) -> ReplaceRequest {
        ReplaceRequest {
            url: url.to_string(),
            auth: auth.to_string(),
            username: username.to_string(),
            realm: realm.to_string(),
            token_id: token.to_string(),
            secret: None,
            ignore_cert: false,
        }
    }

    #[test]
    fn a_password_credential_needs_an_account_and_a_realm() {
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "password",
                "root",
                "pam",
                ""
            )),
            Ok(PveAuthKind::Password)
        );
        // The realm is half of the account name and PVE will not accept a login
        // without it.
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "password",
                "root",
                " ",
                ""
            )),
            Err("missingRealm")
        );
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "password",
                " ",
                "pam",
                ""
            )),
            Err("missingUsername")
        );
        // A password credential stores no token id, and a leftover one is not a
        // reason to refuse the save.
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "password",
                "root",
                "pam",
                "old"
            )),
            Ok(PveAuthKind::Password)
        );
    }

    #[test]
    fn a_token_credential_needs_an_id_beside_the_account() {
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "token",
                "root",
                "pam",
                "automation"
            )),
            Ok(PveAuthKind::Token)
        );
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "token",
                "root",
                "pam",
                " "
            )),
            Err("missingTokenId")
        );
        // The realm is required for a token too: the header PVE wants is
        // `PVEAPIToken=<user>@<realm>!<id>=<secret>`.
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "token",
                "root",
                " ",
                "automation"
            )),
            Err("missingRealm")
        );
    }

    #[test]
    fn a_credential_kind_this_build_does_not_have_is_refused_rather_than_defaulted() {
        // A misspelling that defaulted would be stored as a password — a login
        // that fails every time, with the saved value looking right.
        assert_eq!(
            validate(&request(
                "https://pve.example.com:8006",
                "Token",
                "root",
                "pam",
                "automation"
            )),
            Err("invalidAuth")
        );
        assert_eq!(
            validate(&request("https://pve.example.com:8006", "", "root", "pam", "")),
            Err("invalidAuth")
        );
    }

    #[test]
    fn an_empty_address_clears_a_section_rather_than_failing() {
        assert_eq!(
            validate(&request("", "password", "", "", "")),
            Ok(PveAuthKind::Password)
        );
        assert_eq!(
            validate(&request("   ", "password", "", "", "")),
            Ok(PveAuthKind::Password)
        );
        // A URL that cannot be sent to is refused by the client's own check.
        assert_eq!(
            validate(&request(
                "pve.example.com:8006",
                "password",
                "root",
                "pam",
                ""
            )),
            Err("invalidUrl")
        );
    }

    #[test]
    fn a_settings_view_never_carries_the_secret() {
        let pve = PveConfig {
            url: "https://pve.example.com:8006".to_string(),
            username: "root".to_string(),
            realm: "pam".to_string(),
            secret: Some("hunter2".to_string()),
            ..PveConfig::default()
        };
        let view = SettingsView::of(&pve, true);
        assert!(view.secret.is_none(), "the secret is write-only");
        assert!(view.secret_set);
        assert!(view.configured);

        // Serialized too: the field is present as `null`, which is what a
        // client round-trips as "keep what is stored".
        let json = serde_json::to_value(&view).expect("serializable");
        assert!(!json.to_string().contains("hunter2"));
        assert_eq!(json["secret"], serde_json::Value::Null);
        assert_eq!(json["secret_set"], serde_json::json!(true));
    }
}
