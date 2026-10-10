//! The agent in front of each deployed web app: a listener of its own per
//! app (its own port, so its own origin), forwarding to the service on
//! loopback, so a desk window can frame it.
//!
//! - **Who gets through**: a signed-in account. The window opens
//!   `/__sbm/enter?ticket=…&next=…` with a ticket from
//!   `POST /stacks/{id}/enter` (`Purpose::Proxy`, single use, seconds); the
//!   answer sets an `HttpOnly` cookie (`__sbm_<id>`) naming a session here,
//!   12 h, ended when the account's password changes or it goes. Without it a
//!   request gets a page saying to open the app from the desk. The service's
//!   own login does the rest.
//! - **What is forwarded**: HTTP/1.1 both ways streamed, WebSocket upgrades
//!   spliced. The session cookie never reaches the service. Responses lose
//!   `X-Frame-Options` and get `frame-ancestors` for the panel's origins;
//!   over TLS their cookies are made `SameSite=None; Secure`, so a frame on
//!   another site (a panel on Cloudflare Pages) keeps the service's login.
//! - Cookies ignore ports: apps proxied on one host share a cookie jar, the
//!   service's own cookies included. The session cookie is `HttpOnly`, so an
//!   app's scripts cannot read another's.

use std::collections::HashMap;
use std::convert::Infallible;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use http_body_util::{BodyExt, Empty, Full, combinators::BoxBody};
use hyper::body::{Bytes, Incoming};
use hyper::header::{self, HeaderMap, HeaderName, HeaderValue};
use hyper::{Request, Response, StatusCode};
use hyper_util::client::legacy::{Client, connect::HttpConnector};
use hyper_util::rt::{TokioExecutor, TokioIo};
use tokio::net::TcpListener;
use tokio::task::JoinHandle;

use crate::api::server::AppState;
use crate::api::ws::ticket::Purpose;
use crate::utils::secrets::random_hex;

const SESSION_TTL: Duration = Duration::from_secs(12 * 3600);
/// How often a session's account is looked up again.
const RECHECK: Duration = Duration::from_secs(60);
const MAX_SESSIONS: usize = 4096;
pub const ENTER_PATH: &str = "/__sbm/enter";

type Body = BoxBody<Bytes, hyper::Error>;

struct Session {
    username: String,
    since: i64,
    stack: String,
    expires: Instant,
    checked: Instant,
}

struct Listening {
    port: u16,
    task: JoinHandle<()>,
}

/// Every proxy listener and session of this agent.
#[derive(Default)]
pub struct Proxies {
    listening: Mutex<HashMap<String, Listening>>,
    sessions: Mutex<HashMap<String, Session>>,
}

/// One app to put a listener in front of.
pub struct Target {
    pub stack: String,
    pub listen: SocketAddr,
    pub upstream_port: u16,
    pub tls: Option<Arc<rustls::ServerConfig>>,
    /// Origins besides the agent's own host that may frame the app.
    pub frame_origins: Vec<String>,
}

impl Drop for Proxies {
    fn drop(&mut self) {
        for (_, l) in self.listening.get_mut().unwrap_or_else(|e| e.into_inner()).drain() {
            l.task.abort();
        }
    }
}

impl Proxies {
    /// The port [stack]'s listener is on, while it is.
    pub fn port(&self, stack: &str) -> Option<u16> {
        self.listening.lock().unwrap_or_else(|e| e.into_inner()).get(stack).map(|l| l.port)
    }

    /// Starts [target]'s listener, replacing one [target]'s stack had.
    pub async fn start(&self, state: Arc<AppState>, target: Target) -> std::io::Result<()> {
        self.stop(&target.stack);
        let listener = TcpListener::bind(target.listen).await?;
        let port = listener.local_addr()?.port();
        let stack = target.stack.clone();
        let ctx = Arc::new(Ctx {
            state,
            stack: target.stack,
            upstream_port: target.upstream_port,
            secure: target.tls.is_some(),
            frame_origins: target.frame_origins,
            client: Client::builder(TokioExecutor::new()).build(HttpConnector::new()),
        });
        let acceptor = target.tls.map(|config| {
            let mut config = (*config).clone();
            config.alpn_protocols = vec![b"http/1.1".to_vec()];
            tokio_rustls::TlsAcceptor::from(Arc::new(config))
        });
        let task = tokio::spawn(async move {
            loop {
                let Ok((stream, peer)) = listener.accept().await else { continue };
                let ctx = ctx.clone();
                let acceptor = acceptor.clone();
                tokio::spawn(async move {
                    let service = hyper::service::service_fn(move |req| {
                        let ctx = ctx.clone();
                        async move { Ok::<_, Infallible>(handle(&ctx, req, peer).await) }
                    });
                    let http = hyper::server::conn::http1::Builder::new();
                    let result = match acceptor {
                        Some(acceptor) => match acceptor.accept(stream).await {
                            Ok(tls) => http.serve_connection(TokioIo::new(tls), service).with_upgrades().await,
                            Err(_) => return,
                        },
                        None => http.serve_connection(TokioIo::new(stream), service).with_upgrades().await,
                    };
                    if let Err(e) = result {
                        tracing::debug!("app proxy connection: {e}");
                    }
                });
            }
        });
        self.listening.lock().unwrap_or_else(|e| e.into_inner()).insert(stack, Listening { port, task });
        Ok(())
    }

    pub fn stop(&self, stack: &str) {
        if let Some(l) = self.listening.lock().unwrap_or_else(|e| e.into_inner()).remove(stack) {
            l.task.abort();
        }
        self.sessions.lock().unwrap_or_else(|e| e.into_inner()).retain(|_, s| s.stack != stack);
    }

    /// Ends [username]'s sessions: its password changed or it went.
    pub fn end_account(&self, username: &str) {
        self.sessions.lock().unwrap_or_else(|e| e.into_inner()).retain(|_, s| s.username != username);
    }

    fn open_session(&self, username: String, since: i64, stack: &str) -> Option<String> {
        let token = random_hex(32).ok()?;
        let now = Instant::now();
        let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
        sessions.retain(|_, s| s.expires > now);
        if sessions.len() >= MAX_SESSIONS {
            return None;
        }
        sessions.insert(
            token.clone(),
            Session { username, since, stack: stack.to_string(), expires: now + SESSION_TTL, checked: now },
        );
        Some(token)
    }
}

struct Ctx {
    state: Arc<AppState>,
    stack: String,
    upstream_port: u16,
    secure: bool,
    frame_origins: Vec<String>,
    client: Client<HttpConnector, Incoming>,
}

impl Ctx {
    fn cookie_name(&self) -> String {
        format!("__sbm_{}", self.stack)
    }

    /// Whether [token] names a live session for this app, its account looked
    /// up again when it was last looked up a while ago.
    async fn admits(&self, token: &str) -> bool {
        let proxies = &self.state.stacks.proxies;
        let (username, since, recheck) = {
            let sessions = proxies.sessions.lock().unwrap_or_else(|e| e.into_inner());
            match sessions.get(token) {
                Some(s) if s.stack == self.stack && s.expires > Instant::now() => {
                    (s.username.clone(), s.since, s.checked.elapsed() >= RECHECK)
                }
                _ => return false,
            }
        };
        if recheck {
            let current = crate::api::authz::caller_named(&self.state, &username).await;
            let mut sessions = proxies.sessions.lock().unwrap_or_else(|e| e.into_inner());
            if current.is_none_or(|c| c.since != since) {
                sessions.remove(token);
                return false;
            }
            if let Some(s) = sessions.get_mut(token) {
                s.checked = Instant::now();
            }
        }
        true
    }
}

fn full(status: StatusCode, content_type: &'static str, body: impl Into<Bytes>) -> Response<Body> {
    let mut resp = Response::new(Full::new(body.into()).map_err(|never| match never {}).boxed());
    *resp.status_mut() = status;
    resp.headers_mut().insert(header::CONTENT_TYPE, HeaderValue::from_static(content_type));
    resp.headers_mut().insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    resp
}

fn sign_in_page() -> Response<Body> {
    full(
        StatusCode::UNAUTHORIZED,
        "text/html; charset=utf-8",
        "<!doctype html><meta charset=utf-8><meta name=viewport content=\"width=device-width\">\
         <title>ServerBox</title><p style=\"font:15px system-ui;margin:3em;text-align:center\">\
         Open this app from the ServerBox desk.</p>",
    )
}

/// The query's [name], percent-decoded.
fn query_param(query: Option<&str>, name: &str) -> Option<String> {
    url::form_urlencoded::parse(query?.as_bytes()).find(|(k, _)| k == name).map(|(_, v)| v.into_owned())
}

/// A path on this origin to go to after entering: never another host.
fn local_path(next: Option<String>) -> String {
    match next {
        Some(n) if n.starts_with('/') && !n.starts_with("//") && !n.starts_with("/\\") && !n.contains(['\r', '\n']) => n,
        _ => "/".into(),
    }
}

fn cookie_value(headers: &HeaderMap, name: &str) -> Option<String> {
    headers
        .get_all(header::COOKIE)
        .iter()
        .filter_map(|v| v.to_str().ok())
        .flat_map(|v| v.split(';'))
        .filter_map(|pair| pair.trim().split_once('='))
        .find(|(k, _)| *k == name)
        .map(|(_, v)| v.to_string())
}

/// The `Cookie` header without the agent's own cookies.
fn strip_own_cookies(headers: &mut HeaderMap) {
    let kept: Vec<String> = headers
        .get_all(header::COOKIE)
        .iter()
        .filter_map(|v| v.to_str().ok())
        .flat_map(|v| v.split(';'))
        .map(str::trim)
        .filter(|pair| !pair.is_empty() && !pair.starts_with("__sbm_"))
        .map(String::from)
        .collect();
    headers.remove(header::COOKIE);
    if !kept.is_empty()
        && let Ok(v) = HeaderValue::from_str(&kept.join("; "))
    {
        headers.insert(header::COOKIE, v);
    }
}

const HOP_BY_HOP: &[&str] =
    &["connection", "keep-alive", "proxy-connection", "proxy-authenticate", "proxy-authorization", "te", "trailer", "transfer-encoding", "upgrade"];

fn is_upgrade(headers: &HeaderMap) -> bool {
    headers.contains_key(header::UPGRADE)
        && headers
            .get_all(header::CONNECTION)
            .iter()
            .filter_map(|v| v.to_str().ok())
            .any(|v| v.split(',').any(|t| t.trim().eq_ignore_ascii_case("upgrade")))
}

/// Drops hop-by-hop headers, and those `Connection` names; an upgrade keeps
/// `Connection: upgrade` and `Upgrade`.
fn strip_hop_by_hop(headers: &mut HeaderMap, upgrade: bool) {
    let named: Vec<String> = headers
        .get_all(header::CONNECTION)
        .iter()
        .filter_map(|v| v.to_str().ok())
        .flat_map(|v| v.split(','))
        .map(|t| t.trim().to_ascii_lowercase())
        .filter(|t| t != "upgrade")
        .collect();
    let upgrade_value = headers.get(header::UPGRADE).cloned();
    for name in HOP_BY_HOP.iter().map(|s| s.to_string()).chain(named) {
        if let Ok(name) = HeaderName::from_bytes(name.as_bytes()) {
            headers.remove(name);
        }
    }
    if upgrade && let Some(value) = upgrade_value {
        headers.insert(header::CONNECTION, HeaderValue::from_static("upgrade"));
        headers.insert(header::UPGRADE, value);
    }
}

/// `frame-ancestors` allowing the agent's own host on any port and [origins].
fn frame_ancestors(host: &str, secure: bool, origins: &[String]) -> String {
    let scheme = if secure { "https" } else { "http" };
    let bare = match host.find(']') {
        Some(end) if host.starts_with('[') => &host[..=end],
        _ => host.split(':').next().unwrap_or(host),
    };
    let mut out = format!("frame-ancestors 'self' {scheme}://{bare}:*");
    for o in origins {
        out.push(' ');
        out.push_str(o);
    }
    out
}

/// The service's answer made frameable by the desk, its cookies usable in a
/// cross-site frame over TLS.
fn rewrite_response_headers(headers: &mut HeaderMap, ancestors: &str, secure: bool) {
    headers.remove("x-frame-options");
    let csp = HeaderName::from_static("content-security-policy");
    let policies: Vec<String> = headers.get_all(&csp).iter().filter_map(|v| v.to_str().ok().map(String::from)).collect();
    if !policies.is_empty() {
        headers.remove(&csp);
        for policy in policies {
            let mut kept: Vec<&str> = policy
                .split(';')
                .map(str::trim)
                .filter(|d| !d.is_empty() && !d.to_ascii_lowercase().starts_with("frame-ancestors"))
                .collect();
            kept.push(ancestors);
            if let Ok(v) = HeaderValue::from_str(&kept.join("; ")) {
                headers.append(&csp, v);
            }
        }
    }
    if secure {
        let cookies: Vec<String> =
            headers.get_all(header::SET_COOKIE).iter().filter_map(|v| v.to_str().ok().map(String::from)).collect();
        if !cookies.is_empty() {
            headers.remove(header::SET_COOKIE);
            for cookie in cookies {
                let mut parts: Vec<String> = cookie
                    .split(';')
                    .map(|p| p.trim().to_string())
                    .filter(|p| {
                        let l = p.to_ascii_lowercase();
                        !l.starts_with("samesite") && l != "secure"
                    })
                    .collect();
                parts.push("SameSite=None".into());
                parts.push("Secure".into());
                if let Ok(v) = HeaderValue::from_str(&parts.join("; ")) {
                    headers.append(header::SET_COOKIE, v);
                }
            }
        }
    }
}

async fn handle(ctx: &Ctx, mut req: Request<Incoming>, peer: SocketAddr) -> Response<Body> {
    if req.uri().path() == ENTER_PATH {
        return enter(ctx, &req).await;
    }
    let admitted = match cookie_value(req.headers(), &ctx.cookie_name()) {
        Some(token) => ctx.admits(&token).await,
        None => false,
    };
    if !admitted {
        return sign_in_page();
    }

    let host = req.headers().get(header::HOST).and_then(|v| v.to_str().ok()).unwrap_or("").to_string();
    let upgrade = is_upgrade(req.headers());
    let client_upgrade = upgrade.then(|| hyper::upgrade::on(&mut req));

    let path = req.uri().path_and_query().map_or("/", |p| p.as_str()).to_string();
    let Ok(uri) = format!("http://127.0.0.1:{}{path}", ctx.upstream_port).parse::<hyper::Uri>() else {
        return full(StatusCode::BAD_REQUEST, "text/plain", "bad path");
    };
    *req.uri_mut() = uri;
    let headers = req.headers_mut();
    strip_hop_by_hop(headers, upgrade);
    strip_own_cookies(headers);
    let forwarded_for = match headers.get("x-forwarded-for").and_then(|v| v.to_str().ok()) {
        Some(prior) => format!("{prior}, {}", peer.ip()),
        None => peer.ip().to_string(),
    };
    if let Ok(v) = HeaderValue::from_str(&forwarded_for) {
        headers.insert("x-forwarded-for", v);
    }
    headers.insert("x-forwarded-proto", HeaderValue::from_static(if ctx.secure { "https" } else { "http" }));
    if let Ok(v) = HeaderValue::from_str(&host) {
        headers.insert("x-forwarded-host", v);
    }

    let mut resp = match ctx.client.request(req).await {
        Ok(resp) => resp,
        Err(e) => {
            tracing::debug!("app proxy {}: {e}", ctx.stack);
            return full(StatusCode::BAD_GATEWAY, "text/plain; charset=utf-8", "The app is not answering yet.");
        }
    };

    let ancestors = frame_ancestors(&host, ctx.secure, &ctx.frame_origins);
    if resp.status() == StatusCode::SWITCHING_PROTOCOLS {
        let server_upgrade = hyper::upgrade::on(&mut resp);
        if let Some(client_upgrade) = client_upgrade {
            tokio::spawn(async move {
                if let (Ok(client), Ok(server)) = tokio::join!(client_upgrade, server_upgrade) {
                    let _ = tokio::io::copy_bidirectional(&mut TokioIo::new(client), &mut TokioIo::new(server)).await;
                }
            });
        }
        let (mut parts, _) = resp.into_parts();
        rewrite_response_headers(&mut parts.headers, &ancestors, ctx.secure);
        return Response::from_parts(parts, Empty::new().map_err(|never| match never {}).boxed());
    }
    let (mut parts, body) = resp.into_parts();
    strip_hop_by_hop(&mut parts.headers, false);
    rewrite_response_headers(&mut parts.headers, &ancestors, ctx.secure);
    Response::from_parts(parts, body.boxed())
}

async fn enter(ctx: &Ctx, req: &Request<Incoming>) -> Response<Body> {
    let query = req.uri().query();
    let Some(ticket) = query_param(query, "ticket") else { return sign_in_page() };
    let tickets = &ctx.state.tickets;
    let Ok(reservation) = tickets.reserve(&ticket, Purpose::Proxy) else { return sign_in_page() };
    let username = tickets.commit(reservation);
    let Some(caller) = crate::api::authz::caller_named(&ctx.state, &username).await else { return sign_in_page() };
    let Some(token) = ctx.state.stacks.proxies.open_session(caller.username.clone(), caller.since, &ctx.stack) else {
        return full(StatusCode::SERVICE_UNAVAILABLE, "text/plain", "too many sessions");
    };
    let attributes = if ctx.secure { "SameSite=None; Secure" } else { "SameSite=Lax" };
    let cookie = format!("{}={token}; Path=/; HttpOnly; Max-Age={}; {attributes}", ctx.cookie_name(), SESSION_TTL.as_secs());
    let mut resp = full(StatusCode::SEE_OTHER, "text/plain", "");
    if let (Ok(location), Ok(cookie)) = (HeaderValue::from_str(&local_path(query_param(query, "next"))), HeaderValue::from_str(&cookie)) {
        resp.headers_mut().insert(header::LOCATION, location);
        resp.headers_mut().insert(header::SET_COOKIE, cookie);
    }
    resp
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn next_stays_on_this_origin() {
        assert_eq!(local_path(Some("/photos?x=1".into())), "/photos?x=1");
        assert_eq!(local_path(Some("//evil.example/".into())), "/");
        assert_eq!(local_path(Some("/\\evil.example".into())), "/");
        assert_eq!(local_path(Some("https://evil.example".into())), "/");
        assert_eq!(local_path(None), "/");
    }

    #[test]
    fn own_cookies_never_reach_the_service() {
        let mut h = HeaderMap::new();
        h.insert(header::COOKIE, HeaderValue::from_static("a=1; __sbm_immich=secret; b=2"));
        strip_own_cookies(&mut h);
        assert_eq!(h.get(header::COOKIE).unwrap(), "a=1; b=2");
        let mut h = HeaderMap::new();
        h.insert(header::COOKIE, HeaderValue::from_static("__sbm_immich=secret"));
        strip_own_cookies(&mut h);
        assert!(h.get(header::COOKIE).is_none());
    }

    #[test]
    fn responses_become_frameable() {
        let mut h = HeaderMap::new();
        h.insert("x-frame-options", HeaderValue::from_static("DENY"));
        h.insert("content-security-policy", HeaderValue::from_static("default-src 'self'; frame-ancestors 'none'"));
        h.append(header::SET_COOKIE, HeaderValue::from_static("immich_access_token=x; Path=/; HttpOnly; SameSite=Lax"));
        let ancestors = frame_ancestors("nas.local:3780", true, &["https://panel.example".into()]);
        rewrite_response_headers(&mut h, &ancestors, true);
        assert!(h.get("x-frame-options").is_none());
        assert_eq!(
            h.get("content-security-policy").unwrap(),
            "default-src 'self'; frame-ancestors 'self' https://nas.local:* https://panel.example"
        );
        assert_eq!(h.get(header::SET_COOKIE).unwrap(), "immich_access_token=x; Path=/; HttpOnly; SameSite=None; Secure");
    }

    #[test]
    fn plain_http_keeps_cookies_as_they_are() {
        let mut h = HeaderMap::new();
        h.append(header::SET_COOKIE, HeaderValue::from_static("a=1; SameSite=Lax"));
        rewrite_response_headers(&mut h, "frame-ancestors 'self'", false);
        assert_eq!(h.get(header::SET_COOKIE).unwrap(), "a=1; SameSite=Lax");
    }

    #[test]
    fn frame_ancestors_take_the_host_without_its_port() {
        assert_eq!(frame_ancestors("10.0.0.2:3780", false, &[]), "frame-ancestors 'self' http://10.0.0.2:*");
        assert_eq!(frame_ancestors("nas", false, &[]), "frame-ancestors 'self' http://nas:*");
        assert_eq!(frame_ancestors("[::1]:3780", true, &[]), "frame-ancestors 'self' https://[::1]:*");
    }

    #[test]
    fn hop_by_hop_headers_go_but_an_upgrade_keeps_its_own() {
        let mut h = HeaderMap::new();
        h.insert(header::CONNECTION, HeaderValue::from_static("keep-alive, Upgrade, x-private"));
        h.insert(header::UPGRADE, HeaderValue::from_static("websocket"));
        h.insert("x-private", HeaderValue::from_static("1"));
        h.insert("keep-alive", HeaderValue::from_static("timeout=5"));
        assert!(is_upgrade(&h));
        strip_hop_by_hop(&mut h, true);
        assert_eq!(h.get(header::CONNECTION).unwrap(), "upgrade");
        assert_eq!(h.get(header::UPGRADE).unwrap(), "websocket");
        assert!(h.get("x-private").is_none() && h.get("keep-alive").is_none());
    }
}
