//! `GET /api/v1/bmc` and the three endpoints beside it — a baseboard management
//! controller reached through this agent.
//!
//! # Why this is a proxy rather than a forwarded socket
//!
//! The app reaches a BMC directly over the network, and can only do so because
//! it is holding the credential itself. A panel in a browser cannot: Redfish is
//! not a CORS API, so the choice is between the credential going to the page or
//! the agent keeping it. It stays here. That also means a monitor-only server —
//! the ones with no sshd to forward a socket through — can manage a BMC, which
//! is what `/api/v1/stream/ws` cannot give it either, since the *browser* is the
//! one that would have to speak Redfish.
//!
//! # The credential is write-only, and the certificate is pinned
//!
//! `[bmc]` holds an address, an account, a password and a certificate
//! fingerprint. `GET /bmc/settings` answers `secret: null` and `secret_set`,
//! and a save sending `null` back keeps what is stored — `push` and `/ai/settings`
//! and `/pve`'s convention. Saving is `full_access`, and for `pve`'s reason plus
//! one more: an address can be changed while the stored password is kept, so a
//! caller who could only save could point this agent at their own service and
//! read the password out of the login that followed.
//!
//! The fingerprint is the whole of the TLS trust. `POST /bmc/probe` fetches what
//! an address presents *without sending anything*, which is the one moment a
//! certificate can be looked at before a password goes to it.
//!
//! # Authority
//!
//! Reading the machine and its readings needs only the panel login, and the
//! answer says `editable` so a page that may not act goes read-only rather than
//! failing on the first press. Controlling the power state, saving the
//! credential **and probing a certificate** are `full_access`, re-checked per
//! request — the probe because it dials an address the caller names, which
//! without the grant is a way to map a network the caller is not on.
//!
//! # Refusals
//!
//! Codes come from two places. `sbm_parser::redfish::RedfishFailure` — the
//! vocabulary the app already phrases — for everything about the machine:
//! `notAService`, `noSystem`, `forbidden`, `certificateRejected`, `unauthorized`,
//! `noCredential`, `preconditionRequired`, `unsupportedIntent`, `invalidResponse`,
//! `unreachable`. And this endpoint's own names for what a caller got wrong
//! before anything was dialed: `notConfigured`, `invalidUrl`, `missingUsername`,
//! `missingFingerprint`, `invalidIntent`.
//!
//! A transport failure is a 502 and everything else is a 400; the one status
//! that is never produced is the upstream's own 401, because the panel's client
//! logs the operator out on it and what failed here is the *agent's* credential
//! to a machine the operator is not logged in to.

pub mod client;

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use sbm_parser::redfish::{
    BmcSensors, PowerIntent, RedfishChassis, RedfishFailure, RedfishRoot, RedfishSystem,
    ResetRequest, normalize_fingerprint, pretty_fingerprint,
};

use self::client::{BmcClient, BmcFailure, Credential};
use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::config::{BmcConfig, Config};
use crate::core::config_file;

/// A refusal, as the panel reads it.
#[derive(Serialize)]
struct ErrorResponse {
    error: &'static str,
}

fn bad_request(error: &'static str) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error })
}

fn internal_error(error: &'static str) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse { error })
}

/// A failure as a status and a code. The one place that decides which is which.
fn failure(error: BmcFailure) -> HttpResponse {
    if error.is_transport() {
        HttpResponse::BadGateway().json(&ErrorResponse {
            error: error.code(),
        })
    } else {
        bad_request(error.code())
    }
}

/// The config as written, or the 500 for a file that cannot be read.
///
/// Read fresh off disk rather than from `AppState.config`, which is a startup
/// snapshot: a GET right after a save has to answer with what was saved.
async fn read_config() -> Result<Config, HttpResponse> {
    config_file::read().map_err(|e| {
        tracing::warn!("bmc: could not read the config: {e}");
        internal_error("config_unavailable")
    })
}

/// The settings as a client sees them: everything except the password.
#[derive(Serialize)]
struct SettingsView {
    configured: bool,
    url: String,
    username: String,
    /// Always `null`. Present rather than omitted, so a client that round-trips
    /// this body sends the null back and keeps what is stored.
    secret: Option<String>,
    /// Whether a password is stored. An empty string counts as not set.
    secret_set: bool,
    /// As stored and normalized, lowercase hex.
    fingerprint: String,
    /// The same, in the form a BMC's own interface prints it — what an operator
    /// compares against the page they are looking at.
    fingerprint_pretty: Option<String>,
    fingerprint_set: bool,
    /// Whether this caller may change any of it.
    editable: bool,
}

impl SettingsView {
    fn of(bmc: &BmcConfig, editable: bool) -> Self {
        let pin = bmc.pin();
        Self {
            configured: bmc.is_configured(),
            url: bmc.url.clone(),
            username: bmc.username.clone(),
            secret: None,
            secret_set: bmc.secret.as_deref().is_some_and(|s| !s.is_empty()),
            fingerprint: pin.clone().unwrap_or_default(),
            fingerprint_pretty: pin.as_deref().and_then(pretty_fingerprint),
            fingerprint_set: pin.is_some(),
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
        Ok(config) => Ok(HttpResponse::Ok().json(&SettingsView::of(&config.get_bmc(), editable))),
        Err(response) => Ok(response),
    }
}

/// A save. The whole section is replaced, so an omitted field is stored as its
/// type's default — `pve`'s rule, and `PveConfig`'s reasoning.
#[derive(Deserialize)]
pub struct ReplaceRequest {
    #[serde(default)]
    url: String,
    #[serde(default)]
    username: String,
    /// `null` or absent keeps the stored password, `""` clears it, anything
    /// else replaces it. No `from_index` counterpart: this is one section, not
    /// a list, so the sentinel is the field value itself.
    #[serde(default)]
    secret: Option<String>,
    /// Accepts what a person pastes — colons, spaces, dashes, either case — and
    /// refuses anything that is not a fingerprint.
    #[serde(default)]
    fingerprint: String,
}

/// What is wrong with the section a save would store, or the normalized pin.
fn validate(request: &ReplaceRequest) -> Result<String, &'static str> {
    if request.url.trim().is_empty() {
        // Clearing is not a mistake: it is how the credential is taken back out.
        return Ok(String::new());
    }
    client::validate_url(&request.url).map_err(|_| "invalidUrl")?;
    if request.username.trim().is_empty() {
        return Err("missingUsername");
    }
    // A section with an address and no pin is one nothing can be read through,
    // and the request that would find that out is a request carrying the
    // password. Refusing the save is what keeps the operator in the order that
    // reviews first.
    normalize_fingerprint(&request.fingerprint).ok_or("missingFingerprint")
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
        Event::new(Kind::Bmc, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let fingerprint = match validate(&request) {
        Ok(fingerprint) => fingerprint,
        Err(code) => return Ok(bad_request(code)),
    };

    // The file's own lock, not one of this module's: this reads and rewrites
    // `config.toml`, which `/settings`, `/push`, `/pve/settings`, `/desktop`
    // and `/ai/settings` also do.
    let _config_guard = app_state.config_write.lock().await;
    let mut config = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let stored = config.get_bmc();
    let secret = match request.secret {
        None => stored.secret.clone(),
        Some(secret) if secret.is_empty() => None,
        Some(secret) => Some(secret),
    };
    let bmc = BmcConfig {
        url: request.url.trim().to_string(),
        username: request.username.trim().to_string(),
        secret,
        fingerprint,
    };
    config.bmc = Some(bmc.clone());
    if let Err(e) = config_file::write(&config) {
        tracing::warn!("bmc: could not write the config: {e}");
        return Ok(internal_error("config_unavailable"));
    }

    Event::new(Kind::Bmc, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject("settings")
        .detail(format!(
            "account={} secret={} fingerprint={}",
            bmc.username,
            if bmc.secret.is_some() { "set" } else { "none" },
            if bmc.pin().is_some() { "set" } else { "none" }
        ))
        .record(&app_state.db)
        .await;

    Ok(HttpResponse::Ok().json(&SettingsView::of(&bmc, true)))
}

#[derive(Deserialize)]
pub struct ProbeRequest {
    /// The address to look at. Empty means the stored one, so the page's first
    /// step — "what is out there?" — needs no save first.
    #[serde(default)]
    url: String,
}

#[derive(Serialize)]
struct ProbeResponse {
    fingerprint: String,
    fingerprint_pretty: Option<String>,
}

/// What the certificate at an address is, without sending anything to it.
///
/// The handshake is meant to fail: nothing is pinned yet, and the caller is
/// asking what there is to review. Only a TLS hello leaves the machine, so this
/// is the one request that may be made to an address that has not been
/// reviewed — and the only one that is, since every other endpoint requires a
/// pin before it will speak.
///
/// **`full_access`, and not for the usual reason.** Nothing is read and nothing
/// is changed, but the address comes from the *body* and the agent dials it:
/// without the grant, a panel login could make this agent handshake every
/// address and port on its private network and read the answer back — the leaf
/// fingerprint, and a refusal told apart from an unreachable one — which is a
/// scanner and a certificate oracle on a network the caller is not on. It costs
/// the feature nothing to gate, because saving an address is `full_access` too:
/// probing exists to serve that save, and whoever may not save has nothing to
/// probe for.
pub async fn probe(
    req: HttpRequest,
    body: web::types::Json<ProbeRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Bmc, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }
    let request = body.into_inner();
    let url = if request.url.trim().is_empty() {
        match read_config().await {
            Ok(config) => config.get_bmc().url,
            Err(response) => return Ok(response),
        }
    } else {
        request.url.trim().to_string()
    };
    if url.trim().is_empty() {
        return Ok(bad_request("notConfigured"));
    }

    match client::probe_certificate(&url).await {
        Ok(fingerprint) => {
            let pretty = pretty_fingerprint(&fingerprint);
            Ok(HttpResponse::Ok().json(&ProbeResponse {
                fingerprint,
                fingerprint_pretty: pretty,
            }))
        }
        Err(error) => {
            tracing::warn!("bmc: the probe failed: {}", error.code());
            Ok(failure(error))
        }
    }
}

/// The machine, its chassis and the chassis' readings.
#[derive(Serialize)]
struct StateResponse {
    /// What the service root said it is. Reported, never branched on.
    version: Option<String>,
    product: Option<String>,
    vendor: Option<String>,
    system: RedfishSystem,
    /// Absent when the chassis could not be read, which is not a failed page:
    /// the power state and the machine's identity came from the system.
    #[serde(skip_serializing_if = "Option::is_none")]
    chassis: Option<RedfishChassis>,
    sensors: BmcSensors,
    /// Whether the readings were read at all. `false` with an empty `sensors`
    /// is the honest pair; an empty reading alone reads as a machine with no
    /// fans.
    sensors_read: bool,
    sensors_truncated: bool,
    /// Which intents this machine can actually be asked for, in the order a
    /// form offers them. An intent with nothing behind it is not offered,
    /// rather than offered and failing when pressed.
    intents: Vec<&'static str>,
    /// The `ResetType` each of those would send, so a page can say what pressing
    /// a button does.
    reset_types: Vec<IntentTarget>,
    editable: bool,
}

/// One offerable intent and the `ResetType` behind it.
#[derive(Serialize)]
struct IntentTarget {
    intent: &'static str,
    reset_type: String,
}

/// The intents this system can satisfy, and the request each would send.
fn offers(system: &RedfishSystem) -> Vec<(PowerIntent, ResetRequest)> {
    PowerIntent::ALL
        .into_iter()
        .filter_map(|intent| system.reset_request(intent).map(|request| (intent, request)))
        .collect()
}

pub async fn state(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);

    let (client, credential, root) = match connect().await {
        Ok(opened) => opened,
        Err(response) => return Ok(response),
    };
    let read = client.state_of(&root, &credential).await;
    // Closed before the answer is built, and after the read: the session this
    // agent opened is not left for the operator's own browser to trip over.
    client.close(&credential).await;

    let state = match read {
        Ok(state) => state,
        Err(error) => {
            tracing::warn!("bmc: could not read the machine: {}", error.code());
            return Ok(failure(error));
        }
    };
    let offered = offers(&state.system);
    let intents = offered.iter().map(|(intent, _)| intent.as_str()).collect();
    let reset_types = offered
        .into_iter()
        .map(|(intent, request)| IntentTarget {
            intent: intent.as_str(),
            reset_type: request.reset_type,
        })
        .collect();

    Ok(HttpResponse::Ok().json(&StateResponse {
        version: state.root.version,
        product: state.root.product,
        vendor: state.root.vendor,
        system: state.system,
        chassis: state.chassis,
        sensors: state.sensors,
        sensors_read: state.sensors_read,
        sensors_truncated: state.sensors_truncated,
        intents,
        reset_types,
        editable,
    }))
}

#[derive(Deserialize)]
pub struct ControlRequest {
    /// A `PowerIntent` spelling. A `String` rather than the enum so a
    /// misspelling is `invalidIntent` rather than ntex's own deserialization
    /// error.
    intent: String,
}

#[derive(Serialize)]
struct ControlResponse {
    /// The `ResetType` that was sent. Reported because it is what the operator
    /// actually asked for — `restart` falling back to `ForceRestart` is a
    /// different operation from `restart`, and the page says which.
    reset_type: String,
    /// The power state as it was *before* the request. The machine takes tens
    /// of seconds to move, so the answer says what it is moving from and the
    /// page re-reads until it changes.
    ///
    /// Deliberately not a confirmation loop: two minutes of polling inside one
    /// request is longer than any bound this agent sets, and `/exec`'s own rule
    /// is that work outliving a request is started and then polled in short
    /// ones.
    power_state: sbm_parser::redfish::PowerState,
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
        Event::new(Kind::Bmc, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let request = body.into_inner();
    let Some(intent) = PowerIntent::parse(&request.intent) else {
        return Ok(bad_request("invalidIntent"));
    };
    let subject = intent.as_str();

    let (client, credential, root) = match connect().await {
        Ok(opened) => opened,
        Err(response) => return Ok(response),
    };
    // The state is read before the request is sent, both to say what the
    // machine is moving from and because the intents are a property of the
    // system document rather than of what a caller asked for.
    let read = client.state_of(&root, &credential).await;
    let state = match read {
        Ok(state) => state,
        Err(error) => {
            client.close(&credential).await;
            tracing::warn!("bmc: {subject} could not be prepared: {}", error.code());
            return Ok(failure(error));
        }
    };
    // Nothing behind the intent is a real answer and is answered as one: the
    // page does not offer it, and a caller that asks anyway is told which
    // rather than sent a substitute — `ForceOff` is not a shutdown.
    let Some(reset) = state.system.reset_request(intent) else {
        client.close(&credential).await;
        return Ok(bad_request(RedfishFailure::UnsupportedIntent.as_str()));
    };

    let outcome = client.reset(&credential, &reset).await;
    client.close(&credential).await;

    match outcome {
        Ok(()) => {
            Event::new(Kind::Bmc, Action::Write, Outcome::Ok)
                .remote_ip(remote_ip)
                .subject(subject)
                .detail(format!("resetType={}", reset.reset_type))
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::Ok().json(&ControlResponse {
                reset_type: reset.reset_type,
                power_state: state.system.power_state,
            }))
        }
        Err(error) => {
            tracing::warn!("bmc: {subject} failed: {}", error.code());
            Event::new(Kind::Bmc, Action::Write, Outcome::Error)
                .remote_ip(remote_ip)
                .subject(subject)
                .detail(format!("error={}", error.code()))
                .record(&app_state.db)
                .await;
            Ok(failure(error))
        }
    }
}

/// A client and an open session, or the refusal to answer with.
///
/// The root is read here rather than twice: it is unauthenticated, it is what
/// the login needs to find the session endpoint, and the page shows what it
/// said.
async fn connect() -> Result<(BmcClient, Credential, RedfishRoot), HttpResponse> {
    let config = read_config().await?;
    let bmc = config.get_bmc();
    if !bmc.is_configured() {
        // The model's own code rather than a string of this module's: it is the
        // one refusal here the shared vocabulary already names.
        return Err(bad_request(RedfishFailure::NotConfigured.as_str()));
    }
    let client = BmcClient::new(&bmc).map_err(failure)?;
    let (credential, root) = match client.authenticate().await {
        Ok(opened) => opened,
        Err(error) => {
            tracing::warn!("bmc: authentication failed: {}", error.code());
            return Err(failure(error));
        }
    };
    Ok((client, credential, root))
}
