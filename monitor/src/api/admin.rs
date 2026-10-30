//! The account, over the API: `/me/password`.
//!
//! A password change asks for the current password again (`current_password`):
//! a session left open on a shared machine, or a stolen token, should not be
//! enough to lock the owner out. The check goes through the login throttle,
//! so it is not a second place to guess passwords at.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::http::header::RETRY_AFTER;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use crate::api::authz::{self, error};
use crate::api::server::{AppState, hash_password_off_worker, verify_login_password_off_worker};
use crate::api::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::db::accounts;
use crate::utils::error::Result;

/// The shortest password the account may be given here.
const MIN_PASSWORD: usize = 8;

/// The code a client whose connection ends because of a change here is told.
const REVOKED: &str = "password_changed";

fn bad_request(message: &str) -> HttpResponse {
    error(StatusCode::BAD_REQUEST, "bad_request", message)
}

/// [body] as a [T], or a `bad_request` saying what was wrong with it.
///
/// Taken as JSON and read here rather than by the extractor, so a body of
/// the wrong shape answers in this API's error shape instead of the
/// framework's.
fn parse<T: serde::de::DeserializeOwned>(
    body: web::types::Json<serde_json::Value>,
) -> std::result::Result<T, HttpResponse> {
    serde_json::from_value(body.into_inner()).map_err(|e| bad_request(&e.to_string()))
}

/// An administrative change, recorded under [`Kind::Admin`] with the caller's
/// address: what the account did to the agent itself.
pub(crate) async fn audit(req: &HttpRequest, state: &AppState, action: Action, detail: String) {
    Event::new(Kind::Admin, action, Outcome::Ok)
        .remote_ip(peer_ip(req))
        .detail(detail)
        .record(&state.db)
        .await;
}

/// Checks [password] against [caller]'s own, through the login throttle.
pub(crate) async fn reauth(
    req: &HttpRequest,
    state: &AppState,
    password: Option<&str>,
) -> std::result::Result<(), HttpResponse> {
    let attempt = match state
        .login_throttle
        .begin(req.peer_addr().map(|a| a.ip()), crate::api::ratelimit::Who::SignedIn)
    {
        Ok(attempt) => attempt,
        Err(wait) => {
            let seconds = wait.as_secs().max(1);
            let mut response = error(
                StatusCode::TOO_MANY_REQUESTS,
                "throttled",
                &format!("Too many failed attempts; retry in {seconds}s"),
            );
            if let Ok(value) = seconds.to_string().parse() {
                response.headers_mut().insert(RETRY_AFTER, value);
            }
            return Err(response);
        }
    };
    let hash = match accounts::owner(&state.db).await {
        Ok(owner) => owner.map(|o| o.password_hash),
        Err(e) => {
            state.login_throttle.cancel(attempt);
            tracing::warn!("Could not read the password hash: {e}");
            return Err(error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "Could not check the password",
            ));
        }
    };
    let matched = match verify_login_password_off_worker(password.unwrap_or_default().to_string(), hash).await {
        Ok(matched) => matched && password.is_some(),
        Err(_) => {
            state.login_throttle.cancel(attempt);
            return Err(error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "Could not check the password",
            ));
        }
    };
    if matched {
        state.login_throttle.record_success(attempt);
        Ok(())
    } else {
        state.login_throttle.record_failure(attempt);
        Err(error(
            StatusCode::FORBIDDEN,
            "reauth",
            "current_password is missing or wrong",
        ))
    }
}

async fn hash(password: &str) -> std::result::Result<String, HttpResponse> {
    if password.chars().count() < MIN_PASSWORD {
        return Err(bad_request("A password must be at least 8 characters"));
    }
    hash_password_off_worker(password.to_string()).await.map_err(|_| {
        error(
            StatusCode::INTERNAL_SERVER_ERROR,
            "internal",
            "Could not hash the password",
        )
    })
}

/// A body that carries only the password asked again.
#[derive(Deserialize, Default)]
pub struct Reauth {
    pub(crate) current_password: Option<String>,
}

#[derive(Deserialize)]
pub struct PasswordChange {
    current_password: Option<String>,
    new_password: String,
}

pub async fn change_own_password(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    require!(authz::acting_caller(&req, &state).await);
    let body: PasswordChange = require!(parse(body));
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    let hash = require!(hash(&body.new_password).await);
    crate::lkc::end_before_password_change(&state).await;
    accounts::set_password_hash(&state.db, &hash).await?;
    // Including the caller's own other sessions: a password is changed
    // because someone else may have it.
    authz::end_account(&state, REVOKED);
    audit(&req, &state, Action::Close, "changed the password".into()).await;
    Ok(HttpResponse::NoContent().finish())
}
