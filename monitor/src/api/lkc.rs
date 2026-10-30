//! `/lkc`: the LK Cloud account this agent is signed in to (`crate::lkc`).
//!
//! - `GET /lkc`: `{user, sign_in}`, either `null`; renews nothing.
//! - `POST /lkc/sign-in`: starts a device sign-in, `{sign_in}`.
//! - `DELETE /lkc/sign-in`: ends the one waiting.
//! - `DELETE /lkc`: signs out.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Serialize;

use super::authz;
use super::respond;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::lkc::{self, SignInView};
use sbm_lkc::Failure;

/// The account as a client shows it (`LkcUser`); never a token.
#[derive(Serialize)]
struct UserView {
    id: String,
    name: String,
    group: String,
    avatar: Option<String>,
}

#[derive(Serialize)]
struct Answer {
    user: Option<UserView>,
    sign_in: Option<SignInView>,
}

/// Over a link that may act only: the answer names a person.
pub async fn get(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let user = lkc::current(&state).await.map(|s| UserView {
        id: s.user.id,
        name: s.user.name,
        group: s.user.group,
        avatar: s.user.avatar,
    });
    Ok(HttpResponse::Ok().json(&Answer { user, sign_in: state.lkc.sign_in() }))
}

pub async fn start(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
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
        Err(e) => {
            tracing::warn!("LK Cloud sign-in: {e}");
            let code = if e.failure == Failure::Unreachable { "lkc_unreachable" } else { "lkc_refused" };
            Ok(respond::error(StatusCode::BAD_GATEWAY, code))
        }
    }
}

pub async fn cancel(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if state.lkc.sign_in().is_some() {
        state.lkc.cancel();
        Event::new(Kind::Admin, Action::Write, Outcome::Ok)
            .remote_ip(peer_ip(&req))
            .detail("LK Cloud sign-in cancelled")
            .record(&state.db)
            .await;
    }
    Ok(HttpResponse::NoContent().finish())
}

pub async fn sign_out(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
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
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(respond::internal(&e)),
    }
}
