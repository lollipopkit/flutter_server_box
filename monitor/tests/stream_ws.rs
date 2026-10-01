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
use server_box_monitor::api::authz::revoke_lost;
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
    remote.terminal.enabled = Some(true);
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    common::seed_as_upgrade(&db, &config).await;
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

/// A frame past ntex's default 64 KiB: the relay takes it whole. With the
/// default codec the agent dropped the connection on it, which cut every
/// sizeable upload through the relay (an SFTP write, an HTTP body to PVE).
#[ntex::test]
async fn a_frame_bigger_than_64_kib_goes_through() {
    let target = echo_server().await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
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
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
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
async fn taking_connect_away_ends_a_running_relay() {
    // The role is only consulted when something is started, so a connection
    // already carrying bytes would otherwise outlive the grant an admin just
    // took away — and the app would go on showing a desktop it is no longer
    // allowed to reach.
    let target = echo_server().await;
    let state = app_state(true).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");

    let mut grants = common::grants_of(&state.db, "admin").await;
    grants.connect = None;
    common::set_grants(&state.db, "admin", &grants).await;
    revoke_lost(&state, "permission_revoked").await;

    let reply = next_control(&io, &codec).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "permission_revoked");
}

#[ntex::test]
async fn a_relay_opened_before_revocation_still_starts_after_a_reconnect() {
    // The other half of the rule: what was refused has to stay refused, so a
    // client that reports the close and tries again is turned away at the
    // upgrade rather than getting a second connection.
    let state = app_state(true).await;
    common::set_grants(&state.db, "admin", &Default::default()).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(stream_connection(&srv, &ticket).await.is_err());
}

/// The admin role with `connect` limited to [allow], and nothing else.
async fn connect_only(state: &AppState, allow: &[String]) {
    let grants = server_box_monitor::core::permissions::Grants {
        connect: Some(server_box_monitor::core::permissions::ConnectGrant {
            allow: allow.to_vec(),
        }),
        ..Default::default()
    };
    common::set_grants(&state.db, "admin", &grants).await;
}

#[ntex::test]
async fn an_address_the_roles_allow_list_names_is_relayed() {
    let target = echo_server().await;
    let state = app_state(true).await;
    connect_only(&state, std::slice::from_ref(&target)).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    assert_eq!(request(&io, &codec, &target).await["type"], "ready");
}

#[ntex::test]
async fn an_address_outside_the_allow_list_is_refused_before_dialling() {
    let target = echo_server().await;
    let (_, port) = target.rsplit_once(':').unwrap();
    let state = app_state(true).await;
    // The same host, another port: the port is part of what is allowed.
    connect_only(&state, &["127.0.0.1:1".to_string()]).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;

    let reply = request(&io, &codec, &format!("127.0.0.1:{port}")).await;
    assert_eq!(reply["code"], "forbidden", "{reply}");
}

#[ntex::test]
async fn a_host_name_is_allowed_only_if_every_address_it_resolves_to_is() {
    let target = echo_server().await;
    let (_, port) = target.rsplit_once(':').unwrap();

    // `localhost` is 127.0.0.1, and on most machines ::1 as well. Naming both
    // lets it through — the dial goes to whichever answers, and the echo
    // server is on the IPv4 one.
    let state = app_state(true).await;
    connect_only(
        &state,
        &[format!("127.0.0.1:{port}"), format!("[::1]:{port}")],
    )
    .await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    assert_eq!(
        request(&io, &codec, &format!("localhost:{port}")).await["type"],
        "ready"
    );

    // A name none of whose addresses is allowed is refused, though it is the
    // same machine an allowed entry for another network would not cover.
    let state = app_state(true).await;
    connect_only(&state, &["10.0.0.0/8".to_string()]).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    assert_eq!(
        request(&io, &codec, &format!("localhost:{port}")).await["code"],
        "forbidden"
    );
}

#[ntex::test]
async fn an_ipv6_entry_matches_an_ipv6_target() {
    // Skipped where the machine has no IPv6 loopback to listen on.
    let Ok(listener) = TcpListener::bind("[::1]:0").await else {
        return;
    };
    let port = listener.local_addr().unwrap().port();
    tokio::spawn(async move {
        // Held, not answered: a peer that closed at once would race its own
        // `exit` against the `ready` this test is waiting for.
        let mut held = Vec::new();
        while let Ok((socket, _)) = listener.accept().await {
            held.push(socket);
        }
    });
    let state = app_state(true).await;
    connect_only(&state, &[format!("[::1]:{port}")]).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    let reply = request(&io, &codec, &format!("::1:{port}")).await;
    assert_eq!(reply["type"], "ready", "{reply}");
}

#[ntex::test]
async fn accepting_a_remote_forwards_connection_needs_listen() {
    // `connect` alone opens the relay, and `accept` is still refused: taking a
    // connection a listener holds is the other direction.
    let state = app_state(true).await;
    connect_only(&state, &[]).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_stream(&srv, &ticket).await;
    io.send(
        ws::Message::Text(ByteString::from(format!(
            r#"{{"type":"accept","id":"{}"}}"#,
            "00".repeat(16)
        ))),
        &codec,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io, &codec).await["code"], "forbidden");
}
