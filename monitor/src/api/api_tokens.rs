//! `/api-tokens` (#1681): the API tokens' own management, what the password
//! is for. `GET` lists every token, `POST` mints one after re-entering the
//! password, `DELETE` revokes; all three take [`authz::acting_caller`], as
//! the rows name addresses a plaintext link should not carry.
//!
//! The token itself answers a `POST` once and is then nowhere but the
//! owner's clipboard: the row holds its hash.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use crate::api::respond::error;
use crate::api::server::AppState;
use crate::api::{admin, authz};
use crate::db::api_tokens::{self, Scope, Token};
use crate::utils::error::MonitorError;
use crate::utils::error::Result;

/// How long a new token lives unless its creator says otherwise.
const DEFAULT_DAYS: u32 = 90;

#[derive(Deserialize)]
pub struct CreateRequest {
    pub name: String,
    /// The account's password again — minting a credential costs it, as
    /// changing the password does.
    pub password: String,
    /// Out of `Scope::ALL`; unknown names are refused, unlike a stored row
    /// the code no longer understands — here the person is still typing.
    pub scopes: Vec<String>,
    /// Days the token lives, [`DEFAULT_DAYS`] when absent.
    #[serde(default)]
    pub days: Option<u32>,
}

#[derive(Serialize)]
struct TokenView<'a> {
    id: i64,
    name: &'a str,
    scopes: Vec<&'static str>,
    created_at: &'a str,
    expires_at: &'a str,
    last_used_at: Option<&'a str>,
    last_used_ip: Option<&'a str>,
}

impl<'a> From<&'a Token> for TokenView<'a> {
    fn from(t: &'a Token) -> Self {
        TokenView {
            id: t.id,
            name: &t.name,
            scopes: t.scopes.iter().map(|s| s.as_str()).collect(),
            created_at: &t.created_at,
            expires_at: &t.expires_at,
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
    // A credential good for months: minting one costs the password again,
    // as changing the password does.
    require!(admin::reauth(&req, &state, Some(body.password.as_str())).await);
    let name = body.name.trim();
    if name.is_empty() || name.len() > 128 {
        return Err(MonitorError::Parse("name must be 1..=128 characters".into()));
    }
    let mut scopes: Vec<Scope> = Vec::new();
    for asked in &body.scopes {
        // Refused, not skipped: a scope silently dropped would mint a token
        // the person believes is narrower than it is.
        let Some(scope) = Scope::ALL.iter().copied().find(|s| s.as_str() == *asked) else {
            return Err(MonitorError::Parse(format!("unknown scope: {asked}")));
        };
        if !scopes.contains(&scope) {
            scopes.push(scope);
        }
    }
    if scopes.is_empty() {
        return Err(MonitorError::Parse("a token needs at least one scope".into()));
    }
    let days = body.days.unwrap_or(DEFAULT_DAYS);
    if days == 0 || days > 3650 {
        return Err(MonitorError::Parse("days must be 1..=3650".into()));
    }
    let token = format!("{}{}", api_tokens::PREFIX, crate::utils::secrets::random_hex(32)?);
    let expires_at = (chrono::Utc::now() + chrono::Duration::days(days as i64))
        .format("%Y-%m-%d %H:%M:%S")
        .to_string();
    let id = api_tokens::create(&state.db, name, &api_tokens::hash(&token), &scopes, &expires_at).await?;
    let row = api_tokens::get(&state.db, id).await?.expect("just created");
    admin::audit(
        &req,
        &state,
        crate::api::ws::audit::Action::Open,
        format!("api token '{name}' for {}", scopes.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(",")),
    )
    .await;
    Ok(HttpResponse::Ok().json(&CreatedView {
        token: TokenView::from(&row),
        token_value: token,
    }))
}

pub async fn revoke(
    req: HttpRequest,
    state: Arc<AppState>,
    path: web::types::Path<(i64,)>,
) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let id = path.into_inner().0;
    // The name, so the audit row keeps saying what went after the row is
    // gone.
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
