//! End-to-end coverage for `GET /api/v1/tunnel/ws`.
//!
//! Runs the real ntex app against a real TCP server standing in for sshd, so
//! it exercises the parts that can't be unit tested: the WebSocket handshake,
//! the ticket exchange, and — the reason this file exists — whether tokio
//! sockets and tasks actually work inside ntex's per-worker runtime. That
//! bridging was the main implementation risk in the design.
//!
//! The stand-in speaks no SSH: the relay is deliberately protocol-agnostic,
//! so an echo server proves the same property with far less machinery.

use std::sync::{Arc, Once};
use std::time::Duration;

use ntex::rt::spawn;
use ntex::time::timeout;
use ntex::util::{ByteString, Bytes};
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use ntex::ws;
use rustls::crypto::ring;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::api::ws::tunnel::tunnel_ws;
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::oneshot;

/// Accepts one connection and echoes until EOF.
async fn spawn_echo_server() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            spawn(async move {
                let mut buf = vec![0u8; 4096];
                loop {
                    match socket.read(&mut buf).await {
                        Ok(0) | Err(_) => break,
                        Ok(n) => {
                            if socket.write_all(&buf[..n]).await.is_err() {
                                break;
                            }
                        }
                    }
                }
            });
        }
    });
    addr
}

/// Accepts a connection, sends `payload`, then closes — for the direction
/// where the target speaks first, like a real sshd's version banner.
async fn spawn_greeting_server(payload: &'static [u8]) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            let _ = socket.write_all(payload).await;
            let _ = socket.shutdown().await;
        }
    });
    addr
}

/// ntex's test client is built with rustls support, and rustls refuses to
/// pick a backend by itself when more than one could apply. Production code
/// never hits this — `load_rustls_config` names the provider explicitly — but
/// the test harness constructs its client the generic way.
fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn app_state(ssh_addr: &str, tunnel_enabled: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some("test-secret-that-is-long-enough-32ch".to_string());
    let mut remote = config.get_remote_access();
    remote.ssh_addr = ssh_addr.to_string();
    remote.tunnel.enabled = tunnel_enabled;
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    AppState::new(Arc::new(config), db)
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1").route(
                    "/tunnel/ws",
                    web::get().to(tunnel_ws),
                ),
            )
        }
    })
    .await
}

#[ntex::test]
async fn relays_bytes_in_both_directions() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .expect("upgrade should succeed with a valid ticket");
    let (io, codec, _) = conn.into_inner();

    io.send(ws::Message::Binary(Bytes::from_static(b"hello")), &codec)
        .await
        .unwrap();
    assert_eq!(
        io.recv(&codec).await.unwrap().unwrap(),
        ws::Frame::Binary(Bytes::from_static(b"hello"))
    );

    // A second round proves the relay tasks stay alive rather than servicing
    // one message and exiting
    io.send(ws::Message::Binary(Bytes::from_static(b"again")), &codec)
        .await
        .unwrap();
    assert_eq!(
        io.recv(&codec).await.unwrap().unwrap(),
        ws::Frame::Binary(Bytes::from_static(b"again"))
    );
}

#[ntex::test]
async fn data_the_target_sends_first_reaches_the_client() {
    // sshd sends its version banner before the client says anything
    let greeter = spawn_greeting_server(b"SSH-2.0-OpenSSH_9.6\r\n").await;
    let state = app_state(&greeter, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .unwrap();
    let (io, codec, _) = conn.into_inner();

    assert_eq!(
        io.recv(&codec).await.unwrap().unwrap(),
        ws::Frame::Binary(Bytes::from_static(b"SSH-2.0-OpenSSH_9.6\r\n"))
    );
}

#[ntex::test]
async fn the_target_closing_closes_the_websocket() {
    let greeter = spawn_greeting_server(b"bye").await;
    let state = app_state(&greeter, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .unwrap();
    let (io, codec, _) = conn.into_inner();

    assert_eq!(
        io.recv(&codec).await.unwrap().unwrap(),
        ws::Frame::Binary(Bytes::from_static(b"bye"))
    );
    assert!(
        matches!(
            io.recv(&codec).await.unwrap().unwrap(),
            ws::Frame::Close(_)
        ),
        "EOF from the target must surface as a WebSocket close, not a hang"
    );
}

#[ntex::test]
async fn a_ticket_works_only_once() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let path = format!("/api/v1/tunnel/ws?ticket={ticket}");
    assert!(srv.ws_at(&path).await.is_ok());
    assert!(
        srv.ws_at(&path).await.is_err(),
        "replaying a ticket must not open a second tunnel"
    );
}

#[ntex::test]
async fn a_terminal_ticket_cannot_open_a_tunnel() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(
        srv.ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
            .await
            .is_err()
    );
}

#[ntex::test]
async fn no_ticket_is_refused() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let srv = test_server(state).await;

    assert!(srv.ws_at("/api/v1/tunnel/ws").await.is_err());
    assert!(
        srv.ws_at("/api/v1/tunnel/ws?ticket=deadbeef.cafe")
            .await
            .is_err()
    );
}

#[ntex::test]
async fn a_disabled_tunnel_refuses_even_a_valid_ticket() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, false).await;
    // Minted directly, bypassing the endpoint that would have refused it —
    // the handshake must not rely on the ticket endpoint having said no
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(
        srv.ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
            .await
            .is_err()
    );
}

#[ntex::test]
async fn the_connection_cap_refuses_the_extra_tunnel() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    // Rebuild with an explicit cap of one
    let mut config = (*state.config).clone();
    let mut remote = config.get_remote_access();
    remote.tunnel.max_conns = Some(1);
    config.remote_access = Some(remote);
    let state = AppState::new(Arc::new(config), state.db.clone());

    let first = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let _held = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={first}"))
        .await
        .expect("first tunnel fits");
    assert!(
        srv.ws_at(&format!("/api/v1/tunnel/ws?ticket={second}"))
            .await
            .is_err(),
        "a second tunnel must be refused while the first holds the only slot"
    );
}

#[ntex::test]
async fn several_tunnels_run_side_by_side_without_crossing_streams() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let tickets: Vec<String> = (0..4)
        .map(|_| state.tickets.issue(Purpose::Tunnel, "admin").unwrap())
        .collect();
    let srv = test_server(state).await;

    // Every other test opens one tunnel at a time; a relay that shared state
    // between connections would only show up with several live at once
    let mut conns = Vec::new();
    for ticket in &tickets {
        let conn = srv
            .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
            .await
            .expect("each tunnel should open");
        conns.push(conn.into_inner());
    }

    // Give each one a distinct payload, then check each gets its own back
    for (i, (io, codec, _)) in conns.iter().enumerate() {
        let payload = format!("stream-{i}");
        io.send(ws::Message::Binary(Bytes::from(payload)), codec)
            .await
            .unwrap();
    }
    for (i, (io, codec, _)) in conns.iter().enumerate() {
        let frame = io.recv(codec).await.unwrap().unwrap();
        assert_eq!(
            frame,
            ws::Frame::Binary(Bytes::from(format!("stream-{i}"))),
            "tunnel {i} must receive its own bytes, not another's"
        );
    }
}

#[ntex::test]
async fn text_frames_are_refused_rather_than_relayed() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .unwrap();
    let (io, codec, _) = conn.into_inner();

    io.send(ws::Message::Text(ByteString::from_static("hello")), &codec)
        .await
        .unwrap();
    // Text has no meaning here; feeding it into an SSH stream would corrupt
    // it somewhere far less obvious than the connection close
    assert!(matches!(
        io.recv(&codec).await.unwrap().unwrap(),
        ws::Frame::Close(_)
    ));
}

#[ntex::test]
async fn a_ping_is_answered() {
    let echo = spawn_echo_server().await;
    let state = app_state(&echo, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .unwrap();
    let (io, codec, _) = conn.into_inner();

    io.send(ws::Message::Ping(Bytes::from_static(b"ka")), &codec)
        .await
        .unwrap();
    assert_eq!(
        io.recv(&codec).await.unwrap().unwrap(),
        ws::Frame::Pong(Bytes::from_static(b"ka"))
    );
}

/// Well past the relay's 8-frame queue and its 32 KiB read buffer, so both
/// directions have to stall and resume rather than completing in one pass.
const BULK_FRAMES: usize = 64;
const BULK_FRAME_LEN: usize = 16 * 1024;
const BULK_TOTAL: usize = BULK_FRAMES * BULK_FRAME_LEN;

#[ntex::test]
async fn a_bulk_upload_arrives_complete_and_in_order() {
    // Counts what it receives and reports the total once the write side is
    // shut down. Deliberately not an echo: reading and writing from the same
    // task here would make the test itself the bottleneck and mask the very
    // stalling being measured.
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    let (report, total_seen) = oneshot::channel::<(usize, bool)>();
    spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut buf = vec![0u8; 4096];
        let mut total = 0usize;
        let mut intact = true;
        loop {
            match socket.read(&mut buf).await {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    intact &= buf[..n].iter().all(|&b| b == 0xAB);
                    total += n;
                }
            }
        }
        let _ = report.send((total, intact));
    });

    let state = app_state(&addr, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .unwrap();
    let (io, codec, _) = conn.into_inner();

    let chunk = Bytes::from(vec![0xABu8; BULK_FRAME_LEN]);
    for _ in 0..BULK_FRAMES {
        io.send(ws::Message::Binary(chunk.clone()), &codec)
            .await
            .unwrap();
    }
    io.send(
        ws::Message::Close(Some(ws::CloseCode::Normal.into())),
        &codec,
    )
    .await
    .unwrap();

    let (total, intact) = timeout(Duration::from_secs(30), total_seen)
        .await
        .expect("the relay must drain its queue rather than deadlock")
        .unwrap();
    assert_eq!(total, BULK_TOTAL, "every byte must reach the target once");
    assert!(intact, "bytes must arrive unmodified");
}

#[ntex::test]
async fn a_bulk_download_arrives_complete() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let payload = vec![0xCDu8; BULK_TOTAL];
        let _ = socket.write_all(&payload).await;
        let _ = socket.shutdown().await;
    });

    let state = app_state(&addr, true).await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    let conn = srv
        .ws_at(&format!("/api/v1/tunnel/ws?ticket={ticket}"))
        .await
        .unwrap();
    let (io, codec, _) = conn.into_inner();

    let mut received = 0usize;
    loop {
        match io.recv(&codec).await.unwrap() {
            Some(ws::Frame::Binary(data)) => {
                assert!(data.iter().all(|&b| b == 0xCD), "bytes must arrive unmodified");
                received += data.len();
            }
            Some(ws::Frame::Close(_)) | None => break,
            Some(_) => continue,
        }
    }
    assert_eq!(received, BULK_TOTAL, "every byte must reach the client once");
}
