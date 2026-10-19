//! The web application firewall for real, as root on a throwaway Linux (a
//! container), through the Reverse proxy package (`serverbox.proxy`): a
//! reverse proxy installed and a site behind the firewall;
//! an ordinary request passes, an XSS attempt is refused in blocking mode
//! and passes when only detecting, the audit log names the rules, and
//! the rules left out let it through again.
//!
//!     SBM_E2E_WAF=1 cargo test -p server_box_monitor --test waf_e2e -- --ignored --nocapture
//!
//! `SBM_E2E_WAF_SERVERS=nginx,traefik` picks the servers (Traefik fetches
//! its plugin from the network).

#![cfg(target_os = "linux")]

mod common;

use std::time::{Duration, Instant};

use common::package::App;
use serde_json::json;
use server_box_monitor::core::config::Config;

const UPSTREAM: u16 = 18981;
const MARK: &str = "sbm-waf-ok";
const ATTACK: &str = "/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E";

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

async fn settings(app: &App<'_>, server: &str, mode: &str, exclusions: &[u32]) {
    let r = app.call("setWaf", json!({ "server": server, "settings": { "mode": mode, "paranoia": 1, "exclusions": exclusions } }), true).await;
    assert!(r.is_ok(), "{server} {mode}: {r:?}");
}

async fn verify(app: &App<'_>, server: &str) {
    eprintln!("== {server}");
    let hour = Duration::from_secs(1200);
    app.job_ok("install", json!({ "server": server, "acmeEmail": null }), true, hour).await;
    app.job_ok("installWaf", json!({ "server": server }), true, hour).await;
    let v = app.call("waf", json!(null), false).await.unwrap();
    assert_eq!(v[server]["ready"], true, "{v}");

    // A site behind the firewall before its rules: refused.
    let site = json!([{ "name": "e2e", "domains": ["e2e.test"], "upstream": format!("http://127.0.0.1:{UPSTREAM}"), "tls": false, "cert": null, "key": null, "maxBodyMb": null, "waf": true, "managed": true }]);
    let sites = json!({ "server": server, "sites": site });
    let refusal = app.call("setSites", sites.clone(), true).await.unwrap_err();
    assert_eq!((refusal.error.as_str(), refusal.message.as_str()), ("failedPrecondition", "wafNotSet"), "{refusal:?}");

    settings(app, server, "block", &[]).await;
    app.call("setSites", sites, true).await.unwrap();
    until("/", 200, server).await;
    until(ATTACK, 403, server).await;

    // Detecting only: it passes.
    settings(app, server, "detect", &[]).await;
    until(ATTACK, 200, server).await;

    // The audit log says which rules matched.
    let events = app.call("wafEvents", json!({ "server": server }), true).await.unwrap();
    let ours = events.as_array().unwrap().iter().find(|e| e["uri"].as_str().is_some_and(|u| u.contains("script"))).unwrap_or_else(|| panic!("no event: {events}"));
    eprintln!("{server} event: {} {} {}", ours["status"], ours["uri"], ours["rules"]);
    let left_out: Vec<u32> =
        ours["rules"].as_array().unwrap().iter().filter_map(|r| r[0].as_str()?.parse().ok()).filter(|id: &u32| (941000..942000).contains(id)).collect();
    assert!(!left_out.is_empty());
    let numeric_host = ours["rules"].as_array().unwrap().iter().any(|r| r[0] == "920350");
    assert!(!(server == "traefik" && numeric_host), "the plugin's numeric Host was scored: {ours}");
    // Blocking again, those rules left out: it passes.
    settings(app, server, "block", &left_out).await;
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
    assert_eq!(unsafe { libc::geteuid() }, 0, "root only, on a throwaway machine");
    upstream();
    let (srv, _state) = common::machine::server_with(Config::default()).await;
    let app = common::package::install(&srv, "serverbox.proxy").await;
    let picked = std::env::var("SBM_E2E_WAF_SERVERS").unwrap_or_else(|_| "nginx,traefik".into());
    for server in picked.split(',') {
        verify(&app, server).await;
        let stop = if server == "nginx" { "nginx -s stop" } else { "pkill -x traefik" };
        let _ = std::process::Command::new("sh").arg("-c").arg(stop).output();
        std::thread::sleep(Duration::from_secs(2));
    }
}
