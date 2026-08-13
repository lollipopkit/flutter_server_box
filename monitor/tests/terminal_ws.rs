//! End-to-end coverage for `GET /api/v1/terminal/ws`.
//!
//! The admission rules and the control protocol are exercised against the real
//! app; the SSH half is not, because standing up an sshd is not something a
//! unit test should do. `ssh_session_reaches_a_real_sshd` fills that gap and is
//! opt-in, following the same convention as `sbm_parser`'s `ssh_e2e`.

use std::sync::{Arc, Once};
use std::time::Duration;

use ntex::time::timeout;
use ntex::util::ByteString;
use ntex::web::test::{self as web_test, TestServer};
use ntex::io::{Io, Sealed};
use ntex::web::{self, App};
use ntex::ws;
use rustls::crypto::ring;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::terminal::terminal_ws;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::core::config::Config;

mod fake_sshd;

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// `terminal_enabled` defaults on because most tests want to reach the
/// protocol; `ssh_addr` points nowhere by default, since the tests that get
/// that far assert on the failure rather than on a shell.
async fn app_state(enabled: bool, ssh_addr: &str) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some("test-secret-that-is-long-enough-32ch".to_string());
    let mut remote = config.get_remote_access();
    remote.terminal_enabled = enabled;
    remote.ssh_addr = ssh_addr.to_string();
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
                web::scope("/api/v1").route("/terminal/ws", web::get().to(terminal_ws)),
            )
        }
    })
    .await
}

/// A port nothing is listening on, so `open` fails at connect.
fn dead_addr() -> String {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap().to_string();
    drop(listener);
    addr
}

/// Reads frames until a Text one arrives, and returns it parsed.
///
/// Skips the heartbeat and any binary the session might have produced, so a
/// test can assert on the reply it cares about without racing the pumps.
async fn next_control(
    io: &Io<Sealed>,
    codec: &ws::Codec,
) -> serde_json::Value {
    loop {
        let frame = timeout(Duration::from_secs(5), io.recv(codec))
            .await
            .expect("a control frame should arrive")
            .unwrap()
            .expect("the connection should stay open");
        if let ws::Frame::Text(data) = frame {
            let value: serde_json::Value = serde_json::from_slice(&data).unwrap();
            if value["type"] == "hb" {
                continue;
            }
            return value;
        }
    }
}

async fn open_terminal(srv: &TestServer, ticket: &str) -> (Io<Sealed>, ws::Codec) {
    let conn = srv
        .ws_at(&format!("/api/v1/terminal/ws?ticket={ticket}"))
        .await
        .expect("upgrade should succeed");
    let (io, codec, _) = conn.into_inner();
    (io, codec)
}

#[ntex::test]
async fn a_disabled_terminal_refuses_even_a_valid_ticket() {
    let state = app_state(false, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(
        srv.ws_at(&format!("/api/v1/terminal/ws?ticket={ticket}"))
            .await
            .is_err()
    );
}

#[ntex::test]
async fn a_tunnel_ticket_cannot_open_a_terminal() {
    let state = app_state(true, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Tunnel, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(
        srv.ws_at(&format!("/api/v1/terminal/ws?ticket={ticket}"))
            .await
            .is_err()
    );
}

#[ntex::test]
async fn a_missing_or_forged_ticket_is_refused() {
    let state = app_state(true, "127.0.0.1:22").await;
    let srv = test_server(state).await;

    assert!(srv.ws_at("/api/v1/terminal/ws").await.is_err());
    assert!(
        srv.ws_at("/api/v1/terminal/ws?ticket=dead.beef")
            .await
            .is_err()
    );
}

#[ntex::test]
async fn a_ticket_works_only_once() {
    let state = app_state(true, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let path = format!("/api/v1/terminal/ws?ticket={ticket}");
    assert!(srv.ws_at(&path).await.is_ok());
    assert!(srv.ws_at(&path).await.is_err());
}

#[ntex::test]
async fn a_plaintext_listener_still_serves_a_loopback_client() {
    // The test client connects over loopback, which counts as secure even
    // without TLS — that is the reverse-proxy case, and it must keep working
    let state = app_state(true, "127.0.0.1:22").await;
    assert!(!state.tls_active);
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(
        srv.ws_at(&format!("/api/v1/terminal/ws?ticket={ticket}"))
            .await
            .is_ok()
    );
}

#[ntex::test]
async fn an_unparseable_control_message_is_reported_not_ignored() {
    let state = app_state(true, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(ws::Message::Text(ByteString::from_static("{\"type\":\"nope\"}")), &codec)
        .await
        .unwrap();

    assert_eq!(next_control(&io, &codec).await["code"], "bad_request");
}

#[ntex::test]
async fn an_unreachable_sshd_is_reported_as_a_connect_failure() {
    let state = app_state(true, &dead_addr()).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from(
            r#"{"type":"open","user":"ops","auth":{"kind":"password","password":"x"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let reply = next_control(&io, &codec).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(reply["code"], "connect_failed");
}

#[ntex::test]
async fn attaching_to_an_unknown_session_says_it_is_gone() {
    let state = app_state(true, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from(
            r#"{"type":"attach","session":"dead.beef","since":0}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let reply = next_control(&io, &codec).await;
    assert_eq!(reply["type"], "error");
    assert_eq!(
        reply["code"], "session_gone",
        "unknown, wrong-owner and wrong-secret must be indistinguishable"
    );
}

#[ntex::test]
async fn answering_without_a_prompt_is_refused() {
    let state = app_state(true, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from(r#"{"type":"answer","answers":["x"]}"#)),
        &codec,
    )
    .await
    .unwrap();

    assert_eq!(next_control(&io, &codec).await["code"], "bad_request");
}

#[ntex::test]
async fn a_ping_is_answered() {
    let state = app_state(true, "127.0.0.1:22").await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Ping(ntex::util::Bytes::from_static(b"ka")),
        &codec,
    )
    .await
    .unwrap();

    let frame = timeout(Duration::from_secs(5), io.recv(&codec))
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    assert_eq!(
        frame,
        ws::Frame::Pong(ntex::util::Bytes::from_static(b"ka"))
    );
}

/// Opens a shell against the in-process fake sshd and returns the connection
/// plus the session handle from `ready`.
async fn open_shell(
    srv: &TestServer,
    ticket: &str,
) -> (Io<Sealed>, ws::Codec, String) {
    let (io, codec) = open_terminal(srv, ticket).await;
    let open = serde_json::json!({
        "type": "open",
        "user": fake_sshd::USER,
        "auth": {"kind": "password", "password": fake_sshd::PASSWORD},
    });
    io.send(ws::Message::Text(ByteString::from(open.to_string())), &codec)
        .await
        .unwrap();

    let ready = next_control(&io, &codec).await;
    assert_eq!(ready["type"], "ready", "expected a shell, got {ready}");
    let handle = ready["session"].as_str().unwrap().to_string();
    (io, codec, handle)
}

/// Collects binary frames until `needle` shows up, or gives up.
async fn read_until(io: &Io<Sealed>, codec: &ws::Codec, needle: &[u8]) -> Vec<u8> {
    let mut seen = Vec::new();
    while seen.windows(needle.len()).all(|w| w != needle) {
        let Ok(Ok(Some(frame))) = timeout(Duration::from_secs(5), io.recv(codec)).await else {
            break;
        };
        if let ws::Frame::Binary(data) = frame {
            seen.extend_from_slice(&data);
        }
    }
    seen
}

#[ntex::test]
async fn a_password_login_produces_a_working_shell() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &ticket).await;
    assert!(handle.contains('.'), "the handle must carry its secret");

    let banner = read_until(&io, &codec, fake_sshd::BANNER).await;
    assert!(
        banner.windows(fake_sshd::BANNER.len()).any(|w| w == fake_sshd::BANNER),
        "the shell's own output should reach the browser"
    );

    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(b"echo hi\n")),
        &codec,
    )
    .await
    .unwrap();
    let echoed = read_until(&io, &codec, b"echo hi").await;
    assert!(
        echoed.windows(7).any(|w| w == b"echo hi"),
        "keystrokes should reach the shell and come back"
    );
}

#[ntex::test]
async fn a_wrong_password_is_reported_as_an_auth_failure() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    let open = serde_json::json!({
        "type": "open",
        "user": fake_sshd::USER,
        "auth": {"kind": "password", "password": "wrong"},
    });
    io.send(ws::Message::Text(ByteString::from(open.to_string())), &codec)
        .await
        .unwrap();

    let reply = next_control(&io, &codec).await;
    assert_eq!(reply["code"], "auth_failed");
    assert!(
        !reply["message"].as_str().unwrap().to_lowercase().contains("password"),
        "the message must not narrow the search for a guesser"
    );
}

#[ntex::test]
async fn a_second_factor_prompt_is_forwarded_and_answerable() {
    let sshd = fake_sshd::start(true).await;
    let state = app_state(true, &sshd).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    let open = serde_json::json!({
        "type": "open",
        "user": fake_sshd::USER,
        "auth": {"kind": "interactive"},
    });
    io.send(ws::Message::Text(ByteString::from(open.to_string())), &codec)
        .await
        .unwrap();

    let prompt = next_control(&io, &codec).await;
    assert_eq!(prompt["type"], "prompt");
    assert_eq!(prompt["prompts"][0]["prompt"], "Code: ");
    assert_eq!(
        prompt["prompts"][0]["echo"], false,
        "a code must not be echoed while typing"
    );

    let answer = serde_json::json!({"type": "answer", "answers": [fake_sshd::PASSWORD]});
    io.send(ws::Message::Text(ByteString::from(answer.to_string())), &codec)
        .await
        .unwrap();
    assert_eq!(next_control(&io, &codec).await["type"], "ready");
}

#[ntex::test]
async fn a_reconnect_replays_only_what_was_missed() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    let seen = read_until(&io, &codec, fake_sshd::BANNER).await;
    let rendered = seen.len() as u64;

    // Produce output the first connection will not see
    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(b"missed-while-away")),
        &codec,
    )
    .await
    .unwrap();
    // Drop the connection without a close frame, like a network drop
    drop(io);
    ntex::time::sleep(Duration::from_millis(200)).await;

    let (io2, codec2) = open_terminal(&srv, &second).await;
    let attach = serde_json::json!({
        "type": "attach",
        "session": handle,
        "since": rendered,
    });
    io2.send(
        ws::Message::Text(ByteString::from(attach.to_string())),
        &codec2,
    )
    .await
    .unwrap();

    let replayed = read_until(&io2, &codec2, b"missed-while-away").await;
    assert!(
        replayed.windows(17).any(|w| w == b"missed-while-away"),
        "output produced while disconnected must be replayed"
    );
    assert!(
        !replayed.starts_with(b"\x1bc"),
        "a recoverable gap must not clear the screen"
    );
    assert!(
        replayed.windows(fake_sshd::BANNER.len()).all(|w| w != fake_sshd::BANNER),
        "already-rendered output must not be sent twice"
    );
}

#[ntex::test]
async fn a_superseded_connection_is_told_rather_than_left_silent() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    read_until(&io, &codec, fake_sshd::BANNER).await;

    // Duplicating a tab copies sessionStorage, so two tabs can genuinely hold
    // the same handle. The one that loses must find out: a connection that
    // stays open, keeps its heartbeat and silently receives nothing would
    // look healthy and, once its own heartbeat lapsed, take the session back.
    let (io2, codec2) = open_terminal(&srv, &second).await;
    io2.send(
        ws::Message::Text(ByteString::from(
            serde_json::json!({"type":"attach","session":handle,"since":0}).to_string(),
        )),
        &codec2,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io2, &codec2).await["type"], "ready");

    let reply = next_control(&io, &codec).await;
    assert_eq!(
        reply["code"], "superseded",
        "the losing connection must be told, not just starved"
    );
}

#[ntex::test]
async fn reattaching_before_the_old_socket_is_noticed_still_works() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let tickets = state.tickets.clone();
    let first = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    read_until(&io, &codec, fake_sshd::BANNER).await;

    // Reattach immediately, without giving the agent time to process the old
    // socket's death. This is the ordinary case, not a corner one: a phone
    // that changed networks reconnects long before the old TCP connection is
    // known to be gone, and the stale disconnect handler must not then tear
    // down the connection that replaced it.
    drop(io);
    let (io2, codec2) = open_terminal(&srv, &second).await;
    io2.send(
        ws::Message::Text(ByteString::from(
            serde_json::json!({"type":"attach","session":handle,"since":0}).to_string(),
        )),
        &codec2,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io2, &codec2).await["type"], "ready");

    io2.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(b"after-reattach")),
        &codec2,
    )
    .await
    .unwrap();
    let echoed = read_until(&io2, &codec2, b"after-reattach").await;
    assert!(
        echoed.windows(14).any(|w| w == b"after-reattach"),
        "the reattached connection must keep receiving output"
    );
}

#[ntex::test]
async fn another_account_cannot_take_over_a_session() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let mine = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let theirs = state.tickets.issue(Purpose::Terminal, "intruder").unwrap();
    let srv = test_server(state).await;

    let (_io, _codec, handle) = open_shell(&srv, &mine).await;

    let (io2, codec2) = open_terminal(&srv, &theirs).await;
    let attach = serde_json::json!({"type": "attach", "session": handle, "since": 0});
    io2.send(
        ws::Message::Text(ByteString::from(attach.to_string())),
        &codec2,
    )
    .await
    .unwrap();

    assert_eq!(next_control(&io2, &codec2).await["code"], "session_gone");
}

#[ntex::test]
async fn closing_explicitly_ends_the_session_for_good() {
    let sshd = fake_sshd::start(false).await;
    let state = app_state(true, &sshd).await;
    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    io.send(
        ws::Message::Text(ByteString::from_static(r#"{"type":"close"}"#)),
        &codec,
    )
    .await
    .unwrap();
    ntex::time::sleep(Duration::from_millis(200)).await;

    // Unlike a dropped connection, this must not leave a session to rejoin
    let (io2, codec2) = open_terminal(&srv, &second).await;
    let attach = serde_json::json!({"type": "attach", "session": handle, "since": 0});
    io2.send(
        ws::Message::Text(ByteString::from(attach.to_string())),
        &codec2,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io2, &codec2).await["code"], "session_gone");
}

#[ntex::test]
async fn the_session_cap_refuses_the_extra_terminal() {
    let sshd = fake_sshd::start(false).await;
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some("test-secret-that-is-long-enough-32ch".to_string());
    let mut remote = config.get_remote_access();
    remote.terminal_enabled = true;
    remote.ssh_addr = sshd.clone();
    remote.terminal_max_sessions = Some(1);
    config.remote_access = Some(remote);
    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    let state = AppState::new(Arc::new(config), db);

    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (_io, _codec, _handle) = open_shell(&srv, &first).await;

    let (io2, codec2) = open_terminal(&srv, &second).await;
    let open = serde_json::json!({
        "type": "open",
        "user": fake_sshd::USER,
        "auth": {"kind": "password", "password": fake_sshd::PASSWORD},
    });
    io2.send(
        ws::Message::Text(ByteString::from(open.to_string())),
        &codec2,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io2, &codec2).await["code"], "at_capacity");
}

/// A state with the access without SSH explicitly on or off.
async fn full_access_state(enabled: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some("test-secret-that-is-long-enough-32ch".to_string());
    let mut remote = config.get_remote_access();
    remote.terminal_enabled = true;
    // Nothing listens here: an SSH-less shell must not need it
    remote.ssh_addr = "127.0.0.1:1".to_string();
    remote.full_access = Some(enabled);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

#[ntex::test]
async fn a_full_access_open_starts_a_shell_without_any_credential() {
    let state = full_access_state(true).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","user":"","auth":{"kind":"local"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let ready = next_control(&io, &codec).await;
    assert_eq!(ready["type"], "ready", "expected a shell, got {ready}");

    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(b"echo full-access-ok
")),
        &codec,
    )
    .await
    .unwrap();
    let marker = b"full-access-ok";
    let seen = read_until(&io, &codec, marker).await;
    assert!(
        seen.windows(marker.len()).any(|w| w == marker),
        "the local shell must actually run what it is sent"
    );
}

#[ntex::test]
async fn a_full_access_open_is_refused_when_the_feature_is_off() {
    let state = full_access_state(false).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    // The panel hides the entry when it is off, but the UI is not the
    // boundary — a client can send this frame regardless
    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","user":"","auth":{"kind":"local"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    assert_eq!(
        next_control(&io, &codec).await["code"],
        "full_access_disabled"
    );
}

#[ntex::test]
async fn turning_it_off_from_the_panel_applies_without_a_restart() {
    let state = full_access_state(true).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;

    // What the first-run prompt does
    state
        .full_access_off
        .store(true, std::sync::atomic::Ordering::Release);

    let (io, codec) = open_terminal(&srv, &ticket).await;
    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","user":"","auth":{"kind":"local"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    assert_eq!(
        next_control(&io, &codec).await["code"],
        "full_access_disabled",
        "the switch must bind the running process, not just the config file"
    );
}

/// Builds a state with explicit capacity/timeout overrides, for the tests that
/// need a session to expire or a buffer to overflow inside a test's lifetime.
async fn tuned_state(
    ssh_addr: &str,
    scrollback: Option<usize>,
    detached_secs: u64,
) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some("test-secret-that-is-long-enough-32ch".to_string());
    let mut remote = config.get_remote_access();
    remote.terminal_enabled = true;
    remote.ssh_addr = ssh_addr.to_string();
    remote.terminal_scrollback_bytes = scrollback;
    remote.terminal_detached_timeout_secs = detached_secs;
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

#[ntex::test]
async fn an_outage_longer_than_the_buffer_resets_and_says_so() {
    // A scrollback small enough that a single command's output overruns it,
    // which is the only way to reach the truncated path end to end
    let sshd = fake_sshd::start(false).await;
    let state = tuned_state(&sshd, Some(256), 300).await;
    let tickets = state.tickets.clone();
    let first = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    read_until(&io, &codec, fake_sshd::BANNER).await;

    // Detach at position 0, then push far more than 256 bytes through, so the
    // client's resume point falls out of the buffer entirely
    drop(io);
    ntex::time::sleep(Duration::from_millis(200)).await;

    let (io2, codec2) = open_terminal(&srv, &second).await;
    io2.send(
        ws::Message::Text(ByteString::from(
            serde_json::json!({"type":"attach","session":handle,"since":0}).to_string(),
        )),
        &codec2,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io2, &codec2).await["type"], "ready");

    // Fill past the buffer from the reattached connection, then reattach once
    // more from a stale position
    let filler = vec![b'x'; 2048];
    io2.send(ws::Message::Binary(ntex::util::Bytes::from(filler)), &codec2)
        .await
        .unwrap();
    read_until(&io2, &codec2, b"xxxxxxxx").await;
    drop(io2);
    ntex::time::sleep(Duration::from_millis(200)).await;

    let third = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let (io3, codec3) = open_terminal(&srv, &third).await;
    io3.send(
        ws::Message::Text(ByteString::from(
            serde_json::json!({"type":"attach","session":handle,"since":0}).to_string(),
        )),
        &codec3,
    )
    .await
    .unwrap();

    let mut saw_truncated = false;
    let mut saw_reset = false;
    for _ in 0..6 {
        match timeout(Duration::from_secs(5), io3.recv(&codec3)).await {
            Ok(Ok(Some(ws::Frame::Text(data)))) => {
                let v: serde_json::Value = serde_json::from_slice(&data).unwrap();
                if v["code"] == "gap_truncated" {
                    saw_truncated = true;
                }
            }
            Ok(Ok(Some(ws::Frame::Binary(data)))) => {
                if data.starts_with(b"\x1bc") {
                    saw_reset = true;
                }
            }
            _ => break,
        }
        if saw_truncated && saw_reset {
            break;
        }
    }
    assert!(saw_reset, "a client whose position is gone must be reset");
    assert!(saw_truncated, "and told that output was lost");
}

#[ntex::test]
async fn a_session_nobody_comes_back_for_is_reaped() {
    let sshd = fake_sshd::start(false).await;
    // One second of grace, so the reaper's own interval (a quarter of it,
    // floored at ten seconds elsewhere) isn't what the test waits on
    let state = tuned_state(&sshd, None, 1).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let sessions = state.sessions.clone();
    let srv = test_server(state).await;

    let (io, codec, _handle) = open_shell(&srv, &ticket).await;
    read_until(&io, &codec, fake_sshd::BANNER).await;
    assert_eq!(sessions.len(), 1);

    drop(io);
    ntex::time::sleep(Duration::from_millis(1500)).await;
    assert_eq!(
        sessions.reap(),
        1,
        "a session detached past its grace period must be collected"
    );
    assert_eq!(sessions.len(), 0);
}

/// Opt-in: needs a reachable sshd and credentials that work against it.
///
/// The fake server in `fake_sshd` covers the protocol; this covers OpenSSH,
/// which is the thing that will actually be on the other end. Set one of:
///
/// ```sh
/// # key auth (also exercises decode_secret_key and RSA hash negotiation)
/// SBM_E2E_TERMINAL_ADDR=127.0.0.1:2222 \
/// SBM_E2E_TERMINAL_USER=me \
/// SBM_E2E_TERMINAL_KEY=/path/to/id_ed25519 \
/// cargo test -p server_box_monitor --test terminal_ws
///
/// # or password auth
/// SBM_E2E_TERMINAL_ADDR=127.0.0.1:22 \
/// SBM_E2E_TERMINAL_USER=me \
/// SBM_E2E_TERMINAL_PASSWORD=... \
/// cargo test -p server_box_monitor --test terminal_ws
/// ```
///
/// Credentials come from the environment and are never written to the repo.
/// Silently skipped when unset, like `sbm_parser`'s SSH end-to-end tests.
#[ntex::test]
async fn a_real_sshd_produces_a_working_shell() {
    let (Ok(addr), Ok(user)) = (
        std::env::var("SBM_E2E_TERMINAL_ADDR"),
        std::env::var("SBM_E2E_TERMINAL_USER"),
    ) else {
        eprintln!("SBM_E2E_TERMINAL_* unset; skipping the real-sshd terminal test");
        return;
    };
    let auth = match (
        std::env::var("SBM_E2E_TERMINAL_KEY"),
        std::env::var("SBM_E2E_TERMINAL_PASSWORD"),
    ) {
        (Ok(path), _) => serde_json::json!({
            "kind": "key",
            "pem": std::fs::read_to_string(&path).expect("readable private key"),
            "passphrase": std::env::var("SBM_E2E_TERMINAL_PASSPHRASE").ok(),
        }),
        (_, Ok(password)) => serde_json::json!({"kind": "password", "password": password}),
        _ => {
            eprintln!("neither SBM_E2E_TERMINAL_KEY nor _PASSWORD set; skipping");
            return;
        }
    };

    let state = app_state(true, &addr).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    let open = serde_json::json!({
        "type": "open",
        "user": user,
        "auth": auth,
        "cols": 80,
        "rows": 24,
    });
    io.send(
        ws::Message::Text(ByteString::from(open.to_string())),
        &codec,
    )
    .await
    .unwrap();

    let ready = next_control(&io, &codec).await;
    assert_eq!(ready["type"], "ready", "expected a shell, got {ready}");
    assert!(
        ready["session"].as_str().is_some_and(|s| s.contains('.')),
        "ready must carry the handle used to reattach"
    );

    // Prove the PTY is live in both directions
    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(b"echo sbm-e2e-marker\n")),
        &codec,
    )
    .await
    .unwrap();

    let mut seen = Vec::new();
    let found = loop {
        let Ok(Ok(Some(frame))) = timeout(Duration::from_secs(15), io.recv(&codec)).await else {
            break false;
        };
        if let ws::Frame::Binary(data) = frame {
            seen.extend_from_slice(&data);
            // The echoed command appears first, then its output — two
            // occurrences means the shell actually ran it
            if String::from_utf8_lossy(&seen).matches("sbm-e2e-marker").count() >= 2 {
                break true;
            }
        }
    };
    assert!(
        found,
        "the shell should echo the command and its output; saw {:?}",
        String::from_utf8_lossy(&seen)
    );
}

