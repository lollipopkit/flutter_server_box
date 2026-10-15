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
    method: Method,
    path: &str,
    body: Option<Vec<u8>>,
) -> (u16, Option<String>, Vec<u8>) {
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(60))
        .header(
            "Authorization",
            format!("Bearer {}", generate_token(common::machine::SECRET).unwrap()),
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
async fn a_blob_is_read_back_as_it_was_written() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, true, Method::GET, LIST, None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["blobs"], Value::Array(vec![]));
    assert_eq!(body["max_bytes"], MAX_BYTES);

    let data: Vec<u8> = (0..=255u8).cycle().take(300_000).collect();
    let (status, _, written) =
        raw(&srv, Method::PUT, &blob("srvbox_bak_v3.json"), Some(data.clone())).await;
    assert_eq!(status, 200);
    let written: Value = serde_json::from_slice(&written).unwrap();
    assert_eq!(written["size"], data.len());

    let (_, body) = call(&srv, true, Method::GET, LIST, None).await;
    assert_eq!(body["blobs"], Value::Array(vec![written.clone()]));

    let (status, disposition, read) =
        raw(&srv, Method::GET, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 200);
    assert_eq!(read, data);
    assert_eq!(disposition.as_deref(), Some("attachment; filename=\"srvbox_bak_v3.json\""));

    // A replace keeps one blob under the name.
    raw(&srv, Method::PUT, &blob("srvbox_bak_v3.json"), Some(b"new".to_vec())).await;
    let (_, _, read) = raw(&srv, Method::GET, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(read, b"new");

    let (status, _, _) = raw(&srv, Method::DELETE, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 204);
    let (status, _, _) = raw(&srv, Method::GET, &blob("srvbox_bak_v3.json"), None).await;
    assert_eq!(status, 404);
    let (status, _, _) = raw(&srv, Method::DELETE, &blob("srvbox_bak_v3.json"), None).await;
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
        let (status, _, body) = raw(&srv, Method::PUT, &blob(name), Some(b"x".to_vec())).await;
        assert_eq!(status, 400, "{name}");
        assert_eq!(serde_json::from_slice::<Value>(&body).unwrap()["error"], "invalidName");
    }
}

/// A refusal sent before the body is read used to close the connection under
/// a client still writing it, which then saw a reset instead of the answer.
/// The larger the body, the surer: this one is far from written by then.
#[ntex::test]
async fn a_refused_upload_is_answered_whatever_its_size() {
    let (srv, _) = server().await;
    let body = vec![0u8; 8 * 1024 * 1024];
    for _ in 0..3 {
        let (status, _, body) = raw(&srv, Method::PUT, &blob(".hidden"), Some(body.clone())).await;
        assert_eq!(status, 400);
        assert_eq!(serde_json::from_slice::<Value>(&body).unwrap()["error"], "invalidName");
    }
}

/// What is read of a refused upload is bounded: a client that never signed
/// in cannot keep the agent reading. Past the bound the connection is closed.
#[ntex::test]
async fn a_refused_upload_is_read_no_further_than_one_upload() {
    use futures::stream;
    let (srv, _) = server().await;
    // Endless, chunked: no length to stop at.
    let endless = stream::repeat_with(|| Ok::<_, std::io::Error>(ntex::util::Bytes::from(vec![0u8; 64 * 1024])));
    let sent = tokio::time::timeout(
        std::time::Duration::from_secs(30),
        srv.request(Method::PUT, srv.url(&blob("x"))).send_stream(endless),
    )
    .await;
    // Answered once the bound was read, or cut off there; an agent that kept
    // reading would never answer.
    let Ok(sent) = sent else { panic!("the agent kept reading") };
    if let Ok(resp) = sent {
        assert_eq!(resp.status().as_u16(), 401);
    }
}

#[ntex::test]
async fn the_store_is_bounded() {
    let (srv, _) = server().await;
    let too_large = vec![0u8; MAX_BYTES as usize + 1];
    let (status, _, _) = raw(&srv, Method::PUT, &blob("big"), Some(too_large)).await;
    assert_eq!(status, 413);
    let (status, _, _) = raw(&srv, Method::GET, &blob("big"), None).await;
    assert_eq!(status, 404, "a refused upload stores nothing");

    for i in 0..MAX_BLOBS {
        let (status, _, _) = raw(&srv, Method::PUT, &blob(&format!("b{i}")), Some(vec![1])).await;
        assert_eq!(status, 200);
    }
    let (status, _, body) = raw(&srv, Method::PUT, &blob("one-more"), Some(vec![1])).await;
    assert_eq!(status, 409);
    assert_eq!(serde_json::from_slice::<Value>(&body).unwrap()["error"], "tooMany");
    // Replacing one that is there is not a new place.
    let (status, _, _) = raw(&srv, Method::PUT, &blob("b0"), Some(vec![2])).await;
    assert_eq!(status, 200);
}
