//! JSON bodies with a size limit of their endpoint's own.
//!
//! ntex's `Json` reads one `JsonConfig` for the whole app, 32 KiB unless set;
//! a few endpoints take a bigger body, and only they should.
//!
//! TODO: back to `web::types::Json` once ntex sets a limit per resource
//! again (ntex 3's `Resource::state(JsonConfig)`).

use std::{marker::PhantomData, ops::Deref};

use ntex::http::{HttpMessage, Payload, header};
use ntex::util::BytesMut;
use ntex::web::error::JsonPayloadError;
use ntex::web::{FromRequest, HttpRequest};
use serde::de::DeserializeOwned;

use super::server::Agent;

/// Where a body's limit comes from.
pub trait Limit<St> {
    fn bytes(st: &St) -> usize;
}

/// A fixed limit of `N` bytes.
pub struct Max<const N: usize>;

impl<St, const N: usize> Limit<St> for Max<N> {
    fn bytes(_: &St) -> usize {
        N
    }
}

/// `remote_access.exec.max_request_bytes`: the operator's trade, see
/// `remote_access::ExecConfig`.
pub struct ExecLimit;

impl Limit<Agent> for ExecLimit {
    fn bytes(st: &Agent) -> usize {
        st.0.remote_access.exec.max_request_bytes
    }
}

/// A JSON body of at most `L` bytes.
pub struct Json<T, L>(T, PhantomData<L>);

impl<T, L> Json<T, L> {
    pub fn into_inner(self) -> T {
        self.0
    }
}

impl<T, L> Deref for Json<T, L> {
    type Target = T;

    fn deref(&self) -> &T {
        &self.0
    }
}

impl<St, T: DeserializeOwned, L: Limit<St>> FromRequest<St> for Json<T, L> {
    type Error = JsonPayloadError;

    async fn from_request(st: &St, req: &HttpRequest, payload: &mut Payload) -> Result<Self, Self::Error> {
        read(req, payload, L::bytes(st)).await.map(|body| Self(body, PhantomData))
    }
}

/// What ntex's `Json` does, with [limit].
async fn read<T: DeserializeOwned>(req: &HttpRequest, payload: &mut Payload, limit: usize) -> Result<T, JsonPayloadError> {
    let json = req
        .mime_type()
        .ok()
        .flatten()
        .is_some_and(|mime| mime.subtype() == "json" || mime.suffix().is_some_and(|s| s == "json"));
    if !json {
        return Err(JsonPayloadError::ContentType);
    }
    let length = match req.headers().get(header::CONTENT_LENGTH) {
        None => None,
        Some(value) => Some(
            value
                .to_str()
                .ok()
                .and_then(|s| s.parse::<usize>().ok())
                .ok_or(ntex::http::error::PayloadError::UnknownLength)?,
        ),
    };
    if length.is_some_and(|len| len > limit) {
        return Err(JsonPayloadError::Overflow);
    }
    let mut body = BytesMut::with_capacity(length.unwrap_or(0));
    while let Some(chunk) = payload.recv().await {
        let chunk = chunk?;
        if body.len() + chunk.len() > limit {
            return Err(JsonPayloadError::Overflow);
        }
        body.extend_from_slice(&chunk);
    }
    Ok(serde_json::from_slice(&body)?)
}

#[cfg(test)]
mod tests {
    use ntex::http::header;
    use ntex::web::error::JsonPayloadError;
    use ntex::web::test::{TestRequest, from_request};

    use super::{Json, Max};

    async fn read(req: TestRequest) -> Result<Vec<u8>, JsonPayloadError> {
        let (req, mut payload, ()) = req.to_http_parts();
        from_request::<(), Json<Vec<u8>, Max<8>>>(&(), &req, &mut payload).await.map(Json::into_inner)
    }

    fn json(body: &'static str) -> TestRequest {
        TestRequest::post().header(header::CONTENT_TYPE, "application/json").payload(body)
    }

    #[ntex::test]
    async fn a_body_within_the_limit_is_read() {
        assert_eq!(read(json("[1,2,3]")).await.unwrap(), [1, 2, 3]);
    }

    #[ntex::test]
    async fn a_body_past_the_limit_is_refused() {
        assert!(matches!(read(json("[1,2,3,4,5]")).await, Err(JsonPayloadError::Overflow)));
    }

    #[ntex::test]
    async fn a_declared_length_past_the_limit_is_refused_before_reading() {
        let req = json("[1]").header(header::CONTENT_LENGTH, "9");
        assert!(matches!(read(req).await, Err(JsonPayloadError::Overflow)));
    }

    #[ntex::test]
    async fn another_content_type_is_refused() {
        let req = TestRequest::post().header(header::CONTENT_TYPE, "text/plain").payload("[1]");
        assert!(matches!(read(req).await, Err(JsonPayloadError::ContentType)));
    }
}
