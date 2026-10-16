//! Says `Connection: close` on an answer given before the request's body was
//! read to its end.
//!
//! ntex then drops the connection after the answer (a body left unread
//! cannot be skipped on HTTP/1.1), but marks it `close` only when the body
//! was dropped before the answer went out (`h1::Dispatcher::send_response`);
//! dropped after, the answer reads as keep-alive. A client that reuses the
//! connection, as it may, then sees it gone with its next request: a refusal
//! by an extractor (an invalid query, a JSON 404 under `/api/v1`) did this
//! now and then.

use std::cell::Cell;
use std::pin::Pin;
use std::rc::Rc;
use std::task::{Context, Poll};

use futures::Stream;
use ntex::http::error::PayloadError;
use ntex::http::{ConnectionType, Payload, header};
use ntex::service::{Middleware, Service, ServiceCtx, cfg::SharedCfg};
use ntex::util::Bytes;
use ntex::web::{WebRequest, WebResponse};

pub struct CloseUnreadBody;

impl<S> Middleware<S, SharedCfg> for CloseUnreadBody {
    type Service = CloseUnreadBodyService<S>;

    fn create(&self, service: S, _: SharedCfg) -> Self::Service {
        CloseUnreadBodyService { service }
    }
}

pub struct CloseUnreadBodyService<S> {
    service: S,
}

impl<S, E> Service<WebRequest<E>> for CloseUnreadBodyService<S>
where
    S: Service<WebRequest<E>, Response = WebResponse>,
{
    type Response = WebResponse;
    type Error = S::Error;

    ntex::forward_poll!(service);
    ntex::forward_ready!(service);
    ntex::forward_shutdown!(service);

    async fn call(&self, mut req: WebRequest<E>, ctx: ServiceCtx<'_, Self>) -> Result<Self::Response, Self::Error> {
        if !has_body(&req) {
            return ctx.call(&self.service, req).await;
        }
        let ended = Rc::new(Cell::new(false));
        let body = req.take_payload();
        req.set_payload(Payload::from_stream(Watched { body, ended: ended.clone() }));
        let mut res = ctx.call(&self.service, req).await?;
        if !ended.get() {
            res.response_mut().head_mut().set_connection_type(ConnectionType::Close);
        }
        Ok(res)
    }
}

fn has_body<E>(req: &WebRequest<E>) -> bool {
    let headers = req.headers();
    let length = headers.get(header::CONTENT_LENGTH).and_then(|v| v.to_str().ok()).and_then(|v| v.trim().parse::<u64>().ok());
    length.is_some_and(|n| n > 0) || headers.contains_key(header::TRANSFER_ENCODING)
}

/// The request's body, noting when it has been read to its end.
struct Watched {
    body: Payload,
    ended: Rc<Cell<bool>>,
}

impl Stream for Watched {
    type Item = Result<Bytes, PayloadError>;

    fn poll_next(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        let this = self.get_mut();
        let next = this.body.poll_recv(cx);
        if let Poll::Ready(None) = next {
            this.ended.set(true);
        }
        next
    }
}

#[cfg(test)]
mod tests {
    use ntex::web::{self, App, HttpResponse, test};

    use super::CloseUnreadBody;

    /// An answer given before the body was read says the connection ends; one
    /// after, it does not. Without the middleware a scope's own 404 reads as
    /// keep-alive here every time.
    #[ntex::test]
    async fn an_answer_before_the_body_is_read_closes_the_connection() {
        let srv = test::server(|| async {
            App::new().service(
                web::scope("/api")
                    .middleware(CloseUnreadBody)
                    .route("/read", web::post().to(|_: ntex::util::Bytes| async { HttpResponse::NoContent().finish() })),
            )
        })
        .await;
        let send = |path: &'static str| srv.request(ntex::http::Method::POST, srv.url(path)).send_body(b"body".to_vec());
        let connection = |res: &ntex::client::ClientResponse| res.headers().get("connection").map(|v| v.to_str().unwrap().to_string());

        let missing = send("/api/nope").await.unwrap();
        assert_eq!(missing.status().as_u16(), 404);
        assert_eq!(connection(&missing).as_deref(), Some("close"));
        let read = send("/api/read").await.unwrap();
        assert_eq!(read.status().as_u16(), 204);
        assert_eq!(connection(&read), None);
    }
}
