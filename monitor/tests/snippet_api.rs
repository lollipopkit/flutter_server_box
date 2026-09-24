//! Coverage for `GET/PUT /api/v1/snippets` and `POST /api/v1/snippets/plan`.
//!
//! Two things are asserted here that are not obvious from the handlers:
//!
//! - **Writing needs only the panel login**, unlike `/custom-cmds`, and the
//!   difference is the point: a custom command is run by the status script on
//!   every cycle, while a snippet is typed into a terminal by a person, and a
//!   terminal has credentials of its own. A suite that asserted `full_access`
//!   here would be asserting the wrong grant.
//! - **A replace leaves nothing behind.** The tags are a child table, so a
//!   second save with fewer snippets is the case where an orphan could survive
//!   with nothing to point at it — and nothing would ever read it, so the
//!   library would simply grow a table nobody sees.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use rustls::crypto::ring;
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;
use sqlx::SqlitePool;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// The agent's state, plus the pool behind it so a test can read the tables
/// the handlers wrote rather than only what they answered.
async fn app(full_access: bool) -> (Arc<AppState>, SqlitePool) {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    (AppState::new(Arc::new(config), db.clone()), db)
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(
                        web::resource("/snippets")
                            .state(
                                web::types::JsonConfig::default()
                                    .limit(server_box_monitor::api::snippets::MAX_REQUEST),
                            )
                            .route(web::get().to(server_box_monitor::api::snippets::list))
                            .route(web::put().to(server_box_monitor::api::snippets::replace)),
                    )
                    .route(
                        "/snippets/plan",
                        web::post().to(server_box_monitor::api::snippets::plan),
                    ),
            )
        }
    })
    .await
}

fn token() -> String {
    generate_token("admin", SECRET).unwrap()
}

fn bearer(req: ntex::client::ClientRequest) -> ntex::client::ClientRequest {
    req.header("Authorization", format!("Bearer {}", token()))
}

fn snippet(id: &str, name: &str, script: &str) -> Value {
    json!({"id": id, "name": name, "script": script})
}

async fn put(srv: &TestServer, snippets: Value) -> u16 {
    bearer(srv.put("/api/v1/snippets"))
        .send_json(&json!({ "snippets": snippets }))
        .await
        .unwrap()
        .status()
        .as_u16()
}

async fn get(srv: &TestServer) -> Value {
    let resp = bearer(srv.get("/api/v1/snippets")).send().await.unwrap();
    assert!(resp.status().is_success());
    resp.json().await.unwrap()
}

async fn plan(srv: &TestServer, script: &str, context: Value) -> (u16, Value) {
    let resp = bearer(srv.post("/api/v1/snippets/plan"))
        .send_json(&json!({ "script": script, "context": context }))
        .await
        .unwrap();
    let status = resp.status().as_u16();
    (status, resp.json().await.unwrap())
}

async fn stored(db: &SqlitePool) -> Vec<(String, String, String, i64)> {
    sqlx::query_as("SELECT id, name, script, position FROM snippet ORDER BY position")
        .fetch_all(db)
        .await
        .unwrap()
}

async fn tag_count(db: &SqlitePool) -> i64 {
    sqlx::query_scalar("SELECT count(*) FROM snippet_tag")
        .fetch_one(db)
        .await
        .unwrap()
}

async fn last_log(db: &SqlitePool) -> (String, String, String, Option<String>) {
    sqlx::query_as("SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1")
        .fetch_one(db)
        .await
        .unwrap()
}

#[ntex::test]
async fn both_ends_need_a_token() {
    let (state, _db) = app(true).await;
    let srv = test_server(state).await;

    assert_eq!(srv.get("/api/v1/snippets").send().await.unwrap().status().as_u16(), 401);
    assert_eq!(
        srv.put("/api/v1/snippets")
            .send_json(&json!({"snippets": []}))
            .await
            .unwrap()
            .status()
            .as_u16(),
        401
    );
    assert_eq!(
        srv.post("/api/v1/snippets/plan")
            .send_json(&json!({"script": "ls"}))
            .await
            .unwrap()
            .status()
            .as_u16(),
        401
    );
}

/// The departure from `/custom-cmds`, asserted rather than left to be noticed:
/// a snippet is not run by anything until a person types it into a terminal,
/// and the terminal is where the grant is asked for.
#[ntex::test]
async fn neither_end_needs_full_access() {
    let (state, db) = app(false).await;
    let srv = test_server(state).await;

    assert_eq!(
        put(&srv, json!([snippet("a", "one", "df -h")])).await,
        200
    );
    assert_eq!(stored(&db).await.len(), 1);
    assert_eq!(get(&srv).await["snippets"][0]["name"], "one");

    let (status, body) = plan(&srv, "ls ${sleep 1}", json!({})).await;
    assert_eq!(status, 200);
    assert_eq!(body["steps"].as_array().unwrap().len(), 2);
}

#[ntex::test]
async fn the_round_trip_keeps_order_and_tags() {
    let (state, _db) = app(true).await;
    let srv = test_server(state).await;

    // `note` and `tags` are optional on the way in and always present on the
    // way out: the response is the record as stored, so a field the caller left
    // out is empty rather than missing.
    let first = json!({
        "id": "a", "name": "deploy", "script": "sh deploy.sh",
        "note": "runs on the app host", "tags": ["ops", "release"],
    });
    let second = json!({
        "id": "b", "name": "logs", "script": "journalctl -f",
        "note": "", "tags": ["debug"],
    });

    // The second one is sent without `note` and `tags`, which is how a client
    // leaves an optional field out; they come back present and empty.
    let mut second = second;
    second["tags"] = json!([]);

    assert_eq!(
        put(&srv, json!([first, snippet("b", "logs", "journalctl -f")])).await,
        200
    );
    let body = get(&srv).await;
    assert_eq!(body["snippets"], json!([first, second]));

    // A move is expressed by sending the list in the order wanted, since the
    // order is what is stored. These bodies carry nothing but the three fields
    // the panel always sends, and what comes back is those — a replace stores
    // what it was sent rather than merging it into what was there, so the note
    // and the tags are gone.
    assert_eq!(
        put(
            &srv,
            json!([snippet("b", "logs", "journalctl -f"), snippet("a", "deploy", "sh deploy.sh")])
        )
        .await,
        200
    );
    let body = get(&srv).await;
    assert_eq!(body["snippets"][0]["id"], "b");
    assert_eq!(body["snippets"][1]["id"], "a");
    assert_eq!(body["snippets"][1]["note"], "");
    assert_eq!(body["snippets"][1]["tags"], json!([]));
}

/// The case a child table gets wrong: the second save drops a snippet, and its
/// tags must go with it.
#[ntex::test]
async fn a_replace_leaves_no_tags_behind() {
    let (state, db) = app(true).await;
    let srv = test_server(state).await;

    let mut tagged = snippet("a", "one", "ls");
    tagged["tags"] = json!(["ops", "release"]);
    let mut other = snippet("b", "two", "ls");
    other["tags"] = json!(["ops"]);

    assert_eq!(put(&srv, json!([tagged, other])).await, 200);
    assert_eq!(tag_count(&db).await, 3);

    // The same id, with no tags at all.
    assert_eq!(put(&srv, json!([snippet("a", "one", "ls")])).await, 200);
    assert_eq!(tag_count(&db).await, 0);
    assert_eq!(get(&srv).await["snippets"][0]["tags"], json!([]));
}

/// A body too large is refused while the body is still being read, before any
/// handler sees it — so the library it was going to replace is the library that
/// stays. ntex answers by closing the connection rather than with a status the
/// client can read, which is why this asserts on the library rather than on a
/// code: the request did not reach the endpoint, and that is the fact that
/// matters.
#[ntex::test]
async fn a_refused_body_does_not_touch_the_library() {
    let (state, db) = app(true).await;
    let srv = test_server(state).await;

    assert_eq!(put(&srv, json!([snippet("a", "kept", "ls")])).await, 200);

    let huge = "x".repeat(server_box_monitor::api::snippets::MAX_REQUEST + 1);
    let refused = bearer(srv.put("/api/v1/snippets"))
        .send_json(&json!({ "snippets": [snippet("b", "replacement", &huge)] }))
        .await;
    assert!(refused.is_err(), "an oversized body was accepted");

    let rows = stored(&db).await;
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].1, "kept");
}

/// Every refusal the handler can answer with, and the library it left alone.
#[ntex::test]
async fn a_set_that_cannot_be_stored_is_refused_by_code() {
    let (state, db) = app(true).await;
    let srv = test_server(state).await;
    assert_eq!(put(&srv, json!([snippet("keep", "kept", "ls")])).await, 200);

    let mut two_tags = snippet("a", "one", "ls");
    two_tags["tags"] = json!(["ops", "ops"]);
    let mut blank_tag = snippet("a", "one", "ls");
    blank_tag["tags"] = json!([" "]);

    let cases: Vec<(Value, Value)> = vec![
        (json!([snippet("", "one", "ls")]), json!({"error": "invalidId", "index": 0})),
        (
            json!([snippet("a", "one", "ls"), snippet("a", "two", "ls")]),
            json!({"error": "duplicateId", "index": 1}),
        ),
        (json!([snippet("a", "  ", "ls")]), json!({"error": "invalidName", "index": 0})),
        (
            json!([snippet("a", "one", "ls"), snippet("b", "one", "ls")]),
            json!({"error": "duplicateName", "index": 1}),
        ),
        (json!([blank_tag]), json!({"error": "invalidTag", "index": 0})),
        (json!([two_tags]), json!({"error": "duplicateTag", "index": 0})),
    ];

    for (sent, expected) in cases {
        let resp = bearer(srv.put("/api/v1/snippets"))
            .send_json(&json!({ "snippets": sent }))
            .await
            .unwrap();
        assert_eq!(resp.status().as_u16(), 400, "expected a refusal for {expected}");
        let body: Value = resp.json().await.unwrap();
        assert_eq!(body, expected);
    }

    // Six refusals later, the library is the one that was there before them,
    // and each attempt is a row saying so.
    let rows = stored(&db).await;
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].1, "kept");
    let (kind, action, result, _) = last_log(&db).await;
    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("snippet", "write", "error")
    );
}

/// A save names what was saved, and never what it says: a script is the
/// operator's own text and the access log is not a place to keep it.
#[ntex::test]
async fn a_save_names_the_snippets_and_never_their_scripts() {
    let (state, db) = app(true).await;
    let srv = test_server(state).await;

    let secret = "curl -H 'Authorization: Bearer hunter2' https://example.invalid";
    assert_eq!(
        put(&srv, json!([snippet("a", "deploy", secret), snippet("b", "logs", "ls")])).await,
        200
    );

    let (kind, action, result, subject) = last_log(&db).await;
    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("snippet", "write", "ok"));
    let subject = subject.expect("a save names what was saved");
    assert_eq!(subject, "deploy, logs");
    assert!(!subject.contains("hunter2"), "the script was recorded: {subject}");
}

/// The expansion itself is `sbm_parser::snippet`'s, and it is asserted there in
/// full. What this covers is the wire: the tagged steps a panel reads, and the
/// refusal that a caller cannot answer a placeholder.
#[ntex::test]
async fn plan_answers_the_tagged_steps_and_refuses_what_it_cannot_answer() {
    let (state, _db) = app(true).await;
    let srv = test_server(state).await;

    let (status, body) = plan(
        &srv,
        "ssh ${user}@${host}${enter}${sleep 2}${ctrl+c}",
        json!({"host": "10.0.0.1", "port": "22", "user": "box"}),
    )
    .await;
    assert_eq!(status, 200);
    assert_eq!(
        body["steps"],
        json!([
            {"type": "text", "text": "ssh box@10.0.0.1"},
            {"type": "enter", "times": 1},
            {"type": "sleep", "seconds": 2},
            {"type": "combo", "ctrl": true, "alt": false, "key": "c", "rest": ""},
        ])
    );

    // A key the caller cannot answer is refused and named, rather than
    // substituted away: `${pwd}` expanding to nothing turns a command into a
    // different command.
    let (status, body) = plan(&srv, "cd ${pwd}", json!({})).await;
    assert_eq!(status, 400);
    assert_eq!(body, json!({"error": "unanswerable", "key": "pwd"}));

    // A script with no macros in it is one piece of text, which is the case
    // both clients send most often.
    let (status, body) = plan(&srv, "df -h", json!({})).await;
    assert_eq!(status, 200);
    assert_eq!(body["steps"], json!([{"type": "text", "text": "df -h"}]));
}

/// Expanding a script runs nothing, so it leaves no row — the log's subject is
/// what changed, and nothing did.
#[ntex::test]
async fn expanding_a_script_is_not_recorded() {
    let (state, db) = app(true).await;
    let srv = test_server(state).await;

    assert_eq!(plan(&srv, "ls", json!({})).await.0, 200);
    let rows: i64 = sqlx::query_scalar("SELECT count(*) FROM access_log")
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(rows, 0);
}

/// An empty library is an empty list rather than an absence, so a panel that
/// has never saved anything draws an empty page instead of an error.
#[ntex::test]
async fn an_empty_library_is_an_empty_list() {
    let (state, _db) = app(true).await;
    let srv = test_server(state).await;
    assert_eq!(get(&srv).await, json!({"snippets": []}));
}
