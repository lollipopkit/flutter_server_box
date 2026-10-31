//! Who is asking, and whether this link may carry what they ask.
//!
//! The agent has one account, its own: whoever holds its password may do
//! what the system account the agent runs as may do, and nothing in the
//! agent narrows that (`docs/dev/monitor-permissions.md`). What is left to
//! decide per request is the credential — a panel JWT issued after the
//! password was last set, or a watch token that only reads — and the
//! transport: anything beyond reading the numbers needs TLS or a loopback
//! peer unless `[remote_access] allow_insecure` says otherwise.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{HttpRequest, HttpResponse};
use serde::Serialize;

use crate::api::server::{AppState, bearer_token, verify_watch_token};
use crate::api::{auth, ws};
use crate::db::accounts;

/// What the agent keys the account's sessions, tickets and tasks by, and what
/// its panel tokens name.
pub use crate::api::auth::SUBJECT;

/// The account, as a request resolved it.
#[derive(Debug, Clone)]
pub struct Caller {
    /// What the account's rows (desk, tasks, memory) are keyed by.
    pub id: i64,
    /// When the password was last set, in Unix milliseconds. A token issued
    /// before it does not name this caller, and a connection opened under an
    /// earlier one ends — see [`end_account`].
    pub since: i64,
}

/// Why the machine cannot be acted on over this request. `snake_case` on the
/// wire.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Why {
    /// A plaintext link that `[remote_access] allow_insecure` does not allow.
    InsecureTransport,
}

impl Why {
    pub fn as_str(self) -> &'static str {
        match self {
            Why::InsecureTransport => "insecure_transport",
        }
    }
}

impl Caller {
    /// Whether anything beyond reading the numbers may be done over a link
    /// that is [secure]: a shell, a file, a relay, a hypervisor.
    pub fn check(&self, state: &AppState, secure: bool) -> Result<(), Why> {
        if state.remote_access.transport_ok(secure) {
            Ok(())
        } else {
            Err(Why::InsecureTransport)
        }
    }
}

/// The account, or `None` before it exists.
///
/// A database error reads as no account: refusing a request because the
/// database is unwell is the safe direction, and it is logged.
pub async fn caller(state: &AppState) -> Option<Caller> {
    match accounts::owner(&state.db).await {
        Ok(Some(owner)) => Some(Caller { id: owner.id, since: owner.since }),
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("Could not read the account: {e}");
            None
        }
    }
}

/// `{"error": code, "message": message}`.
pub fn error(status: StatusCode, code: &str, message: &str) -> HttpResponse {
    HttpResponse::builder(status).json(&serde_json::json!({
        "error": code,
        "message": message,
    }))
}

pub fn unauthorized() -> HttpResponse {
    error(
        StatusCode::UNAUTHORIZED,
        "unauthorized",
        "Invalid or missing token",
    )
}

/// The account behind the request's panel JWT. Watch tokens are refused: a
/// watch token reads the numbers and does nothing else, and every route that
/// takes this is one that does something else.
pub async fn jwt_caller(req: &HttpRequest, state: &AppState) -> Result<Caller, HttpResponse> {
    let Ok(token) = bearer_token(req) else {
        return Err(unauthorized());
    };
    let Ok(claims) = auth::verify_token(token, &state.config.get_jwt_secret()) else {
        return Err(unauthorized());
    };
    caller_of(state, &claims).await.ok_or_else(unauthorized)
}

/// The account behind the request's panel JWT, over a link that may carry
/// more than the numbers (`Caller::check`): what every route that changes or
/// configures the machine or the agent takes.
pub async fn acting_caller(req: &HttpRequest, state: &AppState) -> Result<Caller, HttpResponse> {
    let caller = jwt_caller(req, state).await?;
    match caller.check(state, is_secure(req, state)) {
        Ok(()) => Ok(caller),
        Err(why) => Err(error(StatusCode::FORBIDDEN, "forbidden", why.as_str())),
    }
}

/// The account, if [claims] are one of its tokens issued after its password
/// was last set. Earlier ones were paid for by a password that has since been
/// replaced — the reason to replace one is that somebody else may have it.
///
/// To the second, which is all a token's `iat` says: one issued in the same
/// second as the change still counts, so signing in again right after
/// changing a password works.
async fn caller_of(state: &AppState, claims: &auth::Claims) -> Option<Caller> {
    if claims.sub != SUBJECT {
        return None;
    }
    let caller = caller(state).await?;
    (claims.iat as i64 >= caller.since.div_euclid(1000)).then_some(caller)
}

/// Who may read the numbers: the account, or a watch token with the `read`
/// scope.
pub enum Reader {
    Account(Caller),
    Watch,
}

pub async fn read_caller(req: &HttpRequest, state: &AppState) -> Result<Reader, HttpResponse> {
    let Ok(token) = bearer_token(req) else {
        return Err(unauthorized());
    };
    if let Ok(claims) = auth::verify_token(token, &state.config.get_jwt_secret()) {
        return caller_of(state, &claims)
            .await
            .map(Reader::Account)
            .ok_or_else(unauthorized);
    }
    match verify_watch_token(&state.db, token, chrono::Utc::now().timestamp()).await {
        Ok(_) => Ok(Reader::Watch),
        Err(_) => Err(unauthorized()),
    }
}

/// Whether the request came over a link that cannot be read off the network.
pub fn is_secure(req: &HttpRequest, state: &AppState) -> bool {
    ws::is_secure_transport(req, state.tls_active)
}

/// `/capabilities`' `access`: whether [caller] may act on the machine over
/// this link — never, for a watch token.
pub fn access_view(caller: Option<&Caller>, state: &AppState, secure: bool) -> serde_json::Value {
    let checked = match caller {
        Some(caller) => caller.check(state, secure),
        None => return serde_json::json!({ "ok": false }),
    };
    match checked {
        Ok(()) => serde_json::json!({ "ok": true }),
        Err(why) => serde_json::json!({ "ok": false, "why": why.as_str() }),
    }
}

/// Ends everything the account has running: its terminal sessions, its
/// outstanding upgrade tickets, its Agent mode tasks, its app windows, and —
/// through `password_changed`, on which each re-reads the account and finds
/// its password moved on — its relays and listeners. For a password change.
pub fn end_account(state: &Arc<AppState>, code: &'static str) {
    let closed = state.sessions.close_all(code);
    if closed > 0 {
        tracing::info!("Closed {closed} terminal sessions: the password changed");
    }
    state.tickets.revoke_all();
    state.agent.end_account();
    state.stacks.proxies.end_account();
    // Whoever held the old password may have signed the agent in to their
    // own LK Cloud account, or be about to.
    crate::lkc::end_account(state);
    let _ = state.password_changed.send(code);
}
