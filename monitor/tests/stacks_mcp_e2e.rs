//! Catalog apps' MCP servers on a real Docker: each app deployed (a copy of
//! its `store/apps` folder under a name of its own, so a copy an agent on the
//! same machine deployed is never touched), connected to by Agent mode as
//! deployed, a read-only tool called through it, refused without its token,
//! and removed with its data.
//!
//! Opt-in, as `stacks_docker`: it pulls images and runs containers.
//!
//!     SBM_E2E_DOCKER=1 cargo test -p server_box_monitor --test stacks_mcp_e2e -- --ignored --nocapture
//!
//! `SBM_E2E_MCP_APPS=transmission.transmission,…` picks the apps; by default
//! every catalog app whose MCP credential is known at deploy.

mod common;

use std::sync::Arc;
use std::time::{Duration, Instant};

use fl_pi_llm::host::mcp::{McpClient, McpServerConfig};
use fl_pi_llm::host::{Cancel, FetchRequest};
use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::{Config, StacksConfig};
use server_box_monitor::stacks::mcp::Credential;

use common::catalog;

/// The catalog apps tested by default: their MCP server connects with what
/// the deploy wrote, or with a token [provision] makes as the person would.
const AUTOMATIC: &[&str] = &[
    "transmission.transmission",
    "adguard.adguard_home",
    "usememos.memos",
    "homeassistant.home_assistant",
    "futo.immich",
    "jellyfin.jellyfin",
    "karakeep.karakeep",
    "grafana.grafana",
    "n8n.n8n",
    "triliumnext.trilium",
];

/// The password of the accounts this test makes in an app.
const PASSWORD: &str = "e2e-Passw0rd-not-kept";

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    common::machine::call(srv, true, method, path, body).await
}

/// A JSON request to an app's own API on loopback.
async fn app_api(state: &Arc<AppState>, method: &str, url: &str, bearer: Option<&str>, body: Value) -> Value {
    app_api_as(state, method, url, bearer.map(|t| format!("Bearer {t}")), body).await
}

/// [app_api] with the `Authorization` header an app's own scheme takes.
async fn app_api_as(state: &Arc<AppState>, method: &str, url: &str, authorization: Option<String>, body: Value) -> Value {
    let mut headers = vec![("content-type".to_string(), "application/json".to_string())];
    if let Some(a) = authorization {
        headers.push(("authorization".into(), a));
    }
    let req = FetchRequest { url: url.into(), method: method.into(), headers, body: (!body.is_null()).then(|| body.to_string().into_bytes()) };
    let mut res = state.agent.fetch().fetch(req).await.unwrap();
    let mut bytes = Vec::new();
    while let Some(chunk) = res.body.recv().await {
        bytes.extend(chunk.unwrap());
    }
    assert!((200..300).contains(&res.status), "{url}: HTTP {} {}", res.status, String::from_utf8_lossy(&bytes));
    serde_json::from_slice(&bytes).unwrap_or(Value::Null)
}

/// The token an `asked` credential is given, made as the person would: the
/// app's first account and a token of its, through the app's own API.
async fn provision(state: &Arc<AppState>, id: &str, settings: &Value) -> String {
    let catalog = id.trim_end_matches("_e2e");
    match catalog {
        "usememos.memos" => {
            let base = format!("http://127.0.0.1:{}", settings["port"]);
            // The first account signed up is the administrator.
            app_api(state, "POST", &format!("{base}/api/v1/users"), None, json!({ "username": "admin", "password": PASSWORD, "role": "ADMIN" })).await;
            let signed = app_api(state, "POST", &format!("{base}/api/v1/auth/signin"), None, json!({ "passwordCredentials": { "username": "admin", "password": PASSWORD } })).await;
            let access = signed["accessToken"].as_str().unwrap().to_string();
            let pat = app_api(state, "POST", &format!("{base}/api/v1/users/admin/personalAccessTokens"), Some(&access), json!({ "description": "Agent mode" })).await;
            pat["token"].as_str().unwrap().to_string()
        }
        other => panic!("{other}: no way to make its token in this test"),
    }
}

/// Home Assistant set up as its owner would: onboarded through its API, and
/// its Model Context Protocol Server integration added.
async fn set_up_home_assistant(state: &Arc<AppState>, base: &str) {
    let client = format!("{base}/");
    let deadline = Instant::now() + Duration::from_secs(300);
    // Up once it answers its onboarding.
    loop {
        let req = FetchRequest { url: format!("{base}/api/onboarding"), method: "GET".into(), headers: vec![], body: None };
        if state.agent.fetch().fetch(req).await.is_ok_and(|r| r.status == 200) {
            break;
        }
        assert!(Instant::now() < deadline, "Home Assistant did not start");
        tokio::time::sleep(Duration::from_secs(3)).await;
    }
    let user = app_api(state, "POST", &format!("{base}/api/onboarding/users"), None,
        json!({ "client_id": client, "name": "Admin", "username": "admin", "password": PASSWORD, "language": "en" })).await;
    let code = user["auth_code"].as_str().unwrap().to_string();
    // The token endpoint takes a form.
    let form = format!("grant_type=authorization_code&code={code}&client_id={}", url::form_urlencoded::byte_serialize(client.as_bytes()).collect::<String>());
    let req = FetchRequest {
        url: format!("{base}/auth/token"),
        method: "POST".into(),
        headers: vec![("content-type".into(), "application/x-www-form-urlencoded".into())],
        body: Some(form.into_bytes()),
    };
    let mut res = state.agent.fetch().fetch(req).await.unwrap();
    let mut bytes = Vec::new();
    while let Some(chunk) = res.body.recv().await {
        bytes.extend(chunk.unwrap());
    }
    let token: Value = serde_json::from_slice(&bytes).unwrap();
    let token = token["access_token"].as_str().unwrap().to_string();
    for (step, body) in [("core_config", json!({})), ("analytics", json!({})), ("integration", json!({ "client_id": client, "redirect_uri": client }))] {
        app_api(state, "POST", &format!("{base}/api/onboarding/{step}"), Some(&token), body).await;
    }
    let flow = app_api(state, "POST", &format!("{base}/api/config/config_entries/flow"), Some(&token), json!({ "handler": "mcp_server" })).await;
    if flow["type"] == "form" {
        let id = flow["flow_id"].as_str().unwrap();
        app_api(state, "POST", &format!("{base}/api/config/config_entries/flow/{id}"), Some(&token), json!({ "llm_hass_api": ["assist"] })).await;
    }
}

/// Signs Agent mode in to the app's server with OAuth: started through the
/// agent, the person's sign-in made through the app's own login flow, and
/// the browser's way back to the agent.
async fn sign_in(srv: &TestServer, state: &Arc<AppState>, id: &str, url: &str, app_base: &str) {
    let origin = srv.url("/").trim_end_matches('/').to_string();
    let (status, body) = call(srv, Method::POST, "/api/v1/agent/mcp/oauth/start", Some(json!({ "url": url, "origin": origin }))).await;
    assert_eq!(status, 200, "{id}: {body}");
    let to = url::Url::parse(body["authorizeUrl"].as_str().unwrap()).unwrap();
    let q: std::collections::HashMap<String, String> = to.query_pairs().into_owned().collect();
    match id.trim_end_matches("_e2e") {
        "homeassistant.home_assistant" => {
            let flow = app_api(state, "POST", &format!("{app_base}/auth/login_flow"), None,
                json!({
                    "client_id": q["client_id"], "handler": ["homeassistant", null], "redirect_uri": q["redirect_uri"],
                    // As Home Assistant's own authorize page passes them on.
                    "code_challenge": q["code_challenge"], "code_challenge_method": q["code_challenge_method"],
                })).await;
            let flow_id = flow["flow_id"].as_str().unwrap();
            let done = app_api(state, "POST", &format!("{app_base}/auth/login_flow/{flow_id}"), None,
                json!({ "client_id": q["client_id"], "username": "admin", "password": PASSWORD })).await;
            assert_eq!(done["type"], "create_entry", "{id}: {done}");
            let code = done["result"].as_str().unwrap();
            let back = url::Url::parse(&q["redirect_uri"]).unwrap();
            let back = format!("{}?state={}&code={code}", back.path(), q["state"]);
            let res = srv.request(Method::GET, srv.url(&back)).send().await.unwrap();
            let page = res.body().await.unwrap_or_default();
            assert_eq!(res.status().as_u16(), 200, "{id}: the way back was refused: {}", String::from_utf8_lossy(&page));
        }
        other => panic!("{other}: no way to sign in to it in this test"),
    }
}

/// Waits until [url] answers 200.
async fn up(state: &Arc<AppState>, url: &str) {
    let deadline = Instant::now() + Duration::from_secs(600);
    loop {
        let req = FetchRequest { url: url.into(), method: "GET".into(), headers: vec![], body: None };
        if state.agent.fetch().fetch(req).await.is_ok_and(|r| r.status == 200) {
            return;
        }
        assert!(Instant::now() < deadline, "{url} did not come up");
        tokio::time::sleep(Duration::from_secs(3)).await;
    }
}

/// For an app whose sidecar needs the service's own API key, which the
/// service makes only for an account: the setting it goes in and the key,
/// made as the person would. `None` for the others.
async fn api_key_setting(state: &Arc<AppState>, id: &str, settings: &Value) -> Option<(&'static str, String)> {
    match id.trim_end_matches("_e2e") {
        "futo.immich" => {
            let base = format!("http://127.0.0.1:{}", settings["port"]);
            up(state, &format!("{base}/api/server/ping")).await;
            let email = "admin@e2e.invalid";
            app_api(state, "POST", &format!("{base}/api/auth/admin-sign-up"), None, json!({ "email": email, "password": PASSWORD, "name": "Admin" })).await;
            let login = app_api(state, "POST", &format!("{base}/api/auth/login"), None, json!({ "email": email, "password": PASSWORD })).await;
            let access = login["accessToken"].as_str().unwrap().to_string();
            let key = app_api(state, "POST", &format!("{base}/api/api-keys"), Some(&access), json!({ "name": "Agent mode", "permissions": ["all"] })).await;
            Some(("mcp_api_key", key["secret"].as_str().unwrap().to_string()))
        }
        "jellyfin.jellyfin" => {
            let base = format!("http://127.0.0.1:{}", settings["port"]);
            // `/health` and the public routes answer while Jellyfin's startup
            // page still holds the wizard's at 503.
            up(state, &format!("{base}/Startup/Configuration")).await;
            // The startup wizard, as its pages call it.
            let client = r#"MediaBrowser Client="e2e", Device="e2e", DeviceId="sbm-e2e", Version="1.0""#;
            let wizard = |path: &str, body: Value| {
                let url = format!("{base}/Startup/{path}");
                async move { app_api_as(state, "POST", &url, Some(client.into()), body).await }
            };
            wizard("Configuration", json!({ "UICulture": "en-US", "MetadataCountryCode": "US", "PreferredMetadataLanguage": "en" })).await;
            app_api_as(state, "GET", &format!("{base}/Startup/User"), Some(client.into()), Value::Null).await;
            wizard("User", json!({ "Name": "admin", "Password": PASSWORD })).await;
            wizard("RemoteAccess", json!({ "EnableRemoteAccess": true, "EnableAutomaticPortMapping": false })).await;
            wizard("Complete", json!({})).await;
            let login = app_api_as(state, "POST", &format!("{base}/Users/AuthenticateByName"), Some(client.into()), json!({ "Username": "admin", "Pw": PASSWORD })).await;
            let signed = format!(r#"{client}, Token="{}""#, login["AccessToken"].as_str().unwrap());
            app_api_as(state, "POST", &format!("{base}/Auth/Keys?app=AgentMode"), Some(signed.clone()), Value::Null).await;
            let keys = app_api_as(state, "GET", &format!("{base}/Auth/Keys"), Some(signed), Value::Null).await;
            Some(("mcp_api_key", keys["Items"][0]["AccessToken"].as_str().unwrap().to_string()))
        }
        _ => None,
    }
}

async fn verify(srv: &TestServer, state: &Arc<AppState>, id: &str) {
    eprintln!("== {id}");
    let (settings, _cleanup) = catalog::deploy(srv, id).await;

    // The service's own key into its settings, deployed again.
    if let Some((key, value)) = api_key_setting(state, id, &settings).await {
        let mut settings = settings.clone();
        settings[key] = json!(value);
        let (status, body) = call(
            srv,
            Method::PUT,
            &format!("/api/v1/stacks/{id}/settings"),
            Some(json!({ "current_password": common::PASSWORD, "settings": settings })),
        )
        .await;
        assert_eq!(status, 202, "{id}: {body}");
        assert_eq!(catalog::finished(srv, id).await, "succeeded", "{id} set up again");
    }

    // Agent mode finds it, with the credential the deploy wrote, or once the
    // token it asks for is given.
    let find = || async { server_box_monitor::stacks::mcp::servers(state).await.into_iter().find(|s| s.stack == id).expect("its MCP server") };
    let mut app = find().await;
    if let Credential::Asked { given, .. } = &app.credential {
        assert!(!given);
        let token = provision(state, id, &settings).await;
        let (status, body) = call(srv, Method::PUT, &format!("/api/v1/agent/mcp/apps/{id}/{}", app.index), Some(json!({ "token": token }))).await;
        assert_eq!(status, 200, "{body}");
        app = find().await;
        assert!(app.header.is_some(), "{id}: the token was not taken");
    } else if app.credential == Credential::OAuth {
        let base = format!("http://127.0.0.1:{}", settings["port"]);
        set_up_home_assistant(state, &base).await;
        let url = app.url.clone();
        sign_in(srv, state, id, &url, &base).await;
        app = find().await;
    } else {
        assert_eq!(app.credential, Credential::Secret);
    }
    let deadline = Instant::now() + Duration::from_secs(120);
    let tools = loop {
        let (_, view) = call(srv, Method::GET, "/api/v1/agent/mcp", None).await;
        let found = view["status"].as_array().unwrap().iter().find(|s| s["id"] == fl_pi_llm::host::mcp::server_id(&app.url)).cloned();
        if let Some(s) = found.filter(|s| s["connected"] == true) {
            break s["tools"].as_array().unwrap().clone();
        }
        assert!(Instant::now() < deadline, "{id}: Agent mode never connected: {view}");
        tokio::time::sleep(Duration::from_secs(3)).await;
    };
    assert!(!tools.is_empty(), "{id}: no tools");

    // A read-only tool that needs no arguments answers, through the gate.
    let fetch = state.agent.fetch();
    let headers: Vec<(String, String)> = match &app.credential {
        Credential::OAuth => {
            let id = fl_pi_llm::host::mcp::server_id(&app.url);
            let token = server_box_monitor::agent_mode::mcp_oauth::bearer(&state.db, &fetch, &id).await.expect("signed in");
            vec![("Authorization".into(), token)]
        }
        _ => app.header.clone().into_iter().collect(),
    };
    let client = McpClient::connect(fetch.clone(), McpServerConfig { url: app.url.clone(), headers })
        .await
        .unwrap();
    let listed = client.list_tools().await.unwrap();
    // One that needs the app's credential where the server also has some that
    // do not (a ping), or has none without arguments.
    let named = match id.trim_end_matches("_e2e") {
        "futo.immich" => Some(("list_albums", json!({}))),
        "karakeep.karakeep" => Some(("get-lists", json!({}))),
        "grafana.grafana" => Some(("list_datasources", json!({}))),
        "n8n.n8n" => Some(("search_workflows", json!({}))),
        "triliumnext.trilium" => Some(("search_notes", json!({ "query": "root" }))),
        _ => None,
    };
    let read = listed
        .iter()
        .find(|t| named.as_ref().is_some_and(|(n, _)| t.name == *n))
        .or_else(|| listed.iter().find(|t| named.is_none() && t.read_only && t.input_schema["required"].as_array().is_none_or(|r| r.is_empty())))
        .or_else(|| listed.iter().find(|t| t.input_schema["required"].as_array().is_none_or(|r| r.is_empty()) && t.name.contains("stats")))
        .unwrap_or_else(|| panic!("{id}: no tool to call without arguments: {:?}", listed.iter().map(|t| &t.name).collect::<Vec<_>>()));
    let args = named.map(|(_, args)| args).unwrap_or_else(|| json!({}));
    let answer = client.call(&read.name, args, &Cancel::new()).await;
    eprintln!("{id}: {} -> {:?}", read.name, answer.as_ref().map(|r| r.content.first().cloned()));
    assert!(answer.is_ok(), "{id}: {} failed: {answer:?}", read.name);

    // A sidecar, without the token, nothing: its gate. A service's own server
    // decides that itself.
    if app.publisher != server_box_monitor::stacks::manifest::McpPublisher::Builtin {
        let req = FetchRequest {
            url: app.url.clone(),
            method: "POST".into(),
            headers: vec![("content-type".into(), "application/json".into()), ("accept".into(), "application/json, text/event-stream".into())],
            body: Some(br#"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#.to_vec()),
        };
        let res = fetch.fetch(req).await.unwrap();
        assert_eq!(res.status, 401, "{id}: answered without its token");
    }
    catalog::remove(srv, id).await;
}

#[ntex::test]
#[ignore = "deploys on a real Docker: SBM_E2E_DOCKER=1"]
async fn catalog_apps_mcp_servers_answer_agent_mode() {
    if std::env::var("SBM_E2E_DOCKER").is_err() {
        eprintln!("SBM_E2E_DOCKER is not set");
        return;
    }
    let picked = std::env::var("SBM_E2E_MCP_APPS").map(|v| v.split(',').map(str::to_string).collect::<Vec<_>>());
    let picked = picked.unwrap_or_else(|_| AUTOMATIC.iter().map(|s| s.to_string()).collect());
    let apps = tempfile::tempdir().unwrap();
    let copies: Vec<String> = picked.iter().map(|id| catalog::copy_app(id, apps.path())).collect();
    let config = Config { stacks: Some(StacksConfig { local_apps: Some(apps.path().display().to_string()), ..Default::default() }), ..Default::default() };
    let (srv, state) = common::machine::server_with(config).await;
    for id in &copies {
        verify(&srv, &state, id).await;
    }
}
