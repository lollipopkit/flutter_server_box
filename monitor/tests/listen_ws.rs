//! End-to-end coverage for `GET /api/v1/listen/ws`, and the stream `accept`
//! that takes what it hands over.
//!
//! The connection being forwarded is a `TcpStream` this test opens against the
//! port the agent listened on, so the whole remote-forward path runs here:
//! bind, announce, claim, relay.

mod common;

use std::sync::{Arc, Once};
use std::time::Duration;

use ntex::io::{Io, Sealed};
use ntex::service::cfg::SharedCfg;
use ntex::time::{Seconds, timeout};
use ntex::util::{ByteString, Bytes};
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use ntex::ws::{self, WsClient, WsConnection};
use rustls::crypto::ring;
use server_box_monitor::api::authz::revoke_lost;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::listen::listen_ws;
use server_box_monitor::api::ws::stream::stream_ws;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn app_state(listen_public: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some("test-secret-that-is-long-enough-32ch".to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = Some(true);
    remote.full_access = Some(true);
    remote.listen_public = Some(listen_public);
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
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route("/stream/ws", web::get().to(stream_ws))
                    .route("/listen/ws", web::get().to(listen_ws)),
            )
        }
    })
    .await
}

async fn connect(srv: &TestServer, path: &str, ticket: &str) -> (Io<Sealed>, ws::Codec) {
    let conn = WsClient::builder(srv.url(path))
        .address(srv.addr())
        .timeout(Seconds(60))
        .protocols([format!("sbm-ticket.{ticket}")])
        .build(SharedCfg::default())
        .await
        .unwrap()
        .connect()
        .await
        .map(WsConnection::seal)
        .expect("upgrade should succeed");
    let (io, codec, _) = conn.into_inner();
    (io, codec)
}

async fn send_text(io: &Io<Sealed>, codec: &ws::Codec, json: String) {
    io.send(ws::Message::Text(ByteString::from(json)), codec)
        .await
        .unwrap();
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

/// Listens on an OS-chosen loopback port and answers it, with the control
/// socket that holds it.
async fn listen(srv: &TestServer, state: &AppState) -> (Io<Sealed>, ws::Codec, u16) {
    let ticket = state.tickets.issue(Purpose::Listen, "admin").unwrap();
    let (io, codec) = connect(srv, "/api/v1/listen/ws", &ticket).await;
    send_text(&io, &codec, r#"{"type":"listen","host":"127.0.0.1","port":0}"#.into()).await;
    let ready = next_control(&io, &codec).await;
    assert_eq!(ready["type"], "ready", "{ready}");
    let port = ready["port"].as_u64().unwrap() as u16;
    assert_ne!(port, 0);
    (io, codec, port)
}

/// Opens a stream as [subject] and sends `accept` for [id].
async fn accept(
    srv: &TestServer,
    state: &AppState,
    subject: &str,
    id: &str,
) -> (Io<Sealed>, ws::Codec, serde_json::Value) {
    let ticket = state.tickets.issue(Purpose::Stream, subject).unwrap();
    let (io, codec) = connect(srv, "/api/v1/stream/ws", &ticket).await;
    send_text(&io, &codec, format!(r#"{{"type":"accept","id":"{id}"}}"#)).await;
    let reply = next_control(&io, &codec).await;
    (io, codec, reply)
}

#[ntex::test]
async fn a_connection_to_the_port_is_relayed_to_the_app() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (control, control_codec, port) = listen(&srv, &state).await;

    let mut client = TcpStream::connect(("127.0.0.1", port)).await.unwrap();
    let incoming = next_control(&control, &control_codec).await;
    assert_eq!(incoming["type"], "incoming");
    let id = incoming["id"].as_str().unwrap().to_string();
    assert_eq!(id.len(), 32);
    assert!(incoming["peer"].as_str().unwrap().starts_with("127.0.0.1:"));

    let (io, codec, reply) = accept(&srv, &state, "admin", &id).await;
    assert_eq!(reply["type"], "ready", "{reply}");

    // Towards the app.
    client.write_all(b"hello").await.unwrap();
    let frame = timeout(Duration::from_secs(5), io.recv(&codec))
        .await
        .expect("the bytes should arrive")
        .unwrap()
        .unwrap();
    match frame {
        ws::Frame::Binary(data) => assert_eq!(&data[..], b"hello"),
        other => panic!("expected the bytes, got {other:?}"),
    }

    // And back to whoever connected.
    io.send(ws::Message::Binary(Bytes::from_static(b"world")), &codec)
        .await
        .unwrap();
    let mut back = [0u8; 5];
    tokio::time::timeout(Duration::from_secs(5), client.read_exact(&mut back))
        .await
        .expect("the reply should arrive")
        .unwrap();
    assert_eq!(&back, b"world");
}

#[ntex::test]
async fn a_connection_is_only_taken_by_the_account_that_listened() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (control, control_codec, port) = listen(&srv, &state).await;
    let _client = TcpStream::connect(("127.0.0.1", port)).await.unwrap();
    let id = next_control(&control, &control_codec).await["id"]
        .as_str()
        .unwrap()
        .to_string();

    let (_, _, reply) = accept(&srv, &state, "intruder", &id).await;
    assert_eq!(reply["code"], "not_found");
    // Still there for its owner.
    let (_, _, reply) = accept(&srv, &state, "admin", &id).await;
    assert_eq!(reply["type"], "ready");
}

#[ntex::test]
async fn an_unknown_id_is_not_found() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (_, _, reply) = accept(&srv, &state, "admin", "00".repeat(16).as_str()).await;
    assert_eq!(reply["code"], "not_found");
}

#[ntex::test]
async fn closing_the_control_socket_drops_what_waits() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (control, control_codec, port) = listen(&srv, &state).await;
    let _client = TcpStream::connect(("127.0.0.1", port)).await.unwrap();
    let id = next_control(&control, &control_codec).await["id"]
        .as_str()
        .unwrap()
        .to_string();

    control.close();
    drop(control);
    // The agent sees the close on its own schedule.
    let mut reply = serde_json::Value::Null;
    for _ in 0..50 {
        reply = accept(&srv, &state, "admin", &id).await.2;
        if reply["code"] == "not_found" {
            break;
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    assert_eq!(reply["code"], "not_found");
    // And the port is free again.
    assert!(TcpStream::connect(("127.0.0.1", port)).await.is_err());
}

#[ntex::test]
async fn a_public_address_needs_listen_public() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let ticket = state.tickets.issue(Purpose::Listen, "admin").unwrap();
    let (io, codec) = connect(&srv, "/api/v1/listen/ws", &ticket).await;
    send_text(&io, &codec, r#"{"type":"listen","host":"0.0.0.0","port":0}"#.into()).await;
    assert_eq!(next_control(&io, &codec).await["code"], "not_permitted");
}

#[ntex::test]
async fn a_second_listen_on_one_socket_is_refused() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (io, codec, _) = listen(&srv, &state).await;
    send_text(&io, &codec, r#"{"type":"listen","host":"127.0.0.1","port":0}"#.into()).await;
    assert_eq!(next_control(&io, &codec).await["code"], "bad_request");
}

#[ntex::test]
async fn a_stream_ticket_is_not_a_listen_ticket() {
    let state = app_state(false).await;
    let ticket = state.tickets.issue(Purpose::Stream, "admin").unwrap();
    let srv = test_server(state).await;
    let result = WsClient::builder(srv.url("/api/v1/listen/ws"))
        .address(srv.addr())
        .protocols([format!("sbm-ticket.{ticket}")])
        .build(SharedCfg::default())
        .await
        .unwrap()
        .connect()
        .await;
    assert!(result.is_err());
}

#[ntex::test]
async fn taking_listen_away_closes_the_listener() {
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (io, codec, _) = listen(&srv, &state).await;

    let mut grants = common::grants_of(&state.db, "admin").await;
    grants.listen = None;
    common::set_grants(&state.db, "admin", &grants).await;
    revoke_lost(&state, "permission_revoked").await;

    assert_eq!(next_control(&io, &codec).await["code"], "permission_revoked");
}

#[ntex::test]
async fn a_change_that_leaves_listen_alone_keeps_the_listener() {
    // Every role change is broadcast; a listener whose own account kept what
    // it needs must not be closed by somebody else's edit.
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (io, codec, _) = listen(&srv, &state).await;

    revoke_lost(&state, "permission_revoked").await;
    send_text(&io, &codec, r#"{"type":"ping"}"#.into()).await;
    assert_eq!(next_control(&io, &codec).await["type"], "pong");
}

#[ntex::test]
async fn a_port_outside_the_roles_range_is_refused() {
    let state = app_state(false).await;
    let mut grants = common::grants_of(&state.db, "admin").await;
    grants.listen = Some(server_box_monitor::core::permissions::ListenGrant {
        public: false,
        ports: Some([20000, 20010]),
    });
    common::set_grants(&state.db, "admin", &grants).await;
    let srv = test_server(state.clone()).await;
    let ticket = state.tickets.issue(Purpose::Listen, "admin").unwrap();
    let (io, codec) = connect(&srv, "/api/v1/listen/ws", &ticket).await;

    send_text(&io, &codec, r#"{"type":"listen","host":"127.0.0.1","port":0}"#.into()).await;
    assert_eq!(next_control(&io, &codec).await["code"], "not_permitted");
}

#[ntex::test]
async fn a_password_change_closes_the_listener() {
    // The role is unchanged, so this is not what `revoke_lost` sees: what
    // ends it is that the account's password moved on since it was opened —
    // the reason to change a password is that someone else may have it.
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;
    let (io, codec, _) = listen(&srv, &state).await;

    let hash = bcrypt::hash("a-new-password", 4).unwrap();
    server_box_monitor::db::accounts::set_password_hash(&state.db, "admin", &hash)
        .await
        .unwrap();
    server_box_monitor::api::authz::end_account(&state, "admin", "permission_revoked");

    assert_eq!(next_control(&io, &codec).await["code"], "permission_revoked");
}
