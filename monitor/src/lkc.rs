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
//! never lapses. A refresh the IdP refuses itself (any 4xx with its own
//! `error` but a 429: Rauthy says `JwtToken`, `NotFound`, `Forbidden`, never
//! `invalid_grant`) signs out; anything else keeps the session. A password change
//! signs out too ([`end_account`]): whoever held the old one may have
//! approved the sign-in with their own account.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use sbm_lkc::{DeviceAuthorization, DevicePoll, Failure, Tokens, User};
use serde::Serialize;
use sqlx::SqlitePool;

use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use crate::db::sealed::{self, Sealer};
use crate::utils::lock::LockExt;

/// How often [`watch`] renews the session and reads the account again: well
/// inside the refresh token's lifetime.
const WATCH_EVERY: Duration = Duration::from_secs(6 * 3600);
/// How long after start [`watch`] first looks.
const FIRST_WATCH: Duration = Duration::from_secs(10 * 60);

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
    /// The IdP granted it and its tokens are being stored: a cancel no
    /// longer ends it.
    finishing: bool,
    /// [`Lkc::epoch`] when it was asked for: one a password change came
    /// after is revoked, not stored, even once finishing.
    epoch: u64,
}

#[derive(Default)]
pub struct Lkc {
    client: OnceLock<Arc<sbm_lkc::Client>>,
    sign_in: Mutex<Option<SignIn>>,
    /// Raised by a password change: a sign-in started before it is not
    /// begun after it.
    epoch: AtomicU64,
    /// Held through a refresh: the IdP takes a refresh token once, so two at
    /// once would sign the second out. Also by what must not race one
    /// (signing out, finishing a sign-in, rereading the account).
    refreshing: tokio::sync::Mutex<()>,
    /// Set while a refresh token is being sent and its answer stored
    /// ([`Sending`]): then a row marked `refreshing` is being renewed, not
    /// left over by one that never finished.
    sending: AtomicBool,
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

    /// A refresh token is being sent until the value is dropped
    /// ([`session`]).
    pub fn sending(&self) -> Sending<'_> {
        self.sending.store(true, Ordering::Release);
        Sending(&self.sending)
    }

    fn is_sending(&self) -> bool {
        self.sending.load(Ordering::Acquire)
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

    /// Puts [view] in place as the sign-in waiting, ending the one before —
    /// unless a password change came since [epoch].
    pub fn begin(&self, view: SignInView, device_code: String, epoch: u64) -> Result<(), StartError> {
        let mut sign_in = self.sign_in.locked();
        if self.epoch() != epoch {
            return Err(StartError::PasswordChanged);
        }
        if sign_in.as_ref().is_some_and(|s| s.finishing) {
            return Err(StartError::Finishing);
        }
        *sign_in = Some(SignIn { view, device_code, finishing: false, epoch });
        Ok(())
    }

    /// Ends the sign-in waiting, if any; its poll stops at its next turn. One
    /// [finishing](SignIn::finishing) is let finish. True when one ended.
    pub fn cancel(&self) -> bool {
        let mut sign_in = self.sign_in.locked();
        let ends = sign_in.as_ref().is_some_and(|s| !s.finishing && s.view.failed.is_none());
        if !sign_in.as_ref().is_some_and(|s| s.finishing) {
            *sign_in = None;
        }
        ends
    }

    /// For a password change: ends the sign-in waiting, and one being asked
    /// for.
    fn end_epoch(&self) {
        let mut sign_in = self.sign_in.locked();
        self.epoch.fetch_add(1, Ordering::SeqCst);
        if !sign_in.as_ref().is_some_and(|s| s.finishing) {
            *sign_in = None;
        }
    }

    /// Whether a password change came after [device_code] was asked for.
    fn stale(&self, device_code: &str) -> bool {
        self.sign_in.locked().as_ref().filter(|s| s.device_code == device_code).is_none_or(|s| s.epoch != self.epoch())
    }

    /// Whether [device_code] is still the sign-in waiting.
    fn waiting(&self, device_code: &str) -> bool {
        self.sign_in.locked().as_ref().is_some_and(|s| s.device_code == device_code && s.view.failed.is_none())
    }

    /// Once the IdP granted [device_code]'s tokens: from here they are stored
    /// or revoked, whatever is cancelled. False when it is no longer the
    /// sign-in waiting.
    fn claim(&self, device_code: &str) -> bool {
        let mut sign_in = self.sign_in.locked();
        match sign_in.as_mut().filter(|s| s.device_code == device_code && s.view.failed.is_none()) {
            Some(s) => {
                s.finishing = true;
                true
            }
            None => false,
        }
    }

    /// Ends sign-in [device_code] once its outcome is stored: gone when it
    /// signed in, kept with [failed] for the panel to say why otherwise.
    fn settle(&self, device_code: &str, failed: Option<&'static str>) {
        let mut sign_in = self.sign_in.locked();
        let Some(s) = sign_in.as_mut().filter(|s| s.device_code == device_code) else { return };
        match failed {
            None => *sign_in = None,
            Some(code) => {
                s.view.failed = Some(code);
                s.finishing = false;
            }
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
}

/// Why a sign-in did not start.
#[derive(Debug)]
pub enum StartError {
    /// The password changed while the IdP was asked: whoever asked held the
    /// old one.
    PasswordChanged,
    /// Another was granted and is being stored.
    Finishing,
    Lkc(sbm_lkc::Error),
}

/// Starts a device sign-in, ending one already waiting.
pub async fn start(state: &Arc<AppState>) -> Result<SignInView, StartError> {
    let epoch = state.lkc.epoch();
    let client = state.lkc.client().map_err(StartError::Lkc)?;
    let device = client.start_device().await.map_err(StartError::Lkc)?;
    let view = SignInView {
        user_code: device.user_code.clone(),
        verification_uri: device.verification_uri.clone(),
        verification_uri_complete: device.verification_uri_complete.clone(),
        expires_at_ms: device.expires_at_ms,
        failed: None,
    };
    state.lkc.begin(view.clone(), device.device_code.clone(), epoch)?;
    tokio::spawn(poll(state.clone(), device));
    Ok(view)
}

/// Polls [device] while it is the sign-in waiting. Never aborted: a token
/// answer on its way when the sign-in is cancelled is revoked, not dropped.
async fn poll(state: Arc<AppState>, mut device: DeviceAuthorization) {
    let code = device.device_code.clone();
    let client = match state.lkc.client() {
        Ok(client) => client,
        Err(e) => return finish(&state, &code, Err(e)).await,
    };
    let tokens = loop {
        tokio::time::sleep(Duration::from_secs(device.interval_secs)).await;
        if !state.lkc.waiting(&code) {
            return;
        }
        match client.poll_device(&device).await {
            Ok(DevicePoll::Pending) => {}
            Ok(DevicePoll::SlowDown(secs)) => device.interval_secs = secs,
            Ok(DevicePoll::Done(tokens)) => {
                if !state.lkc.claim(&code) {
                    return revoke(&state, tokens.refresh);
                }
                break tokens;
            }
            Err(e) if e.transient() => tracing::debug!("LK Cloud sign-in: {e}"),
            Err(e) => return finish(&state, &code, Err(e)).await,
        }
    };
    // As fl_lib's `signIn`: no account read, no sign-in. Homebase is asked a
    // few times over while it is only unreachable; the grant is spent, so
    // the tokens are handed back rather than left live if it never answers.
    let mut user = client.user(&tokens.access).await;
    for wait in [2, 5, 10, 20] {
        match &user {
            Err(e) if e.transient() => {
                tokio::time::sleep(Duration::from_secs(wait)).await;
                user = client.user(&tokens.access).await;
            }
            _ => break,
        }
    }
    let outcome = match user {
        Ok(user) => Ok(Session { user, tokens }),
        Err(e) => {
            revoke(&state, tokens.refresh);
            Err(e)
        }
    };
    finish(&state, &code, outcome).await;
}

/// Ends sign-in [device_code] with [outcome].
async fn finish(state: &AppState, device_code: &str, outcome: Result<Session, sbm_lkc::Error>) {
    let event = |outcome: Outcome, detail: String| Event::new(Kind::Admin, Action::Write, outcome).detail(detail);
    match outcome {
        Ok(session) => {
            let refreshing = state.lkc.refreshing.lock().await;
            // Asked for under a password since changed: whoever approved it
            // may not be the person who holds the new one.
            if state.lkc.stale(device_code) {
                state.lkc.settle(device_code, Some("rejected"));
                drop(refreshing);
                tracing::warn!("LK Cloud sign-in: the password changed meanwhile, revoked");
                return revoke(state, session.tokens.refresh);
            }
            let previous = match load(&state.db, &state.sealer).await {
                Ok(previous) => previous.map(|p| p.tokens.refresh),
                Err(broken) => Some(broken.refresh),
            }
            .flatten();
            let stored = store(&state.db, &state.sealer, &session).await;
            if stored.is_ok() {
                state.lkc.remember(&session.tokens);
            }
            // Settled once stored, the lock still held: a read in between
            // sees the sign-in waiting or the account, never neither.
            state.lkc.settle(device_code, stored.as_ref().err().map(|_| "invalid"));
            drop(refreshing);
            if let Err(e) = stored {
                tracing::error!("LK Cloud sign-in: storing it: {e}");
                return revoke(state, session.tokens.refresh);
            }
            // The account it replaces is let go of at the IdP too.
            if previous.is_some() && previous != session.tokens.refresh {
                revoke(state, previous);
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
            state.lkc.settle(device_code, Some(code));
            event(Outcome::Denied, format!("LK Cloud sign-in: {code}")).record(&state.db).await;
        }
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
    let _sending = state.lkc.sending();
    match client.refresh(&session.tokens).await {
        Ok(tokens) => {
            let fresh = Session { tokens, ..session };
            // Into the marked row only, the mark cleared: one dropped
            // meanwhile (a password reset from the CLI) stays dropped.
            match store_refresh(&state.db, &state.sealer, &fresh.tokens).await {
                Ok(true) => {
                    state.lkc.remember(&fresh.tokens);
                    Some(fresh)
                }
                stored => {
                    if let Err(e) = stored {
                        tracing::error!("LK Cloud: storing a refresh, signing out: {e}");
                    }
                    let _ = forget(&state.db).await;
                    // Nothing holds the renewed token now.
                    revoke(state, fresh.tokens.refresh);
                    None
                }
            }
        }
        // Never reached the IdP (`sbm_lkc` reads any refusal of its own as
        // `Rejected` or `Expired`). `TooEarly` is not reached (`due` was
        // asked above); listed with what keeps the session, since nothing
        // was sent.
        Err(e) if matches!(e.failure, Failure::Unreachable | Failure::Refused | Failure::Denied | Failure::TooEarly) => {
            tracing::debug!("LK Cloud: refresh: {e}");
            // Left set, the next read signs out instead: safe either way.
            let _ = clear_refreshing(&state.db).await;
            Some(session)
        }
        // Taken back or run out, or sent with no answer this can use:
        // possibly spent.
        Err(e) => {
            tracing::warn!("LK Cloud: signed out, the refresh token is gone or may be spent: {e}");
            let _ = forget(&state.db).await;
            None
        }
    }
}

/// Reads the account from homebase again (`LkcClient.refresh`): a name or
/// avatar changed since.
///
/// Homebase refusing the token does not sign out here, as fl_lib's does: the
/// agent's clock is not to be trusted with an access token's expiry (a board
/// without an RTC, a suspend the monotonic clock did not count), and a token
/// it only thinks is live reads as refused. The next refresh tells: the IdP
/// refusing it signs out.
async fn reread(state: &AppState) {
    let Some(session) = session(state).await else { return };
    // The refresh did not go through: homebase would refuse the expired
    // token.
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
        Err(e) => tracing::debug!("LK Cloud: reading the account: {e}"),
    }
}

/// Signs out: the row is gone at once, the IdP is asked to forget the refresh
/// token after. True when there was a session, readable or not.
pub async fn sign_out(state: &AppState) -> sqlx::Result<bool> {
    let _ = state.lkc.cancel();
    let _refreshing = state.lkc.refreshing.lock().await;
    let refresh = match load(&state.db, &state.sealer).await {
        Ok(None) => return Ok(false),
        Ok(Some(session)) => session.tokens.refresh,
        Err(broken) => broken.refresh,
    };
    forget(&state.db).await?;
    revoke(state, refresh);
    Ok(true)
}

/// Before a password changes through the API: signed out while the row is
/// still there, so its refresh token is revoked (the change itself deletes
/// the row, `accounts::set_password_hash`, for the CLI's sake), and no sign-in
/// asked for so far is begun or stored.
pub async fn end_before_password_change(state: &AppState) {
    state.lkc.end_epoch();
    if let Err(e) = sign_out(state).await {
        tracing::error!("LK Cloud: signing out before a password change: {e}");
    }
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
    let row: Option<(String, bool)> = sqlx::query_as("SELECT user, refreshing FROM lkc_session WHERE id = 1")
        .fetch_optional(&state.db)
        .await
        .inspect_err(|e| tracing::warn!("LK Cloud: reading it: {e}"))
        .ok()
        .flatten();
    let (user, refreshing) = row?;
    // Marked while a refresh is being sent: still signed in. Marked with
    // none being sent, the refresh did not finish storing: the session is
    // over, its row dropped at the next renewal.
    if refreshing && !state.lkc.is_sending() {
        return None;
    }
    serde_json::from_str(&user).ok()
}

/// A refresh token being sent ([`Lkc::sending`]); over when dropped.
pub struct Sending<'a>(&'a AtomicBool);

impl Drop for Sending<'_> {
    fn drop(&mut self) {
        self.0.store(false, Ordering::Release);
    }
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
    // Soon after start too, an agent restarted more often than
    // [`WATCH_EVERY`] would otherwise never get there; not at once, as the
    // wall clock a stored expiry is read by may not be set yet (NTP on a
    // board without an RTC), and one running fast would refresh early.
    tokio::time::sleep(FIRST_WATCH).await;
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

/// [tokens] into the row marked `refreshing`, clearing the mark. False when
/// there is no such row any more.
async fn store_refresh(db: &SqlitePool, sealer: &Sealer, tokens: &Tokens) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
    let done = sqlx::query(
        "UPDATE lkc_session SET access_token = ?, refresh_token = ?, expires_at = ?, refreshing = 0, updated_at = ? \
         WHERE id = 1 AND refreshing = 1",
    )
    .bind(sealer.seal(sealed::LKC_ACCESS_TOKEN, &tokens.access)?)
    .bind(sealer.seal_opt(sealed::LKC_REFRESH_TOKEN, tokens.refresh.as_deref())?)
    .bind(tokens.expires_at_ms)
    .bind(sbm_lkc::now_ms())
    .execute(db)
    .await?;
    Ok(done.rows_affected() == 1)
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
        // A refresh lands in the marked row only.
        let renewed = session(120_000).tokens;
        assert!(!store_refresh(&db, &sealer, &renewed).await.unwrap());
        set_refreshing(&db).await.unwrap();
        assert!(store_refresh(&db, &sealer, &renewed).await.unwrap());
        assert_eq!(load(&db, &sealer).await.unwrap().unwrap().tokens, renewed);
        set_refreshing(&db).await.unwrap();
        forget(&db).await.unwrap();
        assert!(!store_refresh(&db, &sealer, &renewed).await.unwrap());
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
        assert!(matches!(lkc.begin(view(), "d1".into(), epoch), Err(StartError::PasswordChanged)));
        assert!(lkc.sign_in().is_none());
        // Once granted, it is claimed: a cancel lets it finish.
        lkc.begin(view(), "d2".into(), lkc.epoch()).unwrap();
        assert!(lkc.claim("d2") && !lkc.claim("d1"));
        assert!(!lkc.cancel());
        assert!(lkc.waiting("d2") && !lkc.stale("d2"));
        // Nor does another take its place meanwhile.
        assert!(matches!(lkc.begin(view(), "d3".into(), lkc.epoch()), Err(StartError::Finishing)));
        // A password change lets it finish only to be revoked.
        lkc.end_epoch();
        assert!(lkc.waiting("d2") && lkc.stale("d2"));
        lkc.settle("d2", None);
        assert!(lkc.sign_in().is_none());
        // One not claimed stops at its next turn.
        lkc.begin(view(), "d4".into(), lkc.epoch()).unwrap();
        assert!(lkc.cancel());
        assert!(!lkc.waiting("d4"));
    }
}
