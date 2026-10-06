//! `GET/POST /api/v1/containers`, against the real route table.
//!
//! The refusals and what a client is told, and **not** a successful change:
//! this endpoint acts on the container runtime of whoever runs the suite, and
//! a start, stop, removal or prune would leave the machine different from how
//! it was found. The model underneath — the fields `docker ps` is asked for,
//! Podman told from Docker, what a stats row becomes — is
//! `sbm_parser::container`'s own tests.
//!
//! Reading changes nothing and is exercised, accepting whatever the machine
//! has: Docker, Podman, both, or neither.

mod common;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};

use common::machine::{audit, call, server};

async fn get(srv: &TestServer, query: &str) -> (u16, Value) {
    call(srv, Some("admin"), Method::GET, &format!("/api/v1/containers{query}"), None).await
}

async fn post(srv: &TestServer, user: &str, body: Value) -> (u16, Value) {
    call(srv, Some(user), Method::POST, "/api/v1/containers", Some(body)).await
}

#[ntex::test]
async fn both_halves_need_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/containers", None).await;
    assert_eq!(status, 401);

    let (status, body) = call(&srv, Some("viewer"), Method::GET, "/api/v1/containers", None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));
    let (status, _) = post(&srv, "viewer", json!({ "action": "stop", "id": "abc" })).await;
    assert_eq!(status, 403);

    let rows = audit(&db).await;
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert!(rows.iter().all(|(action, _, subject, _)| action == "denied" && subject.as_deref() == Some("viewer")));
    assert_eq!(rows[1].3.as_deref(), Some("containers stop abc: shell not_granted"));
}

/// Each part answers with the same envelope, so the page has one shape to
/// draw whatever the machine has. A read is not recorded.
#[ntex::test]
async fn every_part_answers_with_its_own_shape() {
    let (srv, db) = server().await;
    let (status, body) = get(&srv, "").await;
    assert_eq!((status, &body["part"]), (200, &json!("containers")), "{body}");
    for part in ["containers", "images", "usage"] {
        let (status, body) = get(&srv, &format!("?part={part}")).await;
        assert_eq!(status, 200, "{part}: {body}");
        assert_eq!(body["part"], part, "{body}");
        assert!(body["available"].is_boolean(), "{body}");
        assert!(body["containers"].is_array() && body["images"].is_array(), "{body}");
        // The dangling flag the panel would otherwise re-derive, and the
        // unused count it shows — either may be absent, but the shape is fixed.
        for image in body["images"].as_array().unwrap() {
            assert!(image["dangling"].is_boolean(), "{body}");
        }
        assert!(body["unused_tagged"].is_null() || body["unused_tagged"].is_number(), "{body}");
        if body["available"] == false {
            assert!(body["reason_kind"].is_string(), "an unavailable answer says why: {body}");
        }
    }
    assert!(audit(&db).await.is_empty());
}

/// A part about one container cannot be answered without it; refused before
/// the runtime runs. One the runtime refuses still answers in the envelope.
#[ntex::test]
async fn a_part_about_one_container_needs_its_id() {
    let (srv, _) = server().await;
    assert_eq!(get(&srv, "?part=logs").await.0, 400);
    let (status, body) = get(&srv, "?part=logs&id=definitely-not-a-container").await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["part"], "logs");
}

/// An action or a part this build does not have is refused while
/// deserializing, before anything reaches a shell.
#[ntex::test]
async fn what_this_build_does_not_have_is_refused() {
    let (srv, db) = server().await;
    assert_eq!(get(&srv, "?part=volumes").await.0, 400);
    for body in [json!({ "action": "exec", "id": "abc" }), json!({ "action": "stop" }), json!({ "id": "abc" })] {
        assert_eq!(post(&srv, "admin", body.clone()).await.0, 400, "{body}");
    }
    assert!(audit(&db).await.is_empty());
}

#[ntex::test]
async fn capabilities_list_the_containers_page() {
    let (srv, _) = server().await;
    let (_, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "containers"), "{caps}");
    // A panel offers the container shell only where an agent lists this, since
    // an older agent would ignore the target and open a host shell.
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "container_exec"), "{caps}");
}

/// A value the runtime would read as an option, or one it cannot take, is
/// refused before the runtime is probed or anything runs.
#[ntex::test]
async fn an_invalid_value_is_refused_before_anything_runs() {
    let (srv, db) = server().await;
    let cases = [
        (json!({ "action": "pull_image", "reference": "-rm" }), "leading_dash"),
        (json!({ "action": "pull_image", "reference": "a;b" }), "invalid_reference"),
        (json!({ "action": "remove_image", "id": "  " }), "empty"),
        // A trailing newline is what `trim` would hide; it reaches the command.
        (json!({ "action": "remove_image", "id": "$(id)\n" }), "control_character"),
        (
            json!({ "action": "run", "image": "alpine", "name": "w", "args": "\"unfinished" }),
            "invalid_args",
        ),
        (
            json!({ "action": "run", "image": "alpine", "name": "bad name", "args": "" }),
            "invalid_name",
        ),
        (
            json!({ "action": "run", "image": "alpine\nlatest", "name": "", "args": "" }),
            "control_character",
        ),
    ];
    for (body, code) in &cases {
        let (status, answer) = post(&srv, "admin", body.clone()).await;
        assert_eq!(status, 400, "{body}: {answer}");
        assert_eq!(answer["error"], "invalid_input", "{body}: {answer}");
        assert_eq!(answer["issue"], *code, "{body}: {answer}");
    }
    // Each one recorded as a refusal, and nothing else ran.
    let rows = audit(&db).await;
    assert_eq!(rows.len(), cases.len(), "{rows:?}");
    assert!(
        rows.iter().all(|(action, result, subject, _)| action == "denied"
            && result == "denied"
            && subject.as_deref() == Some("admin")),
        "{rows:?}"
    );
}

/// The image and run actions need `shell` exactly as the container ones do.
#[ntex::test]
async fn every_new_action_needs_the_shell_grant() {
    let (srv, _) = server().await;
    for action in [
        json!({ "action": "remove_image", "id": "abc" }),
        json!({ "action": "pull_image", "reference": "alpine" }),
        json!({ "action": "prune_images", "all_unused": true }),
        json!({ "action": "prune_system", "all_unused_images": false, "include_volumes": false }),
        json!({ "action": "run", "image": "alpine", "name": "", "args": "" }),
    ] {
        let (status, body) = post(&srv, "viewer", action.clone()).await;
        assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")), "{action}");
    }
}
