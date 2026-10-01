//! `GET /api/v1/stream/ws` — a TCP connection to an address the caller names.
//!
//! This is what a monitor-only server has instead of an SSH channel: RDP, VNC
//! and port forwarding are one TCP connection each, and without this the app
//! has no way to reach either on a machine whose only door is an agent.
//!
//! # Authority
//!
//! The caller's role (`core::permissions`): `open` needs `connect`, and the
//! address has to be one its `allow` list names — a host name is resolved
//! here and every address it resolved to must be allowed, and those very
//! addresses are what is dialled, so a name cannot be re-resolved to
//! somewhere else between the check and the connection. `accept` needs
//! `listen`. Checked when the ticket is minted, when the socket opens, when
//! the frame arrives, and again whenever a role changes while bytes are
//! flowing (`AppState.grants_changed`).
//!
//! # Wire format
//!
//! - **Text** — the request first: `{"type":"open","host":..,"port":..}`, or
//!   `{"type":"accept","id":..}` to take a connection a remote forward's
//!   listener is holding (see `api::ws::listen`). Then control JSON, see
//!   [`ClientMsg`] and [`ServerMsg`].
//! - **Binary** — the bytes of that connection, both directions.
//!
//! One socket is one connection, and it ends when either side ends it. Unlike
//! the terminal there is no session store and no replay: RDP and VNC have
//! their own reconnect above this, and a resumed byte stream is not something
//! a protocol like VNC can make sense of anyway — a gap is a corrupted stream,
//! not a shorter one.
//!
//! The endpoint dials and relays; it understands neither protocol. That is what
//! makes it one endpoint for both, and for anything else that needs a socket.

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use ntex::rt::spawn;
use ntex::service::{Service, ServiceCtx, fn_factory_with_config};
use ntex::util::{ByteString, Bytes};
use ntex::web::ws::{self, CloseCode, Frame, Message};

use super::upgrade::WsSink;
use ntex::web::{self, HttpRequest, HttpResponse};
use ntex::ws::Item;
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::{broadcast, mpsc};

use super::audit::{self, Action, Event, Kind, Outcome};
use super::ticket::Purpose;
use crate::api::authz;
use crate::api::server::AppState;
use crate::core::permissions::Grant;

/// How many of the client's frames may wait for a target slower than the
/// client — a disk behind an upload — before the socket stops being read
/// (see [`Relay::ready`]), which is what holds the client back.
const TARGET_QUEUE: usize = 256;

const TICKET_PROTOCOL_PREFIX: &str = "sbm-ticket.";

/// A remote desktop session's screen is megabytes and one of them may be
/// dragged around while the other is used, so the read buffer is a frame's
/// worth rather than a line's.
const READ_BUFFER: usize = 32 * 1024;

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ClientMsg {
    /// Dial this address and start relaying.
    Open { host: String, port: u16 },
    /// Relay a connection a remote forward accepted, by the id its listener
    /// announced. The other way round from `open`: the connection came in
    /// rather than going out, and everything after it is the same.
    Accept { id: String },
    /// Ask the agent to say whether it is still there.
    ///
    /// The app has its own watchdog; this is for a caller that would rather
    /// ask than time out.
    Ping,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ServerMsg<'a> {
    /// The connection is up and bytes may flow.
    Ready,
    Error {
        code: &'a str,
        message: &'a str,
    },
    Exit,
}

impl ServerMsg<'_> {
    fn frame(&self) -> Message {
        let json = serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string());
        Message::Text(ByteString::from(json))
    }
}

pub async fn stream_ws(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
    let remote_ip = audit::peer_ip(&req);

    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Stream, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(reason)
            .record(&app_state.db)
            .await;
        Ok(status)
    };

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
    let Ok(reservation) = app_state.tickets.reserve(raw_ticket, Purpose::Stream) else {
        return deny("ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let subject = reservation.subject().to_string();
    let tickets = app_state.tickets.clone();

    // Checked here as well as at the ticket, so the answer cannot be stale by
    // the time a connection is actually made. Either grant will do; which one
    // the first frame needs is checked when it arrives.
    let admitted = authz::caller_named(&app_state, &subject).await.filter(|caller| {
        [Grant::Connect, Grant::Listen]
            .into_iter()
            .any(|grant| caller.check(grant, &app_state, secure).is_ok())
    });
    let Some(admitted) = admitted else {
        tickets.rollback(reservation);
        return deny("not granted", HttpResponse::Forbidden().finish()).await;
    };

    let ctx = Rc::new(ConnCtx {
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
            async move { Ok::<_, web::Error>(handler(ctx, sink)) }
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

struct ConnCtx {
    state: Arc<AppState>,
    /// Panel account, from the ticket. Recorded in the audit trail.
    subject: String,
    remote_ip: Option<String>,
    secure: bool,
    /// The account's password as of the upgrade (`Caller::since`). A relay
    /// ends once it moves: what was opened under the old one is not the
    /// account's any more — see `authz::end_account`.
    since: i64,
}

/// What a running relay was allowed under, to be asked again when a role
/// changes.
#[derive(Clone, Copy)]
enum Keep {
    /// An `open`: `connect`, to this peer.
    Connect(std::net::SocketAddr),
    /// An `accept`: `listen`.
    Listen,
}

impl ConnCtx {
    /// This connection's account, its role read again — none once its
    /// password has changed since the upgrade.
    async fn caller(&self) -> Option<authz::Caller> {
        authz::caller_named(&self.state, &self.subject)
            .await
            .filter(|caller| caller.since == self.since)
    }

    /// Whether what [keep] says this relay was opened under still holds.
    async fn still(&self, keep: Keep) -> bool {
        let Some(caller) = self.caller().await else {
            return false;
        };
        match keep {
            Keep::Connect(peer) => {
                caller.check(Grant::Connect, &self.state, self.secure).is_ok()
                    && caller.may_connect_to(peer)
            }
            Keep::Listen => caller.check(Grant::Listen, &self.state, self.secure).is_ok(),
        }
    }
}

/// What the connection is doing. One `open` per socket, like the terminal's
/// `open` — a relay that could be re-pointed mid-stream would be a way to
/// reuse a ticket for a second address.
enum Phase {
    Idle,
    Opening,
    Running(mpsc::Sender<Vec<u8>>),
    Done,
}

fn handler(ctx: Rc<ConnCtx>, sink: WsSink) -> Relay {
    let phase = Rc::new(RefCell::new(Phase::Idle));

    // The socket going away is what closes the connection: there is no session
    // to keep, so the reader loop is stopped by dropping the sender it holds.
    {
        let phase = phase.clone();
        let disconnect = sink.on_disconnect();
        spawn(async move {
            disconnect.await;
            *phase.borrow_mut() = Phase::Done;
        });
    }

    Relay { ctx, sink, phase }
}

/// One socket's frames: control, and bytes for the target.
struct Relay {
    ctx: Rc<ConnCtx>,
    sink: WsSink,
    phase: Rc<RefCell<Phase>>,
}

impl Service<Frame> for Relay {
    type Response = Option<Message>;
    type Error = web::Error;

    /// Not ready while the queue towards the target is full.
    ///
    /// The dispatcher calls this service for every frame without waiting for
    /// the last call to finish, and stops reading the socket only while this
    /// says no. Always ready, a target slower than the client — PVE writing an
    /// uploaded ISO to disk — left a call per frame waiting on the full queue,
    /// each holding its frame: the upload was read into this process as fast
    /// as the client could send it, and nothing held the client back.
    async fn ready(&self, _: ServiceCtx<'_, Self>) -> Result<(), Self::Error> {
        let sender = match &*self.phase.borrow() {
            Phase::Running(sender) => Some(sender.clone()),
            _ => None,
        };
        if let Some(sender) = sender {
            // A permit taken and given back: room for one more. A closed
            // queue is the call's to report.
            drop(sender.reserve().await);
        }
        Ok(())
    }

    async fn call(
        &self,
        frame: Frame,
        _: ServiceCtx<'_, Self>,
    ) -> Result<Self::Response, Self::Error> {
        let phase = &self.phase;
        match frame {
            Frame::Text(data) => Ok(on_control(&self.ctx, &self.sink, phase, &data).await),
            Frame::Binary(data) => Ok(on_input(phase, data.to_vec()).await),
            Frame::Continuation(
                Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data),
            ) => Ok(on_input(phase, data.to_vec()).await),
            Frame::Ping(payload) => Ok(Some(Message::Pong(payload))),
            Frame::Pong(_) => Ok(None),
            Frame::Close(_) => {
                *phase.borrow_mut() = Phase::Done;
                Ok(Some(Message::Close(Some(CloseCode::Normal.into()))))
            }
            Frame::Continuation(Item::FirstText(_)) => {
                Ok(Some(Message::Close(Some(CloseCode::Unsupported.into()))))
            }
        }
    }
}

async fn on_input(phase: &Rc<RefCell<Phase>>, data: Vec<u8>) -> Option<Message> {
    if data.is_empty() {
        return None;
    }
    let sender = match &*phase.borrow() {
        Phase::Running(sender) => Some(sender.clone()),
        _ => None,
    };
    match sender {
        Some(sender) => {
            // Room is what `ready` waited for; a failure is the target gone.
            if sender.send(data).await.is_err() {
                return Some(ServerMsg::Error {
                    code: "closed",
                    message: "The connection ended",
                }
                .frame());
            }
            None
        }
        None => Some(error_frame("bad_request", "No connection is open")),
    }
}

async fn on_control(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    raw: &[u8],
) -> Option<Message> {
    let Ok(msg) = serde_json::from_slice::<ClientMsg>(raw) else {
        return Some(error_frame("bad_request", "Unrecognised control message"));
    };

    match msg {
        ClientMsg::Ping => Some(Message::Text(ByteString::from("{\"type\":\"pong\"}"))),
        ClientMsg::Open { host, port } => {
            if !claim_idle(phase) {
                return Some(error_frame("bad_request", "A connection is already open"));
            }
            open(ctx, sink, phase, &host, port).await
        }
        ClientMsg::Accept { id } => {
            if !claim_idle(phase) {
                return Some(error_frame("bad_request", "A connection is already open"));
            }
            accept(ctx, sink, phase, &id).await
        }
    }
}

fn claim_idle(phase: &Rc<RefCell<Phase>>) -> bool {
    let previous = std::mem::replace(&mut *phase.borrow_mut(), Phase::Opening);
    if matches!(previous, Phase::Idle) {
        true
    } else {
        *phase.borrow_mut() = previous;
        false
    }
}

async fn open(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    host: &str,
    port: u16,
) -> Option<Message> {
    // Subscribed before anything else, so a role change landing anywhere
    // between this line and the relay task is still delivered: the broadcast
    // only reaches receivers that existed when it was sent, and the check
    // below is what a change racing the connect would otherwise slip past.
    let changes = ctx.state.grants_changed.subscribe();

    // Re-checked at the moment of use rather than trusted from the handshake:
    // a role can change while a ticket is outstanding, and the capabilities a
    // client was told earlier are not a boundary.
    let target = format!("{host}:{port}");
    let caller = match ctx.caller().await {
        Some(caller) => caller,
        None => {
            *phase.borrow_mut() = Phase::Done;
            audit_connect(ctx, &target, Outcome::Denied).await;
            return Some(error_frame("forbidden", "This account may not connect"));
        }
    };
    if let Err(why) = caller.check(Grant::Connect, &ctx.state, ctx.secure) {
        *phase.borrow_mut() = Phase::Done;
        audit_connect(ctx, &target, Outcome::Denied).await;
        return Some(error_frame(
            "forbidden",
            &format!("This account may not connect ({})", why.as_str()),
        ));
    }

    // Resolved once, here: every address the name has must be allowed, and
    // these addresses are the ones dialled. Resolving again to connect would
    // let a name that answered with an allowed address for the check answer
    // with another for the connection.
    let addrs: Vec<std::net::SocketAddr> = match tokio::net::lookup_host((host, port)).await {
        Ok(addrs) => addrs.collect(),
        Err(error) => {
            *phase.borrow_mut() = Phase::Done;
            audit_connect(ctx, &target, Outcome::Error).await;
            tracing::info!("Stream relay could not resolve {target}: {error}");
            return Some(error_frame("connect_failed", "Could not reach the target"));
        }
    };
    if addrs.is_empty() || !addrs.iter().all(|addr| caller.may_connect_to(*addr)) {
        *phase.borrow_mut() = Phase::Done;
        audit_connect(ctx, &target, Outcome::Denied).await;
        return Some(error_frame(
            "forbidden",
            "This account may not connect to that address",
        ));
    }

    let stream = match TcpStream::connect(&addrs[..]).await {
        Ok(stream) => stream,
        Err(error) => {
            *phase.borrow_mut() = Phase::Done;
            audit_connect(ctx, &target, Outcome::Error).await;
            tracing::info!("Stream relay could not reach {target}: {error}");
            return Some(error_frame("connect_failed", "Could not reach the target"));
        }
    };

    // What it actually reached, which is what a later role change is checked
    // against; one of `addrs` by construction.
    let peer = stream.peer_addr().unwrap_or(addrs[0]);
    *phase.borrow_mut() = relay(ctx, sink, stream, changes, Keep::Connect(peer));
    audit_connect(ctx, &target, Outcome::Ok).await;
    // The caller waits for this before treating the connection as usable: a
    // relay that answers `error` must not be raced by bytes the client already
    // wrote into it.
    Some(ServerMsg::Ready.frame())
}

/// Takes the connection a listener is holding under [id] and relays it.
///
/// Only one the same panel account listened for: an id is not a credential,
/// and a second account that saw one in a log must not be able to take the
/// connection it names. Anything else — unknown, expired, already taken — is
/// the same answer, so the answer says nothing about which.
async fn accept(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    id: &str,
) -> Option<Message> {
    // Before the check, for the reason `open` gives.
    let changes = ctx.state.grants_changed.subscribe();
    if !ctx.still(Keep::Listen).await {
        *phase.borrow_mut() = Phase::Done;
        return Some(error_frame("forbidden", "This account may not listen"));
    }
    let Some((stream, peer)) = ctx.state.pending.claim(id, &ctx.subject) else {
        *phase.borrow_mut() = Phase::Done;
        return Some(error_frame("not_found", "No such connection is waiting"));
    };
    *phase.borrow_mut() = relay(ctx, sink, stream, changes, Keep::Listen);
    audit_connect(ctx, &peer.to_string(), Outcome::Ok).await;
    Some(ServerMsg::Ready.frame())
}

/// Carries [stream] both ways over [sink] until either end closes or the
/// account loses what [keep] says the relay was opened under, and answers the
/// phase the socket is now in.
fn relay(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    stream: TcpStream,
    mut changes: broadcast::Receiver<&'static str>,
    keep: Keep,
) -> Phase {
    let _ = stream.set_nodelay(true);
    let (mut reader, mut writer) = stream.into_split();
    let (tx, mut rx) = mpsc::channel::<Vec<u8>>(TARGET_QUEUE);

    // Towards the target.
    let writing = async move {
        while let Some(data) = rx.recv().await {
            if writer.write_all(&data).await.is_err() {
                break;
            }
        }
        let _ = writer.shutdown().await;
    };

    // Back from it. A send failure means the socket is gone, which the
    // disconnect handler above has already read as the end.
    let reading_sink = sink.clone();
    let reading = async move {
        let mut buffer = vec![0u8; READ_BUFFER];
        loop {
            match reader.read(&mut buffer).await {
                Ok(0) => break,
                Ok(read) => {
                    let frame = Message::Binary(Bytes::copy_from_slice(&buffer[..read]));
                    if reading_sink.send(frame).await.is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
        let _ = reading_sink.send(ServerMsg::Exit.frame()).await;
        let _ = reading_sink
            .send(Message::Close(Some(CloseCode::Normal.into())))
            .await;
    };

    // The grant this connection was opened under, which an admin can take
    // away from a running process. Without this the socket would keep carrying
    // bytes after the role changed — the role is only consulted when something
    // is *started*. The receiver was taken by the caller before its own check,
    // so a change racing the connect is delivered rather than missed.
    let revocation_sink = sink.clone();
    let ctx = ctx.clone();

    spawn(async move {
        tokio::pin!(writing, reading);
        loop {
            tokio::select! {
                _ = &mut writing => break,
                _ = &mut reading => break,
                code = next_change(&mut changes) => {
                    // A change to somebody else's role, or one that left this
                    // account what it needs: carry on.
                    if ctx.still(keep).await {
                        continue;
                    }
                    // Said before closing, so the app reports why rather than
                    // reconnecting into a refusal it cannot see.
                    let _ = revocation_sink
                        .send(
                            ServerMsg::Error {
                                code,
                                message: "This account may no longer use this connection",
                            }
                            .frame(),
                        )
                        .await;
                    let _ = revocation_sink
                        .send(Message::Close(Some(CloseCode::Normal.into())))
                        .await;
                    break;
                }
            }
        }
    });
    Phase::Running(tx)
}

/// The next role change, as the code a client it ends is told — or never.
///
/// A `broadcast` receiver answers `Err` once the sender is gone, and a `select!`
/// arm backed by a future that completes immediately would spin. Neither can
/// happen while the agent is running — the sender lives in `AppState` — but a
/// closed channel is treated as "no signal" rather than as a change, since
/// guessing here would re-check every relay the moment a state was dropped. A
/// receiver that fell behind missed changes, so it re-checks as for one.
pub(super) async fn next_change(changes: &mut broadcast::Receiver<&'static str>) -> &'static str {
    loop {
        match changes.recv().await {
            Ok(code) => return code,
            Err(broadcast::error::RecvError::Lagged(_)) => return "permission_revoked",
            Err(broadcast::error::RecvError::Closed) => std::future::pending().await,
        }
    }
}

/// [target] is the address dialled, or for a connection a listener accepted,
/// the peer it came from.
async fn audit_connect(ctx: &Rc<ConnCtx>, target: &str, outcome: Outcome) {
    Event::new(Kind::Stream, Action::Connect, outcome)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        // The address is the whole of what this endpoint was asked for, and it
        // is the operator's own network being dialled — worth recording, and
        // nothing a credential could be read out of.
        .detail(target)
        .record(&ctx.state.db)
        .await;
}

fn error_frame(code: &str, message: &str) -> Message {
    ServerMsg::Error { code, message }.frame()
}
