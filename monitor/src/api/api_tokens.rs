//! `/api-tokens` (#1681): management of MCP API tokens and the global MCP
//! policy (`mcp_policy`).
//!
//! - `GET /api-tokens`: lists every token (without its secret).
//! - `POST /api-tokens`: mints a token after re-entering the account password;
//!   defaults to all scopes and `allow_all` commands.
//! - `PUT /api-tokens/{id}`: updates a token's name, scopes and command rules.
//! - `DELETE /api-tokens/{id}`: revokes a token.
//! - `GET /api-tokens/policy`: reads the global MCP policy and any `config.toml`
//!   ceiling.
//! - `PUT /api-tokens/policy`: updates the global MCP policy.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use crate::api::respond::error;
use crate::api::server::AppState;
use crate::api::{admin, authz};
use crate::db::api_tokens::{self, CommandPolicy, McpPolicy, Scope, Token};
use crate::utils::error::{MonitorError, Result};

/// How long a new token lives unless its creator says otherwise.
const DEFAULT_DAYS: u32 = 90;

#[derive(Deserialize)]
pub struct CreateRequest {
    pub name: String,
    /// The account's password again — minting a long-lived credential costs it.
    pub password: String,
    /// Out of `Scope::MONITOR`; defaults to every scope when absent.
    #[serde(default)]
    pub scopes: Option<Vec<String>>,
    /// Per-token command policy; defaults to `allow_all` with no rules.
    #[serde(default)]
    pub commands: CommandPolicy,
    /// Days the token lives, [`DEFAULT_DAYS`] when absent.
    #[serde(default)]
    pub days: Option<u32>,
}

#[derive(Deserialize)]
pub struct UpdateRequest {
    pub name: String,
    pub scopes: Vec<String>,
    #[serde(default)]
    pub commands: CommandPolicy,
}

#[derive(Deserialize)]
pub struct PolicyRequest {
    pub scopes: Vec<String>,
    #[serde(default)]
    pub commands: CommandPolicy,
}

#[derive(Serialize)]
struct PolicyView {
    scopes: Vec<&'static str>,
    commands: CommandPolicy,
    /// Scopes allowed by `config.toml` (`[mcp]`), so the UI can show if an
    /// operator ceiling restricts a scope regardless of DB policy.
    config_scopes: Vec<&'static str>,
}

#[derive(Serialize)]
struct TokenView<'a> {
    id: i64,
    name: &'a str,
    scopes: Vec<&'static str>,
    commands: &'a CommandPolicy,
    created_at: &'a str,
    expires_at: &'a str,
    expired: bool,
    last_used_at: Option<&'a str>,
    last_used_ip: Option<&'a str>,
}

impl<'a> From<&'a Token> for TokenView<'a> {
    fn from(t: &'a Token) -> Self {
        TokenView {
            id: t.id,
            name: &t.name,
            scopes: t.scopes.iter().map(|s| s.as_str()).collect(),
            commands: &t.commands,
            created_at: &t.created_at,
            expires_at: &t.expires_at,
            expired: t.expired,
            last_used_at: t.last_used_at.as_deref(),
            last_used_ip: t.last_used_ip.as_deref(),
        }
    }
}

#[derive(Serialize)]
struct CreatedView<'a> {
    #[serde(flatten)]
    token: TokenView<'a>,
    /// The credential, shown this once.
    token_value: String,
}

fn parse_checked_scopes(asked: &[String], allow_empty: bool) -> Result<Vec<Scope>> {
    let mut scopes = Vec::new();
    for item in asked {
        let Some(scope) = Scope::parse(Scope::MONITOR, item) else {
            return Err(MonitorError::Parse(format!("unknown scope: {item}")));
        };
        if !scopes.contains(&scope) {
            scopes.push(scope);
        }
    }
    if !allow_empty && scopes.is_empty() {
        return Err(MonitorError::Parse("a token needs at least one scope".into()));
    }
    Ok(scopes)
}

fn check_name(raw: &str) -> Result<&str> {
    let name = raw.trim();
    if name.is_empty() || name.len() > 128 {
        return Err(MonitorError::Parse("name must be 1..=128 characters".into()));
    }
    Ok(name)
}

pub async fn list(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let tokens = api_tokens::list(&state.db).await?;
    let view: Vec<TokenView> = tokens.iter().map(TokenView::from).collect();
    Ok(HttpResponse::Ok().json(&view))
}

pub async fn create(
    req: HttpRequest,
    state: Arc<AppState>,
    body: web::types::Json<CreateRequest>,
) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let since = require!(admin::reauth_since(&req, &state, Some(body.password.as_str())).await);
    let name = check_name(&body.name)?;
    let scopes = match &body.scopes {
        Some(asked) => parse_checked_scopes(asked, false)?,
        None => Scope::MONITOR.to_vec(),
    };
    body.commands.validate().map_err(MonitorError::Parse)?;
    let days = body.days.unwrap_or(DEFAULT_DAYS);
    if days == 0 || days > 3650 {
        return Err(MonitorError::Parse("days must be 1..=3650".into()));
    }
    let token = sbm_mcp::token::mint().map_err(|e| anyhow::anyhow!(e))?;
    let expires_at = (chrono::Utc::now() + chrono::Duration::days(days as i64))
        .format("%Y-%m-%d %H:%M:%S")
        .to_string();
    let Some(id) = api_tokens::create_for_password_version(
        &state.db,
        since,
        name,
        &api_tokens::hash(&token),
        &scopes,
        &body.commands,
        &expires_at,
    )
    .await?
    else {
        return Ok(authz::error(
            StatusCode::FORBIDDEN,
            "reauth",
            "password changed; sign in again",
        ));
    };
    let Some(row) = api_tokens::get(&state.db, id).await? else {
        return Ok(authz::error(
            StatusCode::FORBIDDEN,
            "reauth",
            "password changed; sign in again",
        ));
    };
    admin::audit(
        &req,
        &state,
        crate::api::ws::audit::Action::Open,
        format!(
            "api token '{name}' for {}",
            scopes.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(",")
        ),
    )
    .await;
    Ok(HttpResponse::Ok().json(&CreatedView {
        token: TokenView::from(&row),
        token_value: token,
    }))
}

pub async fn update(
    req: HttpRequest,
    state: Arc<AppState>,
    path: web::types::Path<(i64,)>,
    body: web::types::Json<UpdateRequest>,
) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let id = path.into_inner().0;
    let name = check_name(&body.name)?;
    let scopes = parse_checked_scopes(&body.scopes, false)?;
    body.commands.validate().map_err(MonitorError::Parse)?;
    let updated = api_tokens::update(&state.db, id, name, &scopes, &body.commands).await?;
    if !updated {
        return Ok(error(StatusCode::NOT_FOUND, "not_found"));
    }
    let Some(row) = api_tokens::get(&state.db, id).await? else {
        return Ok(error(StatusCode::NOT_FOUND, "not_found"));
    };
    admin::audit(
        &req,
        &state,
        crate::api::ws::audit::Action::Write,
        format!(
            "api token '{name}' scopes={} mode={}",
            scopes.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(","),
            body.commands.mode.as_str()
        ),
    )
    .await;
    Ok(HttpResponse::Ok().json(&TokenView::from(&row)))
}

pub async fn revoke(
    req: HttpRequest,
    state: Arc<AppState>,
    path: web::types::Path<(i64,)>,
) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let id = path.into_inner().0;
    let name = api_tokens::get(&state.db, id).await?.map(|t| t.name);
    let revoked = api_tokens::revoke(&state.db, id).await?;
    if !revoked {
        return Ok(error(StatusCode::NOT_FOUND, "not_found"));
    }
    admin::audit(
        &req,
        &state,
        crate::api::ws::audit::Action::Close,
        format!("api token '{}'", name.unwrap_or_default()),
    )
    .await;
    Ok(HttpResponse::NoContent().build())
}

fn policy_view(policy: McpPolicy, state: &AppState) -> PolicyView {
    let config_scopes = state
        .config
        .get_mcp()
        .allowed_scopes()
        .into_iter()
        .map(Scope::as_str)
        .collect();
    PolicyView {
        scopes: policy.scopes.into_iter().map(Scope::as_str).collect(),
        commands: policy.commands,
        config_scopes,
    }
}

pub async fn get_policy(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let policy = api_tokens::load_policy(&state.db).await?;
    Ok(HttpResponse::Ok().json(&policy_view(policy, &state)))
}

pub async fn put_policy(
    req: HttpRequest,
    state: Arc<AppState>,
    body: web::types::Json<PolicyRequest>,
) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    let scopes = parse_checked_scopes(&body.scopes, true)?;
    body.commands.validate().map_err(MonitorError::Parse)?;
    let policy = McpPolicy {
        scopes: scopes.clone(),
        commands: body.commands,
    };
    api_tokens::store_policy(&state.db, &policy).await?;
    admin::audit(
        &req,
        &state,
        crate::api::ws::audit::Action::Write,
        format!(
            "mcp policy: {} scopes, mode={}, {} allow, {} deny",
            scopes.len(),
            policy.commands.mode.as_str(),
            policy.commands.allow.len(),
            policy.commands.deny.len(),
        ),
    )
    .await;
    Ok(HttpResponse::Ok().json(&policy_view(policy, &state)))
}
