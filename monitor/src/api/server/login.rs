//! Signing in (`POST /login`) and watch tokens (`/watch-token`).

use crate::{
    api::auth,
    api::authz,
    api::ratelimit::Who,
    api::ws::audit::{self, Action, Event, Kind, Outcome},
    utils::error::{MonitorError, Result},
};
use ntex::http::header::RETRY_AFTER;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::SqlitePool;
use std::sync::Arc;
use super::*;

pub(super) const WATCH_TOKEN_LIFETIME: chrono::Duration = chrono::Duration::days(90);

/// The password alone: the agent has one account. A `username` an older
/// client still sends is not read (TODO: refuse it once no such client is
/// left; serde ignores it until then).
#[derive(Deserialize)]
pub(super) struct LoginRequest {
    password: String,
    /// The token a previous sign-in gave this device, if any: see
    /// `api::ratelimit::Who`.
    #[serde(default)]
    device: Option<String>,
    /// What the client calls itself (`ServerBox on macOS`), shown in the
    /// device list; its User-Agent when absent.
    #[serde(default)]
    name: Option<String>,
}

/// The most characters of a device's label kept.
pub(super) const MAX_DEVICE_LABEL: usize = 80;

/// [name], else the User-Agent: control characters dropped, whitespace
/// collapsed, at most [`MAX_DEVICE_LABEL`] characters.
pub(super) fn device_label(name: Option<&str>, req: &HttpRequest) -> String {
    let user_agent = req
        .headers()
        .get(ntex::http::header::USER_AGENT)
        .and_then(|v| v.to_str().ok());
    let raw = name.filter(|n| !n.trim().is_empty()).or(user_agent).unwrap_or("");
    raw.split(|c: char| c.is_whitespace() || c.is_control())
        .filter(|word| !word.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
        .chars()
        .take(MAX_DEVICE_LABEL)
        .collect()
}

#[derive(Serialize)]
pub(super) struct LoginResponse {
    token: String,
    /// A new device token, when the request carried none the agent knows.
    /// The client keeps it and sends it with every later sign-in.
    #[serde(skip_serializing_if = "Option::is_none")]
    device: Option<String>,
}

#[derive(Deserialize)]
pub(super) struct WatchTokenRequest {
    client_id: String,
}

#[derive(Serialize)]
pub(super) struct WatchTokenResponse {
    token: String,
    expires_at: i64,
}

pub(super) async fn login(
    http_req: HttpRequest,
    req: web::types::Json<LoginRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    let peer_ip = http_req.peer_addr().map(|addr| addr.ip());

    // A device that signed in before is throttled on its own, out of reach
    // of failures anywhere else; anything else shares the account's counter.
    let now = chrono::Utc::now().timestamp();
    let known_device = match req.device.as_deref().filter(|d| !d.is_empty() && d.len() <= 128) {
        Some(device) => {
            let hash = watch_token_hash(device);
            crate::db::accounts::device_known(&app_state.db, &hash, now)
                .await?
                .then_some(hash)
        }
        None => None,
    };
    let who = match &known_device {
        Some(hash) => Who::Device(hash.clone()),
        None => Who::Stranger,
    };

    // Reserve under the throttle lock before touching bcrypt, so concurrent
    // guesses cannot all pass the same pre-failure snapshot.
    let attempt = match app_state.login_throttle.begin(peer_ip, who) {
        Ok(attempt) => attempt,
        Err(wait) => {
            let seconds = wait.as_secs().max(1);
            login_event(&http_req, Action::Denied, Outcome::Denied, "throttled")
                .record(&app_state.db)
                .await;
            return Ok(HttpResponse::TooManyRequests()
                .header(RETRY_AFTER, seconds.to_string())
                .json(&ErrorResponse {
                    error: format!("Too many failed attempts; retry in {seconds}s"),
                }));
        }
    };

    let owner = match crate::db::accounts::owner(&app_state.db).await {
        Ok(owner) => owner,
        Err(error) => {
            app_state.login_throttle.cancel(attempt);
            return Err(error);
        }
    };

    let password_matches = match verify_login_password_off_worker(
        req.password.clone(),
        owner.as_ref().map(|owner| owner.password_hash.clone()),
    )
    .await
    {
        Ok(matched) => matched,
        Err(error) => {
            app_state.login_throttle.cancel(attempt);
            return Err(error);
        }
    };

    if let Some(owner) = owner
        && password_matches
    {
        app_state.login_throttle.record_success(attempt);
        crate::db::accounts::record_login(&app_state.db, owner.id).await?;
        let seen = if known_device.is_some() { "device known" } else { "new device" };
        login_event(&http_req, Action::Open, Outcome::Ok, seen).record(&app_state.db).await;
        let (device_hash, device) = match known_device {
            Some(hash) => (hash, None),
            None => {
                let device = format!("sbd_{}", crate::utils::secrets::random_hex(32)?);
                (watch_token_hash(&device), Some(device))
            }
        };
        let label = device_label(req.name.as_deref(), &http_req);
        let ip = peer_ip.map(|ip| ip.to_string());
        crate::db::accounts::remember_device(&app_state.db, &device_hash, now, &label, ip.as_deref()).await?;
        let token = auth::generate_token(&app_state.config.get_jwt_secret())?;
        return Ok(HttpResponse::Ok().json(&LoginResponse { token, device }));
    }

    app_state.login_throttle.record_failure(attempt);
    login_event(&http_req, Action::Denied, Outcome::Denied, "wrong password")
        .record(&app_state.db)
        .await;

    Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
        error: "Invalid credentials".to_string(),
    }))
}

/// A sign-in for the audit log: where from and what became of it, never the
/// password or the device token.
pub(super) fn login_event(req: &HttpRequest, action: Action, outcome: Outcome, detail: &str) -> Event {
    Event::new(Kind::Login, action, outcome)
        .remote_ip(audit::peer_ip(req))
        .detail(detail)
}

/// Lowercase hex of the SHA-256, which is what the `watch_tokens` rows already
/// hold — `hex::encode` writes the same bytes the `{:x}` of digest 0.10 did.
pub(super) fn watch_token_hash(token: &str) -> String {
    hex::encode(Sha256::digest(token.as_bytes()))
}

pub(super) fn validate_watch_client_id(client_id: &str) -> Result<&str> {
    let client_id = client_id.trim();
    if client_id.is_empty() || client_id.len() > 128 {
        return Err(MonitorError::Parse(
            "watch token client_id must be 1..=128 characters".to_string(),
        ));
    }
    Ok(client_id)
}

pub(super) async fn issue_watch_token(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<WatchTokenRequest>,
) -> Result<HttpResponse> {
    require_jwt!(&req, &app_state);
    let client_id = validate_watch_client_id(&payload.client_id)?;
    let token = format!("sbw_{}", crate::utils::secrets::random_hex(32)?);
    let token_hash = watch_token_hash(&token);
    let now = chrono::Utc::now().timestamp();
    let expires_at = (chrono::Utc::now() + WATCH_TOKEN_LIFETIME).timestamp();
    sqlx::query(
        // `read`, the only scope there is, and stated rather than left to
        // the column default: the scope is what `verify_watch_token` reads.
        "INSERT INTO watch_tokens(client_id, token_hash, created_at, expires_at, scope) \
         VALUES (?, ?, ?, ?, 'read') \
         ON CONFLICT(client_id) DO UPDATE SET \
         token_hash = excluded.token_hash, created_at = excluded.created_at, \
         expires_at = excluded.expires_at, scope = excluded.scope",
    )
    .bind(client_id)
    .bind(token_hash)
    .bind(now)
    .bind(expires_at)
    .execute(&app_state.db)
    .await?;
    // A credential good for months: who minted one, as forgetting a device is
    // recorded. The client id, never the token.
    crate::api::admin::audit(&req, &app_state, Action::Open, format!("watch token for {client_id}")).await;
    Ok(HttpResponse::Ok().json(&WatchTokenResponse { token, expires_at }))
}

pub(super) async fn revoke_watch_token(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<WatchTokenRequest>,
) -> Result<HttpResponse> {
    require_jwt!(&req, &app_state);
    let client_id = validate_watch_client_id(&payload.client_id)?;
    let revoked = sqlx::query("DELETE FROM watch_tokens WHERE client_id = ?")
        .bind(client_id)
        .execute(&app_state.db)
        .await?;
    if revoked.rows_affected() > 0 {
        crate::api::admin::audit(&req, &app_state, Action::Close, format!("watch token for {client_id} revoked")).await;
    }
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "revoked" })))
}

/// The account a watch token was paired by, for a token that is live and
/// has the `read` scope — the only one a watch token is ever given, and the
/// only routes that call this are the read ones.
pub(crate) async fn verify_watch_token(db: &SqlitePool, token: &str, now: i64) -> Result<()> {
    let token_hash = watch_token_hash(token);
    sqlx::query_scalar::<_, i64>(
        "SELECT 1 FROM watch_tokens WHERE token_hash = ? AND expires_at > ? AND scope = 'read'",
    )
    .bind(token_hash)
    .bind(now)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| MonitorError::Auth("Invalid or expired token".to_string()))?;
    Ok(())
}

#[cfg(test)]
mod watch_token_tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn pool() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await
            .unwrap();
        sqlx::query(
            "CREATE TABLE watch_tokens (\
             client_id TEXT PRIMARY KEY, \
             token_hash TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL, \
             expires_at INTEGER NOT NULL, scope TEXT NOT NULL DEFAULT 'read')",
        )
        .execute(&pool)
        .await
        .unwrap();
        pool
    }

    /// The published SHA-256 of `abc`, so the row below is seeded with a value
    /// this crate did not produce. Hashing the token through
    /// `watch_token_hash` on both sides would agree with itself whatever the
    /// encoding became, and an agent's `watch_tokens` rows outlive the build
    /// that wrote them: a change there invalidates every paired watch, silently.
    const TOKEN: &str = "abc";
    const TOKEN_HASH: &str =
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";

    #[tokio::test]
    async fn watch_tokens_are_hashed_expiring_and_revocable() {
        let pool = pool().await;
        let token = TOKEN;
        assert_eq!(watch_token_hash(token), TOKEN_HASH);
        sqlx::query(
            "INSERT INTO watch_tokens(client_id, token_hash, created_at, expires_at) \
             VALUES (?, ?, ?, ?)",
        )
        .bind("watch:one")
        .bind(TOKEN_HASH)
        .bind(10_i64)
        .bind(20_i64)
        .execute(&pool)
        .await
        .unwrap();

        assert!(verify_watch_token(&pool, token, 19).await.is_ok());
        assert!(verify_watch_token(&pool, token, 20).await.is_err());
        sqlx::query("DELETE FROM watch_tokens WHERE client_id = ?")
            .bind("watch:one")
            .execute(&pool)
            .await
            .unwrap();
        assert!(verify_watch_token(&pool, token, 19).await.is_err());
    }
}
