//! `/lkc`: the LK Cloud account this agent is signed in to (`crate::lkc`).
//!
//! - `GET /lkc`: `{user, sign_in}`, either `null`; renews nothing.
//! - `POST /lkc/sign-in`: starts a device sign-in, `{sign_in}`.
//! - `DELETE /lkc/sign-in`: ends the one waiting.
//! - `DELETE /lkc`: signs out.

use crate::api::WebError;
use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{HttpRequest, HttpResponse};
use serde::Serialize;

use super::authz;
use super::respond;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::lkc::{self, SignInView};

#[derive(Serialize)]
struct Answer {
    /// `sbm_lkc::User` (`LkcUser`); never a token.
    user: Option<sbm_lkc::User>,
    sign_in: Option<SignInView>,
}

/// Over a link that may act only: the answer names a person.
pub async fn get(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    Ok(HttpResponse::Ok().json(&Answer { user: lkc::current(&state).await, sign_in: state.lkc.sign_in() }))
}

pub async fn start(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    match lkc::start(&state).await {
        Ok(sign_in) => {
            Event::new(Kind::Admin, Action::Open, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail("LK Cloud sign-in started")
                .record(&state.db)
                .await;
            Ok(HttpResponse::Ok().json(&serde_json::json!({ "sign_in": sign_in })))
        }
        // The caller's token is no longer good either.
        Err(lkc::StartError::PasswordChanged) => Ok(respond::error(StatusCode::UNAUTHORIZED, "password_changed")),
        Err(lkc::StartError::Finishing) => Ok(respond::error(StatusCode::CONFLICT, "lkc_finishing")),
        Err(lkc::StartError::Lkc(e)) => {
            tracing::warn!("LK Cloud sign-in: {e}");
            let code = if e.transient() { "lkc_unreachable" } else { "lkc_refused" };
            Ok(respond::error(StatusCode::BAD_GATEWAY, code))
        }
    }
}

pub async fn cancel(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    if state.lkc.cancel() {
        Event::new(Kind::Admin, Action::Write, Outcome::Ok)
            .remote_ip(peer_ip(&req))
            .detail("LK Cloud sign-in cancelled")
            .record(&state.db)
            .await;
    }
    Ok(HttpResponse::NoContent().build())
}

pub async fn sign_out(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    require!(authz::acting_caller(&req, &state).await);
    match lkc::sign_out(&state).await {
        Ok(signed_out) => {
            if signed_out {
                Event::new(Kind::Admin, Action::Write, Outcome::Ok)
                    .remote_ip(peer_ip(&req))
                    .detail("LK Cloud sign-out")
                    .record(&state.db)
                    .await;
            }
            Ok(HttpResponse::NoContent().build())
        }
        Err(e) => Ok(respond::internal(&e)),
    }
}
