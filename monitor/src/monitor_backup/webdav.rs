//! A WebDAV folder (RFC 4918), as much of one as backups need: list it,
//! make it, put a file (under a temporary name, then `MOVE`d into place),
//! get one, delete one. Basic authentication; redirects are not followed, so
//! the credentials only reach the address the operator gave.

use std::path::Path;
use std::time::Duration;

use futures::StreamExt;
use reqwest::{Method, StatusCode};
use tokio::io::AsyncWriteExt;
use url::Url;
use zeroize::Zeroizing;

/// The longest folder listing read.
const MAX_LISTING: usize = 4 << 20;
const PROPFIND: &str = r#"<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>"#;

/// Why a request failed, as the API names it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DavError {
    /// The address is not one this monitor sends credentials to.
    InvalidUrl,
    Unreachable(String),
    Unauthorized,
    Forbidden,
    NotFound,
    /// The server is out of space (507).
    Full,
    TooLarge,
    /// Any other answer.
    Status(u16),
    /// A listing that is not a WebDAV multistatus.
    Malformed,
    Io(String),
}

impl DavError {
    pub fn code(&self) -> &'static str {
        match self {
            Self::InvalidUrl => "invalidUrl",
            Self::Unreachable(_) => "unreachable",
            Self::Unauthorized => "unauthorized",
            Self::Forbidden => "forbidden",
            Self::NotFound => "notFound",
            Self::Full => "serverFull",
            Self::TooLarge => "tooLarge",
            Self::Status(_) => "serverError",
            Self::Malformed => "notWebdav",
            Self::Io(_) => "io",
        }
    }
}

impl DavError {
    /// [`Self::code`] as a backup failure names it.
    pub fn prefixed(&self) -> &'static str {
        match self {
            Self::InvalidUrl => "webdav.invalidUrl",
            Self::Unreachable(_) => "webdav.unreachable",
            Self::Unauthorized => "webdav.unauthorized",
            Self::Forbidden => "webdav.forbidden",
            Self::NotFound => "webdav.notFound",
            Self::Full => "webdav.serverFull",
            Self::TooLarge => "webdav.tooLarge",
            Self::Status(_) => "webdav.serverError",
            Self::Malformed => "webdav.notWebdav",
            Self::Io(_) => "webdav.io",
        }
    }
}

impl std::fmt::Display for DavError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unreachable(why) => write!(f, "unreachable: {why}"),
            Self::Status(code) => write!(f, "the server answered {code}"),
            Self::Io(why) => write!(f, "io: {why}"),
            other => f.write_str(other.code()),
        }
    }
}

/// One file in the folder.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Entry {
    pub name: String,
    pub size: u64,
    /// As the server wrote it (RFC 1123), if it did.
    pub modified: Option<String>,
}

/// The folder [url] names, if this monitor may send credentials there: HTTPS,
/// plain HTTP to this machine, or plain HTTP the operator allowed. No
/// credentials, query or fragment in the address itself.
pub fn folder_url(url: &str, allow_insecure: bool) -> Result<Url, DavError> {
    let mut parsed = Url::parse(url.trim()).map_err(|_| DavError::InvalidUrl)?;
    let loopback = match parsed.host() {
        Some(url::Host::Domain(d)) => d.eq_ignore_ascii_case("localhost"),
        Some(url::Host::Ipv4(ip)) => ip.is_loopback(),
        Some(url::Host::Ipv6(ip)) => ip.is_loopback(),
        None => return Err(DavError::InvalidUrl),
    };
    let scheme_ok = match parsed.scheme() {
        "https" => true,
        "http" => loopback || allow_insecure,
        _ => false,
    };
    if !scheme_ok
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || parsed.query().is_some()
        || parsed.fragment().is_some()
        || url.len() > 2048
    {
        return Err(DavError::InvalidUrl);
    }
    if !parsed.path().ends_with('/') {
        let path = format!("{}/", parsed.path());
        parsed.set_path(&path);
    }
    Ok(parsed)
}

/// Whether [a] and [b] are the same server: a stored password goes only to
/// the server it was given for.
pub fn same_origin(a: &Url, b: &Url) -> bool {
    a.origin() == b.origin()
}

pub struct Dav {
    client: reqwest::Client,
    folder: Url,
    username: String,
    password: Option<Zeroizing<String>>,
}

/// One client for every folder: its connections are kept between a check's
/// requests and the next check's.
fn client() -> &'static reqwest::Client {
    static CLIENT: std::sync::OnceLock<reqwest::Client> = std::sync::OnceLock::new();
    CLIENT.get_or_init(|| {
        // reqwest is built without a crypto provider; the monitor's is ring.
        let _ = rustls::crypto::ring::default_provider().install_default();
        reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .connect_timeout(Duration::from_secs(20))
            .read_timeout(Duration::from_secs(120))
            .build()
            .expect("a valid HTTP client")
    })
}

impl Dav {
    pub fn new(folder: Url, username: &str, password: Option<&str>) -> Self {
        Self {
            client: client().clone(),
            folder,
            username: username.to_string(),
            password: password.map(|p| Zeroizing::new(p.to_string())),
        }
    }

    pub fn folder(&self) -> &Url {
        &self.folder
    }

    fn file(&self, name: &str) -> Url {
        // Names are this module's callers' own (`[A-Za-z0-9._-]`), so joining
        // never leaves the folder.
        debug_assert!(name.bytes().all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b)));
        self.folder.join(name).expect("a plain file name")
    }

    fn request(&self, method: Method, url: Url) -> reqwest::RequestBuilder {
        let req = self.client.request(method, url);
        if self.username.is_empty() && self.password.is_none() {
            return req;
        }
        req.basic_auth(&self.username, self.password.as_ref().map(|p| p.as_str()))
    }

    async fn send(&self, req: reqwest::RequestBuilder) -> Result<reqwest::Response, DavError> {
        let resp = req.send().await.map_err(|e| DavError::Unreachable(without_url(e)))?;
        match resp.status() {
            s if s.is_success() => Ok(resp),
            StatusCode::UNAUTHORIZED => Err(DavError::Unauthorized),
            StatusCode::FORBIDDEN => Err(DavError::Forbidden),
            StatusCode::NOT_FOUND => Err(DavError::NotFound),
            StatusCode::INSUFFICIENT_STORAGE => Err(DavError::Full),
            StatusCode::PAYLOAD_TOO_LARGE => Err(DavError::TooLarge),
            s => Err(DavError::Status(s.as_u16())),
        }
    }

    /// The files in the folder; [`DavError::NotFound`] when it is not there.
    pub async fn list(&self) -> Result<Vec<Entry>, DavError> {
        let req = self
            .request(Method::from_bytes(b"PROPFIND").expect("a method"), self.folder.clone())
            .header("Depth", "1")
            .header("Content-Type", "application/xml; charset=utf-8")
            .body(PROPFIND);
        let resp = self.send(req).await?;
        if resp.status() != StatusCode::MULTI_STATUS {
            return Err(DavError::Malformed);
        }
        let body = read_bounded(resp, MAX_LISTING).await?;
        let text = String::from_utf8(body).map_err(|_| DavError::Malformed)?;
        parse_listing(&text, self.folder.path())
    }

    /// Makes the folder and any parent missing; one already there is fine.
    pub async fn make_folder(&self) -> Result<(), DavError> {
        let mut missing = Vec::new();
        let mut at = self.folder.clone();
        loop {
            let resp = self
                .request(Method::from_bytes(b"MKCOL").expect("a method"), at.clone())
                .send()
                .await
                .map_err(|e| DavError::Unreachable(without_url(e)))?;
            match resp.status() {
                // Made, or already there (405: MKCOL on an existing resource).
                s if s.is_success() || s == StatusCode::METHOD_NOT_ALLOWED => break,
                // A parent is missing.
                StatusCode::CONFLICT => {
                    let parent = at.join("..").map_err(|_| DavError::InvalidUrl)?;
                    if parent == at || parent.path() == "/" {
                        return Err(DavError::Status(409));
                    }
                    missing.push(at);
                    at = parent;
                }
                StatusCode::UNAUTHORIZED => return Err(DavError::Unauthorized),
                StatusCode::FORBIDDEN => return Err(DavError::Forbidden),
                s => return Err(DavError::Status(s.as_u16())),
            }
        }
        for url in missing.into_iter().rev() {
            let req = self.request(Method::from_bytes(b"MKCOL").expect("a method"), url);
            match self.send(req).await {
                Ok(_) | Err(DavError::Status(405)) => {}
                Err(e) => return Err(e),
            }
        }
        Ok(())
    }

    /// Writes [bytes] as [name].
    pub async fn put_bytes(&self, name: &str, bytes: Vec<u8>) -> Result<(), DavError> {
        let len = bytes.len() as u64;
        self.put(name, reqwest::Body::from(bytes), len).await
    }

    /// Writes the file at [path] as [name], streamed.
    pub async fn put_file(&self, name: &str, path: &Path) -> Result<(), DavError> {
        let file = tokio::fs::File::open(path).await.map_err(|e| DavError::Io(e.to_string()))?;
        let len = file.metadata().await.map_err(|e| DavError::Io(e.to_string()))?.len();
        self.put(name, reqwest::Body::from(file), len).await
    }

    /// Under a temporary name first, then moved over [name]: a cut upload
    /// never looks like a finished file.
    async fn put(&self, name: &str, body: reqwest::Body, len: u64) -> Result<(), DavError> {
        let part = format!("{name}.part");
        let req = self.request(Method::PUT, self.file(&part)).header("Content-Length", len).body(body);
        if let Err(e) = self.send(req).await {
            let _ = self.delete(&part).await;
            return Err(e);
        }
        let req = self
            .request(Method::from_bytes(b"MOVE").expect("a method"), self.file(&part))
            .header("Destination", self.file(name).as_str())
            .header("Overwrite", "T");
        if let Err(e) = self.send(req).await {
            let _ = self.delete(&part).await;
            return Err(e);
        }
        Ok(())
    }

    /// [name]'s bytes, at most [max].
    pub async fn get_bytes(&self, name: &str, max: usize) -> Result<Vec<u8>, DavError> {
        let resp = self.send(self.request(Method::GET, self.file(name))).await?;
        read_bounded(resp, max).await
    }

    /// [name] into the file at [path], at most [max] bytes.
    pub async fn get_file(&self, name: &str, path: &Path, max: u64) -> Result<(), DavError> {
        let resp = self.send(self.request(Method::GET, self.file(name))).await?;
        if resp.content_length().is_some_and(|l| l > max) {
            return Err(DavError::TooLarge);
        }
        let mut out = tokio::fs::File::create(path).await.map_err(|e| DavError::Io(e.to_string()))?;
        let mut stream = resp.bytes_stream();
        let mut read = 0u64;
        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| DavError::Unreachable(without_url(e)))?;
            read += chunk.len() as u64;
            if read > max {
                return Err(DavError::TooLarge);
            }
            out.write_all(&chunk).await.map_err(|e| DavError::Io(e.to_string()))?;
        }
        out.flush().await.map_err(|e| DavError::Io(e.to_string()))
    }

    /// Removes [name]; one already gone is fine.
    pub async fn delete(&self, name: &str) -> Result<(), DavError> {
        match self.send(self.request(Method::DELETE, self.file(name))).await {
            Ok(_) | Err(DavError::NotFound) => Ok(()),
            Err(e) => Err(e),
        }
    }
}

/// reqwest's message without the URL, which can name a path the operator
/// considers private.
fn without_url(e: reqwest::Error) -> String {
    let e = e.without_url();
    let mut text = e.to_string();
    let mut source = std::error::Error::source(&e);
    while let Some(s) = source {
        text = format!("{text}: {s}");
        source = s.source();
    }
    text.chars().take(300).collect()
}

async fn read_bounded(resp: reqwest::Response, max: usize) -> Result<Vec<u8>, DavError> {
    if resp.content_length().is_some_and(|l| l > max as u64) {
        return Err(DavError::TooLarge);
    }
    let mut out = Vec::new();
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| DavError::Unreachable(without_url(e)))?;
        if out.len() + chunk.len() > max {
            return Err(DavError::TooLarge);
        }
        out.extend_from_slice(&chunk);
    }
    Ok(out)
}

/// The files a PROPFIND multistatus lists directly in the folder at
/// [folder_path] (folders and the folder itself left out).
pub fn parse_listing(xml: &str, folder_path: &str) -> Result<Vec<Entry>, DavError> {
    const DAV: &str = "DAV:";
    let doc = roxmltree::Document::parse(xml).map_err(|_| DavError::Malformed)?;
    let root = doc.root_element();
    if !root.has_tag_name((DAV, "multistatus")) {
        return Err(DavError::Malformed);
    }
    let folder = decode(folder_path.trim_end_matches('/'));
    let mut out = Vec::new();
    for response in root.children().filter(|n| n.has_tag_name((DAV, "response"))) {
        let Some(href) = response.children().find(|n| n.has_tag_name((DAV, "href"))).and_then(|n| n.text()) else {
            continue;
        };
        // An absolute path, or a whole URL some servers answer with.
        let path = match Url::parse(href.trim()) {
            Ok(u) => u.path().to_string(),
            Err(_) => href.trim().to_string(),
        };
        let path = decode(&path);
        let trimmed = path.trim_end_matches('/');
        let Some((parent, name)) = trimmed.rsplit_once('/') else { continue };
        if trimmed == folder || parent != folder || name.is_empty() {
            continue;
        }
        // The props a server found (200), never those it reports missing.
        let props: Vec<_> = response
            .children()
            .filter(|n| n.has_tag_name((DAV, "propstat")))
            .filter(|ps| {
                ps.children()
                    .find(|n| n.has_tag_name((DAV, "status")))
                    .and_then(|n| n.text())
                    .is_none_or(|s| s.contains(" 200"))
            })
            .flat_map(|ps| ps.children().filter(|n| n.has_tag_name((DAV, "prop"))))
            .collect();
        let find = |tag: &str| props.iter().find_map(|p| p.children().find(|n| n.has_tag_name((DAV, tag))));
        let collection = find("resourcetype").is_some_and(|rt| rt.children().any(|n| n.has_tag_name((DAV, "collection"))));
        if collection || path.ends_with('/') {
            continue;
        }
        let size = find("getcontentlength").and_then(|n| n.text()).and_then(|t| t.trim().parse().ok()).unwrap_or(0);
        let modified = find("getlastmodified").and_then(|n| n.text()).map(|t| t.trim().to_string());
        out.push(Entry { name: name.to_string(), size, modified });
    }
    Ok(out)
}

fn decode(path: &str) -> String {
    percent_encoding::percent_decode_str(path).decode_utf8_lossy().into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_addresses_credentials_may_go_to_are_taken() {
        assert_eq!(folder_url("https://dav.example.com/backups", false).unwrap().as_str(), "https://dav.example.com/backups/");
        assert!(folder_url("http://127.0.0.1:8080/dav/", false).is_ok());
        assert!(folder_url("http://localhost/dav/", false).is_ok());
        assert_eq!(folder_url("http://nas.lan/dav/", false), Err(DavError::InvalidUrl));
        assert!(folder_url("http://nas.lan/dav/", true).is_ok());
        for bad in ["https://me:pw@dav.example.com/", "https://dav.example.com/?a=1", "ftp://dav.example.com/", "dav.example.com", "https://dav.example.com/#x"] {
            assert_eq!(folder_url(bad, true), Err(DavError::InvalidUrl), "{bad}");
        }
    }

    #[test]
    fn a_listing_names_the_files_in_the_folder() {
        let xml = r#"<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response><d:href>/dav/my%20box/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>https://dav.example.com/dav/my%20box/a.age</d:href><d:propstat><d:prop><d:resourcetype/><d:getcontentlength>42</d:getcontentlength><d:getlastmodified>Wed, 21 Oct 2026 10:00:00 GMT</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/my%20box/sub/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <D:response xmlns:D="DAV:"><D:href>/dav/my%20box/b.age</D:href><D:propstat><D:prop><D:getcontentlength>7</D:getcontentlength></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat><D:propstat><D:prop><D:getlastmodified/></D:prop><D:status>HTTP/1.1 404 Not Found</D:status></D:propstat></D:response>
</d:multistatus>"#;
        let listed = parse_listing(xml, "/dav/my%20box/").unwrap();
        assert_eq!(
            listed,
            vec![
                Entry { name: "a.age".into(), size: 42, modified: Some("Wed, 21 Oct 2026 10:00:00 GMT".into()) },
                Entry { name: "b.age".into(), size: 7, modified: None },
            ]
        );
        assert_eq!(parse_listing("<html/>", "/"), Err(DavError::Malformed));
    }
}
