use ironrdp_cliprdr::backend::{ClipboardMessage, ClipboardMessageProxy};
use tokio::sync::mpsc;
use tracing::error;

use crate::rdp::RdpInputEvent;

/// Shim that forwards CLIPRDR events into the `RdpInputEvent` channel.
#[derive(Clone, Debug)]
pub(crate) struct ClientClipboardMessageProxy {
    tx: mpsc::UnboundedSender<RdpInputEvent>,
}

impl ClientClipboardMessageProxy {
    pub(crate) fn new(tx: mpsc::UnboundedSender<RdpInputEvent>) -> Self {
        Self { tx }
    }
}

impl ClipboardMessageProxy for ClientClipboardMessageProxy {
    fn send_clipboard_message(&self, message: ClipboardMessage) {
        if self.tx.send(RdpInputEvent::Clipboard(message)).is_err() {
            error!("Failed to send clipboard message; receiver is closed");
        }
    }
}
