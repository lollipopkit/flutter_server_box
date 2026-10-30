//! The LK Cloud account this agent is signed in to (`sbm_lkc`), as the app's
//! fl_lib `LkcClient` is. Separate from the agent's own account
//! (`db::accounts`), which signs in to the panel.
//!
//! Signed in with a device code: the panel shows the code and the page, the
//! person approves it in any browser, and the agent polls — no address of
//! this agent has to be known to the IdP. Who signed in is what homebase
//! answers for the access token. The session is one row (`lkc_session`,
//! migration 041), its tokens sealed, never read back out over the API.
//!
//! The access token is refreshed only once due (`sbm_lkc::Tokens::due`), and
//! [`watch`] does so at start and often enough after that the refresh token
//! never lapses. The IdP's `invalid_grant`, or homebase refusing a token not
//! yet due, signs out; anything else keeps the session. A password change
//! signs out too ([`end_account`]): whoever held the old one may have
//! approved the sign-in with their own account.

use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;

use sbm_lkc::{DeviceAuthorization, DevicePoll, Failure, Tokens, User};
use serde::Serialize;
use sqlx::SqlitePool;
use tokio::task::AbortHandle;

use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use crate::db::sealed::{self, Sealer};
use crate::utils::lock::LockExt;

/// How often [`watch`] renews the session and reads the account again: well
/// inside the refresh token's lifetime.
const WATCH_EVERY: Duration = Duration::from_secs(6 * 3600);

/// A device sign-in as the panel shows it.
#[derive(Debug, Clone, Serialize)]
pub struct SignInView {
    pub user_code: String,
    pub verification_uri: String,
    pub verification_uri_complete: Option<String>,
    /// Unix milliseconds.
    pub expires_at_ms: i64,
    /// Why it ended without signing in: `denied`, `expired`, `rejected`,
    /// `invalid`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub failed: Option<&'static str>,
}

/// What is kept of a sign-in.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Session {
    pub user: User,
    pub tokens: Tokens,
}

struct SignIn {
    view: SignInView,
    device_code: String,
    task: Option<AbortHandle>,
}

#[derive(Default)]
pub struct Lkc {
    client: OnceLock<Arc<sbm_lkc::Client>>,
    sign_in: Mutex<Option<SignIn>>,
    /// Held through a refresh: the IdP takes a refresh token once, so two at
    /// once would sign the second out.
    refreshing: tokio::sync::Mutex<()>,
}

impl Lkc {
    fn client(&self) -> Result<Arc<sbm_lkc::Client>, sbm_lkc::Error> {
        if let Some(client) = self.client.get() {
            return Ok(client.clone());
        }
        let client = Arc::new(sbm_lkc::Client::new()?);
        Ok(self.client.get_or_init(|| client).clone())
    }

    /// The sign-in waiting or just failed, if any.
    pub fn sign_in(&self) -> Option<SignInView> {
        self.sign_in.locked().as_ref().map(|s| s.view.clone())
    }

    /// Puts [view] in place as the sign-in waiting, polled by [task], ending
    /// the one before.
    pub fn begin(&self, view: SignInView, device_code: String, task: AbortHandle) {
        let previous = self.sign_in.locked().replace(SignIn { view, device_code, task: Some(task) });
        if let Some(task) = previous.and_then(|s| s.task) {
            task.abort();
        }
    }

    /// Ends the sign-in waiting, if any.
    pub fn cancel(&self) {
        if let Some(task) = self.sign_in.locked().take().and_then(|s| s.task) {
            task.abort();
        }
    }

    /// The sign-in [device_code], taken out, while it is still the one
    /// waiting.
    fn take_if(&self, device_code: &str) -> Option<SignIn> {
        let mut sign_in = self.sign_in.locked();
        if sign_in.as_ref().is_some_and(|s| s.device_code == device_code && s.view.failed.is_none()) {
            sign_in.take()
        } else {
            None
        }
    }
}

/// Starts a device sign-in, ending one already waiting.
pub async fn start(state: &Arc<AppState>) -> Result<SignInView, sbm_lkc::Error> {
    let device = state.lkc.client()?.start_device().await?;
    let view = SignInView {
        user_code: device.user_code.clone(),
        verification_uri: device.verification_uri.clone(),
        verification_uri_complete: device.verification_uri_complete.clone(),
        expires_at_ms: device.expires_at_ms,
        failed: None,
    };
    let device_code = device.device_code.clone();
    let task = tokio::spawn(poll(state.clone(), device)).abort_handle();
    state.lkc.begin(view.clone(), device_code, task);
    Ok(view)
}

async fn poll(state: Arc<AppState>, mut device: DeviceAuthorization) {
    let client = match state.lkc.client() {
        Ok(client) => client,
        Err(e) => return finish(&state, &device.device_code, Err(e)).await,
    };
    let tokens = loop {
        tokio::time::sleep(Duration::from_secs(device.interval_secs)).await;
        match client.poll_device(&device).await {
            Ok(DevicePoll::Pending) => {}
            Ok(DevicePoll::SlowDown(secs)) => device.interval_secs = secs,
            Ok(DevicePoll::Done(tokens)) => break tokens,
            Err(e) if e.failure == Failure::Unreachable => tracing::debug!("LK Cloud sign-in: {e}"),
            Err(e) => return finish(&state, &device.device_code, Err(e)).await,
        }
    };
    // As fl_lib's `signIn`: no account read, no sign-in. The grant is spent,
    // so the tokens are handed back rather than left to expire.
    let outcome = match client.user(&tokens.access).await {
        Ok(user) => Ok(Session { user, tokens }),
        Err(e) => {
            if let Some(refresh) = tokens.refresh {
                let _ = client.revoke(&refresh).await;
            }
            Err(e)
        }
    };
    finish(&state, &device.device_code, outcome).await;
}

/// Ends sign-in [device_code], if it is still the one waiting.
async fn finish(state: &AppState, device_code: &str, outcome: Result<Session, sbm_lkc::Error>) {
    let event = |outcome: Outcome, detail: String| Event::new(Kind::Admin, Action::Write, outcome).detail(detail);
    match outcome {
        Ok(session) => {
            let _refreshing = state.lkc.refreshing.lock().await;
            // Taken out first, its abort handle with it: one cancelled, or
            // ended by a password change, before this point is not stored,
            // and nothing aborts the store below halfway.
            let Some(mut sign_in) = state.lkc.take_if(device_code) else {
                drop(_refreshing);
                return revoke(state, session.tokens.refresh);
            };
            let previous = load(&state.db, &state.sealer).await;
            if let Err(e) = store(&state.db, &state.sealer, &session).await {
                tracing::error!("LK Cloud sign-in: storing it: {e}");
                drop(_refreshing);
                sign_in.view.failed = Some("invalid");
                sign_in.task = None;
                state.lkc.sign_in.locked().get_or_insert(sign_in);
                return revoke(state, session.tokens.refresh);
            }
            drop(_refreshing);
            // The account it replaces is let go of at the IdP too.
            if let Some(previous) = previous.filter(|p| p.tokens.refresh != session.tokens.refresh) {
                revoke(state, previous.tokens.refresh);
            }
            event(Outcome::Ok, "LK Cloud sign-in".into()).record(&state.db).await;
        }
        Err(e) => {
            tracing::warn!("LK Cloud sign-in: {e}");
            let code = match e.failure {
                Failure::Denied => "denied",
                Failure::Expired => "expired",
                Failure::Rejected | Failure::Refused => "rejected",
                _ => "invalid",
            };
            set_failed(state, device_code, code);
            event(Outcome::Denied, format!("LK Cloud sign-in: {code}")).record(&state.db).await;
        }
    }
}

fn set_failed(state: &AppState, device_code: &str, code: &'static str) {
    if let Some(s) = state.lkc.sign_in.locked().as_mut().filter(|s| s.device_code == device_code) {
        s.view.failed = Some(code);
        s.task = None;
    }
}

/// The account signed in to, its access token refreshed first when due.
/// `None` when signed out, or signed out now because the session is over or
/// the credentials key no longer opens the tokens.
pub async fn session(state: &AppState) -> Option<Session> {
    let _refreshing = state.lkc.refreshing.lock().await;
    let session = load(&state.db, &state.sealer).await?;
    if !session.tokens.due(sbm_lkc::now_ms()) || session.tokens.refresh.is_none() {
        return Some(session);
    }
    let client = state.lkc.client().ok()?;
    match client.refresh(&session.tokens).await {
        Ok(tokens) => {
            let fresh = Session { tokens, ..session };
            if let Err(e) = store(&state.db, &state.sealer, &fresh).await {
                // The stored refresh token is spent; using it again reads to
                // the IdP as a leak and ends every session of the person.
                // Signed out instead.
                tracing::error!("LK Cloud: storing a refresh, signing out: {e}");
                let _ = forget(&state.db).await;
                return None;
            }
            Some(fresh)
        }
        Err(e) if e.failure == Failure::Rejected => {
            tracing::warn!("LK Cloud: signed out, the refresh token is gone: {e}");
            let _ = forget(&state.db).await;
            None
        }
        Err(e) => {
            tracing::debug!("LK Cloud: refresh: {e}");
            Some(session)
        }
    }
}

/// Reads the account from homebase again (`LkcClient.refresh`): a name or
/// avatar changed since, or the token no longer taken, which signs out.
async fn reread(state: &AppState) {
    let Some(session) = session(state).await else { return };
    // The refresh did not go through: homebase would refuse the expired
    // token, which is no word on the session.
    if session.tokens.due(sbm_lkc::now_ms()) {
        return;
    }
    let Ok(client) = state.lkc.client() else { return };
    let user = client.user(&session.tokens.access).await;
    let _refreshing = state.lkc.refreshing.lock().await;
    // Signed out, or signed in again, while homebase answered.
    if load(&state.db, &state.sealer).await.as_ref() != Some(&session) {
        return;
    }
    match user {
        Ok(user) if user != session.user => {
            if let Err(e) = store(&state.db, &state.sealer, &Session { user, ..session }).await {
                tracing::warn!("LK Cloud: storing the account: {e}");
            }
        }
        Ok(_) => {}
        Err(e) if e.failure == Failure::Rejected => {
            tracing::warn!("LK Cloud: signed out, homebase refused the token: {e}");
            let _ = forget(&state.db).await;
        }
        Err(e) => tracing::debug!("LK Cloud: reading the account: {e}"),
    }
}

/// Signs out: the row is gone at once, the IdP is asked to forget the refresh
/// token after.
pub async fn sign_out(state: &AppState) -> sqlx::Result<bool> {
    state.lkc.cancel();
    let _refreshing = state.lkc.refreshing.lock().await;
    let Some(session) = load(&state.db, &state.sealer).await else {
        return Ok(false);
    };
    forget(&state.db).await?;
    revoke(state, session.tokens.refresh);
    Ok(true)
}

/// For a password change: the sign-in waiting ends, and the account signed
/// in to is signed out of.
pub fn end_account(state: &Arc<AppState>) {
    state.lkc.cancel();
    let state = state.clone();
    tokio::spawn(async move {
        match sign_out(&state).await {
            Ok(true) => tracing::info!("LK Cloud: signed out, the password changed"),
            Ok(false) => {}
            Err(e) => tracing::error!("LK Cloud: signing out on a password change: {e}"),
        }
    });
}

/// The account as last stored, without renewing anything: what a read shows.
pub async fn current(state: &AppState) -> Option<Session> {
    load(&state.db, &state.sealer).await
}

/// Asks the IdP to forget [refresh], in the background.
fn revoke(state: &AppState, refresh: Option<String>) {
    let (Some(refresh), Ok(client)) = (refresh, state.lkc.client()) else { return };
    tokio::spawn(async move {
        if let Err(e) = client.revoke(&refresh).await {
            tracing::debug!("LK Cloud: revoking a refresh token: {e}");
        }
    });
}

/// Keeps the refresh token from lapsing and the account as homebase has it.
pub async fn watch(state: Arc<AppState>) {
    // At start too: an agent restarted more often than [`WATCH_EVERY`]
    // would otherwise never get there.
    loop {
        reread(&state).await;
        tokio::time::sleep(WATCH_EVERY).await;
    }
}

type Row = (String, String, Option<String>, i64);

async fn load(db: &SqlitePool, sealer: &Sealer) -> Option<Session> {
    let row: Row =
        match sqlx::query_as("SELECT user, access_token, refresh_token, expires_at FROM lkc_session WHERE id = 1")
            .fetch_optional(db)
            .await
        {
            Ok(row) => row?,
            Err(e) => {
                tracing::warn!("LK Cloud: reading it: {e}");
                return None;
            }
        };
    let (user, access, refresh, expires_at_ms) = row;
    let opened = (|| {
        Ok::<_, sealed::Error>((
            sealer.open(sealed::LKC_ACCESS_TOKEN, &access)?,
            sealer.open_opt(sealed::LKC_REFRESH_TOKEN, refresh.as_deref())?,
        ))
    })();
    let user = serde_json::from_str::<User>(&user);
    match (opened, user) {
        (Ok((access, refresh)), Ok(user)) if !access.is_empty() => {
            Some(Session { user, tokens: Tokens { access, refresh, expires_at_ms } })
        }
        (opened, user) => {
            match (opened, user) {
                (Err(e), _) => tracing::warn!("LK Cloud: its tokens: {e}"),
                (Ok((_, refresh)), Err(e)) => {
                    tracing::warn!("LK Cloud: its account: {e}");
                    // Opened, so let go of at the IdP rather than left live.
                    if let (Some(refresh), Ok(client)) = (refresh, sbm_lkc::Client::new()) {
                        tokio::spawn(async move { client.revoke(&refresh).await });
                    }
                }
                (Ok(_), Ok(_)) => tracing::warn!("LK Cloud: an empty access token"),
            }
            let _ = forget(db).await;
            None
        }
    }
}

async fn store(db: &SqlitePool, sealer: &Sealer, session: &Session) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    sqlx::query(
        "INSERT OR REPLACE INTO lkc_session (id, user, access_token, refresh_token, expires_at, updated_at) \
         VALUES (1, ?, ?, ?, ?, ?)",
    )
    .bind(serde_json::to_string(&session.user)?)
    .bind(sealer.seal(sealed::LKC_ACCESS_TOKEN, &session.tokens.access)?)
    .bind(sealer.seal_opt(sealed::LKC_REFRESH_TOKEN, session.tokens.refresh.as_deref())?)
    .bind(session.tokens.expires_at_ms)
    .bind(sbm_lkc::now_ms())
    .execute(db)
    .await?;
    Ok(())
}

async fn forget(db: &SqlitePool) -> sqlx::Result<()> {
    sqlx::query("DELETE FROM lkc_session").execute(db).await.map(drop)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session(expires_in_ms: i64) -> Session {
        Session {
            user: User {
                id: "u1".into(),
                name: "Ada".into(),
                group: "user".into(),
                avatar: None,
            },
            tokens: Tokens {
                access: "access".into(),
                refresh: Some("refresh".into()),
                expires_at_ms: sbm_lkc::now_ms() + expires_in_ms,
            },
        }
    }

    async fn db() -> SqlitePool {
        let db = sqlx::sqlite::SqlitePoolOptions::new().max_connections(1).connect("sqlite::memory:").await.unwrap();
        crate::db::database::MIGRATOR.run(&db).await.unwrap();
        db
    }

    #[tokio::test]
    async fn a_session_is_kept_sealed_and_read_back() {
        let (db, sealer) = (db().await, Sealer::temporary());
        assert!(load(&db, &sealer).await.is_none());
        let kept = session(60_000);
        store(&db, &sealer, &kept).await.unwrap();
        assert_eq!(load(&db, &sealer).await, Some(kept.clone()));
        let (access, refresh): (String, String) =
            sqlx::query_as("SELECT access_token, refresh_token FROM lkc_session").fetch_one(&db).await.unwrap();
        assert!(!access.contains("access") && !refresh.contains("refresh"));
        // One row: a second sign-in replaces it.
        store(&db, &sealer, &session(1)).await.unwrap();
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM lkc_session").fetch_one(&db).await.unwrap();
        assert_eq!(count, 1);
    }

    #[tokio::test]
    async fn tokens_another_key_sealed_sign_out() {
        let db = db().await;
        store(&db, &Sealer::temporary(), &session(60_000)).await.unwrap();
        assert!(load(&db, &Sealer::temporary()).await.is_none());
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM lkc_session").fetch_one(&db).await.unwrap();
        assert_eq!(count, 0);
    }
}
