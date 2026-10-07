//! End-to-end coverage for `GET /api/v1/terminal/ws`.
//!
//! The admission rules, the control protocol and the session machinery
//! (replay, takeover, the cap, the reaper) are exercised against the real app
//! and a real shell on a local PTY — the only kind of shell there is.

mod common;

use std::sync::{Arc, Once};
use std::time::Duration;

use ntex::io::{Io, Sealed};
use ntex::service::cfg::SharedCfg;
use ntex::time::timeout;
use ntex::time::Seconds;
use ntex::util::ByteString;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use ntex::ws::error::WsClientError;
use ntex::ws::{self, WsClient, WsConnection};
use rustls::crypto::ring;
use server_box_monitor::api::authz::revoke_lost;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::ws::terminal::terminal_ws;
use server_box_monitor::api::ws::ticket::Purpose;
use server_box_monitor::core::config::Config;
use server_box_monitor::core::remote_access::RemoteAccessConfig;

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// A state whose admin role holds `shell` or not ([shell]), with [tune]
/// applied to the remote-access section first (a cap, a scrollback, a grace).
async fn state_with(shell: bool, tune: impl FnOnce(&mut RemoteAccessConfig)) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some("test-secret-that-is-long-enough-32ch".to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // The switches an upgraded agent had; `seed_as_upgrade` turns them into
    // the admin role's grants (`shell` needs both).
    remote.terminal.enabled = Some(true);
    remote.full_access = Some(shell);
    tune(&mut remote);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    common::seed_as_upgrade(&db, &config).await;
    AppState::new(Arc::new(config), db)
}

/// An account that holds `shell`.
async fn app_state() -> Arc<AppState> {
    state_with(true, |_| {}).await
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new()
                .state(state)
                .service(web::scope("/api/v1").route("/terminal/ws", web::get().to(terminal_ws)))
        }
    })
    .await
}

/// Reads frames until a Text one arrives, and returns it parsed.
///
/// Skips the heartbeat and any binary the session might have produced, so a
/// test can assert on the reply it cares about without racing the pumps.
async fn next_control(io: &Io<Sealed>, codec: &ws::Codec) -> serde_json::Value {
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
    let conn = terminal_connection(srv, ticket)
        .await
        .expect("upgrade should succeed");
    let (io, codec, _) = conn.into_inner();
    (io, codec)
}

async fn terminal_connection(
    srv: &TestServer,
    ticket: &str,
) -> Result<WsConnection<Sealed>, WsClientError> {
    WsClient::builder(srv.url("/api/v1/terminal/ws"))
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

#[ntex::test]
async fn an_account_without_shell_is_refused_even_with_a_valid_ticket() {
    let state = state_with(false, |_| {}).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(terminal_connection(&srv, &ticket).await.is_err());
}

#[ntex::test]
async fn a_missing_or_forged_ticket_is_refused() {
    let state = app_state().await;
    let srv = test_server(state).await;

    assert!(srv.ws_at("/api/v1/terminal/ws").await.is_err());
    assert!(terminal_connection(&srv, "dead.beef").await.is_err());
}

#[ntex::test]
async fn a_ticket_works_only_once() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(terminal_connection(&srv, &ticket).await.is_ok());
    assert!(terminal_connection(&srv, &ticket).await.is_err());
}

#[ntex::test]
async fn a_failed_upgrade_does_not_burn_the_ticket() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let response = srv.get("/api/v1/terminal/ws").send().await.unwrap();
    assert!(!response.status().is_success());
    assert!(terminal_connection(&srv, &ticket).await.is_ok());
}

#[ntex::test]
async fn a_plaintext_listener_still_serves_a_loopback_client() {
    // The test client connects over loopback, which counts as secure even
    // without TLS — that is the reverse-proxy case, and it must keep working
    let state = app_state().await;
    assert!(!state.tls_active);
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    assert!(terminal_connection(&srv, &ticket).await.is_ok());
}

#[ntex::test]
async fn an_unparseable_control_message_is_reported_not_ignored() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static("{\"type\":\"nope\"}")),
        &codec,
    )
    .await
    .unwrap();

    assert_eq!(next_control(&io, &codec).await["code"], "bad_request");
}

/// The SSH logins this endpoint once offered are refused at the frame, never
/// opened as the agent's own user instead: with a target or without.
#[ntex::test]
async fn an_open_with_an_ssh_credential_is_refused() {
    let state = app_state().await;
    let sessions = state.sessions.clone();
    let tickets = state.tickets.clone();
    let srv = test_server(state).await;

    for open in [
        r#"{"type":"open","user":"ops","auth":{"kind":"password","password":"x"}}"#,
        r#"{"type":"open","user":"ops","auth":{"kind":"key","pem":"-----","passphrase":null}}"#,
        r#"{"type":"open","user":"ops","auth":{"kind":"interactive"}}"#,
        r#"{"type":"open","user":"ops","auth":{"kind":"password","password":"x"},"target":{"kind":"container","id":"abc"}}"#,
        r#"{"type":"answer","answers":["x"]}"#,
    ] {
        let ticket = tickets.issue(Purpose::Terminal, "admin").unwrap();
        let (io, codec) = open_terminal(&srv, &ticket).await;
        io.send(ws::Message::Text(ByteString::from(open)), &codec)
            .await
            .unwrap();
        assert_eq!(next_control(&io, &codec).await["code"], "bad_request", "{open}");
    }
    assert!(sessions.is_empty(), "nothing should have been opened");
}

#[ntex::test]
async fn attaching_to_an_unknown_session_says_it_is_gone() {
    let state = app_state().await;
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
async fn a_ping_is_answered() {
    let state = app_state().await;
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

/// Opens a shell and returns the connection plus the session handle from
/// `ready`, once the shell has run a command (so its start-up output is
/// behind it).
async fn open_shell(srv: &TestServer, ticket: &str) -> (Io<Sealed>, ws::Codec, String) {
    let (io, codec) = open_terminal(srv, ticket).await;
    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let ready = next_control(&io, &codec).await;
    assert_eq!(ready["type"], "ready", "expected a shell, got {ready}");
    let handle = ready["session"].as_str().unwrap().to_string();
    answer_cursor_position_query(&io, &codec).await;
    (io, codec, handle)
}

/// Runs `echo` with [tag] split by quoting, so that only the command's output
/// (`<tag>-42`), not the echo of what was typed, matches; answers what was
/// read up to it.
async fn run_marker(io: &Io<Sealed>, codec: &ws::Codec, tag: &str) -> Vec<u8> {
    // `''` joins in sh, bash, zsh and fish; `^` escapes in cmd.
    let command = if cfg!(windows) {
        format!("echo {tag}-4^2\r")
    } else {
        format!("echo {tag}-4''2\r")
    };
    io.send(ws::Message::Binary(ntex::util::Bytes::from(command)), codec)
        .await
        .unwrap();
    let marker = format!("{tag}-42");
    let seen = read_until(io, codec, marker.as_bytes()).await;
    assert!(
        seen.windows(marker.len()).any(|w| w == marker.as_bytes()),
        "the shell should run what it is sent; saw {:?}",
        String::from_utf8_lossy(&seen)
    );
    seen
}

/// Collects binary frames until `needle` shows up, or gives up.
///
/// Answers a primary device-attributes query on the way: some shells (fish)
/// send one at start-up and wait for the reply before reading input, as a real
/// terminal would give it.
async fn read_until(io: &Io<Sealed>, codec: &ws::Codec, needle: &[u8]) -> Vec<u8> {
    const DA1: [&[u8]; 2] = [b"\x1b[c", b"\x1b[0c"];
    let mut seen = Vec::new();
    let mut answered = 0;
    while seen.windows(needle.len()).all(|w| w != needle) {
        let Ok(Ok(Some(frame))) = timeout(Duration::from_secs(5), io.recv(codec)).await else {
            break;
        };
        if let ws::Frame::Binary(data) = frame {
            seen.extend_from_slice(&data);
            let asked = DA1
                .iter()
                .map(|q| seen.windows(q.len()).filter(|w| w == q).count())
                .sum::<usize>();
            while answered < asked {
                answered += 1;
                io.send(
                    ws::Message::Binary(ntex::util::Bytes::from_static(b"\x1b[?62;22c")),
                    codec,
                )
                .await
                .unwrap();
            }
        }
    }
    seen
}

#[cfg(windows)]
async fn answer_cursor_position_query(io: &Io<Sealed>, codec: &ws::Codec) {
    let query = b"\x1b[6n";
    let seen = read_until(io, codec, query).await;
    assert!(
        seen.windows(query.len()).any(|window| window == query),
        "ConPTY should ask for the cursor position; saw {seen:?}"
    );
    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(b"\x1b[1;1R")),
        codec,
    )
    .await
    .unwrap();
}

#[cfg(not(windows))]
async fn answer_cursor_position_query(_io: &Io<Sealed>, _codec: &ws::Codec) {}

#[ntex::test]
async fn an_open_starts_a_working_shell() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &ticket).await;
    assert!(handle.contains('.'), "the handle must carry its secret");
    run_marker(&io, &codec, "works").await;
}

/// A paste bigger than ntex's default 64 KiB frame limit arrives as one
/// frame: the shell gets all of it, and the connection stays up.
#[cfg(unix)]
#[ntex::test]
async fn a_paste_bigger_than_64_kib_reaches_the_shell() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec, _) = open_shell(&srv, &ticket).await;
    run_marker(&io, &codec, "start").await;

    // Raw and silent, so the bytes reach `head` exactly; `wc` counts them. The
    // `count-` prefix is added by `sed`, so the echo of the command line
    // cannot match it.
    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(
            b"stty raw -echo; echo go-4''2; head -c 204800 | wc -c | sed 's/ //g; s/^/count-/'; stty sane\r",
        )),
        &codec,
    )
    .await
    .unwrap();
    // Sent once `head` is about to read, not into the line editor.
    read_until(&io, &codec, b"go-42").await;
    io.send(
        ws::Message::Binary(ntex::util::Bytes::from(vec![b'a'; 200 << 10])),
        &codec,
    )
    .await
    .unwrap();
    let count = b"count-204800";
    let seen = read_until(&io, &codec, count).await;
    assert!(
        seen.windows(count.len()).any(|w| w == count),
        "the whole paste should reach the shell; saw {:?}",
        String::from_utf8_lossy(&seen)
    );
}

#[ntex::test]
async fn concurrent_open_frames_create_only_one_session() {
    let state = app_state().await;
    let sessions = state.sessions.clone();
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;
    let open = r#"{"type":"open","auth":{"kind":"local"}}"#;

    io.send(ws::Message::Text(ByteString::from_static(open)), &codec)
        .await
        .unwrap();
    io.send(ws::Message::Text(ByteString::from_static(open)), &codec)
        .await
        .unwrap();

    let replies = [
        next_control(&io, &codec).await,
        next_control(&io, &codec).await,
    ];
    assert_eq!(
        replies
            .iter()
            .filter(|reply| reply["type"] == "ready")
            .count(),
        1
    );
    assert_eq!(
        replies
            .iter()
            .filter(|reply| reply["code"] == "bad_request")
            .count(),
        1
    );
    assert_eq!(sessions.len(), 1);
}

#[ntex::test]
async fn a_reconnect_replays_only_what_was_missed() {
    let state = app_state().await;
    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let sessions = state.sessions.clone();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    let seen = run_marker(&io, &codec, "before").await;
    let rendered = seen.len() as u64;
    let session = sessions.get(&handle, "admin").unwrap();

    // Produce output the first connection will not see: typed, so the line
    // editor echoes it.
    const MISSED: &[u8] = b"missedwhileaway";
    io.send(
        ws::Message::Binary(ntex::util::Bytes::from_static(MISSED)),
        &codec,
    )
    .await
    .unwrap();
    for _ in 0..100 {
        let received =
            session.scrollback.lock().unwrap().next_seq() >= rendered + MISSED.len() as u64;
        if received {
            break;
        }
        ntex::time::sleep(Duration::from_millis(10)).await;
    }
    assert!(
        session.scrollback.lock().unwrap().next_seq() >= rendered + MISSED.len() as u64,
        "the echo must reach scrollback before the connection is dropped"
    );
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

    let replayed = read_until(&io2, &codec2, MISSED).await;
    assert!(
        replayed.windows(MISSED.len()).any(|w| w == MISSED),
        "output produced while disconnected must be replayed"
    );
    assert!(
        !replayed.starts_with(b"\x1bc"),
        "a recoverable gap must not clear the screen"
    );
    assert!(
        replayed.windows(9).all(|w| w != b"before-42"),
        "already-rendered output must not be sent twice"
    );
}

#[ntex::test]
async fn a_superseded_connection_is_told_rather_than_left_silent() {
    let state = app_state().await;
    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    run_marker(&io, &codec, "ready").await;

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
    let state = app_state().await;
    let tickets = state.tickets.clone();
    let first = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    run_marker(&io, &codec, "ready").await;

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
        ws::Message::Binary(ntex::util::Bytes::from_static(b"afterreattach")),
        &codec2,
    )
    .await
    .unwrap();
    let echoed = read_until(&io2, &codec2, b"afterreattach").await;
    assert!(
        echoed.windows(13).any(|w| w == b"afterreattach"),
        "the reattached connection must keep receiving output"
    );
}

#[ntex::test]
async fn another_account_cannot_take_over_a_session() {
    let state = app_state().await;
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
    let state = app_state().await;
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
    let state = state_with(true, |remote| remote.terminal.max_sessions = Some(1)).await;
    let first = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (_io, _codec, _handle) = open_shell(&srv, &first).await;

    let (io2, codec2) = open_terminal(&srv, &second).await;
    io2.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"}}"#,
        )),
        &codec2,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io2, &codec2).await["code"], "at_capacity");
}

/// The same grant the container page needs, re-checked at the frame.
#[ntex::test]
async fn a_container_target_needs_the_shell_grant() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    // Taken after the upgrade: without it the upgrade itself is refused.
    let (io, codec) = open_terminal(&srv, &ticket).await;
    take_shell(&state).await;
    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"container","id":"abc"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    assert_eq!(next_control(&io, &codec).await["code"], "forbidden");
}

/// An id the runtime would read as an option is refused before the runtime is
/// even probed, let alone a shell spawned.
#[ntex::test]
async fn an_invalid_container_id_is_refused_before_anything_spawns() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"container","id":"-x"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let frame = next_control(&io, &codec).await;
    assert_eq!(frame["code"], "bad_request", "{frame}");
    assert!(state.sessions.is_empty(), "nothing should have been registered");
}

/// A trailing newline in an id is refused too: `trim` would have hidden it,
/// and it is the untrimmed value that reaches the command.
#[ntex::test]
async fn a_container_id_with_a_control_character_is_refused() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"container","id":"abc\n"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let frame = next_control(&io, &codec).await;
    assert_eq!(frame["code"], "bad_request", "{frame}");
    assert!(state.sessions.is_empty(), "nothing should have been registered");
}

/// An iperf host with a shell metacharacter is refused before the runtime is
/// reached, with the issue the panel phrases.
#[ntex::test]
async fn an_invalid_iperf_host_is_refused_before_anything_spawns() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"iperf","host":"host;echo","port":5201}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let frame = next_control(&io, &codec).await;
    assert_eq!(frame["code"], "invalid_input", "{frame}");
    assert_eq!(frame["issue"], "invalid_host", "{frame}");
    assert!(state.sessions.is_empty(), "nothing should have been registered");
}

/// A port out of `1..=65535` is refused too.
#[ntex::test]
async fn an_iperf_port_out_of_range_is_refused_before_anything_spawns() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"iperf","host":"example.com","port":0}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let frame = next_control(&io, &codec).await;
    assert_eq!(frame["code"], "invalid_input", "{frame}");
    assert_eq!(frame["issue"], "invalid_port", "{frame}");
    assert!(state.sessions.is_empty(), "nothing should have been registered");
}

/// A tmux session id that is not `$` and digits is refused before tmux is even
/// looked for, with the issue the panel phrases.
#[ntex::test]
async fn an_invalid_tmux_session_id_is_refused_before_anything_spawns() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"tmux","session":"$3;rm"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let frame = next_control(&io, &codec).await;
    assert_eq!(frame["code"], "invalid_input", "{frame}");
    assert_eq!(frame["issue"], "invalid_session_id", "{frame}");
    assert!(state.sessions.is_empty(), "nothing should have been registered");
}

/// A new session's name is checked too, and the refusal names which rule it
/// broke: `:` is tmux's own session/window separator.
#[ntex::test]
async fn an_invalid_tmux_new_name_is_refused_before_anything_spawns() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"},"target":{"kind":"tmux_new","name":"a:b"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    let frame = next_control(&io, &codec).await;
    assert_eq!(frame["code"], "invalid_input", "{frame}");
    assert_eq!(frame["issue"], "name_separator", "{frame}");
    assert!(state.sessions.is_empty(), "nothing should have been registered");
}

/// Takes `shell` away from the admin role, as an admin editing it would.
async fn take_shell(state: &AppState) {
    let mut grants = common::grants_of(&state.db, "admin").await;
    grants.shell = false;
    common::set_grants(&state.db, "admin", &grants).await;
}

#[ntex::test]
async fn taking_shell_away_applies_without_a_restart() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;

    // Between the upgrade and the frame, as an admin editing the role would.
    let (io, codec) = open_terminal(&srv, &ticket).await;
    take_shell(&state).await;
    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();

    assert_eq!(
        next_control(&io, &codec).await["code"],
        "forbidden",
        "the role must bind the running process, not just what was read at startup"
    );
}

#[ntex::test]
async fn taking_shell_away_closes_an_existing_local_shell() {
    let state = app_state().await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state.clone()).await;
    let (io, codec) = open_terminal(&srv, &ticket).await;

    io.send(
        ws::Message::Text(ByteString::from_static(
            r#"{"type":"open","auth":{"kind":"local"}}"#,
        )),
        &codec,
    )
    .await
    .unwrap();
    assert_eq!(next_control(&io, &codec).await["type"], "ready");

    take_shell(&state).await;
    revoke_lost(&state, "permission_revoked").await;
    assert_eq!(
        next_control(&io, &codec).await["code"],
        "permission_revoked"
    );
    assert!(state.sessions.is_empty());
}

#[ntex::test]
async fn an_outage_longer_than_the_buffer_reports_and_replays() {
    // A scrollback small enough that a single command's output overruns it,
    // which is the only way to reach the truncated path end to end
    let state = state_with(true, |remote| remote.terminal.scrollback_bytes = Some(256)).await;
    let tickets = state.tickets.clone();
    let first = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let second = tickets.issue(Purpose::Terminal, "admin").unwrap();
    let srv = test_server(state).await;

    let (io, codec, handle) = open_shell(&srv, &first).await;
    run_marker(&io, &codec, "ready").await;

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
    io2.send(
        ws::Message::Binary(ntex::util::Bytes::from(filler)),
        &codec2,
    )
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
    let mut saw_replay = false;
    for _ in 0..6 {
        match timeout(Duration::from_secs(5), io3.recv(&codec3)).await {
            Ok(Ok(Some(ws::Frame::Text(data)))) => {
                let v: serde_json::Value = serde_json::from_slice(&data).unwrap();
                if v["code"] == "gap_truncated" {
                    saw_truncated = true;
                }
            }
            Ok(Ok(Some(ws::Frame::Binary(data)))) => {
                assert!(
                    saw_truncated,
                    "the client must reset before rendering the truncated replay"
                );
                assert!(
                    !data.starts_with(b"\x1bc"),
                    "the frontend owns the reset so replay bytes stay unchanged"
                );
                saw_replay = true;
            }
            _ => break,
        }
        if saw_truncated && saw_replay {
            break;
        }
    }
    assert!(
        saw_truncated,
        "the client must be told that output was lost"
    );
    assert!(
        saw_replay,
        "the surviving scrollback must still be replayed"
    );
}

#[ntex::test]
async fn a_session_nobody_comes_back_for_is_reaped() {
    // One second of grace, so the reaper's own interval (a quarter of it,
    // floored at ten seconds elsewhere) isn't what the test waits on
    let state = state_with(true, |remote| remote.terminal.detached_timeout_secs = 1).await;
    let ticket = state.tickets.issue(Purpose::Terminal, "admin").unwrap();
    let sessions = state.sessions.clone();
    let srv = test_server(state).await;

    let (io, codec, _handle) = open_shell(&srv, &ticket).await;
    run_marker(&io, &codec, "ready").await;
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
