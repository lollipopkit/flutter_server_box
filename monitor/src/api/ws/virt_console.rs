//! `GET /api/v1/virt/console/ws` — a guest's console on the Virtualization
//! page.
//!
//! What it connects to was resolved by `POST /virt/console` and is bound to
//! the ticket that opens this socket (`Purpose::Virt`, `sbm-ticket.<ticket>`
//! as the subprotocol): PVE's `vncwebsocket` with the agent's session, or a
//! libvirt VNC display dialled from this machine. The client names nothing.
//!
//! # Wire format
//!
//! `/stream/ws`'s, so the panel's relay channel serves both:
//!
//! - **Binary** — the console's bytes, both directions: RFB for VNC; for a
//!   text console, terminal output one way and keystrokes the other, which
//!   `sbm_virt::pve::console::Console` turns into termproxy's — its ticket
//!   and `OK` are done before `ready`, and it sends the keep-alive.
//! - **Text**, server to client — `{"type":"ready"}` once bytes may flow,
//!   `{"type":"error","code","message"}`, `{"type":"exit"}`.
//! - **Text**, client to server — `{"type":"resize","cols","rows"}` (a text
//!   console), `{"type":"ping"}`.
//!
//! # Authority
//!
//! The transport rule: when the console was resolved, when the socket opens,
//! and again on a password change while it runs (`AppState.password_changed`).

use crate::api::WebError;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use ntex::rt::spawn;
use ntex::service::{BindCtx, Ctx, Service};
use ntex::util::{ByteString, Bytes};
use ntex::web::ws::{self, CloseCode, Frame, Message};
use ntex::web::{HttpRequest, HttpResponse};
use ntex::ws::Item;
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::mpsc;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::live::{Ending, LiveKind};
use super::ticket::Purpose;
use super::upgrade::{QueueGate, WsSink};
use crate::api::authz;
use crate::api::server::AppState;
use crate::api::virt::ConsoleTarget;
use sbm_virt::model::ConsoleKind;

const TICKET_PROTOCOL_PREFIX: &str = "sbm-ticket.";
const QUEUE: usize = 256;
const READ_BUFFER: usize = 32 * 1024;

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ClientMsg {
    Resize { cols: u16, rows: u16 },
    Ping,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ServerMsg<'a> {
    Ready,
    Error { code: &'a str, message: &'a str },
    Exit,
}

impl ServerMsg<'_> {
    fn frame(&self) -> Message {
        Message::Text(ByteString::from(serde_json::to_string(self).unwrap_or_else(|_| "{}".into())))
    }
}

enum Input {
    Bytes(Vec<u8>),
    Resize(u16, u16),
}

enum Phase {
    Opening,
    Running(mpsc::Sender<Input>),
    Done,
}

struct ConnCtx {
    state: Arc<AppState>,
    remote_ip: Option<String>,
    secure: bool,
    since: i64,
    what: String,
}

impl ConnCtx {
    async fn still(&self) -> bool {
        authz::caller(&self.state)
            .await
            .filter(|c| c.since == self.since)
            .is_some_and(|c| c.check(&self.state, self.secure).is_ok())
    }

    async fn audit(&self, action: Action, outcome: Outcome, why: Option<&str>) {
        Event::new(Kind::Machine, action, outcome)
            .remote_ip(self.remote_ip.clone())
            .detail(match why {
                Some(why) => format!("{}: {why}", self.what),
                None => self.what.clone(),
            })
            .record(&self.state.db)
            .await;
    }
}

pub async fn virt_console_ws(
    req: HttpRequest,
    app_state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    let remote_ip = audit::peer_ip(&req);
    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Machine, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(format!("virt console: {reason}"))
            .record(&app_state.db)
            .await;
        Ok(status)
    };
    let secure = super::is_secure_transport(&req, app_state.tls_active);
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().build()).await;
    }
    let Some(protocol) =
        ws::subprotocols(&req).find(|v| v.starts_with(TICKET_PROTOCOL_PREFIX)).map(str::to_owned)
    else {
        return deny("no ticket", HttpResponse::Unauthorized().build()).await;
    };
    let raw_ticket = protocol[TICKET_PROTOCOL_PREFIX.len()..].to_owned();
    let Ok(reservation) = app_state.tickets.reserve(&raw_ticket, Purpose::Virt) else {
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
    let Some(pending) = app_state.virt.take_console(&raw_ticket) else {
        tickets.rollback(reservation);
        return deny("no console", HttpResponse::Unauthorized().build()).await;
    };
    let ctx = Rc::new(ConnCtx {
        state: app_state,
        remote_ip,
        secure,
        since: admitted.since,
        what: pending.what,
    });
    let upgraded = super::upgrade::start(
        &req,
        Some(&protocol),
        move |sink: WsSink| handler(ctx, sink, pending.target),
    )
    .await;
    if upgraded.is_ok() {
        tickets.commit(reservation);
    } else {
        tickets.rollback(reservation);
    }
    upgraded
}

fn handler(ctx: Rc<ConnCtx>, sink: WsSink, target: ConsoleTarget) -> Relay {
    let phase = Rc::new(RefCell::new(Phase::Opening));
    {
        let phase = phase.clone();
        let disconnect = sink.on_disconnect();
        spawn(async move {
            disconnect.await;
            *phase.borrow_mut() = Phase::Done;
        });
    }
    let text = matches!(&target, ConsoleTarget::Pve(_, c) if c.kind == ConsoleKind::Text);
    {
        let (sink, phase) = (sink.clone(), phase.clone());
        spawn(async move { connect(ctx, sink, phase, target).await });
    }
    Relay { phase, text, gate: QueueGate::default() }
}

/// Connects to the console and starts carrying it, or says why not.
async fn connect(ctx: Rc<ConnCtx>, sink: WsSink, phase: Rc<RefCell<Phase>>, target: ConsoleTarget) {
    // Subscribed before the check, so a password change racing it is delivered.
    let changes = ctx.state.password_changed.subscribe();
    if !ctx.still().await {
        *phase.borrow_mut() = Phase::Done;
        ctx.audit(Action::Denied, Outcome::Denied, Some("not admitted")).await;
        let _ = sink.send(error_frame("forbidden", "The password changed, or this link may not act")).await;
        return;
    }
    // Connected first, carried after: `ready` goes out before the console's
    // first byte (a VNC server speaks first), which the client would
    // otherwise read before it knows the console is up.
    enum Opened {
        Tcp(tokio::net::TcpStream),
        Pve(Box<sbm_virt::pve::console::Console>),
    }
    // What `/live` lists it as: the guest on PVE, the display's address on
    // libvirt.
    let listed = match &target {
        ConsoleTarget::Pve(_, console) => format!("{}/{}", console.node, console.vmid),
        ConsoleTarget::Tcp { host, port } => format!("{host}:{port}"),
    };
    let opened = match target {
        ConsoleTarget::Tcp { host, port } => match tokio::net::TcpStream::connect((host.as_str(), port)).await {
            Ok(stream) => {
                let _ = stream.set_nodelay(true);
                Opened::Tcp(stream)
            }
            Err(e) => {
                *phase.borrow_mut() = Phase::Done;
                tracing::info!("virt console could not reach {host}:{port}: {e}");
                ctx.audit(Action::Connect, Outcome::Error, Some("unreachable")).await;
                let _ = sink.send(error_frame("connect_failed", "Could not reach the console")).await;
                return;
            }
        },
        ConsoleTarget::Pve(client, console) => match client.open_console(&console).await {
            Ok(console) => Opened::Pve(Box::new(console)),
            Err(e) => {
                *phase.borrow_mut() = Phase::Done;
                ctx.audit(Action::Connect, Outcome::Error, Some(&format!("{:?}", e.kind))).await;
                let message = e.message.unwrap_or_else(|| "The console did not open".into());
                let _ = sink.send(error_frame("connect_failed", &message)).await;
                return;
            }
        },
    };
    if matches!(*phase.borrow(), Phase::Done) {
        if let Opened::Pve(console) = &opened {
            console.close().await;
        }
        return;
    }
    // Asked again: the password may have changed while the console was opening,
    // which no change notice reaches before `watch` listens.
    if !ctx.still().await {
        *phase.borrow_mut() = Phase::Done;
        if let Opened::Pve(console) = &opened {
            console.close().await;
        }
        ctx.audit(Action::Denied, Outcome::Denied, Some("not admitted")).await;
        let _ = sink.send(error_frame("forbidden", "The password changed, or this link may not act")).await;
        return;
    }
    let (tx, rx) = mpsc::channel::<Input>(QUEUE);
    *phase.borrow_mut() = Phase::Running(tx);
    ctx.audit(Action::Connect, Outcome::Ok, None).await;
    if sink.send(ServerMsg::Ready.frame()).await.is_err() {
        return;
    }
    let (stop_tx, stop_rx) = tokio::sync::oneshot::channel();
    let pump = match opened {
        Opened::Tcp(stream) => spawn_tcp(stream, rx, sink.clone(), stop_rx),
        Opened::Pve(console) => spawn_pve(*console, rx, sink.clone(), stop_rx),
    };
    let ending = ctx.state.live.register(changes, LiveKind::VirtConsole, listed, ctx.remote_ip.clone());
    watch(ctx, sink, ending, pump, stop_tx);
}

/// Ends the console on a password change, when it is ended (`api::ws::live`)
/// or when the pump stops. Either of the first two stops the pump too, which
/// closes the console behind the socket.
fn watch(
    ctx: Rc<ConnCtx>,
    sink: WsSink,
    mut ending: Ending,
    pump: tokio::sync::oneshot::Receiver<()>,
    stop: tokio::sync::oneshot::Sender<()>,
) {
    spawn(async move {
        tokio::pin!(pump);
        loop {
            tokio::select! {
                _ = &mut pump => break,
                signal = ending.next() => {
                    if signal.rechecks() && ctx.still().await {
                        continue;
                    }
                    let _ = stop.send(());
                    let _ = sink.send(ServerMsg::Error { code: signal.code(), message: signal.message() }.frame()).await;
                    let _ = sink.send(Message::Close(Some(CloseCode::Normal.into()))).await;
                    break;
                }
            }
        }
    });
}

fn spawn_tcp(
    stream: tokio::net::TcpStream,
    mut rx: mpsc::Receiver<Input>,
    sink: WsSink,
    stop: tokio::sync::oneshot::Receiver<()>,
) -> tokio::sync::oneshot::Receiver<()> {
    let (done_tx, done_rx) = tokio::sync::oneshot::channel();
    let (mut reader, mut writer) = stream.into_split();
    spawn(async move {
        let writing = async move {
            while let Some(input) = rx.recv().await {
                if let Input::Bytes(data) = input
                    && writer.write_all(&data).await.is_err()
                {
                    break;
                }
            }
            let _ = writer.shutdown().await;
        };
        let reading_sink = sink.clone();
        let reading = async move {
            let mut buffer = vec![0u8; READ_BUFFER];
            loop {
                match reader.read(&mut buffer).await {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if reading_sink.send(Message::Binary(Bytes::copy_from_slice(&buffer[..n]))).await.is_err() {
                            break;
                        }
                    }
                }
            }
        };
        tokio::select! {
            _ = writing => {},
            _ = reading => {},
            _ = stop => {},
        }
        end(&sink).await;
        let _ = done_tx.send(());
    });
    done_rx
}

fn spawn_pve(
    console: sbm_virt::pve::console::Console,
    mut rx: mpsc::Receiver<Input>,
    sink: WsSink,
    stop: tokio::sync::oneshot::Receiver<()>,
) -> tokio::sync::oneshot::Receiver<()> {
    let (done_tx, done_rx) = tokio::sync::oneshot::channel();
    let console = Rc::new(console);
    spawn(async move {
        // The console frames input, sizes and keep-alives itself.
        let up = console.clone();
        let writing = async move {
            while let Some(input) = rx.recv().await {
                let sent = match input {
                    Input::Bytes(data) => up.send(&data).await,
                    Input::Resize(cols, rows) => up.resize(cols, rows).await,
                };
                if sent.is_err() {
                    break;
                }
            }
        };
        let down = console.clone();
        let reading_sink = sink.clone();
        let reading = async move {
            while let Some(data) = down.recv().await {
                if reading_sink.send(Message::Binary(Bytes::from(data))).await.is_err() {
                    break;
                }
            }
        };
        tokio::select! {
            _ = writing => {},
            _ = reading => {},
            _ = stop => {},
        }
        console.close().await;
        end(&sink).await;
        let _ = done_tx.send(());
    });
    done_rx
}

async fn end(sink: &WsSink) {
    let _ = sink.send(ServerMsg::Exit.frame()).await;
    let _ = sink.send(Message::Close(Some(CloseCode::Normal.into()))).await;
}

struct Relay {
    phase: Rc<RefCell<Phase>>,
    text: bool,
    gate: QueueGate,
}

impl Relay {
    /// The queue towards the console, while one is open.
    fn running(&self) -> Option<mpsc::Sender<Input>> {
        match &*self.phase.borrow() {
            Phase::Running(sender) => Some(sender.clone()),
            _ => None,
        }
    }

    async fn input(&self, input: Input) -> Option<Message> {
        match self.running() {
            Some(sender) => {
                if self.gate.send(&sender, input).await.is_err() {
                    return Some(error_frame("closed", "The console ended"));
                }
                None
            }
            None => Some(error_frame("not_ready", "The console is not open yet")),
        }
    }
}

impl Service<WsSink, Frame> for Relay {
    type Res = Option<Message>;
    type Error = WebError;

    fn bind(&self, ctx: BindCtx<'_>) {
        self.gate.bind(ctx);
    }

    /// Not ready while the queue towards the console is full, which is what
    /// holds a fast client back.
    async fn ready(&self, _: Ctx<'_, Self, WsSink>) -> Result<(), Self::Error> {
        self.gate.ready(self.running()).await;
        Ok(())
    }

    async fn call(&self, frame: Frame, _: Ctx<'_, Self, WsSink>) -> Result<Self::Res, Self::Error> {
        match frame {
            Frame::Binary(data)
            | Frame::Continuation(Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data)) => {
                if data.is_empty() {
                    return Ok(None);
                }
                Ok(self.input(Input::Bytes(data.to_vec())).await)
            }
            Frame::Text(raw) => match serde_json::from_slice::<ClientMsg>(&raw) {
                Ok(ClientMsg::Ping) => Ok(Some(Message::Text(ByteString::from("{\"type\":\"pong\"}")))),
                Ok(ClientMsg::Resize { cols, rows }) if self.text => Ok(self.input(Input::Resize(cols, rows)).await),
                Ok(ClientMsg::Resize { .. }) => Ok(None),
                Err(_) => Ok(Some(error_frame("bad_request", "Unrecognised control message"))),
            },
            Frame::Ping(payload) => Ok(Some(Message::Pong(payload))),
            Frame::Pong(_) => Ok(None),
            Frame::Close(_) => {
                *self.phase.borrow_mut() = Phase::Done;
                Ok(Some(Message::Close(Some(CloseCode::Normal.into()))))
            }
            Frame::Continuation(Item::FirstText(_)) => Ok(Some(Message::Close(Some(CloseCode::Unsupported.into())))),
        }
    }
}

fn error_frame(code: &str, message: &str) -> Message {
    ServerMsg::Error { code, message }.frame()
}
