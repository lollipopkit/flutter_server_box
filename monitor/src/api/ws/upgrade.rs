//! The WebSocket upgrade, with a frame limit of our own.
//!
//! `ntex::web::ws::start` builds its codec with `ws::Codec::new()`, whose
//! limit on an incoming frame is 64 KiB, and takes no codec or size from the
//! caller: a bigger frame is a protocol error, and the connection is dropped.
//! Clients send bigger ones as a matter of course — a relayed SFTP write or
//! HTTP body, a paste into the terminal — so [`start`] is ntex 3.12.3's
//! `start` and `start_with` with that one line changed, and [`WsSink`] its
//! sink (whose constructor ntex keeps to itself).
//!
//! TODO: remove once ntex lets the caller set the limit (its unreleased
//! rewrite of `web::ws` still builds `Codec::new()`), and go back to
//! `ntex::web::ws::start`.

use std::{fmt, future::Future, rc::Rc};

use ntex::http::{body::BodySize, h1, header};
use ntex::io::{DispatchItem, IoConfig, IoRef, OnDisconnect, Reason};
use ntex::service::cfg::SharedCfg;
use ntex::service::{
    IntoServiceFactory, Service, ServiceCtx, ServiceFactory, chain_factory, fn_factory_with_config,
};
use ntex::time::Seconds;
use ntex::util::Ready;
use ntex::web::ws::{Frame, Message};
use ntex::web::{HttpRequest, HttpResponse};
use ntex::ws::{self, error::HandshakeError, error::WsError, handshake};
use ntex::{http::StatusCode, rt};

/// The largest frame a client may send: well past what any client of the
/// agent sends at once (the app's relay writes 64 KiB, a terminal paste a
/// few), and a bound on what one frame can make the agent hold in memory.
pub const MAX_FRAME: usize = 4 << 20;

thread_local! {
    // As ntex's own: no keep-alive timer on an upgraded connection.
    static CFG: SharedCfg = SharedCfg::new("WS")
        .add(IoConfig::new().set_keepalive_timeout(Seconds::ZERO))
        .into();
}

/// `ntex::web::ws::start`, with frames up to [`MAX_FRAME`].
pub async fn start<T, F, Err>(
    req: HttpRequest,
    subprotocol: Option<&str>,
    factory: F,
) -> Result<HttpResponse, Err>
where
    T: ServiceFactory<Frame, WsSink, Response = Option<Message>> + 'static,
    T::Error: fmt::Debug,
    F: IntoServiceFactory<T, Frame, WsSink>,
    Err: From<T::InitError> + From<HandshakeError>,
{
    let inner = Rc::new(chain_factory(factory).map_err(WsError::Service));
    let factory = fn_factory_with_config(async move |sink: WsSink| {
        let srv = inner.create(sink.clone()).await?;
        Ok::<_, T::InitError>(DispatchService { srv, sink })
    });

    let mut res = handshake(req.head())?;
    if let Some(protocol) = subprotocol {
        res.set_header(header::SEC_WEBSOCKET_PROTOCOL, protocol);
    }
    let res = res.finish().into_parts().0;

    let (io, h1_codec) = req.head().take_io().ok_or(HandshakeError::NoWebsocketUpgrade)?;
    io.encode(h1::Message::Item((res, BodySize::Empty)), &h1_codec)
        .map_err(|_| HandshakeError::NoWebsocketUpgrade)?;

    let codec = ws::Codec::new().max_size(MAX_FRAME);
    let sink = WsSink::new(io.get_ref(), codec.clone());
    let srv = factory.into_factory().create(sink.clone()).await?;
    io.set_config(CFG.with(Clone::clone));
    // The h1 dispatcher may have started a headers-read timer on this IO.
    io.stop_timer();

    rt::spawn(async move {
        let _ = ntex::io::Dispatcher::new(io, codec, srv).await;
    });
    Ok(HttpResponse::new(StatusCode::OK))
}

/// Sends messages to the peer: `ntex::ws::WsSink`, which only ntex can make.
/// Its codec encodes; decoding is the dispatcher's codec, which is where the
/// frame limit is.
#[derive(Clone, Debug)]
pub struct WsSink(Rc<(IoRef, ws::Codec)>);

impl WsSink {
    fn new(io: IoRef, codec: ws::Codec) -> Self {
        Self(Rc::new((io, codec)))
    }

    pub fn io(&self) -> &IoRef {
        &self.0.0
    }

    /// Encodes and sends [`item`]; a close the codec has already sent once
    /// closes the connection.
    pub fn send(&self, item: Message) -> impl Future<Output = Result<(), ws::error::ProtocolError>> {
        let close = matches!(item, Message::Close(_)) && self.0.1.is_closed();
        if let Err(e) = self.0.0.encode(item, &self.0.1) {
            Ready::Err(e)
        } else {
            if close {
                self.0.0.close();
            }
            Ready::Ok(())
        }
    }

    pub fn on_disconnect(&self) -> OnDisconnect {
        self.0.0.on_disconnect()
    }
}

/// ntex's own: frames to the service, a close answered by closing the IO,
/// and the dispatcher's stop reasons as errors.
struct DispatchService<S> {
    srv: S,
    sink: WsSink,
}

impl<S, E> Service<DispatchItem<ws::Codec>> for DispatchService<S>
where
    S: Service<Frame, Response = Option<Message>, Error = WsError<E>>,
    E: fmt::Debug,
{
    type Response = Option<Message>;
    type Error = WsError<E>;

    ntex::forward_ready!(srv);
    ntex::forward_poll!(srv);
    ntex::forward_shutdown!(srv);

    async fn call(
        &self,
        req: DispatchItem<ws::Codec>,
        ctx: ServiceCtx<'_, Self>,
    ) -> Result<Self::Response, Self::Error> {
        match req {
            DispatchItem::Item(item) => {
                let close = matches!(item, Frame::Close(_)).then(|| self.sink.clone());
                let result = ctx.call(&self.srv, item).await;
                if let Some(s) = close {
                    rt::spawn(async move { s.io().close() });
                }
                result
            }
            DispatchItem::Control(_) => Ok(None),
            DispatchItem::Stop(Reason::KeepAliveTimeout) => Err(WsError::KeepAlive),
            DispatchItem::Stop(Reason::ReadTimeout) => Err(WsError::ReadTimeout),
            DispatchItem::Stop(Reason::Decoder(e) | Reason::Encoder(e)) => Err(WsError::Protocol(e)),
            DispatchItem::Stop(Reason::Io(e)) => Err(WsError::Disconnected(e)),
        }
    }
}
