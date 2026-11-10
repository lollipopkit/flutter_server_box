//! `GET /api/v1/listen/ws` — a port listened on for the app's remote forwards.
//!
//! The other half of `api::ws::stream`. That endpoint dials out to an address
//! the app names; a remote forward (`ssh -R`) needs the opposite — a port on
//! this machine whose connections end up in the app. Without this a server
//! whose only door is the agent cannot have one.
//!
//! # Shape
//!
//! This socket is control only. The app sends one
//! `{"type":"listen","host":..,"port":..}`; the agent binds and answers
//! `{"type":"ready","port":..}`, then `{"type":"incoming","id":..,"peer":..}`
//! for every connection accepted. The app takes each one by opening a
//! `/api/v1/stream/ws` and sending `{"type":"accept","id":..}` instead of
//! `open`, and from there it is that endpoint's relay — its own socket, its own
//! backpressure, its own revocation. Nothing is multiplexed here: one slow
//! connection never holds up another.
//!
//! An accepted connection waits in [`PendingStore`] until it is claimed, for
//! [`PENDING_TTL`] at most. Closing this socket stops listening and drops every
//! connection of its own still waiting.
//!
//! # Authority
//!
//! The transport rule, and whatever address and port the system account may
//! bind — see [`bind_host`]. Checked when the ticket is minted, when the
//! socket opens, when `listen` arrives, and again on a password change while
//! the port is open (`AppState.password_changed`).

use crate::api::WebError;
use crate::utils::lock::LockExt;
use std::cell::RefCell;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use ntex::rt::spawn;
use ntex::service::{Ctx, Service};
use ntex::util::ByteString;
use ntex::web::ws::{self, CloseCode, Frame, Message};
use ntex::web::{HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::net::{TcpListener, TcpStream};

use super::audit::{self, Action, Event, Kind, Outcome};
use super::live::{Ending, LiveKind};
use super::ticket::Purpose;
use super::upgrade::WsSink;
use crate::api::authz;
use crate::api::server::AppState;
use crate::utils::secrets::random_hex;

const TICKET_PROTOCOL_PREFIX: &str = "sbm-ticket.";

/// How long an accepted connection waits for the app to take it.
///
/// The app opens a relay the moment it hears `incoming`, so this is far more
/// than a claim takes — it is the bound on a connection held for an app that
/// went away without closing the control socket.
pub const PENDING_TTL: Duration = Duration::from_secs(10);

/// Connections one listener may have waiting. Past it a new one is closed as
/// it arrives: something is connecting faster than the app takes them, and
/// holding more would be holding sockets for nobody.
pub const MAX_PENDING: usize = 64;

/// Listeners the agent holds at once, across every client.
pub const MAX_LISTENERS: usize = 32;

/// What to bind for [host]: an empty host and `localhost` are `127.0.0.1`;
/// anything else is bound as given, as far as the system account may.
pub fn bind_host(host: &str) -> String {
    let host = host.trim();
    if host.is_empty() || host.eq_ignore_ascii_case("localhost") {
        return "127.0.0.1".to_string();
    }
    host.trim_start_matches('[').trim_end_matches(']').to_string()
}

/// Connections a listener accepted and the app has not taken yet.
///
/// Shared by every listener, since the relay that claims one is a different
/// socket from the listener that accepted it and can only find it by id.
#[derive(Default)]
pub struct PendingStore {
    inner: Mutex<Inner>,
}

#[derive(Default)]
struct Inner {
    next_listener: u64,
    listeners: usize,
    waiting: HashMap<String, Waiting>,
}

struct Waiting {
    stream: TcpStream,
    peer: SocketAddr,
    listener: u64,
    accepted_at: Instant,
}

impl PendingStore {
    /// Room for one more listener, or `None` at [`MAX_LISTENERS`].
    pub fn open_listener(self: &Arc<Self>) -> Option<Listener> {
        let mut inner = self.lock();
        if inner.listeners >= MAX_LISTENERS {
            return None;
        }
        inner.listeners += 1;
        inner.next_listener += 1;
        Some(Listener {
            store: self.clone(),
            id: inner.next_listener,
        })
    }

    /// Takes the connection waiting under [id].
    pub fn claim(&self, id: &str) -> Option<(TcpStream, SocketAddr)> {
        let mut inner = self.lock();
        Self::expire_locked(&mut inner, Instant::now());
        inner.waiting.remove(id).map(|w| (w.stream, w.peer))
    }

    /// Closes every connection that has waited past [`PENDING_TTL`] at [now].
    pub fn expire(&self, now: Instant) {
        Self::expire_locked(&mut self.lock(), now);
    }

    fn expire_locked(inner: &mut Inner, now: Instant) {
        inner
            .waiting
            .retain(|_, w| now.duration_since(w.accepted_at) < PENDING_TTL);
    }

    /// Poisoning is ignored: every critical section leaves the map whole, so a
    /// panic in one says nothing about the state it left.
    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner.locked()
    }
}

/// One listener's place in a [`PendingStore`]. Dropping it — the control
/// socket closing — frees the place and closes the connections it still has
/// waiting.
pub struct Listener {
    store: Arc<PendingStore>,
    id: u64,
}

impl Listener {
    /// Holds [stream] for the app and answers the id to announce it by, or
    /// `None` when it was closed instead — [`MAX_PENDING`] already waiting, or
    /// no randomness to name it with.
    pub fn hold(&self, stream: TcpStream, peer: SocketAddr) -> Option<String> {
        let mut inner = self.store.lock();
        PendingStore::expire_locked(&mut inner, Instant::now());
        let mine = inner.waiting.values().filter(|w| w.listener == self.id).count();
        if mine >= MAX_PENDING {
            return None;
        }
        let id = random_hex(16).ok()?;
        inner.waiting.insert(
            id.clone(),
            Waiting {
                stream,
                peer,
                listener: self.id,
                accepted_at: Instant::now(),
            },
        );
        Some(id)
    }
}

impl Drop for Listener {
    fn drop(&mut self) {
        let mut inner = self.store.lock();
        inner.listeners -= 1;
        inner.waiting.retain(|_, w| w.listener != self.id);
    }
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ClientMsg {
    /// Bind this address and announce what connects to it.
    Listen { host: String, port: u16 },
    Ping,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ServerMsg<'a> {
    /// Bound. [port] is the one the OS gave, which is what to tell the user
    /// when the app asked for `0`.
    Ready { port: u16 },
    /// A connection is waiting under [id]; take it with a stream `accept`.
    Incoming { id: &'a str, peer: &'a str },
    Error { code: &'a str, message: &'a str },
}

impl ServerMsg<'_> {
    fn frame(&self) -> Message {
        let json = serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string());
        Message::Text(ByteString::from(json))
    }
}

fn error_frame(code: &str, message: &str) -> Message {
    ServerMsg::Error { code, message }.frame()
}

pub async fn listen_ws(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    let remote_ip = audit::peer_ip(&req);

    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Listen, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(reason)
            .record(&app_state.db)
            .await;
        Ok(status)
    };

    // The same admission as `stream`, for the same reasons — see there.
    let secure = super::is_secure_transport(&req, app_state.tls_active);
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().build()).await;
    }

    let Some(protocol) = ws::subprotocols(&req)
        .find(|value| value.starts_with(TICKET_PROTOCOL_PREFIX))
        .map(str::to_owned)
    else {
        return deny("no ticket", HttpResponse::Unauthorized().build()).await;
    };
    let raw_ticket = &protocol[TICKET_PROTOCOL_PREFIX.len()..];
    let Ok(reservation) = app_state.tickets.reserve(raw_ticket, Purpose::Listen) else {
        return deny("ticket", HttpResponse::Unauthorized().build()).await;
    };
    let tickets = app_state.tickets.clone();

    let admitted = authz::caller(&app_state)
        .await
        .filter(|caller| caller.check(&app_state, secure).is_ok());
    let Some(admitted) = admitted else {
        tickets.rollback(reservation);
        return deny("not admitted", HttpResponse::Forbidden().build()).await;
    };

    let ctx = Rc::new(ListenCtx {
        state: app_state,
        remote_ip,
        secure,
        since: admitted.since,
    });

    let upgraded = super::upgrade::start(
        &req,
        Some(&protocol),
        move |sink: WsSink| Control {
            ctx,
            sink,
            phase: Rc::new(RefCell::new(Phase::Idle)),
        },
    )
    .await;
    if upgraded.is_ok() {
        tickets.commit(reservation);
    } else {
        tickets.rollback(reservation);
    }
    upgraded
}

struct ListenCtx {
    state: Arc<AppState>,
    /// Where the upgrade came from, for the audit log.
    remote_ip: Option<String>,
    secure: bool,
    /// The account's password as of the upgrade — see `stream::ConnCtx`.
    since: i64,
}

impl ListenCtx {
    /// This socket's account, read again — none once its password has
    /// changed since the upgrade.
    async fn caller(&self) -> Option<authz::Caller> {
        authz::caller(&self.state)
            .await
            .filter(|caller| caller.since == self.since)
    }

    /// Whether the port may still be held: the password unchanged, the link
    /// still one the machine may be acted on over.
    async fn may_hold(&self) -> bool {
        let Some(caller) = self.caller().await else {
            return false;
        };
        caller.check(&self.state, self.secure).is_ok()
    }
}

/// One `listen` per socket, like `stream`'s one `open`: a listener that could
/// be moved would be a second port for one ticket.
enum Phase {
    Idle,
    Listening,
}

struct Control {
    ctx: Rc<ListenCtx>,
    sink: WsSink,
    phase: Rc<RefCell<Phase>>,
}

impl Service<WsSink, Frame> for Control {
    type Res = Option<Message>;
    type Error = WebError;

    async fn call(&self, frame: Frame, _: Ctx<'_, Self, WsSink>) -> Result<Self::Res, Self::Error> {
        match frame {
            Frame::Text(data) => Ok(self.on_control(&data).await),
            // Bytes travel over the stream sockets that claim connections,
            // never here.
            Frame::Binary(_) | Frame::Continuation(_) => Ok(Some(error_frame(
                "bad_request",
                "This socket carries control messages only",
            ))),
            Frame::Ping(payload) => Ok(Some(Message::Pong(payload))),
            Frame::Pong(_) => Ok(None),
            Frame::Close(_) => Ok(Some(Message::Close(Some(CloseCode::Normal.into())))),
        }
    }
}

impl Control {
    async fn on_control(&self, raw: &[u8]) -> Option<Message> {
        let Ok(msg) = serde_json::from_slice::<ClientMsg>(raw) else {
            return Some(error_frame("bad_request", "Unrecognised control message"));
        };
        match msg {
            ClientMsg::Ping => Some(Message::Text(ByteString::from("{\"type\":\"pong\"}"))),
            ClientMsg::Listen { host, port } => {
                if !matches!(
                    std::mem::replace(&mut *self.phase.borrow_mut(), Phase::Listening),
                    Phase::Idle
                ) {
                    return Some(error_frame("bad_request", "Already listening"));
                }
                self.listen(&host, port).await
            }
        }
    }

    async fn listen(&self, host: &str, port: u16) -> Option<Message> {
        let ctx = &self.ctx;
        // Before the check, for the reason `stream::open` gives.
        let changes = ctx.state.password_changed.subscribe();
        let allowed = match ctx.caller().await {
            Some(caller) => caller.check(&ctx.state, ctx.secure).is_ok(),
            None => false,
        };
        if !allowed {
            self.audit(Action::Denied, Outcome::Denied, "not allowed").await;
            return Some(error_frame("forbidden", "A port may not be listened on here"));
        }
        let bind = bind_host(host);
        let Some(slot) = ctx.state.pending.open_listener() else {
            return Some(error_frame("limit", "Too many listeners are open"));
        };
        let listener = match TcpListener::bind((bind.as_str(), port)).await {
            Ok(listener) => listener,
            Err(error) => {
                tracing::info!("Could not listen on {bind}:{port}: {error}");
                self.audit(Action::Denied, Outcome::Error, &format!("{bind}:{port}"))
                    .await;
                return Some(error_frame("bind_failed", "Could not listen on that address"));
            }
        };
        let Ok(bound) = listener.local_addr() else {
            return Some(error_frame("bind_failed", "Could not listen on that address"));
        };
        self.audit(Action::Open, Outcome::Ok, &bound.to_string()).await;

        // Sent here rather than returned, so it is on the socket before the
        // first `incoming` can be: a connection may arrive the moment the port
        // is bound.
        if self
            .sink
            .send(ServerMsg::Ready { port: bound.port() }.frame())
            .await
            .is_err()
        {
            return None;
        }

        let ending = ctx.state.live.register(changes, LiveKind::Listen, bound.to_string(), ctx.remote_ip.clone());
        spawn(accept_loop(
            ctx.clone(),
            self.sink.clone(),
            listener,
            slot,
            ending,
            bound,
        ));
        None
    }

    async fn audit(&self, action: Action, outcome: Outcome, detail: &str) {
        audit_listen(&self.ctx, action, outcome, detail).await;
    }
}

/// Accepts until the control socket goes or the account may no longer hold
/// the port, then closes it and everything of its own still waiting.
#[allow(clippy::too_many_arguments)]
async fn accept_loop(
    ctx: Rc<ListenCtx>,
    sink: WsSink,
    listener: TcpListener,
    slot: Listener,
    mut ending: Ending,
    bound: SocketAddr,
) {
    let disconnect = sink.on_disconnect();
    tokio::pin!(disconnect);
    loop {
        tokio::select! {
            _ = &mut disconnect => break,
            signal = ending.next() => {
                if signal.rechecks() && ctx.may_hold().await {
                    continue;
                }
                let _ = sink
                    .send(error_frame(signal.code(), signal.message()))
                    .await;
                let _ = sink.send(Message::Close(Some(CloseCode::Normal.into()))).await;
                break;
            }
            accepted = listener.accept() => {
                let (stream, peer) = match accepted {
                    Ok(accepted) => accepted,
                    Err(error) => {
                        // Out of descriptors, mostly: worth a pause rather
                        // than a loop that spins on the same error.
                        tracing::info!("Listener on {bound} could not accept: {error}");
                        tokio::time::sleep(Duration::from_millis(100)).await;
                        continue;
                    }
                };
                let Some(id) = slot.hold(stream, peer) else {
                    tracing::warn!(
                        "Listener on {bound} has {MAX_PENDING} connections waiting; closed one from {peer}"
                    );
                    continue;
                };
                // Closed here if the app never takes it, whatever else happens
                // in the meantime.
                let store = ctx.state.pending.clone();
                spawn(async move {
                    tokio::time::sleep(PENDING_TTL).await;
                    store.expire(Instant::now());
                });
                let peer = peer.to_string();
                let frame = ServerMsg::Incoming { id: &id, peer: &peer }.frame();
                if sink.send(frame).await.is_err() {
                    break;
                }
            }
        }
    }
    drop(listener);
    drop(slot);
    audit_listen(&ctx, Action::Close, Outcome::Ok, &bound.to_string()).await;
}

async fn audit_listen(ctx: &ListenCtx, action: Action, outcome: Outcome, detail: &str) {
    Event::new(Kind::Listen, action, outcome)
        .remote_ip(ctx.remote_ip.clone())
        .detail(detail)
        .record(&ctx.state.db)
        .await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_empty_host_and_localhost_are_loopback_and_the_rest_is_as_given() {
        assert_eq!(bind_host(""), "127.0.0.1");
        assert_eq!(bind_host("LOCALHOST"), "127.0.0.1");
        assert_eq!(bind_host("[::1]"), "::1");
        assert_eq!(bind_host("0.0.0.0"), "0.0.0.0");
    }

    /// A connected pair, so the store has a real socket to hold.
    async fn connection() -> (TcpStream, SocketAddr, TcpStream) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let client = TcpStream::connect(listener.local_addr().unwrap()).await.unwrap();
        let (server, peer) = listener.accept().await.unwrap();
        (server, peer, client)
    }

    #[tokio::test]
    async fn a_connection_is_claimed_once() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener().unwrap();
        let (stream, peer, _client) = connection().await;
        let id = slot.hold(stream, peer).unwrap();
        assert_eq!(id.len(), 32);

        let (_, claimed_peer) = store.claim(&id).unwrap();
        assert_eq!(claimed_peer, peer);
        assert!(store.claim(&id).is_none());
    }

    #[tokio::test]
    async fn an_unclaimed_connection_expires() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener().unwrap();
        let (stream, peer, _client) = connection().await;
        let id = slot.hold(stream, peer).unwrap();

        store.expire(Instant::now() + PENDING_TTL + Duration::from_secs(1));
        assert!(store.claim(&id).is_none());
    }

    #[tokio::test]
    async fn closing_the_listener_drops_what_it_has_waiting() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener().unwrap();
        let other = store.open_listener().unwrap();
        let (a, peer_a, _ca) = connection().await;
        let (b, peer_b, _cb) = connection().await;
        let mine = slot.hold(a, peer_a).unwrap();
        let theirs = other.hold(b, peer_b).unwrap();

        drop(slot);
        assert!(store.claim(&mine).is_none());
        assert!(store.claim(&theirs).is_some());
    }

    #[tokio::test]
    async fn a_listener_holds_at_most_max_pending() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener().unwrap();
        let mut clients = Vec::new();
        for _ in 0..MAX_PENDING {
            let (stream, peer, client) = connection().await;
            clients.push(client);
            assert!(slot.hold(stream, peer).is_some());
        }
        let (stream, peer, _client) = connection().await;
        assert!(slot.hold(stream, peer).is_none());
    }

    #[test]
    fn listeners_are_capped_and_freed() {
        let store = Arc::new(PendingStore::default());
        let slots: Vec<_> = (0..MAX_LISTENERS)
            .map(|_| store.open_listener().unwrap())
            .collect();
        assert!(store.open_listener().is_none());
        drop(slots);
        assert!(store.open_listener().is_some());
    }
}
