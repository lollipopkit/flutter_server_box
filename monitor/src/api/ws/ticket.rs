//! Single-use tickets authorising one WebSocket upgrade.
//!
//! Browsers cannot set an `Authorization` header on a WebSocket handshake, so
//! the bearer token has to travel some other way. Putting the JWT in the query
//! string would write it into ntex's access log on every connection, and it
//! stays valid for 24 hours. Instead the client exchanges its JWT — over an
//! ordinary authenticated `POST` — for a ticket that is single-use, expires in
//! seconds, and is bound to the terminal endpoint.
//!
//! The app takes the same path even though it *could* send a header: one
//! mechanism to audit and get right rather than two, at the cost of one extra
//! round trip on a connection that is about to carry an SSH session.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};

use crate::utils::error::{MonitorError, Result};
use crate::utils::secrets::{constant_time_eq, random_hex};

/// Long enough for a handshake that follows straight after the POST, short
/// enough that a ticket captured from memory or a proxy log is dead by the
/// time it's read.
const TTL: Duration = Duration::from_secs(30);

/// Upper bound on live tickets. Only an authenticated client can create them,
/// so this is a backstop against a buggy or hostile client looping on the
/// issue endpoint, not a security boundary.
const MAX_LIVE: usize = 256;
const MAX_PER_SUBJECT: usize = 32;

const ID_BYTES: usize = 16;
const SECRET_BYTES: usize = 32;

/// The only WebSocket endpoint the agent exposes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Purpose {
    Terminal,
}

struct Entry {
    /// Hex, compared in constant time. Never logged.
    secret: String,
    purpose: Purpose,
    subject: String,
    expires_at: Instant,
}

#[derive(Default)]
pub struct TicketStore {
    entries: Mutex<HashMap<String, Entry>>,
}

/// Why a ticket was refused. Deliberately not surfaced to the client in
/// detail — every failure answers the same 401, so a prober cannot tell how
/// far it got.
#[derive(Debug, PartialEq, Eq)]
pub enum TicketError {
    Malformed,
    Unknown,
    Expired,
    WrongPurpose,
    BadSecret,
}

/// The subject a ticket was issued to, or why it was refused. Named so the
/// signatures don't have to spell out `std::result::Result` to escape this
/// crate's `Result` alias.
pub type TicketResult = std::result::Result<String, TicketError>;

impl TicketStore {
    pub fn new() -> Self {
        Self::default()
    }

    /// Mints a ticket, returning the `id.secret` string to hand to the client.
    ///
    /// `subject` is the JWT subject that authorised it, carried through so the
    /// terminal can bind a resumable session to the account that created it.
    pub fn issue(&self, purpose: Purpose, subject: &str) -> Result<String> {
        self.issue_at(purpose, subject, Instant::now())
    }

    /// Validates and burns a ticket, returning the subject it was issued to.
    pub fn consume(&self, raw: &str, purpose: Purpose) -> TicketResult {
        self.consume_at(raw, purpose, Instant::now())
    }

    fn issue_at(&self, purpose: Purpose, subject: &str, now: Instant) -> Result<String> {
        let id = random_hex(ID_BYTES)?;
        let secret = random_hex(SECRET_BYTES)?;

        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        // Sweeping here rather than from a background task: issuing is the
        // only way the map grows, so it is also the only moment pruning is
        // needed. Unconsumed tickets otherwise linger for their TTL, which
        // costs a few dozen bytes each.
        entries.retain(|_, e| e.expires_at > now);
        if entries.len() >= MAX_LIVE {
            return Err(MonitorError::Auth(
                "Too many outstanding WebSocket tickets".to_string(),
            ));
        }
        let per_subject = entries.values().filter(|e| e.subject == subject).count();
        if per_subject >= MAX_PER_SUBJECT {
            return Err(MonitorError::Auth(
                "Too many outstanding WebSocket tickets for this account".to_string(),
            ));
        }

        entries.insert(
            id.clone(),
            Entry {
                secret: secret.clone(),
                purpose,
                subject: subject.to_string(),
                expires_at: now + TTL,
            },
        );
        Ok(format!("{id}.{secret}"))
    }

    fn consume_at(&self, raw: &str, purpose: Purpose, now: Instant) -> TicketResult {
        let Some((id, secret)) = raw.split_once('.') else {
            return Err(TicketError::Malformed);
        };

        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        // Removed on any id hit, including a wrong secret: a ticket id is only
        // ever delivered together with its secret, so anyone who can name one
        // already has the whole thing. Burning it on a mismatch turns a
        // guessing loop against a known id into a single attempt.
        let Some(entry) = entries.remove(id) else {
            return Err(TicketError::Unknown);
        };

        if entry.expires_at <= now {
            return Err(TicketError::Expired);
        }
        if entry.purpose != purpose {
            return Err(TicketError::WrongPurpose);
        }
        if !constant_time_eq(entry.secret.as_bytes(), secret.as_bytes()) {
            return Err(TicketError::BadSecret);
        }
        Ok(entry.subject)
    }

    #[cfg(test)]
    fn len(&self) -> usize {
        self.entries.lock().unwrap().len()
    }
}

/// Response body of `POST /api/v1/ws-ticket`.
#[derive(Serialize)]
pub struct TicketResponse {
    pub ticket: String,
    pub expires_in: u64,
}

impl TicketResponse {
    pub fn new(ticket: String) -> Self {
        Self {
            ticket,
            expires_in: TTL.as_secs(),
        }
    }
}

/// Request body of `POST /api/v1/ws-ticket`.
#[derive(Deserialize)]
pub struct TicketRequest {
    pub purpose: Purpose,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_ticket_works_exactly_once() {
        let store = TicketStore::new();
        let ticket = store.issue(Purpose::Terminal, "admin").unwrap();
        assert_eq!(store.consume(&ticket, Purpose::Terminal).unwrap(), "admin");
        assert_eq!(
            store.consume(&ticket, Purpose::Terminal),
            Err(TicketError::Unknown)
        );
    }

    #[test]
    fn expiry_is_enforced() {
        let store = TicketStore::new();
        let now = Instant::now();
        let ticket = store.issue_at(Purpose::Terminal, "admin", now).unwrap();
        assert_eq!(
            store.consume_at(&ticket, Purpose::Terminal, now + TTL + Duration::from_secs(1)),
            Err(TicketError::Expired)
        );
    }

    #[test]
    fn a_wrong_secret_burns_the_ticket() {
        let store = TicketStore::new();
        let ticket = store.issue(Purpose::Terminal, "admin").unwrap();
        let (id, _) = ticket.split_once('.').unwrap();
        let forged = format!("{id}.{}", "0".repeat(SECRET_BYTES * 2));

        assert_eq!(
            store.consume(&forged, Purpose::Terminal),
            Err(TicketError::BadSecret)
        );
        // Guessing the secret gets one shot, not unlimited attempts
        assert_eq!(
            store.consume(&ticket, Purpose::Terminal),
            Err(TicketError::Unknown)
        );
    }

    #[test]
    fn malformed_input_is_rejected_without_touching_the_store() {
        let store = TicketStore::new();
        let ticket = store.issue(Purpose::Terminal, "admin").unwrap();
        assert_eq!(
            store.consume("no-separator", Purpose::Terminal),
            Err(TicketError::Malformed)
        );
        assert_eq!(store.len(), 1);
        assert!(store.consume(&ticket, Purpose::Terminal).is_ok());
    }

    #[test]
    fn issuing_sweeps_expired_entries() {
        let store = TicketStore::new();
        let now = Instant::now();
        for _ in 0..10 {
            store.issue_at(Purpose::Terminal, "admin", now).unwrap();
        }
        assert_eq!(store.len(), 10);

        store
            .issue_at(Purpose::Terminal, "admin", now + TTL + Duration::from_secs(1))
            .unwrap();
        assert_eq!(store.len(), 1, "expired tickets should not accumulate");
    }

    #[test]
    fn outstanding_tickets_are_capped() {
        let store = TicketStore::new();
        let now = Instant::now();
        for _ in 0..MAX_LIVE {
            store.issue_at(Purpose::Terminal, "admin", now).unwrap();
        }
        assert!(store.issue_at(Purpose::Terminal, "admin", now).is_err());
    }

    #[test]
    fn tickets_are_unique_and_long_enough_to_be_unguessable() {
        let store = TicketStore::new();
        let a = store.issue(Purpose::Terminal, "admin").unwrap();
        let b = store.issue(Purpose::Terminal, "admin").unwrap();
        assert_ne!(a, b);

        let (id, secret) = a.split_once('.').unwrap();
        assert_eq!(id.len(), ID_BYTES * 2);
        assert_eq!(secret.len(), SECRET_BYTES * 2);
    }

    #[test]
    fn the_subject_survives_the_round_trip() {
        let store = TicketStore::new();
        let ticket = store.issue(Purpose::Terminal, "someone").unwrap();
        assert_eq!(store.consume(&ticket, Purpose::Terminal).unwrap(), "someone");
    }
}
