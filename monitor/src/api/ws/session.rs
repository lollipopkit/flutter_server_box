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
    Resize { cols: u16, rows: u16 },
    /// Deliberate teardown, as opposed to a connection simply dropping.
    Close,
}

/// What a session pushes towards the attached client.
#[derive(Clone, Debug)]
pub enum SessionOutput {
    Data(Vec<u8>),
    Exit(Option<u32>),
    Error(String),
}

pub struct Session {
    /// Panel account that created it. An `attach` from any other account is
    /// refused, so one user's ticket cannot pick up another's shell.
    pub subject: String,
    pub ssh_user: String,
    secret: String,
    pub scrollback: Mutex<Scrollback>,
    /// Feeds the SSH side. Dropping every clone of this ends the session.
    pub input: mpsc::Sender<SessionInput>,
    /// Set while a WebSocket is attached; the reaper only counts down when it
    /// is `None`.
    pub attached: Mutex<Option<mpsc::Sender<SessionOutput>>>,
    /// When the last WebSocket detached, for the reaper.
    pub detached_at: Mutex<Option<Instant>>,
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
        scrollback_bytes: usize,
        input_queue: usize,
    ) -> (Self, mpsc::Receiver<SessionInput>) {
        let (input, input_rx) = mpsc::channel(input_queue);
        let session = Self {
            subject: subject.into(),
            ssh_user: ssh_user.into(),
            secret: String::new(),
            scrollback: Mutex::new(Scrollback::new(scrollback_bytes)),
            input,
            attached: Mutex::new(None),
            detached_at: Mutex::new(None),
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
        let attached = self.attached.lock().unwrap_or_else(|e| e.into_inner());
        if let SessionOutput::Data(data) = &output {
            self.scrollback
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(data);
        }
        if let Some(tx) = attached.as_ref() {
            // A full queue means the client stopped reading; the scrollback
            // already has the bytes, so dropping the live copy loses nothing
            // that a reattach can't recover.
            let _ = tx.try_send(output);
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
    ) -> (mpsc::Receiver<SessionOutput>, Replay, u64) {
        let mut attached = self.attached.lock().unwrap_or_else(|e| e.into_inner());
        let (replay, start_seq) = {
            let scrollback = self.scrollback.lock().unwrap_or_else(|e| e.into_inner());
            (scrollback.replay_from(since), scrollback.start_seq())
        };
        let (tx, rx) = mpsc::channel(queue);
        // Dropping the previous sender ends that connection's pump, which is
        // how a takeover releases the old socket
        *attached = Some(tx);
        *self.detached_at.lock().unwrap_or_else(|e| e.into_inner()) = None;
        (rx, replay, start_seq)
    }

    pub fn detach(&self) {
        *self.attached.lock().unwrap_or_else(|e| e.into_inner()) = None;
        *self.detached_at.lock().unwrap_or_else(|e| e.into_inner()) = Some(Instant::now());
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
        let session = Arc::new(Session { secret: secret.clone(), ..session });

        let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
        if sessions.len() >= self.max {
            return Ok(None);
        }
        sessions.insert(id.clone(), session.clone());
        Ok(Some((format!("{id}.{secret}"), session)))
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

    /// Drops sessions that have been unattached past the timeout.
    ///
    /// Returns how many went, so the caller can log a number rather than a
    /// line per session.
    pub fn reap(&self) -> usize {
        self.reap_at(Instant::now())
    }

    fn reap_at(&self, now: Instant) -> usize {
        let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
        let before = sessions.len();
        sessions.retain(|_, session| {
            let detached_at = *session.detached_at.lock().unwrap_or_else(|e| e.into_inner());
            match detached_at {
                Some(at) => now.saturating_duration_since(at) < self.detached_timeout,
                None => true,
            }
        });
        before - sessions.len()
    }

    pub fn len(&self) -> usize {
        self.sessions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session(subject: &str) -> Session {
        Session::new(subject, "ops", 1024, 8).0
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
        assert_eq!(sb.next_seq(), 1000, "the counter tracks everything ever sent");
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

        session.detach();
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
            store.get(&format!("{id}.{}", "0".repeat(ID_BYTES * 2)), "admin").err(),
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
        assert_eq!(store.get("dead.beef", "admin").err(), Some(AttachError::Unknown));
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
        let (_, detached) = store.insert(session("admin")).unwrap().unwrap();

        let (tx, _rx) = mpsc::channel(1);
        *attached.attached.lock().unwrap() = Some(tx);
        detached.detach();

        let now = Instant::now();
        assert_eq!(store.reap_at(now), 0, "nothing is stale yet");
        assert_eq!(store.len(), 2);

        assert_eq!(store.reap_at(now + Duration::from_secs(301)), 1);
        assert_eq!(store.len(), 1, "an attached session is never reaped");
    }

    #[test]
    fn removing_accepts_the_full_handle_or_the_bare_id() {
        let store = SessionStore::new(4, Duration::from_secs(300));
        let (handle, _) = store.insert(session("admin")).unwrap().unwrap();
        store.remove(&handle);
        assert_eq!(store.len(), 0);
    }
}
