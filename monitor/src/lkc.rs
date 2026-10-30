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

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

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
    /// Raised by a password change: a sign-in started before it is not
    /// begun after it.
    epoch: AtomicU64,
    /// Held through a refresh: the IdP takes a refresh token once, so two at
    /// once would sign the second out.
    refreshing: tokio::sync::Mutex<()>,
    /// The monotonic expiry of the access token this process received
    /// (`sbm_lkc::Tokens::deadline`), which storage does not keep.
    deadline: Mutex<Option<(String, Instant)>>,
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

    /// What [`Self::begin`] is to be given, read before a sign-in is asked
    /// for.
    pub fn epoch(&self) -> u64 {
        self.epoch.load(Ordering::SeqCst)
    }

    /// Puts [view] in place as the sign-in waiting, polled by [task], ending
    /// the one before — unless a password change came since [epoch], which
    /// ends [task] instead.
    pub fn begin(&self, view: SignInView, device_code: String, task: AbortHandle, epoch: u64) -> bool {
        let mut sign_in = self.sign_in.locked();
        if self.epoch() != epoch {
            task.abort();
            return false;
        }
        let previous = sign_in.replace(SignIn { view, device_code, task: Some(task) });
        drop(sign_in);
        if let Some(task) = previous.and_then(|s| s.task) {
            task.abort();
        }
        true
    }

    /// For a password change: ends the sign-in waiting, and one being asked
    /// for.
    fn end_epoch(&self) {
        let sign_in = self.sign_in.locked().take();
        self.epoch.fetch_add(1, Ordering::SeqCst);
        if let Some(task) = sign_in.and_then(|s| s.task) {
            task.abort();
        }
    }

    /// Once the IdP granted [device_code]'s tokens: nothing aborts its task
    /// any more, so they are stored or revoked. False when it is no longer
    /// the sign-in waiting.
    fn claim(&self, device_code: &str) -> bool {
        let mut sign_in = self.sign_in.locked();
        match sign_in.as_mut().filter(|s| s.device_code == device_code && s.view.failed.is_none()) {
            Some(s) => {
                s.task = None;
                true
            }
            None => false,
        }
    }

    /// [tokens] with the monotonic expiry this process knows for them.
    fn with_deadline(&self, mut tokens: Tokens) -> Tokens {
        if let Some((access, deadline)) = self.deadline.locked().as_ref()
            && *access == tokens.access
        {
            tokens.deadline = Some(*deadline);
        }
        tokens
    }

    fn remember(&self, tokens: &Tokens) {
        *self.deadline.locked() = tokens.deadline.map(|d| (tokens.access.clone(), d));
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
    let epoch = state.lkc.epoch();
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
    if !state.lkc.begin(view.clone(), device_code, task, epoch) {
        return Err(sbm_lkc::Error::new(Failure::Refused, "the password changed meanwhile"));
    }
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
            Ok(DevicePoll::Done(tokens)) => {
                if !state.lkc.claim(&device.device_code) {
                    return revoke(&state, tokens.refresh);
                }
                break tokens;
            }
            Err(e) if e.transient() => tracing::debug!("LK Cloud sign-in: {e}"),
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
            let previous = load(&state.db, &state.sealer).await.ok().flatten();
            if let Err(e) = store(&state.db, &state.sealer, &session).await {
                tracing::error!("LK Cloud sign-in: storing it: {e}");
                drop(_refreshing);
                sign_in.view.failed = Some("invalid");
                sign_in.task = None;
                state.lkc.sign_in.locked().get_or_insert(sign_in);
                return revoke(state, session.tokens.refresh);
            }
            state.lkc.remember(&session.tokens);
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
    let mut session = load_or_forget(state).await?;
    session.tokens = state.lkc.with_deadline(session.tokens);
    if !session.tokens.due(sbm_lkc::now_ms()) {
        return Some(session);
    }
    if session.tokens.refresh.is_none() {
        // As fl_lib: due, with nothing to renew it by, it is over.
        tracing::warn!("LK Cloud: signed out, the access token ran out and there is no refresh token");
        let _ = forget(&state.db).await;
        return None;
    }
    let client = state.lkc.client().ok()?;
    // Marked before it is sent, in the row: one whose answer is lost, or
    // whose renewal cannot be stored, is never sent again, a restart
    // included. Not sent when the mark cannot be written.
    if let Err(e) = set_refreshing(&state.db).await {
        tracing::warn!("LK Cloud: not refreshing, the session cannot be written: {e}");
        return Some(session);
    }
    match client.refresh(&session.tokens).await {
        Ok(tokens) => {
            let fresh = Session { tokens, ..session };
            // Stored with the mark cleared.
            if let Err(e) = store(&state.db, &state.sealer, &fresh).await {
                tracing::error!("LK Cloud: storing a refresh, signing out: {e}");
                let _ = forget(&state.db).await;
                return None;
            }
            state.lkc.remember(&fresh.tokens);
            Some(fresh)
        }
        // Never reached the IdP, or refused without spending it.
        Err(e) if matches!(e.failure, Failure::Unreachable | Failure::Refused | Failure::TooEarly) => {
            tracing::debug!("LK Cloud: refresh: {e}");
            // Left set, the next read signs out instead: safe either way.
            let _ = clear_refreshing(&state.db).await;
            Some(session)
        }
        // Taken back, or sent with no answer this can use: possibly spent.
        Err(e) => {
            tracing::warn!("LK Cloud: signed out, the refresh token is gone or may be spent: {e}");
            let _ = forget(&state.db).await;
            None
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
    if load(&state.db, &state.sealer).await.ok().flatten().as_ref() != Some(&session) {
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
            if forget(&state.db).await.is_ok() {
                revoke(state, session.tokens.refresh);
            }
        }
        Err(e) => tracing::debug!("LK Cloud: reading the account: {e}"),
    }
}

/// Signs out: the row is gone at once, the IdP is asked to forget the refresh
/// token after.
pub async fn sign_out(state: &AppState) -> sqlx::Result<bool> {
    state.lkc.cancel();
    let _refreshing = state.lkc.refreshing.lock().await;
    let Some(session) = load_or_forget(state).await else {
        return Ok(false);
    };
    forget(&state.db).await?;
    revoke(state, session.tokens.refresh);
    Ok(true)
}

/// For a password change: the sign-in waiting ends, and the account signed
/// in to is signed out of.
pub fn end_account(state: &Arc<AppState>) {
    state.lkc.end_epoch();
    let state = state.clone();
    tokio::spawn(async move {
        match sign_out(&state).await {
            Ok(true) => tracing::info!("LK Cloud: signed out, the password changed"),
            Ok(false) => {}
            Err(e) => tracing::error!("LK Cloud: signing out on a password change: {e}"),
        }
    });
}

/// The account as last stored, without renewing or opening anything: what a
/// read shows.
pub async fn current(state: &AppState) -> Option<User> {
    let user: Option<String> = sqlx::query_scalar("SELECT user FROM lkc_session WHERE id = 1")
        .fetch_optional(&state.db)
        .await
        .inspect_err(|e| tracing::warn!("LK Cloud: reading it: {e}"))
        .ok()
        .flatten();
    serde_json::from_str(&user?).ok()
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

type Row = (String, String, Option<String>, i64, bool);

/// A stored session that cannot be read back, and its refresh token when it
/// could be opened.
#[derive(Debug)]
struct Broken {
    refresh: Option<String>,
}

/// [load], dropping a session that cannot be read back: its refresh token
/// revoked when it could be opened. Under `refreshing`.
async fn load_or_forget(state: &AppState) -> Option<Session> {
    match load(&state.db, &state.sealer).await {
        Ok(session) => session,
        Err(broken) => {
            let _ = forget(&state.db).await;
            revoke(state, broken.refresh);
            None
        }
    }
}

async fn load(db: &SqlitePool, sealer: &Sealer) -> Result<Option<Session>, Broken> {
    let row: Row =
        match sqlx::query_as("SELECT user, access_token, refresh_token, expires_at, refreshing FROM lkc_session WHERE id = 1")
            .fetch_optional(db)
            .await
        {
            Ok(Some(row)) => row,
            Ok(None) => return Ok(None),
            Err(e) => {
                tracing::warn!("LK Cloud: reading it: {e}");
                return Ok(None);
            }
        };
    let (user, access, refresh, expires_at_ms, refreshing) = row;
    if refreshing {
        // Its refresh token may be spent: neither sent nor revoked again.
        tracing::warn!("LK Cloud: a refresh did not finish storing");
        return Err(Broken { refresh: None });
    }
    let opened = (|| {
        Ok::<_, sealed::Error>((
            sealer.open(sealed::LKC_ACCESS_TOKEN, &access)?,
            sealer.open_opt(sealed::LKC_REFRESH_TOKEN, refresh.as_deref())?,
        ))
    })();
    let user = serde_json::from_str::<User>(&user);
    match (opened, user) {
        (Ok((access, refresh)), Ok(user)) if !access.is_empty() => {
            Ok(Some(Session { user, tokens: Tokens::stored(access, refresh, expires_at_ms) }))
        }
        (Err(e), _) => {
            tracing::warn!("LK Cloud: its tokens: {e}");
            Err(Broken { refresh: None })
        }
        (Ok((_, refresh)), user) => {
            match user {
                Err(e) => tracing::warn!("LK Cloud: its account: {e}"),
                Ok(_) => tracing::warn!("LK Cloud: an empty access token"),
            }
            Err(Broken { refresh })
        }
    }
}

async fn store(db: &SqlitePool, sealer: &Sealer, session: &Session) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    sqlx::query(
        "INSERT OR REPLACE INTO lkc_session (id, user, access_token, refresh_token, expires_at, refreshing, updated_at) \
         VALUES (1, ?, ?, ?, ?, 0, ?)",
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

async fn set_refreshing(db: &SqlitePool) -> sqlx::Result<()> {
    let marked = sqlx::query("UPDATE lkc_session SET refreshing = 1 WHERE id = 1").execute(db).await?;
    if marked.rows_affected() == 1 { Ok(()) } else { Err(sqlx::Error::RowNotFound) }
}

async fn clear_refreshing(db: &SqlitePool) -> sqlx::Result<()> {
    sqlx::query("UPDATE lkc_session SET refreshing = 0 WHERE id = 1").execute(db).await.map(drop)
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
            tokens: Tokens::stored("access".into(), Some("refresh".into()), sbm_lkc::now_ms() + expires_in_ms),
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
        assert!(load(&db, &sealer).await.unwrap().is_none());
        let kept = session(60_000);
        store(&db, &sealer, &kept).await.unwrap();
        assert_eq!(load(&db, &sealer).await.unwrap(), Some(kept.clone()));
        let (access, refresh): (String, String) =
            sqlx::query_as("SELECT access_token, refresh_token FROM lkc_session").fetch_one(&db).await.unwrap();
        assert!(!access.contains("access") && !refresh.contains("refresh"));
        // One row: a second sign-in replaces it.
        store(&db, &sealer, &session(1)).await.unwrap();
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM lkc_session").fetch_one(&db).await.unwrap();
        assert_eq!(count, 1);
    }

    #[tokio::test]
    async fn tokens_another_key_sealed_cannot_be_read() {
        let db = db().await;
        store(&db, &Sealer::temporary(), &session(60_000)).await.unwrap();
        assert!(load(&db, &Sealer::temporary()).await.unwrap_err().refresh.is_none());
    }

    #[tokio::test]
    async fn a_refresh_not_stored_is_never_sent_again() {
        let (db, sealer) = (db().await, Sealer::temporary());
        store(&db, &sealer, &session(60_000)).await.unwrap();
        set_refreshing(&db).await.unwrap();
        // As after a restart: the token may be spent, so it is not handed back.
        assert!(load(&db, &sealer).await.unwrap_err().refresh.is_none());
        clear_refreshing(&db).await.unwrap();
        assert!(load(&db, &sealer).await.unwrap().is_some());
        // A store clears it.
        set_refreshing(&db).await.unwrap();
        store(&db, &sealer, &session(60_000)).await.unwrap();
        assert!(load(&db, &sealer).await.unwrap().is_some());
        // Nothing to mark: not sent.
        forget(&db).await.unwrap();
        assert!(set_refreshing(&db).await.is_err());
    }

    #[tokio::test]
    async fn an_unreadable_account_hands_back_its_refresh_token() {
        let (db, sealer) = (db().await, Sealer::temporary());
        store(&db, &sealer, &session(60_000)).await.unwrap();
        sqlx::query("UPDATE lkc_session SET user = '{}'").execute(&db).await.unwrap();
        assert_eq!(load(&db, &sealer).await.unwrap_err().refresh.as_deref(), Some("refresh"));
    }

    #[test]
    fn a_sign_in_asked_for_before_a_password_change_is_not_begun() {
        let rt = tokio::runtime::Builder::new_current_thread().build().unwrap();
        let _guard = rt.enter();
        let lkc = Lkc::default();
        let view = || SignInView {
            user_code: "ABCD".into(),
            verification_uri: "https://auth.example/device".into(),
            verification_uri_complete: None,
            expires_at_ms: i64::MAX,
            failed: None,
        };
        let epoch = lkc.epoch();
        lkc.end_epoch();
        let task = rt.spawn(std::future::pending::<()>());
        assert!(!lkc.begin(view(), "d1".into(), task.abort_handle(), epoch));
        assert!(lkc.sign_in().is_none());
        assert!(rt.block_on(task).unwrap_err().is_cancelled());
        // Once granted, it is claimed: nothing aborts it after.
        let task = rt.spawn(std::future::pending::<()>());
        assert!(lkc.begin(view(), "d2".into(), task.abort_handle(), lkc.epoch()));
        assert!(lkc.claim("d2") && !lkc.claim("d1"));
        lkc.cancel();
        assert!(!task.is_finished());
        task.abort();
    }
}
