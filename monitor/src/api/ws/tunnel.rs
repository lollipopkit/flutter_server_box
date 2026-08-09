//! `GET /api/v1/tunnel/ws` — a byte relay between a WebSocket and the local
//! sshd, so the app can reach SSH on a host whose SSH port isn't exposed.
//!
//! The agent moves bytes and nothing else. What flows through is the SSH wire
//! protocol, negotiated end to end between the app and sshd, with the app
//! verifying the host key at its own end; this process could not read or
//! alter the session even if it tried. That is also why port forwarding needs
//! nothing here: the app's forwards are SSH channels inside that stream, and
//! which port they reach is sshd's decision, not ours.
//!
//! There is no target parameter. The address comes from
//! `remote_access.ssh_addr` and nowhere else, which is what keeps an
//! authenticated panel account from turning the agent into a pivot onto its
//! network. Reaching a second machine is done by configuring it in the app
//! with this one as a jump server, so that hop is authorised by SSH.

use std::cell::Cell;
use std::rc::Rc;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

use ntex::rt::spawn;
use ntex::service::{Service, fn_factory_with_config, fn_service};
use ntex::time::sleep;
use ntex::util::Bytes;
use ntex::web::ws::{self, CloseCode, Frame, Message, WsSink};
use ntex::web::{self, HttpRequest, HttpResponse};
// `web::ws` re-exports only the handful of types a handler usually needs;
// continuation items come from the protocol module itself.
use ntex::ws::Item;
use sqlx::SqlitePool;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::ticket::Purpose;
use crate::api::server::AppState;

/// Read size for the sshd→client direction. Comfortably under the 64 KiB
/// frame limit `ws::start` builds its codec with, and large enough that a
/// bulk SFTP transfer isn't dominated by per-frame overhead.
const READ_CHUNK: usize = 32 * 1024;

/// Frames waiting to be written to sshd. Small on purpose: it exists to
/// absorb scheduling jitter, not to buffer a transfer. When it fills, the
/// handler stops returning, ntex stops reading the socket, and the TCP window
/// closes back towards the app — which is the backpressure we want.
const TO_SSHD_QUEUE: usize = 8;

/// How long to wait between checks while the WebSocket write buffer is over
/// its high-water mark. ntex exposes backpressure as a flag rather than as
/// something awaitable from a `WsSink`, so this direction polls.
const BACKPRESSURE_POLL: Duration = Duration::from_millis(5);

/// Keepalive cadence. Also how quickly a half-open connection — a phone that
/// changed networks without a FIN — gets noticed and its sshd connection
/// released.
const PING_INTERVAL: Duration = Duration::from_secs(30);
const PONG_TIMEOUT: Duration = Duration::from_secs(90);

/// Live tunnels, for the concurrency cap. Decremented by [`ConnGuard`] so an
/// early return or a panic can't leak a slot.
#[derive(Default)]
pub struct TunnelCount(AtomicUsize);

struct ConnGuard(Arc<TunnelCount>);

impl TunnelCount {
    /// `None` when `max` is already reached.
    fn acquire(self: &Arc<Self>, max: usize) -> Option<ConnGuard> {
        let mut current = self.0.load(Ordering::Relaxed);
        loop {
            if current >= max {
                return None;
            }
            match self.0.compare_exchange_weak(
                current,
                current + 1,
                Ordering::AcqRel,
                Ordering::Relaxed,
            ) {
                Ok(_) => return Some(ConnGuard(self.clone())),
                Err(actual) => current = actual,
            }
        }
    }
}

impl Drop for ConnGuard {
    fn drop(&mut self) {
        self.0.0.fetch_sub(1, Ordering::AcqRel);
    }
}

pub async fn tunnel_ws(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
    let remote_ip = audit::peer_ip(&req);

    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Tunnel, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(reason)
            .record(&app_state.db)
            .await;
        Ok(status)
    };

    if !app_state.remote_access.tunnel_enabled {
        return deny("disabled", HttpResponse::Forbidden().finish()).await;
    }
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().finish()).await;
    }

    let Some(raw_ticket) = query_param(req.query_string(), "ticket") else {
        return deny("no ticket", HttpResponse::Unauthorized().finish()).await;
    };
    // Every rejection answers the same 401: telling a prober whether a ticket
    // was expired, unknown or minted for the other endpoint would let them
    // measure how far they got.
    let Ok(subject) = app_state.tickets.consume(&raw_ticket, Purpose::Tunnel) else {
        return deny("ticket", HttpResponse::Unauthorized().finish()).await;
    };

    let Some(guard) = app_state
        .tunnel_count
        .acquire(app_state.remote_access.tunnel_max_conns)
    else {
        return deny("at capacity", HttpResponse::ServiceUnavailable().finish()).await;
    };

    // Connect before upgrading, so a client that can't be served learns it
    // from an HTTP status rather than from a WebSocket that opens and
    // immediately closes.
    let stream = match TcpStream::connect(&app_state.remote_access.ssh_addr).await {
        Ok(stream) => stream,
        Err(e) => {
            tracing::warn!(
                "Tunnel could not reach {}: {e}",
                app_state.remote_access.ssh_addr
            );
            return deny("target unreachable", HttpResponse::BadGateway().finish()).await;
        }
    };
    // Every byte is already framed by the SSH layer above; Nagle would only
    // add latency to interactive keystrokes.
    let _ = stream.set_nodelay(true);

    Event::new(Kind::Tunnel, Action::Open, Outcome::Ok)
        .subject(&subject)
        .remote_ip(remote_ip.clone())
        .record(&app_state.db)
        .await;

    let session = Rc::new(SessionCtx {
        db: app_state.db.clone(),
        subject,
        remote_ip,
        _guard: guard,
    });
    let stream = Rc::new(Cell::new(Some(stream)));

    ws::start::<_, _, &str, web::Error>(
        req,
        None,
        fn_factory_with_config(move |sink: WsSink| {
            let session = session.clone();
            let stream = stream.clone();
            async move {
                let stream = stream
                    .take()
                    .expect("ws::start creates the service exactly once per upgrade");
                Ok::<_, web::Error>(spawn_relay(stream, sink, session))
            }
        }),
    )
    .await
}

/// Kept alive for the lifetime of the relay: dropping it records the close
/// and releases the concurrency slot, whichever way the session ended.
struct SessionCtx {
    db: SqlitePool,
    subject: String,
    remote_ip: Option<String>,
    _guard: ConnGuard,
}

impl Drop for SessionCtx {
    fn drop(&mut self) {
        let db = self.db.clone();
        let subject = self.subject.clone();
        let remote_ip = self.remote_ip.clone();
        spawn(async move {
            Event::new(Kind::Tunnel, Action::Close, Outcome::Ok)
                .subject(subject)
                .remote_ip(remote_ip)
                .record(&db)
                .await;
        });
    }
}

/// Wires up both directions and returns the service handling inbound frames.
///
/// The two directions are deliberately asymmetric:
///
/// - **sshd → client** runs in its own task that reads TCP and writes to the
///   sink. It applies backpressure by not reading TCP while the WebSocket
///   write buffer is over its mark, which closes the TCP window back towards
///   sshd. No queue is involved at all.
/// - **client → sshd** goes through a short bounded channel. The frame
///   handler awaits a free slot, and while it does, ntex isn't reading the
///   next frame — so the pressure lands on the WebSocket connection.
fn spawn_relay(
    stream: TcpStream,
    sink: WsSink,
    session: Rc<SessionCtx>,
) -> impl Service<Frame, Response = Option<Message>, Error = web::Error> {
    let (mut reader, mut writer) = tokio::io::split(stream);
    let (to_sshd, mut to_sshd_rx) = mpsc::channel::<Bytes>(TO_SSHD_QUEUE);

    // Set on every inbound frame, cleared by the keepalive task each round:
    // any traffic at all counts as proof of life, not just a pong.
    let alive = Rc::new(Cell::new(true));

    {
        let sink = sink.clone();
        // Holds the session open for as long as bytes can still arrive from
        // sshd, so the close is recorded and the slot freed only once both
        // directions are really done.
        let _session = session.clone();
        spawn(async move {
            let mut buf = vec![0u8; READ_CHUNK];
            loop {
                match reader.read(&mut buf).await {
                    // sshd closed: mirror it as a normal WebSocket close
                    Ok(0) => {
                        let _ = sink.send(Message::Close(Some(CloseCode::Normal.into()))).await;
                        break;
                    }
                    Ok(n) => {
                        if sink
                            .send(Message::Binary(Bytes::copy_from_slice(&buf[..n])))
                            .await
                            .is_err()
                        {
                            break;
                        }
                        if !await_write_capacity(&sink).await {
                            break;
                        }
                    }
                    Err(e) => {
                        tracing::debug!("Tunnel read from sshd ended: {e}");
                        let _ = sink.send(Message::Close(Some(CloseCode::Error.into()))).await;
                        break;
                    }
                }
            }
            drop(_session);
            sink.io().close();
        });
    }

    {
        let sink = sink.clone();
        spawn(async move {
            while let Some(chunk) = to_sshd_rx.recv().await {
                if writer.write_all(&chunk).await.is_err() {
                    break;
                }
            }
            let _ = writer.shutdown().await;
            sink.io().close();
        });
    }

    {
        let sink = sink.clone();
        let alive = alive.clone();
        spawn(async move {
            let rounds = (PONG_TIMEOUT.as_millis() / PING_INTERVAL.as_millis()).max(1);
            let mut silent = 0;
            loop {
                sleep(PING_INTERVAL).await;
                if sink.io().is_closed() {
                    break;
                }
                if alive.replace(false) {
                    silent = 0;
                } else {
                    silent += 1;
                    if silent as u128 >= rounds {
                        tracing::debug!("Tunnel peer stopped responding; closing");
                        sink.io().close();
                        break;
                    }
                }
                if sink.send(Message::Ping(Bytes::new())).await.is_err() {
                    break;
                }
            }
        });
    }

    fn_service(move |frame: Frame| {
        let to_sshd = to_sshd.clone();
        let alive = alive.clone();
        // Held so the relay's audit/close bookkeeping outlives the handler
        let _session = session.clone();
        async move {
            alive.set(true);
            let payload = match frame {
                Frame::Binary(data) => Some(data),
                // A byte relay doesn't need to reassemble fragments: order is
                // the only thing that matters, so each piece goes straight out.
                Frame::Continuation(Item::FirstBinary(data))
                | Frame::Continuation(Item::Continue(data))
                | Frame::Continuation(Item::Last(data)) => Some(data),
                Frame::Ping(payload) => return Ok(Some(Message::Pong(payload))),
                Frame::Pong(_) => None,
                Frame::Close(_) => {
                    return Ok(Some(Message::Close(Some(CloseCode::Normal.into()))));
                }
                // Text has no meaning on this endpoint. Refusing rather than
                // ignoring keeps a confused client from silently corrupting an
                // SSH stream that would then fail somewhere far less obvious.
                Frame::Text(_) | Frame::Continuation(Item::FirstText(_)) => {
                    return Ok(Some(Message::Close(Some(
                        CloseCode::Unsupported.into(),
                    ))));
                }
            };

            if let Some(data) = payload
                && !data.is_empty()
                && to_sshd.send(data).await.is_err()
            {
                return Ok(Some(Message::Close(Some(CloseCode::Error.into()))));
            }
            Ok::<_, web::Error>(None)
        }
    })
}

/// Waits until the WebSocket write buffer is back under its high-water mark.
///
/// Returns `false` if the connection died while waiting. Polling rather than
/// awaiting a notification: `WsSink` hands out an `IoRef`, whose backpressure
/// is a flag with no awaitable counterpart, and `Io::flush` isn't reachable
/// from here. The cost is one timer per stalled chunk on a connection that is
/// already the bottleneck.
async fn await_write_capacity(sink: &WsSink) -> bool {
    while sink.io().is_wr_backpressure() {
        if sink.io().is_closed() {
            return false;
        }
        sleep(BACKPRESSURE_POLL).await;
    }
    !sink.io().is_closed()
}

/// First value of `name` in a query string.
///
/// Hand-rolled rather than pulled from a form decoder because the only value
/// read here is an opaque hex ticket, and a percent-decoding step would be a
/// place for a `%00`-style trick to hide.
pub fn query_param(query: &str, name: &str) -> Option<String> {
    query.split('&').find_map(|pair| {
        let (key, value) = pair.split_once('=')?;
        (key == name).then(|| value.to_string())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn query_param_reads_the_named_value() {
        assert_eq!(query_param("ticket=abc", "ticket").as_deref(), Some("abc"));
        assert_eq!(
            query_param("a=1&ticket=abc&b=2", "ticket").as_deref(),
            Some("abc")
        );
        assert_eq!(query_param("a=1&b=2", "ticket"), None);
        assert_eq!(query_param("", "ticket"), None);
        // A bare key is not a value
        assert_eq!(query_param("ticket", "ticket"), None);
        // Must not match on a suffix or prefix of the name
        assert_eq!(query_param("myticket=abc", "ticket"), None);
        assert_eq!(query_param("ticketx=abc", "ticket"), None);
    }

    #[test]
    fn the_connection_cap_is_enforced_and_released() {
        let count = Arc::new(TunnelCount::default());
        let a = count.acquire(2).expect("first slot");
        let b = count.acquire(2).expect("second slot");
        assert!(count.acquire(2).is_none(), "third must be refused");

        drop(a);
        let c = count.acquire(2).expect("a freed slot is reusable");
        drop(b);
        drop(c);
        assert!(count.acquire(1).is_some(), "all slots should be back");
    }

    #[test]
    fn a_zero_cap_refuses_everything() {
        let count = Arc::new(TunnelCount::default());
        assert!(count.acquire(0).is_none());
    }
}
