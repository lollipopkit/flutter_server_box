//! Accounts and roles, over the API (issue #1610): `/me`, `/me/password`,
//! `/users*`, `/roles*`.
//!
//! Only an admin may change an account — another's or their own — or a role.
//! Every change that alters who may do what asks for the calling admin's own
//! password again (`current_password`): an admin session left open on a
//! shared machine, or a stolen token, should not be enough to hand out a
//! shell. The check goes through the login throttle, so it is not a second
//! place to guess passwords at.
//!
//! Two things are held true whatever is asked: there is always an admin (the
//! last one cannot be deleted or given another role), and the built-in roles
//! keep their names and their `admin` flag. A change that takes a grant away
//! ends what was running under it — see `authz::revoke_lost`.

use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::http::header::RETRY_AFTER;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use crate::api::authz::{self, Caller, error};
use crate::api::server::{AppState, hash_password_off_worker, verify_login_password_off_worker};
use crate::api::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::permissions::{Role, valid_role_name};
use crate::db::accounts::{self, Guarded};
use crate::utils::error::Result;

/// The shortest password an account may be given here.
const MIN_PASSWORD: usize = 8;

/// The code a client whose connection ends because of a change here is told.
const REVOKED: &str = "permission_revoked";

fn bad_request(message: &str) -> HttpResponse {
    error(StatusCode::BAD_REQUEST, "bad_request", message)
}

fn not_found(message: &str) -> HttpResponse {
    error(StatusCode::NOT_FOUND, "not_found", message)
}

fn conflict(message: &str) -> HttpResponse {
    error(StatusCode::CONFLICT, "conflict", message)
}

fn last_admin() -> HttpResponse {
    error(
        StatusCode::CONFLICT,
        "last_admin",
        "This is the last admin account; make another account an admin first",
    )
}

/// 1–64 characters of letters, digits and `._@-`. Only for accounts created
/// here: one made with `user set-password` before this existed keeps its name.
fn valid_username(name: &str) -> bool {
    (1..=64).contains(&name.len())
        && name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'@' | b'-'))
}

/// [body] as a [T], or a `bad_request` saying what was wrong with it.
///
/// Taken as JSON and read here rather than by the extractor, so a body of
/// the wrong shape — a misspelt grant, which `Grants` refuses rather than
/// dropping — answers in this API's error shape instead of the framework's.
fn parse<T: serde::de::DeserializeOwned>(
    body: web::types::Json<serde_json::Value>,
) -> std::result::Result<T, HttpResponse> {
    serde_json::from_value(body.into_inner()).map_err(|e| bad_request(&e.to_string()))
}

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

async fn audit(req: &HttpRequest, state: &AppState, caller: &Caller, action: Action, detail: String) {
    Event::new(Kind::Admin, action, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(req))
        .detail(detail)
        .record(&state.db)
        .await;
}

/// Checks [password] against [caller]'s own, through the login throttle.
pub(crate) async fn reauth(
    req: &HttpRequest,
    state: &AppState,
    caller: &Caller,
    password: Option<&str>,
) -> std::result::Result<(), HttpResponse> {
    let attempt = match state
        .login_throttle
        .begin(req.peer_addr().map(|a| a.ip()), &caller.username)
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
    let hash = match accounts::password_hash(&state.db, &caller.username).await {
        Ok(hash) => hash,
        Err(e) => {
            state.login_throttle.cancel(attempt);
            tracing::warn!("Could not read {}'s password hash: {e}", caller.username);
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

// ---- /me ----

pub async fn me(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    let caller = require!(authz::jwt_caller(&req, &state).await);
    Ok(HttpResponse::Ok().json(&serde_json::json!({
        "username": caller.username,
        "role": caller.role,
    })))
}

#[derive(Deserialize)]
pub struct PasswordChange {
    current_password: Option<String>,
    new_password: String,
}

/// Any account may change its own password, and nothing else about itself.
pub async fn change_own_password(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let body: PasswordChange = require!(parse(body));
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    let hash = require!(hash(&body.new_password).await);
    accounts::set_password_hash(&state.db, &caller.username, &hash).await?;
    // Including the caller's own other sessions: a password is changed
    // because someone else may have it.
    authz::end_account(&state, &caller.username, "permission_revoked");
    audit(&req, &state, &caller, Action::Close, "changed own password".into()).await;
    Ok(HttpResponse::NoContent().finish())
}

// ---- /users ----

pub async fn list_users(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    require!(authz::admin_caller(&req, &state).await);
    Ok(HttpResponse::Ok().json(&accounts::accounts(&state.db).await?))
}

#[derive(Deserialize)]
pub struct NewUser {
    username: String,
    password: String,
    role: String,
    current_password: Option<String>,
}

pub async fn create_user(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let body: NewUser = require!(parse(body));
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    if !valid_username(&body.username) {
        return Ok(bad_request(
            "A username is 1–64 letters, digits, '.', '_', '@' or '-'",
        ));
    }
    if accounts::role(&state.db, &body.role).await?.is_none() {
        return Ok(bad_request(&format!("No such role: {}", body.role)));
    }
    if accounts::account(&state.db, &body.username).await?.is_some() {
        return Ok(conflict("An account with that name exists"));
    }
    let hash = require!(hash(&body.password).await);
    accounts::insert_account(&state.db, &body.username, &hash, &body.role).await?;
    audit(
        &req,
        &state,
        &caller,
        Action::Open,
        format!("created account {} with role {}", body.username, body.role),
    )
    .await;
    let view = accounts::account_view_of(&state.db, &body.username).await?;
    Ok(HttpResponse::Created().json(&view))
}

#[derive(Deserialize)]
pub struct UserChange {
    role: Option<String>,
    password: Option<String>,
    current_password: Option<String>,
}

pub async fn update_user(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    path: web::types::Path<String>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let username = path.into_inner();
    let body: UserChange = require!(parse(body));
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    let Some((_, current)) = accounts::account(&state.db, &username).await? else {
        return Ok(not_found("No such account"));
    };

    // Everything checked before anything is written, so a refused half does
    // not leave the other half applied.
    let new_hash = match &body.password {
        Some(password) => Some(require!(hash(password).await)),
        None => None,
    };
    let role_change = match &body.role {
        Some(role) if *role != current.name => {
            if accounts::role(&state.db, role).await?.is_none() {
                return Ok(bad_request(&format!("No such role: {role}")));
            }
            Some(role.clone())
        }
        _ => None,
    };

    // The role first: it is the half that can still be refused — the last
    // admin, decided in the same statement that writes it — and a refusal
    // must not leave the password already changed.
    if let Some(role) = &role_change {
        match accounts::set_role_keeping_an_admin(&state.db, &username, role).await? {
            Guarded::Done => {}
            Guarded::NotFound => return Ok(not_found("No such account")),
            Guarded::LastAdmin => return Ok(last_admin()),
        }
    }
    if let Some(hash) = &new_hash {
        accounts::set_password_hash(&state.db, &username, hash).await?;
        authz::end_account(&state, &username, "permission_revoked");
        audit(&req, &state, &caller, Action::Close, format!("reset the password of {username}")).await;
    }
    if let Some(role) = &role_change {
        audit(
            &req,
            &state,
            &caller,
            Action::Close,
            format!("moved {username} from role {} to {role}", current.name),
        )
        .await;
        authz::revoke_lost(state.get_ref(), REVOKED).await;
    }
    let view = accounts::account_view_of(&state.db, &username).await?;
    Ok(HttpResponse::Ok().json(&view))
}

#[derive(Deserialize, Default)]
pub struct Reauth {
    pub(crate) current_password: Option<String>,
}

/// The body of a DELETE: optional as far as the extractor goes, so a missing
/// one answers `reauth` like a wrong password rather than a parse error.
fn reauth_body(body: Option<web::types::Json<Reauth>>) -> Reauth {
    body.map(|b| b.into_inner()).unwrap_or_default()
}

pub async fn delete_user(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    path: web::types::Path<String>,
    body: Option<web::types::Json<Reauth>>,
) -> Result<HttpResponse> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let username = path.into_inner();
    let body = reauth_body(body);
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    match accounts::delete_account(&state.db, &username).await? {
        Guarded::Done => {}
        Guarded::NotFound => return Ok(not_found("No such account")),
        Guarded::LastAdmin => return Ok(last_admin()),
    }
    audit(&req, &state, &caller, Action::Close, format!("deleted account {username}")).await;
    authz::revoke_lost(state.get_ref(), REVOKED).await;
    Ok(HttpResponse::NoContent().finish())
}

// ---- /roles ----

pub async fn list_roles(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    require!(authz::admin_caller(&req, &state).await);
    Ok(HttpResponse::Ok().json(&accounts::roles(&state.db).await?))
}

/// [body] as a [`RoleBody`], with grants that no longer exist dropped from
/// it first.
///
/// TODO: remove once no supported app sends `ssh_terminal` (the app's role
/// editor wrote it out with every save until the SSH terminal was removed
/// from the agent, migration 023); `Grants` refuses it, so without this every
/// role save from such an app would fail.
fn parse_role(
    mut body: web::types::Json<serde_json::Value>,
) -> std::result::Result<RoleBody, HttpResponse> {
    if let Some(grants) = body
        .get_mut("role")
        .and_then(|role| role.get_mut("grants"))
        .and_then(|grants| grants.as_object_mut())
    {
        grants.remove("ssh_terminal");
    }
    parse(body)
}

#[derive(Deserialize)]
pub struct RoleBody {
    role: Role,
    current_password: Option<String>,
}

pub async fn create_role(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let RoleBody {
        mut role,
        current_password,
    } = require!(parse_role(body));
    require!(reauth(&req, &state, &caller, current_password.as_deref()).await);
    if !valid_role_name(&role.name) {
        return Ok(bad_request("A role name is 1–32 of a-z, 0-9, '_' or '-'"));
    }
    if role.admin {
        return Ok(bad_request("Only the built-in admin role administers the agent"));
    }
    if let Err(e) = role.grants.validate() {
        return Ok(bad_request(&e));
    }
    if accounts::role(&state.db, &role.name).await?.is_some() {
        return Ok(conflict("A role with that name exists"));
    }
    role.builtin = false;
    accounts::insert_role(&state.db, &role).await?;
    audit(
        &req,
        &state,
        &caller,
        Action::Open,
        format!("created role {} with {}", role.name, serde_json::to_string(&role.grants)?),
    )
    .await;
    Ok(HttpResponse::Created().json(&role))
}

pub async fn update_role(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    path: web::types::Path<String>,
    body: web::types::Json<serde_json::Value>,
) -> Result<HttpResponse> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let name = path.into_inner();
    // A client older than a grant sends a role without it. Read as "not
    // granted", saving any other change from that client would take the
    // grant away without anyone having chosen to.
    let sent_virt = body
        .get("role")
        .and_then(|role| role.get("grants"))
        .is_some_and(|grants| grants.get("virt").is_some());
    let RoleBody {
        mut role,
        current_password,
    } = require!(parse_role(body));
    require!(reauth(&req, &state, &caller, current_password.as_deref()).await);
    let Some(stored) = accounts::role(&state.db, &name).await? else {
        return Ok(not_found("No such role"));
    };
    if role.name != stored.name {
        return Ok(bad_request("A role cannot be renamed"));
    }
    if role.admin != stored.admin {
        return Ok(bad_request("Whether a role administers the agent cannot be changed"));
    }
    if !sent_virt {
        role.grants.virt = stored.grants.virt;
    }
    if let Err(e) = role.grants.validate() {
        return Ok(bad_request(&e));
    }
    accounts::set_grants(&state.db, &name, &role.grants).await?;
    audit(
        &req,
        &state,
        &caller,
        Action::Close,
        format!("set role {name} to {}", serde_json::to_string(&role.grants)?),
    )
    .await;
    authz::revoke_lost(state.get_ref(), REVOKED).await;
    let updated = accounts::role(&state.db, &name).await?;
    Ok(HttpResponse::Ok().json(&updated))
}

pub async fn delete_role(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    path: web::types::Path<String>,
    body: Option<web::types::Json<Reauth>>,
) -> Result<HttpResponse> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let name = path.into_inner();
    let body = reauth_body(body);
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    let Some(stored) = accounts::role(&state.db, &name).await? else {
        return Ok(not_found("No such role"));
    };
    if stored.builtin {
        return Ok(error(
            StatusCode::FORBIDDEN,
            "forbidden",
            "A built-in role cannot be deleted",
        ));
    }
    if accounts::role_holders(&state.db, &name).await? > 0 {
        return Ok(conflict("Accounts still hold this role; give them another first"));
    }
    accounts::delete_role(&state.db, &name).await?;
    audit(&req, &state, &caller, Action::Close, format!("deleted role {name}")).await;
    Ok(HttpResponse::NoContent().finish())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn usernames_are_a_safe_alphabet() {
        assert!(valid_username("alice"));
        assert!(valid_username("ops.bot-2@lan"));
        assert!(!valid_username(""));
        assert!(!valid_username("a b"));
        assert!(!valid_username("../x"));
        assert!(!valid_username(&"a".repeat(65)));
    }
}
