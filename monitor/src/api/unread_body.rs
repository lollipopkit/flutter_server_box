//! An answer given before the request's body was read to its end: what is
//! left of the body is read first (at most [`MAX_DRAIN`] and [`DRAIN_TIME`]),
//! so the connection carries on; past either, the answer says
//! `Connection: close`.
//!
//! Unread, ntex drops the connection after the answer (a body cannot be
//! skipped on HTTP/1.1), under a client that may still be writing it, which
//! then fails with the connection gone instead of reading the answer; and it
//! marks the answer `close` only when the body was dropped before the answer
//! went out (`h1::Dispatcher::send_response`), so a client may also reuse a
//! connection about to close. A refusal by an extractor (an invalid query, a
//! JSON 404 under `/api/v1`) did both now and then. `api::backup` reads a
//! refused upload further itself (`discard`).

use std::cell::{Cell, RefCell};
use std::pin::Pin;
use std::rc::Rc;
use std::task::{Context, Poll};
use std::time::Duration;

use futures::Stream;
use ntex::http::error::PayloadError;
use ntex::http::{ConnectionType, Payload, header};
use ntex::service::{Middleware, Service, ServiceCtx, cfg::SharedCfg};
use ntex::util::Bytes;
use ntex::web::{WebRequest, WebResponse};

/// What is read of a body left unread, at most: as much as a request a
/// handler reads whole may be, so a refusal costs no more than an answer.
const MAX_DRAIN: usize = 1 << 20;
const DRAIN_TIME: Duration = Duration::from_secs(5);

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
        let body = Rc::new(Body { payload: RefCell::new(req.take_payload()), ended: Cell::new(false) });
        req.set_payload(Payload::from_stream(Watched(body.clone())));
        let mut res = ctx.call(&self.service, req).await?;
        if !body.ended.get() && !body.drain().await {
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

/// The request's body, shared by the handler's reads and what is drained
/// after it; noting when it has been read to its end.
struct Body {
    payload: RefCell<Payload>,
    ended: Cell<bool>,
}

impl Body {
    fn poll_next(&self, cx: &mut Context<'_>) -> Poll<Option<Result<Bytes, PayloadError>>> {
        let next = self.payload.borrow_mut().poll_recv(cx);
        if let Poll::Ready(None) = next {
            self.ended.set(true);
        }
        next
    }

    /// Reads what is left, keeping none of it; whether it reached the end.
    async fn drain(&self) -> bool {
        let read = async {
            let mut read = 0usize;
            loop {
                match std::future::poll_fn(|cx| self.poll_next(cx)).await {
                    None => return true,
                    Some(Ok(chunk)) => {
                        read += chunk.len();
                        if read > MAX_DRAIN {
                            return false;
                        }
                    }
                    Some(Err(_)) => return false,
                }
            }
        };
        tokio::time::timeout(DRAIN_TIME, read).await.unwrap_or(false)
    }
}

struct Watched(Rc<Body>);

impl Stream for Watched {
    type Item = Result<Bytes, PayloadError>;

    fn poll_next(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        self.0.poll_next(cx)
    }
}

#[cfg(test)]
mod tests {
    use ntex::web::{self, App, HttpResponse, test};

    use super::{CloseUnreadBody, MAX_DRAIN};

    /// A body left unread is read before the answer, so the connection
    /// carries on; one past what is read says it ends. Without the
    /// middleware a scope's own 404 left the body unread and the answer
    /// keep-alive, every time.
    #[ntex::test]
    async fn an_unread_body_is_read_before_the_answer_or_the_connection_ends() {
        let srv = test::server(|| async {
            App::new().service(
                web::scope("/api")
                    .middleware(CloseUnreadBody)
                    .route("/read", web::post().to(|_: ntex::util::Bytes| async { HttpResponse::NoContent().finish() })),
            )
        })
        .await;
        let send = |path: &'static str, body: Vec<u8>| srv.request(ntex::http::Method::POST, srv.url(path)).send_body(body);
        let connection = |res: &ntex::client::ClientResponse| res.headers().get("connection").map(|v| v.to_str().unwrap().to_string());

        for _ in 0..3 {
            let missing = send("/api/nope", b"body".to_vec()).await.unwrap();
            assert_eq!((missing.status().as_u16(), connection(&missing)), (404, None));
        }
        let read = send("/api/read", b"body".to_vec()).await.unwrap();
        assert_eq!((read.status().as_u16(), connection(&read)), (204, None));
        // Ended either way: the answer says so, or, when the close comes
        // while the client is still sending, the unread rest makes it a
        // reset (ntex does not linger), which discards the answer.
        match send("/api/nope", vec![0u8; MAX_DRAIN + (64 << 10)]).await {
            Ok(large) => assert_eq!((large.status().as_u16(), connection(&large).as_deref()), (404, Some("close"))),
            Err(ntex::client::error::SendRequestError::Send(e)) => {
                assert!(matches!(e.kind(), std::io::ErrorKind::ConnectionReset | std::io::ErrorKind::ConnectionAborted), "{e}")
            }
            Err(e) => panic!("{e:?}"),
        }
    }
}
