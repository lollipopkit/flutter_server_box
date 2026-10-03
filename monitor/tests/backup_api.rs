//! `/api/v1/backup`, against the real route table: admin only, a blob read
//! back byte for byte, and the bounds on what the store holds.

mod common;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::Value;

use common::machine::{call, server};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::backup::{MAX_BLOBS, MAX_BYTES};

const LIST: &str = "/api/v1/backup";

fn blob(name: &str) -> String {
    format!("/api/v1/backup/blob?name={name}")
}

/// One request with a raw body, and its status, `content-disposition` and body.
async fn raw(
    srv: &TestServer,
    user: &str,
    method: Method,
    path: &str,
    body: Option<Vec<u8>>,
) -> (u16, Option<String>, Vec<u8>) {
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(60))
        .header(
            "Authorization",
            format!("Bearer {}", generate_token(user, common::machine::SECRET).unwrap()),
        );
    let resp = match body {
        Some(body) => req.send_body(body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let disposition = resp
        .headers()
        .get("content-disposition")
        .map(|v| v.to_str().unwrap().to_string());
    let bytes = resp.body().limit(2 * MAX_BYTES as usize).await.unwrap_or_default();
    (resp.status().as_u16(), disposition, bytes.to_vec())
}

async fn backup_audit(db: &sqlx::SqlitePool) -> Vec<(String, String, Option<String>)> {
    sqlx::query_as("SELECT action, subject, detail FROM access_log WHERE kind = 'backup' ORDER BY id")
        .fetch_all(db)
        .await
        .unwrap()
}

#[ntex::test]
async fn only_an_admin_reaches_the_store() {
    let (srv, _) = server().await;
    let (status, _) = call(&srv, None, Method::GET, LIST, None).await;
    assert_eq!(status, 401);

    let (status, _) = call(&srv, Some("viewer"), Method::GET, LIST, None).await;
    assert_eq!(status, 403);
    for method in [Method::GET, Method::DELETE] {
        let (status, _, _) = raw(&srv, "viewer", method, &blob("a"), None).await;
        assert_eq!(status, 403);
    }
    let (status, _, _) = raw(&srv, "viewer", Method::PUT, &blob("a"), Some(b"x".to_vec())).await;
    assert_eq!(status, 403);
}

#[ntex::test]
async fn a_blob_is_read_back_as_it_was_written() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, LIST, None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["blobs"], Value::Array(vec![]));
    assert_eq!(body["max_bytes"], MAX_BYTES);

    let data: Vec<u8> = (0..=255u8).cycle().take(300_000).collect();
    let (status, _, written) =
        raw(&srv, "admin", Method::PUT, &blob("srvbox_bak_v3.json"), Some(data.clone())).await;
    assert_eq!(status, 200);
    let written: Value = serde_json::from_slice(&written).unwrap();
    assert_eq!(written["size"], data.len());

    let (_, body) = call(&srv, Some("admin"), Method::GET, LIST, None).await;
    assert_eq!(body["blobs"], Value::Array(vec![written.clone()]));

    let (status, disposition, read) =
        raw(&srv, "admin", Method::GET, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 200);
    assert_eq!(read, data);
    assert_eq!(disposition.as_deref(), Some("attachment; filename=\"srvbox_bak_v3.json\""));

    // A replace keeps one blob under the name.
    raw(&srv, "admin", Method::PUT, &blob("srvbox_bak_v3.json"), Some(b"new".to_vec())).await;
    let (_, _, read) = raw(&srv, "admin", Method::GET, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(read, b"new");

    let (status, _, _) = raw(&srv, "admin", Method::DELETE, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 204);
    let (status, _, _) = raw(&srv, "admin", Method::GET, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 404);
    let (status, _, _) = raw(&srv, "admin", Method::DELETE, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 404);

    let details: Vec<_> = backup_audit(&db).await.into_iter().map(|row| row.2.unwrap()).collect();
    assert_eq!(
        details,
        [
            "backup write srvbox_bak_v3.json: 300000 bytes",
            "backup write srvbox_bak_v3.json: 3 bytes",
            "backup remove srvbox_bak_v3.json",
        ]
    );
}

#[ntex::test]
async fn a_name_that_is_a_path_is_refused() {
    let (srv, _) = server().await;
    for name in ["..%2Fx", ".hidden", "a%2Fb", "a%20b"] {
        let (status, _, body) = raw(&srv, "admin", Method::PUT, &blob(name), Some(b"x".to_vec())).await;
        assert_eq!(status, 400, "{name}");
        assert_eq!(serde_json::from_slice::<Value>(&body).unwrap()["error"], "invalidName");
    }
}

#[ntex::test]
async fn the_store_is_bounded() {
    let (srv, _) = server().await;
    let too_large = vec![0u8; MAX_BYTES as usize + 1];
    let (status, _, _) = raw(&srv, "admin", Method::PUT, &blob("big"), Some(too_large)).await;
    assert_eq!(status, 413);
    let (status, _, _) = raw(&srv, "admin", Method::GET, &blob("big"), None).await;
    assert_eq!(status, 404, "a refused upload stores nothing");

    for i in 0..MAX_BLOBS {
        let (status, _, _) = raw(&srv, "admin", Method::PUT, &blob(&format!("b{i}")), Some(vec![1])).await;
        assert_eq!(status, 200);
    }
    let (status, _, body) = raw(&srv, "admin", Method::PUT, &blob("one-more"), Some(vec![1])).await;
    assert_eq!(status, 409);
    assert_eq!(serde_json::from_slice::<Value>(&body).unwrap()["error"], "tooMany");
    // Replacing one that is there is not a new place.
    let (status, _, _) = raw(&srv, "admin", Method::PUT, &blob("b0"), Some(vec![2])).await;
    assert_eq!(status, 200);
}
