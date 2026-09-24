//! End-to-end coverage for `GET /api/v1/rdp/ws`.
//!
//! The RDP server on the other end is a `TcpListener` this test owns, so the
//! whole exchange — the request PDU, the X.224 negotiation, the TLS handshake
//! and the relay — runs against the real handler with nothing that needs a
//! second machine. The fake speaks just enough RDP to be answered: it reads an
//! X.224 Connection Request, answers with a Connection Confirm, terminates TLS
//! with a certificate it generated, and then echoes whatever it is sent.

use std::io;
use std::sync::{Arc, Mutex, Once, OnceLock};
use std::time::Duration;

use ironrdp_rdcleanpath::{DetectionResult, RDCleanPath, RDCleanPathPdu};
use ntex::io::{Io, Sealed};
use ntex::service::cfg::SharedCfg;
use ntex::time::{Seconds, timeout};
use ntex::util::Bytes;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use ntex::ws::error::WsClientError;
use ntex::ws::{self, WsClient, WsConnection};
use rcgen::{CertifiedKey, generate_simple_self_signed};
use rustls::crypto::ring;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use rustls::ServerConfig;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::rdcleanpath::rdp_ws;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio_rustls::TlsAcceptor;

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// An agent with the terminal on — which is what `full_access_available`
/// requires — and `full_access` as asked for.
async fn app_state(full_access: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some("test-secret-that-is-long-enough-32ch".to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    AppState::new(Arc::new(config), db)
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new()
                .state(state)
                .service(web::scope("/api/v1").route("/rdp/ws", web::get().to(rdp_ws)))
        }
    })
    .await
}

// ---------------------------------------------------------------- RDP frames

const NEG_RSP: u8 = 0x02;
const NEG_FAILURE: u8 = 0x03;

/// A frame in the X.224/TPKT shape RDP negotiates in: a four-byte TPKT header,
/// then `LI`, the TPDU code, two references and a class byte.
fn x224(tpdu_code: u8, negotiation: &[u8]) -> Vec<u8> {
    let length = 11 + negotiation.len();
    let mut frame = vec![0x03, 0x00, (length >> 8) as u8, length as u8];
    frame.extend_from_slice(&[0x06, tpdu_code, 0x00, 0x00, 0x12, 0x34, 0x00]);
    frame.extend_from_slice(negotiation);
    frame
}

/// The client's own negotiation request: `requestedProtocols` of SSL|HYBRID,
/// which is what a real client asks for.
fn connection_request() -> Vec<u8> {
    let mut blob = vec![0x01, 0x00, 0x08, 0x00];
    blob.extend_from_slice(&3u32.to_le_bytes());
    x224(0xe0, &blob)
}

fn connection_confirm(negotiation: &[u8]) -> Vec<u8> {
    x224(0xd0, negotiation)
}

fn neg_rsp(protocol: u32) -> Vec<u8> {
    let mut blob = vec![NEG_RSP, 0x00, 0x08, 0x00];
    blob.extend_from_slice(&protocol.to_le_bytes());
    blob
}

fn neg_failure(code: u32) -> Vec<u8> {
    let mut blob = vec![NEG_FAILURE, 0x00, 0x08, 0x00];
    blob.extend_from_slice(&code.to_le_bytes());
    blob
}

/// Reads one TPKT-framed frame, by the length in its header.
async fn read_tpkt<S: AsyncReadExt + Unpin>(socket: &mut S) -> io::Result<Vec<u8>> {
    let mut header = [0u8; 4];
    socket.read_exact(&mut header).await?;
    let length = usize::from(u16::from_be_bytes([header[2], header[3]]));
    let mut frame = vec![0u8; length];
    frame[..4].copy_from_slice(&header);
    socket.read_exact(&mut frame[4..]).await?;
    Ok(frame)
}

// ------------------------------------------------------------ fake RDP server

/// The certificate the fake server presents, and its key.
///
/// Generated once for the whole test binary and shared with the assertions:
/// `generate_simple_self_signed` is random, so a second call would produce a
/// certificate that is *not* the one the server presented, and comparing
/// against it would pass while checking nothing.
fn fake_identity() -> &'static (CertificateDer<'static>, Vec<u8>) {
    static IDENTITY: OnceLock<(CertificateDer<'static>, Vec<u8>)> = OnceLock::new();
    IDENTITY.get_or_init(|| {
        let CertifiedKey { cert, signing_key } =
            generate_simple_self_signed(vec!["localhost".into()]).expect("a certificate");
        (cert.der().clone(), signing_key.serialize_der())
    })
}

/// What the fake server was asked for, for the assertions.
///
/// `Arc<Mutex<_>>` rather than `Mutex<_>` so the server's task can hold its own
/// handle while the test reads the same cells.
#[derive(Default)]
struct Observed {
    /// The X.224 Connection Request the proxy forwarded, verbatim.
    request: Arc<Mutex<Option<Vec<u8>>>>,
    /// Whether the TLS handshake completed — the proxy's doing, not the
    /// client's, and the thing a refused negotiation must not be followed by.
    tls: Arc<Mutex<bool>>,
}

/// A fake RDP server: negotiate, then TLS, then echo.
///
/// [confirm] is the negotiation blob it answers with, which is what the tests
/// vary. Whatever arrives over TLS is echoed back byte for byte — the proxy
/// understands neither RDP nor this, and the thing on the other end of it does
/// not need to either.
async fn fake_rdp(confirm: Vec<u8>, greeting: Option<&'static [u8]>) -> (String, Observed) {
    ensure_crypto_provider();
    let (cert, key) = fake_identity();

    let tls = ServerConfig::builder_with_provider(Arc::new(ring::default_provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .with_no_client_auth()
        .with_single_cert(
            vec![cert.clone()],
            PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(key.clone())),
        )
        .unwrap();
    let acceptor = TlsAcceptor::from(Arc::new(tls));

    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    let observed = Observed::default();

    let request_seen = observed.request.clone();
    let tls_seen = observed.tls.clone();
    tokio::spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            let confirm = confirm.clone();
            let acceptor = acceptor.clone();
            let request_seen = request_seen.clone();
            let tls_seen = tls_seen.clone();
            tokio::spawn(async move {
                let Ok(request) = read_tpkt(&mut socket).await else {
                    return;
                };
                *request_seen.lock().unwrap() = Some(request);

                if socket.write_all(&confirm).await.is_err() {
                    return;
                }

                let Ok(mut socket) = acceptor.accept(socket).await else {
                    return;
                };
                *tls_seen.lock().unwrap() = true;

                // Written before the client sends anything, so a test can see
                // which frame reaches it first.
                if let Some(greeting) = greeting {
                    let _ = socket.write_all(greeting).await;
                }

                let mut buffer = [0u8; 1024];
                while let Ok(read) = socket.read(&mut buffer).await {
                    if read == 0 {
                        return;
                    }
                    let _ = socket.write_all(&buffer[..read]).await;
                }
            });
        }
    });

    (addr, observed)
}

/// A port nothing is listening on.
fn dead_addr() -> String {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    drop(listener);
    addr
}

// -------------------------------------------------------------- the ws client

async fn rdp_connection(srv: &TestServer) -> Result<WsConnection<Sealed>, WsClientError> {
    WsClient::builder(srv.url("/api/v1/rdp/ws"))
        .address(srv.addr())
        .timeout(Seconds(60))
        .build(SharedCfg::default())
        .await
        .unwrap()
        .connect()
        .await
        .map(WsConnection::seal)
}

async fn open_rdp(srv: &TestServer) -> (Io<Sealed>, ws::Codec) {
    let conn = rdp_connection(srv).await.expect("upgrade should succeed");
    let (io, codec, _) = conn.into_inner();
    (io, codec)
}

/// The request PDU, as the wasm client builds it: the destination and the
/// ticket travel in it, and the X.224 Connection Request is what the proxy is
/// asked to forward.
fn request_pdu(destination: &str, ticket: &str) -> Vec<u8> {
    RDCleanPathPdu::new_request(
        connection_request(),
        destination.to_string(),
        ticket.to_string(),
        None,
    )
    .unwrap()
    .to_der()
    .unwrap()
}

/// Reads binary frames until they add up to a PDU, the way the client does —
/// the socket is a byte stream, not one message per PDU.
async fn next_pdu(io: &Io<Sealed>, codec: &ws::Codec) -> RDCleanPath {
    let mut buffer = Vec::new();
    loop {
        let frame = timeout(Duration::from_secs(5), io.recv(codec))
            .await
            .expect("a frame should arrive")
            .unwrap()
            .expect("the connection should stay open");
        match frame {
            ws::Frame::Binary(data) => buffer.extend_from_slice(&data),
            // Every frame on this endpoint is binary — including the errors,
            // which have to be PDUs the client can decode.
            other => panic!("expected a binary frame, got {other:?}"),
        }

        match RDCleanPathPdu::detect(&buffer) {
            DetectionResult::Detected { total_length, .. } if buffer.len() >= total_length => {
                return RDCleanPathPdu::from_der(&buffer[..total_length])
                    .expect("the proxy sent a decodable PDU")
                    .into_enum()
                    .expect("the PDU is a complete one");
            }
            DetectionResult::Detected { .. } | DetectionResult::NotEnoughBytes => {}
            DetectionResult::Failed => {
                panic!("the proxy sent something that is not an RDCleanPath PDU")
            }
        }
    }
}

/// The HTTP status a refusal carries, where it is one.
fn http_error(pdu: &RDCleanPath) -> Option<u16> {
    match pdu {
        RDCleanPath::GeneralErr(err) => err.http_status_code,
        _ => None,
    }
}

/// The binary bytes of the next frame, whatever they are.
async fn next_bytes(io: &Io<Sealed>, codec: &ws::Codec) -> Vec<u8> {
    let frame = timeout(Duration::from_secs(5), io.recv(codec))
        .await
        .expect("a frame should arrive")
        .unwrap()
        .expect("the connection should stay open");
    match frame {
        ws::Frame::Binary(data) => data.to_vec(),
        other => panic!("expected a binary frame, got {other:?}"),
    }
}

async fn send(io: &Io<Sealed>, codec: &ws::Codec, bytes: Vec<u8>) {
    io.send(ws::Message::Binary(Bytes::from(bytes)), codec)
        .await
        .unwrap();
}

// ------------------------------------------------------------------- the tests

#[ntex::test]
async fn without_full_access_the_upgrade_is_refused() {
    let state = app_state(false).await;
    let srv = test_server(state).await;

    assert!(rdp_connection(&srv).await.is_err());
}

#[ntex::test]
async fn a_stream_ticket_is_not_an_rdp_ticket() {
    // A stream ticket authorises a byte relay; this endpoint speaks a handshake
    // first, and the two are not interchangeable. The purpose is what a ticket
    // is *for*, not a label on it.
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&dead_addr(), &ticket)).await;

    assert_eq!(http_error(&next_pdu(&io, &codec).await), Some(401));
}

#[ntex::test]
async fn a_forged_ticket_is_refused() {
    let state = app_state(true).await;
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&dead_addr(), "dead.beef")).await;

    assert_eq!(http_error(&next_pdu(&io, &codec).await), Some(401));
}

#[ntex::test]
async fn a_pdu_that_is_not_a_request_is_refused() {
    // A response PDU decodes, so this is the case the `into_enum` arm has to
    // answer rather than the decoder's.
    let state = app_state(true).await;
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(
        &io,
        &codec,
        RDCleanPathPdu::new_general_error().to_der().unwrap(),
    )
    .await;

    assert_eq!(http_error(&next_pdu(&io, &codec).await), Some(400));
}

#[ntex::test]
async fn a_preconnection_blob_is_refused_rather_than_ignored() {
    // The blob is a PCB for the RDP server and what a client puts in the string
    // is a convention its author picked, so reading it wrong routes the session
    // to a different RDP source with nothing to show for it.
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    let pdu = RDCleanPathPdu::new_request(
        connection_request(),
        dead_addr(),
        ticket,
        Some("a-pcb-the-agent-does-not-read".to_string()),
    )
    .unwrap();

    send(&io, &codec, pdu.to_der().unwrap()).await;

    let refusal = next_pdu(&io, &codec).await;
    assert!(matches!(refusal, RDCleanPath::GeneralErr(_)), "{refusal:?}");
    assert_eq!(http_error(&refusal), None);
}

#[ntex::test]
async fn an_unreachable_target_is_answered_as_a_bad_gateway() {
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&dead_addr(), &ticket)).await;

    assert_eq!(http_error(&next_pdu(&io, &codec).await), Some(502));
}

#[ntex::test]
async fn the_response_carries_the_servers_confirm_and_its_certificate() {
    // The certificate is the whole reason RDCleanPath exists: the handshake
    // happens on this side of the socket, so the chain has to be sent back for
    // the client to bind the session's credentials to.
    let confirm = connection_confirm(&neg_rsp(1)); // PROTOCOL_SSL
    let (target, observed) = fake_rdp(confirm.clone(), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;

    match next_pdu(&io, &codec).await {
        RDCleanPath::Response {
            x224_connection_response,
            server_cert_chain,
            server_addr,
        } => {
            assert_eq!(x224_connection_response.as_bytes(), confirm.as_slice());
            assert!(
                !server_cert_chain.is_empty(),
                "the chain is what the client needs"
            );
            // The leaf is the certificate the fake server generated, byte for
            // byte — anything else and the client would bind its credentials to
            // the wrong key.
            assert_eq!(server_cert_chain[0].as_bytes(), fake_identity().0.as_ref());
            assert_eq!(server_addr, target);
        }
        other => panic!("expected a response, got {other:?}"),
    }

    // The request the proxy forwarded is the client's own, unmodified: the
    // negotiation that gets answered is the negotiation that was asked for.
    assert_eq!(
        observed.request.lock().unwrap().as_deref(),
        Some(connection_request().as_slice())
    );
    assert!(
        *observed.tls.lock().unwrap(),
        "the proxy should have terminated TLS"
    );
}

#[ntex::test]
async fn the_response_arrives_before_anything_the_server_sent() {
    // The client reads its first bytes through `detect`, so a read loop started
    // before the response was queued would put RDP bytes in front of it and the
    // session would be reported as broken. The fake server writes its greeting
    // the moment TLS is up, which is the earliest it can.
    let greeting: &'static [u8] = b"A-GREETING-BEFORE-ANYTHING-IS-SENT";
    let (target, _) = fake_rdp(connection_confirm(&neg_rsp(2)), Some(greeting)).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;

    assert!(matches!(
        next_pdu(&io, &codec).await,
        RDCleanPath::Response { .. }
    ));
    assert_eq!(next_bytes(&io, &codec).await, greeting);
}

#[ntex::test]
async fn bytes_travel_both_ways_through_the_tls_session() {
    // What crosses this socket after the response is the RDP stream *after* the
    // agent decrypted it, so a plain echo proves the relay is on the right side
    // of the handshake.
    let (target, _) = fake_rdp(connection_confirm(&neg_rsp(2)), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;
    assert!(matches!(
        next_pdu(&io, &codec).await,
        RDCleanPath::Response { .. }
    ));

    send(&io, &codec, b"rdp-bytes".to_vec()).await;
    assert_eq!(next_bytes(&io, &codec).await, b"rdp-bytes");
}

#[ntex::test]
async fn bytes_sent_alongside_the_request_are_forwarded_and_not_lost() {
    // The wasm client may write its first RDP bytes without waiting for a reply
    // where the protocol allows it, and they arrive in the same frame as the
    // request — RDP does not tolerate reordering, so they have to reach the
    // server rather than be discarded with the PDU.
    let (target, _) = fake_rdp(connection_confirm(&neg_rsp(2)), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    let mut frame = request_pdu(&target, &ticket);
    frame.extend_from_slice(b"early-bytes");
    send(&io, &codec, frame).await;

    assert!(matches!(
        next_pdu(&io, &codec).await,
        RDCleanPath::Response { .. }
    ));
    assert_eq!(next_bytes(&io, &codec).await, b"early-bytes");
}

#[ntex::test]
async fn a_server_that_requires_credssp_is_answered_with_a_negotiation_error() {
    // The server's own bytes go back with the refusal, because "CredSSP (NLA) is
    // required" is in them — a general error would throw away the only
    // explanation the operator could be shown.
    let confirm = connection_confirm(&neg_failure(5)); // HYBRID_REQUIRED_BY_SERVER
    let (target, observed) = fake_rdp(confirm.clone(), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;

    match next_pdu(&io, &codec).await {
        RDCleanPath::NegotiationErr {
            x224_connection_response,
        } => assert_eq!(x224_connection_response, confirm),
        other => panic!("expected a negotiation error, got {other:?}"),
    }
    assert!(
        !*observed.tls.lock().unwrap(),
        "a refused negotiation must not be followed by a TLS handshake"
    );
}

#[ntex::test]
async fn a_server_that_selects_no_security_is_refused() {
    // `PROTOCOL_RDP` means no TLS at all, and this endpoint has nothing else to
    // offer: the client has already marked itself upgraded, so relaying a
    // plaintext session would be answering with something it cannot use.
    let confirm = connection_confirm(&neg_rsp(0));
    let (target, observed) = fake_rdp(confirm.clone(), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;

    match next_pdu(&io, &codec).await {
        RDCleanPath::NegotiationErr {
            x224_connection_response,
        } => assert_eq!(x224_connection_response, confirm),
        other => panic!("expected a negotiation error, got {other:?}"),
    }
    assert!(!*observed.tls.lock().unwrap());
}

#[ntex::test]
async fn a_confirm_with_no_negotiation_is_refused() {
    // Pre-Windows-7 servers answer with a plain Connection Confirm, which has
    // no blob and therefore no TLS.
    let confirm = connection_confirm(&[]);
    let (target, _) = fake_rdp(confirm.clone(), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;

    match next_pdu(&io, &codec).await {
        RDCleanPath::NegotiationErr {
            x224_connection_response,
        } => assert_eq!(x224_connection_response, confirm),
        other => panic!("expected a negotiation error, got {other:?}"),
    }
}

#[ntex::test]
async fn revoking_full_access_ends_a_running_session() {
    // The flag is only consulted when something is *started*, so a session
    // already carrying a screen would otherwise outlive the grant the panel
    // just took away.
    let (target, _) = fake_rdp(connection_confirm(&neg_rsp(2)), None).await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Rdp, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&target, &ticket)).await;
    assert!(matches!(
        next_pdu(&io, &codec).await,
        RDCleanPath::Response { .. }
    ));

    // What `DELETE /api/v1/remote-access/full-access` does.
    state
        .full_access_off
        .store(true, std::sync::atomic::Ordering::Release);
    let _ = state.full_access_revoked.send(());

    assert!(matches!(
        next_pdu(&io, &codec).await,
        RDCleanPath::GeneralErr(_)
    ));
}

#[ntex::test]
async fn a_session_opened_after_revocation_does_not_start() {
    let state = app_state(true).await;
    state
        .full_access_off
        .store(true, std::sync::atomic::Ordering::Release);
    let srv = test_server(state).await;

    assert!(rdp_connection(&srv).await.is_err());
}

#[ntex::test]
async fn a_refusal_is_recorded_without_the_ticket() {
    // The access log is the only record that a call was turned away, and the
    // ticket is a bearer credential — a row quoting it would be a row that
    // grants what it records.
    let state = app_state(true).await;
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_rdp(&srv).await;

    send(&io, &codec, request_pdu(&dead_addr(), "dead.beef")).await;
    assert_eq!(http_error(&next_pdu(&io, &codec).await), Some(401));

    let rows: Vec<(String, Option<String>)> =
        sqlx::query_as("SELECT detail, subject FROM access_log WHERE kind = 'rdp'")
            .fetch_all(&state.db)
            .await
            .unwrap();
    assert_eq!(rows.len(), 1, "{rows:?}");
    assert_eq!(rows[0].0, "ticket");
    assert_eq!(rows[0].1, None);
    assert!(!format!("{rows:?}").contains("dead.beef"));
}
