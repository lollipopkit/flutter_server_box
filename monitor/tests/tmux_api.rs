//! `GET /api/v1/tmux` — the machine's tmux sessions, and who may ask.
//!
//! The route is the real one (`configure_api`), so this asserts what the
//! shipped binary exposes rather than a handler in isolation.

mod common;

use ntex::http::Method;

/// The listing needs `shell`, the same grant the terminal that attaches to a
/// session needs: a session is a shell.
#[ntex::test]
async fn a_viewer_is_refused() {
    let (srv, _) = common::machine::server().await;
    let (status, body) = common::machine::call(
        &srv,
        Some("viewer"),
        Method::GET,
        "/api/v1/tmux",
        None,
    )
    .await;
    assert_eq!(status, 403, "{body}");
    assert_eq!(body["error"], "forbidden", "{body}");
}

/// Without a token there is nothing to check the grant against.
#[ntex::test]
async fn an_unauthenticated_caller_is_refused() {
    let (srv, _) = common::machine::server().await;
    let (status, _) = common::machine::call(&srv, None, Method::GET, "/api/v1/tmux", None).await;
    assert_eq!(status, 401);
}

/// The shape the panel reads, whichever way this machine answers.
///
/// The absence branch (`available: false`, no sessions) cannot be forced from
/// a test: tmux is found through the agent's own command, and there is no
/// request field that names a binary or changes its `PATH`. So this asserts the
/// keys and the types on either answer, and the per-session fields only when
/// there is a listing to read — a machine with no tmux still proves the shape
/// the panel branches on.
#[ntex::test]
async fn the_answer_is_the_shape_the_panel_reads() {
    let (srv, _) = common::machine::server().await;
    let (status, body) =
        common::machine::call(&srv, Some("admin"), Method::GET, "/api/v1/tmux", None).await;
    assert_eq!(status, 200, "{body}");
    assert!(body["available"].is_boolean(), "{body}");
    let sessions = body["sessions"].as_array().expect("sessions is an array");
    for session in sessions {
        assert!(session["id"].is_string(), "{session}");
        assert!(session["name"].is_string(), "{session}");
        assert!(session["windows"].is_number(), "{session}");
        assert!(session["attached"].is_boolean(), "{session}");
    }
}
