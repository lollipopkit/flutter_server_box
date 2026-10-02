//! `GET /api/v1/rdp/ws` — the panel's RDP session, with the agent as the
//! RDCleanPath proxy.
//!
//! [`super::stream`] is a byte relay and RDP cannot use it: the browser's
//! client (IronRDP's wasm build) opens its socket with an RDCleanPath request
//! and accepts only an RDCleanPath response. RDCleanPath exists because a page
//! cannot do the TLS handshake RDP wants, so the agent, one hop from the RDP
//! server, does it instead.
//!
//! # Wire format
//!
//! Binary frames only, read as a byte stream: the client splits a large PDU
//! across messages. First the DER request PDU; after the response the same
//! socket is the RDP connection in the clear.
//!
//! # The exchange
//!
//! 1. Read the request PDU. Its `proxy_auth` carries the ticket
//!    ([`Purpose::Rdp`]): the client opens its socket with no subprotocols, so
//!    the `sbm-ticket.` convention of the other endpoints is not available.
//! 2. Check `connect` and its `allow` list as `/stream/ws` does: the
//!    destination is resolved once, every address must be allowed, and those
//!    addresses are what is dialled.
//! 3. Forward the client's X.224 Connection Request, read the Confirm.
//! 4. Do the TLS handshake with the RDP server. The certificate chain observed
//!    goes back in the response, the only way the browser ever sees it.
//! 5. Answer, then relay between the socket and the TLS session until either
//!    end goes or the account loses `connect` to that address
//!    (`AppState.grants_changed`).
//!
//! # TLS
//!
//! **The agent terminates TLS, so the session — an NLA credential included —
//! is plaintext in this process.** That is the protocol: the client marks
//! itself upgraded without doing TLS. The panel says so beside the session.
//!
//! The RDP server's certificate is **captured, not verified**
//! ([`CapturingVerifier`]): RDP servers are self-signed as a rule and the agent
//! has no anchor. With NLA, CredSSP binds the credentials to the server's key,
//! so a party between the agent and the server cannot complete the session;
//! without NLA the leg to the server is not authenticated. The app's own
//! remote desktop over SSH verifies the certificate, and is the choice for a
//! path that is not trusted.

use std::cell::RefCell;
use std::io;
use std::net::SocketAddr;
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ironrdp_rdcleanpath::{DetectionResult, RDCleanPath, RDCleanPathPdu};
use ntex::rt::spawn;
use ntex::service::{fn_factory_with_config, fn_service};
use ntex::util::Bytes;
use ntex::web::ws::{CloseCode, Frame, Message};
use ntex::web::{self, HttpRequest, HttpResponse};
use ntex::ws::Item;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{ClientConfig, DigitallySignedStruct, Error as TlsError, SignatureScheme};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::{broadcast, mpsc};
use tokio_rustls::TlsConnector;
use tokio_rustls::client::TlsStream;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::upgrade::WsSink;
use super::stream::next_change;
use super::ticket::Purpose;
use crate::api::authz;
use crate::api::server::AppState;
use crate::core::permissions::Grant;

/// How much of the server's output may queue for a slow client before the
/// session is torn down: a hole in an RDP stream is a broken screen, not a
/// shorter one.
const OUTPUT_QUEUE: usize = 256;

const READ_BUFFER: usize = 32 * 1024;

/// How long the request PDU may take. The upgrade cannot check the ticket —
/// it is inside the PDU — so without this a socket could be held for free.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(15);

/// The largest request PDU accepted. Real ones are a few hundred bytes plus
/// an X.224 request; this bounds what an unauthenticated socket can make the
/// agent buffer.
const MAX_REQUEST: usize = 64 * 1024;

/// Bounds a hostile Connection Confirm; real servers answer in tens of bytes.
const MAX_TPKT: usize = 16 * 1024;

/// The port of a destination that names none.
const DEFAULT_PORT: u16 = 3389;

/// Where the negotiation blob sits in an X.224 Connection Confirm: a 4-byte
/// TPKT header, then LI, the TPDU code, two references and a class byte.
const NEGOTIATION_OFFSET: usize = 11;
const NEG_RSP: u8 = 0x02;
const NEG_FAILURE: u8 = 0x03;
/// `PROTOCOL_RDP`, no security. Every other selection is TLS-based.
const PROTOCOL_RDP: u32 = 0;

pub async fn rdp_ws(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
    let remote_ip = audit::peer_ip(&req);
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        Event::new(Kind::Stream, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("rdp: origin")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let ctx = Rc::new(ConnCtx {
        secure: super::is_secure_transport(&req, app_state.tls_active),
        state: app_state,
        remote_ip,
        account: RefCell::new(None),
    });
    // No subprotocol: the client offers none.
    super::upgrade::start::<_, _, web::Error>(
        req,
        None,
        fn_factory_with_config(move |sink: WsSink| {
            let ctx = ctx.clone();
            async move { Ok::<_, web::Error>(handler(ctx, sink)) }
        }),
    )
    .await
}

struct ConnCtx {
    state: Arc<AppState>,
    remote_ip: Option<String>,
    secure: bool,
    /// The panel account and its password epoch (`Caller::since`), once the
    /// ticket in the request has been taken.
    account: RefCell<Option<(String, i64)>>,
}

impl ConnCtx {
    fn subject(&self) -> Option<String> {
        self.account.borrow().as_ref().map(|(name, _)| name.clone())
    }

    /// The account, its role read again — none once its password changed.
    async fn caller(&self) -> Option<authz::Caller> {
        let (name, since) = self.account.borrow().clone()?;
        authz::caller_named(&self.state, &name)
            .await
            .filter(|caller| caller.since == since)
    }

    /// Whether the account may still reach [peer].
    async fn still(&self, peer: SocketAddr) -> bool {
        match self.caller().await {
            Some(caller) => {
                caller.check(Grant::Connect, &self.state, self.secure).is_ok()
                    && caller.may_connect_to(peer)
            }
            None => false,
        }
    }

    async fn audit(&self, outcome: Outcome, detail: &str) {
        let mut event = Event::new(Kind::Stream, Action::Connect, outcome)
            .remote_ip(self.remote_ip.clone())
            .detail(format!("rdp {detail}"));
        if let Some(subject) = self.subject() {
            event = event.subject(&subject);
        }
        event.record(&self.state.db).await;
    }
}

/// What the connection is doing. `Request` holds the bytes read so far;
/// RDCleanPath's own `detect` says when they add up to a PDU.
enum Phase {
    Request(Vec<u8>),
    /// A PDU was read and is being answered; one socket is one session.
    Opening,
    Running(mpsc::Sender<Vec<u8>>),
    Done,
}

fn handler(
    ctx: Rc<ConnCtx>,
    sink: WsSink,
) -> impl ntex::service::Service<Frame, Response = Option<Message>, Error = web::Error> {
    let phase = Rc::new(RefCell::new(Phase::Request(Vec::new())));

    // The socket going away ends the relay, by dropping the sender it holds.
    {
        let phase = phase.clone();
        let disconnect = sink.on_disconnect();
        spawn(async move {
            disconnect.await;
            *phase.borrow_mut() = Phase::Done;
        });
    }

    // Started now, so a socket that says nothing at all is closed too.
    {
        let ctx = ctx.clone();
        let sink = sink.clone();
        let phase = phase.clone();
        spawn(async move {
            tokio::time::sleep(REQUEST_TIMEOUT).await;
            if matches!(*phase.borrow(), Phase::Request(_)) {
                *phase.borrow_mut() = Phase::Done;
                ctx.audit(Outcome::Denied, "no request").await;
                refuse(&sink, &RDCleanPathPdu::new_general_error());
            }
        });
    }

    fn_service(move |frame: Frame| {
        let ctx = ctx.clone();
        let sink = sink.clone();
        let phase = phase.clone();
        async move {
            match frame {
                Frame::Binary(data) => Ok(on_input(&ctx, &sink, &phase, data.to_vec()).await),
                Frame::Continuation(
                    Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data),
                ) => Ok(on_input(&ctx, &sink, &phase, data.to_vec()).await),
                Frame::Ping(payload) => Ok(Some(Message::Pong(payload))),
                Frame::Pong(_) => Ok(None),
                // Nothing here is text: the wrong endpoint, not a bad message.
                Frame::Text(_) | Frame::Continuation(Item::FirstText(_)) => {
                    *phase.borrow_mut() = Phase::Done;
                    Ok(Some(Message::Close(Some(CloseCode::Unsupported.into()))))
                }
                Frame::Close(_) => {
                    *phase.borrow_mut() = Phase::Done;
                    Ok(Some(Message::Close(Some(CloseCode::Normal.into()))))
                }
            }
        }
    })
}

async fn on_input(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    data: Vec<u8>,
) -> Option<Message> {
    if data.is_empty() {
        return None;
    }
    // Taken out of the cell in its own statement: the disconnect and timeout
    // tasks write it, so a borrow held across an await would panic.
    let previous = std::mem::replace(&mut *phase.borrow_mut(), Phase::Done);
    let mut buffer = match previous {
        Phase::Running(sender) => {
            let failed = sender.send(data).await.is_err();
            *phase.borrow_mut() = Phase::Running(sender);
            return failed.then(|| error_pdu(&RDCleanPathPdu::new_general_error()));
        }
        Phase::Request(buffer) => buffer,
        done => {
            *phase.borrow_mut() = done;
            return None;
        }
    };

    buffer.extend_from_slice(&data);
    if buffer.len() > MAX_REQUEST {
        ctx.audit(Outcome::Denied, "request too large").await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    }
    match RDCleanPathPdu::detect(&buffer) {
        DetectionResult::NotEnoughBytes => {
            *phase.borrow_mut() = Phase::Request(buffer);
            None
        }
        DetectionResult::Detected { total_length, .. } if buffer.len() < total_length => {
            *phase.borrow_mut() = Phase::Request(buffer);
            None
        }
        DetectionResult::Detected { total_length, .. } => {
            // Bytes after the PDU are the head of the RDP stream.
            let pending = buffer.split_off(total_length);
            *phase.borrow_mut() = Phase::Opening;
            handshake(ctx, sink, phase, &buffer, pending).await
        }
        DetectionResult::Failed => {
            ctx.audit(Outcome::Denied, "not an RDCleanPath request").await;
            refuse(sink, &RDCleanPathPdu::new_http_error(400))
        }
    }
}

/// Reads the request, checks it, dials, and answers. Always `None`: every
/// message goes through [`refuse`] or the relay task, so nothing can be put
/// in front of them.
async fn handshake(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    raw: &[u8],
    pending: Vec<u8>,
) -> Option<Message> {
    let Ok(Ok(RDCleanPath::Request {
        destination,
        proxy_auth,
        preconnection_blob,
        x224_connection_request,
        ..
    })) = RDCleanPathPdu::from_der(raw).map(RDCleanPathPdu::into_enum)
    else {
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };

    // `reserve` burns the ticket on a wrong secret; committed at once, since
    // nothing after this can hand it back.
    let Ok(reservation) = ctx.state.tickets.reserve(&proxy_auth, Purpose::Rdp) else {
        ctx.audit(Outcome::Denied, "ticket").await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(401));
    };
    let subject = ctx.state.tickets.commit(reservation);
    let Some(caller) = authz::caller_named(&ctx.state, &subject).await else {
        ctx.audit(Outcome::Denied, "no such account").await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(403));
    };
    *ctx.account.borrow_mut() = Some((subject, caller.since));

    // A preconnection blob routes the session to another source on the
    // server by a convention the client's author picked. Nothing this panel
    // sends carries one, so it is refused rather than guessed at.
    if preconnection_blob.is_some() {
        ctx.audit(Outcome::Denied, "preconnection blob").await;
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    }

    // Subscribed before the checks, so a role change racing them is
    // delivered to the relay rather than missed.
    let changes = ctx.state.grants_changed.subscribe();

    if caller.check(Grant::Connect, &ctx.state, ctx.secure).is_err() {
        ctx.audit(Outcome::Denied, &format!("{destination}: not granted")).await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(403));
    }
    let Ok((host, port)) = parse_destination(&destination) else {
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };
    // Resolved once: every address must be allowed, and these are dialled.
    let addrs: Vec<SocketAddr> = match tokio::net::lookup_host((host.as_str(), port)).await {
        Ok(addrs) => addrs.collect(),
        Err(error) => {
            tracing::info!("RDP proxy could not resolve {destination}: {error}");
            ctx.audit(Outcome::Error, &destination).await;
            return refuse(sink, &RDCleanPathPdu::new_http_error(502));
        }
    };
    if addrs.is_empty() || !addrs.iter().all(|addr| caller.may_connect_to(*addr)) {
        ctx.audit(Outcome::Denied, &format!("{destination}: not allowed")).await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(403));
    }

    let mut stream = match TcpStream::connect(&addrs[..]).await {
        Ok(stream) => stream,
        Err(error) => {
            tracing::info!("RDP proxy could not reach {destination}: {error}");
            ctx.audit(Outcome::Error, &destination).await;
            return refuse(sink, &RDCleanPathPdu::new_http_error(502));
        }
    };
    let _ = stream.set_nodelay(true);
    let peer = stream.peer_addr().unwrap_or(addrs[0]);
    let server_addr = peer.to_string();

    // The client's own X.224 request, as written: the negotiation it asks for
    // is the one that gets answered.
    if let Err(error) = stream.write_all(x224_connection_request.as_bytes()).await {
        tracing::info!("RDP proxy could not write the X.224 request: {error}");
        ctx.audit(Outcome::Error, &destination).await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(502));
    }
    let connection_confirm = match read_tpkt(&mut stream).await {
        Ok(confirm) => confirm,
        Err(error) => {
            tracing::info!("RDP proxy could not read the X.224 confirm: {error}");
            ctx.audit(Outcome::Error, &destination).await;
            return refuse(sink, &RDCleanPathPdu::new_http_error(502));
        }
    };

    // A negotiation the client cannot use is answered with the server's own
    // bytes: "CredSSP (NLA) is required" is in there.
    if let Negotiation::Refused(reason) = negotiation(&connection_confirm) {
        tracing::info!("RDP proxy refusing {server_addr}: {reason}");
        ctx.audit(Outcome::Error, &format!("{destination}: {reason}")).await;
        let pdu = RDCleanPathPdu::new_negotiation_error(connection_confirm)
            .unwrap_or_else(|_| RDCleanPathPdu::new_general_error());
        return refuse(sink, &pdu);
    }

    let verifier = Arc::new(CapturingVerifier::default());
    let Ok(config) = tls_config(verifier.clone()) else {
        tracing::error!("RDP proxy has no TLS client configuration");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    };
    // The name validates nothing (see the module doc), but an SNI of the
    // destination is what a server behind a virtual host expects.
    let Ok(name) = ServerName::try_from(host.clone()) else {
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };
    let tls = match TlsConnector::from(config).connect(name, stream).await {
        Ok(tls) => tls,
        Err(error) => {
            tracing::info!("RDP proxy could not open TLS with {server_addr}: {error}");
            ctx.audit(Outcome::Error, &format!("{destination}: tls")).await;
            return refuse(sink, &tls_error_pdu(&error));
        }
    };
    let chain = verifier.take_chain();
    if chain.is_empty() {
        tracing::error!("RDP proxy finished a TLS handshake with no certificate");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    }
    let Ok(der) = RDCleanPathPdu::new_response(server_addr.clone(), connection_confirm, chain)
        .and_then(|response| response.to_der())
    else {
        tracing::error!("RDP proxy could not build the response for {server_addr}");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    };

    ctx.audit(Outcome::Ok, &destination).await;
    relay(ctx, sink, phase, tls, pending, changes, peer, der);
    None
}

/// Relays between the socket and the TLS session. The response is sent from
/// inside the task: both go through one sink, so a read loop started first
/// could put RDP bytes in front of it.
#[allow(clippy::too_many_arguments)]
fn relay(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    tls: TlsStream<TcpStream>,
    pending: Vec<u8>,
    mut changes: broadcast::Receiver<&'static str>,
    peer: SocketAddr,
    response: Vec<u8>,
) {
    let (mut reader, mut writer) = tokio::io::split(tls);
    let (tx, mut rx) = mpsc::channel::<Vec<u8>>(OUTPUT_QUEUE);
    // What the client sent alongside its request goes first, in order.
    if !pending.is_empty() {
        let _ = tx.try_send(pending);
    }
    *phase.borrow_mut() = Phase::Running(tx);

    let sink = sink.clone();
    let ctx = ctx.clone();
    spawn(async move {
        if sink.send(Message::Binary(Bytes::from(response))).await.is_err() {
            return;
        }
        let writing = async move {
            while let Some(data) = rx.recv().await {
                if writer.write_all(&data).await.is_err() {
                    break;
                }
                let _ = writer.flush().await;
            }
            let _ = writer.shutdown().await;
        };
        let reading_sink = sink.clone();
        let reading = async move {
            let mut buffer = vec![0u8; READ_BUFFER];
            loop {
                match reader.read(&mut buffer).await {
                    Ok(0) | Err(_) => break,
                    Ok(read) => {
                        let frame = Message::Binary(Bytes::copy_from_slice(&buffer[..read]));
                        if reading_sink.send(frame).await.is_err() {
                            break;
                        }
                    }
                }
            }
            let _ = reading_sink
                .send(Message::Close(Some(CloseCode::Normal.into())))
                .await;
        };
        tokio::pin!(writing, reading);
        loop {
            tokio::select! {
                _ = &mut writing => break,
                _ = &mut reading => break,
                _ = next_change(&mut changes) => {
                    if ctx.still(peer).await {
                        continue;
                    }
                    // The session carries credentials: closed, not left to
                    // finish what it was doing.
                    tracing::info!("RDP session for {:?} ended: connect was taken away", ctx.subject());
                    let _ = sink
                        .send(Message::Close(Some(CloseCode::Policy.into())))
                        .await;
                    break;
                }
            }
        }
    });
}

/// Sends an error PDU and a close, and answers `None`. Spawned, so the caller
/// cannot put a second message in front of it.
fn refuse(sink: &WsSink, pdu: &RDCleanPathPdu) -> Option<Message> {
    let sink = sink.clone();
    let message = error_pdu(pdu);
    spawn(async move {
        let _ = sink.send(message).await;
        let _ = sink
            .send(Message::Close(Some(CloseCode::Normal.into())))
            .await;
    });
    None
}

/// A refusal the client can read: an RDCleanPath PDU, since it reads this
/// socket through `detect` and anything else is a decode failure.
fn error_pdu(pdu: &RDCleanPathPdu) -> Message {
    match pdu.to_der() {
        Ok(der) => Message::Binary(Bytes::from(der)),
        Err(error) => {
            tracing::error!("RDP proxy could not encode an error PDU: {error}");
            Message::Close(Some(CloseCode::Normal.into()))
        }
    }
}

/// Reads one TPKT frame by its length: the TLS handshake follows on the same
/// connection, so reading "what is there" would swallow its start.
async fn read_tpkt(stream: &mut TcpStream) -> io::Result<Vec<u8>> {
    let mut header = [0u8; 4];
    stream.read_exact(&mut header).await?;
    if header[0] != 0x03 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("not a TPKT frame (version {:#04x})", header[0]),
        ));
    }
    let length = usize::from(u16::from_be_bytes([header[2], header[3]]));
    if !(4..=MAX_TPKT).contains(&length) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("nonsensical TPKT length {length}"),
        ));
    }
    let mut frame = vec![0u8; length];
    frame[..4].copy_from_slice(&header);
    stream.read_exact(&mut frame[4..]).await?;
    Ok(frame)
}

enum Negotiation {
    /// A TLS-based protocol was selected.
    Tls,
    /// No TLS on offer, or the negotiation failed; the reason is for the log.
    Refused(String),
}

/// The negotiation blob of an X.224 Connection Confirm (MS-RDPBCGR 2.2.1.2).
fn negotiation(confirm: &[u8]) -> Negotiation {
    if confirm.len() < NEGOTIATION_OFFSET + 8 {
        return Negotiation::Refused("the target answered without a negotiation".to_string());
    }
    let blob = &confirm[NEGOTIATION_OFFSET..];
    let length = usize::from(u16::from_le_bytes([blob[2], blob[3]]));
    if length < 8 {
        return Negotiation::Refused(format!("a negotiation blob of {length} bytes"));
    }
    let value = u32::from_le_bytes([blob[4], blob[5], blob[6], blob[7]]);
    match blob[0] {
        NEG_RSP if value == PROTOCOL_RDP => {
            Negotiation::Refused("the target selected no security".to_string())
        }
        NEG_RSP => Negotiation::Tls,
        NEG_FAILURE => Negotiation::Refused(format!(
            "the target refused the negotiation: {}",
            failure_reason(value)
        )),
        other => Negotiation::Refused(format!("an unexpected negotiation type {other:#04x}")),
    }
}

/// MS-RDPBCGR 2.2.1.1.1.1, for the log line.
fn failure_reason(code: u32) -> &'static str {
    match code {
        1 => "SSL is required but not offered",
        2 => "SSL is not allowed by the server",
        3 => "the server has no certificate",
        4 => "the server's flags are inconsistent",
        5 => "CredSSP (NLA) is required",
        6 => "SSL with user authentication is required",
        _ => "an unrecognised refusal",
    }
}

/// `host`, `host:port`, `[v6]`, `[v6]:port` or a bare IPv6 literal — which
/// is why this is not `rsplit_once(':')`.
fn parse_destination(destination: &str) -> Result<(String, u16), ()> {
    let destination = destination.trim();
    if destination.is_empty() {
        return Err(());
    }
    if let Some(rest) = destination.strip_prefix('[') {
        let (host, rest) = rest.split_once(']').ok_or(())?;
        if host.is_empty() {
            return Err(());
        }
        return match rest.strip_prefix(':') {
            Some(port) => parse_port(port).map(|port| (host.to_string(), port)),
            None if rest.is_empty() => Ok((host.to_string(), DEFAULT_PORT)),
            None => Err(()),
        };
    }
    match destination.matches(':').count() {
        0 => Ok((destination.to_string(), DEFAULT_PORT)),
        1 => {
            let (host, port) = destination.rsplit_once(':').ok_or(())?;
            if host.is_empty() {
                return Err(());
            }
            parse_port(port).map(|port| (host.to_string(), port))
        }
        _ => Ok((destination.to_string(), DEFAULT_PORT)),
    }
}

fn parse_port(port: &str) -> Result<u16, ()> {
    match port.parse::<u16>() {
        Ok(0) | Err(_) => Err(()),
        Ok(port) => Ok(port),
    }
}

/// Records the chain the server presents, and accepts it: the client is
/// handed the chain and binds the credentials to its key (see the module
/// doc). **Nothing is verified here.**
#[derive(Debug, Default)]
struct CapturingVerifier {
    chain: Mutex<Vec<Vec<u8>>>,
}

impl CapturingVerifier {
    fn take_chain(&self) -> Vec<Vec<u8>> {
        std::mem::take(&mut *self.chain.lock().unwrap_or_else(|e| e.into_inner()))
    }
}

impl ServerCertVerifier for CapturingVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, TlsError> {
        *self.chain.lock().unwrap_or_else(|e| e.into_inner()) = std::iter::once(end_entity)
            .chain(intermediates.iter())
            .map(|cert| cert.as_ref().to_vec())
            .collect();
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        rustls::crypto::ring::default_provider()
            .signature_verification_algorithms
            .supported_schemes()
    }
}

fn tls_config(verifier: Arc<CapturingVerifier>) -> Result<Arc<ClientConfig>, TlsError> {
    let provider = Arc::new(rustls::crypto::ring::default_provider());
    Ok(Arc::new(
        ClientConfig::builder_with_provider(provider)
            .with_safe_default_protocol_versions()?
            .dangerous()
            .with_custom_certificate_verifier(verifier)
            .with_no_client_auth(),
    ))
}

/// The TLS alert the server sent, where there was one.
fn tls_error_pdu(error: &io::Error) -> RDCleanPathPdu {
    let alert = error.get_ref().and_then(|inner| match inner.downcast_ref() {
        Some(TlsError::AlertReceived(alert)) => Some(u8::from(*alert)),
        _ => None,
    });
    match alert {
        Some(code) => RDCleanPathPdu::new_tls_error(code),
        None => RDCleanPathPdu::new_general_error(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_destination_may_name_a_port_or_not() {
        assert_eq!(parse_destination("10.0.0.7"), Ok(("10.0.0.7".to_string(), 3389)));
        assert_eq!(parse_destination("10.0.0.7:3390"), Ok(("10.0.0.7".to_string(), 3390)));
        assert_eq!(
            parse_destination(" rdp.example.com:3390 "),
            Ok(("rdp.example.com".to_string(), 3390))
        );
    }

    #[test]
    fn a_bare_ipv6_literal_is_not_read_as_a_port() {
        assert_eq!(parse_destination("2001:db8::1"), Ok(("2001:db8::1".to_string(), 3389)));
        assert_eq!(parse_destination("[2001:db8::1]"), Ok(("2001:db8::1".to_string(), 3389)));
        assert_eq!(
            parse_destination("[2001:db8::1]:3390"),
            Ok(("2001:db8::1".to_string(), 3390))
        );
    }

    #[test]
    fn a_destination_with_nothing_in_it_is_refused() {
        for bad in ["", "   ", ":3389", "[]:3389", "[::1", "[::1]x", "host:", "host:0", "host:99999", "host:rdp"] {
            assert_eq!(parse_destination(bad), Err(()), "{bad:?}");
        }
    }

    fn confirm(negotiation: &[u8]) -> Vec<u8> {
        let length = 11 + negotiation.len();
        let mut frame = vec![0x03, 0x00, (length >> 8) as u8, length as u8];
        frame.extend_from_slice(&[0x06, 0xd0, 0x00, 0x00, 0x12, 0x34, 0x00]);
        frame.extend_from_slice(negotiation);
        frame
    }

    fn neg(kind: u8, value: u32) -> Vec<u8> {
        let mut blob = vec![kind, 0x00, 0x08, 0x00];
        blob.extend_from_slice(&value.to_le_bytes());
        blob
    }

    #[test]
    fn a_tls_protocol_is_accepted() {
        // SSL, HYBRID (NLA) and HYBRID_EX are all TLS-based.
        for protocol in [1u32, 2, 8] {
            assert!(matches!(negotiation(&confirm(&neg(NEG_RSP, protocol))), Negotiation::Tls));
        }
    }

    #[test]
    fn no_tls_or_a_failed_negotiation_is_refused() {
        let Negotiation::Refused(reason) = negotiation(&confirm(&neg(NEG_RSP, PROTOCOL_RDP))) else {
            panic!("accepted no security")
        };
        assert!(reason.contains("no security"));
        let Negotiation::Refused(reason) = negotiation(&confirm(&neg(NEG_FAILURE, 5))) else {
            panic!("accepted a failure")
        };
        assert!(reason.contains("CredSSP"));
    }

    #[test]
    fn a_short_or_badly_framed_confirm_is_refused_rather_than_panicking() {
        let mut small_blob = confirm(&neg(NEG_RSP, 1));
        small_blob[13] = 0x04;
        let mut odd_type = confirm(&neg(NEG_RSP, 1));
        odd_type[11] = 0x7f;
        for frame in [vec![], vec![0x03, 0x00, 0x00, 0x08], confirm(&[]), small_blob, odd_type] {
            assert!(matches!(negotiation(&frame), Negotiation::Refused(_)), "{frame:02x?}");
        }
    }
}
