//! Reverse proxies for real, as root on a throwaway Linux (a container):
//! each server installed through the agent, a site written and served
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

mod common;

use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::core::config::Config;

const UPSTREAM: u16 = 18980;
const MARK: &str = "sbm-proxy-ok";

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    common::machine::call(srv, true, method, path, body).await
}

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
    json!({ "name": "e2e", "domains": [domain], "upstream": upstream, "tls": tls })
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

async fn view(srv: &TestServer, server: &str) -> Value {
    let (status, body) = call(srv, Method::GET, "/api/v1/proxy", None).await;
    assert_eq!(status, 200, "{body}");
    body["servers"].as_array().unwrap().iter().find(|s| s["server"] == server).cloned().unwrap()
}

async fn install(srv: &TestServer, server: &str) {
    let (status, body) = call(srv, Method::POST, &format!("/api/v1/proxy/{server}/install"), Some(json!({}))).await;
    assert_eq!(status, 202, "{server}: {body}");
    let deadline = Instant::now() + Duration::from_secs(1200);
    loop {
        let (_, job) = call(srv, Method::GET, "/api/v1/proxy/job", None).await;
        match job["state"].as_str() {
            Some("running") => {}
            Some("succeeded") => break,
            _ => {
                let lines: Vec<&str> = job["lines"].as_array().into_iter().flatten().filter_map(|l| l["text"].as_str()).collect();
                panic!("{server} install: {}\n{}", job["state"], lines.join("\n"));
            }
        }
        assert!(Instant::now() < deadline, "{server}: the install did not end");
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

async fn put(srv: &TestServer, server: &str, sites: Value) -> (u16, Value) {
    call(srv, Method::PUT, &format!("/api/v1/proxy/{server}/sites"), Some(json!({ "sites": sites }))).await
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

async fn verify(srv: &TestServer, server: &str) {
    eprintln!("== {server}");
    install(srv, server).await;
    let v = view(srv, server).await;
    eprintln!("{server} {} active={}", v["version"], v["active"]);
    assert_eq!(v["installed"], true, "{v}");

    // A site, served.
    let (status, body) = put(srv, server, json!([site("e2e.test", false, &format!("http://127.0.0.1:{UPSTREAM}"))])).await;
    assert_eq!(status, 200, "{server}: {body}");
    let v = view(srv, server).await;
    assert!(v["sites"].as_array().unwrap().iter().any(|s| s["name"] == "e2e" && s["managed"] == true), "{v}");
    assert!(served("e2e.test", false).await, "{server}: e2e.test is not sent on");

    // nginx refuses an upstream it cannot resolve; the site before stays.
    if server == "nginx" {
        let (status, body) = put(srv, server, json!([site("e2e.test", false, "http://no-such-host.invalid:1")])).await;
        assert_eq!((status, body["error"].as_str()), (409, Some("refused")), "{body}");
        assert!(served("e2e.test", false).await, "nginx: the previous site did not stay");
    }
    // Caddy's own certificate for a local name.
    if server == "caddy" {
        let (status, body) = put(srv, server, json!([site("e2e.localhost", true, &format!("http://127.0.0.1:{UPSTREAM}"))])).await;
        assert_eq!(status, 200, "{body}");
        assert!(served("e2e.localhost", true).await, "caddy: no HTTPS for e2e.localhost");
    }

    // Taken away.
    let (status, body) = put(srv, server, json!([])).await;
    assert_eq!(status, 200, "{body}");
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
    assert_eq!(unsafe { libc_geteuid() }, 0, "root only, on a throwaway machine");
    upstream();
    let (srv, _state) = common::machine::server_with(Config::default()).await;
    let picked = std::env::var("SBM_E2E_PROXY_SERVERS").unwrap_or_else(|_| "nginx,caddy,traefik".into());
    for server in picked.split(',') {
        verify(&srv, server).await;
    }
}

unsafe extern "C" {
    #[link_name = "geteuid"]
    fn libc_geteuid() -> u32;
}
