//! The WebSocket upgrade, with a frame limit of our own.
//!
//! `ntex::web::ws::start` builds its codec with `ws::Codec::new()`, whose
//! limit on an incoming frame is 64 KiB, and takes no codec or size from the
//! caller: a bigger frame is a protocol error, and the connection is dropped.
//! Clients send bigger ones as a matter of course — a relayed SFTP write or
//! HTTP body, a paste into the terminal — so [`start`] is ntex 4.4.2's
//! `start_with` with that one line changed, and [`WsSink`] its sink (whose
//! constructor ntex keeps to itself).
//!
//! It differs in one more way: the connection runs on a task of its own and
//! [`start`] returns once the handshake is sent, so a caller can commit what
//! the upgrade consumed (a ticket) without waiting for the socket to close.
//!
//! TODO: remove once ntex lets the caller set the limit, and go back to
//! `ntex::web::ws::start`.

use std::{fmt, rc::Rc};

use ntex::codec::{Decoder, Encoder};
use ntex::http::{StatusCode, body::BodySize, h1, header};
use ntex::io::{DispatchItem, IoConfig, IoRef, Reason, Waiter};
use ntex::service::{BindCtx, Ctx, Pipeline, ReadyNotifier, Service};
use ntex::time::{Millis, Seconds, sleep};
use ntex::util::{BytePages, BytesMut, select};
use ntex::web::ws::{Frame, Message, subprotocols};
use ntex::web::{HttpRequest, HttpResponse};
use ntex::ws::{self, error::HandshakeError, error::WsError, handshake};
use ntex::{SharedCfg, rt};

use tokio::sync::mpsc;

use crate::api::WebError;

/// The largest frame a client may send: well past what any client of the
/// agent sends at once (the app's relay writes 64 KiB, a terminal paste a
/// few), and a bound on what one frame can make the agent hold in memory.
pub const MAX_FRAME: usize = 4 << 20;

/// How long a close we sent waits for the peer's before the connection is
/// closed: ntex's default.
const CLOSE_TIMEOUT: Millis = Millis(5_000);

thread_local! {
    // As ntex's own: no keep-alive timer on an upgraded connection.
    static CFG: SharedCfg = SharedCfg::new("WS")
        .add(IoConfig::new().set_keepalive_timeout(Seconds::ZERO))
        .into();
}

/// `ntex::web::ws::start`, with frames up to [`MAX_FRAME`]. [`service`]
/// makes the connection's frame handler from its sink.
pub async fn start<S>(
    req: &HttpRequest,
    subprotocol: Option<&str>,
    service: impl FnOnce(WsSink) -> S,
) -> Result<HttpResponse, WebError>
where
    S: Service<WsSink, Frame, Res = Option<Message>> + 'static,
    S::Error: fmt::Debug + 'static,
{
    let mut res = handshake(req.head()).map_err(WebError::from_err)?;
    if let Some(protocol) = subprotocol {
        // As ntex: only a token the client offered is echoed.
        if !is_token(protocol) || !subprotocols(req).any(|offered| offered == protocol) {
            return Err(WebError::from_err(HandshakeError::BadWebsocketProtocol));
        }
        res.set_header(header::SEC_WEBSOCKET_PROTOCOL, protocol);
    }
    let res = res.build().into_parts().0;

    let not_upgraded = || WebError::from_err(HandshakeError::NoWebsocketUpgrade);
    let (io, h1_codec) = req.head().take_io().ok_or_else(not_upgraded)?;
    io.encode(h1::Message::Item((res, BodySize::Empty)), &h1_codec).map_err(|_| not_upgraded())?;

    let sink = WsSink::new(io.get_ref(), ws::Codec::new().max_size(MAX_FRAME));
    // SAFETY: the HTTP dispatcher has handed `io` over to this upgrade, and
    // no reference from `io.cfg()` is held.
    unsafe {
        io.set_config(CFG.with(Clone::clone));
    }
    // The h1 dispatcher may have started a headers-read timer on this IO.
    io.stop_timer();

    let srv = Pipeline::new(sink.clone(), DispatchService { srv: service(sink.clone()) });
    rt::spawn_detached(async move {
        let _ = ntex::io::Dispatcher::new(io, sink, srv).await;
    });
    Ok(HttpResponse::new(StatusCode::OK))
}

/// An HTTP token (RFC 9110 5.6.2), what a subprotocol must be.
fn is_token(value: &str) -> bool {
    !value.is_empty() && value.bytes().all(|b| b.is_ascii_alphanumeric() || b"!#$%&'*+-.^_`|~".contains(&b))
}

/// Sends messages to the peer: `ntex::ws::WsSink`, which only ntex can make.
/// It is also the connection's codec, so a close sent through any clone is
/// seen by all of them and by the dispatcher.
#[derive(Clone, Debug)]
pub struct WsSink(Rc<(IoRef, ws::Codec)>);

impl WsSink {
    fn new(io: IoRef, codec: ws::Codec) -> Self {
        Self(Rc::new((io, codec)))
    }

    pub fn io(&self) -> &IoRef {
        &self.0.0
    }

    fn is_closed(&self) -> bool {
        self.0.1.is_closed()
    }

    /// Closes the connection if the peer has not answered a close in time.
    fn start_close_timeout(&self) {
        let io = self.0.0.clone();
        rt::spawn_detached(async move {
            select(sleep(CLOSE_TIMEOUT), io.on_disconnect()).await;
            if io.is_active() {
                io.close();
            }
        });
    }

    /// Encodes and sends [`item`]. A data message waits while the write
    /// buffer is full; a close starts the closing handshake, and a close
    /// after one was sent ends the connection, as in ntex 3 (the codec
    /// refuses anything after a close).
    pub async fn send(&self, item: Message) -> Result<(), ws::error::ProtocolError> {
        let close = matches!(item, Message::Close(_));
        if close && self.is_closed() {
            self.0.0.close();
            return Ok(());
        }
        if matches!(item, Message::Text(_) | Message::Binary(_) | Message::Continuation(_)) {
            // A closed connection drops the message in `encode`.
            let _ = self.0.0.write_ready().await;
        }
        self.0.0.encode(item, &self.0.1)?;
        if close {
            self.start_close_timeout();
        }
        Ok(())
    }

    pub fn on_disconnect(&self) -> Waiter<'static> {
        self.0.0.on_disconnect()
    }
}

impl Encoder for WsSink {
    type Item = Message;
    type Error = ws::error::ProtocolError;

    fn encode(&self, item: Message, dst: &mut BytePages) -> Result<(), Self::Error> {
        self.0.1.encode(item, dst)
    }
}

impl Decoder for WsSink {
    type Item = Frame;
    type Error = ws::error::ProtocolError;

    fn decode(&self, src: &mut BytesMut) -> Result<Option<Frame>, Self::Error> {
        self.0.1.decode(src)
    }

    fn decode_eof(&self, src: &mut BytesMut) -> Result<Option<Frame>, Self::Error> {
        self.0.1.decode_eof(src)
    }
}

/// A frame service's readiness: room in the queue towards its target.
///
/// The dispatcher calls the service for every frame without waiting for the
/// last call to finish, and stops reading the socket only while the service
/// is not ready. Always ready, a target slower than the client — PVE writing
/// an uploaded ISO to disk — left a call per frame waiting on the full queue,
/// each holding its frame, and nothing held the client back. ntex keeps a
/// ready answer until told otherwise, so a send that fills the queue says so.
#[derive(Default)]
pub struct QueueGate(ReadyNotifier);

impl QueueGate {
    /// For the service's `bind`.
    pub fn bind(&self, ctx: BindCtx<'_>) {
        ctx.subscribe(&self.0);
    }

    /// For the service's `ready`: waits for room in [sender]'s queue. A
    /// closed queue is the call's to report.
    pub async fn ready<T>(&self, sender: Option<mpsc::Sender<T>>) {
        if let Some(sender) = sender {
            drop(sender.reserve().await);
        }
    }

    /// Sends [item]; a queue left full has readiness checked again.
    pub async fn send<T>(&self, sender: &mpsc::Sender<T>, item: T) -> Result<(), mpsc::error::SendError<T>> {
        sender.send(item).await?;
        if sender.capacity() == 0 {
            self.0.notify();
        }
        Ok(())
    }
}

/// ntex's own: frames to the service, a close answered by closing the IO,
/// and the dispatcher's stop reasons as errors.
struct DispatchService<S> {
    srv: S,
}

impl<S, E> Service<WsSink, DispatchItem<WsSink>> for DispatchService<S>
where
    S: Service<WsSink, Frame, Res = Option<Message>, Error = E>,
    E: fmt::Debug,
{
    type Res = Option<Message>;
    type Error = WsError<E>;

    ntex::forward_bind!(WsSink, srv);
    ntex::forward_ready!(WsSink, srv, WsError::Service);
    ntex::forward_shutdown!(WsSink, srv);

    async fn call(
        &self,
        req: DispatchItem<WsSink>,
        ctx: Ctx<'_, Self, WsSink>,
    ) -> Result<Self::Res, Self::Error> {
        let peer_closed = matches!(req, DispatchItem::Item(Frame::Close(_)));
        let result = match req {
            DispatchItem::Item(item) => {
                let close = matches!(item, Frame::Close(_)).then(|| ctx.st().clone());
                let result = ctx.call(&self.srv, item).await.map_err(WsError::Service);
                if let Some(s) = close {
                    rt::spawn_detached(async move { s.io().close() });
                }
                result
            }
            // A clean disconnect is not an error.
            DispatchItem::Control(_) | DispatchItem::Stop(Reason::Io(None)) => Ok(None),
            DispatchItem::Stop(Reason::Service) => Ok(Some(Message::Close(Some(ws::CloseCode::Away.into())))),
            DispatchItem::Stop(Reason::KeepAlive) => Err(WsError::KeepAlive),
            DispatchItem::Stop(Reason::ReadTimeout) => Err(WsError::ReadTimeout),
            DispatchItem::Stop(Reason::WriteTimeout) => Err(WsError::WriteTimeout),
            DispatchItem::Stop(Reason::Decoder(e)) => {
                let sink = ctx.st();
                if !sink.is_closed() {
                    let _ = sink.send(Message::Close(Some(ws::CloseCode::Protocol.into()))).await;
                }
                Err(WsError::Protocol(e))
            }
            DispatchItem::Stop(Reason::Encoder(e)) => Err(WsError::Protocol(e)),
            DispatchItem::Stop(Reason::Io(e)) => Err(WsError::Disconnected(e)),
        };
        match result {
            // The codec refuses a second close: the one already sent stands,
            // and the connection ends.
            Ok(Some(Message::Close(_))) if ctx.st().is_closed() => {
                ctx.st().io().close();
                Ok(None)
            }
            // A close the peer started is closed above; one we start waits
            // for the peer's answer.
            Ok(Some(Message::Close(_))) if !peer_closed => {
                ctx.st().start_close_timeout();
                result
            }
            _ => result,
        }
    }
}
