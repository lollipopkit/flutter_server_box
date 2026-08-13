//! End-to-end coverage for `POST /api/v1/exec`.
//!
//! The endpoint runs whatever it is given, so what these assert is mostly the
//! refusals: no token, and the grant switched off. The happy path is checked
//! against real commands, since an exec endpoint that reports someone else's
//! output would be worse than one that reports none.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use rustls::crypto::ring;
use serde_json::json;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// The test client speaks TLS whether or not this server does, and rustls
/// refuses to pick a provider for itself.
fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn app_state(full_access: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some(SECRET.to_string());
    let mut remote = config.get_remote_access();
    // The grant is gated on the terminal being available, so that switching
    // the terminal off cannot leave this door open behind it. The test server
    // listens on loopback, which counts as a secure transport.
    remote.terminal_enabled = true;
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
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route("/exec", web::post().to(server_box_monitor::api::exec::exec)),
            )
        }
    })
    .await
}

/// The response body, or the status when the call was refused.
async fn post(srv: &TestServer, body: serde_json::Value) -> Result<serde_json::Value, u16> {
    let resp = srv
        .post("/api/v1/exec")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

fn token() -> String {
    generate_token("admin", SECRET).unwrap()
}

#[ntex::test]
async fn a_command_runs_and_its_output_comes_back() {
    let srv = test_server(app_state(true).await).await;
    let body = post(&srv, json!({"cmd": "echo exec-ok"})).await.unwrap();

    assert_eq!(body["exit_code"], 0);
    assert_eq!(body["stdout"], "exec-ok\n");
    assert_eq!(body["stderr"], "");
    assert_eq!(body["truncated"], false);
    assert_eq!(body["timed_out"], false);
}

/// The two streams stay apart: a caller that parses `stdout` must not find a
/// warning in the middle of it.
#[ntex::test]
async fn stdout_and_stderr_are_reported_separately() {
    let srv = test_server(app_state(true).await).await;
    let body = post(&srv, json!({"cmd": "echo out; echo err 1>&2"}))
        .await
        .unwrap();

    assert_eq!(body["stdout"], "out\n");
    assert_eq!(body["stderr"], "err\n");
}

#[ntex::test]
async fn a_failing_command_reports_its_exit_code() {
    let srv = test_server(app_state(true).await).await;
    let body = post(&srv, json!({"cmd": "exit 3"})).await.unwrap();

    assert_eq!(body["exit_code"], 3);
}

/// How a sudo password gets in with no terminal to type it into.
#[ntex::test]
async fn stdin_reaches_the_command() {
    let srv = test_server(app_state(true).await).await;
    let body = post(&srv, json!({"cmd": "cat", "stdin": "fed-on-stdin"}))
        .await
        .unwrap();

    assert_eq!(body["stdout"], "fed-on-stdin");
}

/// A script arrives on stdin rather than as an argument, which is how a
/// multi-line one survives — `ServerExec.run` sends every script this way.
#[ntex::test]
async fn a_multi_line_script_fed_to_a_shell_runs_whole() {
    let srv = test_server(app_state(true).await).await;
    let body = post(
        &srv,
        json!({
            "cmd": "cat | sh",
            "stdin": "echo first\necho 'second with \"quotes\"'\n",
        }),
    )
    .await
    .unwrap();

    assert_eq!(body["stdout"], "first\nsecond with \"quotes\"\n");
}

#[ntex::test]
async fn env_reaches_the_command_without_being_quoted_into_it() {
    let srv = test_server(app_state(true).await).await;
    let body = post(
        &srv,
        json!({
            "cmd": "printf '%s' \"$SBM_TEST\"",
            // Would need escaping if it were prepended to the command as an
            // `export` line, which is the reason this is a field.
            "env": {"SBM_TEST": "a 'quoted' \"value\""},
        }),
    )
    .await
    .unwrap();

    assert_eq!(body["stdout"], "a 'quoted' \"value\"");
}

/// The agent's own environment is kept, not replaced: a command still needs a
/// `PATH` to find anything.
#[ntex::test]
async fn env_adds_to_the_environment_rather_than_replacing_it() {
    let srv = test_server(app_state(true).await).await;
    let body = post(
        &srv,
        json!({"cmd": "test -n \"$PATH\" && echo has-path", "env": {"SBM_TEST": "x"}}),
    )
    .await
    .unwrap();

    assert_eq!(body["stdout"], "has-path\n");
}

#[ntex::test]
async fn an_empty_command_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(post(&srv, json!({"cmd": "   "})).await.unwrap_err(), 400);
}

/// The grant is re-read per request, so what the client was told earlier about
/// capabilities decides nothing.
#[ntex::test]
async fn the_endpoint_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(
        post(&srv, json!({"cmd": "echo nope"})).await.unwrap_err(),
        403
    );
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .post("/api/v1/exec")
        .send_json(&json!({"cmd": "echo nope"}))
        .await
        .unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn a_forged_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let forged = generate_token("admin", "another-secret-that-is-long-enough").unwrap();
    let resp = srv
        .post("/api/v1/exec")
        .header("Authorization", format!("Bearer {forged}"))
        .send_json(&json!({"cmd": "echo nope"}))
        .await
        .unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

/// What ran is recorded before it runs, so a command that hangs or takes the
/// agent down still leaves a trace.
#[ntex::test]
async fn the_command_is_audited() {
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    post(&srv, json!({"cmd": "echo audited-command"}))
        .await
        .unwrap();

    let subject: Option<String> =
        sqlx::query_scalar("SELECT subject FROM access_log WHERE kind = 'exec' ORDER BY id DESC LIMIT 1")
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!(subject.as_deref(), Some("echo audited-command"));
}

/// Refusals are recorded too — an attempt that was turned down is exactly what
/// someone reading the log is looking for.
#[ntex::test]
async fn a_refusal_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    let _ = post(&srv, json!({"cmd": "echo nope"})).await;

    let outcome: Option<String> =
        sqlx::query_scalar("SELECT result FROM access_log WHERE kind = 'exec' ORDER BY id DESC LIMIT 1")
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!(outcome.as_deref(), Some("denied"));
}
