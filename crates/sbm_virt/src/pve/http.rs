//! How a request reaches the PVE API: one [`Http`] per configuration, made by
//! a [`Connector`]. [`TlsConnector`] is the real one; tests script the API
//! behind the same trait.
//!
//! **The byte stream is the caller's** ([`Dial`]): the agent opens a TCP
//! connection itself ([`TcpDial`]); the app reaches PVE over SSH, its agent's
//! relay or directly, through a loopback port its `ServerTcpDialer` serves
//! with an access token ([`LoopbackDial`]). The address's host is resolved on
//! the far end of that stream, so `https://127.0.0.1:8006` is the PVE host
//! itself in every case.
//!
//! **TLS is decided here**, not by the stream: a certificate that validates
//! against the trust roots is trusted as it is; otherwise its SHA-256 must be
//! the pinned one. With none pinned, or a different one, the request fails
//! with the certificate it was shown ([`TransportError::Cert`]) — before
//! anything was sent, since the request carries a password or a token.

use std::future::Future;
use std::io;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};
use std::time::Duration;

use bytes::Bytes;
use http_body_util::{BodyExt, Full, Limited};
use hyper::Uri;
use hyper::rt::{Read, ReadBufCursor, Write};
use hyper_util::client::legacy::Client as HyperClient;
use hyper_util::client::legacy::connect::{Connected, Connection};
use hyper_util::rt::{TokioExecutor, TokioIo, TokioTimer};
use rustls::client::WebPkiServerVerifier;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::WebPkiSupportedAlgorithms;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{CertificateError, DigitallySignedStruct, RootCertStore, SignatureScheme};
use sbm_redfish::cert::{CertInfo, PinnedCert, fingerprint};
use tokio::io::{AsyncRead, AsyncWrite, AsyncWriteExt};

use super::Config;
use crate::error::{Error, ErrorKind};

pub type BoxFuture<'a, T> = Pin<Box<dyn Future<Output = T> + Send + 'a>>;

/// How long a connection may take to open, TLS included.
pub const CONNECT_TIMEOUT: Duration = Duration::from_secs(15);

/// How long one request may take.
pub const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

/// How long an idle connection is kept for the next request: under
/// pveproxy's own 5 s, after which it closes the connection. A request sent
/// on one as pveproxy closes it fails with "Connection closed before full
/// header was received" (PVE 9.2, directly and over SSH) — for a power
/// action, after it may have been received.
pub const IDLE_TIMEOUT: Duration = Duration::from_secs(3);

/// The most of one response read. `/cluster/resources` of a large cluster is
/// the largest answer, and is kilobytes per guest.
pub const MAX_BODY: usize = 32 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Method {
    Get,
    Post,
    Put,
    Delete,
}

impl Method {
    pub fn as_str(self) -> &'static str {
        match self {
            Method::Get => "GET",
            Method::Post => "POST",
            Method::Put => "PUT",
            Method::Delete => "DELETE",
        }
    }
}

/// A request body and its content type.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Body {
    pub content_type: String,
    pub bytes: Vec<u8>,
}

impl Body {
    /// `application/x-www-form-urlencoded`, what PVE's own clients send.
    pub fn form(encoded: String) -> Self {
        Self { content_type: "application/x-www-form-urlencoded".into(), bytes: encoded.into_bytes() }
    }
}

/// One API request. `path` is under the address's root, query included
/// (`/api2/json/cluster/resources`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Request {
    pub method: Method,
    pub path: String,
    pub headers: Vec<(String, String)>,
    pub body: Option<Body>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Response {
    pub status: u16,
    /// The reason phrase, which carries PVE's message on some refusals.
    pub reason: Option<String>,
    pub body: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TransportError {
    /// Nothing answered, or not with a response.
    Unreachable(String),
    /// The certificate was neither CA-valid nor the pinned one.
    Cert { cert: CertInfo, pinned: Option<String> },
}

/// Sends requests to one address, with one certificate decision.
pub trait Http: Send + Sync {
    fn send(&self, req: Request) -> BoxFuture<'_, Result<Response, TransportError>>;

    /// A websocket upgrade of `req` (a console's `vncwebsocket`): the stream
    /// it became, or the answer that refused it.
    fn upgrade(&self, req: Request) -> BoxFuture<'_, Result<Upgrade, TransportError>> {
        let _ = req;
        Box::pin(async { Err(TransportError::Unreachable("no upgrades here".into())) })
    }
}

/// What a websocket upgrade came to.
pub enum Upgrade {
    /// `101 Switching Protocols`: the connection, now the websocket's.
    Switched(Box<dyn Stream>),
    /// Anything else, as answered.
    Refused(Response),
}

/// Makes the [`Http`] for a configuration: its address and its pin. A new one
/// is made whenever either changes, so a request of an older session never
/// reaches a new address.
pub trait Connector: Send + Sync {
    fn http(&self, config: &Config) -> Result<Arc<dyn Http>, Error>;
}

// ---------------------------------------------------------------------------
// Byte streams
// ---------------------------------------------------------------------------

pub trait Stream: AsyncRead + AsyncWrite + Unpin + Send {}
impl<T: AsyncRead + AsyncWrite + Unpin + Send> Stream for T {}

/// Opens a byte stream to `host:port` as seen from the PVE server.
pub trait Dial: Send + Sync {
    fn dial(&self, host: String, port: u16) -> BoxFuture<'static, io::Result<Box<dyn Stream>>>;
}

/// A TCP connection from this machine: the agent on the PVE host.
pub struct TcpDial;

impl Dial for TcpDial {
    fn dial(&self, host: String, port: u16) -> BoxFuture<'static, io::Result<Box<dyn Stream>>> {
        Box::pin(async move {
            let stream = tokio::net::TcpStream::connect((host.as_str(), port)).await?;
            stream.set_nodelay(true)?;
            Ok(Box::new(stream) as Box<dyn Stream>)
        })
    }
}

/// A loopback port whose server carries a connection only after it has been
/// sent `token` (the app's authenticated `ServerTcpDialer.loopback`). Where it
/// connects to was fixed when the port was opened; `host` and `port` are not
/// sent.
pub struct LoopbackDial {
    pub port: u16,
    pub token: Vec<u8>,
}

impl Dial for LoopbackDial {
    fn dial(&self, _host: String, _port: u16) -> BoxFuture<'static, io::Result<Box<dyn Stream>>> {
        let (port, token) = (self.port, self.token.clone());
        Box::pin(async move {
            let mut stream = tokio::net::TcpStream::connect((std::net::Ipv4Addr::LOCALHOST, port)).await?;
            stream.set_nodelay(true)?;
            stream.write_all(&token).await?;
            Ok(Box::new(stream) as Box<dyn Stream>)
        })
    }
}

// ---------------------------------------------------------------------------
// The real connector
// ---------------------------------------------------------------------------

/// HTTP/1.1 over [`Dial`]'s streams, TLS decided by [`PveVerifier`].
pub struct TlsConnector {
    dial: Arc<dyn Dial>,
    roots: Arc<RootCertStore>,
}

impl TlsConnector {
    /// Trusting the Mozilla roots (`webpki-roots`), which is what "signed by
    /// a CA" means here on every platform alike. A certificate from a private
    /// CA is pinned like a self-signed one.
    pub fn new(dial: Arc<dyn Dial>) -> Self {
        let roots = RootCertStore { roots: webpki_roots::TLS_SERVER_ROOTS.to_vec() };
        Self::with_roots(dial, roots)
    }

    pub fn with_roots(dial: Arc<dyn Dial>, roots: RootCertStore) -> Self {
        Self { dial, roots: Arc::new(roots) }
    }
}

impl Connector for TlsConnector {
    fn http(&self, config: &Config) -> Result<Arc<dyn Http>, Error> {
        let base = config.base_uri()?;
        let provider = Arc::new(rustls::crypto::ring::default_provider());
        // No roots, no CA check: only the pin decides.
        let webpki = if self.roots.is_empty() {
            None
        } else {
            Some(
                WebPkiServerVerifier::builder_with_provider(self.roots.clone(), provider.clone())
                    .build()
                    .map_err(|e| Error::msg(ErrorKind::Unreachable, e.to_string()))?,
            )
        };
        let tls = TlsPolicy { provider, webpki, pin: PinnedCert::new(config.cert_sha256.as_deref()) };
        // Checked once here, so a connection's own build cannot fail on it.
        tls.client_config(Arc::new(Mutex::new(None))).map_err(|e| Error::msg(ErrorKind::Unreachable, e.to_string()))?;
        let connect = PveConnect { dial: self.dial.clone(), tls: Arc::new(tls) };
        let client = HyperClient::builder(TokioExecutor::new())
            .pool_idle_timeout(IDLE_TIMEOUT)
            .pool_timer(TokioTimer::new())
            .pool_max_idle_per_host(4)
            .build(connect);
        Ok(Arc::new(HyperHttp { client, base, pin: config.cert_sha256.clone() }))
    }
}

/// The certificate decision, made into a TLS configuration per connection:
/// each handshake keeps the leaf it refused in a slot of its own, so a
/// failed request reports the certificate its own connection was shown,
/// never one a connection beside it was.
struct TlsPolicy {
    provider: Arc<rustls::crypto::CryptoProvider>,
    webpki: Option<Arc<WebPkiServerVerifier>>,
    pin: PinnedCert,
}

impl TlsPolicy {
    fn client_config(&self, presented: Arc<Mutex<Option<Vec<u8>>>>) -> Result<rustls::ClientConfig, rustls::Error> {
        let verifier = PveVerifier {
            webpki: self.webpki.clone(),
            pin: self.pin.clone(),
            presented,
            algorithms: self.provider.signature_verification_algorithms,
        };
        Ok(rustls::ClientConfig::builder_with_provider(self.provider.clone())
            .with_safe_default_protocol_versions()?
            .dangerous()
            .with_custom_certificate_verifier(Arc::new(verifier))
            .with_no_client_auth())
    }
}

/// A handshake refused for its certificate: the leaf it presented, carried
/// up through hyper's error to the request whose connection it was.
#[derive(Debug)]
struct CertRefused(Vec<u8>);

impl std::fmt::Display for CertRefused {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("certificate refused")
    }
}

impl std::error::Error for CertRefused {}

/// The refused leaf somewhere in `e`'s chain. An `io::Error` hides its inner
/// error from `source()`, so each one is looked into.
fn refused_cert(e: &(dyn std::error::Error + 'static)) -> Option<Vec<u8>> {
    let mut at = Some(e);
    while let Some(err) = at {
        if let Some(c) = err.downcast_ref::<CertRefused>() {
            return Some(c.0.clone());
        }
        if let Some(c) = err.downcast_ref::<io::Error>().and_then(|io| io.get_ref()).and_then(|i| i.downcast_ref::<CertRefused>()) {
            return Some(c.0.clone());
        }
        at = err.source();
    }
    None
}

struct HyperHttp {
    client: HyperClient<PveConnect, Full<Bytes>>,
    base: Uri,
    pin: Option<String>,
}

impl Http for HyperHttp {
    fn upgrade(&self, req: Request) -> BoxFuture<'_, Result<Upgrade, TransportError>> {
        Box::pin(async move {
            let uri = format!("{}{}", self.base.to_string().trim_end_matches('/'), req.path);
            let mut builder = hyper::Request::builder()
                .method("GET")
                .uri(uri)
                .header("connection", "Upgrade")
                .header("upgrade", "websocket")
                .header("sec-websocket-version", "13")
                .header("sec-websocket-key", tokio_tungstenite::tungstenite::handshake::client::generate_key())
                // What PVE's own clients ask for: frames relayed byte for byte.
                .header("sec-websocket-protocol", "binary");
            for (k, v) in &req.headers {
                builder = builder.header(k, v);
            }
            let request = builder
                .body(Full::new(Bytes::new()))
                .map_err(|e| TransportError::Unreachable(e.to_string()))?;
            // One deadline for the answer and, when it refuses, the body it
            // says why in: a refusal whose body never ends is no answer.
            let answer = tokio::time::timeout(REQUEST_TIMEOUT, async {
                let resp = self.client.request(request).await?;
                if resp.status() == hyper::StatusCode::SWITCHING_PROTOCOLS {
                    return Ok::<_, hyper_util::client::legacy::Error>(Ok(resp));
                }
                let status = resp.status().as_u16();
                let body = Limited::new(resp.into_body(), MAX_BODY).collect().await.map(|b| b.to_bytes().to_vec()).unwrap_or_default();
                Ok(Err(Response { status, reason: None, body }))
            })
            .await;
            let resp = match answer {
                Ok(Ok(Ok(resp))) => resp,
                Ok(Ok(Err(refused))) => return Ok(Upgrade::Refused(refused)),
                Ok(Err(e)) => return Err(self.transport_error(&e)),
                Err(_) => return Err(TransportError::Unreachable("no answer to the upgrade".into())),
            };
            let upgraded = hyper::upgrade::on(resp).await.map_err(|e| TransportError::Unreachable(e.to_string()))?;
            Ok(Upgrade::Switched(Box::new(TokioIo::new(upgraded)) as Box<dyn Stream>))
        })
    }

    fn send(&self, req: Request) -> BoxFuture<'_, Result<Response, TransportError>> {
        Box::pin(async move {
            let uri = format!("{}{}", self.base.to_string().trim_end_matches('/'), req.path);
            let mut builder = hyper::Request::builder().method(req.method.as_str()).uri(uri);
            for (k, v) in &req.headers {
                builder = builder.header(k, v);
            }
            let body = match req.body {
                Some(body) => {
                    builder = builder.header("content-type", body.content_type);
                    Full::new(Bytes::from(body.bytes))
                }
                None => Full::new(Bytes::new()),
            };
            let request = builder.body(body).map_err(|e| TransportError::Unreachable(e.to_string()))?;
            let sent = tokio::time::timeout(REQUEST_TIMEOUT, async {
                let resp = self.client.request(request).await?;
                let status = resp.status();
                // PVE writes its refusal into the status line ("401 No ticket").
                // hyper keeps a phrase only where it is not the standard one,
                // which says nothing the status does not.
                let reason = resp
                    .extensions()
                    .get::<hyper::ext::ReasonPhrase>()
                    .map(|r| String::from_utf8_lossy(r.as_bytes()).into_owned());
                let body = Limited::new(resp.into_body(), MAX_BODY)
                    .collect()
                    .await
                    .map_err(|e| io::Error::other(e.to_string()))?
                    .to_bytes();
                Ok::<_, Box<dyn std::error::Error + Send + Sync>>((status, reason, body))
            })
            .await;
            match sent {
                Ok(Ok((status, reason, body))) => Ok(Response { status: status.as_u16(), reason, body: body.to_vec() }),
                Ok(Err(e)) => Err(self.transport_error(e.as_ref())),
                Err(_) => Err(TransportError::Unreachable(format!(
                    "no answer within {}s",
                    REQUEST_TIMEOUT.as_secs()
                ))),
            }
        })
    }
}

impl HyperHttp {
    fn transport_error(&self, e: &(dyn std::error::Error + 'static)) -> TransportError {
        match refused_cert(e).and_then(|der| CertInfo::from_der(&der).or_else(|| bare_info(&der))) {
            Some(cert) => TransportError::Cert { cert, pinned: self.pin.clone() },
            None => TransportError::Unreachable(error_chain(e)),
        }
    }
}

/// A certificate `x509-cert` cannot read is still shown by its fingerprint,
/// rather than hidden behind a bare handshake error.
fn bare_info(der: &[u8]) -> Option<CertInfo> {
    Some(CertInfo {
        fingerprint: fingerprint(der),
        subject: String::new(),
        issuer: String::new(),
        not_before: 0,
        not_after: 0,
    })
}

fn error_chain(e: &(dyn std::error::Error + 'static)) -> String {
    let mut out = e.to_string();
    let mut source = e.source();
    while let Some(s) = source {
        let text = s.to_string();
        if !out.contains(&text) {
            out.push_str(": ");
            out.push_str(&text);
        }
        source = s.source();
    }
    out
}

/// CA-valid, or the pinned leaf. A refused leaf is kept for the error.
#[derive(Debug)]
struct PveVerifier {
    webpki: Option<Arc<WebPkiServerVerifier>>,
    pin: PinnedCert,
    presented: Arc<Mutex<Option<Vec<u8>>>>,
    algorithms: WebPkiSupportedAlgorithms,
}

impl ServerCertVerifier for PveVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        intermediates: &[CertificateDer<'_>],
        server_name: &ServerName<'_>,
        ocsp_response: &[u8],
        now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        if self.pin.accepts(Some(end_entity.as_ref()))
            || self.webpki.as_ref().is_some_and(|v| {
                v.verify_server_cert(end_entity, intermediates, server_name, ocsp_response, now).is_ok()
            })
        {
            return Ok(ServerCertVerified::assertion());
        }
        *self.presented.lock().unwrap() = Some(end_entity.as_ref().to_vec());
        Err(rustls::Error::InvalidCertificate(CertificateError::ApplicationVerificationFailure))
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls12_signature(message, cert, dss, &self.algorithms)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}

/// hyper's connector: a [`Dial`] stream, secured for `https`.
#[derive(Clone)]
struct PveConnect {
    dial: Arc<dyn Dial>,
    tls: Arc<TlsPolicy>,
}

impl tower_service::Service<Uri> for PveConnect {
    type Response = Conn;
    type Error = io::Error;
    type Future = BoxFuture<'static, io::Result<Conn>>;

    fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        Poll::Ready(Ok(()))
    }

    fn call(&mut self, uri: Uri) -> Self::Future {
        let (dial, tls) = (self.dial.clone(), self.tls.clone());
        Box::pin(async move {
            let https = uri.scheme_str() == Some("https");
            let host = uri.host().unwrap_or_default().trim_start_matches('[').trim_end_matches(']').to_owned();
            let port = uri.port_u16().unwrap_or(if https { 443 } else { 80 });
            let opened = tokio::time::timeout(CONNECT_TIMEOUT, async {
                let stream = dial.dial(host.clone(), port).await?;
                if !https {
                    return Ok(stream);
                }
                let name = ServerName::try_from(host).map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
                let presented = Arc::new(Mutex::new(None));
                let config = tls.client_config(presented.clone()).map_err(io::Error::other)?;
                match tokio_rustls::TlsConnector::from(Arc::new(config)).connect(name, stream).await {
                    Ok(secured) => Ok::<_, io::Error>(Box::new(secured) as Box<dyn Stream>),
                    Err(e) => Err(match presented.lock().unwrap().take() {
                        Some(der) => io::Error::other(CertRefused(der)),
                        None => e,
                    }),
                }
            })
            .await
            .map_err(|_| io::Error::new(io::ErrorKind::TimedOut, "connect timed out"))??;
            Ok(Conn(TokioIo::new(opened)))
        })
    }
}

struct Conn(TokioIo<Box<dyn Stream>>);

impl Connection for Conn {
    fn connected(&self) -> Connected {
        Connected::new()
    }
}

impl Read for Conn {
    fn poll_read(self: Pin<&mut Self>, cx: &mut Context<'_>, buf: ReadBufCursor<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.get_mut().0).poll_read(cx, buf)
    }
}

impl Write for Conn {
    fn poll_write(self: Pin<&mut Self>, cx: &mut Context<'_>, buf: &[u8]) -> Poll<io::Result<usize>> {
        Pin::new(&mut self.get_mut().0).poll_write(cx, buf)
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.get_mut().0).poll_flush(cx)
    }

    fn poll_shutdown(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        Pin::new(&mut self.get_mut().0).poll_shutdown(cx)
    }
}
