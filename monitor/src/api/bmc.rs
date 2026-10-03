//! `/api/v1/bmc` — the BMCs (Redfish) the panel reaches through this agent.
//!
//! - `GET /bmc`: the saved targets, never a password (`has_password`).
//! - `PUT /bmc`: replaces the set, in order; a `password` of `null` keeps the
//!   stored one, matched by id.
//! - `POST /bmc/probe`: the certificate an address presents, for the operator
//!   to review before it is pinned.
//! - `GET /bmc/{id}`: one target's state — power, the system, sensors.
//! - `POST /bmc/{id}/power`: a power action.
//!
//! The Redfish client is `sbm_redfish`, the one the app reaches over FFI too.
//! **One login per request, and the session is deleted again**: a BMC keeps a
//! handful of sessions and the operator's own browser usually holds one.
//! **A target without a pinned certificate is not dialled** (`require_pin`):
//! BMCs are self-signed, and accepting any certificate hands the password to
//! whatever answers on that address.
//!
//! A failure upstream is never this agent's status: a BMC answering 401 is
//! answered `502 {"error":"bmc","failure":"unauthorized"}`, since a 401 here
//! would log the panel out.
//!
//! # Privilege
//!
//! `virt` to see and control (`docs/dev/monitor-permissions.md`); admin to
//! change the targets or probe an address, since those decide where the agent
//! sends a password.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::Duration;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use sbm_redfish::client::{Auth, Client, ClientConfig};
use sbm_redfish::model::{PowerIntent, ResetRequest};

use super::authz;
use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

/// The most targets the set may hold.
pub const MAX_TARGETS: usize = 64;
const MAX_NAME: usize = 64;
const MAX_URL: usize = 512;
const MAX_IDENT: usize = 256;

/// How long one Redfish request may take. Reading sensors is one request per
/// member, each bounded by this.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
/// How long a certificate probe may take.
const PROBE_TIMEOUT: Duration = Duration::from_secs(10);

/// One target as a read answers it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TargetView {
    pub id: String,
    pub name: String,
    /// `https://host[:port]`.
    pub url: String,
    pub username: String,
    pub has_password: bool,
    /// The pinned leaf certificate, `sbm_redfish::cert`'s format.
    pub cert_sha256: Option<String>,
}

/// One target as a write sends it.
#[derive(Debug, Clone, Deserialize)]
pub struct TargetInput {
    pub id: String,
    pub name: String,
    pub url: String,
    pub username: String,
    /// `null` keeps the stored password; a string replaces it.
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub cert_sha256: Option<String>,
}

#[derive(Serialize)]
struct ListResponse {
    targets: Vec<TargetView>,
    /// Whether this caller may change the set.
    editable: bool,
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    targets: Vec<TargetInput>,
}

#[derive(Deserialize)]
pub struct ProbeRequest {
    url: String,
}

#[derive(Deserialize)]
pub struct PowerRequest {
    intent: PowerIntent,
}

/// A set refused before it was stored: a code and the row it is about.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Refusal {
    TooMany,
    InvalidId { index: usize },
    DuplicateId { index: usize },
    InvalidName { index: usize },
    DuplicateName { index: usize },
    InvalidUrl { index: usize },
    InvalidUsername { index: usize },
    InvalidCertificate { index: usize },
}

impl Serialize for Refusal {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let (code, index) = match *self {
            Refusal::TooMany => ("tooMany", None),
            Refusal::InvalidId { index } => ("invalidId", Some(index)),
            Refusal::DuplicateId { index } => ("duplicateId", Some(index)),
            Refusal::InvalidName { index } => ("invalidName", Some(index)),
            Refusal::DuplicateName { index } => ("duplicateName", Some(index)),
            Refusal::InvalidUrl { index } => ("invalidUrl", Some(index)),
            Refusal::InvalidUsername { index } => ("invalidUsername", Some(index)),
            Refusal::InvalidCertificate { index } => ("invalidCertificate", Some(index)),
        };
        serde_json::json!({ "error": code, "index": index }).serialize(serializer)
    }
}

fn refusal(status: StatusCode, error: &'static str) -> HttpResponse {
    HttpResponse::build(status).json(&serde_json::json!({ "error": error }))
}

fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("bmc: {e}");
    refusal(StatusCode::INTERNAL_SERVER_ERROR, "internal")
}

/// An upstream failure, as the panel reads it. The detail is
/// `sbm_redfish`'s, which never carries a credential or a response body.
fn upstream(e: &sbm_redfish::Error) -> HttpResponse {
    HttpResponse::BadGateway().json(&serde_json::json!({
        "error": "bmc",
        "failure": e.failure.as_str(),
        "detail": e.detail,
    }))
}

pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, Grant::Virt, "bmc list").await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    match load(&state.db).await {
        Ok(rows) => Ok(HttpResponse::Ok().json(&ListResponse {
            targets: rows.into_iter().map(|row| row.view()).collect(),
            editable: gated.caller.is_admin(),
        })),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn replace(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::admin_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return Ok(refused),
    };
    let targets: Vec<TargetInput> = body.into_inner().targets.into_iter().map(normalize).collect();
    if let Err(refusal) = validate(&targets) {
        return Ok(HttpResponse::BadRequest().json(&refusal));
    }

    let names = targets.iter().map(|t| t.name.as_str()).collect::<Vec<_>>().join(", ");
    let result = store(&state.db, &targets).await;
    let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
    Event::new(Kind::Machine, Action::Write, outcome)
        .subject(&caller.username)
        .remote_ip(super::ws::audit::peer_ip(&req))
        .detail(format!("bmc replace: {names}"))
        .record(&state.db)
        .await;
    match result {
        Ok(()) => match load(&state.db).await {
            Ok(rows) => Ok(HttpResponse::Ok().json(&ListResponse {
                targets: rows.into_iter().map(|row| row.view()).collect(),
                editable: true,
            })),
            Err(e) => Ok(internal_error(&e)),
        },
        Err(e) => Ok(internal_error(&e)),
    }
}

/// The certificate `url` presents, unverified: what the operator compares
/// with the BMC's own console before pinning it.
pub async fn probe(
    req: HttpRequest,
    body: web::types::Json<ProbeRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = authz::admin_caller(&req, &state).await {
        return Ok(refused);
    }
    let Some((host, port)) = host_port(&body.url) else {
        return Ok(refusal(StatusCode::BAD_REQUEST, "invalidUrl"));
    };
    match sbm_redfish::cert::fetch_server_cert(&host, port, PROBE_TIMEOUT).await {
        Ok(info) => Ok(HttpResponse::Ok().json(&info)),
        Err(e) => Ok(upstream(&e)),
    }
}

pub async fn status(
    req: HttpRequest,
    path: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Virt, "bmc status").await {
        return Ok(refused);
    }
    let client = match connect(&state.db, &path).await {
        Ok(client) => client,
        Err(response) => return Ok(response),
    };
    let snapshot = sbm_redfish::snapshot(&client, None).await;
    client.close().await;
    match snapshot {
        Ok(snapshot) => {
            // Which actions this system answers, so the panel offers those
            // without a second copy of how an intent maps to a reset type.
            let intents: Vec<PowerIntent> = match &snapshot.topology.system {
                Some(system) => PowerIntent::ALL
                    .iter()
                    .copied()
                    .filter(|intent| ResetRequest::build(system, *intent).is_some())
                    .collect(),
                None => Vec::new(),
            };
            Ok(HttpResponse::Ok().json(&serde_json::json!({
                "snapshot": snapshot,
                "intents": intents,
            })))
        }
        Err(e) => Ok(upstream(&e)),
    }
}

pub async fn power(
    req: HttpRequest,
    path: web::types::Path<String>,
    body: web::types::Json<PowerRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let intent = body.into_inner().intent;
    let what = format!("bmc power {}", intent.as_str());
    let gated = match machine::gate(&req, &state, Grant::Virt, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let client = match connect(&state.db, &path).await {
        Ok(client) => client,
        Err(response) => return Ok(response),
    };
    let result = match sbm_redfish::discover(&client).await {
        Ok(topology) => sbm_redfish::power(&client, &topology, intent).await,
        Err(e) => Err(e),
    };
    client.close().await;

    let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
    Event::new(Kind::Machine, Action::Write, outcome)
        .subject(&gated.caller.username)
        .remote_ip(gated.remote_ip)
        .detail(format!("{what} {}", path.as_str()))
        .record(&state.db)
        .await;
    match result {
        Ok(outcome) => Ok(HttpResponse::Ok().json(&serde_json::json!({ "outcome": outcome }))),
        Err(e) => Ok(upstream(&e)),
    }
}

/// A client for the target `id`, or the answer to give instead.
async fn connect(db: &SqlitePool, id: &str) -> Result<Client, HttpResponse> {
    let row = match sqlx::query_as::<_, Row>(
        "SELECT id, name, url, username, password, cert_sha256 FROM bmc_target WHERE id = ?",
    )
        .bind(id)
        .fetch_optional(db)
        .await
    {
        Ok(Some(row)) => row,
        Ok(None) => return Err(refusal(StatusCode::NOT_FOUND, "noSuchTarget")),
        Err(e) => return Err(internal_error(&e)),
    };
    Client::new(ClientConfig {
        base_url: row.url,
        user: row.username,
        password: row.password,
        pinned_sha256: row.cert_sha256,
        require_pin: true,
        auth: Auth::default(),
        timeout: REQUEST_TIMEOUT,
    })
    .map_err(|e| upstream(&e))
}

/// The host and port of an `https://host[:port]` address, the only shape a
/// target may have: Redfish is HTTPS, and a path or credentials in the
/// address would be somewhere for a mistake to hide.
fn host_port(url: &str) -> Option<(String, u16)> {
    let parsed = reqwest::Url::parse(url).ok()?;
    if parsed.scheme() != "https"
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || !matches!(parsed.path(), "" | "/")
        || parsed.query().is_some()
        || parsed.fragment().is_some()
    {
        return None;
    }
    let host = parsed.host_str()?.trim_start_matches('[').trim_end_matches(']').to_string();
    Some((host, parsed.port_or_known_default()?))
}

fn has_control(value: &str) -> bool {
    value.chars().any(char::is_control)
}

/// Trimmed as both editors trim, and the URL without a trailing slash, so
/// what is stored is what was checked.
fn normalize(t: TargetInput) -> TargetInput {
    TargetInput {
        id: t.id.trim().to_string(),
        name: t.name.trim().to_string(),
        url: t.url.trim().trim_end_matches('/').to_string(),
        username: t.username.trim().to_string(),
        cert_sha256: t
            .cert_sha256
            .map(|c| sbm_redfish::cert::normalize_fingerprint(&c))
            .filter(|c| !c.is_empty()),
        ..t
    }
}

/// The first problem in the set, in the order the caller sent it.
fn validate(targets: &[TargetInput]) -> Result<(), Refusal> {
    if targets.len() > MAX_TARGETS {
        return Err(Refusal::TooMany);
    }
    let mut ids = HashSet::new();
    let mut names = HashSet::new();
    for (index, t) in targets.iter().enumerate() {
        if t.id.is_empty() || t.id.len() > MAX_IDENT || has_control(&t.id) {
            return Err(Refusal::InvalidId { index });
        }
        if !ids.insert(t.id.as_str()) {
            return Err(Refusal::DuplicateId { index });
        }
        if t.name.is_empty() || t.name.chars().count() > MAX_NAME || has_control(&t.name) {
            return Err(Refusal::InvalidName { index });
        }
        if !names.insert(t.name.as_str()) {
            return Err(Refusal::DuplicateName { index });
        }
        if t.url.len() > MAX_URL || host_port(&t.url).is_none() {
            return Err(Refusal::InvalidUrl { index });
        }
        if t.username.is_empty() || t.username.chars().count() > MAX_IDENT || has_control(&t.username) {
            return Err(Refusal::InvalidUsername { index });
        }
        if let Some(cert) = &t.cert_sha256
            && !sbm_redfish::cert::is_fingerprint(cert)
        {
            return Err(Refusal::InvalidCertificate { index });
        }
    }
    Ok(())
}


#[derive(sqlx::FromRow)]
struct Row {
    id: String,
    name: String,
    url: String,
    username: String,
    password: Option<String>,
    cert_sha256: Option<String>,
}

impl Row {
    fn view(self) -> TargetView {
        TargetView {
            id: self.id,
            name: self.name,
            url: self.url,
            username: self.username,
            has_password: self.password.is_some_and(|p| !p.is_empty()),
            cert_sha256: self.cert_sha256,
        }
    }
}

async fn load(db: &SqlitePool) -> Result<Vec<Row>, sqlx::Error> {
    sqlx::query_as::<_, Row>(
        "SELECT id, name, url, username, password, cert_sha256 FROM bmc_target ORDER BY position",
    )
    .fetch_all(db)
    .await
}

/// Replaces the set in one transaction, carrying each kept password over by
/// id.
async fn store(db: &SqlitePool, targets: &[TargetInput]) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    let stored: HashMap<String, Option<String>> =
        sqlx::query_as::<_, (String, Option<String>)>("SELECT id, password FROM bmc_target")
            .fetch_all(&mut *tx)
            .await?
            .into_iter()
            .collect();
    sqlx::query("DELETE FROM bmc_target").execute(&mut *tx).await?;
    let now = chrono::Utc::now().to_rfc3339();
    for (position, t) in targets.iter().enumerate() {
        let password = match &t.password {
            Some(password) => Some(password.clone()),
            None => stored.get(&t.id).cloned().flatten(),
        };
        sqlx::query(
            "INSERT INTO bmc_target (id, name, url, username, password, cert_sha256, position, updated_at) \
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&t.id)
        .bind(&t.name)
        .bind(&t.url)
        .bind(&t.username)
        .bind(password)
        .bind(&t.cert_sha256)
        .bind(position as i64)
        .bind(&now)
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await
}

#[cfg(test)]
mod tests {
    use super::*;

    fn target(id: &str, name: &str) -> TargetInput {
        TargetInput {
            id: id.into(),
            name: name.into(),
            url: "https://10.0.0.9".into(),
            username: "root".into(),
            password: None,
            cert_sha256: None,
        }
    }

    #[test]
    fn a_target_is_an_https_origin() {
        assert_eq!(host_port("https://10.0.0.9"), Some(("10.0.0.9".into(), 443)));
        assert_eq!(host_port("https://bmc.lan:8443/"), Some(("bmc.lan".into(), 8443)));
        assert_eq!(host_port("https://[fe80::1]:443"), Some(("fe80::1".into(), 443)));
        for bad in ["http://10.0.0.9", "https://u:p@10.0.0.9", "https://h/redfish/v1", "https://h?x", "10.0.0.9", ""] {
            assert_eq!(host_port(bad), None, "{bad:?}");
        }
    }

    #[test]
    fn each_row_is_refused_at_its_index() {
        assert_eq!(validate(&[target("a", "one"), target("b", "two")]), Ok(()));
        let cases = [
            (target("a", "x"), Refusal::DuplicateId { index: 1 }),
            (target("b", "one"), Refusal::DuplicateName { index: 1 }),
            (target("b", ""), Refusal::InvalidName { index: 1 }),
            (TargetInput { url: "http://h".into(), ..target("b", "x") }, Refusal::InvalidUrl { index: 1 }),
            (TargetInput { username: String::new(), ..target("b", "x") }, Refusal::InvalidUsername { index: 1 }),
        ];
        for (second, refusal) in cases {
            assert_eq!(validate(&[target("a", "one"), second.clone()]), Err(refusal), "{second:?}");
        }
    }

    #[test]
    fn surrounding_whitespace_and_a_trailing_slash_are_not_stored() {
        let t = normalize(TargetInput { url: " https://h/ ".into(), ..target(" a ", " one ") });
        assert_eq!((t.id.as_str(), t.name.as_str(), t.url.as_str()), ("a", "one", "https://h"));
    }
}
