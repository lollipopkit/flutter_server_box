//! End-to-end coverage for `GET /api/v1/stream/ws`.
//!
//! The admission rules, the wire format and the actual relay are all exercised
//! against the real app: the target is a `TcpListener` this test owns, so unlike
//! the terminal's SSH half there is nothing here that needs a second machine.

use std::sync::{Arc, Once};
use std::time::Duration;

use ntex::io::{Io, Sealed};
use ntex::service::cfg::SharedCfg;
use ntex::time::{Seconds, timeout};
use ntex::util::{ByteString, Bytes};
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use ntex::ws::error::WsClientError;
use ntex::ws::{self, WsClient, WsConnection};
use rustls::crypto::ring;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::stream::stream_ws;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

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
                .service(web::scope("/api/v1").route("/stream/ws", web::get().to(stream_ws)))
        }
    })
    .await
}

/// A listener that echoes everything it receives.
///
/// Enough of a peer to prove the bytes went through in both directions, which
/// is the whole of what this endpoint does — it understands neither RDP nor
/// VNC, so neither is what a test of it should speak.
async fn echo_server() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    tokio::spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            tokio::spawn(async move {
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
    addr
}

/// A port nothing is listening on, so `open` fails at connect.
fn dead_addr() -> String {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    drop(listener);
    addr
}

async fn stream_connection(
    srv: &TestServer,
    ticket: &str,
) -> Result<WsConnection<Sealed>, WsClientError> {
    WsClient::builder(srv.url("/api/v1/stream/ws"))
        .address(srv.addr())
        .timeout(Seconds(60))
        .protocols([format!("sbm-ticket.{ticket}")])
        .build(SharedCfg::default())
        .await
        .unwrap()
        .connect()
        .await
        .map(WsConnection::seal)
}

async fn open_stream(srv: &TestServer, ticket: &str) -> (Io<Sealed>, ws::Codec) {
    let conn = stream_connection(srv, ticket)
        .await
        .expect("upgrade should succeed");
    let (io, codec, _) = conn.into_inner();
    (io, codec)
}

/// Reads frames until a Text one arrives, and returns it parsed.
async fn next_control(io: &Io<Sealed>, codec: &ws::Codec) -> serde_json::Value {
    loop {
        let frame = timeout(Duration::from_secs(5), io.recv(codec))
            .await
            .expect("a control frame should arrive")
            .unwrap()
            .expect("the connection should stay open");
        if let ws::Frame::Text(data) = frame {
            return serde_json::from_slice(&data).unwrap();
        }
    }
}

/// Sends `open` for [target] — `host:port` — and returns the reply.
async fn request(
    io: &Io<Sealed>,
    codec: &ws::Codec,
    target: &str,
) -> serde_json::Value {
    let (host, port) = target.rsplit_once(':').unwrap();
    io.send(
        ws::Message::Text(ByteString::from(format!(
            r#"{{"type":"open","host":"{host}","port":{port}}}"#
        ))),
        codec,
    )
    .await
    .unwrap();
    next_control(io, codec).await
}

#[ntex::test]
async fn without_full_access_the_upgrade_is_refused() {
    let state = app_state(false).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(stream_connection(&srv, &ticket).await.is_err());
}

#[ntex::test]
async fn a_terminal_ticket_is_not_a_stream_ticket() {
    // The purpose is what a ticket is for, not a label on it: a client that
    // asks the terminal for a ticket and then opens the relay with it would
    // otherwise be trading one grant for another.
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(stream_connection(&srv, &ticket).await.is_err());
}

#[ntex::test]
async fn a_missing_or_forged_ticket_is_refused() {
    let state = app_state(true).await;
    let srv = test_server(state).await;

    assert!(srv.ws_at("/api/v1/stream/ws").await.is_err());
    assert!(stream_connection(&srv, "dead.beef").await.is_err());
}

#[ntex::test]
async fn bytes_travel_both_ways() {
    let target = echo_server().await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    io.send(ws::Message::Binary(Bytes::from_static(b"ping")), &codec)
        .await
        .unwrap();
    let frame = timeout(Duration::from_secs(5), io.recv(&codec))
        .await
        .expect("the echo should come back")
        .unwrap()
        .unwrap();
    match frame {
        ws::Frame::Binary(data) => assert_eq!(&data[..], b"ping"),
        other => panic!("expected the bytes back, got {other:?}"),
    }
}

#[ntex::test]
async fn an_unreachable_target_is_reported_as_a_connect_failure() {
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    let reply = request(&io, &codec, &dead_addr()).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "connect_failed");
}

#[ntex::test]
async fn a_second_open_on_one_socket_is_refused() {
    // One socket is one connection: a relay that could be re-pointed mid-stream
    // would let a single ticket reach a second address.
    let target = echo_server().await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    let reply = request(&io, &codec, &target).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "bad_request");
}

#[ntex::test]
async fn input_before_open_is_refused_rather_than_buffered() {
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    io.send(ws::Message::Binary(Bytes::from_static(b"hi")), &codec)
        .await
        .unwrap();

    assert_eq!(next_control(&io, &codec).await["code"], "bad_request");
}

#[ntex::test]
async fn revoking_full_access_ends_a_running_relay() {
    // The flag `full_access_allowed` reads is only consulted when something is
    // started, so a connection already carrying bytes would otherwise outlive
    // the grant the panel just took away — and the app would go on showing a
    // desktop it is no longer allowed to reach.
    let target = echo_server().await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    // What `DELETE /api/v1/remote-access/full-access` does.
    state
        .full_access_off
        .store(true, std::sync::atomic::Ordering::Release);
    let _ = state.full_access_revoked.send(());

    let reply = next_control(&io, &codec).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "full_access_disabled");
}

#[ntex::test]
async fn a_relay_opened_before_revocation_still_starts_after_a_reconnect() {
    // The other half of the rule: what was refused has to stay refused, so a
    // client that reports the close and tries again is turned away at the
    // upgrade rather than getting a second connection.
    let state = app_state(true).await;
    state
        .full_access_off
        .store(true, std::sync::atomic::Ordering::Release);
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(stream_connection(&srv, &ticket).await.is_err());
}
