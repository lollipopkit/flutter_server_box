//! `/api/v1/desktops`, against the real route table: the grant, a set that
//! survives a round trip in its order, and a refusal that leaves the stored
//! set. Nothing here dials a desktop; the relay is `stream_ws.rs`'s.

mod common;

use ntex::http::Method;
use serde_json::json;

use common::machine::{audit, call, server};

const PATH: &str = "/api/v1/desktops";

#[ntex::test]
async fn both_halves_need_the_connect_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, PATH, None).await;
    assert_eq!(status, 401);

    let (status, body) = call(&srv, Some("viewer"), Method::GET, PATH, None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));
    let (status, _) =
        call(&srv, Some("viewer"), Method::PUT, PATH, Some(json!({"desktops": []}))).await;
    assert_eq!(status, 403);

    let details: Vec<_> = audit(&db).await.into_iter().map(|row| row.3.unwrap()).collect();
    assert_eq!(
        details,
        ["desktops list: connect not_granted", "desktops replace: connect not_granted"]
    );
}

#[ntex::test]
async fn a_set_is_read_back_as_it_was_written() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["desktops"], json!([]));
    assert_eq!(
        body["protocols"],
        json!([{"id": "vnc", "default_port": 5900}, {"id": "rdp", "default_port": 3389}])
    );

    let set = json!([
        {"id": "b", "name": "Office", "protocol": "vnc", "host": "10.0.0.5", "port": 5901,
         "username": null, "domain": null, "view_only": true, "shared": false},
        {"id": "a", "name": "Local", "protocol": "vnc", "host": "127.0.0.1", "port": 5900,
         "username": "lk", "domain": null, "view_only": false, "shared": true},
    ]);
    let (status, body) =
        call(&srv, Some("admin"), Method::PUT, PATH, Some(json!({"desktops": set}))).await;
    assert_eq!(status, 200, "{body}");
    let (_, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!(body["desktops"], set);

    let rows = audit(&db).await;
    assert_eq!(rows.len(), 1, "{rows:?}");
    assert_eq!(rows[0].3.as_deref(), Some("desktops replace: Office, Local"));
}

#[ntex::test]
async fn a_refused_set_leaves_the_stored_one() {
    let (srv, _) = server().await;
    let stored = json!([{"id": "a", "name": "one", "protocol": "vnc", "host": "127.0.0.1",
        "port": 5900, "username": null, "domain": null, "view_only": false, "shared": true}]);
    call(&srv, Some("admin"), Method::PUT, PATH, Some(json!({"desktops": stored}))).await;

    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::PUT,
        PATH,
        Some(json!({"desktops": [
            {"id": "x", "name": "two", "protocol": "vnc", "host": "127.0.0.1", "port": 5900},
            {"id": "y", "name": "three", "protocol": "vnc", "host": "bad host", "port": 5900},
        ]})),
    )
    .await;
    assert_eq!((status, body), (400, json!({"error": "invalidHost", "index": 1})));
    let (_, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!(body["desktops"], stored);
}
