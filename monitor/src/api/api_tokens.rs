//! `/api/v1/api-tokens` (issue #1681).
//!
//! Panel JWT only. Creating one asks for the account's password again, the
//! same way an account change does: a stolen session must not be enough to
//! mint a credential that outlives it. Admins can list and revoke every
//! account's tokens; everyone else sees only their own.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use crate::api::admin;
use crate::api::authz::{self, Caller, error};
use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::db::api_tokens::{self, ApiToken, DEFAULT_TTL_DAYS, MAX_TTL_DAYS};
use crate::utils::error::Result;
use crate::utils::secrets;

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

fn bad_request(message: &str) -> HttpResponse {
    error(StatusCode::BAD_REQUEST, "bad_request", message)
}

fn not_found(message: &str) -> HttpResponse {
    error(StatusCode::NOT_FOUND, "not_found", message)
}

fn valid_name(name: &str) -> bool {
    (1..=64).contains(&name.len())
        && name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b' '))
}

#[derive(Deserialize)]
struct NewToken {
    name: String,
    #[serde(default)]
    scopes: Vec<String>,
    /// Days until expiry. Omitted is [`DEFAULT_TTL_DAYS`].
    expires_days: Option<i64>,
    current_password: Option<String>,
}

#[derive(Serialize)]
struct TokenView {
    id: String,
    subject: String,
    name: String,
    scopes: Vec<String>,
    created_at: i64,
    expires_at: i64,
    last_used_at: Option<i64>,
    last_used_ip: Option<String>,
}

impl From<ApiToken> for TokenView {
    fn from(token: ApiToken) -> Self {
        Self {
            id: token.id,
            subject: token.subject,
            name: token.name,
            scopes: token.scopes,
            created_at: token.created_at,
            expires_at: token.expires_at,
            last_used_at: token.last_used_at,
            last_used_ip: token.last_used_ip,
        }
    }
}

async fn audit(req: &HttpRequest, state: &AppState, caller: &Caller, action: Action, detail: String) {
    Event::new(Kind::Admin, action, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(req))
        .detail(detail)
        .record(&state.db)
        .await;
}

/// Own tokens, or every token when an admin sends `all=1`.
pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let all = req.query_string().split('&').any(|part| part == "all=1" || part == "all=true");
    let tokens = if all {
        if !caller.is_admin() {
            return Ok(error(
                StatusCode::FORBIDDEN,
                "forbidden",
                "Only an admin may list every account's tokens",
            ));
        }
        api_tokens::list_all(&state.db).await?
    } else {
        api_tokens::list_for(&state.db, &caller.username).await?
    };
    let views: Vec<TokenView> = tokens.into_iter().map(TokenView::from).collect();
    Ok(HttpResponse::Ok().json(&views))
}

pub async fn create(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let body: NewToken = match serde_json::from_value(body.into_inner()) {
        Ok(body) => body,
        Err(e) => return Ok(bad_request(&e.to_string())),
    };
    require!(admin::reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    if !valid_name(&body.name) {
        return Ok(bad_request(
            "name must be 1..=64 letters, digits, space, or ._- ",
        ));
    }
    if let Err(e) = api_tokens::parse_scopes(&body.scopes, caller.grants()) {
        return Ok(bad_request(&e));
    }
    let days = body.expires_days.unwrap_or(DEFAULT_TTL_DAYS);
    if !(1..=MAX_TTL_DAYS).contains(&days) {
        return Ok(bad_request(&format!(
            "expires_days must be 1..={MAX_TTL_DAYS}"
        )));
    }
    let id = secrets::random_hex(16)?;
    let secret = format!("{}{}", api_tokens::PREFIX, secrets::random_hex(32)?);
    let now = chrono::Utc::now().timestamp();
    let expires_at = now + days * 86_400;
    api_tokens::insert(
        &state.db,
        &id,
        &caller.username,
        &body.name,
        &api_tokens::hash(&secret),
        &api_tokens::scope_names_json(&body.scopes)?,
        now,
        expires_at,
    )
    .await?;
    audit(
        &req,
        &state,
        &caller,
        Action::Write,
        format!("created api token {id}"),
    )
    .await;
    Ok(HttpResponse::Ok().json(&serde_json::json!({
        "id": id,
        "name": body.name,
        "token": secret,
        "scopes": body.scopes,
        "created_at": now,
        "expires_at": expires_at,
    })))
}

pub async fn revoke(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    path: web::types::Path<String>,
) -> Result<HttpResponse> {
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let id = path.into_inner();
    let Some(token) = api_tokens::get(&state.db, &id).await? else {
        return Ok(not_found("No such token"));
    };
    if token.subject != caller.username && !caller.is_admin() {
        return Ok(error(
            StatusCode::FORBIDDEN,
            "forbidden",
            "Only an admin may revoke another account's token",
        ));
    }
    api_tokens::delete(&state.db, &id).await?;
    audit(
        &req,
        &state,
        &caller,
        Action::Close,
        format!("revoked api token {id}"),
    )
    .await;
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "revoked" })))
}
