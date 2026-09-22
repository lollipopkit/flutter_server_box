//! Authenticated byte relay for the app's RDP and VNC clients.
//!
//! A desktop ticket grants only one WebSocket upgrade. The panel account must
//! also have `full_access`, which already grants a shell and arbitrary network
//! access as the agent's user. Binary frames carry TCP bytes in both directions;
//! the first text frame selects the target, and the agent answers `ready` or
//! `error` before any desktop bytes are accepted.

use std::cell::{Cell, RefCell};
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Duration;

use ntex::service::{fn_factory_with_config, fn_service};
use ntex::util::Bytes;
use ntex::web::ws::{self, CloseCode, Frame, Message, WsSink};
use ntex::web::{self, HttpRequest, HttpResponse};
use ntex::ws::Item;
use serde::Deserialize;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::{Semaphore, mpsc};
use tokio::time::timeout;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::ticket::Purpose;
use crate::api::server::AppState;

const TICKET_PROTOCOL_PREFIX: &str = "sbm-ticket.";
const MAX_CONNECTIONS: usize = 8;
const OPEN_TIMEOUT: Duration = Duration::from_secs(10);
const INPUT_QUEUE: usize = 64;
static SLOTS: OnceLock<Arc<Semaphore>> = OnceLock::new();

#[derive(Deserialize)]
struct OpenTarget {
    host: String,
    port: u16,
}

pub async fn desktop_ws(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
    let remote_ip = audit::peer_ip(&req);
    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Desktop, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(reason)
            .record(&app_state.db)
            .await;
        Ok(status)
    };

    if !app_state.full_access_allowed(super::is_secure_transport(&req, app_state.tls_active)) {
        return deny(
            "full access unavailable",
            HttpResponse::Forbidden().finish(),
        )
        .await;
    }
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().finish()).await;
    }
    let Some(protocol) = ws::subprotocols(&req)
        .find(|value| value.starts_with(TICKET_PROTOCOL_PREFIX))
        .map(str::to_owned)
    else {
        return deny("no ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let raw_ticket = &protocol[TICKET_PROTOCOL_PREFIX.len()..];
    let Ok(reservation) = app_state.tickets.reserve(raw_ticket, Purpose::Desktop) else {
        return deny("ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let subject = reservation.subject().to_string();
    let tickets = app_state.tickets.clone();
    let upgraded = ws::start::<_, _, &str, web::Error>(
        req,
        Some(&protocol),
        fn_factory_with_config(move |sink: WsSink| {
            let app_state = app_state.clone();
            let subject = subject.clone();
            let remote_ip = remote_ip.clone();
            async move { Ok::<_, web::Error>(handler(app_state, subject, remote_ip, sink)) }
        }),
    )
    .await;
    if upgraded.is_ok() {
        tickets.commit(reservation);
    } else {
        tickets.rollback(reservation);
    }
    upgraded
}

fn handler(
    app_state: Arc<AppState>,
    subject: String,
    remote_ip: Option<String>,
    sink: WsSink,
) -> impl ntex::service::Service<Frame, Response = Option<Message>, Error = web::Error> {
    let input = Rc::new(RefCell::new(None::<mpsc::Sender<Bytes>>));
    let opened = Rc::new(Cell::new(false));
    fn_service(move |frame: Frame| {
        let app_state = app_state.clone();
        let subject = subject.clone();
        let remote_ip = remote_ip.clone();
        let sink = sink.clone();
        let input = input.clone();
        let opened = opened.clone();
        async move {
            match frame {
                Frame::Text(text) => {
                    if opened.replace(true) {
                        return Ok(Some(error("Desktop connection already open")));
                    }
                    let target = match serde_json::from_slice::<OpenTarget>(&text) {
                        Ok(target) if valid_target(&target) => target,
                        _ => return Ok(Some(error("Invalid desktop target"))),
                    };
                    if app_state.full_access_off.load(Ordering::Acquire) {
                        return Ok(Some(error("Desktop access is no longer available")));
                    }
                    let slots = SLOTS.get_or_init(|| Arc::new(Semaphore::new(MAX_CONNECTIONS)));
                    let Ok(permit) = slots.clone().try_acquire_owned() else {
                        return Ok(Some(error("Too many desktop connections")));
                    };
                    let stream = match timeout(
                        OPEN_TIMEOUT,
                        TcpStream::connect((target.host.as_str(), target.port)),
                    )
                    .await
                    {
                        Ok(Ok(stream)) => stream,
                        _ => return Ok(Some(error("Could not connect to desktop target"))),
                    };
                    if app_state.full_access_off.load(Ordering::Acquire) {
                        return Ok(Some(error("Desktop access is no longer available")));
                    }
                    Event::new(Kind::Desktop, Action::Open, Outcome::Ok)
                        .subject(&subject)
                        .remote_ip(remote_ip)
                        .detail(format!("{}:{}", target.host, target.port))
                        .record(&app_state.db)
                        .await;
                    let (tx, rx) = mpsc::channel(INPUT_QUEUE);
                    *input.borrow_mut() = Some(tx);
                    if sink
                        .send(Message::Text("{\"type\":\"ready\"}".into()))
                        .await
                        .is_err()
                    {
                        input.borrow_mut().take();
                        return Ok(None);
                    }
                    ntex::rt::spawn(async move {
                        let _permit = permit;
                        relay(stream, rx, sink, app_state.full_access_off.clone()).await;
                    });
                    Ok(None)
                }
                Frame::Binary(data) => {
                    forward(&input, data).await;
                    Ok(None)
                }
                Frame::Continuation(
                    Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data),
                ) => {
                    forward(&input, data).await;
                    Ok(None)
                }
                Frame::Ping(data) => Ok(Some(Message::Pong(data))),
                Frame::Close(_) => {
                    input.borrow_mut().take();
                    Ok(Some(Message::Close(Some(CloseCode::Normal.into()))))
                }
                _ => Ok(None),
            }
        }
    })
}

fn valid_target(target: &OpenTarget) -> bool {
    target.port != 0
        && !target.host.is_empty()
        && target.host.len() <= 255
        && !target
            .host
            .chars()
            .any(|ch| ch.is_whitespace() || ch == '\0')
}

fn error(message: &str) -> Message {
    Message::Text(
        serde_json::json!({ "type": "error", "message": message })
            .to_string()
            .into(),
    )
}

async fn forward(input: &RefCell<Option<mpsc::Sender<Bytes>>>, bytes: Bytes) {
    let tx = input.borrow().clone();
    if let Some(tx) = tx {
        let _ = tx.send(bytes).await;
    }
}

async fn relay(
    stream: TcpStream,
    mut input: mpsc::Receiver<Bytes>,
    sink: WsSink,
    full_access_off: Arc<AtomicBool>,
) {
    let (mut reader, mut writer) = stream.into_split();
    let read = async {
        let mut buffer = [0u8; 32 * 1024];
        loop {
            let count = reader.read(&mut buffer).await?;
            if count == 0 {
                break;
            }
            if sink
                .send(Message::Binary(Bytes::copy_from_slice(&buffer[..count])))
                .await
                .is_err()
            {
                break;
            }
        }
        Ok::<(), std::io::Error>(())
    };
    let write = async {
        while let Some(data) = input.recv().await {
            writer.write_all(&data).await?;
        }
        Ok::<(), std::io::Error>(())
    };
    tokio::pin!(read, write);
    let disconnect = sink.on_disconnect();
    tokio::pin!(disconnect);
    let mut check_access = tokio::time::interval(Duration::from_secs(1));
    loop {
        tokio::select! {
            _ = &mut read => break,
            _ = &mut write => break,
            _ = &mut disconnect => break,
            _ = check_access.tick() => {
                if full_access_off.load(Ordering::Acquire) { break; }
            },
        }
    }
    let _ = sink
        .send(Message::Close(Some(CloseCode::Normal.into())))
        .await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalid_targets_are_rejected() {
        for (host, port) in [("", 3389), ("localhost", 0), ("a b", 3389), ("a\0b", 3389)] {
            assert!(!valid_target(&OpenTarget {
                host: host.into(),
                port
            }));
        }
        assert!(valid_target(&OpenTarget {
            host: "127.0.0.1".into(),
            port: 3389
        }));
    }
}
