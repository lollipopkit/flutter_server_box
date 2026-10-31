//! LK Cloud for the monitor agent: signing in at the IdP (auth.lolli.tech,
//! OpenID Connect) and reading the account from homebase (api.lolli.tech).
//! The app's client is fl_lib's `LkcClient`; this follows it, so both see the
//! IdP and homebase alike.
//!
//! The agent signs in with a device code (RFC 8628) as the public client
//! [`CLIENT_ID`]: no address of an agent can be registered at the IdP ahead of
//! time. Homebase is sent the IdP's access token; who signed in is what it
//! answers ([`User`]), so no ID token is read.

mod error;

use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio::sync::OnceCell;

pub use error::{Error, Failure};

/// The IdP every LK Cloud client signs in at (`LkcOidc.defaultIssuer`).
pub const ISSUER: &str = "https://auth.lolli.tech/auth/v1/";
/// ServerBox's public client there.
pub const CLIENT_ID: &str = "serverbox";
/// Homebase (`LkcClient.defaultBaseUrl`).
pub const API: &str = "https://api.lolli.tech";
/// What a sign-in asks for (`LkcOidc.scopes`).
pub const SCOPE: &str = "openid profile";

/// How long before its expiry an access token is refreshed
/// (`LkcTokens.refreshWindow`).
///
/// The IdP refuses a refresh token before the last minute of its access
/// token, and answers an early use by revoking every session of the person.
/// The expiry is taken on receipt, after the IdP's own clock started, so this
/// window is entered no earlier than the IdP's; the margin under 60 s covers
/// the request's own way there.
pub const REFRESH_WINDOW: Duration = Duration::from_secs(45);

const CONNECT_TIMEOUT: Duration = Duration::from_secs(15);
const TIMEOUT: Duration = Duration::from_secs(30);
/// What one answer may be.
const MAX_BODY: usize = 1 << 20;
/// What a device sign-in waits between polls when the IdP does not say.
const DEVICE_INTERVAL_SECS: u64 = 5;
/// The longest lifetime taken from an `expires_in`: past it a token or code
/// is read as living this long, so no answer overflows a clock.
const MAX_LIFETIME: Duration = Duration::from_secs(366 * 24 * 3600);

/// The IdP's endpoints, from its discovery document.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Metadata {
    pub issuer: String,
    pub token_endpoint: String,
    pub device_authorization_endpoint: Option<String>,
    pub revocation_endpoint: Option<String>,
}

impl Metadata {
    /// [doc] as served for [issuer]: it must name the same issuer, and every
    /// endpoint must be `https://`.
    pub fn from_json(issuer: &str, doc: &Value) -> Result<Self, Error> {
        let field = |name: &str| doc[name].as_str().map(str::to_string);
        let required = |name: &str| {
            field(name).ok_or_else(|| Error::new(Failure::InvalidResponse, format!("discovery: no {name}")))
        };
        let metadata = Self {
            issuer: required("issuer")?,
            token_endpoint: required("token_endpoint")?,
            device_authorization_endpoint: field("device_authorization_endpoint"),
            revocation_endpoint: field("revocation_endpoint"),
        };
        if metadata.issuer != issuer {
            return Err(Error::new(Failure::InvalidResponse, format!("discovery names issuer {}", metadata.issuer)));
        }
        let endpoints = [
            Some(&metadata.token_endpoint),
            metadata.device_authorization_endpoint.as_ref(),
            metadata.revocation_endpoint.as_ref(),
        ];
        if let Some(bad) = endpoints.into_iter().flatten().find(|url| !url.starts_with("https://")) {
            return Err(Error::new(Failure::InvalidResponse, format!("discovery: {bad} is not https://")));
        }
        Ok(metadata)
    }
}

/// The IdP's tokens (`LkcTokens`); homebase is sent [access]. `Debug` leaves
/// the tokens out.
#[derive(Clone)]
pub struct Tokens {
    pub access: String,
    /// `None` when the IdP gave none; a refresh that gives none keeps the
    /// previous one.
    pub refresh: Option<String>,
    /// Unix milliseconds: this side's clock on receipt plus `expires_in`.
    pub expires_at_ms: i64,
    /// The same expiry on this process's monotonic clock, while it is the
    /// process that received the tokens: a wall clock stepped forward (NTP
    /// on a board without an RTC) would otherwise make them due early, and
    /// an early refresh ends every session of the person.
    pub deadline: Option<Instant>,
}

impl Tokens {
    /// Tokens as stored, without a [deadline](Self::deadline).
    pub fn stored(access: String, refresh: Option<String>, expires_at_ms: i64) -> Self {
        Self { access, refresh, expires_at_ms, deadline: None }
    }

    /// Whether [`Client::refresh`] may be asked at [now_ms]: within
    /// [`REFRESH_WINDOW`] of the expiry, by [deadline](Self::deadline) when
    /// known.
    pub fn due(&self, now_ms: i64) -> bool {
        match self.deadline {
            Some(deadline) => Instant::now() + REFRESH_WINDOW >= deadline,
            None => self.expires_at_ms - now_ms < REFRESH_WINDOW.as_millis() as i64,
        }
    }

    /// A token answer received at [now_ms]; [previous] keeps a refresh token
    /// not rotated. One without `expires_in` is refused: no expiry would make
    /// it due at once, and a refresh that early ends every session of the
    /// person.
    fn from_response(value: &Value, now_ms: i64, previous: Option<&Tokens>) -> Result<Self, Error> {
        let text = |name: &str| value[name].as_str().filter(|s| !s.is_empty()).map(str::to_string);
        let lifetime = value["expires_in"]
            .as_u64()
            .filter(|&secs| secs > 0)
            .map(|secs| Duration::from_secs(secs).min(MAX_LIFETIME))
            .ok_or_else(|| Error::new(Failure::InvalidResponse, "no expires_in"))?;
        Ok(Self {
            access: text("access_token").ok_or_else(|| Error::new(Failure::InvalidResponse, "no access_token"))?,
            refresh: text("refresh_token").or_else(|| previous.and_then(|p| p.refresh.clone())),
            expires_at_ms: now_ms + lifetime.as_millis() as i64,
            deadline: Some(Instant::now() + lifetime),
        })
    }
}

/// The same tokens, wherever their [deadline](Tokens::deadline) was read.
impl PartialEq for Tokens {
    fn eq(&self, other: &Self) -> bool {
        (&self.access, &self.refresh, self.expires_at_ms) == (&other.access, &other.refresh, other.expires_at_ms)
    }
}

impl Eq for Tokens {}

impl std::fmt::Debug for Tokens {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Tokens")
            .field("refresh", &self.refresh.as_ref().map(|_| "…"))
            .field("expires_at_ms", &self.expires_at_ms)
            .finish_non_exhaustive()
    }
}

/// The signed-in person as homebase answers (`LkcUser`): only what is shown,
/// so a field homebase adds or drops elsewhere does not make a stored one
/// unreadable.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    #[serde(default)]
    pub name: String,
    /// `user`, `admin`, `bot`, …
    #[serde(default)]
    pub group: String,
    #[serde(default)]
    pub avatar: Option<String>,
}

/// A device sign-in: the person opens [verification_uri_complete] (or
/// [verification_uri] and types [user_code]) anywhere; the caller polls.
/// `Debug` leaves [device_code] out: it redeems the grant.
#[derive(Clone, PartialEq, Eq)]
pub struct DeviceAuthorization {
    pub device_code: String,
    pub user_code: String,
    pub verification_uri: String,
    pub verification_uri_complete: Option<String>,
    /// Unix milliseconds.
    pub expires_at_ms: i64,
    /// Seconds between polls; raised by a `slow_down`.
    pub interval_secs: u64,
}

impl std::fmt::Debug for DeviceAuthorization {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DeviceAuthorization")
            .field("user_code", &self.user_code)
            .field("verification_uri", &self.verification_uri)
            .field("expires_at_ms", &self.expires_at_ms)
            .finish_non_exhaustive()
    }
}

/// One poll of a device sign-in.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DevicePoll {
    /// Not yet approved; poll again after the interval.
    Pending,
    /// Polled too often; poll again after the given interval (seconds).
    SlowDown(u64),
    Done(Tokens),
}

/// The IdP and homebase, as one client of them.
pub struct Client {
    http: reqwest::Client,
    issuer: String,
    client_id: String,
    api: String,
    metadata: OnceCell<Metadata>,
}

impl Client {
    /// [`CLIENT_ID`] at [`ISSUER`], homebase at [`API`].
    pub fn new() -> Result<Self, Error> {
        Self::with(ISSUER, CLIENT_ID, API)
    }

    /// Nothing is sent until the first request.
    pub fn with(issuer: &str, client_id: &str, api: &str) -> Result<Self, Error> {
        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let roots = rustls::RootCertStore { roots: webpki_roots::TLS_SERVER_ROOTS.to_vec() };
        let tls = rustls::ClientConfig::builder_with_provider(provider)
            .with_safe_default_protocol_versions()
            .map_err(|e| Error::new(Failure::Unreachable, format!("TLS setup: {e}")))?
            .with_root_certificates(roots)
            .with_no_client_auth();
        let http = reqwest::Client::builder()
            .tls_backend_preconfigured(tls)
            // Every endpoint is the service's own; a redirect would carry a
            // code or a token somewhere it did not name.
            .redirect(reqwest::redirect::Policy::none())
            .https_only(true)
            // A device sign-in polls every few seconds; anything else is hours
            // apart, when a pooled connection the other end has closed would
            // fail the next request.
            .pool_idle_timeout(Duration::from_secs(30))
            .connect_timeout(CONNECT_TIMEOUT)
            .timeout(TIMEOUT)
            .build()
            .map_err(|e| Error::new(Failure::Unreachable, format!("HTTP client setup: {e}")))?;
        Ok(Self {
            http,
            issuer: issuer.to_string(),
            client_id: client_id.to_string(),
            api: api.trim_end_matches('/').to_string(),
            metadata: OnceCell::new(),
        })
    }

    pub async fn metadata(&self) -> Result<&Metadata, Error> {
        self.metadata
            .get_or_try_init(|| async {
                let url = format!("{}/.well-known/openid-configuration", self.issuer.trim_end_matches('/'));
                let (status, body) = self.send(self.http.get(&url), &url).await?;
                if !(200..300).contains(&status) {
                    return Err(Error::new(Failure::Unreachable, format!("{url}: HTTP {status}")));
                }
                let doc = serde_json::from_slice(&body)
                    .map_err(|e| Error::new(Failure::InvalidResponse, format!("{url}: not JSON: {e}")))?;
                Metadata::from_json(&self.issuer, &doc)
            })
            .await
    }

    pub async fn start_device(&self) -> Result<DeviceAuthorization, Error> {
        let endpoint = self
            .metadata()
            .await?
            .device_authorization_endpoint
            .clone()
            .ok_or_else(|| Error::new(Failure::InvalidResponse, "the IdP offers no device sign-in"))?;
        let value = self.post_form(&endpoint, &[("scope", SCOPE)]).await.map_err(TokenError::into_error)?;
        parse_device(&value, now_ms())
    }

    /// One poll. [`Failure::Unreachable`] is worth polling again after the
    /// interval; any other failure ends the sign-in.
    pub async fn poll_device(&self, device: &DeviceAuthorization) -> Result<DevicePoll, Error> {
        if now_ms() >= device.expires_at_ms {
            return Err(Error::new(Failure::Expired, "the code expired"));
        }
        let response = self
            .token(&[("grant_type", "urn:ietf:params:oauth:grant-type:device_code"), ("device_code", &device.device_code)])
            .await;
        match response {
            Ok(value) => match Tokens::from_response(&value, now_ms(), None) {
                Ok(tokens) => Ok(DevicePoll::Done(tokens)),
                Err(e) => {
                    self.discard(&value).await;
                    Err(e)
                }
            },
            Err(TokenError::Refused { error, .. }) if error == "authorization_pending" => Ok(DevicePoll::Pending),
            Err(TokenError::Refused { error, .. }) if error == "slow_down" => {
                Ok(DevicePoll::SlowDown(device.interval_secs + 5))
            }
            Err(e) => Err(e.into_error()),
        }
    }

    /// New tokens for [tokens], once [`Tokens::due`]; before that
    /// [`Failure::TooEarly`] and nothing is sent. [`Failure::Rejected`] means
    /// the IdP took the refresh token back and [`Failure::Expired`] that it
    /// ran out: the session is over either way. After [`Failure::Unknown`]
    /// or [`Failure::InvalidResponse`] the token may be spent, and sending
    /// it again ends every session of the person.
    pub async fn refresh(&self, tokens: &Tokens) -> Result<Tokens, Error> {
        let Some(refresh) = tokens.refresh.as_deref() else {
            return Err(Error::new(Failure::Rejected, "no refresh token"));
        };
        if !tokens.due(now_ms()) {
            return Err(Error::new(Failure::TooEarly, "the access token is not due"));
        }
        let value = self
            .token(&[("grant_type", "refresh_token"), ("refresh_token", refresh)])
            .await
            .map_err(TokenError::into_error)?;
        match Tokens::from_response(&value, now_ms(), Some(tokens)) {
            Ok(fresh) => Ok(fresh),
            Err(e) => {
                // A rotated token is let go of; the one sent is spent.
                if value["refresh_token"].as_str() != Some(refresh) {
                    self.discard(&value).await;
                }
                Err(e)
            }
        }
    }

    /// A granted answer this cannot use: its refresh token is revoked rather
    /// than left live with no one holding it.
    async fn discard(&self, value: &Value) {
        if let Some(refresh) = value["refresh_token"].as_str().filter(|s| !s.is_empty()) {
            let _ = self.revoke(refresh).await;
        }
    }

    /// Asks the IdP to forget [refresh_token]. Signing out does not wait on
    /// this: an IdP that cannot be reached leaves the token to expire.
    pub async fn revoke(&self, refresh_token: &str) -> Result<(), Error> {
        let Some(endpoint) = self.metadata().await?.revocation_endpoint.clone() else {
            return Ok(());
        };
        // RFC 7009 answers 200 with an empty body.
        let body = self.form(&[("token", refresh_token), ("token_type_hint", "refresh_token")]);
        let (status, body) = self.send(self.form_request(&endpoint, body), &endpoint).await?;
        if (200..300).contains(&status) {
            return Ok(());
        }
        answer(&endpoint, status, &body).map(drop).map_err(TokenError::into_error)
    }

    /// Who [access] is for: homebase's `GET /auth/user`.
    pub async fn user(&self, access: &str) -> Result<User, Error> {
        let url = format!("{}/auth/user", self.api);
        let request = self.http.get(&url).bearer_auth(access).header(reqwest::header::ACCEPT, "application/json");
        let (status, body) = self.send(request, &url).await?;
        let data = unwrap(&url, status, &body)?;
        serde_json::from_value(data).map_err(|e| Error::new(Failure::InvalidResponse, format!("{url}: {e}")))
    }

    async fn token(&self, pairs: &[(&str, &str)]) -> Result<Value, TokenError> {
        let endpoint = self.metadata().await.map_err(TokenError::Other)?.token_endpoint.clone();
        self.post_form(&endpoint, pairs).await
    }

    async fn post_form(&self, url: &str, pairs: &[(&str, &str)]) -> Result<Value, TokenError> {
        let request = self.form_request(url, self.form(pairs));
        let (status, body) = self.send(request, url).await.map_err(TokenError::Other)?;
        answer(url, status, &body)
    }

    fn form(&self, pairs: &[(&str, &str)]) -> String {
        url::form_urlencoded::Serializer::new(String::new())
            .append_pair("client_id", &self.client_id)
            .extend_pairs(pairs)
            .finish()
    }

    fn form_request(&self, url: &str, body: String) -> reqwest::RequestBuilder {
        self.http
            .post(url)
            .header(reqwest::header::CONTENT_TYPE, "application/x-www-form-urlencoded")
            .header(reqwest::header::ACCEPT, "application/json")
            .body(body)
    }

    async fn send(&self, request: reqwest::RequestBuilder, url: &str) -> Result<(u16, Vec<u8>), Error> {
        let mut response = request.send().await.map_err(|e| unreachable(url, e))?;
        let status = response.status().as_u16();
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(|e| unreachable(url, e))? {
            body.extend_from_slice(&chunk);
            if body.len() > MAX_BODY {
                return Err(Error::new(Failure::InvalidResponse, format!("{url}: answer too large")));
            }
        }
        Ok((status, body))
    }
}

/// A token or device endpoint's answer: its JSON on a success, else why not.
/// Only a 4xx carrying an OAuth `error` is the IdP's refusal. A 429 or a page
/// some proxy answered with (a challenge, an error page) never reached it; a
/// 5xx may have come after it spent the grant.
fn answer(url: &str, status: u16, body: &[u8]) -> Result<Value, TokenError> {
    let again = || TokenError::Other(Error::new(Failure::Unreachable, format!("{url}: HTTP {status}")));
    if status >= 500 {
        return Err(TokenError::Other(Error::new(Failure::Unknown, format!("{url}: HTTP {status}"))));
    }
    if status == 429 {
        return Err(again());
    }
    let value: Option<Value> = serde_json::from_slice(body).ok();
    if (200..300).contains(&status) {
        return value.ok_or_else(|| TokenError::Other(Error::new(Failure::InvalidResponse, format!("{url}: not JSON"))));
    }
    let Some(value) = value.filter(|v| v["error"].is_string()) else {
        return Err(again());
    };
    let text = |name: &str| value[name].as_str().unwrap_or_default().to_string();
    Err(TokenError::Refused { error: text("error"), description: text("error_description") })
}

/// A token or device endpoint's answer other than a success.
enum TokenError {
    /// A 4xx with the IdP's `error` code.
    Refused { error: String, description: String },
    Other(Error),
}

impl TokenError {
    /// Only `invalid_grant` says the grant itself is gone, as fl_lib reads
    /// it, and `expired_token` that it ran out: a refresh refused either way
    /// signs out, any other refusal keeps the session.
    fn into_error(self) -> Error {
        match self {
            TokenError::Refused { error, description } => {
                let failure = match error.as_str() {
                    "invalid_grant" => Failure::Rejected,
                    "access_denied" => Failure::Denied,
                    "expired_token" => Failure::Expired,
                    "temporarily_unavailable" => Failure::Unreachable,
                    "server_error" => Failure::Unknown,
                    _ => Failure::Refused,
                };
                let detail = if description.is_empty() { error } else { format!("{error}: {description}") };
                Error::new(failure, detail.chars().take(200).collect::<String>())
            }
            TokenError::Other(e) => e,
        }
    }
}

/// The `data` of a homebase reply (`LkcClient.unwrap`), or its refusal: `code`
/// is `LkcCode`'s index, left out when `ok`; `perm` (2) is a token homebase
/// no longer takes. Anything not the API's own answer, such as a proxy's
/// page (JSON or not), a 5xx or a 429, is worth trying again.
fn unwrap(url: &str, status: u16, body: &[u8]) -> Result<Value, Error> {
    let again = || Error::new(Failure::Unreachable, format!("{url}: HTTP {status}"));
    if status >= 500 || status == 429 {
        return Err(again());
    }
    let Ok(Value::Object(json)) = serde_json::from_slice::<Value>(body) else {
        return Err(again());
    };
    // Only a success may leave the code out; an error without one is not
    // homebase's.
    let code = match json.get("code") {
        None if (200..300).contains(&status) => Some(0),
        None => return Err(again()),
        Some(code) => code.as_u64(),
    };
    let text = |name: &str| json.get(name).and_then(Value::as_str).unwrap_or_default().to_string();
    match code {
        Some(0) => Ok(json.get("data").cloned().unwrap_or(Value::Null)),
        Some(2) => Err(Error::new(Failure::Rejected, format!("{url}: perm {}", text("reason")))),
        Some(1) => Err(again()),
        Some(code) => Err(Error::new(Failure::Refused, format!("{url}: code {code} {}", text("reason")))),
        None => Err(Error::new(Failure::InvalidResponse, format!("{url}: no code"))),
    }
}

fn parse_device(value: &Value, now_ms: i64) -> Result<DeviceAuthorization, Error> {
    let text = |name: &str| value[name].as_str().filter(|s| !s.is_empty()).map(str::to_string);
    let required = |name: &str| text(name).ok_or_else(|| Error::new(Failure::InvalidResponse, format!("device: no {name}")));
    let device = DeviceAuthorization {
        device_code: required("device_code")?,
        user_code: required("user_code")?,
        verification_uri: required("verification_uri")?,
        verification_uri_complete: text("verification_uri_complete"),
        expires_at_ms: now_ms.saturating_add(
            Duration::from_secs(value["expires_in"].as_u64().filter(|&s| s > 0).unwrap_or(300))
                .min(MAX_LIFETIME)
                .as_millis() as i64,
        ),
        interval_secs: value["interval"].as_u64().unwrap_or(DEVICE_INTERVAL_SECS).max(1),
    };
    let pages = [Some(&device.verification_uri), device.verification_uri_complete.as_ref()];
    if pages.into_iter().flatten().any(|u| !u.starts_with("https://")) {
        return Err(Error::new(Failure::InvalidResponse, "device: verification page is not https://"));
    }
    Ok(device)
}

/// [e] with its causes: reqwest's own text alone says only that sending
/// failed. [`Failure::Unreachable`] when no connection was made, else
/// [`Failure::Unknown`]: the request may have arrived.
fn unreachable(url: &str, e: reqwest::Error) -> Error {
    let failure = if e.is_connect() || e.is_builder() { Failure::Unreachable } else { Failure::Unknown };
    let mut detail = format!("{url}: {e}");
    let mut source = std::error::Error::source(&e);
    while let Some(cause) = source {
        detail.push_str(&format!(": {cause}"));
        source = cause.source();
    }
    Error::new(failure, detail)
}

pub fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as i64).unwrap_or_default()
}

#[cfg(test)]
mod tests;
