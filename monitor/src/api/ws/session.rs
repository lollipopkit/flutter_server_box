//! Terminal sessions that outlive the WebSocket driving them.
//!
//! A phone changing networks, a laptop sleeping, a flaky link — none of those
//! should cost the shell that was running. So the SSH session lives here,
//! keyed by an id the browser holds, and a reconnect reattaches to it.
//!
//! Two things make that safe rather than convenient:
//!
//! - The id is a bearer capability for an *already authenticated* shell. It is
//!   256 bits of system entropy, compared in constant time, bound to the panel
//!   account that created it, never logged, and never written to disk.
//! - Sessions exist only in memory. Restarting the agent ends every one of
//!   them, which is the correct behaviour for a live shell — persisting one
//!   would mean a process that just started inherits a session nobody is
//!   watching.
//!
//! Reattaching aims to be seamless rather than merely possible: see
//! [`Scrollback`] for how a short outage is recovered without clearing the
//! screen.

use std::collections::HashMap;
use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use tokio::sync::mpsc;

use crate::utils::error::Result;
use crate::utils::secrets::{constant_time_eq, random_hex};

const ID_BYTES: usize = 32;

/// PTY output held for reattach, with enough bookkeeping to send only what a
/// reconnecting client missed.
///
/// `next_seq` counts every byte ever written to the client. A client knows how
/// many bytes it has rendered — one number, needing no protocol support, since
/// WebSocket frames arrive whole or not at all — and sends it as `since` when
/// it reattaches. If that point is still inside the buffer, the gap alone gets
/// replayed and the screen carries on untouched. Only when an outage outlasts
/// the buffer does the client have to be reset and redrawn.
pub struct Scrollback {
    buf: VecDeque<u8>,
    capacity: usize,
    /// Total bytes ever produced, i.e. the sequence number just past the end.
    next_seq: u64,
}

/// What a reattaching client should be sent.
#[derive(Debug, PartialEq, Eq)]
pub enum Replay {
    /// Exactly the bytes it missed; its screen is still valid.
    Gap(Vec<u8>),
    /// Its position fell out of the buffer. The client must reset and redraw
    /// from whatever is left, and should say so — output was lost.
    Truncated(Vec<u8>),
}

impl Scrollback {
    pub fn new(capacity: usize) -> Self {
        Self {
            buf: VecDeque::with_capacity(capacity.min(64 * 1024)),
            capacity,
            next_seq: 0,
        }
    }

    pub fn push(&mut self, data: &[u8]) {
        self.next_seq += data.len() as u64;

        // A single write larger than the buffer: keep only its tail, which is
        // all that could have survived anyway
        let data = if data.len() > self.capacity {
            &data[data.len() - self.capacity..]
        } else {
            data
        };

        let overflow = (self.buf.len() + data.len()).saturating_sub(self.capacity);
        self.buf.drain(..overflow);
        self.buf.extend(data.iter().copied());
    }

    /// Sequence number of the oldest byte still held.
    pub fn start_seq(&self) -> u64 {
        self.next_seq - self.buf.len() as u64
    }

    pub fn next_seq(&self) -> u64 {
        self.next_seq
    }

    /// What to send a client that has rendered `since` bytes.
    pub fn replay_from(&self, since: u64) -> Replay {
        let start = self.start_seq();
        // `since > next_seq` shouldn't happen — a client can't have rendered
        // more than was sent — but a corrupted value must not panic on the
        // slice below, and treating it as "nothing missed" is the harmless
        // reading
        if since >= self.next_seq {
            return Replay::Gap(Vec::new());
        }
        if since < start {
            return Replay::Truncated(self.buf.iter().copied().collect());
        }
        let skip = (since - start) as usize;
        Replay::Gap(self.buf.iter().skip(skip).copied().collect())
    }
}

/// What the session task accepts from whichever WebSocket is attached.
pub enum SessionInput {
    Data(Vec<u8>),
    Resize {
        cols: u16,
        rows: u16,
    },
    /// Deliberate teardown, as opposed to a connection simply dropping.
    Close,
}

/// What a session pushes towards the attached client.
#[derive(Clone, Debug)]
pub enum SessionOutput {
    Data(Vec<u8>),
    Exit(Option<u32>),
    Error(String),
    FullAccessRevoked,
    ReplayRequired,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionAuth {
    Ssh,
    Local,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AttachmentId(u64);

struct AttachmentState {
    next_id: u64,
    current: Option<(AttachmentId, mpsc::Sender<SessionOutput>)>,
    detached_at: Option<Instant>,
    closed: bool,
    replay_requested: bool,
}

pub struct Session {
    /// Panel account that created it. An `attach` from any other account is
    /// refused, so one user's ticket cannot pick up another's shell.
    pub subject: String,
    pub ssh_user: String,
    pub auth: SessionAuth,
    secret: String,
    pub scrollback: Mutex<Scrollback>,
    /// Feeds the shell side. Dropping every clone of this ends the session.
    pub input: mpsc::Sender<SessionInput>,
    attachment: Mutex<AttachmentState>,
}

impl Session {
    /// A session and the receiver its shell task should read input from.
    ///
    /// The secret is deliberately not a constructor argument: it is minted by
    /// [`SessionStore::insert`], so no caller can accidentally supply a weak
    /// or reused one.
    pub fn new(
        subject: impl Into<String>,
        ssh_user: impl Into<String>,
        auth: SessionAuth,
        scrollback_bytes: usize,
        input_queue: usize,
    ) -> (Self, mpsc::Receiver<SessionInput>) {
        let (input, input_rx) = mpsc::channel(input_queue);
        let session = Self {
            subject: subject.into(),
            ssh_user: ssh_user.into(),
            auth,
            secret: String::new(),
            scrollback: Mutex::new(Scrollback::new(scrollback_bytes)),
            input,
            attachment: Mutex::new(AttachmentState {
                next_id: 0,
                current: None,
                detached_at: None,
                closed: false,
                replay_requested: false,
            }),
        };
        (session, input_rx)
    }

    /// Publishes output to whoever is attached, and always to the scrollback.
    ///
    /// Buffering unconditionally is the point: output produced while nobody is
    /// attached is exactly what reattaching needs to replay.
    pub fn publish(&self, output: SessionOutput) {
        // `attached` is taken first and held across the scrollback write, so
        // that [`Session::attach`] can read the scrollback and install its
        // sender as one atomic step. Otherwise output produced in between
        // would land in the buffer *after* the replay was computed and go to
        // a sender that is about to be replaced — visible to nobody.
        let mut attachment = self.attachment.lock().unwrap_or_else(|e| e.into_inner());
        if let SessionOutput::Data(data) = &output {
            self.scrollback
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(data);
        }
        if attachment.replay_requested {
            return;
        }
        let Some(tx) = attachment.current.as_ref().map(|(_, tx)| tx.clone()) else {
            return;
        };
        match tx.try_send(output) {
            Ok(()) => {}
            Err(mpsc::error::TrySendError::Full(_)) => {
                // Stop adding live output until the client reconnects. The
                // scrollback above remains authoritative, and this marker is
                // queued behind everything the client can still render.
                attachment.replay_requested = true;
                tokio::spawn(async move {
                    let _ = tx.send(SessionOutput::ReplayRequired).await;
                });
            }
            Err(mpsc::error::TrySendError::Closed(_)) => {
                attachment.current = None;
                attachment.detached_at = Some(Instant::now());
            }
        }
    }

    /// Takes the session over for a new connection.
    ///
    /// Returns the receiver its output should be pumped from, what the
    /// reconnecting client missed, and where the buffer now starts. Reading
    /// the scrollback and installing the sender happen under one lock, so no
    /// output can slip into the gap between "what to replay" and "where to
    /// send from here" — see [`Session::publish`].
    pub fn attach(
        &self,
        since: u64,
        queue: usize,
    ) -> Option<(AttachmentId, mpsc::Receiver<SessionOutput>, Replay, u64)> {
        let mut attachment = self.attachment.lock().unwrap_or_else(|e| e.into_inner());
        if attachment.closed {
            return None;
        }
        let (replay, start_seq) = {
            let scrollback = self.scrollback.lock().unwrap_or_else(|e| e.into_inner());
            (scrollback.replay_from(since), scrollback.start_seq())
        };
        let (tx, rx) = mpsc::channel(queue);
        let id = AttachmentId(attachment.next_id);
        attachment.next_id = attachment.next_id.wrapping_add(1);
        // Dropping the previous sender ends that connection's pump, which is
        // how a takeover releases the old socket
        attachment.current = Some((id, tx));
        attachment.detached_at = None;
        attachment.replay_requested = false;
        Some((id, rx, replay, start_seq))
    }

    pub fn detach(&self, id: AttachmentId) -> bool {
        let mut attachment = self.attachment.lock().unwrap_or_else(|e| e.into_inner());
        if !matches!(attachment.current.as_ref(), Some((current, _)) if *current == id) {
            return false;
        }
        attachment.current = None;
        attachment.detached_at = Some(Instant::now());
        true
    }

    fn close(&self) -> Option<mpsc::Sender<SessionOutput>> {
        let mut attachment = self.attachment.lock().unwrap_or_else(|e| e.into_inner());
        attachment.closed = true;
        attachment.detached_at = Some(Instant::now());
        attachment.current.take().map(|(_, sender)| sender)
    }
}

/// Every live terminal session, and the rules for getting at one.
pub struct SessionStore {
    sessions: Mutex<HashMap<String, Arc<Session>>>,
    max: usize,
    detached_timeout: Duration,
}

/// Why an attach was refused. All of them answer the same thing to the client;
/// the distinction is for the audit log.
#[derive(Debug, PartialEq, Eq)]
pub enum AttachError {
    Unknown,
    WrongSubject,
    BadSecret,
}

impl SessionStore {
    pub fn new(max: usize, detached_timeout: Duration) -> Self {
        Self {
            sessions: Mutex::new(HashMap::new()),
            max,
            detached_timeout,
        }
    }

    /// Registers a session, returning the `id.secret` handle for the client.
    ///
    /// `None` when the cap is reached. Expired sessions are reaped first, so a
    /// cap is only hit by genuinely live ones.
    pub fn insert(&self, session: Session) -> Result<Option<(String, Arc<Session>)>> {
        let id = random_hex(16)?;
        let secret = random_hex(ID_BYTES)?;
        let session = Arc::new(Session {
            secret: secret.clone(),
            ..session
        });

        let (expired, inserted) = {
            let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
            let expired = Self::take_expired(&mut sessions, Instant::now(), self.detached_timeout);
            let inserted = if sessions.len() >= self.max {
                None
            } else {
                sessions.insert(id.clone(), session.clone());
                Some((format!("{id}.{secret}"), session))
            };
            (expired, inserted)
        };
        Self::terminate(expired);
        Ok(inserted)
    }

    /// Looks up a session for `subject`, verifying the secret in constant time.
    pub fn get(
        &self,
        handle: &str,
        subject: &str,
    ) -> std::result::Result<Arc<Session>, AttachError> {
        let Some((id, secret)) = handle.split_once('.') else {
            return Err(AttachError::Unknown);
        };
        let sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
        let Some(session) = sessions.get(id) else {
            return Err(AttachError::Unknown);
        };
        if !constant_time_eq(session.secret.as_bytes(), secret.as_bytes()) {
            return Err(AttachError::BadSecret);
        }
        // Checked after the secret so a wrong id and a wrong owner are
        // indistinguishable to anyone who doesn't already hold the handle
        if session.subject != subject {
            return Err(AttachError::WrongSubject);
        }
        Ok(session.clone())
    }

    pub fn remove(&self, handle: &str) {
        let id = handle.split_once('.').map(|(id, _)| id).unwrap_or(handle);
        self.sessions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(id);
    }

    /// Removes and terminates every shell that bypassed SSH authentication.
    pub fn close_local(&self) -> usize {
        let local = {
            let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
            let ids = sessions
                .iter()
                .filter(|(_, session)| session.auth == SessionAuth::Local)
                .map(|(id, _)| id.clone())
                .collect::<Vec<_>>();
            ids.into_iter()
                .filter_map(|id| sessions.remove(&id))
                .collect::<Vec<_>>()
        };

        for session in &local {
            if let Some(output) = session.close() {
                let _ = output.try_send(SessionOutput::FullAccessRevoked);
            }
            if let Err(mpsc::error::TrySendError::Full(close)) =
                session.input.try_send(SessionInput::Close)
            {
                let input = session.input.clone();
                tokio::spawn(async move {
                    let _ = input.send(close).await;
                });
            }
        }
        local.len()
    }

    /// Drops sessions that have been unattached past the timeout.
    ///
    /// Returns how many went, so the caller can log a number rather than a
    /// line per session.
    pub fn reap(&self) -> usize {
        self.reap_at(Instant::now())
    }

    fn reap_at(&self, now: Instant) -> usize {
        let expired = {
            let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
            Self::take_expired(&mut sessions, now, self.detached_timeout)
        };
        let count = expired.len();
        Self::terminate(expired);
        count
    }

    fn take_expired(
        sessions: &mut HashMap<String, Arc<Session>>,
        now: Instant,
        timeout: Duration,
    ) -> Vec<Arc<Session>> {
        let ids = sessions
            .iter()
            .filter_map(|(id, session)| {
                let detached_at = session
                    .attachment
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .detached_at;
                detached_at
                    .filter(|at| now.saturating_duration_since(*at) >= timeout)
                    .map(|_| id.clone())
            })
            .collect::<Vec<_>>();
        ids.into_iter()
            .filter_map(|id| sessions.remove(&id))
            .collect()
    }

    fn terminate(sessions: Vec<Arc<Session>>) {
        for session in sessions {
            session.close();
            if let Err(mpsc::error::TrySendError::Full(close)) =
                session.input.try_send(SessionInput::Close)
            {
                let input = session.input.clone();
                tokio::spawn(async move {
                    let _ = input.send(close).await;
                });
            }
        }
    }

    pub fn len(&self) -> usize {
        self.sessions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session(subject: &str) -> Session {
        Session::new(subject, "ops", SessionAuth::Ssh, 1024, 8).0
    }

    #[test]
    fn a_short_outage_replays_only_the_gap() {
        let mut sb = Scrollback::new(1024);
        sb.push(b"hello ");
        let seen = sb.next_seq();
        sb.push(b"world");

        assert_eq!(sb.replay_from(seen), Replay::Gap(b"world".to_vec()));
    }

    #[test]
    fn a_client_that_missed_nothing_gets_nothing() {
        let mut sb = Scrollback::new(1024);
        sb.push(b"hello");
        assert_eq!(sb.replay_from(sb.next_seq()), Replay::Gap(Vec::new()));
    }

    #[test]
    fn an_outage_past_the_buffer_is_reported_as_truncated() {
        let mut sb = Scrollback::new(8);
        sb.push(b"aaaa");
        let seen = sb.next_seq();
        sb.push(b"bbbbbbbbbbbb");

        // The client's position is gone; it must reset rather than splice
        // unrelated bytes onto its screen
        match sb.replay_from(seen) {
            Replay::Truncated(data) => assert_eq!(data, b"bbbbbbbb"),
            other => panic!("expected truncation, got {other:?}"),
        }
    }

    #[test]
    fn the_buffer_never_exceeds_its_capacity() {
        let mut sb = Scrollback::new(16);
        for _ in 0..100 {
            sb.push(b"0123456789");
        }
        assert!(sb.buf.len() <= 16);
        assert_eq!(
            sb.next_seq(),
            1000,
            "the counter tracks everything ever sent"
        );
        assert_eq!(sb.start_seq(), 1000 - 16);
    }

    #[test]
    fn a_write_larger_than_the_buffer_keeps_its_tail() {
        let mut sb = Scrollback::new(4);
        sb.push(b"abcdefgh");
        assert_eq!(sb.buf.iter().copied().collect::<Vec<_>>(), b"efgh");
        assert_eq!(sb.next_seq(), 8);
    }

    #[test]
    fn an_impossible_position_is_treated_as_up_to_date() {
        // A corrupted `since` from a client must not panic the agent
        let mut sb = Scrollback::new(16);
        sb.push(b"abc");
        assert_eq!(sb.replay_from(u64::MAX), Replay::Gap(Vec::new()));
    }

    #[test]
    fn output_produced_while_detached_is_still_recoverable() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (_handle, session) = store.insert(session("admin")).unwrap().unwrap();

        let (attachment, _, _, _) = session.attach(0, 1).unwrap();
        session.detach(attachment);
        session.publish(SessionOutput::Data(b"while you were away".to_vec()));

        let sb = session.scrollback.lock().unwrap();
        assert_eq!(
            sb.replay_from(0),
            Replay::Gap(b"while you were away".to_vec())
        );
    }

    #[test]
    fn a_handle_only_works_for_the_account_that_made_it() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (handle, _) = store.insert(session("admin")).unwrap().unwrap();

        assert!(store.get(&handle, "admin").is_ok());
        assert_eq!(
            store.get(&handle, "someone-else").err(),
            Some(AttachError::WrongSubject)
        );
    }

    #[test]
    fn a_forged_secret_is_refused() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (handle, _) = store.insert(session("admin")).unwrap().unwrap();
        let (id, _) = handle.split_once('.').unwrap();

        assert_eq!(
            store
                .get(&format!("{id}.{}", "0".repeat(ID_BYTES * 2)), "admin")
                .err(),
            Some(AttachError::BadSecret)
        );
        // Unlike a ticket, a wrong secret must not destroy the session: that
        // would let anyone who learns an id kill a stranger's shell
        assert!(store.get(&handle, "admin").is_ok());
    }

    #[test]
    fn unknown_and_malformed_handles_are_refused() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        assert_eq!(store.get("nope", "admin").err(), Some(AttachError::Unknown));
        assert_eq!(
            store.get("dead.beef", "admin").err(),
            Some(AttachError::Unknown)
        );
    }

    #[test]
    fn the_session_cap_is_enforced() {
        let store = SessionStore::new(2, Duration::from_secs(300));
        assert!(store.insert(session("admin")).unwrap().is_some());
        assert!(store.insert(session("admin")).unwrap().is_some());
        assert!(store.insert(session("admin")).unwrap().is_none());
    }

    #[test]
    fn only_detached_sessions_are_reaped_and_only_after_the_timeout() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (_attached_handle, attached) = store.insert(session("admin")).unwrap().unwrap();
        let (detached_session, mut detached_input) =
            Session::new("admin", "ops", SessionAuth::Ssh, 1024, 8);
        let (_, detached) = store.insert(detached_session).unwrap().unwrap();

        let _attached = attached.attach(0, 1).unwrap();
        let (detached_id, _, _, _) = detached.attach(0, 1).unwrap();
        detached.detach(detached_id);

        let now = Instant::now();
        assert_eq!(store.reap_at(now), 0, "nothing is stale yet");
        assert_eq!(store.len(), 2);

        assert_eq!(store.reap_at(now + Duration::from_secs(301)), 1);
        assert_eq!(store.len(), 1, "an attached session is never reaped");
        assert!(matches!(detached_input.try_recv(), Ok(SessionInput::Close)));
    }

    #[test]
    fn insertion_reaps_expired_sessions_before_enforcing_the_cap() {
        let store = SessionStore::new(1, Duration::ZERO);
        let (old, mut old_input) = Session::new("admin", "ops", SessionAuth::Ssh, 1024, 8);
        let (_, old) = store.insert(old).unwrap().unwrap();
        let (attachment, _, _, _) = old.attach(0, 1).unwrap();
        old.detach(attachment);

        assert!(store.insert(session("admin")).unwrap().is_some());
        assert_eq!(store.len(), 1);
        assert!(matches!(old_input.try_recv(), Ok(SessionInput::Close)));
    }

    #[tokio::test]
    async fn a_slow_attachment_is_closed_and_recovers_from_scrollback() {
        let session = session("admin");
        let (_, mut output, _, _) = session.attach(0, 1).unwrap();

        session.publish(SessionOutput::Data(b"first".to_vec()));
        session.publish(SessionOutput::Data(b"second".to_vec()));
        session.publish(SessionOutput::Data(b"third".to_vec()));

        assert!(matches!(
            output.recv().await,
            Some(SessionOutput::Data(data)) if data == b"first"
        ));
        assert!(matches!(
            output.recv().await,
            Some(SessionOutput::ReplayRequired)
        ));
        let (_, _, replay, _) = session.attach(5, 1).unwrap();
        assert_eq!(replay, Replay::Gap(b"secondthird".to_vec()));
    }

    #[test]
    fn removing_accepts_the_full_handle_or_the_bare_id() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (handle, _) = store.insert(session("admin")).unwrap().unwrap();
        store.remove(&handle);
        assert_eq!(store.len(), 0);
    }

    #[test]
    fn a_stale_detach_cannot_clear_the_new_attachment() {
        let session = session("admin");
        let (old, _old_rx, _, _) = session.attach(0, 1).unwrap();
        let (new, mut new_rx, _, _) = session.attach(0, 1).unwrap();

        assert!(!session.detach(old));
        session.publish(SessionOutput::Data(b"still attached".to_vec()));
        assert!(matches!(
            new_rx.try_recv(),
            Ok(SessionOutput::Data(data)) if data == b"still attached"
        ));
        assert!(session.detach(new));
    }

    #[tokio::test]
    async fn closing_local_sessions_leaves_ssh_sessions_running() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (local, mut local_input) = Session::new("admin", "local", SessionAuth::Local, 1024, 8);
        let (ssh, mut ssh_input) = Session::new("admin", "ops", SessionAuth::Ssh, 1024, 8);
        let (local_handle, local) = store.insert(local).unwrap().unwrap();
        let (ssh_handle, ssh) = store.insert(ssh).unwrap().unwrap();
        let (_, mut local_output, _, _) = local.attach(0, 1).unwrap();
        let _ssh_attachment = ssh.attach(0, 1).unwrap();

        assert_eq!(store.close_local(), 1);
        assert_eq!(
            store.get(&local_handle, "admin").err(),
            Some(AttachError::Unknown)
        );
        assert!(store.get(&ssh_handle, "admin").is_ok());
        assert!(matches!(
            local_input.recv().await,
            Some(SessionInput::Close)
        ));
        assert!(matches!(
            local_output.recv().await,
            Some(SessionOutput::FullAccessRevoked)
        ));
        assert!(ssh_input.try_recv().is_err());
    }
}
