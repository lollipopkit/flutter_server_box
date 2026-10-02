//! `/api/v1/snippets` and `/api/v1/snippets/plan`, against the real route
//! table: the grant, a library that survives a round trip in its order, the
//! refusals, and the expansion. What a macro expands to is
//! `sbm_parser::snippet`'s own tests.

mod common;

use ntex::http::Method;
use serde_json::json;

use common::machine::{audit, call, server};

const PATH: &str = "/api/v1/snippets";
const PLAN: &str = "/api/v1/snippets/plan";

#[ntex::test]
async fn every_route_needs_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, PATH, None).await;
    assert_eq!(status, 401);

    for (method, path, body) in [
        (Method::GET, PATH, None),
        (Method::PUT, PATH, Some(json!({"snippets": []}))),
        (Method::POST, PLAN, Some(json!({"script": "ls"}))),
    ] {
        let (status, body) = call(&srv, Some("viewer"), method, path, body).await;
        assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")), "{path}");
    }
    let rows = audit(&db).await;
    let details: Vec<_> = rows.iter().map(|row| row.3.as_deref().unwrap()).collect();
    assert_eq!(
        details,
        [
            "snippets list: shell not_granted",
            "snippets replace: shell not_granted",
            "snippets plan: shell not_granted",
        ]
    );
}

#[ntex::test]
async fn a_library_is_read_back_as_it_was_written() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!((status, body), (200, json!({"snippets": []})));

    let library = json!([
        {"id": "b", "name": "Disk", "script": "df -h", "note": "", "tags": ["ops", "disk"]},
        {"id": "a", "name": "Login", "script": "ssh ${user}@${host}", "note": "jump", "tags": []},
    ]);
    let (status, body) =
        call(&srv, Some("admin"), Method::PUT, PATH, Some(json!({"snippets": library}))).await;
    assert_eq!(status, 200, "{body}");
    let (_, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    // The order is the one sent, and so is each snippet's tag order.
    assert_eq!(body["snippets"], library);

    // A replace drops what it does not carry, tags included.
    let (status, _) = call(
        &srv,
        Some("admin"),
        Method::PUT,
        PATH,
        Some(json!({"snippets": [{"id": "a", "name": "Login", "script": "ssh"}]})),
    )
    .await;
    assert_eq!(status, 200);
    let (_, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!(
        body["snippets"],
        json!([{"id": "a", "name": "Login", "script": "ssh", "note": "", "tags": []}])
    );

    // A write names the snippets and never a script.
    let rows = audit(&db).await;
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert_eq!(rows[0].3.as_deref(), Some("snippets replace: Disk, Login"));
    assert!(rows.iter().all(|row| !row.3.as_deref().unwrap().contains("df -h")));
}

#[ntex::test]
async fn a_refused_library_leaves_the_stored_one() {
    let (srv, _) = server().await;
    let stored = json!([{"id": "a", "name": "one", "script": "ls", "note": "", "tags": []}]);
    call(&srv, Some("admin"), Method::PUT, PATH, Some(json!({"snippets": stored}))).await;

    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::PUT,
        PATH,
        Some(json!({"snippets": [
            {"id": "x", "name": "two", "script": "ls"},
            {"id": "y", "name": "two", "script": "ls"},
        ]})),
    )
    .await;
    assert_eq!((status, body), (400, json!({"error": "duplicateName", "index": 1})));
    let (_, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!(body["snippets"], stored);
}

#[ntex::test]
async fn a_plan_is_the_steps_or_the_placeholder_it_cannot_answer() {
    let (srv, db) = server().await;
    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::POST,
        PLAN,
        Some(json!({"script": "echo ${name}${sleep 1}${ctrl+c}", "context": {"name": "box"}})),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(
        body["steps"],
        json!([
            {"type": "text", "text": "echo box"},
            {"type": "sleep", "seconds": 1},
            {"type": "combo", "ctrl": true, "alt": false, "key": "c", "rest": ""},
        ])
    );

    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::POST,
        PLAN,
        Some(json!({"script": "sshpass -p ${pwd} true"})),
    )
    .await;
    assert_eq!((status, body), (400, json!({"error": "unanswerable", "key": "pwd"})));
    // A plan runs nothing and is not recorded.
    assert!(audit(&db).await.is_empty());
}
