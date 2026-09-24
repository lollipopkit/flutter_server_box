//! The HTTP client one PVE request is sent through.
//!
//! **One login per request, and nothing cached.** A ticket could be kept for
//! its two hours and reused, but what invalidates one is not something this
//! agent can observe: a password change, a revoke in PVE's own UI, an ACL edit,
//! a restart of `pveproxy`. A cached ticket therefore fails at an arbitrary
//! later moment, in a request the caller did not connect to the login, and the
//! panel's answer would be about a session it never saw. The cost of not
//! caching is one extra request per page refresh, on an endpoint a person
//! pressed a button to reach.
//!
//! **The upstream's words are carried, its body is not.** A failure answers
//! with the message PVE put in `errors` or `message`, bounded and never the
//! document: the login body is a document about a credential, and `openai`'s
//! rule is the same one — a provider's complaint can echo what it was sent.
//!
//! **No upstream status becomes our status.** PVE answering 401 does not make
//! this agent answer 401: the panel's client logs the operator out on that, and
//! what failed here is the *agent's* credential to a machine the operator is
//! not logged in to. Every upstream failure is answered as an agent-side code
//! instead — see [`PveFailure`].

use std::time::Duration;

use reqwest::header::{COOKIE, CONTENT_TYPE, HeaderName, HeaderValue};
use reqwest::{Client, Response};
use serde_json::Value;

use sbm_parser::pve::{
    AUTH_COOKIE, CSRF_HEADER, PveError, PveResource, RESOURCES_PATH, TICKET_PATH, VERSION_PATH,
    parse_cluster_resources, parse_version, token_header,
};

use crate::core::config::{PveAuthKind, PveConfig};

/// How long a connection may take to open. PVE's own API is on a LAN or a
/// public address; either answers well inside this, and the failure this bounds
/// is an address nothing is listening on.
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

/// How long one request may take. `/cluster/resources` walks every node's
/// guests, which on a large cluster is seconds rather than milliseconds.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

/// The most of a response this agent will read.
///
/// A bound on what a mistyped address can make the agent buffer, not on a real
/// cluster: `/cluster/resources` is a few hundred bytes per guest, so this is
/// some ten thousand of them. Over it, the answer is `invalidResponse` — the
/// address is not answering a PVE API.
pub const MAX_BODY: usize = 4 * 1024 * 1024;

/// The longest upstream message carried to a client. A failure says which
/// machine refused and roughly why; PVE's own diagnostics are the operator's to
/// read in its log, and an arbitrarily long string is something a client would
/// have to render.
const MESSAGE_LIMIT: usize = 300;

/// The header PVE wants beside the cookie on anything that changes state. Sent
/// with a ticket credential only; a token needs no CSRF token, because there is
/// no browser session for a forged request to ride on.
fn csrf_header() -> HeaderName {
    HeaderName::from_static("csrfpreventiontoken")
}

/// What a request is authenticated with, resolved once per call.
///
/// A token needs no login at all — that is the point of it — so
/// [`PveClient::authenticate`] answers one without a request. A ticket carries
/// the CSRF token PVE requires on writes, so both travel together.
pub enum Credential {
    Ticket { ticket: String, csrf: String },
    Token(String),
}

/// Why a request did not answer.
///
/// The codes are the stable names a client phrases, so changing one is a break
/// in the contract. `loginFailed`, `needTfa` and `invalidResponse` are the app's
/// own words for the same conditions (`PveErrType`), kept equal so the same
/// failure reads the same in both clients.
#[derive(Debug)]
pub enum PveFailure {
    /// A refusal of the caller's own arguments, carrying the code to phrase:
    /// `invalidNode` and `invalidVmid` from `sbm_parser::pve`, `invalidUrl`
    /// from a stored address this agent will not send to. Answered as a 400.
    Refused(&'static str),
    /// Nothing answered, or the TLS session would not open.
    Unreachable(String),
    /// PVE refused the credential, or the ticket it issued was not accepted.
    /// PVE's own message, when it gave one.
    LoginFailed(Option<String>),
    /// The account has two-factor authentication, so a ticket cannot be issued
    /// from a password at all. An API token is the way through — it is what PVE
    /// documents for automation, precisely because it bypasses TFA.
    NeedTfa,
    /// The credential authenticated but is not permitted this. Its own code,
    /// where the app folds it into `loginFailed`: a ticket carries the whole
    /// user's rights, so the app's 403 is always a session that has gone, while
    /// a token has its own ACL and PVE answers 403 for a guest it may not
    /// control.
    Forbidden(Option<String>),
    /// The answer was not the document it should have been, at any stage.
    InvalidResponse,
    /// PVE answered an error for an authenticated request. Its own words, when
    /// it gave any.
    Upstream(Option<String>),
}

impl PveFailure {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Refused(code) => code,
            Self::Unreachable(_) => "unreachable",
            Self::LoginFailed(_) => "loginFailed",
            Self::NeedTfa => "needTfa",
            Self::Forbidden(_) => "forbidden",
            Self::InvalidResponse => "invalidResponse",
            Self::Upstream(_) => "upstream",
        }
    }

    /// PVE's own words, when there are any. Absent rather than empty when it
    /// said nothing this agent could read.
    pub fn detail(&self) -> Option<&str> {
        match self {
            Self::Unreachable(detail) => Some(detail.as_str()).filter(|d| !d.is_empty()),
            Self::LoginFailed(detail) | Self::Forbidden(detail) | Self::Upstream(detail) => {
                detail.as_deref()
            }
            Self::Refused(_) | Self::NeedTfa | Self::InvalidResponse => None,
        }
    }

    /// Whether this is a failure of the transport rather than of the request.
    /// What the endpoint turns into a 502: the agent could not reach the
    /// cluster, or could not read what it answered. Everything else is about
    /// the caller's request or the stored credential, and is a 400.
    pub fn is_transport(&self) -> bool {
        matches!(self, Self::Unreachable(_) | Self::InvalidResponse | Self::Upstream(_))
    }
}

/// A base URL this agent could send a request to.
///
/// A URL rather than "not empty", and a scheme rather than any URL: an operator
/// who typed `pve.example.com:8006` with no scheme would otherwise get a page
/// that fails on every request with the same `unreachable`, a minute after the
/// save instead of at it. Answers the URL with no trailing slash, which is what
/// every path below is appended to.
pub fn validate_url(value: &str) -> Result<String, &'static str> {
    let trimmed = value.trim();
    let Ok(url) = reqwest::Url::parse(trimmed) else {
        return Err("invalidUrl");
    };
    if !matches!(url.scheme(), "http" | "https") {
        return Err("invalidUrl");
    }
    if url.host_str().is_none_or(str::is_empty) {
        return Err("invalidUrl");
    }
    // A base with a path would silently lose it: the paths below are absolute.
    // PVE never serves its API under one, so the operator's intent is the host
    // and port, and this says so rather than dropping a segment they typed.
    if url.path() != "/" && !url.path().is_empty() {
        return Err("invalidUrl");
    }
    Ok(trimmed.trim_end_matches('/').to_string())
}

/// One cluster, one credential, and the client requests go through.
pub struct PveClient {
    http: Client,
    base: String,
    config: PveConfig,
}

impl PveClient {
    /// Builds a client for one cluster. The URL is validated here, so the
    /// caller may hold a stored one that predates the check.
    pub fn new(config: &PveConfig) -> Result<Self, PveFailure> {
        let base = validate_url(&config.url).map_err(PveFailure::Refused)?;

        // reqwest is built without a crypto provider of its own, so the one the
        // rest of the agent uses has to be the process default before a TLS
        // config is built — otherwise the first request panics inside rustls
        // rather than failing as a request error. `ring`, matching every other
        // TLS user in this binary; `monitoring::push::http_client` installs the
        // same one, and a second call answers `Err` rather than replacing it.
        let _ = rustls::crypto::ring::default_provider().install_default();

        let builder = Client::builder()
            .connect_timeout(CONNECT_TIMEOUT)
            .timeout(REQUEST_TIMEOUT)
            .pool_idle_timeout(Duration::from_secs(60))
            // Per cluster, because a PVE install answers on its own certificate
            // and a self-signed one is the common case: without this the
            // feature works only after the operator has done PKI for a machine
            // they already trust.
            .danger_accept_invalid_certs(config.ignore_cert);
        #[cfg(test)]
        let builder = builder.no_proxy();
        let http = builder.build().map_err(|e| {
            tracing::warn!("pve: could not build the HTTP client: {e}");
            PveFailure::Unreachable("the HTTP client could not be built".into())
        })?;

        Ok(Self {
            http,
            base,
            config: config.clone(),
        })
    }

    /// The credential one call is made with. A token answers itself; a password
    /// is exchanged for a ticket here.
    pub async fn authenticate(&self) -> Result<Credential, PveFailure> {
        match self.config.auth {
            PveAuthKind::Token => {
                let secret = self.secret()?;
                Ok(Credential::Token(token_header(
                    self.config.username.trim(),
                    self.config.realm.trim(),
                    self.config.token_id.trim(),
                    secret,
                )))
            }
            PveAuthKind::Password => self.ticket().await,
        }
    }

    /// The stored secret, or a refusal. `None` is what an absent one is in the
    /// config, and the endpoint reports that as `secret_set` rather than
    /// letting a request go out with an empty password — which PVE would answer
    /// as a failed login, a code that names the wrong thing.
    fn secret(&self) -> Result<&str, PveFailure> {
        match self.config.secret.as_deref() {
            Some(secret) if !secret.is_empty() => Ok(secret),
            _ => Err(PveFailure::LoginFailed(Some(
                "no credential is stored for this cluster".to_string(),
            ))),
        }
    }

    async fn ticket(&self) -> Result<Credential, PveFailure> {
        let secret = self.secret()?;
        let response = self
            .http
            .post(self.url(TICKET_PATH))
            .form(&[
                ("username", self.config.username.trim()),
                ("password", secret),
                ("realm", self.config.realm.trim()),
                // PVE ≥ 6 answers the newer shape with this; without it an
                // account with TFA enabled is not told so.
                ("new-format", "1"),
            ])
            .send()
            .await
            .map_err(unreachable)?;

        let body = self.body(response, true).await?;
        let data = data(&body)?;
        // A ticket request that PVE answered without complaint but without
        // trusting the caller: the password was accepted and a second factor is
        // still owed. Neither a failure of the credential nor a session.
        let needs_tfa = data.get("NeedTFA").and_then(Value::as_u64) == Some(1)
            || data.get("TFA").is_some_and(|value| !value.is_null());
        if needs_tfa {
            return Err(PveFailure::NeedTfa);
        }

        let ticket = non_empty_str(data.get("ticket")).ok_or(PveFailure::InvalidResponse)?;
        // Required, not optional: this credential is used to change state, and
        // PVE refuses a write without it. Missing now is a clear refusal at the
        // login rather than a 401 on the press of a button later.
        let csrf =
            non_empty_str(data.get(CSRF_HEADER)).ok_or(PveFailure::InvalidResponse)?;
        Ok(Credential::Ticket {
            ticket: ticket.to_string(),
            csrf: csrf.to_string(),
        })
    }

    /// The cluster's release, e.g. `8.2.4`. `None` when PVE did not say.
    pub async fn version(&self, credential: &Credential) -> Result<Option<String>, PveFailure> {
        let response = self.get(VERSION_PATH, credential).await?;
        let body = self.body(response, false).await?;
        Ok(parse_version(&body))
    }

    /// Every resource in the cluster, sorted and with unreadable entries
    /// skipped — `sbm_parser::pve` owns both of those decisions.
    pub async fn resources(&self, credential: &Credential) -> Result<Vec<PveResource>, PveFailure> {
        let response = self.get(RESOURCES_PATH, credential).await?;
        let body = self.body(response, true).await?;
        parse_cluster_resources(&body).map_err(|error| match error {
            PveError::InvalidResponse => PveFailure::InvalidResponse,
            // Unreachable from here: the path this reads is fixed, and both
            // codes are about a caller's arguments.
            other => {
                tracing::warn!("pve: {} from a listing this agent composed", other.as_str());
                PveFailure::InvalidResponse
            }
        })
    }

    /// Starts, stops, shuts down or reboots one guest, at a path the caller
    /// composed. Answers the UPID PVE assigned the task, when it gave one.
    ///
    /// The path arrives rather than being built here because it is built by
    /// `sbm_parser::pve::control_path`, which validates every part of it, and
    /// the endpoint calls that **before** it dials: a node name this agent
    /// would not put in a path is the caller's mistake, and a login spent on it
    /// is a request PVE never needed to see. Nothing here formats one.
    pub async fn control(
        &self,
        credential: &Credential,
        path: &str,
    ) -> Result<Option<String>, PveFailure> {
        let request = self
            .http
            .post(self.url(path))
            .header(CONTENT_TYPE, "application/x-www-form-urlencoded");
        let response = self.send(request, credential).await?;
        // `data` is not required here: PVE answers a status change with the
        // task's UPID, and a build that answered nothing but 200 would still
        // have performed it. Refusing that would report a failure for a machine
        // that did what it was asked.
        let body = self.body(response, false).await?;
        // `{"data": "UPID:pve:..."}` on success. Its absence is not a failure:
        // PVE answers a status change with the task id, and a build that did
        // not would still have performed it.
        Ok(non_empty_str(body.get("data")).map(str::to_string))
    }

    async fn get(&self, path: &str, credential: &Credential) -> Result<Response, PveFailure> {
        let request = self.http.get(self.url(path));
        self.send(request, credential).await
    }

    async fn send(
        &self,
        request: reqwest::RequestBuilder,
        credential: &Credential,
    ) -> Result<Response, PveFailure> {
        let request = match credential {
            Credential::Ticket { ticket, csrf } => request
                .header(
                    COOKIE,
                    HeaderValue::from_str(&format!("{AUTH_COOKIE}={ticket}"))
                        .map_err(|_| PveFailure::InvalidResponse)?,
                )
                .header(
                    csrf_header(),
                    HeaderValue::from_str(csrf).map_err(|_| PveFailure::InvalidResponse)?,
                ),
            Credential::Token(header) => request.header(
                reqwest::header::AUTHORIZATION,
                HeaderValue::from_str(header).map_err(|_| PveFailure::InvalidResponse)?,
            ),
        };
        request.send().await.map_err(unreachable)
    }

    /// Checks the status, caps the body and parses it as JSON.
    ///
    /// `data_expected` says whether the document must carry PVE's `data`
    /// member: a read that answers a value must have one, while a write is read
    /// for its outcome rather than its payload.
    async fn body(&self, response: Response, data_expected: bool) -> Result<Value, PveFailure> {
        let status = response.status();
        if let Some(length) = response.content_length()
            && length > MAX_BODY as u64
        {
            return Err(PveFailure::InvalidResponse);
        }
        let text = response.text().await.map_err(unreachable)?;
        if text.len() > MAX_BODY {
            return Err(PveFailure::InvalidResponse);
        }

        if !status.is_success() {
            let message = upstream_message(&text);
            return Err(match status.as_u16() {
                // The credential, or what it is permitted. Answered as their
                // own codes rather than passed through: a 401 here would log
                // the operator out of a panel they are still signed in to.
                401 => PveFailure::LoginFailed(message),
                403 => PveFailure::Forbidden(message),
                _ => PveFailure::Upstream(message),
            });
        }

        let body: Value =
            serde_json::from_str(&text).map_err(|_| PveFailure::InvalidResponse)?;
        if body.get("data").is_none() && data_expected {
            // PVE answers `{"data": …}` for everything, including `null`. A
            // document without the key is not one of its answers.
            return Err(PveFailure::InvalidResponse);
        }
        Ok(body)
    }

    /// The absolute URL of a path this agent composed. `base` carries no
    /// trailing slash and every path here begins with one.
    fn url(&self, path: &str) -> String {
        format!("{}{path}", self.base)
    }
}

fn unreachable(error: reqwest::Error) -> PveFailure {
    // The URL is not in it: `reqwest::Error`'s own Display can carry the
    // address, which is the operator's network and not something a response
    // needs to say.
    let detail = if error.is_timeout() {
        "the request timed out".to_string()
    } else if error.is_connect() {
        "the connection could not be opened".to_string()
    } else {
        "the request could not be completed".to_string()
    };
    tracing::debug!("pve: {error}");
    PveFailure::Unreachable(detail)
}

fn non_empty_str(value: Option<&Value>) -> Option<&str> {
    value.and_then(Value::as_str).filter(|s| !s.is_empty())
}

/// The `data` member, which is where PVE puts everything. `PveClient::body`
/// already checked it is there when the caller said it must be; this is the
/// read that cannot fail for that caller.
fn data(body: &Value) -> Result<&Value, PveFailure> {
    body.get("data").ok_or(PveFailure::InvalidResponse)
}

/// PVE's own words about why a request failed, bounded, or nothing.
///
/// Both shapes it uses: `errors` is a map of parameter to complaint (a refused
/// login answers one), `message` is a single sentence. Anything else is not
/// carried — the body is a document about a credential, and this agent does not
/// hand documents back to a browser.
fn upstream_message(body: &str) -> Option<String> {
    let parsed: Value = serde_json::from_str(body).ok()?;
    let message = parsed
        .get("errors")
        .and_then(Value::as_object)
        .map(|errors| {
            errors
                .values()
                .filter_map(Value::as_str)
                .collect::<Vec<&str>>()
                .join("; ")
        })
        .filter(|text| !text.is_empty())
        .or_else(|| non_empty_str(parsed.get("message")).map(str::to_string))?;
    Some(message.chars().take(MESSAGE_LIMIT).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_address_is_a_url_a_request_can_be_sent_to() {
        assert_eq!(
            validate_url("https://pve.example.com:8006"),
            Ok("https://pve.example.com:8006".to_string())
        );
        // A trailing slash is what a browser's address bar produces, and the
        // paths below are absolute.
        assert_eq!(
            validate_url("https://pve.example.com:8006/"),
            Ok("https://pve.example.com:8006".to_string())
        );
        assert_eq!(
            validate_url("  http://127.0.0.1:8006  "),
            Ok("http://127.0.0.1:8006".to_string())
        );

        // No scheme, which is the mistake this check exists for.
        assert_eq!(validate_url("pve.example.com:8006"), Err("invalidUrl"));
        assert_eq!(validate_url(""), Err("invalidUrl"));
        assert_eq!(validate_url("ftp://pve.example.com"), Err("invalidUrl"));
        assert_eq!(validate_url("file:///etc/passwd"), Err("invalidUrl"));
        assert_eq!(validate_url("https://"), Err("invalidUrl"));
        // A path would be dropped by `url`, silently.
        assert_eq!(validate_url("https://pve.example.com/api2"), Err("invalidUrl"));
    }

    #[test]
    fn an_upstream_message_is_its_own_words_or_nothing() {
        assert_eq!(
            upstream_message(r#"{"data":null,"errors":{"password":"invalid credentials"}}"#),
            Some("invalid credentials".to_string())
        );
        assert_eq!(
            upstream_message(r#"{"message":"no such node"}"#),
            Some("no such node".to_string())
        );
        // Several complaints are all carried: PVE lists them together and the
        // operator's fix depends on which ones.
        assert!(
            upstream_message(r#"{"errors":{"a":"one","b":"two"}}"#)
                .is_some_and(|m| m.contains("one") && m.contains("two"))
        );
        assert_eq!(upstream_message(r#"{"data":null}"#), None);
        assert_eq!(upstream_message("not json"), None);
        assert_eq!(upstream_message(""), None);
        // A long one is cut rather than passed on whole.
        let long = upstream_message(&format!(r#"{{"message":"{}"}}"#, "x".repeat(500))).unwrap();
        assert_eq!(long.chars().count(), MESSAGE_LIMIT);
    }

    #[test]
    fn a_failure_answers_a_code_and_never_a_status() {
        // The codes are the contract, so they are asserted rather than derived.
        assert_eq!(PveFailure::Unreachable(String::new()).code(), "unreachable");
        assert_eq!(PveFailure::LoginFailed(None).code(), "loginFailed");
        assert_eq!(PveFailure::NeedTfa.code(), "needTfa");
        assert_eq!(PveFailure::Forbidden(None).code(), "forbidden");
        assert_eq!(PveFailure::InvalidResponse.code(), "invalidResponse");
        assert_eq!(PveFailure::Upstream(None).code(), "upstream");
        // A refusal carries the code it was given, and they are the parser's
        // own for the two it raises.
        assert_eq!(PveFailure::Refused("invalidNode").code(), "invalidNode");
        assert_eq!(
            PveFailure::Refused(PveError::InvalidVmid.as_str()).code(),
            "invalidVmid"
        );

        // An empty detail is absent, not a blank line a client would render.
        assert_eq!(PveFailure::Unreachable(String::new()).detail(), None);
        assert_eq!(
            PveFailure::Upstream(Some("no such node".to_string())).detail(),
            Some("no such node")
        );
        assert_eq!(PveFailure::NeedTfa.detail(), None);
    }

    #[test]
    fn a_transport_failure_is_told_apart_from_a_refusal() {
        assert!(PveFailure::Unreachable(String::new()).is_transport());
        assert!(PveFailure::InvalidResponse.is_transport());
        assert!(PveFailure::Upstream(None).is_transport());
        // These three are about the request or the credential, and the client
        // has something to do about them.
        assert!(!PveFailure::LoginFailed(None).is_transport());
        assert!(!PveFailure::NeedTfa.is_transport());
        assert!(!PveFailure::Forbidden(None).is_transport());
        assert!(!PveFailure::Refused("invalidNode").is_transport());
    }

    #[test]
    fn a_config_without_a_secret_is_refused_by_name() {
        let config = PveConfig {
            url: "https://pve.example.com:8006".to_string(),
            username: "root".to_string(),
            realm: "pam".to_string(),
            ..PveConfig::default()
        };
        let client = PveClient::new(&config).expect("a valid address");
        let failure = client.secret().expect_err("no secret is stored");
        assert_eq!(failure.code(), "loginFailed");
        assert!(failure.detail().is_some());
    }
}
