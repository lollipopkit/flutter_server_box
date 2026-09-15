use core::pin::Pin;
use core::task::{Context, Poll, ready};
use std::io;

use futures_util::{Sink, SinkExt as _, Stream, StreamExt as _};
use tokio::io::{AsyncRead, AsyncWrite};
use tokio_tungstenite::tungstenite;

pub(crate) fn websocket_compat<S>(stream: S) -> impl AsyncRead + AsyncWrite + Unpin + Send + 'static
where
    S: Stream<Item = Result<tungstenite::Message, tungstenite::Error>>
        + Sink<tungstenite::Message, Error = tungstenite::Error>
        + Unpin
        + Send
        + 'static,
{
    let compat = stream
        .filter_map(|item| {
            let mapped = item
                .map(|msg| match msg {
                    tungstenite::Message::Text(s) => Some(WsReadMsg::Payload(tungstenite::Bytes::from(s))),
                    tungstenite::Message::Binary(data) => Some(WsReadMsg::Payload(data)),
                    tungstenite::Message::Ping(_) | tungstenite::Message::Pong(_) => None,
                    tungstenite::Message::Close(_) => Some(WsReadMsg::Close),
                    tungstenite::Message::Frame(_) => unreachable!("raw frames are never returned when reading"),
                })
                .transpose();

            core::future::ready(mapped)
        })
        .with(|item| {
            core::future::ready(Ok::<_, tungstenite::Error>(tungstenite::Message::Binary(
                tungstenite::Bytes::from(item),
            )))
        });

    WsStream::new(compat)
}

/// A WebSocket message as consumed by [`WsStream`] when reading.
enum WsReadMsg {
    Payload(tungstenite::Bytes),
    Close,
}

/// Wraps a stream/sink of WebSocket messages and exposes it as [`AsyncRead`] + [`AsyncWrite`].
///
/// The wrapped `S` is required to be [`Unpin`] so no pinning projection is needed; the caller of
/// [`websocket_compat`] always provides an `Unpin` stream.
struct WsStream<S> {
    inner: S,
    read_buf: Option<tungstenite::Bytes>,
}

impl<S> WsStream<S> {
    fn new(inner: S) -> Self {
        Self { inner, read_buf: None }
    }
}

impl<S, E> AsyncRead for WsStream<S>
where
    S: Stream<Item = Result<WsReadMsg, E>> + Unpin,
    E: core::error::Error + Send + Sync + 'static,
{
    fn poll_read(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut tokio::io::ReadBuf<'_>,
    ) -> Poll<io::Result<()>> {
        let this = &mut *self;

        let mut data = if let Some(data) = this.read_buf.take() {
            data
        } else {
            match ready!(Pin::new(&mut this.inner).poll_next(cx)) {
                Some(Ok(WsReadMsg::Payload(data))) => data,
                Some(Ok(WsReadMsg::Close)) => return Poll::Ready(Ok(())),
                Some(Err(e)) => return Poll::Ready(Err(io::Error::other(e))),
                None => return Poll::Ready(Ok(())),
            }
        };

        let bytes_to_copy = core::cmp::min(buf.remaining(), data.len());

        let dest = buf.initialize_unfilled_to(bytes_to_copy);
        dest.copy_from_slice(&data.split_to(bytes_to_copy));
        buf.advance(bytes_to_copy);

        if !data.is_empty() {
            this.read_buf = Some(data);
        }

        Poll::Ready(Ok(()))
    }
}

impl<S, E> AsyncWrite for WsStream<S>
where
    S: Sink<Vec<u8>, Error = E> + Unpin,
    E: core::error::Error + Send + Sync + 'static,
{
    fn poll_write(mut self: Pin<&mut Self>, cx: &mut Context<'_>, buf: &[u8]) -> Poll<io::Result<usize>> {
        let this = &mut *self;

        // Try flushing preemptively.
        let _ = Pin::new(&mut this.inner).poll_flush(cx);

        // Make sure the sink is ready to send.
        if let Err(e) = ready!(Pin::new(&mut this.inner).poll_ready(cx)) {
            return Poll::Ready(Err(io::Error::other(e)));
        }

        // Actually submit the new item. If no error occurred, the message is accepted and queued
        // (that is: `to_vec` is called only once).
        if let Err(e) = Pin::new(&mut this.inner).start_send(buf.to_vec()) {
            return Poll::Ready(Err(io::Error::other(e)));
        }

        Poll::Ready(Ok(buf.len()))
    }

    fn poll_flush(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        let res = ready!(Pin::new(&mut self.inner).poll_flush(cx));
        Poll::Ready(res.map_err(io::Error::other))
    }

    fn poll_shutdown(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        let res = ready!(Pin::new(&mut self.inner).poll_close(cx));
        Poll::Ready(res.map_err(io::Error::other))
    }
}
