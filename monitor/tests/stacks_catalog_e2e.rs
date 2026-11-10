//! Catalog apps on a real Docker, as a desk window reaches them: each app
//! deployed with the settings its check offers (a copy of its `store/apps`
//! folder under a name of its own, so a copy an agent on the same machine
//! deployed is never touched), healthy, its page opened through the agent's
//! proxy over HTTPS, signed in to there with the sign-in its details show,
//! and removed with its data.
//!
//! Opt-in, as `stacks_docker`: it pulls images and runs containers.
//!
//!     SBM_E2E_DOCKER=1 cargo test -p server_box_monitor --test stacks_catalog_e2e -- --ignored --nocapture
//!
//! `SBM_E2E_CATALOG_APPS=gitea.gitea,…` picks the apps; by default every
//! catalog app.

mod common;

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::{Config, ServerConfig, StacksConfig, TlsConfig};

use common::catalog;

/// The password of the accounts this test makes in an app.
const PASSWORD: &str = "e2e-Passw0rd-not-kept";

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    common::machine::call(srv, true, method, path, body).await
}

/// A browser on the app's window: the proxy's origin, the cookies it was
/// given, and the `Origin` and `Referer` a page's own requests carry.
struct Browser {
    client: reqwest::Client,
    origin: String,
    cookies: BTreeMap<String, String>,
}

struct Page {
    status: u16,
    location: Option<String>,
    body: String,
}

impl Page {
    fn json(&self) -> Value {
        serde_json::from_str(&self.body).unwrap_or(Value::Null)
    }
}

impl Browser {
    /// Enters app [id]'s window as the desk does: a ticket from
    /// `POST /stacks/{id}/enter`, opened on the proxy.
    async fn enter(srv: &TestServer, id: &str) -> Self {
        let (status, entry) = call(srv, Method::POST, &format!("/api/v1/stacks/{id}/enter"), None).await;
        assert_eq!(status, 200, "{entry}");
        assert_eq!(entry["tls"], true, "{entry}");
        let client = reqwest::Client::builder()
            .no_proxy()
            .danger_accept_invalid_certs(true)
            // A browser's: some apps tell a page from an API client by it.
            .user_agent("Mozilla/5.0 (X11; Linux x86_64) ServerBox-e2e")
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(60))
            .build()
            .unwrap();
        let mut browser = Browser { client, origin: format!("https://localhost:{}", entry["port"]), cookies: BTreeMap::new() };
        let enter = format!("{}?ticket={}&next=%2F", entry["enter"].as_str().unwrap(), entry["ticket"].as_str().unwrap());
        let page = browser.send(Method::GET, &enter, None, &[]).await;
        assert!(browser.cookies.keys().any(|k| k.starts_with("__sbm_")), "{id}: no session cookie: HTTP {}", page.status);
        browser
    }

    async fn send(&mut self, method: Method, path: &str, body: Option<(&str, Vec<u8>)>, headers: &[(&str, String)]) -> Page {
        let method = reqwest::Method::from_bytes(method.as_str().as_bytes()).unwrap();
        let mut req = self.client.request(method.clone(), format!("{}{path}", self.origin));
        if !self.cookies.is_empty() {
            let jar: Vec<String> = self.cookies.iter().map(|(k, v)| format!("{k}={v}")).collect();
            req = req.header("cookie", jar.join("; "));
        }
        if method != reqwest::Method::GET {
            req = req.header("origin", &self.origin).header("referer", format!("{}{path}", self.origin));
        }
        for (k, v) in headers {
            req = req.header(*k, v);
        }
        if let Some((content_type, bytes)) = body {
            req = req.header("content-type", content_type).body(bytes);
        }
        let res = req.send().await.unwrap_or_else(|e| panic!("{path}: {e}"));
        for cookie in res.headers().get_all("set-cookie") {
            let pair = cookie.to_str().unwrap().split(';').next().unwrap();
            if let Some((k, v)) = pair.split_once('=') {
                if v.is_empty() {
                    self.cookies.remove(k.trim());
                } else {
                    self.cookies.insert(k.trim().to_string(), v.to_string());
                }
            }
        }
        let status = res.status().as_u16();
        let location = res.headers().get("location").and_then(|v| v.to_str().ok()).map(str::to_string);
        Page { status, location, body: res.text().await.unwrap_or_default() }
    }

    async fn get(&mut self, path: &str) -> Page {
        self.send(Method::GET, path, None, &[]).await
    }

    /// GET [path], following the app's redirects on its own origin.
    async fn open(&mut self, path: &str) -> Page {
        let mut path = path.to_string();
        for _ in 0..10 {
            // A navigation's Accept: some apps answer an API request with
            // JSON and a page with their sign-in.
            let page = self.send(Method::GET, &path, None, &[("accept", "text/html,application/xhtml+xml,*/*;q=0.8".into())]).await;
            let Some(to) = page.location.clone().filter(|_| (300..400).contains(&page.status)) else { return page };
            // Resolved as the browser would, against the page that redirected.
            let here = url::Url::parse(&format!("{}{path}", self.origin)).unwrap();
            let there = here.join(&to).unwrap_or_else(|e| panic!("{path} redirected to {to}: {e}"));
            assert_eq!(there.origin(), here.origin(), "{path} redirected off the window's origin to {to}");
            path = there[url::Position::BeforePath..].to_string();
        }
        panic!("{path}: too many redirects")
    }

    async fn post_json(&mut self, path: &str, body: Value, headers: &[(&str, String)]) -> Page {
        self.send(Method::POST, path, Some(("application/json", body.to_string().into_bytes())), headers).await
    }

    async fn post_form(&mut self, path: &str, fields: &[(&str, &str)]) -> Page {
        let form = url::form_urlencoded::Serializer::new(String::new()).extend_pairs(fields).finish();
        self.send(Method::POST, path, Some(("application/x-www-form-urlencoded", form.into_bytes())), &[]).await
    }

    /// A Django sign-in form at [path], filled in and sent as the browser
    /// does: its CSRF token from the page, the cookie it set.
    async fn django_sign_in(&mut self, path: &str, user_field: &str, user: &str, password: &str) -> Page {
        let page = self.open(path).await;
        assert_eq!(page.status, 200, "{path}: {}", page.body);
        let token = input_value(&page.body, "csrfmiddlewaretoken").unwrap_or_else(|| panic!("{path}: no CSRF token"));
        self.post_form(path, &[("csrfmiddlewaretoken", &token), (user_field, user), ("password", password)]).await
    }
}

/// The value of the form input named [name] in [html].
fn input_value(html: &str, name: &str) -> Option<String> {
    inputs(html).into_iter().find(|(n, _)| n == name).map(|(_, v)| v)
}

/// A page's form inputs as a browser submits them: every named input with
/// its value, checkboxes and radios only when checked.
fn inputs(html: &str) -> Vec<(String, String)> {
    let tag = regex::Regex::new(r"(?is)<input\b[^>]*>").unwrap();
    let attr = |t: &str, a: &str| {
        regex::Regex::new(&format!(r#"(?is)\s{a}\s*=\s*(?:"([^"]*)"|'([^']*)')"#))
            .unwrap()
            .captures(t)
            .map(|c| c.get(1).or(c.get(2)).unwrap().as_str().replace("&amp;", "&").replace("&#34;", "\"").replace("&quot;", "\""))
    };
    tag.find_iter(html)
        .filter_map(|m| {
            let t = m.as_str();
            let name = attr(t, "name")?;
            let kind = attr(t, "type").unwrap_or_default().to_ascii_lowercase();
            let checked = regex::Regex::new(r"(?i)\schecked\b").unwrap().is_match(t);
            if (kind == "checkbox" || kind == "radio") && !checked {
                return None;
            }
            Some((name, attr(t, "value").unwrap_or_else(|| if kind == "checkbox" { "on".into() } else { String::new() })))
        })
        .collect()
}

/// The sign-in app [id]'s details show (`POST /stacks/{id}/login`).
async fn login(srv: &TestServer, id: &str) -> (Option<String>, Option<String>) {
    let (status, login) = call(srv, Method::POST, &format!("/api/v1/stacks/{id}/login"), Some(json!({ "current_password": common::PASSWORD }))).await;
    if status == 404 {
        return (None, None);
    }
    assert_eq!(status, 200, "{login}");
    (login["user"].as_str().map(str::to_string), login["password"].as_str().map(str::to_string))
}

/// Waits until app [id] is healthy, as the agent's watch sees it.
async fn healthy(srv: &TestServer, state: &Arc<AppState>, id: &str) {
    let deadline = Instant::now() + Duration::from_secs(900);
    loop {
        server_box_monitor::stacks::health::check(state).await;
        let (_, list) = call(srv, Method::GET, "/api/v1/stacks", None).await;
        let app = list["apps"].as_array().unwrap().iter().find(|a| a["manifest"]["id"] == id).cloned().unwrap_or(Value::Null);
        let now = app["health"]["state"].as_str().unwrap_or_default().to_string();
        if now == "healthy" {
            return;
        }
        assert!(Instant::now() < deadline, "{id}: {now}, never healthy: {}", app["health"]);
        tokio::time::sleep(Duration::from_secs(5)).await;
    }
}

/// Signs in to app [id] in [browser] with the sign-in its details show, as
/// the person would on its page, and checks the app now knows them.
async fn sign_in(browser: &mut Browser, id: &str, user: Option<&str>, password: Option<&str>, settings: &Value) {
    let catalog = id.trim_end_matches("_e2e");
    let need = |v: Option<&str>| v.unwrap_or_else(|| panic!("{id}: its details show no sign-in")).to_string();
    match catalog {
        "openwebui.open_webui" => {
            let page = browser.post_json("/api/v1/auths/signin", json!({ "email": need(user), "password": need(password) }), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            assert_eq!(page.json()["role"], "admin", "{id}: {}", page.body);
            // Sign-up is off once the administrator is made.
            let config = browser.get("/api/config").await.json();
            assert_eq!(config["features"]["enable_signup"], false, "{id}: {config}");
        }
        "paperless.paperless_ngx" => {
            let page = browser.django_sign_in("/accounts/login/", "login", &need(user), &need(password)).await;
            assert_eq!(page.status, 302, "{id}: the sign-in was refused: {}", page.body);
            let me = browser.get("/api/ui_settings/").await;
            assert_eq!(me.status, 200, "{id}: {}", me.body);
            assert_eq!(me.json()["user"]["username"], "admin", "{id}: {}", me.body);
        }
        "sissbruecker.linkding" => {
            let page = browser.django_sign_in("/login/", "username", &need(user), &need(password)).await;
            assert_eq!(page.status, 302, "{id}: the sign-in was refused: {}", page.body);
            let bookmarks = browser.get("/bookmarks").await;
            assert_eq!(bookmarks.status, 200, "{id}: {}", bookmarks.body);
        }
        "mealie.mealie" => {
            // The first account's fixed password was replaced by the seed job.
            let old = browser.post_form("/api/auth/token", &[("username", &need(user)), ("password", "MyPassword")]).await;
            assert_eq!(old.status, 401, "{id}: the default password still signs in");
            let page = browser.post_form("/api/auth/token", &[("username", &need(user)), ("password", &need(password))]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let me = browser.get("/api/users/self").await;
            assert_eq!(me.json()["admin"], true, "{id}: {}", me.body);
        }
        "binwiederhier.ntfy" => {
            use base64::Engine;
            let basic = format!("Basic {}", base64::engine::general_purpose::STANDARD.encode(format!("{}:{}", need(user), need(password))));
            let anonymous = browser.send(Method::POST, "/sbm-e2e", Some(("text/plain", b"hello".to_vec())), &[]).await;
            assert!(matches!(anonymous.status, 401 | 403), "{id}: published without signing in: {}", anonymous.status);
            let published = browser.send(Method::POST, "/sbm-e2e", Some(("text/plain", b"hello".to_vec())), &[("authorization", basic.clone())]).await;
            assert_eq!(published.status, 200, "{id}: {}", published.body);
            let account = browser.send(Method::GET, "/v1/account", None, &[("authorization", basic)]).await;
            assert_eq!(account.json()["role"], "admin", "{id}: {}", account.body);
        }
        "advplyr.audiobookshelf" => {
            assert_eq!(browser.get("/status").await.json()["isInit"], true, "{id}: no root user");
            let page = browser.post_json("/login", json!({ "username": need(user), "password": need(password) }), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            assert_eq!(page.json()["user"]["type"], "root", "{id}: {}", page.body);
        }
        "gitea.gitea" => {
            // The installation page, as its note says: the administrator made
            // there, everything else as offered.
            let install = browser.open("/").await;
            assert_eq!(install.status, 200, "{id}: {}", install.body);
            let mut form = inputs(&install.body);
            assert!(form.iter().any(|(k, v)| k == "db_type" && v == "sqlite3"), "{id}: SQLite not chosen: {form:?}");
            form.retain(|(k, _)| !k.starts_with("admin_"));
            for (k, v) in [("admin_name", "e2e-admin"), ("admin_email", "admin@e2e.invalid"), ("admin_passwd", PASSWORD), ("admin_confirm_passwd", PASSWORD)] {
                form.push((k.into(), v.into()));
            }
            let fields: Vec<(&str, &str)> = form.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect();
            let done = browser.post_form("/", &fields).await;
            // Gitea answers its "installing now" page, or the form again with what it refused.
            let refused = regex::Regex::new(r"(?s)ui negative message.*?<p>(.*?)</p>").unwrap();
            let why = refused.captures(&done.body).map(|c| c[1].trim().to_string());
            assert!(done.status < 400 && done.body.contains("post-install"), "{id}: the installation was refused: HTTP {} {why:?}", done.status);
            // Gitea restarts into its installed self, the administrator signed
            // in; signed out (its cookies gone), the sign-in page.
            let deadline = Instant::now() + Duration::from_secs(120);
            let signin = loop {
                browser.cookies.retain(|k, _| k.starts_with("__sbm_"));
                let page = browser.open("/user/login").await;
                if page.status == 200 && page.body.contains("name=\"user_name\"") {
                    break page;
                }
                assert!(Instant::now() < deadline, "{id}: never installed: HTTP {}", page.status);
                tokio::time::sleep(Duration::from_secs(3)).await;
            };
            let csrf = input_value(&signin.body, "_csrf").unwrap_or_default();
            let page = browser.post_form("/user/login", &[("_csrf", &csrf), ("user_name", "e2e-admin"), ("password", PASSWORD)]).await;
            assert_eq!(page.status, 303, "{id}: the sign-in was refused: {}", page.body);
            // Its site administration answers the administrator only (the API
            // takes tokens, not the page's session).
            let admin = browser.get("/-/admin").await;
            assert_eq!(admin.status, 200, "{id}: not the administrator: HTTP {} {:?}", admin.status, admin.location);
            // Sign-up is off.
            let signup = browser.open("/user/sign_up").await;
            assert!(!signup.body.contains("name=\"user_name\""), "{id}: sign-up is open");
        }
        "karakeep.karakeep" => {
            // Its API key exchange, as its browser extension signs in.
            let made = browser
                .post_json("/api/trpc/apiKeys.exchange", json!({ "json": { "keyName": "e2e", "email": need(user), "password": need(password) } }), &[])
                .await;
            assert_eq!(made.status, 200, "{id}: {}", made.body);
            let key = made.json()["result"]["data"]["json"]["key"].as_str().unwrap().to_string();
            let me = browser.send(Method::GET, "/api/v1/users/me", None, &[("authorization", format!("Bearer {key}"))]).await;
            assert_eq!(me.status, 200, "{id}: {}", me.body);
            // Sign-up is off for everyone else.
            let signup = browser
                .post_json("/api/trpc/users.create", json!({ "json": { "name": "x", "email": "x@e2e.invalid", "password": PASSWORD, "confirmPassword": PASSWORD } }), &[])
                .await;
            assert_eq!(signup.status, 403, "{id}: sign-up is open: {}", signup.body);
        }
        "searxng.searxng" => {
            // No account: a search answers with its results page.
            let results = browser.open("/search?q=serverbox").await;
            assert_eq!(results.status, 200, "{id}");
            assert!(results.body.contains("serverbox"), "{id}: not a results page");
        }
        "sonarr.sonarr" | "radarr.radarr" | "prowlarr.prowlarr" | "lidarr.lidarr" => {
            let api = if matches!(catalog, "prowlarr.prowlarr" | "lidarr.lidarr") { "v1" } else { "v3" };
            assert_eq!(browser.get(&format!("/api/{api}/system/status")).await.status, 401, "{id}: answered before signing in");
            let page = browser.post_form("/login", &[("username", &need(user)), ("password", &need(password)), ("rememberMe", "on")]).await;
            assert_eq!(page.status, 302, "{id}: {}", page.body);
            assert!(!page.location.as_deref().unwrap_or_default().contains("loginFailed"), "{id}: the sign-in was refused");
            // Signed in, the page is given the API key its own requests carry.
            let init = browser.get("/initialize.json").await;
            assert_eq!(init.status, 200, "{id}: {}", init.body);
            let key = init.json()["apiKey"].as_str().unwrap_or_else(|| panic!("{id}: no API key: {}", init.body)).to_string();
            let status = browser.send(Method::GET, &format!("/api/{api}/system/status"), None, &[("x-api-key", key)]).await;
            assert_eq!(status.status, 200, "{id}: {}", status.body);
        }
        "bazarr.bazarr" => {
            // Signed in, its page is given the API key its own requests carry.
            let key = regex::Regex::new(r#""apiKey":\s*"([0-9a-f]+)""#).unwrap();
            assert!(!key.is_match(&browser.open("/").await.body), "{id}: the API key shown before signing in");
            let wrong = browser.post_form("/api/system/account", &[("action", "login"), ("username", &need(user)), ("password", PASSWORD)]).await;
            assert_eq!(wrong.status, 403, "{id}: a wrong password signed in");
            let page = browser.post_form("/api/system/account", &[("action", "login"), ("username", &need(user)), ("password", &need(password))]).await;
            assert_eq!(page.status, 204, "{id}: {}", page.body);
            let index = browser.open("/").await;
            let key = key.captures(&index.body).unwrap_or_else(|| panic!("{id}: no API key once signed in"))[1].to_string();
            let status = browser.send(Method::GET, "/api/system/status", None, &[("x-api-key", key)]).await;
            assert_eq!(status.status, 200, "{id}: {}", status.body);
        }
        "dgtlmoon.changedetection" => {
            // Its page asks for the password from the first start on.
            let form = browser.open("/").await;
            assert!(form.body.contains("name=\"password\""), "{id}: no password asked");
            let csrf = input_value(&form.body, "csrf_token").unwrap_or_else(|| panic!("{id}: no CSRF token"));
            let wrong = browser.post_form("/login", &[("csrf_token", &csrf), ("password", PASSWORD)]).await;
            assert!(browser.open(wrong.location.as_deref().unwrap_or("/")).await.body.contains("name=\"password\""), "{id}: a wrong password signed in");
            let form = browser.open("/login").await;
            let csrf = input_value(&form.body, "csrf_token").unwrap_or_else(|| panic!("{id}: no CSRF token"));
            let page = browser.post_form("/login", &[("csrf_token", &csrf), ("password", &need(password))]).await;
            assert_eq!(page.status, 302, "{id}: {}", page.body);
            let watches = browser.open("/").await;
            assert!(watches.status == 200 && !watches.body.contains("name=\"password\""), "{id}: the sign-in was refused: HTTP {}", watches.status);
        }
        "grafana.grafana" => {
            assert_eq!(browser.get("/api/user").await.status, 401, "{id}: answered before signing in");
            let page = browser.post_json("/login", json!({ "user": need(user), "password": need(password) }), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let me = browser.get("/api/user").await;
            assert_eq!(me.json()["isGrafanaAdmin"], true, "{id}: {}", me.body);
            // Sign-up is off.
            let signup = browser.post_json("/api/user/signup", json!({ "email": "x@e2e.invalid" }), &[]).await;
            assert!(matches!(signup.status, 401 | 403 | 404), "{id}: sign-up is open: HTTP {}", signup.status);
        }
        "n8n.n8n" => {
            // Its session is bound to the browser-id header its page sends.
            let browser_id = [("browser-id", "sbm-e2e".to_string())];
            assert_eq!(browser.send(Method::GET, "/rest/login", None, &browser_id).await.status, 401, "{id}: signed in before signing in");
            let body = json!({ "emailOrLdapLoginId": need(user), "password": need(password) });
            let page = browser.post_json("/rest/login", body, &browser_id).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let me = browser.send(Method::GET, "/rest/login", None, &browser_id).await;
            assert_eq!(me.json()["data"]["role"], "global:owner", "{id}: {}", me.body);
        }
        "triliumnext.trilium" => {
            let logged_in = |page: Page| page.json()["loggedIn"].clone();
            assert_eq!(logged_in(browser.get("/bootstrap").await), false, "{id}: signed in before signing in");
            browser.post_form("/login", &[("password", PASSWORD)]).await;
            assert_eq!(logged_in(browser.get("/bootstrap").await), false, "{id}: a wrong password signed in");
            let page = browser.post_form("/login", &[("password", &need(password))]).await;
            assert_eq!(page.status, 302, "{id}: {}", page.body);
            assert_eq!(logged_in(browser.get("/bootstrap").await), true, "{id}: the sign-in was refused");
        }
        "jgraph.drawio" => {
            // Nothing to sign in to: the editor's own page.
            assert!(browser.open("/").await.body.contains("draw.io"), "{id}: not draw.io's page");
        }
        "schlagmichdoch.pairdrop" => {
            assert!(browser.open("/").await.body.contains("PairDrop"), "{id}: not PairDrop's page");
        }
        "gotify.gotify" => {
            use base64::Engine;
            let basic = |p: &str| format!("Basic {}", base64::engine::general_purpose::STANDARD.encode(format!("{}:{p}", need(user))));
            assert_eq!(browser.get("/current/user").await.status, 401, "{id}: answered before signing in");
            let wrong = browser.send(Method::GET, "/current/user", None, &[("authorization", basic(PASSWORD))]).await;
            assert_eq!(wrong.status, 401, "{id}: a wrong password signed in");
            let me = browser.send(Method::GET, "/current/user", None, &[("authorization", basic(&need(password)))]).await;
            assert_eq!(me.json()["admin"], true, "{id}: {}", me.body);
        }
        "miniflux.miniflux" => {
            let form = browser.open("/").await;
            let csrf = input_value(&form.body, "csrf").unwrap_or_else(|| panic!("{id}: no CSRF token"));
            let wrong = browser.post_form("/login", &[("csrf", &csrf), ("username", &need(user)), ("password", PASSWORD)]).await;
            assert_ne!(wrong.status, 302, "{id}: a wrong password signed in");
            let form = browser.open("/").await;
            let csrf = input_value(&form.body, "csrf").unwrap_or_else(|| panic!("{id}: no CSRF token"));
            let page = browser.post_form("/login", &[("csrf", &csrf), ("username", &need(user)), ("password", &need(password))]).await;
            assert_eq!(page.status, 302, "{id}: the sign-in was refused: {}", page.body);
            let unread = browser.open("/unread").await;
            assert!(unread.status == 200 && !unread.body.contains("name=\"password\""), "{id}: not signed in: HTTP {}", unread.status);
            use base64::Engine;
            let basic = format!("Basic {}", base64::engine::general_purpose::STANDARD.encode(format!("{}:{}", need(user), need(password))));
            let me = browser.send(Method::GET, "/v1/me", None, &[("authorization", basic)]).await;
            assert_eq!(me.json()["is_admin"], true, "{id}: {}", me.body);
        }
        "photoprism.photoprism" => {
            let wrong = browser.post_json("/api/v1/session", json!({ "username": need(user), "password": PASSWORD }), &[]).await;
            assert_eq!(wrong.status, 401, "{id}: a wrong password signed in");
            let page = browser.post_json("/api/v1/session", json!({ "username": need(user), "password": need(password) }), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            assert_eq!(page.json()["user"]["Role"], "admin", "{id}: {}", page.body);
        }
        "siyuan.siyuan" => {
            let before = browser.post_json("/api/notebook/lsNotebooks", json!({}), &[]).await;
            assert_eq!(before.status, 401, "{id}: answered before signing in");
            let wrong = browser.post_json("/api/system/loginAuth", json!({ "authCode": PASSWORD }), &[]).await;
            assert_ne!(wrong.json()["code"], 0, "{id}: a wrong code signed in");
            let page = browser.post_json("/api/system/loginAuth", json!({ "authCode": need(password) }), &[]).await;
            assert_eq!(page.json()["code"], 0, "{id}: {}", page.body);
            let now = browser.post_json("/api/notebook/lsNotebooks", json!({}), &[]).await;
            assert_eq!(now.json()["code"], 0, "{id}: {}", now.body);
        }
        "filebrowser.filebrowser" => {
            let wrong = browser.post_json("/api/login", json!({ "username": need(user), "password": PASSWORD }), &[]).await;
            assert_eq!(wrong.status, 403, "{id}: a wrong password signed in");
            let page = browser.post_json("/api/login", json!({ "username": need(user), "password": need(password) }), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let files = browser.send(Method::GET, "/api/resources/", None, &[("x-auth", page.body.clone())]).await;
            assert_eq!(files.status, 200, "{id}: {}", files.body);
        }
        "kiwix.kiwix" => {
            // No account: its library page.
            assert!(browser.open("/").await.body.to_ascii_lowercase().contains("kiwix"), "{id}: not Kiwix's page");
        }
        "kanboard.kanboard" => {
            use base64::Engine;
            let basic = |p: &str| format!("Basic {}", base64::engine::general_purpose::STANDARD.encode(format!("{}:{p}", need(user))));
            let get_me = json!({ "jsonrpc": "2.0", "method": "getMe", "id": 1 });
            // Its default password no longer signs in.
            let old = browser.post_json("/jsonrpc.php", get_me.clone(), &[("authorization", basic("admin"))]).await;
            assert_eq!(old.status, 401, "{id}: admin/admin still signs in");
            let me = browser.post_json("/jsonrpc.php", get_me, &[("authorization", basic(&need(password)))]).await;
            assert_eq!(me.json()["result"]["role"], "app-admin", "{id}: {}", me.body);
        }
        "grocy.grocy" => {
            let old = browser.post_form("/login", &[("username", &need(user)), ("password", "admin")]).await;
            assert!(old.location.as_deref().unwrap_or_default().contains("invalid"), "{id}: admin/admin still signs in");
            let page = browser.post_form("/login", &[("username", &need(user)), ("password", &need(password))]).await;
            assert!(page.status == 302 && !page.location.as_deref().unwrap_or_default().contains("invalid"), "{id}: the sign-in was refused");
            let me = browser.get("/api/user").await;
            assert_eq!(me.json()[0]["username"], "admin", "{id}: {}", me.body);
        }
        "nodered.node_red" => {
            assert_eq!(browser.get("/flows").await.status, 401, "{id}: the editor's API answered before signing in");
            fn token(p: &str) -> [(&str, &str); 5] {
                [("client_id", "node-red-editor"), ("grant_type", "password"), ("scope", "*"), ("username", "admin"), ("password", p)]
            }
            let wrong = browser.post_form("/auth/token", &token(PASSWORD)).await;
            assert_ne!(wrong.status, 200, "{id}: a wrong password signed in");
            let password = need(password);
            let page = browser.post_form("/auth/token", &token(&password)).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let token = page.json()["access_token"].as_str().unwrap_or_else(|| panic!("{id}: no token: {}", page.body)).to_string();
            let flows = browser.send(Method::GET, "/flows", None, &[("authorization", format!("Bearer {token}"))]).await;
            assert_eq!(flows.status, 200, "{id}: {}", flows.body);
        }
        "ellite.wallos" => {
            // Registration closed once its administrator is made.
            let signup = browser.get("/registration.php").await;
            assert!(signup.location.as_deref().unwrap_or_default().contains("login"), "{id}: registration is open: HTTP {}", signup.status);
            let wrong = browser.post_form("/login.php", &[("username", &need(user)), ("password", PASSWORD)]).await;
            assert_ne!(wrong.status, 302, "{id}: a wrong password signed in");
            let page = browser.post_form("/login.php", &[("username", &need(user)), ("password", &need(password))]).await;
            assert_eq!(page.status, 302, "{id}: the sign-in was refused: {}", page.body);
            let settings = browser.open("/settings.php").await;
            assert!(settings.status == 200 && !settings.body.contains("name=\"password\""), "{id}: not signed in: HTTP {}", settings.status);
        }
        "sysadminsmedia.homebox" => {
            let signup = browser.post_json("/api/v1/users/register", json!({ "name": "x", "email": "x@e2e.invalid", "password": PASSWORD }), &[]).await;
            assert_eq!(signup.status, 403, "{id}: registration is open: {}", signup.body);
            let wrong = browser.post_json("/api/v1/users/login", json!({ "username": need(user), "password": PASSWORD }), &[]).await;
            assert!(wrong.status >= 400, "{id}: a wrong password signed in");
            let page = browser.post_json("/api/v1/users/login", json!({ "username": need(user), "password": need(password), "stayLoggedIn": false }), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let token = page.json()["token"].as_str().unwrap_or_else(|| panic!("{id}: no token: {}", page.body)).to_string();
            let me = browser.send(Method::GET, "/api/v1/users/self", None, &[("authorization", token)]).await;
            assert_eq!(me.status, 200, "{id}: {}", me.body);
        }
        "garethgeorge.backrest" => {
            // Its Connect API, as its page signs in.
            let login = |p: &str| json!({ "username": "admin", "password": p });
            let config = browser.post_json("/v1.Backrest/GetConfig", json!({}), &[]).await;
            assert_eq!(config.status, 401, "{id}: answered before signing in: {}", config.body);
            let wrong = browser.post_json("/v1.Authentication/Login", login(PASSWORD), &[]).await;
            assert_ne!(wrong.status, 200, "{id}: a wrong password signed in");
            let page = browser.post_json("/v1.Authentication/Login", login(&need(password)), &[]).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let token = page.json()["token"].as_str().unwrap_or_else(|| panic!("{id}: no token: {}", page.body)).to_string();
            let config = browser.post_json("/v1.Backrest/GetConfig", json!({}), &[("authorization", format!("Bearer {token}"))]).await;
            assert_eq!(config.status, 200, "{id}: {}", config.body);
            assert_eq!(config.json()["instance"], "serverbox", "{id}: {}", config.body);
        }
        "langfuse.langfuse" => {
            // NextAuth's credentials sign-in, as its page sends it.
            let csrf = browser.get("/api/auth/csrf").await.json()["csrfToken"].as_str().unwrap_or_default().to_string();
            assert!(!csrf.is_empty(), "{id}: no CSRF token");
            let page = browser.post_form("/api/auth/callback/credentials", &[("email", &need(user)), ("password", &need(password)), ("csrfToken", &csrf), ("json", "true")]).await;
            assert!(page.status < 400 && !page.location.as_deref().unwrap_or_default().contains("error"), "{id}: the sign-in was refused: HTTP {} {:?}", page.status, page.location);
            let session = browser.get("/api/auth/session").await;
            assert_eq!(session.json()["user"]["email"], need(user), "{id}: {}", session.body);
            // Sign-up is off.
            let signup = browser.post_json("/api/auth/signup", json!({ "name": "x", "email": "x@e2e.invalid", "password": PASSWORD }), &[]).await;
            assert!(signup.status >= 400, "{id}: sign-up is open: {}", signup.body);
        }
        "toeverything.affine" => {
            let version = [("x-affine-version", "0.27.4".to_string())];
            let wrong = browser.post_json("/api/auth/sign-in", json!({ "email": need(user), "password": PASSWORD }), &version).await;
            assert!(wrong.status >= 400, "{id}: a wrong password signed in");
            let page = browser.post_json("/api/auth/sign-in", json!({ "email": need(user), "password": need(password) }), &version).await;
            assert_eq!(page.status, 200, "{id}: {}", page.body);
            let session = browser.get("/api/auth/session").await;
            assert_eq!(session.json()["user"]["email"], need(user), "{id}: {}", session.body);
            // Sign-up is off: an unknown address is refused a sign-in link
            // (which would make its account).
            let signup = browser.post_json("/api/auth/sign-in", json!({ "email": "x@e2e.invalid" }), &version).await;
            assert_eq!(signup.status, 403, "{id}: sign-up is open: {}", signup.body);
        }
        "juanfont.headscale" => {
            // The API key its note points to, in the data folder.
            let file = std::path::Path::new(settings["data"].as_str().expect("the data folder")).join("headplane-api-key");
            let key = std::fs::read_to_string(&file).unwrap_or_else(|e| panic!("{id}: {}: {e}", file.display())).trim().to_string();
            assert!(key.starts_with("hskey-api-"), "{id}: not an API key");
            let wrong = browser.post_form("/admin/login", &[("api_key", "hskey-api-wrong")]).await;
            assert_ne!(wrong.status, 302, "{id}: a wrong key signed in");
            let page = browser.post_form("/admin/login", &[("api_key", &key)]).await;
            assert_eq!(page.status, 302, "{id}: the sign-in was refused: {}", &page.body[..page.body.len().min(400)]);
            let machines = browser.open("/admin/machines").await;
            assert!(machines.status == 200 && !machines.body.contains("name=\"api_key\""), "{id}: not signed in: HTTP {}", machines.status);
        }
        "excalidraw.excalidraw" => {
            // Nothing to sign in to: the app's own page.
            assert!(browser.open("/").await.body.contains("Excalidraw"), "{id}: not Excalidraw's page");
        }
        "corentinth.it_tools" => {
            // Nothing to sign in to: one of its own routes, which the server
            // answers with the page.
            let tool = browser.open("/uuid-generator").await;
            assert_eq!(tool.status, 200, "{id}");
            assert!(tool.body.contains("IT Tools"), "{id}: {}", &tool.body[..tool.body.len().min(400)]);
        }
        _ => eprintln!("{id}: the page only"),
    }
}

/// A ZIM file put in Kiwix's folder (`SBM_E2E_KIWIX_ZIM`, a small one such as
/// wikipedia_en_ray-charles_nopic) is served within its minute, without a
/// restart.
async fn kiwix_serves_a_zim(browser: &mut Browser, settings: &Value) {
    let Ok(zim) = std::env::var("SBM_E2E_KIWIX_ZIM") else {
        eprintln!("kiwix: SBM_E2E_KIWIX_ZIM is not set: no ZIM file served");
        return;
    };
    let folder = std::path::PathBuf::from(settings["zims"].as_str().expect("the ZIM folder"));
    let copy = folder.join("sbm-e2e.zim");
    std::fs::copy(&zim, &copy).unwrap();
    let deadline = Instant::now() + Duration::from_secs(120);
    loop {
        let entries = browser.get("/catalog/v2/entries").await;
        if entries.body.contains("<entry>") {
            break;
        }
        assert!(Instant::now() < deadline, "kiwix: the ZIM file never served: {}", entries.body);
        tokio::time::sleep(Duration::from_secs(5)).await;
    }
    std::fs::remove_file(&copy).unwrap();
}

async fn verify(srv: &TestServer, state: &Arc<AppState>, id: &str) {
    eprintln!("== {id}");
    let started = Instant::now();
    let (settings, _cleanup) = catalog::deploy(srv, id).await;
    healthy(srv, state, id).await;

    let mut browser = Browser::enter(srv, id).await;
    let path = state.stacks.package(id).unwrap().manifest.web.as_ref().unwrap().path.clone();
    let page = browser.open(&path).await;
    assert_eq!(page.status, 200, "{id}: its page: {}", &page.body[..page.body.len().min(400)]);
    assert!(page.body.to_ascii_lowercase().contains("<html"), "{id}: not a page: {}", &page.body[..page.body.len().min(400)]);

    let (user, password) = login(srv, id).await;
    sign_in(&mut browser, id, user.as_deref(), password.as_deref(), &settings).await;
    if id.trim_end_matches("_e2e") == "kiwix.kiwix" {
        kiwix_serves_a_zim(&mut browser, &settings).await;
    }

    catalog::remove(srv, id).await;
    eprintln!("{id}: ok in {:?}", started.elapsed());
}

#[ntex::test]
#[ignore = "deploys on a real Docker: SBM_E2E_DOCKER=1"]
async fn catalog_apps_open_and_sign_in_through_the_desk() {
    if std::env::var("SBM_E2E_DOCKER").is_err() {
        eprintln!("SBM_E2E_DOCKER is not set");
        return;
    }
    let picked = match std::env::var("SBM_E2E_CATALOG_APPS") {
        Ok(v) => v.split(',').map(str::to_string).collect::<Vec<_>>(),
        Err(_) => server_box_monitor::stacks::builtin::packages().iter().map(|p| p.manifest.id.clone()).collect(),
    };
    let apps = tempfile::tempdir().unwrap();
    let copies: Vec<String> = picked.iter().map(|id| catalog::copy_app(id, apps.path())).collect();

    // The agent on HTTPS, so its proxy is too: what the desk's apps see
    // behind it (cookies, X-Forwarded-Proto, the CSRF checks).
    let rcgen::CertifiedKey { cert, signing_key } = rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
    let (cert_path, key_path) = (apps.path().join("tls.crt"), apps.path().join("tls.key"));
    std::fs::write(&cert_path, cert.pem()).unwrap();
    std::fs::write(&key_path, signing_key.serialize_pem()).unwrap();
    let config = Config {
        server: Some(ServerConfig {
            host: "127.0.0.1".into(),
            port: 0,
            tls: Some(TlsConfig { cert_path: cert_path.display().to_string(), key_path: key_path.display().to_string() }),
            ..Default::default()
        }),
        stacks: Some(StacksConfig { local_apps: Some(apps.path().display().to_string()), ..Default::default() }),
        ..Default::default()
    };
    let (srv, state) = common::machine::server_with(config).await;
    for id in &copies {
        verify(&srv, &state, id).await;
    }
}
