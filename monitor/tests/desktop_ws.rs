//! End-to-end admission and byte relay for the monitor desktop endpoint.

use std::sync::atomic::Ordering;
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
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::desktop::desktop_ws;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

async fn test_server(full_access: bool) -> (Arc<AppState>, TestServer) {
    static CRYPTO: Once = Once::new();
    CRYPTO.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
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
    let state = AppState::new(Arc::new(config), db);
    let srv = web_test::server({
        let state = state.clone();
        move || {
            let state = state.clone();
            async move {
                App::new()
                    .state(state)
                    .service(web::scope("/api/v1").route("/desktop/ws", web::get().to(desktop_ws)))
            }
        }
    })
    .await;
    (state, srv)
}

async fn connect(
    srv: &TestServer,
    ticket: &str,
) -> Result<WsConnection<Sealed>, ntex::ws::error::WsClientError> {
    WsClient::builder(srv.url("/api/v1/desktop/ws"))
        .address(srv.addr())
        .timeout(Seconds(10))
        .protocols([format!("sbm-ticket.{ticket}")])
        .build(SharedCfg::default())
        .await
        .unwrap()
        .connect()
        .await
        .map(WsConnection::seal)
}

async fn reply(io: &Io<Sealed>, codec: &ws::Codec) -> ws::Frame {
    timeout(Duration::from_secs(5), io.recv(codec))
        .await
        .unwrap()
        .unwrap()
        .unwrap()
}

#[ntex::test]
async fn desktop_requires_full_access_and_its_own_ticket() {
    let (state, srv) = test_server(false).await;
    let ticket = state.tickets.issue(Purpose::Desktop, "admin").unwrap();
    assert!(connect(&srv, &ticket).await.is_err());

    let (state, srv) = test_server(true).await;
    let terminal_ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    assert!(connect(&srv, &terminal_ticket).await.is_err());
}

#[ntex::test]
async fn desktop_relay_carries_tcp_bytes() {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    let echo = tokio::spawn(async move {
        let (mut stream, _) = listener.accept().await.unwrap();
        let mut buffer = [0u8; 1024];
        let count = stream.read(&mut buffer).await.unwrap();
        stream.write_all(&buffer[..count]).await.unwrap();
    });
    let (state, srv) = test_server(true).await;
    let ticket = state.tickets.issue(Purpose::Desktop, "admin").unwrap();
    let (io, codec, _) = connect(&srv, &ticket).await.unwrap().into_inner();
    io.send(
        ws::Message::Text(ByteString::from(format!(
            r#"{{"host":"127.0.0.1","port":{port}}}"#
        ))),
        &codec,
    )
    .await
    .unwrap();
    let ws::Frame::Text(ready) = reply(&io, &codec).await else {
        panic!("expected relay ready");
    };
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&ready).unwrap()["type"],
        "ready"
    );
    io.send(ws::Message::Binary(Bytes::from_static(b"hello")), &codec)
        .await
        .unwrap();
    let ws::Frame::Binary(data) = reply(&io, &codec).await else {
        panic!("expected relayed bytes");
    };
    assert_eq!(&data[..], b"hello");
    echo.await.unwrap();
}

#[ntex::test]
async fn disabling_full_access_after_upgrade_blocks_target_open() {
    let (state, srv) = test_server(true).await;
    let ticket = state.tickets.issue(Purpose::Desktop, "admin").unwrap();
    let (io, codec, _) = connect(&srv, &ticket).await.unwrap().into_inner();
    state.full_access_off.store(true, Ordering::Release);
    io.send(
        ws::Message::Text(ByteString::from_static(
            "{\"host\":\"127.0.0.1\",\"port\":3389}",
        )),
        &codec,
    )
    .await
    .unwrap();
    let ws::Frame::Text(response) = reply(&io, &codec).await else {
        panic!("expected access error");
    };
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&response).unwrap()["type"],
        "error"
    );
}

#[ntex::test]
async fn turning_full_access_off_closes_an_existing_desktop_relay() {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    let echo = tokio::spawn(async move {
        let (mut stream, _) = listener.accept().await.unwrap();
        let mut byte = [0u8; 1];
        stream.read_exact(&mut byte).await.unwrap();
        stream.write_all(&byte).await.unwrap();
        let _ = stream.read(&mut byte).await;
    });
    let (state, srv) = test_server(true).await;
    let ticket = state.tickets.issue(Purpose::Desktop, "admin").unwrap();
    let (io, codec, _) = connect(&srv, &ticket).await.unwrap().into_inner();
    io.send(
        ws::Message::Text(ByteString::from(format!(
            r#"{{"host":"127.0.0.1","port":{port}}}"#
        ))),
        &codec,
    )
    .await
    .unwrap();
    assert!(matches!(reply(&io, &codec).await, ws::Frame::Text(_)));
    io.send(ws::Message::Binary(Bytes::from_static(b"x")), &codec)
        .await
        .unwrap();
    assert!(matches!(reply(&io, &codec).await, ws::Frame::Binary(_)));
    state.full_access_off.store(true, Ordering::Release);
    assert!(matches!(reply(&io, &codec).await, ws::Frame::Close(_)));
    echo.await.unwrap();
}
