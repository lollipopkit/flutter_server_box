//! End-to-end coverage for `GET /api/v1/stream/ws`.
//!
//! The admission rules, the wire format and the actual relay are all exercised
//! against the real app: the target is a `TcpListener` this test owns, so unlike
//! the terminal's SSH half there is nothing here that needs a second machine.

mod common;

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
use server_box_monitor::api::authz::end_account;
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

/// An agent with its account.
async fn app_state() -> Arc<AppState> {
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some("test-secret-that-is-long-enough-32ch".to_string()),
        ..Default::default()
    };

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    common::add_owner(&db).await;
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

/// A listener that takes a connection and never reads it: a target slower
/// than anything the client can send. The sockets are kept, so the connection
/// stays open rather than resetting.
async fn stalled_server() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    tokio::spawn(async move {
        let mut held = Vec::new();
        while let Ok((socket, _)) = listener.accept().await {
            held.push(socket);
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
async fn a_terminal_ticket_is_not_a_stream_ticket() {
    // The purpose is what a ticket is for, not a label on it: a client that
    // asks the terminal for a ticket and then opens the relay with it would
    // otherwise be trading one grant for another.
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal).unwrap();
    let srv = test_server(state).await;

    assert!(stream_connection(&srv, &ticket).await.is_err());
}

#[ntex::test]
async fn a_missing_or_forged_ticket_is_refused() {
    let state = app_state().await;
    let srv = test_server(state).await;

    assert!(srv.ws_at("/api/v1/stream/ws").await.is_err());
    assert!(stream_connection(&srv, "dead.beef").await.is_err());
}

#[ntex::test]
async fn bytes_travel_both_ways() {
    let target = echo_server().await;
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
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

/// A frame past ntex's default 64 KiB: the relay takes it whole. With the
/// default codec the agent dropped the connection on it, which cut every
/// sizeable upload through the relay (an SFTP write, an HTTP body to PVE).
#[ntex::test]
async fn a_frame_bigger_than_64_kib_goes_through() {
    let target = echo_server().await;
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    let sent: Vec<u8> = (0..1 << 20).map(|i: u32| (i % 251) as u8).collect();
    io.send(ws::Message::Binary(Bytes::from(sent.clone())), &codec)
        .await
        .unwrap();
    let mut back = Vec::new();
    while back.len() < sent.len() {
        let frame = timeout(Duration::from_secs(5), io.recv(&codec))
            .await
            .expect("the echo should come back")
            .unwrap()
            .expect("the connection should stay open");
        match frame {
            ws::Frame::Binary(data) => back.extend_from_slice(&data),
            other => panic!("expected the bytes back, got {other:?}"),
        }
    }
    assert_eq!(back, sent);
}

/// A target that does not read holds the client back: the agent stops
/// reading the socket once its queue towards the target is full, instead of
/// taking every frame into memory as it arrives.
#[ntex::test]
async fn a_target_that_does_not_read_holds_the_client_back() {
    let target = stalled_server().await;
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    let frame = Bytes::from(vec![7u8; 64 * 1024]);
    let mut sent = 0usize;
    let sending = async {
        loop {
            if io
                .send(ws::Message::Binary(frame.clone()), &codec)
                .await
                .is_err()
            {
                break;
            }
            sent += frame.len();
        }
    };
    let _ = timeout(Duration::from_secs(3), sending).await;
    // The queue (256 frames of 64 KiB) and the sockets' buffers, not the
    // gigabytes three seconds of loopback would carry.
    assert!(sent < 128 << 20, "sent {} MiB into a target that reads nothing", sent >> 20);
}

#[ntex::test]
async fn an_unreachable_target_is_reported_as_a_connect_failure() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
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
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    let reply = request(&io, &codec, &target).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "bad_request");
}

#[ntex::test]
async fn input_before_open_is_refused_rather_than_buffered() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    io.send(ws::Message::Binary(Bytes::from_static(b"hi")), &codec)
        .await
        .unwrap();

    assert_eq!(next_control(&io, &codec).await["code"], "bad_request");
}

#[ntex::test]
async fn a_password_change_ends_a_running_relay() {
    // The account is only consulted when something is started, so a
    // connection already carrying bytes would otherwise outlive the password
    // it was opened under.
    let target = echo_server().await;
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    let hash = bcrypt::hash("a-new-password", 4).unwrap();
    server_box_monitor::db::accounts::set_password_hash(&state.db, &hash).await.unwrap();
    end_account(&state, "password_changed");

    let reply = next_control(&io, &codec).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "password_changed");
}

/// `GET /live` lists a running relay, and ending it from there stops that one
/// and no other.
#[ntex::test]
async fn a_running_relay_is_listed_and_can_be_ended_alone() {
    let target = echo_server().await;
    let state = app_state().await;
    let srv = test_server(state.clone()).await;
    let (first, codec) = open_stream(&srv, &state.tickets.issue(Purpose::Stream).unwrap()).await;
    assert_eq!(request(&first, &codec, &target).await["type"], "ready");
    let (second, second_codec) = open_stream(&srv, &state.tickets.issue(Purpose::Stream).unwrap()).await;
    assert_eq!(request(&second, &second_codec, &target).await["type"], "ready");

    let listed = state.live.list();
    assert_eq!(listed.len(), 2);
    assert_eq!(listed[0].target, target);
    assert_eq!(listed[0].remote_ip.as_deref(), Some("127.0.0.1"));

    assert!(state.live.end(&listed[0].id));
    let reply = next_control(&first, &codec).await;
    assert_eq!((reply["type"].as_str(), reply["code"].as_str()), (Some("error"), Some("ended")));

    // Off the list once its loop let go of it; the other still there.
    for _ in 0..50 {
        if state.live.list().len() == 1 {
            break;
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    let left = state.live.list();
    assert_eq!(left.len(), 1);
    assert_eq!(left[0].id, listed[1].id);
}

#[ntex::test]
async fn any_address_the_machine_reaches_is_relayed() {
    // `localhost` is 127.0.0.1, and on most machines ::1 as well: the dial
    // goes to whichever answers, and the echo server is on the IPv4 one.
    let target = echo_server().await;
    let (_, port) = target.rsplit_once(':').unwrap();
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Stream).unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    assert_eq!(
        request(&io, &codec, &format!("localhost:{port}")).await["type"],
        "ready"
    );
}
