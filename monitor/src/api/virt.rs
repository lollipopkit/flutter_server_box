//! `/api/v1/virt` — the panel's Virtualization page: this machine's guests,
//! whether it runs Proxmox VE or libvirt.
//!
//! - `POST /virt`: the host and its guests (`sbm_virt::model::HostView`). A
//!   POST because a libvirt host may need the operator's sudo password,
//!   which a body carries and a URL must not.
//! - `POST /virt/power`: a power action on one guest.
//! - `GET /virt/pve`, `PUT /virt/pve`, `DELETE /virt/pve`: how this agent
//!   reaches the PVE API — never a secret (`has_password`,
//!   `has_token_secret`); a secret of `null` keeps the stored one.
//! - `POST /virt/pve/cert`: pins the certificate the API presented.
//! - `POST /virt/pve/tfa`: the TOTP code a password login is waiting for.
//!
//! Everything said to the host is `sbm_virt`'s, the crate the app reaches
//! over FFI: the PVE client (one session per agent, kept between requests —
//! a ticket lasts two hours, and an account with TOTP would otherwise be
//! asked for a code on every refresh) and the libvirt scripts with their
//! mapping onto the same model.
//!
//! A host's failure is never this agent's status: it is answered 200 with
//! `error` (`sbm_virt::error::Error`), the state the page shows — a PVE login
//! refused with 401 would otherwise log the panel out.
//!
//! # Privilege
//!
//! `virt` to see and control (`docs/dev/monitor-permissions.md`). Admin to
//! change how the API is reached or to pin its certificate, since those
//! decide where the agent sends a password or a token.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use sbm_parser::SystemType;
use sbm_virt::error::{Error as VirtError, ErrorKind};
use sbm_virt::libvirt::{self, VirtHostProbe, host as lv};
use sbm_virt::model::{HostKind, HostView, PowerAction};
use sbm_virt::pve::http::{TcpDial, TlsConnector};
use sbm_virt::pve::{self, Auth, Client};
use sbm_virt::rates::RateTracker;

use super::authz;
use super::exec::ExecResponse;
use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

const MAX_ADDR: usize = 512;
const MAX_IDENT: usize = 256;

/// What this agent keeps between requests.
#[derive(Default)]
pub struct VirtState {
    /// The client for the stored PVE configuration, made on first use and
    /// told when the configuration changes.
    pve: tokio::sync::Mutex<Option<Arc<Client>>>,
    libvirt: tokio::sync::Mutex<LibvirtState>,
}

struct LibvirtState {
    rates: RateTracker,
    /// `pool-capabilities`, read once: None until read, `Some(None)` where
    /// the host could not say.
    pool_types: Option<Option<Vec<String>>>,
    /// libvirt refused this account once: every script goes through sudo
    /// from then on, as the app's backend does.
    via_sudo: bool,
}

impl Default for LibvirtState {
    fn default() -> Self {
        Self { rates: RateTracker::new(false), pool_types: None, via_sudo: false }
    }
}

// ---------------------------------------------------------------------------
// Wire shapes
// ---------------------------------------------------------------------------

#[derive(Deserialize, Default)]
pub struct LoadRequest {
    /// The operator's sudo password, for a libvirt that refuses this agent's
    /// account. Used for this request only; never stored.
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct LoadResponse {
    /// What manages guests here; None where nothing does (or the platform
    /// has no such thing: `supported` false).
    host: Option<HostKind>,
    supported: bool,
    /// PVE runs here and this agent has a configuration for its API.
    pve_configured: bool,
    probe: Option<VirtHostProbe>,
    view: Option<HostView>,
    error: Option<VirtError>,
}

#[derive(Deserialize)]
pub struct PowerRequest {
    guest: String,
    action: PowerAction,
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct PowerResponse {
    error: Option<VirtError>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PveAuthKind {
    Password,
    Token,
}

impl PveAuthKind {
    fn as_str(self) -> &'static str {
        match self {
            PveAuthKind::Password => "password",
            PveAuthKind::Token => "token",
        }
    }
}

#[derive(Serialize)]
struct PveView {
    configured: bool,
    addr: Option<String>,
    auth: Option<PveAuthKind>,
    username: Option<String>,
    has_password: bool,
    token_id: Option<String>,
    has_token_secret: bool,
    cert_sha256: Option<String>,
    /// Whether this caller may change it.
    editable: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PveInput {
    addr: String,
    auth: PveAuthKind,
    #[serde(default)]
    username: Option<String>,
    /// `null` keeps the stored password; a string replaces it.
    #[serde(default)]
    password: Option<String>,
    #[serde(default)]
    token_id: Option<String>,
    /// `null` keeps the stored secret; a string replaces it.
    #[serde(default)]
    token_secret: Option<String>,
    #[serde(default)]
    cert_sha256: Option<String>,
}

#[derive(Deserialize)]
pub struct CertRequest {
    fingerprint: String,
}

#[derive(Deserialize)]
pub struct TfaRequest {
    code: String,
}

fn refusal(status: StatusCode, error: &'static str) -> HttpResponse {
    HttpResponse::build(status).json(&serde_json::json!({ "error": error }))
}

fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("virt: {e}");
    refusal(StatusCode::INTERNAL_SERVER_ERROR, "internal")
}

// ---------------------------------------------------------------------------
// The host
// ---------------------------------------------------------------------------

pub async fn load(
    req: HttpRequest,
    body: Option<web::types::Json<LoadRequest>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt load").await {
        return Ok(refused);
    }
    let password = body.and_then(|b| b.into_inner().password).filter(|p| !p.is_empty());
    let mut answer = LoadResponse {
        host: None,
        supported: unix(),
        pve_configured: false,
        probe: None,
        view: None,
        error: None,
    };
    match pve_client(&state).await {
        Ok(Some(client)) => {
            answer.host = Some(HostKind::Pve);
            answer.pve_configured = true;
            match client.load().await {
                Ok(view) => answer.view = Some(view),
                Err(e) => answer.error = Some(e),
            }
            return Ok(HttpResponse::Ok().json(&answer));
        }
        Ok(None) => {}
        Err(e) => return Ok(internal_error(&e)),
    }
    if !answer.supported {
        return Ok(HttpResponse::Ok().json(&answer));
    }
    // Which manager runs here. A libvirt that refuses this account is still
    // libvirt: the refusal is what sudo is asked about next.
    let probe = match machine::as_self(&libvirt::probe_script(), &state.remote_access.exec).await {
        Ok(out) => libvirt::parse_probe(&combined(&out)),
        Err(e) => {
            answer.error = Some(VirtError::msg(ErrorKind::Unreachable, e.to_string()));
            return Ok(HttpResponse::Ok().json(&answer));
        }
    };
    let libvirt_here = match probe {
        Ok(probe) => {
            let pve = probe.pve.is_some();
            let found = probe.libvirt.is_some();
            answer.probe = Some(probe);
            if pve {
                // Not a host until an admin says how to reach its API.
                answer.host = Some(HostKind::Pve);
                return Ok(HttpResponse::Ok().json(&answer));
            }
            found
        }
        Err(libvirt::VirtError::PermissionDenied { .. }) => true,
        Err(e) => {
            answer.error = Some(lv::error_of(&e, false));
            return Ok(HttpResponse::Ok().json(&answer));
        }
    };
    if !libvirt_here {
        return Ok(HttpResponse::Ok().json(&answer));
    }
    answer.host = Some(HostKind::Libvirt);
    match libvirt_view(&state, password.as_deref()).await {
        Ok(view) => answer.view = Some(view),
        Err(e) => answer.error = Some(e),
    }
    Ok(HttpResponse::Ok().json(&answer))
}

pub async fn power(
    req: HttpRequest,
    body: web::types::Json<PowerRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let request = body.into_inner();
    let action = serde_json::to_value(request.action).ok().and_then(|v| v.as_str().map(str::to_owned));
    let what = format!("virt {} {}", action.as_deref().unwrap_or("?"), request.guest);
    let gated = match machine::gate(&req, &state, Grant::Virt, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let record = |action, outcome, why: Option<&str>| {
        Event::new(Kind::Machine, action, outcome)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip.clone())
            .detail(match why {
                Some(why) => format!("{what}: {why}"),
                None => what.clone(),
            })
    };
    // Recorded before it runs: what was asked of the machine is on file
    // whatever happens next.
    record(Action::Open, Outcome::Ok, None).record(&state.db).await;
    let password = request.password.as_deref().filter(|p| !p.is_empty());
    let result = match pve_client(&state).await {
        Ok(Some(client)) => pve_power(&client, &request.guest, request.action).await,
        Ok(None) if unix() => libvirt_power(&state, &request.guest, request.action, password).await,
        Ok(None) => Err(VirtError::new(ErrorKind::Unsupported)),
        Err(e) => return Ok(internal_error(&e)),
    };
    if let Err(e) = &result {
        record(Action::Close, Outcome::Error, Some(&format!("{:?}", e.kind))).record(&state.db).await;
    }
    Ok(HttpResponse::Ok().json(&PowerResponse { error: result.err() }))
}

async fn pve_power(client: &Client, id: &str, action: PowerAction) -> Result<(), VirtError> {
    // What the guest offers now, not what a page drawn a while ago showed.
    let view = client.load().await?;
    let guest = view
        .guests
        .iter()
        .find(|g| g.id == id)
        .ok_or_else(|| VirtError::msg(ErrorKind::ActionFailed, format!("no guest {id}")))?;
    client.power(guest, action).await
}

async fn libvirt_power(state: &AppState, id: &str, action: PowerAction, password: Option<&str>) -> Result<(), VirtError> {
    let overview = run_libvirt(state, &libvirt::overview_script(), password, false, libvirt::parse_overview).await?;
    let domain = overview
        .domains
        .iter()
        .find(|d| d.uuid == id)
        .ok_or_else(|| VirtError::msg(ErrorKind::ActionFailed, format!("no guest {id}")))?;
    let guest = lv::guest_of(domain);
    let plan = lv::power_plan(&guest, action).ok_or_else(|| {
        VirtError::detail(ErrorKind::Unsupported, sbm_virt::error::Detail::NotOffered)
    })?;
    // A crashed domain's start is a destroy first; that destroy finding
    // nothing to destroy (`invalid state`) means it is gone already.
    let crashed_start = plan.len() > 1;
    for (i, step) in plan.into_iter().enumerate() {
        let gone_is_fine = crashed_start && i == 0;
        let parse = |raw: &str| match libvirt::parse_action(raw) {
            Err(libvirt::VirtError::InvalidState { .. }) if gone_is_fine => Ok(()),
            other => other,
        };
        run_libvirt(state, &libvirt::action_script(step, &domain.uuid), password, true, parse).await?;
    }
    Ok(())
}

async fn libvirt_view(state: &AppState, password: Option<&str>) -> Result<HostView, VirtError> {
    let overview = run_libvirt(state, &libvirt::overview_script(), password, false, libvirt::parse_overview).await?;
    let read = state.virt.libvirt.lock().await.pool_types.is_some();
    if !read {
        // Best effort: where it cannot be said, every type is offered.
        let types = run_libvirt(state, &libvirt::pool_types_script(), password, false, |raw| {
            Ok(libvirt::parse_pool_types(raw))
        })
        .await
        .unwrap_or(None);
        state.virt.libvirt.lock().await.pool_types = Some(types);
    }
    let mut lv_state = state.virt.libvirt.lock().await;
    let pool_types = lv_state.pool_types.clone().flatten();
    let at = chrono::Utc::now().timestamp_millis();
    // `vol-upload` needs a channel that carries bytes; this agent's command
    // runner does not.
    Ok(lv::view_of(&overview, &mut lv_state.rates, at, pool_types.as_deref(), false))
}

/// Runs a libvirt script and parses it: as this account, and through sudo
/// once libvirt has refused it (from then on, every time).
async fn run_libvirt<T>(
    state: &AppState,
    script: &str,
    password: Option<&str>,
    action: bool,
    parse: impl Fn(&str) -> Result<T, libvirt::VirtError>,
) -> Result<T, VirtError> {
    let limits = &state.remote_access.exec;
    let mut refused = None;
    if !state.virt.libvirt.lock().await.via_sudo {
        let out = machine::as_self(script, limits).await.map_err(unreachable)?;
        match parse(&combined(&out)) {
            Err(libvirt::VirtError::PermissionDenied { message }) => {
                refused = Some(message);
                state.virt.libvirt.lock().await.via_sudo = true;
            }
            other => return other.map_err(|e| lv::error_of(&e, action)),
        }
    }
    let out = machine::as_root(script, password, limits).await.map_err(unreachable)?;
    if let Some(e) = lv::sudo_refusal(&out.stderr, password.is_some()) {
        return Err(e);
    }
    match parse(&combined(&out)) {
        // Output that is not the script's is sudo itself failing — not
        // installed, or this account not in sudoers. What the operator has to
        // change is libvirt's permission, so that is what is reported, with
        // sudo's words after it.
        Err(libvirt::VirtError::Malformed { .. }) => {
            let text = [refused.unwrap_or_default(), combined(&out).trim().to_owned()]
                .into_iter()
                .filter(|m| !m.is_empty())
                .collect::<Vec<_>>()
                .join("\n");
            Err(VirtError::msg(ErrorKind::PermissionDenied, text))
        }
        other => other.map_err(|e| lv::error_of(&e, action)),
    }
}

fn combined(out: &ExecResponse) -> String {
    format!("{}{}", out.stdout, out.stderr)
}

fn unreachable(e: std::io::Error) -> VirtError {
    VirtError::msg(ErrorKind::Unreachable, e.to_string())
}

/// The scripts are POSIX `sh`: Windows has neither them nor a hypervisor
/// either backend manages.
fn unix() -> bool {
    crate::monitoring::system_type() != SystemType::Windows
}

// ---------------------------------------------------------------------------
// The PVE configuration
// ---------------------------------------------------------------------------

#[derive(sqlx::FromRow, Clone)]
struct Row {
    addr: String,
    auth: String,
    username: Option<String>,
    password: Option<String>,
    token_id: Option<String>,
    token_secret: Option<String>,
    cert_sha256: Option<String>,
}

impl Row {
    fn config(&self) -> pve::Config {
        let auth = if self.auth == "token" {
            Auth::Token {
                id: self.token_id.clone().unwrap_or_default(),
                secret: self.token_secret.clone().unwrap_or_default(),
            }
        } else {
            Auth::Password {
                user: self.username.clone().unwrap_or_default(),
                password: self.password.clone().unwrap_or_default(),
            }
        };
        pve::Config { addr: self.addr.clone(), auth, cert_sha256: self.cert_sha256.clone() }
    }
}

async fn row(db: &SqlitePool) -> Result<Option<Row>, sqlx::Error> {
    sqlx::query_as::<_, Row>(
        "SELECT addr, auth, username, password, token_id, token_secret, cert_sha256 FROM virt_pve WHERE id = 1",
    )
    .fetch_optional(db)
    .await
}

/// The client for the stored configuration, None where there is none.
async fn pve_client(state: &AppState) -> Result<Option<Arc<Client>>, sqlx::Error> {
    let Some(row) = row(&state.db).await? else {
        *state.virt.pve.lock().await = None;
        return Ok(None);
    };
    let config = row.config();
    let mut held = state.virt.pve.lock().await;
    match held.as_ref() {
        Some(client) => {
            // Changed by an edit (a confirmed pin is already the client's own).
            client.update_config(config);
            Ok(Some(client.clone()))
        }
        None => {
            let connector = Arc::new(TlsConnector::new(Arc::new(TcpDial)));
            let client = Arc::new(Client::new(config, connector, pve::Options::default()));
            *held = Some(client.clone());
            Ok(Some(client))
        }
    }
}

pub async fn pve_get(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, Grant::Virt, "virt pve").await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    match row(&state.db).await {
        Ok(row) => Ok(HttpResponse::Ok().json(&view(row, gated.caller.is_admin()))),
        Err(e) => Ok(internal_error(&e)),
    }
}

fn view(row: Option<Row>, editable: bool) -> PveView {
    match row {
        None => PveView {
            configured: false,
            addr: None,
            auth: None,
            username: None,
            has_password: false,
            token_id: None,
            has_token_secret: false,
            cert_sha256: None,
            editable,
        },
        Some(row) => PveView {
            configured: true,
            auth: Some(if row.auth == "token" { PveAuthKind::Token } else { PveAuthKind::Password }),
            addr: Some(row.addr),
            username: row.username,
            has_password: row.password.is_some_and(|p| !p.is_empty()),
            token_id: row.token_id,
            has_token_secret: row.token_secret.is_some_and(|s| !s.is_empty()),
            cert_sha256: row.cert_sha256,
            editable,
        },
    }
}

pub async fn pve_put(
    req: HttpRequest,
    body: web::types::Json<PveInput>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::admin_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return Ok(refused),
    };
    let input = normalize(body.into_inner());
    if let Err(code) = validate(&input) {
        return Ok(refusal(StatusCode::BAD_REQUEST, code));
    }
    let result = store(&state.db, &input).await;
    let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
    Event::new(Kind::Machine, Action::Write, outcome)
        .subject(&caller.username)
        .remote_ip(super::ws::audit::peer_ip(&req))
        .detail(format!("virt pve set: {} ({})", input.addr, input.auth.as_str()))
        .record(&state.db)
        .await;
    if let Err(e) = result {
        return Ok(internal_error(&e));
    }
    match row(&state.db).await {
        Ok(row) => Ok(HttpResponse::Ok().json(&view(row, true))),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn pve_delete(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::admin_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return Ok(refused),
    };
    let result = sqlx::query("DELETE FROM virt_pve").execute(&state.db).await;
    if let Some(client) = state.virt.pve.lock().await.take() {
        client.close();
    }
    let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
    Event::new(Kind::Machine, Action::Write, outcome)
        .subject(&caller.username)
        .remote_ip(super::ws::audit::peer_ip(&req))
        .detail("virt pve remove")
        .record(&state.db)
        .await;
    match result {
        Ok(_) => Ok(HttpResponse::Ok().json(&view(None, true))),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// Pins the certificate the last refused connection presented, as the
/// client confirms it, and stores the pin.
pub async fn pve_cert(
    req: HttpRequest,
    body: web::types::Json<CertRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::admin_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return Ok(refused),
    };
    let client = match pve_client(&state).await {
        Ok(Some(client)) => client,
        Ok(None) => return Ok(refusal(StatusCode::NOT_FOUND, "notConfigured")),
        Err(e) => return Ok(internal_error(&e)),
    };
    let pin = match client.confirm_cert(&body.fingerprint) {
        Ok(pin) => pin,
        Err(e) => return Ok(HttpResponse::Ok().json(&PowerResponse { error: Some(e) })),
    };
    let result = sqlx::query("UPDATE virt_pve SET cert_sha256 = ?, updated_at = ? WHERE id = 1")
        .bind(&pin)
        .bind(chrono::Utc::now().to_rfc3339())
        .execute(&state.db)
        .await;
    let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
    Event::new(Kind::Machine, Action::Write, outcome)
        .subject(&caller.username)
        .remote_ip(super::ws::audit::peer_ip(&req))
        .detail(format!("virt pve pin: {pin}"))
        .record(&state.db)
        .await;
    match result {
        Ok(_) => Ok(HttpResponse::Ok().json(&PowerResponse { error: None })),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// The TOTP code for the login waiting on one. Whoever may see the host may
/// answer it: the code proves the second factor of the stored account, and
/// nothing about it can be changed from here.
pub async fn pve_tfa(
    req: HttpRequest,
    body: web::types::Json<TfaRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "virt pve tfa").await {
        return Ok(refused);
    }
    let client = match pve_client(&state).await {
        Ok(Some(client)) => client,
        Ok(None) => return Ok(refusal(StatusCode::NOT_FOUND, "notConfigured")),
        Err(e) => return Ok(internal_error(&e)),
    };
    let error = client.submit_tfa(&body.code).await.err();
    Ok(HttpResponse::Ok().json(&PowerResponse { error }))
}

fn normalize(input: PveInput) -> PveInput {
    let trimmed = |v: Option<String>| v.map(|v| v.trim().to_owned()).filter(|v| !v.is_empty());
    PveInput {
        addr: input.addr.trim().trim_end_matches('/').to_owned(),
        username: trimmed(input.username),
        token_id: trimmed(input.token_id),
        cert_sha256: input
            .cert_sha256
            .map(|c| sbm_redfish::cert::normalize_fingerprint(&c))
            .filter(|c| !c.is_empty()),
        ..input
    }
}

/// What PVE accepts as an API token id: a user id (`name@realm`), `!`, and
/// the token's own name, which starts with a letter (the app's
/// `PveConfig.tokenIdPattern`).
fn is_token_id(id: &str) -> bool {
    let Some((user, token)) = id.split_once('!') else { return false };
    let Some((name, realm)) = user.split_once('@') else { return false };
    let word = |s: &str| {
        s.starts_with(|c: char| c.is_ascii_alphabetic())
            && s.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-'))
    };
    !name.is_empty() && !name.contains(|c: char| c.is_whitespace() || matches!(c, ':' | '/' | '@' | '!')) && word(realm) && word(token)
}

fn validate(input: &PveInput) -> Result<(), &'static str> {
    let config = pve::Config {
        addr: input.addr.clone(),
        auth: Auth::Token { id: String::new(), secret: String::new() },
        cert_sha256: None,
    };
    if input.addr.len() > MAX_ADDR || config.base_uri().is_err() || input.addr.starts_with("http://") {
        return Err("invalidAddr");
    }
    match input.auth {
        PveAuthKind::Password => match &input.username {
            Some(u) if u.chars().count() <= MAX_IDENT && !u.chars().any(char::is_control) => {}
            _ => return Err("invalidUsername"),
        },
        PveAuthKind::Token => match &input.token_id {
            Some(id) if id.len() <= MAX_IDENT && is_token_id(id) => {}
            _ => return Err("invalidTokenId"),
        },
    }
    if let Some(cert) = &input.cert_sha256
        && !sbm_redfish::cert::is_fingerprint(cert)
    {
        return Err("invalidCertificate");
    }
    Ok(())
}

/// Writes the one row, carrying a secret sent as `null` over from what is
/// stored. A secret of the other auth is kept too, so switching back and
/// forth does not lose it.
async fn store(db: &SqlitePool, input: &PveInput) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    let stored: Option<(Option<String>, Option<String>)> =
        sqlx::query_as("SELECT password, token_secret FROM virt_pve WHERE id = 1")
            .fetch_optional(&mut *tx)
            .await?;
    let (old_password, old_secret) = stored.unwrap_or_default();
    let password = input.password.clone().or(old_password);
    let secret = input.token_secret.clone().or(old_secret);
    sqlx::query(
        "INSERT INTO virt_pve (id, addr, auth, username, password, token_id, token_secret, cert_sha256, updated_at) \
         VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?) \
         ON CONFLICT(id) DO UPDATE SET addr = excluded.addr, auth = excluded.auth, username = excluded.username, \
         password = excluded.password, token_id = excluded.token_id, token_secret = excluded.token_secret, \
         cert_sha256 = excluded.cert_sha256, updated_at = excluded.updated_at",
    )
    .bind(&input.addr)
    .bind(input.auth.as_str())
    .bind(&input.username)
    .bind(password)
    .bind(&input.token_id)
    .bind(secret)
    .bind(&input.cert_sha256)
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(&mut *tx)
    .await?;
    tx.commit().await
}

#[cfg(test)]
mod tests {
    use super::*;

    fn input(addr: &str, auth: PveAuthKind) -> PveInput {
        PveInput {
            addr: addr.into(),
            auth,
            username: Some("root".into()),
            password: None,
            token_id: Some("root@pam!sb".into()),
            token_secret: None,
            cert_sha256: None,
        }
    }

    #[test]
    fn token_ids_are_what_pve_accepts() {
        for ok in ["root@pam!sb", "ops@pve!panel-1", "a.b@pam!t_1"] {
            assert!(is_token_id(ok), "{ok}");
        }
        for bad in ["root@pam", "root!sb", "@pam!sb", "root@pam!1sb", "ro ot@pam!sb", "root@pam!", "root@1pam!sb"] {
            assert!(!is_token_id(bad), "{bad}");
        }
    }

    #[test]
    fn a_configuration_is_an_https_origin_with_its_account() {
        assert_eq!(validate(&input("https://127.0.0.1:8006", PveAuthKind::Token)), Ok(()));
        assert_eq!(validate(&input("http://127.0.0.1:8006", PveAuthKind::Token)), Err("invalidAddr"));
        assert_eq!(validate(&input("127.0.0.1:8006", PveAuthKind::Token)), Err("invalidAddr"));
        let no_user = PveInput { username: None, ..input("https://h:8006", PveAuthKind::Password) };
        assert_eq!(validate(&no_user), Err("invalidUsername"));
        let bad_token = PveInput { token_id: Some("root".into()), ..input("https://h:8006", PveAuthKind::Token) };
        assert_eq!(validate(&bad_token), Err("invalidTokenId"));
        let bad_pin = PveInput { cert_sha256: Some("zz".into()), ..input("https://h:8006", PveAuthKind::Token) };
        assert_eq!(validate(&normalize(bad_pin)), Err("invalidCertificate"));
    }
}
