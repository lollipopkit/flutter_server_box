//! `GET /api/v1/stream/ws` — a TCP connection to an address the caller names.
//!
//! This is what a monitor-only server has instead of an SSH channel: RDP, VNC
//! and port forwarding are one TCP connection each, and without this the app
//! has no way to reach either on a machine whose only door is an agent.
//!
//! # Authority
//!
//! `remote_access.full_access`, checked here when the socket opens *and* when
//! the ticket is minted. The host connects as the account the agent runs as,
//! so this is the same grant as the shell and `/exec` — and deliberately not a
//! switch of its own: anyone who can open a shell can `ssh -L` from it, so a
//! grant that withheld this while granting the shell would withhold nothing.
//! See `RemoteAccess::full_access_available`.
//!
//! # Wire format
//!
//! - **Text** — the request first: `{"type":"open","host":..,"port":..}`. Then
//!   control JSON, see [`ClientMsg`] and [`ServerMsg`].
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
use ntex::service::{fn_factory_with_config, fn_service};
use ntex::util::{ByteString, Bytes};
use ntex::web::ws::{self, CloseCode, Frame, Message, WsSink};
use ntex::web::{self, HttpRequest, HttpResponse};
use ntex::ws::Item;
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::ticket::Purpose;
use crate::api::server::AppState;

/// How much of the remote's output may queue for a slow client before the
/// connection is torn down.
///
/// Dropping is not an option the way it is for a terminal's scrollback: RDP and
/// VNC are stateful protocols and a hole in the stream leaves the screen wrong
/// until something reconnects. So a client that cannot keep up is disconnected,
/// which is a failure it can see and recover from.
const OUTPUT_QUEUE: usize = 256;

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
    // Checked here as well as at the ticket, so the answer cannot be stale by
    // the time a connection is actually made.
    if !app_state.full_access_allowed(secure) {
        return deny("no full access", HttpResponse::Forbidden().finish()).await;
    }
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

    let ctx = Rc::new(ConnCtx {
        state: app_state,
        subject,
        remote_ip,
        secure,
    });

    let upgraded = ws::start::<_, _, &str, web::Error>(
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

fn handler(
    ctx: Rc<ConnCtx>,
    sink: WsSink,
) -> impl ntex::service::Service<Frame, Response = Option<Message>, Error = web::Error> {
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

    fn_service(move |frame: Frame| {
        let ctx = ctx.clone();
        let sink = sink.clone();
        let phase = phase.clone();
        async move {
            match frame {
                Frame::Text(data) => Ok(on_control(&ctx, &sink, &phase, &data).await),
                Frame::Binary(data) => Ok(on_input(&phase, data.to_vec()).await),
                Frame::Continuation(
                    Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data),
                ) => Ok(on_input(&phase, data.to_vec()).await),
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
    })
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
            // A full queue means the remote is producing faster than the
            // client takes it, which for RDP or VNC is a stream that is already
            // broken.
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
    // Subscribed before anything else, so a revocation landing anywhere between
    // this line and the relay task subscribing for itself is still delivered:
    // the broadcast only reaches receivers that existed when it was sent, and
    // the check below is what a revocation racing the connect would otherwise
    // slip past.
    let revoked = ctx.state.full_access_revoked.subscribe();

    // Re-checked at the moment of use rather than trusted from the handshake:
    // the grant can be turned off while a ticket is outstanding, and the
    // capabilities a client was told earlier are not a boundary.
    if !ctx.state.full_access_allowed(ctx.secure) {
        *phase.borrow_mut() = Phase::Done;
        audit_connect(ctx, host, port, Outcome::Denied).await;
        return Some(error_frame("forbidden", "Full access is off"));
    }

    let stream = match TcpStream::connect((host, port)).await {
        Ok(stream) => stream,
        Err(error) => {
            *phase.borrow_mut() = Phase::Done;
            audit_connect(ctx, host, port, Outcome::Error).await;
            tracing::info!("Stream relay could not reach {host}:{port}: {error}");
            return Some(error_frame("connect_failed", "Could not reach the target"));
        }
    };
    let _ = stream.set_nodelay(true);

    let (mut reader, mut writer) = stream.into_split();
    let (tx, mut rx) = mpsc::channel::<Vec<u8>>(OUTPUT_QUEUE);
    *phase.borrow_mut() = Phase::Running(tx);
    audit_connect(ctx, host, port, Outcome::Ok).await;

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

    // The grant this connection was opened under, which the panel can take
    // away from a running process. Without this the socket would keep carrying
    // bytes after `full_access` was switched off — the flag is only consulted
    // when something is *started*. The receiver was taken at the top of this
    // function, so a revocation racing the connect is delivered rather than
    // missed.
    let revocation_sink = sink.clone();

    spawn(async move {
        tokio::select! {
            _ = writing => {}
            _ = reading => {}
            _ = super::awaiting_revocation(revoked) => {
                // Said before closing, so the app reports why rather than
                // reconnecting into a refusal it cannot see.
                let _ = revocation_sink
                    .send(
                        ServerMsg::Error {
                            code: "full_access_disabled",
                            message: "Full access has been disabled",
                        }
                        .frame(),
                    )
                    .await;
                let _ = revocation_sink
                    .send(Message::Close(Some(CloseCode::Normal.into())))
                    .await;
            }
        }
    });
    // The caller waits for this before treating the connection as usable: a
    // relay that answers `error` must not be raced by bytes the client already
    // wrote into it.
    Some(ServerMsg::Ready.frame())
}

async fn audit_connect(ctx: &Rc<ConnCtx>, host: &str, port: u16, outcome: Outcome) {
    Event::new(Kind::Stream, Action::Connect, outcome)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        // The address is the whole of what this endpoint was asked for, and it
        // is the operator's own network being dialled — worth recording, and
        // nothing a credential could be read out of.
        .detail(format!("{host}:{port}"))
        .record(&ctx.state.db)
        .await;
}

fn error_frame(code: &str, message: &str) -> Message {
    ServerMsg::Error { code, message }.frame()
}
