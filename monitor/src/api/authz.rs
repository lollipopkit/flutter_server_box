//! Who is asking, and what their role lets them do (issue #1610).
//!
//! One place answers both, for every route: the caller is resolved from the
//! credential — a panel JWT names an account, the account names a role — and
//! each grant is checked against that role, the machine's configuration, and
//! the transport the request came over. Handlers ask [`Caller::check`] and
//! nothing else; none of them reads a switch out of `config.toml` any more.
//!
//! A JWT for an account that no longer exists is refused like a bad one: the
//! token outlives a deletion by up to an hour, and an account removed for a
//! reason should not keep reading or acting until it expires.

use std::net::SocketAddr;
use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{HttpRequest, HttpResponse};
use serde::Serialize;

use crate::api::server::{AppState, bearer_token, verify_watch_token};
use crate::api::{auth, ws};
use crate::core::permissions::{Grant, Grants, Role};
use crate::db::accounts;

/// An account, and the role it held when this request was resolved.
#[derive(Debug, Clone)]
pub struct Caller {
    pub username: String,
    pub role: Role,
    /// When the account's password was last set, in Unix milliseconds. A
    /// token issued before it does not name this caller, and a connection
    /// opened under an earlier one ends when it is next asked — see
    /// [`end_account`].
    pub since: i64,
}

/// Why a grant cannot be used right now. `snake_case` on the wire.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Why {
    /// The role does not hold it.
    NotGranted,
    /// The role holds it, and the machine has nothing to serve: `files` with
    /// no roots configured.
    NotConfigured,
    /// The role holds it, and this request came over a plaintext link that
    /// [`crate::core::remote_access::RemoteAccess::transport_ok`] refuses.
    InsecureTransport,
}

impl Why {
    pub fn as_str(self) -> &'static str {
        match self {
            Why::NotGranted => "not_granted",
            Why::NotConfigured => "not_configured",
            Why::InsecureTransport => "insecure_transport",
        }
    }
}

impl Caller {
    pub fn grants(&self) -> &Grants {
        &self.role.grants
    }

    pub fn is_admin(&self) -> bool {
        self.role.admin
    }

    /// Whether [grant] may be used now, over a link that is [secure].
    ///
    /// In order of what the caller can do about it: a grant they do not hold
    /// is the role's to change, a machine with nothing to serve is the
    /// operator's, and an insecure link is the connection's.
    pub fn check(&self, grant: Grant, state: &AppState, secure: bool) -> Result<(), Why> {
        if !self.role.grants.holds(grant) {
            return Err(Why::NotGranted);
        }
        if grant == Grant::Files && !state.remote_access.fs.configured() {
            return Err(Why::NotConfigured);
        }
        if !state.remote_access.transport_ok(grant, secure) {
            return Err(Why::InsecureTransport);
        }
        Ok(())
    }

    /// Whether [addr] may be dialled under this role's `connect` grant —
    /// [`Self::check`] for `Connect` already passed.
    pub fn may_connect_to(&self, addr: SocketAddr) -> bool {
        self.role
            .grants
            .connect
            .as_ref()
            .is_some_and(|connect| connect.permits(addr))
    }
}

/// The account [username] names, or `None` when there is none.
///
/// A database error reads as no account: refusing a request because the
/// database is unwell is the safe direction, and it is logged.
pub async fn caller_named(state: &AppState, username: &str) -> Option<Caller> {
    match accounts::account_since(&state.db, username).await {
        Ok(found) => found.map(|(username, role, since)| Caller {
            username,
            role,
            since,
        }),
        Err(e) => {
            tracing::warn!("Could not resolve account {username:?}: {e}");
            None
        }
    }
}

/// `{"error": code, "message": message}` — the shape every endpoint added
/// with roles answers errors in.
pub fn error(status: StatusCode, code: &str, message: &str) -> HttpResponse {
    HttpResponse::build(status).json(&serde_json::json!({
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

/// The account [claims] name, if they were issued after its password was
/// last set. Earlier ones were paid for by a password that has since been
/// replaced — the reason to replace one is that somebody else may have it —
/// or by an account of the same name that was deleted.
///
/// To the second, which is all a token's `iat` says: one issued in the same
/// second as the change still counts, so signing in again right after
/// changing a password works.
async fn caller_of(state: &AppState, claims: &auth::Claims) -> Option<Caller> {
    let caller = caller_named(state, &claims.sub).await?;
    (claims.iat as i64 >= caller.since.div_euclid(1000)).then_some(caller)
}

/// [`jwt_caller`], and an admin.
pub async fn admin_caller(req: &HttpRequest, state: &AppState) -> Result<Caller, HttpResponse> {
    let caller = jwt_caller(req, state).await?;
    if !caller.is_admin() {
        return Err(error(
            StatusCode::FORBIDDEN,
            "forbidden",
            "Only an admin may do this",
        ));
    }
    Ok(caller)
}

/// Who may read the numbers: an account, or a watch token with the `read`
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

/// The `grants` object of `/capabilities`, for [caller] over a link that is
/// [secure] — or every grant `not_granted`, for a watch token.
pub fn grants_view(caller: Option<&Caller>, state: &AppState, secure: bool) -> serde_json::Value {
    let mut out = serde_json::Map::new();
    for grant in Grant::ALL {
        let checked = match caller {
            Some(caller) => caller.check(grant, state, secure),
            None => Err(Why::NotGranted),
        };
        let mut entry = serde_json::Map::new();
        entry.insert("ok".into(), checked.is_ok().into());
        if let Err(why) = checked {
            entry.insert("why".into(), why.as_str().into());
        }
        // The options of a grant the role holds, whether or not it is usable
        // over this link: they are what the role says, and a client greying
        // out an entry for `insecure_transport` still wants to say what it
        // would allow.
        if let Some(caller) = caller {
            let grants = &caller.role.grants;
            match grant {
                Grant::Files => {
                    if let Some(files) = &grants.files {
                        entry.insert("mode".into(), serde_json::to_value(files.mode).unwrap_or_default());
                    }
                }
                Grant::Connect => {
                    if let Some(connect) = &grants.connect {
                        entry.insert("allow".into(), connect.allow.clone().into());
                    }
                }
                Grant::Listen => {
                    if let Some(listen) = &grants.listen {
                        entry.insert("public".into(), listen.public.into());
                        entry.insert(
                            "ports".into(),
                            serde_json::to_value(listen.ports).unwrap_or_default(),
                        );
                    }
                }
                Grant::Shell | Grant::Virt => {}
            }
        }
        out.insert(grant.as_str().into(), entry.into());
    }
    out.into()
}

/// Ends everything [username] has running: its terminal sessions, its
/// outstanding upgrade tickets, and — through `grants_changed`, on which each
/// re-reads the account and finds its password moved on — its relays and
/// listeners. For a password change, which keeps the role and so is not
/// something [`revoke_lost`] would see.
pub fn end_account(state: &Arc<AppState>, username: &str, code: &'static str) {
    let closed = state
        .sessions
        .close_where(|session| session.subject == username, code);
    if closed > 0 {
        tracing::info!("Closed {closed} terminal sessions of {username}: its password changed");
    }
    state.tickets.revoke_subject(username);
    let _ = state.grants_changed.send(code);
}

/// Ends what accounts can no longer do, after a role or an account changed.
///
/// Terminal sessions outlive their sockets, so they are swept here: each
/// session's account is looked up again and a session whose role no longer
/// grants `shell` is closed, with [code] as what the client is
/// told — as is one opened under a password the account no longer has. Relays and listeners are told through `AppState.grants_changed` and
/// each re-checks its own account — see `api::ws::stream` and `listen`.
pub async fn revoke_lost(state: &Arc<AppState>, code: &'static str) {
    for subject in state.sessions.subjects() {
        let caller = caller_named(state, &subject).await;
        let since = caller.as_ref().map(|c| c.since);
        let shell = caller
            .as_ref()
            .is_some_and(|c| c.grants().holds(Grant::Shell));
        let closed = state.sessions.close_where(
            |session| session.subject == subject && (since != Some(session.since) || !shell),
            code,
        );
        if closed > 0 {
            tracing::info!("Closed {closed} terminal sessions of {subject}: their grant is gone");
        }
    }
    let _ = state.grants_changed.send(code);
}
