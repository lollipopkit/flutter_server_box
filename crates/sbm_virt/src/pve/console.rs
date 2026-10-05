//! An open PVE console: the bytes of a `vncproxy` or `termproxy` session over
//! the node's `vncwebsocket`, what both the agent's relay and the app's
//! console views read and write.
//!
//! [`Client::open_console`](super::Client::open_console) opens it; for a text
//! console the termproxy login is done by then. What is sent is framed here —
//! input as termproxy's `0:<len>:<data>`, a resize, the keep-alive — so a
//! caller hands over terminal bytes and a size, never protocol.

use std::sync::Arc;

use futures_util::stream::{SplitSink, SplitStream};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::Mutex;
use tokio::task::JoinHandle;
use tokio_tungstenite::tungstenite::Message;

use super::client::ConsoleSocket;
use super::termproxy;
use crate::error::{Error, ErrorKind, Result};
use crate::model::ConsoleKind;

type Sink = SplitSink<ConsoleSocket, Message>;

pub struct Console {
    kind: ConsoleKind,
    sink: Arc<Mutex<Sink>>,
    stream: Mutex<SplitStream<ConsoleSocket>>,
    /// Output that arrived in the frame termproxy accepted the ticket with.
    first: Mutex<Option<Vec<u8>>>,
    /// A text console's keep-alive, running until [`Console::close`] or drop.
    keep_alive: Option<JoinHandle<()>>,
}

impl Console {
    /// `first` is output already read past the termproxy handshake.
    ///
    /// A text console's keep-alive is spawned on the current tokio runtime,
    /// so this is called from within one.
    pub(super) fn new(socket: ConsoleSocket, kind: ConsoleKind, first: Vec<u8>) -> Self {
        let (sink, stream) = socket.split();
        let sink = Arc::new(Mutex::new(sink));
        let keep_alive = (kind == ConsoleKind::Text).then(|| {
            let sink = Arc::downgrade(&sink);
            tokio::spawn(async move {
                let mut every = tokio::time::interval(termproxy::KEEP_ALIVE_INTERVAL);
                every.tick().await;
                loop {
                    every.tick().await;
                    let Some(sink) = sink.upgrade() else { break };
                    let sent = sink.lock().await.send(Message::Binary(termproxy::KEEP_ALIVE.to_vec().into())).await;
                    if sent.is_err() {
                        break;
                    }
                }
            })
        });
        Self {
            kind,
            sink,
            stream: Mutex::new(stream),
            first: Mutex::new((!first.is_empty()).then_some(first)),
            keep_alive,
        }
    }

    pub fn kind(&self) -> ConsoleKind {
        self.kind
    }

    /// The next bytes from the console, or `None` once it has ended — closed
    /// from either side, or failed.
    ///
    /// A text frame is terminal output like a binary one; on a graphical
    /// console it is not part of the RFB stream, and is dropped.
    pub async fn recv(&self) -> Option<Vec<u8>> {
        if let Some(first) = self.first.lock().await.take() {
            return Some(first);
        }
        let mut stream = self.stream.lock().await;
        loop {
            match stream.next().await? {
                Ok(Message::Binary(b)) => return Some(b.to_vec()),
                Ok(Message::Text(t)) if self.kind == ConsoleKind::Text => return Some(t.as_bytes().to_vec()),
                Ok(Message::Close(_)) | Err(_) => return None,
                Ok(_) => continue,
            }
        }
    }

    /// Terminal input for a text console, the RFB stream's next bytes for a
    /// graphical one.
    pub async fn send(&self, data: &[u8]) -> Result<()> {
        if data.is_empty() {
            return Ok(());
        }
        let frame = match self.kind {
            ConsoleKind::Text => termproxy::input(data),
            ConsoleKind::Vnc => data.to_vec(),
        };
        self.send_frame(frame).await
    }

    /// A new terminal size; nothing for a graphical console, whose size is
    /// the guest's.
    pub async fn resize(&self, cols: u16, rows: u16) -> Result<()> {
        if self.kind != ConsoleKind::Text || cols == 0 || rows == 0 {
            return Ok(());
        }
        self.send_frame(termproxy::resize(cols, rows)).await
    }

    async fn send_frame(&self, frame: Vec<u8>) -> Result<()> {
        self.sink
            .lock()
            .await
            .send(Message::Binary(frame.into()))
            .await
            .map_err(|e| Error::msg(ErrorKind::Closed, e.to_string()))
    }

    /// Ends the session: a close frame, waited for no longer than the send.
    pub async fn close(&self) {
        if let Some(keep_alive) = &self.keep_alive {
            keep_alive.abort();
        }
        let mut sink = self.sink.lock().await;
        let _ = tokio::time::timeout(std::time::Duration::from_secs(3), sink.close()).await;
    }
}

impl Drop for Console {
    fn drop(&mut self) {
        if let Some(keep_alive) = &self.keep_alive {
            keep_alive.abort();
        }
    }
}

/// What a termproxy handshake read, frame by frame: `OK` may arrive split
/// across frames, or with the first output after it in the same one.
#[derive(Default)]
pub(super) struct Handshake(Vec<u8>);

impl Handshake {
    /// `None` while too little has arrived to say; `Some(Ok(rest))` once `OK`
    /// has, with the output after it; `Some(Err(()))` for anything else.
    pub(super) fn feed(&mut self, bytes: &[u8]) -> Option<std::result::Result<Vec<u8>, ()>> {
        self.0.extend_from_slice(bytes);
        let n = termproxy::ACCEPTED.len();
        if self.0.len() < n {
            return if termproxy::ACCEPTED.starts_with(&self.0) { None } else { Some(Err(())) };
        }
        if &self.0[..n] != termproxy::ACCEPTED {
            return Some(Err(()));
        }
        Some(Ok(self.0.split_off(n)))
    }
}

#[cfg(test)]
mod tests {
    use super::Handshake;

    #[test]
    fn ok_split_or_followed_by_output() {
        let mut h = Handshake::default();
        assert_eq!(h.feed(b"O"), None);
        assert_eq!(h.feed(b"Kroot# "), Some(Ok(b"root# ".to_vec())));
        assert_eq!(Handshake::default().feed(b"OK"), Some(Ok(Vec::new())));
        assert_eq!(Handshake::default().feed(b"NO"), Some(Err(())));
        assert_eq!(Handshake::default().feed(b"X"), Some(Err(())));
    }
}
