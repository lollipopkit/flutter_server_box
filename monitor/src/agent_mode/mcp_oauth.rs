//! Signing in to an MCP server with OAuth, as the MCP authorization
//! specification has it (2025-06-18): the agent is the client. A server that
//! answers 401 names where its Protected Resource Metadata is (RFC 9728),
//! which names its authorization server, whose metadata (RFC 8414) names the
//! endpoints. The client registers itself where the server offers it
//! (RFC 7591); otherwise its id is the address the browser comes back to, as
//! Home Assistant (IndieAuth) takes one. Authorization code with PKCE (S256)
//! and the server as `resource` (RFC 8707).
//!
//! The browser carries the person to the authorization server and back to
//! `/agent/mcp/oauth/callback`, which a one-time `state` alone lets in; the
//! code is exchanged here, so no token reaches the browser. Tokens are kept
//! by server id (`mcp_oauth`, migration 036), refreshed when they are about
//! to run out, and never read back out over the API.

use crate::utils::lock::LockExt;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use base64::Engine;
use fl_pi_llm::host::{Fetch, FetchRequest, fetch_allowed};
use serde_json::{Value, json};
use sha2::Digest;
use sqlx::SqlitePool;

use crate::db::sealed::{self, Sealer};

/// How long a sign-in may take, from its start to the browser coming back.
const PENDING_TTL: Duration = Duration::from_secs(10 * 60);
/// Sign-ins waiting at once, at most.
const MAX_PENDING: usize = 16;
/// A token this close to running out is refreshed first.
const REFRESH_AHEAD_MS: i64 = 60_000;
/// What one metadata or token answer may be.
const MAX_BODY: usize = 1 << 20;
const TIMEOUT: Duration = Duration::from_secs(20);
pub const CALLBACK_PATH: &str = "/api/v1/agent/mcp/oauth/callback";

/// Where a server's tokens come from.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthServer {
    pub authorization_endpoint: String,
    pub token_endpoint: String,
    pub registration_endpoint: Option<String>,
    /// The server as the tokens are asked for (`resource`).
    pub resource: String,
    pub scopes: Vec<String>,
}

/// The agent as the authorization server knows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Client {
    pub id: String,
    pub secret: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Tokens {
    pub access: String,
    pub refresh: Option<String>,
    pub expires_at_ms: Option<i64>,
}

/// The `resource_metadata` a `WWW-Authenticate: Bearer …` names.
pub fn resource_metadata(www_authenticate: &str) -> Option<String> {
    let at = www_authenticate.find("resource_metadata=")? + "resource_metadata=".len();
    let rest = &www_authenticate[at..];
    let value = match rest.strip_prefix('"') {
        Some(quoted) => quoted.split('"').next()?,
        None => rest.split([',', ' ']).next()?,
    };
    (!value.is_empty()).then(|| value.to_string())
}

/// RFC 8414/9728's well-known address for [url]: inserted between its origin
/// and its path (`https://h/.well-known/x/path`), or at the root.
fn well_known(url: &url::Url, name: &str, with_path: bool) -> String {
    let origin = url.origin().ascii_serialization();
    let path = url.path().trim_end_matches('/');
    if with_path && !path.is_empty() { format!("{origin}/.well-known/{name}{path}") } else { format!("{origin}/.well-known/{name}") }
}

async fn read_body(fetch: &dyn Fetch, req: FetchRequest) -> Result<(u16, Vec<(String, String)>, Vec<u8>), String> {
    if !fetch_allowed(&req.url, &[]) {
        return Err(format!("{}: https://, or http:// on this machine", req.url));
    }
    let res = tokio::time::timeout(TIMEOUT, fetch.fetch(req)).await.map_err(|_| "no answer".to_string())??;
    let (status, headers, mut body) = (res.status, res.headers, res.body);
    let mut out = Vec::new();
    let read = async {
        while let Some(chunk) = body.recv().await {
            out.extend(chunk?);
            if out.len() > MAX_BODY {
                return Err("the answer is too large".to_string());
            }
        }
        Ok(())
    };
    tokio::time::timeout(TIMEOUT, read).await.map_err(|_| "no answer".to_string())??;
    Ok((status, headers, out))
}

async fn get_json(fetch: &dyn Fetch, url: &str) -> Result<Value, String> {
    let req = FetchRequest { url: url.into(), method: "GET".into(), headers: vec![("accept".into(), "application/json".into())], body: None };
    let (status, _, body) = read_body(fetch, req).await?;
    if !(200..300).contains(&status) {
        return Err(format!("{url}: HTTP {status}"));
    }
    serde_json::from_slice(&body).map_err(|e| format!("{url}: not JSON: {e}"))
}

/// POSTs [body] (form or JSON by [content_type]); the answer as JSON, or the
/// server's `error_description`/`error`.
async fn post(fetch: &dyn Fetch, url: &str, content_type: &str, body: Vec<u8>) -> Result<Value, String> {
    let headers = vec![("content-type".into(), content_type.into()), ("accept".into(), "application/json".into())];
    let (status, _, body) = read_body(fetch, FetchRequest { url: url.into(), method: "POST".into(), headers, body: Some(body) }).await?;
    let value: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        let why = value["error_description"].as_str().or(value["error"].as_str()).unwrap_or("refused");
        return Err(format!("{url}: HTTP {status} {}", fl_pi_llm::mcp::cap(why, 200)));
    }
    Ok(value)
}

fn form(pairs: &[(&str, &str)]) -> Vec<u8> {
    url::form_urlencoded::Serializer::new(String::new()).extend_pairs(pairs).finish().into_bytes()
}

/// Where [mcp_url]'s tokens come from: its Protected Resource Metadata (as
/// its 401 names it, else at the well-known address), then its authorization
/// server's metadata. A server without the first is its own authorization
/// server.
pub async fn discover(fetch: &dyn Fetch, mcp_url: &str) -> Result<AuthServer, String> {
    let url = url::Url::parse(mcp_url).map_err(|e| e.to_string())?;
    // Asked as a client would be: its 401 says where its metadata is.
    let probe = json!({ "jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": fl_pi_llm::host::mcp::PROTOCOL_VERSION, "capabilities": {}, "clientInfo": { "name": "server_box_monitor" } } });
    let req = FetchRequest {
        url: mcp_url.into(),
        method: "POST".into(),
        headers: vec![
            ("content-type".into(), "application/json".into()),
            ("accept".into(), "application/json, text/event-stream".into()),
        ],
        body: Some(probe.to_string().into_bytes()),
    };
    let (status, headers, _) = read_body(fetch, req).await?;
    if status != 401 {
        return Err("the server does not ask to sign in".into());
    }
    let named = headers.iter().find(|(k, _)| k.eq_ignore_ascii_case("www-authenticate")).and_then(|(_, v)| resource_metadata(v));
    let mut prm = None;
    for at in named.into_iter().chain([well_known(&url, "oauth-protected-resource", true), well_known(&url, "oauth-protected-resource", false)]) {
        if let Ok(v) = get_json(fetch, &at).await {
            prm = Some(v);
            break;
        }
    }
    let (issuer, resource, scopes) = match &prm {
        Some(p) => (
            p["authorization_servers"][0].as_str().ok_or("its resource metadata names no authorization server")?.to_string(),
            p["resource"].as_str().unwrap_or(mcp_url).to_string(),
            p["scopes_supported"].as_array().into_iter().flatten().filter_map(|s| s.as_str().map(String::from)).collect(),
        ),
        None => (url.origin().ascii_serialization(), mcp_url.to_string(), Vec::new()),
    };
    let issuer_url = url::Url::parse(&issuer).map_err(|e| format!("authorization server {issuer}: {e}"))?;
    let tries = [
        well_known(&issuer_url, "oauth-authorization-server", true),
        well_known(&issuer_url, "openid-configuration", true),
        format!("{}/.well-known/openid-configuration", issuer.trim_end_matches('/')),
    ];
    let mut last = String::new();
    for at in tries {
        match get_json(fetch, &at).await {
            Ok(m) => {
                let endpoint = |k: &str| m[k].as_str().filter(|u| fetch_allowed(u, &[])).map(String::from);
                let (Some(authorization_endpoint), Some(token_endpoint)) = (endpoint("authorization_endpoint"), endpoint("token_endpoint")) else {
                    return Err(format!("{at}: no usable authorization or token endpoint"));
                };
                return Ok(AuthServer { authorization_endpoint, token_endpoint, registration_endpoint: endpoint("registration_endpoint"), resource, scopes });
            }
            Err(e) => last = e,
        }
    }
    Err(format!("no authorization server metadata: {last}"))
}

/// The agent as a client of [server]: registered where it offers that,
/// otherwise named by where the browser comes back to (its origin).
pub async fn register(fetch: &dyn Fetch, server: &AuthServer, redirect_uri: &str) -> Result<Client, String> {
    let Some(endpoint) = &server.registration_endpoint else {
        let origin = url::Url::parse(redirect_uri).map_err(|e| e.to_string())?.origin().ascii_serialization();
        return Ok(Client { id: format!("{origin}/"), secret: None });
    };
    let body = json!({
        "client_name": "ServerBox Monitor",
        "redirect_uris": [redirect_uri],
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "token_endpoint_auth_method": "none",
    });
    let v = post(fetch, endpoint, "application/json", body.to_string().into_bytes()).await?;
    let id = v["client_id"].as_str().ok_or("the registration answered no client_id")?;
    Ok(Client { id: id.into(), secret: v["client_secret"].as_str().map(String::from) })
}

/// A PKCE verifier and its S256 challenge.
pub fn pkce() -> Result<(String, String), String> {
    let mut bytes = [0u8; 32];
    getrandom::fill(&mut bytes).map_err(|e| e.to_string())?;
    let verifier = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes);
    let challenge = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(sha2::Sha256::digest(verifier.as_bytes()));
    Ok((verifier, challenge))
}

/// Where the browser is sent to sign in.
pub fn authorize_url(server: &AuthServer, client: &Client, redirect_uri: &str, state: &str, challenge: &str) -> Result<String, String> {
    let mut url = url::Url::parse(&server.authorization_endpoint).map_err(|e| e.to_string())?;
    {
        let mut q = url.query_pairs_mut();
        q.append_pair("response_type", "code")
            .append_pair("client_id", &client.id)
            .append_pair("redirect_uri", redirect_uri)
            .append_pair("state", state)
            .append_pair("code_challenge", challenge)
            .append_pair("code_challenge_method", "S256")
            .append_pair("resource", &server.resource);
        if !server.scopes.is_empty() {
            q.append_pair("scope", &server.scopes.join(" "));
        }
    }
    Ok(url.into())
}

fn tokens(v: &Value, kept_refresh: Option<&str>) -> Result<Tokens, String> {
    let access = v["access_token"].as_str().filter(|t| !t.is_empty()).ok_or("the answer has no access_token")?;
    let expires_at_ms = v["expires_in"].as_i64().map(|s| chrono::Utc::now().timestamp_millis() + s * 1000);
    Ok(Tokens { access: access.into(), refresh: v["refresh_token"].as_str().or(kept_refresh).map(String::from), expires_at_ms })
}

async fn token_request(fetch: &dyn Fetch, token_endpoint: &str, client: &Client, mut pairs: Vec<(&str, &str)>) -> Result<Value, String> {
    pairs.push(("client_id", &client.id));
    if let Some(secret) = &client.secret {
        pairs.push(("client_secret", secret));
    }
    post(fetch, token_endpoint, "application/x-www-form-urlencoded", form(&pairs)).await
}

/// The code the browser came back with, exchanged for tokens.
pub async fn exchange(fetch: &dyn Fetch, server: &AuthServer, client: &Client, code: &str, verifier: &str, redirect_uri: &str) -> Result<Tokens, String> {
    let pairs = vec![
        ("grant_type", "authorization_code"),
        ("code", code),
        ("redirect_uri", redirect_uri),
        ("code_verifier", verifier),
        ("resource", server.resource.as_str()),
    ];
    tokens(&token_request(fetch, &server.token_endpoint, client, pairs).await?, None)
}

/// A sign-in waiting for the browser to come back.
struct Pending {
    server_id: String,
    url: String,
    server: AuthServer,
    client: Client,
    verifier: String,
    redirect_uri: String,
    started: Instant,
}

/// Sign-ins waiting, by `state`.
#[derive(Default)]
pub struct Flows(std::sync::Mutex<HashMap<String, Pending>>);

/// What a finished sign-in signed in to.
pub struct SignedIn {
    pub server_id: String,
    pub url: String,
}

impl Flows {
    /// Starts signing in to [url] (server [server_id]); the address to send
    /// the browser to. [origin] is the agent as the browser reaches it.
    pub async fn start(&self, fetch: &dyn Fetch, server_id: &str, url: &str, origin: &str) -> Result<String, String> {
        let redirect_uri = format!("{}{CALLBACK_PATH}", origin.trim_end_matches('/'));
        let server = discover(fetch, url).await?;
        let client = register(fetch, &server, &redirect_uri).await?;
        let (verifier, challenge) = pkce()?;
        let state = crate::utils::secrets::random_hex(32).map_err(|e| e.to_string())?;
        let to = authorize_url(&server, &client, &redirect_uri, &state, &challenge)?;
        let mut pending = self.0.locked();
        pending.retain(|_, p| p.started.elapsed() < PENDING_TTL);
        if pending.len() >= MAX_PENDING {
            return Err("too many sign-ins at once".into());
        }
        pending.insert(
            state,
            Pending { server_id: server_id.into(), url: url.into(), server, client, verifier, redirect_uri, started: Instant::now() },
        );
        Ok(to)
    }

    /// The browser came back with [code] for [state]: the tokens kept. A
    /// `state` works once, and only within [`PENDING_TTL`].
    pub async fn finish(&self, db: &SqlitePool, sealer: &Sealer, fetch: &dyn Fetch, state: &str, code: &str) -> Result<SignedIn, String> {
        let p = self.0.locked().remove(state).filter(|p| p.started.elapsed() < PENDING_TTL).ok_or("this sign-in is unknown or expired")?;
        let t = exchange(fetch, &p.server, &p.client, code, &p.verifier, &p.redirect_uri).await?;
        let kept = Kept { server_id: &p.server_id, url: &p.url, token_endpoint: &p.server.token_endpoint, client: &p.client, resource: &p.server.resource };
        store(db, sealer, &kept, &t).await.map_err(|e| e.to_string())?;
        Ok(SignedIn { server_id: p.server_id, url: p.url })
    }

    /// Ends the sign-in waiting for [state] (the person declined).
    pub fn abandon(&self, state: &str) {
        self.0.locked().remove(state);
    }
}

/// A sign-in as `mcp_oauth` keeps it, beside its tokens.
struct Kept<'a> {
    server_id: &'a str,
    url: &'a str,
    token_endpoint: &'a str,
    client: &'a Client,
    resource: &'a str,
}

async fn store(db: &SqlitePool, sealer: &Sealer, k: &Kept<'_>, t: &Tokens) -> sqlx::Result<()> {
    let Kept { server_id, url, token_endpoint, client, resource } = *k;
    sqlx::query(
        "INSERT OR REPLACE INTO mcp_oauth (server_id, url, token_endpoint, client_id, client_secret, resource, access_token, \
         refresh_token, expires_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(server_id)
    .bind(url)
    .bind(token_endpoint)
    .bind(&client.id)
    .bind(sealer.seal_opt(sealed::MCP_OAUTH_CLIENT_SECRET, client.secret.as_deref())?)
    .bind(resource)
    .bind(sealer.seal(sealed::MCP_OAUTH_ACCESS_TOKEN, &t.access)?)
    .bind(sealer.seal_opt(sealed::MCP_OAUTH_REFRESH_TOKEN, t.refresh.as_deref())?)
    .bind(t.expires_at_ms)
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(db)
    .await
    .map(drop)
}

/// The servers signed in to, by id.
pub async fn signed_in(db: &SqlitePool) -> Vec<String> {
    sqlx::query_scalar("SELECT server_id FROM mcp_oauth").fetch_all(db).await.unwrap_or_default()
}

pub async fn forget(db: &SqlitePool, server_id: &str) -> sqlx::Result<()> {
    sqlx::query("DELETE FROM mcp_oauth WHERE server_id = ?").bind(server_id).execute(db).await.map(drop)
}

type Row = (String, String, String, Option<String>, String, String, Option<String>, Option<i64>);

/// `Authorization` for server [server_id] when signed in to it: its access
/// token, refreshed first when it is about to run out. A refresh refused
/// forgets the sign-in, so the server asks for one again, as does one the
/// credentials key no longer opens.
pub async fn bearer(db: &SqlitePool, sealer: &Sealer, fetch: &Arc<dyn Fetch>, server_id: &str) -> Option<String> {
    let row: Row = sqlx::query_as(
        "SELECT url, token_endpoint, client_id, client_secret, resource, access_token, refresh_token, expires_at \
         FROM mcp_oauth WHERE server_id = ?",
    )
    .bind(server_id)
    .fetch_optional(db)
    .await
    .ok()??;
    let (url, token_endpoint, client_id, client_secret, resource, access, refresh, expires_at) = row;
    let opened = (|| {
        Ok::<_, sealed::Error>((
            sealer.open_opt(sealed::MCP_OAUTH_CLIENT_SECRET, client_secret.as_deref())?,
            sealer.open(sealed::MCP_OAUTH_ACCESS_TOKEN, &access)?,
            sealer.open_opt(sealed::MCP_OAUTH_REFRESH_TOKEN, refresh.as_deref())?,
        ))
    })();
    let (client_secret, access, refresh) = match opened {
        Ok(o) => o,
        Err(e) => {
            tracing::warn!("MCP server {server_id}: its sign-in: {e}");
            let _ = forget(db, server_id).await;
            return None;
        }
    };
    let fresh = expires_at.is_none_or(|at| at - chrono::Utc::now().timestamp_millis() > REFRESH_AHEAD_MS);
    if fresh {
        return Some(format!("Bearer {access}"));
    }
    let client = Client { id: client_id, secret: client_secret };
    let Some(refresh) = refresh else {
        let _ = forget(db, server_id).await;
        return None;
    };
    let pairs = vec![("grant_type", "refresh_token"), ("refresh_token", refresh.as_str()), ("resource", resource.as_str())];
    match token_request(fetch.as_ref(), &token_endpoint, &client, pairs).await.and_then(|v| tokens(&v, Some(&refresh))) {
        Ok(t) => {
            let kept = Kept { server_id, url: &url, token_endpoint: &token_endpoint, client: &client, resource: &resource };
            let _ = store(db, sealer, &kept, &t).await;
            Some(format!("Bearer {}", t.access))
        }
        Err(e) => {
            tracing::warn!("MCP server {server_id}: refreshing its sign-in: {e}");
            let _ = forget(db, server_id).await;
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_challenge_names_the_resource_metadata() {
        assert_eq!(
            resource_metadata(r#"Bearer error="invalid_token", resource_metadata="https://h/.well-known/oauth-protected-resource/mcp""#).as_deref(),
            Some("https://h/.well-known/oauth-protected-resource/mcp")
        );
        assert_eq!(resource_metadata("Bearer resource_metadata=https://h/x, realm=a").as_deref(), Some("https://h/x"));
        assert_eq!(resource_metadata("Bearer realm=\"a\""), None);
        let url = url::Url::parse("https://h:8123/api/mcp/").unwrap();
        assert_eq!(well_known(&url, "oauth-protected-resource", true), "https://h:8123/.well-known/oauth-protected-resource/api/mcp");
        assert_eq!(well_known(&url, "oauth-authorization-server", false), "https://h:8123/.well-known/oauth-authorization-server");
    }

    #[test]
    fn the_browser_is_sent_with_pkce_and_the_resource() {
        let (verifier, challenge) = pkce().unwrap();
        assert_eq!(verifier.len(), 43);
        assert_eq!(challenge, base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(sha2::Sha256::digest(verifier.as_bytes())));
        let server = AuthServer {
            authorization_endpoint: "https://h/auth/authorize".into(),
            token_endpoint: "https://h/auth/token".into(),
            registration_endpoint: None,
            resource: "https://h/api/mcp".into(),
            scopes: vec!["a".into(), "b".into()],
        };
        let to = url::Url::parse(&authorize_url(&server, &Client { id: "https://agent/".into(), secret: None }, "https://agent/cb", "s1", &challenge).unwrap()).unwrap();
        let q: HashMap<_, _> = to.query_pairs().into_owned().collect();
        assert_eq!(q["response_type"], "code");
        assert_eq!(q["code_challenge_method"], "S256");
        assert_eq!(q["resource"], "https://h/api/mcp");
        assert_eq!(q["scope"], "a b");
        assert_eq!((q["client_id"].as_str(), q["redirect_uri"].as_str(), q["state"].as_str()), ("https://agent/", "https://agent/cb", "s1"));
    }
}
