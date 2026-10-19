//! Reverse proxies for real, as root on a throwaway Linux (a container):
//! the Reverse proxy package (`serverbox.proxy`, the one the agent ships)
//! installed, each server installed through it, a site written and served
//! (a request for its name reaches the upstream this test runs), a change
//! the server refuses rolled back while the site keeps answering, HTTPS
//! through Caddy's own CA, and the sites taken away again.
//!
//! Opt-in and root only: it installs packages and writes `/etc`.
//!
//!     SBM_E2E_PROXY=1 cargo test -p server_box_monitor --test proxy_e2e -- --ignored --nocapture
//!
//! `SBM_E2E_PROXY_SERVERS=nginx,caddy,traefik` picks the servers (one at a
//! time on ports 80 and 443, each stopped after).

#![cfg(target_os = "linux")]

mod common;

use std::time::{Duration, Instant};

use common::package::App;
use serde_json::{Value, json};
use server_box_monitor::core::config::Config;

const UPSTREAM: u16 = 18980;
const MARK: &str = "sbm-proxy-ok";

/// The service the sites send on to: every request answered with [MARK].
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

fn site(domain: &str, tls: bool, upstream: &str) -> Value {
    json!({ "name": "e2e", "domains": [domain], "upstream": upstream, "tls": tls, "cert": null, "key": null, "maxBodyMb": null, "waf": false, "managed": true })
}

/// What a request for [host] gets through the proxy on this machine.
async fn fetch(host: &str, https: bool) -> Option<String> {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let port = if https { 443 } else { 80 };
    let client = reqwest::Client::builder()
        .no_proxy()
        .danger_accept_invalid_certs(true)
        .resolve(host, std::net::SocketAddr::from(([127, 0, 0, 1], port)))
        .timeout(Duration::from_secs(10))
        .build()
        .unwrap();
    let url = format!("{}://{host}/", if https { "https" } else { "http" });
    let res = client.get(url).send().await.ok()?;
    if !res.status().is_success() {
        return None;
    }
    res.text().await.ok()
}

async fn served(host: &str, https: bool) -> bool {
    let deadline = Instant::now() + Duration::from_secs(60);
    loop {
        if fetch(host, https).await.as_deref() == Some(MARK) {
            return true;
        }
        if Instant::now() > deadline {
            return false;
        }
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

async fn view(app: &App<'_>, server: &str) -> Value {
    let v = app.call("view", json!(null), false).await.unwrap();
    v["servers"].as_array().unwrap().iter().find(|s| s["server"] == server).cloned().unwrap()
}

async fn install(app: &App<'_>, server: &str) {
    app.job_ok("install", json!({ "server": server, "acmeEmail": null }), true, Duration::from_secs(1200)).await;
}

async fn put(app: &App<'_>, server: &str, sites: Value) -> Result<Value, common::package::Refusal> {
    app.call("setSites", json!({ "server": server, "sites": sites }), true).await
}

fn stop(server: &str) {
    let cmd = match server {
        "nginx" => "nginx -s stop",
        "caddy" => "caddy stop",
        _ => "pkill -x traefik",
    };
    let _ = std::process::Command::new("sh").arg("-c").arg(cmd).output();
    std::thread::sleep(Duration::from_secs(2));
}

async fn verify(app: &App<'_>, server: &str) {
    eprintln!("== {server}");
    install(app, server).await;
    let v = view(app, server).await;
    eprintln!("{server} {} active={}", v["version"], v["active"]);
    assert_eq!(v["installed"], true, "{v}");

    // A site, served.
    put(app, server, json!([site("e2e.test", false, &format!("http://127.0.0.1:{UPSTREAM}"))])).await.unwrap();
    let v = view(app, server).await;
    assert!(v["sites"].as_array().unwrap().iter().any(|s| s["name"] == "e2e" && s["managed"] == true), "{v}");
    assert!(served("e2e.test", false).await, "{server}: e2e.test is not sent on");

    // nginx refuses an upstream it cannot resolve; the site before stays.
    if server == "nginx" {
        let refusal = put(app, server, json!([site("e2e.test", false, "http://no-such-host.invalid:1")])).await.unwrap_err();
        assert_eq!(refusal.error, "failedPrecondition", "{refusal:?}");
        assert!(refusal.message.starts_with("refused\n"), "{refusal:?}");
        assert!(served("e2e.test", false).await, "nginx: the previous site did not stay");
    }
    // Caddy's own certificate for a local name.
    if server == "caddy" {
        put(app, server, json!([site("e2e.localhost", true, &format!("http://127.0.0.1:{UPSTREAM}"))])).await.unwrap();
        assert!(served("e2e.localhost", true).await, "caddy: no HTTPS for e2e.localhost");
    }

    // Taken away.
    put(app, server, json!([])).await.unwrap();
    // Traefik notices its folder changed within a few seconds.
    let deadline = Instant::now() + Duration::from_secs(30);
    while fetch("e2e.test", false).await.as_deref() == Some(MARK) {
        assert!(Instant::now() < deadline, "{server}: the site stayed");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
    stop(server);
}

#[ntex::test]
#[ignore = "installs reverse proxies as root: SBM_E2E_PROXY=1 on a throwaway machine"]
async fn proxies_serve_and_roll_back() {
    if std::env::var("SBM_E2E_PROXY").is_err() {
        eprintln!("SBM_E2E_PROXY is not set");
        return;
    }
    // SAFETY: a libc call with no arguments.
    assert_eq!(unsafe { libc::geteuid() }, 0, "root only, on a throwaway machine");
    upstream();
    let (srv, _state) = common::machine::server_with(Config::default()).await;
    let app = common::package::install(&srv, "serverbox.proxy").await;
    let picked = std::env::var("SBM_E2E_PROXY_SERVERS").unwrap_or_else(|_| "nginx,caddy,traefik".into());
    for server in picked.split(',') {
        verify(&app, server).await;
    }
}
