//! The agent in front of each deployed web app: a listener of its own per
//! app (its own port, so its own origin), forwarding to the service on
//! loopback, so a desk window can frame it.
//!
//! - **Who gets through**: the signed-in account. The window opens
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
//! - **By host** (`[stacks] apps_url = "https://*.apps.example.com"`): one
//!   more listener (`apps_port`) takes every app, told apart by the `Host`
//!   its request names (`futo-immich.apps.example.com` is `futo.immich`), for
//!   an agent behind a reverse proxy or a tunnel, where the per-app ports
//!   are not reachable. Each app is then its own host: its own cookie jar.
//!   Whether cookies are `Secure` follows `apps_url`'s scheme (TLS usually
//!   ends at the proxy in front).
//! - Over HTTPS the cookies are also `Partitioned` (CHIPS): a panel on
//!   another site (`*.pages.dev`) keeps them in browsers that block
//!   third-party cookies but allow partitioned ones. A panel on the same
//!   site as the apps (`panel.example.com` and `*.apps.example.com`) needs
//!   neither.
//! - `frame-ancestors` also names the origin of the page that asked for the
//!   window (`POST /stacks/{id}/enter`'s `Origin`, when the agent allows it),
//!   so a panel the agent serves frames apps on another host.

use std::collections::HashMap;
use std::convert::Infallible;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicU16, Ordering};
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
    since: i64,
    stack: String,
    /// The panel's origin that asked for the window, to frame it.
    origin: Option<String>,
    expires: Instant,
    checked: Instant,
}

struct Listening {
    port: u16,
    secure: bool,
    ctx: Arc<Ctx>,
    /// The service's port, which new settings may change under a listener
    /// that stays.
    upstream: Arc<AtomicU16>,
    task: JoinHandle<()>,
}

/// Every proxy listener and session of this agent.
#[derive(Default)]
pub struct Proxies {
    listening: Mutex<HashMap<String, Listening>>,
    sessions: Mutex<HashMap<String, Session>>,
    /// The listener taking every app by host, when `apps_url` is set.
    by_host: Mutex<Option<(Hosts, JoinHandle<()>)>>,
    /// The origin a ticket was asked from, until the ticket is used.
    entries: Mutex<HashMap<String, (String, Instant)>>,
}

/// `apps_url`: `<scheme>://*.<suffix>[:port]`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Hosts {
    pub secure: bool,
    /// What follows `*.`, port included when there is one.
    pub suffix: String,
}

impl Hosts {
    /// `https://*.apps.example.com` (a port allowed, no path), or why not.
    pub fn parse(apps_url: &str) -> Result<Self, String> {
        let (scheme, rest) = apps_url.trim().split_once("://").ok_or("apps_url: a scheme is required")?;
        let secure = match scheme {
            "https" => true,
            "http" => false,
            _ => return Err("apps_url: http or https".into()),
        };
        let rest = rest.trim_end_matches('/');
        let suffix = rest.strip_prefix("*.").ok_or("apps_url: the host starts with *.")?;
        if suffix.is_empty() || suffix.contains(['/', '*', '?', '#', '@']) {
            return Err("apps_url: *.<domain>, no path".into());
        }
        Ok(Self { secure, suffix: suffix.to_ascii_lowercase() })
    }

    /// The address of app [id] (`futo.immich` → `https://futo-immich.<suffix>`).
    pub fn url_of(&self, id: &str) -> String {
        format!("{}://{}.{}", if self.secure { "https" } else { "http" }, id.replace('.', "-"), self.suffix)
    }

    /// The app a request's `Host` names: its first label, its one `-` read
    /// back as the `.` of an id (an id's parts have no `-`).
    fn app_of(&self, host: &str) -> Option<String> {
        let host = host.to_ascii_lowercase();
        let label = host.strip_suffix(&self.suffix)?.strip_suffix('.')?;
        if label.contains('.') {
            return None;
        }
        let (publisher, name) = label.split_once('-')?;
        crate::core::app_id::make(publisher, name)
    }
}

/// One app to put a listener in front of.
pub struct Target {
    pub stack: String,
    pub listen: SocketAddr,
    pub upstream_port: u16,
    pub tls: Option<Arc<rustls::ServerConfig>>,
    /// Origins besides the agent's own host that may frame the app.
    pub frame_origins: Vec<String>,
    /// Sent to the service on a request without its own (`[web]
    /// basic_auth`); never to the browser.
    pub authorization: Option<HeaderValue>,
}

impl Drop for Proxies {
    fn drop(&mut self) {
        for (_, l) in self.listening.get_mut().unwrap_or_else(|e| e.into_inner()).drain() {
            l.task.abort();
        }
        if let Some((_, task)) = self.by_host.get_mut().unwrap_or_else(|e| e.into_inner()).take() {
            task.abort();
        }
    }
}

impl Proxies {
    /// The port [stack]'s listener is on, while it is.
    pub fn port(&self, stack: &str) -> Option<u16> {
        self.listening.lock().unwrap_or_else(|e| e.into_inner()).get(stack).map(|l| l.port)
    }

    /// Starts [target]'s listener, replacing one [target]'s stack had. One
    /// already on the same port goes on, now to [Target::upstream_port]: its
    /// sessions stay, and its port is not let go and bound again (an aborted
    /// listener closes later than this returns).
    pub async fn start(&self, state: Arc<AppState>, target: Target) -> std::io::Result<()> {
        {
            let listening = self.listening.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(l) = listening.get(&target.stack)
                && l.port == target.listen.port()
                && l.secure == target.tls.is_some()
            {
                l.upstream.store(target.upstream_port, Ordering::Relaxed);
                *l.ctx.authorization.lock().unwrap_or_else(|e| e.into_inner()) = target.authorization;
                return Ok(());
            }
        }
        self.stop(&target.stack);
        let listener = TcpListener::bind(target.listen).await?;
        let port = listener.local_addr()?.port();
        let stack = target.stack.clone();
        let upstream = Arc::new(AtomicU16::new(target.upstream_port));
        let secure = target.tls.is_some();
        let ctx = Arc::new(Ctx {
            state,
            stack: target.stack,
            upstream_port: upstream.clone(),
            secure: target.tls.is_some(),
            frame_origins: target.frame_origins,
            authorization: Mutex::new(target.authorization),
            client: Client::builder(TokioExecutor::new()).build(HttpConnector::new()),
        });
        let kept = ctx.clone();
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
                        async move {
                            let secure = ctx.secure;
                            Ok::<_, Infallible>(handle(&ctx, req, peer, secure).await)
                        }
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
        self.listening.lock().unwrap_or_else(|e| e.into_inner()).insert(stack, Listening { port, secure, ctx: kept, upstream, task });
        Ok(())
    }

    /// Starts the listener taking every app by host on [listen], replacing
    /// one there was.
    pub async fn start_by_host(&self, listen: SocketAddr, hosts: Hosts, tls: Option<Arc<rustls::ServerConfig>>, state: Arc<AppState>) -> std::io::Result<u16> {
        if let Some((_, task)) = self.by_host.lock().unwrap_or_else(|e| e.into_inner()).take() {
            task.abort();
        }
        let listener = TcpListener::bind(listen).await?;
        let port = listener.local_addr()?.port();
        let acceptor = tls.map(|config| {
            let mut config = (*config).clone();
            config.alpn_protocols = vec![b"http/1.1".to_vec()];
            tokio_rustls::TlsAcceptor::from(Arc::new(config))
        });
        let routing = hosts.clone();
        let task = tokio::spawn(async move {
            loop {
                let Ok((stream, peer)) = listener.accept().await else { continue };
                let (state, hosts, acceptor) = (state.clone(), routing.clone(), acceptor.clone());
                tokio::spawn(async move {
                    let service = hyper::service::service_fn(move |req: Request<Incoming>| {
                        let (state, hosts) = (state.clone(), hosts.clone());
                        async move {
                            let host = req.headers().get(header::HOST).and_then(|v| v.to_str().ok()).unwrap_or("");
                            let ctx = hosts.app_of(host).and_then(|id| state.stacks.proxies.ctx(&id));
                            Ok::<_, Infallible>(match ctx {
                                Some(ctx) => handle(&ctx, req, peer, hosts.secure).await,
                                None => full(StatusCode::NOT_FOUND, "text/plain; charset=utf-8", "No such app here."),
                            })
                        }
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
        *self.by_host.lock().unwrap_or_else(|e| e.into_inner()) = Some((hosts, task));
        Ok(port)
    }

    /// Where app [id]'s window enters when apps are taken by host.
    pub fn host_url(&self, id: &str) -> Option<String> {
        self.by_host.lock().unwrap_or_else(|e| e.into_inner()).as_ref().map(|(hosts, _)| hosts.url_of(id))
    }

    fn ctx(&self, stack: &str) -> Option<Arc<Ctx>> {
        self.listening.lock().unwrap_or_else(|e| e.into_inner()).get(stack).map(|l| l.ctx.clone())
    }

    /// Remembers that [ticket] was asked for from [origin], to frame the
    /// window there.
    pub fn note_entry(&self, ticket: &str, origin: String) {
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        entries.retain(|_, (_, at)| at.elapsed() < Duration::from_secs(120));
        if entries.len() < MAX_SESSIONS {
            entries.insert(ticket.to_string(), (origin, Instant::now()));
        }
    }

    fn take_entry(&self, ticket: &str) -> Option<String> {
        self.entries.lock().unwrap_or_else(|e| e.into_inner()).remove(ticket).map(|(o, _)| o)
    }

    pub fn stop(&self, stack: &str) {
        if let Some(l) = self.listening.lock().unwrap_or_else(|e| e.into_inner()).remove(stack) {
            l.task.abort();
        }
        self.sessions.lock().unwrap_or_else(|e| e.into_inner()).retain(|_, s| s.stack != stack);
    }

    /// Ends every session: the password changed.
    pub fn end_account(&self) {
        self.sessions.lock().unwrap_or_else(|e| e.into_inner()).clear();
    }

    fn open_session(&self, since: i64, stack: &str, origin: Option<String>) -> Option<String> {
        let token = random_hex(32).ok()?;
        let now = Instant::now();
        let mut sessions = self.sessions.lock().unwrap_or_else(|e| e.into_inner());
        sessions.retain(|_, s| s.expires > now);
        if sessions.len() >= MAX_SESSIONS {
            return None;
        }
        sessions.insert(
            token.clone(),
            Session { since, stack: stack.to_string(), origin, expires: now + SESSION_TTL, checked: now },
        );
        Some(token)
    }
}

struct Ctx {
    state: Arc<AppState>,
    stack: String,
    upstream_port: Arc<AtomicU16>,
    secure: bool,
    frame_origins: Vec<String>,
    /// [Target::authorization], new settings changing it under a listener
    /// that stays.
    authorization: Mutex<Option<HeaderValue>>,
    client: Client<HttpConnector, Incoming>,
}

impl Ctx {
    fn cookie_name(&self) -> String {
        format!("__sbm_{}", self.stack)
    }

    /// Whether [token] names a live session for this app, its account looked
    /// up again when it was last looked up a while ago: the origin it was
    /// entered from (`Some(None)` when none was noted).
    async fn admits(&self, token: &str) -> Option<Option<String>> {
        let proxies = &self.state.stacks.proxies;
        let (since, recheck, origin) = {
            let sessions = proxies.sessions.lock().unwrap_or_else(|e| e.into_inner());
            match sessions.get(token) {
                Some(s) if s.stack == self.stack && s.expires > Instant::now() => {
                    (s.since, s.checked.elapsed() >= RECHECK, s.origin.clone())
                }
                _ => return None,
            }
        };
        if recheck {
            let current = crate::api::authz::caller(&self.state).await;
            let mut sessions = proxies.sessions.lock().unwrap_or_else(|e| e.into_inner());
            if current.is_none_or(|c| c.since != since) {
                sessions.remove(token);
                return None;
            }
            if let Some(s) = sessions.get_mut(token) {
                s.checked = Instant::now();
            }
        }
        Some(origin)
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
                        !l.starts_with("samesite") && l != "secure" && l != "partitioned"
                    })
                    .collect();
                parts.push("SameSite=None".into());
                parts.push("Secure".into());
                parts.push("Partitioned".into());
                if let Ok(v) = HeaderValue::from_str(&parts.join("; ")) {
                    headers.append(header::SET_COOKIE, v);
                }
            }
        }
    }
}

/// One request to [ctx]'s app; [secure]: what the browser sees is HTTPS.
async fn handle(ctx: &Ctx, mut req: Request<Incoming>, peer: SocketAddr, secure: bool) -> Response<Body> {
    if req.uri().path() == ENTER_PATH {
        return enter(ctx, &req, secure).await;
    }
    let admitted = match cookie_value(req.headers(), &ctx.cookie_name()) {
        Some(token) => ctx.admits(&token).await,
        None => None,
    };
    let Some(entered_from) = admitted else {
        return sign_in_page();
    };

    let host = req.headers().get(header::HOST).and_then(|v| v.to_str().ok()).unwrap_or("").to_string();
    let upgrade = is_upgrade(req.headers());
    let client_upgrade = upgrade.then(|| hyper::upgrade::on(&mut req));

    let path = req.uri().path_and_query().map_or("/", |p| p.as_str()).to_string();
    let Ok(uri) = format!("http://127.0.0.1:{}{path}", ctx.upstream_port.load(Ordering::Relaxed)).parse::<hyper::Uri>() else {
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
    headers.insert("x-forwarded-proto", HeaderValue::from_static(if secure { "https" } else { "http" }));
    if let Ok(v) = HeaderValue::from_str(&host) {
        headers.insert("x-forwarded-host", v);
    }
    if !headers.contains_key(header::AUTHORIZATION)
        && let Some(auth) = ctx.authorization.lock().unwrap_or_else(|e| e.into_inner()).clone()
    {
        headers.insert(header::AUTHORIZATION, auth);
    }

    let mut resp = match ctx.client.request(req).await {
        Ok(resp) => resp,
        Err(e) => {
            tracing::debug!("app proxy {}: {e}", ctx.stack);
            return full(StatusCode::BAD_GATEWAY, "text/plain; charset=utf-8", "The app is not answering yet.");
        }
    };

    let mut origins = ctx.frame_origins.clone();
    origins.extend(entered_from.filter(|o| !ctx.frame_origins.contains(o)));
    let ancestors = frame_ancestors(&host, secure, &origins);
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
        rewrite_response_headers(&mut parts.headers, &ancestors, secure);
        return Response::from_parts(parts, Empty::new().map_err(|never| match never {}).boxed());
    }
    let (mut parts, body) = resp.into_parts();
    strip_hop_by_hop(&mut parts.headers, false);
    rewrite_response_headers(&mut parts.headers, &ancestors, secure);
    Response::from_parts(parts, body.boxed())
}

async fn enter(ctx: &Ctx, req: &Request<Incoming>, secure: bool) -> Response<Body> {
    let query = req.uri().query();
    let Some(ticket) = query_param(query, "ticket") else { return sign_in_page() };
    let tickets = &ctx.state.tickets;
    let Ok(reservation) = tickets.reserve(&ticket, Purpose::Proxy) else { return sign_in_page() };
    tickets.commit(reservation);
    let proxies = &ctx.state.stacks.proxies;
    let origin = proxies.take_entry(&ticket);
    let Some(caller) = crate::api::authz::caller(&ctx.state).await else { return sign_in_page() };
    let Some(token) = proxies.open_session(caller.since, &ctx.stack, origin) else {
        return full(StatusCode::SERVICE_UNAVAILABLE, "text/plain", "too many sessions");
    };
    let attributes = if secure { "SameSite=None; Secure; Partitioned" } else { "SameSite=Lax" };
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
    fn apps_url_is_a_wildcard_host() {
        let hosts = Hosts::parse("https://*.Apps.Example.com/").unwrap();
        assert_eq!(hosts, Hosts { secure: true, suffix: "apps.example.com".into() });
        assert_eq!(hosts.url_of("futo.immich"), "https://futo-immich.apps.example.com");
        assert_eq!(hosts.app_of("futo-immich.apps.example.com").as_deref(), Some("futo.immich"));
        assert_eq!(hosts.app_of("FUTO-IMMICH.apps.example.com").as_deref(), Some("futo.immich"));
        for host in ["immich.apps.example.com", "x.futo-immich.apps.example.com", "futo-immich.apps.example.org", "futo-immich-x.apps.example.com"] {
            assert_eq!(hosts.app_of(host), None, "{host}");
        }
        let with_port = Hosts::parse("http://*.apps.lan:8443").unwrap();
        assert_eq!(with_port.app_of("serverbox-testweb.apps.lan:8443").as_deref(), Some("serverbox.testweb"));
        for bad in ["apps.example.com", "ftp://*.x", "https://apps.example.com", "https://*.x/path", "https://*."] {
            assert!(Hosts::parse(bad).is_err(), "{bad}");
        }
    }

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
        assert_eq!(h.get(header::SET_COOKIE).unwrap(), "immich_access_token=x; Path=/; HttpOnly; SameSite=None; Secure; Partitioned");
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
