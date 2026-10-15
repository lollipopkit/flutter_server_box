//! `/api/v1/container-backups*`: who may use it, and what it refuses before
//! any container is touched. Backing up and restoring on a real Docker is in
//! `stacks_docker.rs`.

mod common;

use std::sync::Arc;

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::json;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::container_backups;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

async fn setup() -> TestServer {
    let db = common::database().await;
    let config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    common::add_owner(&db).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(
                        web::resource("/container-backups")
                            .route(web::get().to(container_backups::list))
                            .route(web::post().to(container_backups::create)),
                    )
                    .service(web::resource("/container-backups/job").route(web::get().to(container_backups::job)))
                    .service(web::resource("/container-backups/settings").route(web::put().to(container_backups::put_settings)))
                    .service(web::resource("/container-backups/schedules").route(web::post().to(container_backups::add_schedule)))
                    .service(web::resource("/container-backups/schedules/{id}").route(web::delete().to(container_backups::remove_schedule)))
                    .service(web::resource("/container-backups/job/cancel").route(web::post().to(container_backups::cancel)))
                    .service(web::resource("/container-backups/{id}/restore").route(web::post().to(container_backups::restore)))
                    .service(web::resource("/container-backups/{id}").route(web::delete().to(container_backups::remove))),
            )
        }
    })
    .await
}

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<serde_json::Value>) -> (u16, serde_json::Value) {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
        .timeout(std::time::Duration::from_secs(30));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let bytes = resp.body().await.unwrap_or_default();
    (resp.status().as_u16(), serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null))
}

#[ntex::test]
async fn backing_up_checks_its_containers_and_restoring_asks_the_password() {
    let srv = setup().await;
    let pw = json!({ "current_password": common::PASSWORD });
    let id = "20261011-013000-sbm-x";

    let (status, body) = call(&srv, Method::GET, "/api/v1/container-backups", None).await;
    assert_eq!((status, body["backups"].clone()), (200, json!([])));
    let (status, body) = call(&srv, Method::POST, "/api/v1/container-backups", Some(json!({ "containers": [] }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("invalidContainer")));
    let (status, body) =
        call(&srv, Method::POST, "/api/v1/container-backups", Some(json!({ "containers": ["$(id)"] }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("invalidContainer")));

    let (status, _) = call(&srv, Method::POST, &format!("/api/v1/container-backups/{id}/restore"), Some(json!({ "current_password": "wrong" }))).await;
    assert_ne!(status, 202);
    let (status, body) = call(&srv, Method::POST, &format!("/api/v1/container-backups/{id}/restore"), Some(pw.clone())).await;
    assert_eq!((status, body["error"].as_str()), (404, Some("notFound")));
    let (status, _) = call(&srv, Method::DELETE, "/api/v1/container-backups/..%2F..%2Fetc", Some(pw.clone())).await;
    assert_eq!(status, 404);
}

#[ntex::test]
async fn backups_go_where_they_are_told_on_the_schedule_set() {
    let srv = setup().await;
    let (status, body) =
        call(&srv, Method::PUT, "/api/v1/container-backups/settings", Some(json!({ "destination": "/nowhere/at/all", "keep": 3 }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("destinationMissing")));
    let disk = tempfile::tempdir().unwrap();
    let (status, body) = call(
        &srv,
        Method::PUT,
        "/api/v1/container-backups/settings",
        Some(json!({ "destination": disk.path().to_str().unwrap(), "keep": 3 })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["keep"], 3);
    let (_, list) = call(&srv, Method::GET, "/api/v1/container-backups", None).await;
    assert!(list["folder"].as_str().unwrap().ends_with("serverbox-container-backups"), "{list}");
    assert!(disk.path().join("serverbox-container-backups").is_dir());
    assert!(list["free_bytes"].as_u64().unwrap() > 0);

    for bad in [
        json!({ "containers": ["web"], "every": "hourly", "at": "03:00" }),
        json!({ "containers": ["web"], "every": "daily", "at": "25:00" }),
        json!({ "containers": ["web"], "every": "weekly", "at": "03:00" }),
        json!({ "containers": ["$(id)"], "every": "daily", "at": "03:00" }),
    ] {
        let (status, _) = call(&srv, Method::POST, "/api/v1/container-backups/schedules", Some(bad.clone())).await;
        assert_eq!(status, 400, "{bad}");
    }
    let (status, made) = call(
        &srv,
        Method::POST,
        "/api/v1/container-backups/schedules",
        Some(json!({ "containers": ["sbm-futo-immich-server-1"], "project": true, "every": "weekly", "at": "03:30", "weekday": 6, "keep": 4 })),
    )
    .await;
    assert_eq!(status, 201, "{made}");
    let (_, list) = call(&srv, Method::GET, "/api/v1/container-backups", None).await;
    assert_eq!(list["schedules"][0]["weekday"], 6);
    let (status, _) = call(&srv, Method::DELETE, &format!("/api/v1/container-backups/schedules/{}", made["id"].as_str().unwrap()), None).await;
    assert_eq!(status, 204);
}
