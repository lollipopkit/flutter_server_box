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
//! The caller's `listen` grant (`core::permissions::ListenGrant`): loopback
//! only unless it says `public` — see [`bind_host`] — and only on its `ports`
//! when it names a range. Checked when the ticket is minted, when the socket
//! opens, when `listen` arrives, and again whenever a role changes while the
//! port is open.

use std::cell::RefCell;
use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use ntex::rt::spawn;
use ntex::service::{Service, ServiceCtx, fn_factory_with_config};
use ntex::util::ByteString;
use ntex::web::ws::{self, CloseCode, Frame, Message};
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::net::{TcpListener, TcpStream};

use super::audit::{self, Action, Event, Kind, Outcome};
use super::stream::next_change;
use super::ticket::Purpose;
use super::upgrade::WsSink;
use crate::api::authz;
use crate::api::server::AppState;
use crate::core::permissions::Grant;
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

/// What to bind for [host], or `None` when it may not be bound.
///
/// Loopback is always allowed — `127.0.0.0/8`, `::1`, `localhost`, and an
/// empty host, which means `127.0.0.1`. Anything else, `0.0.0.0` and `::`
/// included, only with [public] (`listen_public`): sshd's `GatewayPorts`, and
/// off for the same reason — a forward bound to every interface hands the port
/// to everyone who can reach this machine.
///
/// A name that is not an address is a public bind too: what it resolves to is
/// not known here, and `localhost` is the one name that is.
pub fn bind_host(host: &str, public: bool) -> Option<String> {
    let host = host.trim();
    if host.is_empty() || host.eq_ignore_ascii_case("localhost") {
        return Some("127.0.0.1".to_string());
    }
    let bare = host.trim_start_matches('[').trim_end_matches(']');
    let loopback = bare.parse::<IpAddr>().is_ok_and(|ip| ip.is_loopback());
    (loopback || public).then(|| bare.to_string())
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
    /// The panel account that listened, which is the only one that may claim.
    subject: String,
    accepted_at: Instant,
}

impl PendingStore {
    /// Room for one more listener, or `None` at [`MAX_LISTENERS`].
    pub fn open_listener(self: &Arc<Self>, subject: &str) -> Option<Listener> {
        let mut inner = self.lock();
        if inner.listeners >= MAX_LISTENERS {
            return None;
        }
        inner.listeners += 1;
        inner.next_listener += 1;
        Some(Listener {
            store: self.clone(),
            id: inner.next_listener,
            subject: subject.to_string(),
        })
    }

    /// Takes the connection waiting under [id], if [subject] is who listened
    /// for it.
    ///
    /// A connection asked for by anyone else is left where it is: an id is not
    /// a credential, and one seen in a log must not be a way to take the
    /// connection — nor to drop it before its owner can.
    pub fn claim(&self, id: &str, subject: &str) -> Option<(TcpStream, SocketAddr)> {
        let mut inner = self.lock();
        Self::expire_locked(&mut inner, Instant::now());
        if inner.waiting.get(id)?.subject != subject {
            return None;
        }
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
        self.inner.lock().unwrap_or_else(|e| e.into_inner())
    }
}

/// One listener's place in a [`PendingStore`]. Dropping it — the control
/// socket closing — frees the place and closes the connections it still has
/// waiting.
pub struct Listener {
    store: Arc<PendingStore>,
    id: u64,
    subject: String,
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
                subject: self.subject.clone(),
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
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
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
        return deny("origin", HttpResponse::Unauthorized().finish()).await;
    }

    let Some(protocol) = ws::subprotocols(&req)
        .find(|value| value.starts_with(TICKET_PROTOCOL_PREFIX))
        .map(str::to_owned)
    else {
        return deny("no ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let raw_ticket = &protocol[TICKET_PROTOCOL_PREFIX.len()..];
    let Ok(reservation) = app_state.tickets.reserve(raw_ticket, Purpose::Listen) else {
        return deny("ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let subject = reservation.subject().to_string();
    let tickets = app_state.tickets.clone();

    let admitted = authz::caller_named(&app_state, &subject)
        .await
        .filter(|caller| caller.check(Grant::Listen, &app_state, secure).is_ok());
    let Some(admitted) = admitted else {
        tickets.rollback(reservation);
        return deny("not granted", HttpResponse::Forbidden().finish()).await;
    };

    let ctx = Rc::new(ListenCtx {
        state: app_state,
        subject,
        remote_ip,
        secure,
        since: admitted.since,
    });

    let upgraded = super::upgrade::start::<_, _, web::Error>(
        req,
        Some(&protocol),
        fn_factory_with_config(move |sink: WsSink| {
            let ctx = ctx.clone();
            async move {
                Ok::<_, web::Error>(Control {
                    ctx,
                    sink,
                    phase: Rc::new(RefCell::new(Phase::Idle)),
                })
            }
        }),
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
    /// Panel account, from the ticket. Only it may claim what this accepts.
    subject: String,
    remote_ip: Option<String>,
    secure: bool,
    /// The account's password as of the upgrade — see `stream::ConnCtx`.
    since: i64,
}

impl ListenCtx {
    /// This socket's account, its role read again — none once its password
    /// has changed since the upgrade.
    async fn caller(&self) -> Option<authz::Caller> {
        authz::caller_named(&self.state, &self.subject)
            .await
            .filter(|caller| caller.since == self.since)
    }

    /// Whether this account may still hold a port bound to [bound], asked for
    /// as [requested] — its role read again.
    async fn may_hold(&self, bound: SocketAddr, requested: u16) -> bool {
        let Some(caller) = self.caller().await else {
            return false;
        };
        if caller.check(Grant::Listen, &self.state, self.secure).is_err() {
            return false;
        }
        let Some(listen) = &caller.grants().listen else {
            return false;
        };
        (listen.public || bound.ip().is_loopback()) && listen.permits_port(requested)
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

impl Service<Frame> for Control {
    type Response = Option<Message>;
    type Error = web::Error;

    async fn call(&self, frame: Frame, _: ServiceCtx<'_, Self>) -> Result<Self::Response, Self::Error> {
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
        let changes = ctx.state.grants_changed.subscribe();
        let caller = ctx.caller().await;
        let grant = match &caller {
            Some(caller) => match caller.check(Grant::Listen, &ctx.state, ctx.secure) {
                Ok(()) => caller.grants().listen.clone(),
                Err(_) => None,
            },
            None => None,
        };
        let Some(grant) = grant else {
            self.audit(Action::Denied, Outcome::Denied, "not granted").await;
            return Some(error_frame("forbidden", "This account may not listen"));
        };
        let Some(bind) = bind_host(host, grant.public) else {
            self.audit(Action::Denied, Outcome::Denied, &format!("public bind {host}:{port}"))
                .await;
            return Some(error_frame(
                "not_permitted",
                "Only loopback may be listened on; this account's role does not allow public binds",
            ));
        };
        if !grant.permits_port(port) {
            self.audit(Action::Denied, Outcome::Denied, &format!("port {port}"))
                .await;
            return Some(error_frame(
                "not_permitted",
                "This account's role does not allow listening on that port",
            ));
        }
        let Some(slot) = ctx.state.pending.open_listener(&ctx.subject) else {
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

        spawn(accept_loop(
            ctx.clone(),
            self.sink.clone(),
            listener,
            slot,
            changes,
            bound,
            port,
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
    mut changes: tokio::sync::broadcast::Receiver<&'static str>,
    bound: SocketAddr,
    requested: u16,
) {
    let disconnect = sink.on_disconnect();
    tokio::pin!(disconnect);
    loop {
        tokio::select! {
            _ = &mut disconnect => break,
            code = next_change(&mut changes) => {
                if ctx.may_hold(bound, requested).await {
                    continue;
                }
                let _ = sink
                    .send(error_frame(code, "This account may no longer listen on this port"))
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
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .detail(detail)
        .record(&ctx.state.db)
        .await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loopback_is_always_allowed() {
        for host in ["", "localhost", "LOCALHOST", "127.0.0.1", "127.8.9.10", "::1", "[::1]"] {
            assert!(bind_host(host, false).is_some(), "{host}");
        }
        assert_eq!(bind_host("", false).as_deref(), Some("127.0.0.1"));
        assert_eq!(bind_host("[::1]", false).as_deref(), Some("::1"));
    }

    #[test]
    fn anything_else_needs_listen_public() {
        for host in ["0.0.0.0", "::", "192.168.1.2", "example.com"] {
            assert!(bind_host(host, false).is_none(), "{host}");
            assert!(bind_host(host, true).is_some(), "{host}");
        }
    }

    /// A connected pair, so the store has a real socket to hold.
    async fn connection() -> (TcpStream, SocketAddr, TcpStream) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let client = TcpStream::connect(listener.local_addr().unwrap()).await.unwrap();
        let (server, peer) = listener.accept().await.unwrap();
        (server, peer, client)
    }

    #[tokio::test]
    async fn a_connection_is_claimed_once_by_who_listened() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener("alice").unwrap();
        let (stream, peer, _client) = connection().await;
        let id = slot.hold(stream, peer).unwrap();
        assert_eq!(id.len(), 32);

        // Someone else asking neither takes it nor drops it.
        assert!(store.claim(&id, "mallory").is_none());
        let (_, claimed_peer) = store.claim(&id, "alice").unwrap();
        assert_eq!(claimed_peer, peer);
        assert!(store.claim(&id, "alice").is_none());
    }

    #[tokio::test]
    async fn an_unclaimed_connection_expires() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener("alice").unwrap();
        let (stream, peer, _client) = connection().await;
        let id = slot.hold(stream, peer).unwrap();

        store.expire(Instant::now() + PENDING_TTL + Duration::from_secs(1));
        assert!(store.claim(&id, "alice").is_none());
    }

    #[tokio::test]
    async fn closing_the_listener_drops_what_it_has_waiting() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener("alice").unwrap();
        let other = store.open_listener("alice").unwrap();
        let (a, peer_a, _ca) = connection().await;
        let (b, peer_b, _cb) = connection().await;
        let mine = slot.hold(a, peer_a).unwrap();
        let theirs = other.hold(b, peer_b).unwrap();

        drop(slot);
        assert!(store.claim(&mine, "alice").is_none());
        assert!(store.claim(&theirs, "alice").is_some());
    }

    #[tokio::test]
    async fn a_listener_holds_at_most_max_pending() {
        let store = Arc::new(PendingStore::default());
        let slot = store.open_listener("alice").unwrap();
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
            .map(|_| store.open_listener("alice").unwrap())
            .collect();
        assert!(store.open_listener("alice").is_none());
        drop(slots);
        assert!(store.open_listener("alice").is_some());
    }
}
