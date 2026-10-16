//! The web application firewall for real, as root on a throwaway Linux (a
//! container): a reverse proxy installed and a site behind the firewall;
//! an ordinary request passes, an XSS attempt is refused in blocking mode
//! and passes when only detecting, the audit log names the rules, and
//! the rules left out let it through again.
//!
//!     SBM_E2E_WAF=1 cargo test -p server_box_monitor --test waf_e2e -- --ignored --nocapture
//!
//! `SBM_E2E_WAF_SERVERS=nginx,traefik` picks the servers (Traefik fetches
//! its plugin from the network).

mod common;

use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::core::config::Config;

const UPSTREAM: u16 = 18981;
const MARK: &str = "sbm-waf-ok";
const ATTACK: &str = "/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E";

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    common::machine::call(srv, true, method, path, body).await
}

fn upstream() {
    std::thread::spawn(|| {
        use std::io::{Read, Write};
        let listener = std::net::TcpListener::bind(("127.0.0.1", UPSTREAM)).unwrap();
        for stream in listener.incoming() {
            let Ok(mut s) = stream else { continue };
            let mut buf = [0u8; 4096];
            let _ = s.read(&mut buf);
            let _ = write!(s, "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{MARK}", MARK.len());
        }
    });
}

/// The status a request for [path] on e2e.test gets through the proxy.
async fn status(path: &str) -> u16 {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let client = reqwest::Client::builder().no_proxy().timeout(Duration::from_secs(10)).build().unwrap();
    match client.get(format!("http://127.0.0.1{path}")).header("Host", "e2e.test").send().await {
        Ok(r) => r.status().as_u16(),
        Err(_) => 0,
    }
}

/// Waits until [path] gets [want].
async fn until(path: &str, want: u16, what: &str) {
    let deadline = Instant::now() + Duration::from_secs(60);
    loop {
        let got = status(path).await;
        if got == want {
            return;
        }
        assert!(Instant::now() < deadline, "{what}: {path} got {got}, not {want}");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

async fn job(srv: &TestServer, what: &str) {
    let deadline = Instant::now() + Duration::from_secs(1200);
    loop {
        let (_, job) = call(srv, Method::GET, "/api/v1/proxy/job", None).await;
        match job["state"].as_str() {
            Some("running") => {}
            Some("succeeded") => return,
            _ => {
                let lines: Vec<&str> = job["lines"].as_array().into_iter().flatten().filter_map(|l| l["text"].as_str()).collect();
                panic!("{what}: {}\n{}", job["state"], lines.join("\n"));
            }
        }
        assert!(Instant::now() < deadline, "{what} did not end");
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

async fn settings(srv: &TestServer, server: &str, mode: &str, exclusions: &[u32]) {
    let (s, body) = call(srv, Method::PUT, &format!("/api/v1/waf/{server}"), Some(json!({ "settings": { "mode": mode, "paranoia": 1, "exclusions": exclusions } }))).await;
    assert_eq!(s, 200, "{server} {mode}: {body}");
}

async fn verify(srv: &TestServer, server: &str) {
    eprintln!("== {server}");
    let (s, body) = call(srv, Method::POST, &format!("/api/v1/proxy/{server}/install"), Some(json!({}))).await;
    assert_eq!(s, 202, "{body}");
    job(srv, &format!("{server} install")).await;
    let (s, body) = call(srv, Method::POST, &format!("/api/v1/waf/{server}/install"), Some(json!({}))).await;
    assert_eq!(s, 202, "{body}");
    job(srv, &format!("{server} firewall install")).await;
    let (_, v) = call(srv, Method::GET, "/api/v1/waf", None).await;
    assert_eq!(v[server]["ready"], true, "{v}");

    // A site behind the firewall before its rules: refused.
    let site = json!([{ "name": "e2e", "domains": ["e2e.test"], "upstream": format!("http://127.0.0.1:{UPSTREAM}"), "tls": false, "waf": true }]);
    let (s, body) = call(srv, Method::PUT, &format!("/api/v1/proxy/{server}/sites"), Some(json!({ "sites": site }))).await;
    assert_eq!((s, body["error"].as_str()), (409, Some("wafNotSet")), "{body}");

    settings(srv, server, "block", &[]).await;
    let (s, body) = call(srv, Method::PUT, &format!("/api/v1/proxy/{server}/sites"), Some(json!({ "sites": site }))).await;
    assert_eq!(s, 200, "{body}");
    until("/", 200, server).await;
    until(ATTACK, 403, server).await;

    // Detecting only: it passes.
    settings(srv, server, "detect", &[]).await;
    until(ATTACK, 200, server).await;

    // The audit log says which rules matched.
    let (s, body) = call(srv, Method::POST, &format!("/api/v1/waf/{server}/events"), Some(json!({}))).await;
    assert_eq!(s, 200, "{body}");
    let events = body["events"].as_array().unwrap();
    let ours = events.iter().find(|e| e["uri"].as_str().is_some_and(|u| u.contains("script"))).unwrap_or_else(|| panic!("no event: {body}"));
    eprintln!("{server} event: {} {} {}", ours["status"], ours["uri"], ours["rules"]);
    let left_out: Vec<u32> =
        ours["rules"].as_array().unwrap().iter().filter_map(|r| r[0].as_str()?.parse().ok()).filter(|id: &u32| (941000..942000).contains(id)).collect();
    assert!(!left_out.is_empty());
    let numeric_host = ours["rules"].as_array().unwrap().iter().any(|r| r[0] == "920350");
    assert!(!(server == "traefik" && numeric_host), "the plugin's numeric Host was scored: {ours}");
    // Blocking again, those rules left out: it passes.
    settings(srv, server, "block", &left_out).await;
    until(ATTACK, 200, server).await;
    until("/", 200, server).await;
}

#[ntex::test]
#[ignore = "installs a firewall as root: SBM_E2E_WAF=1 on a throwaway machine"]
async fn the_firewall_refuses_and_lets_through() {
    if std::env::var("SBM_E2E_WAF").is_err() {
        eprintln!("SBM_E2E_WAF is not set");
        return;
    }
    // SAFETY: a libc call with no arguments.
    assert_eq!(unsafe { libc_geteuid() }, 0, "root only, on a throwaway machine");
    upstream();
    let (srv, _state) = common::machine::server_with(Config::default()).await;
    let picked = std::env::var("SBM_E2E_WAF_SERVERS").unwrap_or_else(|_| "nginx,traefik".into());
    for server in picked.split(',') {
        verify(&srv, server).await;
        let stop = if server == "nginx" { "nginx -s stop" } else { "pkill -x traefik" };
        let _ = std::process::Command::new("sh").arg("-c").arg(stop).output();
        std::thread::sleep(Duration::from_secs(2));
    }
}

unsafe extern "C" {
    #[link_name = "geteuid"]
    fn libc_geteuid() -> u32;
}
