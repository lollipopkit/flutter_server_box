//! `GET /api/v1/rdp/ws` — an RDP session, with the agent as the RDCleanPath
//! proxy.
//!
//! [`super::stream::stream_ws`] is a byte relay and RDP cannot use it: the
//! client that runs a session in the browser (`ironrdp-web`) opens its socket
//! with an RDCleanPath request and refuses anything but an RDCleanPath response
//! in reply. RDCleanPath exists because the browser cannot do the TLS handshake
//! RDP wants: the client needs the server's certificate to bind the session's
//! credentials to it, and it has no way to trust an RDP server's usually
//! self-signed certificate from inside a page. The agent, one network hop away
//! from the RDP server and already trusted by the operator, is what stands in
//! for that.
//!
//! # Wire format
//!
//! Nothing but **Binary** frames, and they are a *byte stream* rather than one
//! message per PDU: the client's own framing splits a large PDU across messages
//! and reads bytes back by accumulating them, so this end accumulates too. The
//! first thing in the stream is the DER-encoded request PDU; after the response
//! the same socket is the RDP connection in the clear.
//!
//! # The exchange
//!
//! 1. Read the request PDU. Its `proxy_auth` field carries the ticket, which is
//!    where the authorisation for this endpoint travels: the wasm client opens
//!    its socket with no subprotocols, so the `sbm-ticket.` convention the other
//!    two endpoints use is not available to it.
//! 2. Dial `destination`, forward the client's X.224 Connection Request, read
//!    the Connection Confirm.
//! 3. Do the TLS handshake with the RDP server and keep the session. The
//!    certificate chain observed here goes back in the response, because it is
//!    the only way the browser ever sees it.
//! 4. Answer with the Connection Confirm, the chain and the address; from there
//!    relay bytes between the socket and the TLS session.
//!
//! # Authority
//!
//! `remote_access.full_access`, checked when the socket opens and again when the
//! request PDU arrives. The second check is the one that matters — a ticket is
//! what authorises the session and it is inside the PDU — and the first is what
//! keeps a client with no business here from opening a socket at all.
//!
//! # TLS
//!
//! **The agent terminates TLS and the operator's stream is plaintext in this
//! process.** That is the protocol rather than a shortcut: the client marks
//! itself upgraded without doing TLS, so what crosses the socket is the RDP
//! stream after decryption. Anything that can read this process's memory can
//! read the session, including an NLA credential.
//!
//! The certificate the RDP server presents is **captured, not verified** — see
//! [`CapturingVerifier`]. The agent has no anchor to check it against (RDP
//! servers are self-signed as a rule) and the client is the party that ends up
//! judging it, by binding the credentials to the public key it is handed. What
//! follows is worth stating plainly rather than leaving to be discovered: the
//! leg between this agent and the RDP server is **not authenticated**, so a
//! party on that path can sit in the middle of it. The app's own remote desktop
//! over SSH does verify, and is the choice for a link that is not trusted — a
//! panel reached over the public internet is a link that is not trusted.

use std::cell::RefCell;
use std::io;
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ironrdp_rdcleanpath::{DetectionResult, RDCleanPath, RDCleanPathPdu};
use ntex::rt::spawn;
use ntex::service::{fn_factory_with_config, fn_service};
use ntex::util::Bytes;
use ntex::web::ws::{self, CloseCode, Frame, Message, WsSink};
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
use super::ticket::Purpose;
use crate::api::server::AppState;

/// How much of the RDP server's output may queue for a slow client before the
/// connection is torn down. The same bound and the same reason as the relay's:
/// a hole in an RDP stream leaves the screen wrong until something reconnects,
/// so a client that cannot keep up is disconnected rather than skipped.
const OUTPUT_QUEUE: usize = 256;

/// The read buffer for the RDP direction, matching the relay's.
const READ_BUFFER: usize = 32 * 1024;

/// How long the request PDU may take to arrive.
///
/// The upgrade cannot check the ticket — that is inside the PDU — so without
/// this a socket could be opened and held open for free, and opening a socket
/// is the one thing this endpoint offers before it knows who is asking.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(15);

/// A TPKT header is four bytes and its length is a 16-bit field, so a
/// Connection Confirm is small; this bounds a hostile one. Real servers answer
/// in tens of bytes.
const MAX_TPKT: usize = 16 * 1024;

/// The port a destination with none of its own is dialled on, matching
/// `DesktopProtocol::Rdp`'s default in the agent's own config.
const DEFAULT_PORT: u16 = 3389;

/// Where the negotiation blob sits inside an X.224 Connection Confirm: a
/// four-byte TPKT header, then `LI`, the TPDU code, two references and a class
/// byte — eleven bytes in all.
const NEGOTIATION_OFFSET: usize = 11;

const NEG_RSP: u8 = 0x02;
const NEG_FAILURE: u8 = 0x03;

/// `PROTOCOL_RDP` — no security at all. Every other value the negotiation can
/// select is TLS-based, which is what this endpoint has to offer.
const PROTOCOL_RDP: u32 = 0;

pub async fn rdp_ws(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
    let remote_ip = audit::peer_ip(&req);

    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Rdp, Action::Connect, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(reason)
            .record(&app_state.db)
            .await;
        Ok(status)
    };

    let secure = super::is_secure_transport(&req, app_state.tls_active);
    // As far as the handshake can be checked, given that the ticket is inside
    // the PDU. It keeps a client that has no business here from opening a
    // socket at all; the request itself is refused if the grant has gone by the
    // time it arrives.
    if !app_state.full_access_allowed(secure) {
        return deny("no full access", HttpResponse::Forbidden().finish()).await;
    }
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().finish()).await;
    }

    let ctx = Rc::new(ConnCtx {
        state: app_state,
        remote_ip,
        secure,
        subject: RefCell::new(None),
    });

    ws::start::<_, _, &str, web::Error>(
        req,
        // No subprotocol is offered back: `ironrdp-web` opens its socket with
        // none and ignores the header entirely.
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
    /// The panel account, once the ticket in the request PDU has been
    /// validated. Recorded in the audit trail.
    subject: RefCell<Option<String>>,
}

/// What the connection is doing.
///
/// `Request` holds the bytes read so far, which is the whole of the framing:
/// RDCleanPath's own `detect` says when they add up to a PDU.
enum Phase {
    Request(Vec<u8>),
    /// A PDU was read and is being answered. Distinct from `Request` so bytes
    /// arriving alongside the first PDU are not taken for a second handshake —
    /// one socket is one session.
    Opening,
    Running(mpsc::Sender<Vec<u8>>),
    Done,
}

fn handler(
    ctx: Rc<ConnCtx>,
    sink: WsSink,
) -> impl ntex::service::Service<Frame, Response = Option<Message>, Error = web::Error> {
    let phase = Rc::new(RefCell::new(Phase::Request(Vec::new())));

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

    // Started here rather than on the first frame, so the countdown covers a
    // socket that is opened and then says nothing at all.
    {
        let ctx = ctx.clone();
        let sink = sink.clone();
        let phase = phase.clone();
        spawn(async move {
            tokio::time::sleep(REQUEST_TIMEOUT).await;
            let waiting = matches!(*phase.borrow(), Phase::Request(_));
            if waiting {
                *phase.borrow_mut() = Phase::Done;
                Event::new(Kind::Rdp, Action::Connect, Outcome::Denied)
                    .remote_ip(ctx.remote_ip.clone())
                    .detail("no request")
                    .record(&ctx.state.db)
                    .await;
                let _ = sink
                    .send(error_pdu(&RDCleanPathPdu::new_general_error()))
                    .await;
                let _ = sink
                    .send(Message::Close(Some(CloseCode::Normal.into())))
                    .await;
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
                // Nothing on this endpoint is text, and the relay next door
                // takes a JSON request — so a text frame is the wrong endpoint
                // rather than a malformed message, and closing says so.
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

    // Taken out of the cell rather than borrowed across the await below, and
    // taken in a statement of its own: the disconnect and timeout tasks write
    // this cell from other tasks, so a borrow spanning a frame's arrival would
    // panic — and a temporary in a `match` scrutinee lives until the end of the
    // match, which is exactly that.
    let previous = std::mem::replace(&mut *phase.borrow_mut(), Phase::Done);
    let mut buffer = match previous {
        Phase::Running(sender) => {
            // A full queue is a client that cannot keep up, which for RDP is a
            // stream that is already broken.
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
            // Bytes after the PDU are the head of the RDP stream — a client
            // that wrote them early is not doing anything wrong, and dropping
            // them would corrupt the connection it is about to have.
            let pdu = buffer[..total_length].to_vec();
            let pending = buffer[total_length..].to_vec();
            *phase.borrow_mut() = Phase::Opening;
            handshake(ctx, sink, phase, &pdu, pending).await
        }
        DetectionResult::Failed => {
            *phase.borrow_mut() = Phase::Done;
            Event::new(Kind::Rdp, Action::Connect, Outcome::Denied)
                .remote_ip(ctx.remote_ip.clone())
                .detail("not an RDCleanPath request")
                .record(&ctx.state.db)
                .await;
            refuse(sink, &RDCleanPathPdu::new_http_error(400))
        }
    }
}

/// Reads the request PDU, dials the RDP server, and answers.
///
/// Answers `None` always: every message this function produces goes through
/// [`refuse`] or through the relay task, so a caller returning a message of its
/// own could only put one on top of them.
async fn handshake(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    raw: &[u8],
    pending: Vec<u8>,
) -> Option<Message> {
    let Ok(pdu) = RDCleanPathPdu::from_der(raw) else {
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };
    let Ok(RDCleanPath::Request {
        destination,
        proxy_auth,
        preconnection_blob,
        x224_connection_request,
        ..
    }) = pdu.into_enum()
    else {
        // Also the answer to a PDU that decodes but is a *response*: a client
        // has no business sending one, and there is no request to read out of
        // it.
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };

    // Refused rather than guessed at. The blob is a PCB for the RDP server,
    // sent as its own PDU before the X.224 request, and what a client puts in
    // the string here is a convention its author picked — the wrong reading
    // routes the session to a different RDP source with nothing to show for it.
    // Nothing this app sends carries one, so refusing costs nothing today and
    // cannot be silently wrong.
    if preconnection_blob.is_some() {
        tracing::info!("RDP proxy refused a preconnection blob");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    }

    // The ticket. `reserve` burns the entry on a wrong secret, so a wrong one
    // here is one attempt; `commit` right away, since there is no failed
    // handshake left to roll it back into.
    let Ok(reservation) = ctx.state.tickets.reserve(&proxy_auth, Purpose::Rdp) else {
        Event::new(Kind::Rdp, Action::Connect, Outcome::Denied)
            .remote_ip(ctx.remote_ip.clone())
            .detail("ticket")
            .record(&ctx.state.db)
            .await;
        return refuse(sink, &RDCleanPathPdu::new_http_error(401));
    };
    *ctx.subject.borrow_mut() = Some(ctx.state.tickets.commit(reservation));

    // Re-checked at the moment of use: the grant can be turned off while a
    // ticket is outstanding, and the capabilities a client was told earlier are
    // not a boundary.
    if !ctx.state.full_access_allowed(ctx.secure) {
        return refuse(sink, &RDCleanPathPdu::new_http_error(403));
    }

    let Ok((host, port)) = parse_destination(&destination) else {
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };

    // Subscribed before the connect, so a revocation landing between here and
    // the relay task's own subscription is still delivered: a broadcast only
    // reaches receivers that existed when it was sent.
    let revoked = ctx.state.full_access_revoked.subscribe();

    let mut stream = match TcpStream::connect((host.as_str(), port)).await {
        Ok(stream) => stream,
        Err(error) => {
            tracing::info!("RDP proxy could not reach {host}:{port}: {error}");
            return refuse(sink, &RDCleanPathPdu::new_http_error(502));
        }
    };
    let _ = stream.set_nodelay(true);
    let server_addr = stream
        .peer_addr()
        .map(|addr| addr.to_string())
        .unwrap_or_else(|_| format!("{host}:{port}"));

    // The client's own X.224 Connection Request, forwarded as it was written:
    // the negotiation it asks for is the negotiation that gets answered.
    if let Err(error) = stream.write_all(x224_connection_request.as_bytes()).await {
        tracing::info!("RDP proxy could not write the X.224 request: {error}");
        return refuse(sink, &RDCleanPathPdu::new_http_error(502));
    }

    let connection_confirm = match read_tpkt(&mut stream).await {
        Ok(confirm) => confirm,
        Err(error) => {
            tracing::info!("RDP proxy could not read the X.224 confirm: {error}");
            return refuse(sink, &RDCleanPathPdu::new_http_error(502));
        }
    };

    // A negotiation the client cannot use is answered with the server's own
    // bytes, which is the point of a negotiation error: "CredSSP (NLA) is
    // required" is in there and a general error would throw it away.
    let selected = match negotiation(&connection_confirm) {
        Negotiation::Tls(protocol) => protocol,
        Negotiation::Refused(reason) => {
            tracing::info!("RDP proxy refusing {server_addr}: {reason}");
            audit_connect(ctx, &destination, Outcome::Error).await;
            let pdu = RDCleanPathPdu::new_negotiation_error(connection_confirm)
                .unwrap_or_else(|_| RDCleanPathPdu::new_general_error());
            return refuse(sink, &pdu);
        }
    };

    let verifier = Arc::new(CapturingVerifier::default());
    let Ok(config) = tls_config(verifier.clone()) else {
        tracing::error!("RDP proxy has no TLS client configuration");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    };

    // The name validates nothing — see the module notice — but rustls wants a
    // well-formed one, and an SNI of the destination is what a server behind a
    // virtual host expects.
    let Ok(name) = ServerName::try_from(host.clone()) else {
        return refuse(sink, &RDCleanPathPdu::new_http_error(400));
    };
    let tls = match TlsConnector::from(config).connect(name, stream).await {
        Ok(tls) => tls,
        Err(error) => {
            tracing::info!("RDP proxy could not open TLS with {server_addr}: {error}");
            return refuse(sink, &tls_error_pdu(&error));
        }
    };

    let chain = verifier.take_chain();
    if chain.is_empty() {
        // Unreachable — rustls finishes no handshake without a certificate —
        // but a response without a chain is one the client refuses with "server
        // cert chain missing", so sending it would only be a worse error.
        tracing::error!("RDP proxy finished a TLS handshake with no certificate");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    }

    let Ok(response) = RDCleanPathPdu::new_response(server_addr.clone(), connection_confirm, chain)
    else {
        tracing::error!("RDP proxy could not build the response for {server_addr}");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    };
    let Ok(der) = response.to_der() else {
        tracing::error!("RDP proxy could not encode the response for {server_addr}");
        return refuse(sink, &RDCleanPathPdu::new_general_error());
    };

    tracing::debug!("RDP proxy opened {destination} ({server_addr}), protocol {selected:#x}");
    audit_connect(ctx, &destination, Outcome::Ok).await;
    relay(ctx, sink, phase, tls, pending, revoked, der);

    None
}

/// Relays bytes between the socket and the TLS session, until either end goes.
///
/// Spawned, and the response is sent from inside the task rather than by the
/// caller. The order matters and this is the only way to have it: both messages
/// go out through the same sink, so a read loop started before the response was
/// queued could put RDP bytes in front of it, and the client reading its first
/// bytes through `detect` would call the session broken.
fn relay(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    tls: TlsStream<TcpStream>,
    pending: Vec<u8>,
    revoked: broadcast::Receiver<()>,
    response: Vec<u8>,
) {
    let (mut reader, mut writer) = tokio::io::split(tls);
    let (tx, mut rx) = mpsc::channel::<Vec<u8>>(OUTPUT_QUEUE);
    // Bytes the client sent alongside its request go to the server first, and
    // in order: RDP is not a protocol that tolerates reordering.
    if !pending.is_empty() {
        let _ = tx.try_send(pending);
    }
    *phase.borrow_mut() = Phase::Running(tx);

    let sink = sink.clone();
    let subject = ctx.subject.borrow().clone().unwrap_or_default();

    spawn(async move {
        // Before any of the server's output, and before the loops below can put
        // any there.
        if sink
            .send(Message::Binary(Bytes::from(response)))
            .await
            .is_err()
        {
            return;
        }

        // Towards the server.
        let writing = async move {
            while let Some(data) = rx.recv().await {
                if writer.write_all(&data).await.is_err() {
                    break;
                }
                let _ = writer.flush().await;
            }
            let _ = writer.shutdown().await;
        };

        // Back from it. A send failure means the socket is gone, which the
        // disconnect handler has already read as the end.
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
            let _ = reading_sink
                .send(Message::Close(Some(CloseCode::Normal.into())))
                .await;
        };

        // The grant this session was opened under, which the panel can take
        // away from a running process. Without this the socket would keep
        // carrying a screen after `full_access` was switched off — the flag is
        // only consulted when something is *started*. The receiver was taken
        // before the connect, so a revocation racing it is delivered rather
        // than missed.
        tokio::select! {
            _ = writing => {}
            _ = reading => {}
            _ = super::awaiting_revocation(revoked) => {
                // The session carries credentials, so it is closed rather than
                // left to finish what it was doing.
                tracing::info!("RDP session for {subject} ended: full access was disabled");
                let _ = sink
                    .send(error_pdu(&RDCleanPathPdu::new_general_error()))
                    .await;
                let _ = sink
                    .send(Message::Close(Some(CloseCode::Normal.into())))
                    .await;
            }
        }
    });
}

/// Sends a refusal — an error PDU and then a close — and answers `None`.
///
/// Spawned so the caller's return value stays free: a caller that had to send
/// these itself could put a second message on top of them, and the client reads
/// whatever arrives first as the answer to its request.
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

/// A refusal as the client can read it: a RDCleanPath error PDU, not a text
/// frame.
///
/// The client is reading this socket through `detect`, which fails on anything
/// that is not a PDU — so an error has to be one, or the operator is shown a
/// decode failure instead of the reason.
fn error_pdu(pdu: &RDCleanPathPdu) -> Message {
    match pdu.to_der() {
        Ok(der) => Message::Binary(Bytes::from(der)),
        // Unreachable: every error PDU here is a fixed, small structure. A
        // frame that cannot be built is dropped rather than answered with
        // something the client would misread.
        Err(error) => {
            tracing::error!("RDP proxy could not encode an error PDU: {error}");
            Message::Close(Some(CloseCode::Normal.into()))
        }
    }
}

/// Reads one TPKT-framed PDU.
///
/// The length in the four-byte TPKT header is what makes this safe: the
/// Connection Confirm is followed on the same connection by the TLS handshake,
/// so a read that took "whatever was there" would swallow the start of it.
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

/// What the RDP server answered to the X.224 negotiation.
enum Negotiation {
    /// A protocol that involves TLS. The value is the selected protocol, for
    /// the log line.
    Tls(u32),
    /// No TLS on offer, or the negotiation failed. The reason is for the log;
    /// the client is given the server's own bytes.
    Refused(String),
}

/// Reads the negotiation blob out of an X.224 Connection Confirm.
///
/// Hand-built rather than parsed with `ironrdp-pdu`, which would be a
/// considerable dependency for four fixed fields. The offsets are MS-RDPBCGR
/// 2.2.1.2, and the structure has not moved since Windows 7.
fn negotiation(confirm: &[u8]) -> Negotiation {
    if confirm.len() < NEGOTIATION_OFFSET + 8 {
        return Negotiation::Refused("the target answered without a negotiation".to_string());
    }
    let blob = &confirm[NEGOTIATION_OFFSET..];
    let length = usize::from(u16::from_le_bytes([blob[2], blob[3]]));
    if length < 8 {
        return Negotiation::Refused(format!("a negotiation blob of {length} bytes"));
    }

    match blob[0] {
        NEG_RSP => {
            let selected = u32::from_le_bytes([blob[4], blob[5], blob[6], blob[7]]);
            if selected == PROTOCOL_RDP {
                // The server will not do TLS, and this endpoint has nothing
                // else to offer: the client has already marked itself upgraded.
                Negotiation::Refused("the target selected no security".to_string())
            } else {
                Negotiation::Tls(selected)
            }
        }
        NEG_FAILURE => {
            let code = u32::from_le_bytes([blob[4], blob[5], blob[6], blob[7]]);
            Negotiation::Refused(format!(
                "the target refused the negotiation: {}",
                failure_reason(code)
            ))
        }
        other => Negotiation::Refused(format!("an unexpected negotiation type {other:#04x}")),
    }
}

/// MS-RDPBCGR 2.2.1.1.1.1 failure codes, for the log line. The client reads the
/// code itself out of the bytes it is sent.
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

/// Splits a destination into a host and a port.
///
/// `host`, `host:port`, `[v6]`, `[v6]:port` and a bare IPv6 literal all arrive
/// here: the string is the operator's and the wasm client passes it through
/// untouched. A bare IPv6 literal is why this is not `rsplit_once(':')` —
/// `2001:db8::1` would split at the last colon and read `1` as a port.
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
        // More than one colon and no brackets: an IPv6 literal with no port.
        _ => Ok((destination.to_string(), DEFAULT_PORT)),
    }
}

fn parse_port(port: &str) -> Result<u16, ()> {
    match port.parse::<u16>() {
        Ok(0) | Err(_) => Err(()),
        Ok(port) => Ok(port),
    }
}

/// Records a session that got as far as dialling. The address is the whole of
/// what the endpoint was asked for, and it is the operator's own network.
async fn audit_connect(ctx: &Rc<ConnCtx>, destination: &str, outcome: Outcome) {
    let mut event = Event::new(Kind::Rdp, Action::Connect, outcome)
        .remote_ip(ctx.remote_ip.clone())
        .detail(destination);
    if let Some(subject) = ctx.subject.borrow().as_deref() {
        event = event.subject(subject);
    }
    event.record(&ctx.state.db).await;
}

/// The certificate capture the response needs, and the handshake it happens
/// during.
///
/// The client wants the chain and has no other way to get it: the handshake
/// happens here, on the other side of a socket it cannot read. So the chain is
/// recorded on the way past and sent in the response.
///
/// **Nothing is verified.** RDP servers are self-signed as a rule, so there is
/// no anchor an agent could reasonably check against, and the party that ends
/// up judging the certificate is the client — it binds the session's
/// credentials to the public key out of the chain it is handed. Accepting
/// whatever is presented is what the protocol calls for, and it is also the
/// reason the module notice says the leg to the RDP server is unauthenticated.
#[derive(Debug, Default)]
struct CapturingVerifier {
    chain: Mutex<Vec<Vec<u8>>>,
}

impl CapturingVerifier {
    /// The chain as it was presented, leaf first. Taken rather than cloned: it
    /// is read once, on the way into the response.
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
        let mut chain = self.chain.lock().unwrap_or_else(|e| e.into_inner());
        *chain = std::iter::once(end_entity)
            .chain(intermediates.iter())
            .map(|cert| cert.as_ref().to_vec())
            .collect();
        Ok(ServerCertVerified::assertion())
    }

    /// Also unconditional, and for the same reason: the signatures are checked
    /// against a key nothing here has decided to trust.
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

    /// The provider's own list, not a hand-written one: a scheme this omits is
    /// a handshake that fails against a server offering only that.
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

/// The TLS alert the server sent, where there was one. It is the most specific
/// thing the client can be told, and `RDCleanPathErr` has a field for it.
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
        assert_eq!(
            parse_destination("10.0.0.7"),
            Ok(("10.0.0.7".to_string(), 3389))
        );
        assert_eq!(
            parse_destination("10.0.0.7:3390"),
            Ok(("10.0.0.7".to_string(), 3390))
        );
        assert_eq!(
            parse_destination("rdp.example.com"),
            Ok(("rdp.example.com".to_string(), 3389))
        );
        assert_eq!(
            parse_destination(" rdp.example.com:3390 "),
            Ok(("rdp.example.com".to_string(), 3390))
        );
    }

    #[test]
    fn a_bare_ipv6_literal_is_not_read_as_a_port() {
        // The reason this is not `rsplit_once(':')`: `2001:db8::1` ends in
        // something that parses as a port, and the host would be cut short.
        assert_eq!(
            parse_destination("2001:db8::1"),
            Ok(("2001:db8::1".to_string(), 3389))
        );
        assert_eq!(
            parse_destination("[2001:db8::1]"),
            Ok(("2001:db8::1".to_string(), 3389))
        );
        assert_eq!(
            parse_destination("[2001:db8::1]:3390"),
            Ok(("2001:db8::1".to_string(), 3390))
        );
        assert_eq!(parse_destination("[::1]:3389"), Ok(("::1".to_string(), 3389)));
    }

    #[test]
    fn a_destination_with_nothing_in_it_is_refused() {
        assert_eq!(parse_destination(""), Err(()));
        assert_eq!(parse_destination("   "), Err(()));
        assert_eq!(parse_destination(":3389"), Err(()));
        assert_eq!(parse_destination("[]:3389"), Err(()));
        assert_eq!(parse_destination("[::1"), Err(()));
        assert_eq!(parse_destination("[::1]x"), Err(()));
        assert_eq!(parse_destination("host:"), Err(()));
        assert_eq!(parse_destination("host:0"), Err(()));
        assert_eq!(parse_destination("host:99999"), Err(()));
        assert_eq!(parse_destination("host:rdp"), Err(()));
        assert_eq!(parse_destination("[::1]:x"), Err(()));
    }

    /// An X.224 Connection Confirm carrying a negotiation blob, built here
    /// rather than captured: the frame is four fields and constructing it shows
    /// what the parser is reading.
    fn confirm(negotiation: &[u8]) -> Vec<u8> {
        let length = 11 + negotiation.len();
        let mut frame = vec![0x03, 0x00, (length >> 8) as u8, length as u8];
        // LI 6, Connection Confirm, two references, class and options.
        frame.extend_from_slice(&[0x06, 0xd0, 0x00, 0x00, 0x12, 0x34, 0x00]);
        frame.extend_from_slice(negotiation);
        frame
    }

    fn neg_rsp(protocol: u32) -> Vec<u8> {
        let mut blob = vec![NEG_RSP, 0x00, 0x08, 0x00];
        blob.extend_from_slice(&protocol.to_le_bytes());
        blob
    }

    #[test]
    fn a_tls_protocol_is_read_out_of_the_confirm() {
        // SSL, HYBRID (NLA) and HYBRID_EX are all TLS-based.
        for protocol in [1u32, 2, 8] {
            match negotiation(&confirm(&neg_rsp(protocol))) {
                Negotiation::Tls(selected) => assert_eq!(selected, protocol),
                Negotiation::Refused(reason) => panic!("{protocol} refused: {reason}"),
            }
        }
    }

    #[test]
    fn a_server_that_will_not_do_tls_is_refused() {
        // `PROTOCOL_RDP` is no security at all, and this endpoint has nothing
        // else to offer — the client has already marked itself upgraded.
        match negotiation(&confirm(&neg_rsp(PROTOCOL_RDP))) {
            Negotiation::Tls(selected) => panic!("accepted {selected:#x}"),
            Negotiation::Refused(reason) => assert!(reason.contains("no security"), "{reason}"),
        }
    }

    #[test]
    fn a_failed_negotiation_is_refused_with_its_own_code() {
        let mut blob = vec![NEG_FAILURE, 0x00, 0x08, 0x00];
        blob.extend_from_slice(&5u32.to_le_bytes()); // HYBRID_REQUIRED_BY_SERVER
        match negotiation(&confirm(&blob)) {
            Negotiation::Tls(selected) => panic!("accepted {selected:#x}"),
            Negotiation::Refused(reason) => assert!(reason.contains("CredSSP"), "{reason}"),
        }
    }

    #[test]
    fn a_confirm_with_no_negotiation_is_refused() {
        // Pre-Windows-7 servers answer with a plain X.224 Connection Confirm,
        // which has no blob and therefore no TLS.
        match negotiation(&confirm(&[])) {
            Negotiation::Tls(selected) => panic!("accepted {selected:#x}"),
            Negotiation::Refused(reason) => {
                assert!(reason.contains("without a negotiation"), "{reason}");
            }
        }
    }

    #[test]
    fn a_confirm_that_is_short_or_badly_framed_is_refused_rather_than_panicking() {
        // These come off a socket the operator's route points at, so the parser
        // is fed by whatever is on the other end of it.
        for frame in [
            // Shorter than the offset the blob is read from.
            vec![0x03, 0x00, 0x00, 0x08],
            vec![],
            // A blob whose length field is smaller than the structure it is.
            {
                let mut frame = confirm(&neg_rsp(1));
                frame[13] = 0x04;
                frame
            },
            // A blob type that is neither a response nor a failure.
            {
                let mut frame = confirm(&neg_rsp(1));
                frame[11] = 0x7f;
                frame
            },
        ] {
            assert!(
                matches!(negotiation(&frame), Negotiation::Refused(_)),
                "{frame:02x?} was not refused"
            );
        }
    }

    #[test]
    fn the_confirm_a_test_builds_is_the_shape_the_parser_expects() {
        let frame = confirm(&neg_rsp(1));
        assert_eq!(frame.len(), NEGOTIATION_OFFSET + 8);
        assert_eq!(u16::from_be_bytes([frame[2], frame[3]]) as usize, frame.len());
        assert_eq!(frame[0], 0x03);
    }

    #[test]
    fn a_tpkt_length_is_bounded() {
        // A read that trusted the field with no bound would let the operator's
        // route point the agent at a server that answers with a huge length.
        assert!(!(4..=MAX_TPKT).contains(&3usize), "a body-less header");
        assert!(!(4..=MAX_TPKT).contains(&(MAX_TPKT + 1)), "past the bound");
        assert!(MAX_TPKT < u16::MAX as usize, "the bound is below the field's range");
    }
}
