//! What is open through the agent right now, besides terminal sessions
//! (`session::SessionStore`): relayed connections, listened ports, guest
//! consoles and remote desktops — each one listed by `GET /live` and ended one
//! at a time by `DELETE /live/connections/{id}`.
//!
//! A connection registers when it starts carrying bytes and is gone from the
//! list when its [`Ending`] drops, so the list cannot hold one that already
//! ended. The [`Ending`] is also what its loop waits on: the password changing
//! (as before) or this one connection being ended.

use crate::utils::lock::LockExt;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use serde::Serialize;
use tokio::sync::{broadcast, watch};

use super::stream::next_change;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LiveKind {
    /// A TCP connection relayed for the caller (`/stream/ws` `open`): a
    /// forwarded port or a VNC desktop.
    Stream,
    /// A connection a listened port took, handed to the caller (`accept`).
    Accepted,
    /// A port the agent listens on for the caller (`/listen/ws`).
    Listen,
    /// A guest's console (`/virt/console/ws`).
    VirtConsole,
    /// A remote desktop over RDP (`/rdp/ws`).
    Rdp,
}

#[derive(Debug, Clone, Serialize)]
pub struct LiveConnection {
    pub id: String,
    pub kind: LiveKind,
    /// The address dialled or listened on, the peer a listened port took, or
    /// the guest a console is for.
    pub target: String,
    /// Where the client driving it connected from.
    pub remote_ip: Option<String>,
    pub opened_at: String,
}

struct Entry {
    connection: LiveConnection,
    end: watch::Sender<bool>,
}

#[derive(Default)]
pub struct LiveConnections {
    open: Mutex<HashMap<u64, Entry>>,
    next: AtomicU64,
}

impl LiveConnections {
    /// Lists a connection that starts now, and answers what its loop waits on.
    /// [changes] is `AppState.password_changed`, subscribed by the caller
    /// before its own checks so a change racing them is still delivered.
    pub fn register(
        self: &Arc<Self>,
        changes: broadcast::Receiver<&'static str>,
        kind: LiveKind,
        target: impl Into<String>,
        remote_ip: Option<String>,
    ) -> Ending {
        let id = self.next.fetch_add(1, Ordering::Relaxed) + 1;
        let (end, ended) = watch::channel(false);
        let connection = LiveConnection {
            id: id.to_string(),
            kind,
            target: target.into(),
            remote_ip,
            opened_at: chrono::Utc::now().to_rfc3339(),
        };
        self.lock().insert(id, Entry { connection, end });
        Ending { changes, ended, live: self.clone(), id }
    }

    /// Oldest first.
    pub fn list(&self) -> Vec<LiveConnection> {
        let mut open: Vec<(u64, LiveConnection)> = self
            .lock()
            .iter()
            .map(|(id, entry)| (*id, entry.connection.clone()))
            .collect();
        open.sort_by_key(|(id, _)| *id);
        open.into_iter().map(|(_, connection)| connection).collect()
    }

    /// Ends one; `false` when there is no such connection (any more).
    pub fn end(&self, id: &str) -> bool {
        let Ok(id) = id.parse::<u64>() else { return false };
        match self.lock().get(&id) {
            Some(entry) => {
                entry.end.send_replace(true);
                true
            }
            None => false,
        }
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<u64, Entry>> {
        self.open.locked()
    }
}

/// Why a connection's loop is told to stop.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Signal {
    /// The password changed, as `AppState.password_changed` said. The loop
    /// re-checks the caller: a notice can leave a connection what it needs.
    Changed(&'static str),
    /// This connection was ended (`DELETE /live/connections/{id}`). No
    /// re-check: it ends.
    Ended,
}

impl Signal {
    /// Whether the loop asks the caller again before ending.
    pub fn rechecks(self) -> bool {
        matches!(self, Signal::Changed(_))
    }

    /// The code a client is told.
    pub fn code(self) -> &'static str {
        match self {
            Signal::Changed(code) => code,
            Signal::Ended => "ended",
        }
    }

    pub fn message(self) -> &'static str {
        match self {
            Signal::Changed(_) => "The password changed",
            Signal::Ended => "Ended from another device",
        }
    }
}

/// A listed connection's stop signals; dropping it takes it off the list.
pub struct Ending {
    changes: broadcast::Receiver<&'static str>,
    ended: watch::Receiver<bool>,
    live: Arc<LiveConnections>,
    id: u64,
}

impl Ending {
    /// The next reason to stop. Cancel-safe, for a `select!` arm.
    pub async fn next(&mut self) -> Signal {
        tokio::select! {
            code = next_change(&mut self.changes) => Signal::Changed(code),
            () = ended(&mut self.ended) => Signal::Ended,
        }
    }
}

impl Drop for Ending {
    fn drop(&mut self) {
        self.live.lock().remove(&self.id);
    }
}

/// Resolves once [ended] holds `true`; never when its sender is gone, which
/// is only the entry being dropped by this same [`Ending`].
async fn ended(ended: &mut watch::Receiver<bool>) {
    loop {
        if *ended.borrow_and_update() {
            return;
        }
        if ended.changed().await.is_err() {
            std::future::pending::<()>().await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn a_connection_is_listed_until_its_ending_drops() {
        let live = Arc::new(LiveConnections::default());
        let (changes, _) = broadcast::channel(4);
        let first = live.register(changes.subscribe(), LiveKind::Stream, "10.0.0.2:5900", Some("192.0.2.1".into()));
        let second = live.register(changes.subscribe(), LiveKind::Listen, "127.0.0.1:8080", None);
        let ids: Vec<String> = live.list().into_iter().map(|c| c.id).collect();
        assert_eq!(ids, ["1", "2"]);
        drop(first);
        assert_eq!(live.list().len(), 1);
        drop(second);
        assert!(live.list().is_empty());
        assert!(!live.end("1"));
    }

    #[tokio::test]
    async fn ending_one_stops_only_that_one() {
        let live = Arc::new(LiveConnections::default());
        let (changes, _) = broadcast::channel(4);
        let mut one = live.register(changes.subscribe(), LiveKind::Stream, "a:1", None);
        let mut other = live.register(changes.subscribe(), LiveKind::Stream, "b:1", None);
        assert!(live.end("1"));
        assert_eq!(one.next().await, Signal::Ended);
        // Asked again (a loop that came round): still ended, not stuck.
        assert_eq!(one.next().await, Signal::Ended);
        let pending = tokio::time::timeout(std::time::Duration::from_millis(50), other.next()).await;
        assert!(pending.is_err(), "the other one was not ended");
        assert!(!live.end("nope"));
    }

    #[tokio::test]
    async fn a_password_change_reaches_every_one_and_asks_for_a_recheck() {
        let live = Arc::new(LiveConnections::default());
        let (changes, _) = broadcast::channel(4);
        let mut one = live.register(changes.subscribe(), LiveKind::Rdp, "host:3389", None);
        changes.send("password_changed").unwrap();
        let signal = one.next().await;
        assert_eq!(signal, Signal::Changed("password_changed"));
        assert!(signal.rechecks());
        assert!(!Signal::Ended.rechecks());
    }
}
