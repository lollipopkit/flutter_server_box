//! RDP and VNC client sessions exposed to Flutter.
//!
//! The Dart side owns the SSH tunnel and passes its loopback endpoint here.
//! Protocol tasks own their sockets and keep only the newest complete frame,
//! so a slow Flutter image conversion cannot grow a native frame queue.

use std::io::Cursor;
use std::collections::{HashSet, VecDeque};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ironrdp::client::config::{ClipboardType, ConfigBuilder, Destination};
use ironrdp::client::rdp::{RdpClient, RdpInputEvent, RdpOutputEvent};
use ironrdp::cliprdr::backend::{ClipboardMessage, CliprdrBackend};
use ironrdp::cliprdr::pdu::{
    ClipboardFormat, ClipboardFormatId, ClipboardGeneralCapabilityFlags,
    FileContentsRequest, FileContentsResponse, FormatDataRequest,
    FormatDataResponse, LockDataId, OwnedFormatDataResponse,
};
use ironrdp::core::impl_as_any;
use ironrdp::input::{Database as RdpInputDatabase, MouseButton, MousePosition, Operation, Scancode, WheelRotations};
use ironrdp::pdu::input::fast_path::{FastPathInputEvent, KeyboardFlags};
use ironrdp::pdu::rdp::capability_sets::MajorPlatformType;
use jpeg_decoder::PixelFormat as JpegPixelFormat;
use sha2::{Digest as _, Sha256};
use smallvec::SmallVec;
use tokio::net::TcpStream;
use tokio::runtime::Builder;
use tokio::sync::{mpsc, watch, Notify};
use vnc::{ClientKeyEvent, ClientMouseEvent, PixelFormat, Rect, VncConnector, VncEncoding, VncEvent, X11Event};

const MAX_WIDTH: u32 = 8192;
const MAX_HEIGHT: u32 = 8192;
const MAX_FRAME_BYTES: usize = 64 * 1024 * 1024;
const FRAME_INTERVAL: Duration = Duration::from_millis(33);
const CHANNEL_CAPACITY: usize = 64;

#[derive(Clone, Debug)]
pub struct RdpSessionParams {
    /// Loopback address of the SSH local tunnel.
    pub connect_host: String,
    pub connect_port: u16,
    /// Hostname as seen by the SSH server and used for certificate checks.
    pub server_name: String,
    pub server_port: u16,
    pub username: String,
    pub password: String,
    pub domain: Option<String>,
    pub trusted_cert_sha256: Option<String>,
    pub width: u16,
    pub height: u16,
    pub scale_factor: u32,
}

#[derive(Clone, Debug)]
pub struct VncSessionParams {
    /// Loopback address of the SSH local tunnel.
    pub connect_host: String,
    pub connect_port: u16,
    pub password: Option<String>,
    pub shared: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RemoteDesktopConnectionState {
    Connecting,
    Connected,
    Reconnecting,
    Disconnected,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RemoteDesktopEndReason {
    ClosedByUser,
    AuthenticationFailed,
    CertificateRejected,
    ConfigurationError,
    TransportError,
    ServerDisconnected,
}

#[derive(Clone, Debug)]
pub enum RemoteDesktopEvent {
    ConnectionState {
        state: RemoteDesktopConnectionState,
        attempt: u8,
    },
    Frame {
        bgra: Vec<u8>,
        width: u32,
        height: u32,
        sequence: u64,
    },
    Resolution {
        width: u32,
        height: u32,
    },
    CursorDefault,
    CursorHidden,
    CursorPosition {
        x: u32,
        y: u32,
    },
    CursorBitmap {
        rgba: Vec<u8>,
        width: u32,
        height: u32,
        hotspot_x: u32,
        hotspot_y: u32,
    },
    ClipboardText {
        text: String,
    },
    CertificateRequest {
        sha256: String,
        subject: String,
        issuer: String,
        valid_from: String,
        valid_to: String,
        previous_sha256: Option<String>,
    },
    Error {
        message: String,
        retryable: bool,
    },
    Ended {
        reason: RemoteDesktopEndReason,
        message: Option<String>,
    },
}

#[derive(Debug)]
enum SessionCommand {
    Close,
    SetVisible(bool),
    Key {
        code: u32,
        down: bool,
        extended: bool,
    },
    UnicodeText(String),
    Pointer {
        x: u16,
        y: u16,
        buttons: u8,
    },
    Wheel {
        x: u16,
        y: u16,
        delta_x: i16,
        delta_y: i16,
    },
    Clipboard(String),
    Resize {
        width: u16,
        height: u16,
        scale_factor: u32,
        physical_width_mm: Option<u32>,
        physical_height_mm: Option<u32>,
    },
    ReleaseAll,
}

struct CommandQueue {
    queue: Mutex<VecDeque<SessionCommand>>,
    notify: Notify,
    closed: Mutex<bool>,
}

impl CommandQueue {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            queue: Mutex::new(VecDeque::with_capacity(CHANNEL_CAPACITY)),
            notify: Notify::new(),
            closed: Mutex::new(false),
        })
    }

    fn send(&self, command: SessionCommand) -> Result<(), ()> {
        let mut queue = self.queue.lock().map_err(|_| ())?;
        if *self.closed.lock().map_err(|_| ())? {
            return Err(());
        }
        if queue.len() >= CHANNEL_CAPACITY {
            if let Some(existing) = queue.iter_mut().rev().find(|item| {
                matches!(item, SessionCommand::Pointer { .. } | SessionCommand::Wheel { .. } | SessionCommand::Resize { .. } | SessionCommand::SetVisible(_))
            }) {
                if matches!(&command, SessionCommand::Pointer { .. } | SessionCommand::Wheel { .. } | SessionCommand::Resize { .. } | SessionCommand::SetVisible(_)) {
                    *existing = command;
                    self.notify.notify_one();
                    return Ok(());
                }
            }
            if let Some(index) = queue.iter().position(|item| {
                matches!(item, SessionCommand::Pointer { .. } | SessionCommand::Wheel { .. } | SessionCommand::Resize { .. } | SessionCommand::SetVisible(_))
            }) {
                queue.remove(index);
            } else if matches!(&command, SessionCommand::Close) {
                queue.clear();
            } else {
                return Err(());
            }
        }
        queue.push_back(command);
        self.notify.notify_one();
        Ok(())
    }

    async fn recv(&self) -> Option<SessionCommand> {
        loop {
            let notified = self.notify.notified();
            if let Ok(mut queue) = self.queue.lock() {
                if let Some(command) = queue.pop_front() {
                    return Some(command);
                }
                if self.closed.lock().map(|closed| *closed).unwrap_or(true) {
                    return None;
                }
            } else {
                return None;
            }
            notified.await;
        }
    }

    fn try_recv(&self) -> Option<SessionCommand> {
        self.queue.lock().ok()?.pop_front()
    }

    fn close(&self) {
        if let Ok(mut closed) = self.closed.lock() {
            *closed = true;
        }
        self.notify.notify_waiters();
    }

}

struct EventReceiver {
    events: Arc<EventQueue>,
    frames: watch::Receiver<Option<Arc<Frame>>>,
}

#[derive(Debug)]
struct EventQueue {
    queue: Mutex<VecDeque<RemoteDesktopEvent>>,
    notify: Notify,
    closed: Mutex<bool>,
}

impl EventQueue {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            queue: Mutex::new(VecDeque::with_capacity(CHANNEL_CAPACITY)),
            notify: Notify::new(),
            closed: Mutex::new(false),
        })
    }

    fn send(&self, event: RemoteDesktopEvent) {
        let Ok(mut queue) = self.queue.lock() else { return };
        if self.closed.lock().map(|closed| *closed).unwrap_or(true) {
            return;
        }
        let replaceable = matches!(&event, RemoteDesktopEvent::CursorPosition { .. });
        if queue.len() >= CHANNEL_CAPACITY {
            if replaceable {
                if let Some(existing) = queue.iter_mut().rev().find(|item| matches!(item, RemoteDesktopEvent::CursorPosition { .. })) {
                    *existing = event;
                }
                return;
            }
            if let Some(index) = queue.iter().position(|item| matches!(item, RemoteDesktopEvent::CursorPosition { .. })) {
                queue.remove(index);
            } else {
                return;
            }
        }
        queue.push_back(event);
        self.notify.notify_one();
    }

    async fn recv(&self) -> Option<RemoteDesktopEvent> {
        loop {
            let notified = self.notify.notified();
            if let Ok(mut queue) = self.queue.lock() {
                if let Some(event) = queue.pop_front() {
                    return Some(event);
                }
                if self.closed.lock().map(|closed| *closed).unwrap_or(true) {
                    return None;
                }
            } else {
                return None;
            }
            notified.await;
        }
    }

    fn close(&self) {
        if let Ok(mut closed) = self.closed.lock() {
            *closed = true;
        }
        self.notify.notify_waiters();
    }

    fn is_closed(&self) -> bool {
        self.closed.lock().map(|closed| *closed).unwrap_or(true)
    }
}

#[derive(Debug)]
struct Frame {
    bgra: Arc<Vec<u8>>,
    width: u32,
    height: u32,
    sequence: u64,
}

#[derive(Clone, Debug)]
struct EventSender {
    events: Arc<EventQueue>,
    frames: watch::Sender<Option<Arc<Frame>>>,
    sequence: Arc<std::sync::atomic::AtomicU64>,
}

impl EventSender {
    fn event(&self, event: RemoteDesktopEvent) {
        self.events.send(event);
    }

    fn frame(&self, bgra: Vec<u8>, width: u32, height: u32) {
        self.frame_shared(Arc::new(bgra), width, height);
    }

    fn frame_shared(&self, bgra: Arc<Vec<u8>>, width: u32, height: u32) {
        let sequence = self
            .sequence
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            .saturating_add(1);
        self.frames.send_replace(Some(Arc::new(Frame {
            bgra,
            width,
            height,
            sequence,
        })));
    }
}

/// Opaque native session. Only commands and one-at-a-time event reads cross FFI.
#[flutter_rust_bridge::frb(opaque)]
pub struct RemoteDesktopSessionHandle {
    commands: Arc<CommandQueue>,
    receiver: tokio::sync::Mutex<EventReceiver>,
}

impl RemoteDesktopSessionHandle {
    #[flutter_rust_bridge::frb(sync)]
    pub fn start_rdp(params: RdpSessionParams) -> Result<Self, String> {
        validate_endpoint(&params.connect_host, params.connect_port)?;
        validate_size(u32::from(params.width), u32::from(params.height))?;
        if params.server_name.trim().is_empty() {
            return Err("RDP server name is empty".to_owned());
        }
        if params.server_port == 0 {
            return Err("RDP server port must be non-zero".to_owned());
        }
        if params.username.is_empty() {
            return Err("RDP username is empty".to_owned());
        }
        Self::spawn(move |commands, events| run_rdp(params, commands, events))
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn start_vnc(params: VncSessionParams) -> Result<Self, String> {
        validate_endpoint(&params.connect_host, params.connect_port)?;
        if let Some(password) = &params.password {
            if !password.is_ascii() || password.len() > 8 {
                return Err("VNC passwords must contain at most 8 ASCII bytes".to_owned());
            }
        }
        Self::spawn(move |commands, events| run_vnc(params, commands, events))
    }

    fn spawn<F, Fut>(run: F) -> Result<Self, String>
    where
        F: FnOnce(Arc<CommandQueue>, EventSender) -> Fut + Send + 'static,
        Fut: std::future::Future<Output = ()> + 'static,
    {
        let command_tx = CommandQueue::new();
        let event_queue = EventQueue::new();
        let (frame_tx, frame_rx) = watch::channel(None);
        let events = EventSender {
            events: event_queue.clone(),
            frames: frame_tx,
            sequence: Arc::new(std::sync::atomic::AtomicU64::new(0)),
        };
        let worker_commands = command_tx.clone();
        let worker_events = event_queue.clone();
        std::thread::Builder::new()
            .name("server-box-remote-desktop".to_owned())
            .spawn(move || {
                let runtime = Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("remote desktop runtime");
                runtime.block_on(run(worker_commands.clone(), events));
                worker_commands.close();
                worker_events.close();
            })
            .map_err(|error| format!("failed to start remote desktop worker: {error}"))?;
        Ok(Self {
            commands: command_tx,
            receiver: tokio::sync::Mutex::new(EventReceiver {
                events: event_queue,
                frames: frame_rx,
            }),
        })
    }

    /// Wait for the next state/input event or the newest complete frame.
    pub async fn next_event(&self) -> Option<RemoteDesktopEvent> {
        let mut receiver = self.receiver.lock().await;
        let EventReceiver { events, frames } = &mut *receiver;
        loop {
            tokio::select! {
                    event = events.recv() => return event,
                changed = frames.changed() => {
                    if changed.is_err() {
                        if events.is_closed() {
                            return None;
                        }
                        continue;
                    }
                    let frame = frames.borrow_and_update().clone();
                    if let Some(frame) = frame {
                        return Some(RemoteDesktopEvent::Frame {
                            bgra: frame.bgra.as_ref().clone(),
                            width: frame.width,
                            height: frame.height,
                            sequence: frame.sequence,
                        });
                    }
                }
            }
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn close(&self) {
        self.send(SessionCommand::Close);
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn set_visible(&self, visible: bool) {
        self.send(SessionCommand::SetVisible(visible));
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn send_key(&self, code: u32, down: bool, extended: bool) {
        self.send(SessionCommand::Key {
            code,
            down,
            extended,
        });
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn send_unicode_text(&self, text: String) {
        self.send(SessionCommand::UnicodeText(text));
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn send_pointer(&self, x: u16, y: u16, buttons: u8) {
        self.send(SessionCommand::Pointer { x, y, buttons });
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn send_wheel(&self, x: u16, y: u16, delta_x: i16, delta_y: i16) {
        self.send(SessionCommand::Wheel {
            x,
            y,
            delta_x,
            delta_y,
        });
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn send_clipboard_text(&self, text: String) -> Result<(), String> {
        self.commands
            .send(SessionCommand::Clipboard(text))
            .map_err(|_| "remote desktop session is closed".to_owned())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn resize(
        &self,
        width: u16,
        height: u16,
        scale_factor: u32,
        physical_width_mm: Option<u32>,
        physical_height_mm: Option<u32>,
    ) -> Result<(), String> {
        validate_size(u32::from(width), u32::from(height))?;
        self.commands
            .send(SessionCommand::Resize {
                width,
                height,
                scale_factor,
                physical_width_mm,
                physical_height_mm,
            })
            .map_err(|_| "remote desktop session is closed".to_owned())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn release_all_keys(&self) {
        self.send(SessionCommand::ReleaseAll);
    }

    fn send(&self, command: SessionCommand) {
        let _ = self.commands.send(command);
    }
}

impl Drop for RemoteDesktopSessionHandle {
    fn drop(&mut self) {
        let _ = self.commands.send(SessionCommand::Close);
    }
}

fn validate_endpoint(host: &str, port: u16) -> Result<(), String> {
    if host.trim().is_empty() {
        return Err("remote desktop tunnel host is empty".to_owned());
    }
    if port == 0 {
        return Err("remote desktop tunnel port must be non-zero".to_owned());
    }
    Ok(())
}

fn validate_size(width: u32, height: u32) -> Result<(), String> {
    let frame_bytes = usize::try_from(width)
        .ok()
        .and_then(|width| usize::try_from(height).ok().and_then(|height| width.checked_mul(height)))
        .and_then(|pixels| pixels.checked_mul(4));
    if width == 0
        || height == 0
        || width > MAX_WIDTH
        || height > MAX_HEIGHT
        || frame_bytes.is_none_or(|bytes| bytes > MAX_FRAME_BYTES)
    {
        return Err(format!(
            "remote desktop size must be between 1x1 and {MAX_WIDTH}x{MAX_HEIGHT}, with at most {MAX_FRAME_BYTES} framebuffer bytes"
        ));
    }
    Ok(())
}

async fn run_rdp(
    params: RdpSessionParams,
    commands: Arc<CommandQueue>,
    events: EventSender,
) {
    events.event(RemoteDesktopEvent::ConnectionState {
        state: RemoteDesktopConnectionState::Connecting,
        attempt: 0,
    });

    let destination = Destination::from_parts(params.server_name.clone(), params.server_port);
    let tcp_destination = Destination::from_parts(params.connect_host.clone(), params.connect_port);
    let mut builder = ConfigBuilder::new()
        .with_destination(destination)
        .with_tcp_destination(tcp_destination)
        .with_username(params.username)
        .with_password(params.password)
        .with_client_build(0)
        .with_client_dir("ServerBox")
        .with_client_name("ServerBox")
        .with_platform(MajorPlatformType::UNSPECIFIED)
        .with_desktop_width(params.width)
        .with_desktop_height(params.height)
        .with_desktop_scale_factor(params.scale_factor.clamp(100, 500))
        .with_credssp(true)
        .with_tls(true)
        .with_server_pointer(true)
        .with_pointer_software_rendering(false)
        .with_clipboard(ClipboardType::Disable);
    if let Some(fingerprint) = params.trusted_cert_sha256.as_deref() {
        match parse_sha256_fingerprint(fingerprint) {
            Ok(fingerprint) => builder = builder.with_trusted_cert_sha256(fingerprint),
            Err(message) => {
                events.event(RemoteDesktopEvent::Error {
                    message: message.clone(),
                    retryable: false,
                });
                events.event(RemoteDesktopEvent::Ended {
                    reason: RemoteDesktopEndReason::ConfigurationError,
                    message: Some(message),
                });
                return;
            }
        }
    }
    if let Some(domain) = params.domain.filter(|value| !value.is_empty()) {
        builder = builder.with_domain(domain);
    }

    let clipboard_state = Arc::new(Mutex::new(RdpClipboardState::default()));
    let clipboard_events = events.clone();
    let clipboard_state_for_factory = clipboard_state.clone();
    builder = builder.with_static_channel(move |_| {
        Some(ironrdp::cliprdr::Cliprdr::new(Box::new(RdpClipboardBackend {
            state: clipboard_state_for_factory.clone(),
            events: clipboard_events.clone(),
        })))
    });

    let config = match builder.build() {
        Ok(config) => config,
        Err(error) => {
            let message = error.to_string();
            events.event(RemoteDesktopEvent::Error {
                message: message.clone(),
                retryable: false,
            });
            events.event(RemoteDesktopEvent::Ended {
                reason: RemoteDesktopEndReason::ConfigurationError,
                message: Some(message),
            });
            return;
        }
    };

    let (rdp_output_tx, mut rdp_output_rx) = mpsc::channel(2);
    let client = RdpClient::new(config, rdp_output_tx);
    let rdp_input = client.input_sender();
    if let Ok(mut state) = clipboard_state.lock() {
        state.input = Some(rdp_input.clone());
    }
    let client_run = client.run();
    tokio::pin!(client_run);
    let mut input = RdpInputDatabase::new();
    let mut visible = true;
    let mut latest_frame: Option<(Arc<Vec<u8>>, u32, u32)> = None;
    let mut frame_dirty = false;
    let mut connected_sent = false;
    let mut client_done = false;
    let mut last_frame_sent = tokio::time::Instant::now() - FRAME_INTERVAL;
    let mut ticker = tokio::time::interval(FRAME_INTERVAL);
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        tokio::select! {
            output = rdp_output_rx.recv() => {
                match output {
                    Some(RdpOutputEvent::Image { buffer, width, height }) => {
                        let width = u32::from(width.get());
                        let height = u32::from(height.get());
                        if let Err(message) = validate_size(width, height) {
                            events.event(RemoteDesktopEvent::Error {
                                message: message.clone(),
                                retryable: false,
                            });
                            events.event(RemoteDesktopEvent::Ended {
                                reason: RemoteDesktopEndReason::ConfigurationError,
                                message: Some(message),
                            });
                            break;
                        }
                        let expected_pixels = usize::try_from(width)
                            .ok()
                            .and_then(|width| usize::try_from(height).ok().and_then(|height| width.checked_mul(height)));
                        if expected_pixels != Some(buffer.len()) {
                            let message = "RDP frame dimensions do not match its pixel buffer".to_owned();
                            events.event(RemoteDesktopEvent::Error {
                                message: message.clone(),
                                retryable: false,
                            });
                            events.event(RemoteDesktopEvent::Ended {
                                reason: RemoteDesktopEndReason::ConfigurationError,
                                message: Some(message),
                            });
                            break;
                        }
                        latest_frame = Some((Arc::new(rdp_pixels_to_bgra(&buffer)), width, height));
                        frame_dirty = true;
                        if !connected_sent {
                            events.event(RemoteDesktopEvent::ConnectionState {
                                state: RemoteDesktopConnectionState::Connected,
                                attempt: 0,
                            });
                            events.event(RemoteDesktopEvent::Resolution { width, height });
                            connected_sent = true;
                        }
                        if visible && last_frame_sent.elapsed() >= FRAME_INTERVAL {
                            publish_latest_frame(&events, &latest_frame);
                            frame_dirty = false;
                            last_frame_sent = tokio::time::Instant::now();
                        }
                    }
                    Some(RdpOutputEvent::PointerDefault) => events.event(RemoteDesktopEvent::CursorDefault),
                    Some(RdpOutputEvent::PointerHidden) => events.event(RemoteDesktopEvent::CursorHidden),
                    Some(RdpOutputEvent::PointerPosition { x, y }) => events.event(RemoteDesktopEvent::CursorPosition {
                        x: u32::from(x),
                        y: u32::from(y),
                    }),
                    Some(RdpOutputEvent::PointerBitmap(pointer)) => events.event(RemoteDesktopEvent::CursorBitmap {
                        rgba: pointer.bitmap_data.clone(),
                        width: u32::from(pointer.width),
                        height: u32::from(pointer.height),
                        hotspot_x: u32::from(pointer.hotspot_x),
                        hotspot_y: u32::from(pointer.hotspot_y),
                    }),
                    Some(RdpOutputEvent::CertificateRequest { der, previous_sha256 }) => {
                        match certificate_event(&der, previous_sha256) {
                            Ok(event) => events.event(event),
                            Err(message) => events.event(RemoteDesktopEvent::Error {
                                message,
                                retryable: false,
                            }),
                        }
                    }
                    Some(RdpOutputEvent::ConnectionFailure(error)) => {
                        let message = error.to_string();
                        let reason = classify_rdp_failure(&message);
                        events.event(RemoteDesktopEvent::Error {
                            message: message.clone(),
                            retryable: reason == RemoteDesktopEndReason::TransportError,
                        });
                        events.event(RemoteDesktopEvent::Ended { reason, message: Some(message) });
                        break;
                    }
                    Some(RdpOutputEvent::Terminated(result)) => {
                        let message = result.err().map(|error| error.to_string());
                        events.event(RemoteDesktopEvent::Ended {
                            reason: if message.is_some() {
                                RemoteDesktopEndReason::TransportError
                            } else {
                                RemoteDesktopEndReason::ServerDisconnected
                            },
                            message,
                        });
                        break;
                    }
                    None => {
                        events.event(RemoteDesktopEvent::Ended {
                            reason: RemoteDesktopEndReason::ServerDisconnected,
                            message: None,
                        });
                        break;
                    }
                }
            }
            command = commands.recv() => {
                match command {
                    Some(SessionCommand::Close) | None => {
                        let _ = rdp_input.send(RdpInputEvent::Close);
                        events.event(RemoteDesktopEvent::Ended {
                            reason: RemoteDesktopEndReason::ClosedByUser,
                            message: None,
                        });
                        break;
                    }
                    Some(SessionCommand::SetVisible(value)) => {
                        visible = value;
                        if visible {
                            publish_latest_frame(&events, &latest_frame);
                            frame_dirty = false;
                            last_frame_sent = tokio::time::Instant::now();
                        }
                    }
                    Some(command) => handle_rdp_command(command, &rdp_input, &mut input, &clipboard_state),
                }
            }
            _ = ticker.tick(), if visible && frame_dirty => {
                if last_frame_sent.elapsed() >= FRAME_INTERVAL {
                    publish_latest_frame(&events, &latest_frame);
                    frame_dirty = false;
                    last_frame_sent = tokio::time::Instant::now();
                }
            }
            _ = &mut client_run, if !client_done => {
                client_done = true;
            }
        }
    }
}

fn publish_latest_frame(events: &EventSender, latest: &Option<(Arc<Vec<u8>>, u32, u32)>) {
    if let Some((bgra, width, height)) = latest {
        events.frame_shared(Arc::clone(bgra), *width, *height);
    }
}

fn handle_rdp_command(
    command: SessionCommand,
    sender: &mpsc::UnboundedSender<RdpInputEvent>,
    input: &mut RdpInputDatabase,
    clipboard_state: &Arc<Mutex<RdpClipboardState>>,
) {
    match command {
        SessionCommand::Key {
            code,
            down,
            extended,
        } => {
            let Ok(code) = u8::try_from(code) else { return };
            let operation = if down {
                Operation::KeyPressed(Scancode::from_u8(extended, code))
            } else {
                Operation::KeyReleased(Scancode::from_u8(extended, code))
            };
            send_rdp_fast_path(sender, input.apply([operation]));
        }
        SessionCommand::UnicodeText(text) => {
            let mut events = Vec::new();
            for unit in text.encode_utf16() {
                events.push(FastPathInputEvent::UnicodeKeyboardEvent(KeyboardFlags::empty(), unit));
                events.push(FastPathInputEvent::UnicodeKeyboardEvent(KeyboardFlags::RELEASE, unit));
            }
            send_rdp_fast_path(sender, events);
        }
        SessionCommand::Pointer { x, y, buttons } => {
            let mut operations = vec![Operation::MouseMove(MousePosition { x, y })];
            for (index, button) in [MouseButton::Left, MouseButton::Middle, MouseButton::Right]
                .into_iter()
                .enumerate()
            {
                let down = buttons & (1 << index) != 0;
                if down != input.is_mouse_button_pressed(button) {
                    operations.push(if down {
                        Operation::MouseButtonPressed(button)
                    } else {
                        Operation::MouseButtonReleased(button)
                    });
                }
            }
            send_rdp_fast_path(sender, input.apply(operations));
        }
        SessionCommand::Wheel {
            x,
            y,
            delta_x,
            delta_y,
        } => {
            let mut operations = vec![Operation::MouseMove(MousePosition { x, y })];
            if delta_y != 0 {
                operations.push(Operation::WheelRotations(WheelRotations {
                    is_vertical: true,
                    rotation_units: delta_y,
                }));
            }
            if delta_x != 0 {
                operations.push(Operation::WheelRotations(WheelRotations {
                    is_vertical: false,
                    rotation_units: delta_x,
                }));
            }
            send_rdp_fast_path(sender, input.apply(operations));
        }
        SessionCommand::Clipboard(text) => {
            if let Ok(mut state) = clipboard_state.lock() {
                state.local_text = text;
            }
            let _ = sender.send(RdpInputEvent::Clipboard(ClipboardMessage::SendInitiateCopy(vec![
                ClipboardFormat::new(ClipboardFormatId::CF_UNICODETEXT),
            ])));
        }
        SessionCommand::Resize {
            width,
            height,
            scale_factor,
            physical_width_mm,
            physical_height_mm,
        } => {
            let physical_size = physical_width_mm.zip(physical_height_mm);
            let _ = sender.send(RdpInputEvent::Resize {
                width,
                height,
                scale_factor,
                physical_size,
            });
        }
        SessionCommand::ReleaseAll => {
            send_rdp_fast_path(sender, input.release_all());
        }
        SessionCommand::Close | SessionCommand::SetVisible(_) => {}
    }
}

fn send_rdp_fast_path(
    sender: &mpsc::UnboundedSender<RdpInputEvent>,
    events: impl IntoIterator<Item = FastPathInputEvent>,
) {
    let events: SmallVec<[FastPathInputEvent; 2]> = events.into_iter().collect();
    if !events.is_empty() {
        let _ = sender.send(RdpInputEvent::FastPath(events));
    }
}

fn classify_rdp_failure(message: &str) -> RemoteDesktopEndReason {
    let lower = message.to_ascii_lowercase();
    if lower.contains("credential") || lower.contains("logon") || lower.contains("authentication") {
        RemoteDesktopEndReason::AuthenticationFailed
    } else if lower.contains("certificate") {
        RemoteDesktopEndReason::CertificateRejected
    } else {
        RemoteDesktopEndReason::TransportError
    }
}

fn parse_sha256_fingerprint(value: &str) -> Result<[u8; 32], String> {
    let compact: String = value.chars().filter(|character| *character != ':').collect();
    if compact.len() != 64 || !compact.is_ascii() {
        return Err("RDP certificate fingerprint must contain 64 hexadecimal digits".to_owned());
    }
    let mut fingerprint = [0_u8; 32];
    for (index, byte) in fingerprint.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&compact[index * 2..index * 2 + 2], 16)
            .map_err(|_| "RDP certificate fingerprint is not hexadecimal".to_owned())?;
    }
    Ok(fingerprint)
}

fn format_sha256(fingerprint: &[u8; 32]) -> String {
    fingerprint
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect::<Vec<_>>()
        .join(":")
}

fn certificate_event(
    der: &[u8],
    previous_sha256: Option<[u8; 32]>,
) -> Result<RemoteDesktopEvent, String> {
    use x509_cert::der::Decode as _;

    let certificate = x509_cert::Certificate::from_der(der)
        .map_err(|error| format!("RDP certificate could not be decoded: {error}"))?;
    let fingerprint: [u8; 32] = Sha256::digest(der).into();
    Ok(RemoteDesktopEvent::CertificateRequest {
        sha256: format_sha256(&fingerprint),
        subject: certificate.tbs_certificate.subject.to_string(),
        issuer: certificate.tbs_certificate.issuer.to_string(),
        valid_from: certificate.tbs_certificate.validity.not_before.to_string(),
        valid_to: certificate.tbs_certificate.validity.not_after.to_string(),
        previous_sha256: previous_sha256.as_ref().map(format_sha256),
    })
}

fn rdp_pixels_to_bgra(pixels: &[u32]) -> Vec<u8> {
    let mut bgra = Vec::with_capacity(pixels.len().saturating_mul(4));
    for pixel in pixels {
        bgra.push((pixel & 0xff) as u8);
        bgra.push(((pixel >> 8) & 0xff) as u8);
        bgra.push(((pixel >> 16) & 0xff) as u8);
        bgra.push(0xff);
    }
    bgra
}

#[derive(Debug, Default)]
#[flutter_rust_bridge::frb(ignore)]
struct RdpClipboardState {
    local_text: String,
    input: Option<mpsc::UnboundedSender<RdpInputEvent>>,
}

#[derive(Debug)]
struct RdpClipboardBackend {
    state: Arc<Mutex<RdpClipboardState>>,
    events: EventSender,
}

impl_as_any!(RdpClipboardBackend);

impl CliprdrBackend for RdpClipboardBackend {
    fn temporary_directory(&self) -> &str {
        ".serverbox-cliprdr"
    }

    fn client_capabilities(&self) -> ClipboardGeneralCapabilityFlags {
        ClipboardGeneralCapabilityFlags::empty()
    }

    fn on_ready(&mut self) {}

    fn on_request_format_list(&mut self) {}

    fn on_process_negotiated_capabilities(&mut self, _: ClipboardGeneralCapabilityFlags) {}

    fn on_remote_copy(&mut self, formats: &[ClipboardFormat]) {
        if formats.iter().any(|format| format.id() == ClipboardFormatId::CF_UNICODETEXT) {
            if let Ok(state) = self.state.lock() {
                if let Some(input) = &state.input {
                    let _ = input.send(RdpInputEvent::Clipboard(ClipboardMessage::SendInitiatePaste(
                        ClipboardFormatId::CF_UNICODETEXT,
                    )));
                }
            }
        }
    }

    fn on_format_data_request(&mut self, request: FormatDataRequest) {
        let response = if request.format == ClipboardFormatId::CF_UNICODETEXT {
            self.state
                .lock()
                .map(|state| OwnedFormatDataResponse::new_unicode_string(&state.local_text))
                .unwrap_or_else(|_| OwnedFormatDataResponse::new_error())
        } else {
            OwnedFormatDataResponse::new_error()
        };
        if let Ok(state) = self.state.lock() {
            if let Some(input) = &state.input {
                let _ = input.send(RdpInputEvent::Clipboard(ClipboardMessage::SendFormatData(response)));
            }
        }
    }

    fn on_format_data_response(&mut self, response: FormatDataResponse<'_>) {
        if let Ok(text) = response.to_unicode_string() {
            self.events.event(RemoteDesktopEvent::ClipboardText { text });
        }
    }

    fn on_file_contents_request(&mut self, _: FileContentsRequest) {}

    fn on_file_contents_response(&mut self, _: FileContentsResponse<'_>) {}

    fn on_lock(&mut self, _: LockDataId) {}

    fn on_unlock(&mut self, _: LockDataId) {}
}

async fn run_vnc(
    params: VncSessionParams,
    commands: Arc<CommandQueue>,
    events: EventSender,
) {
    const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
    const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(15);
    events.event(RemoteDesktopEvent::ConnectionState {
        state: RemoteDesktopConnectionState::Connecting,
        attempt: 0,
    });
    let endpoint = format_endpoint(&params.connect_host, params.connect_port);
    let mut pending_commands = VecDeque::new();
    let connect = TcpStream::connect(endpoint.as_str());
    tokio::pin!(connect);
    let connect_timeout = tokio::time::sleep(CONNECT_TIMEOUT);
    tokio::pin!(connect_timeout);
    let stream = loop {
        tokio::select! {
            result = &mut connect => {
                match result {
                    Ok(stream) => break stream,
                    Err(error) => {
                        finish_vnc_error(&events, error.to_string(), true);
                        return;
                    }
                }
            }
            _ = &mut connect_timeout => {
                finish_vnc_error(&events, "VNC TCP connection timed out".to_owned(), true);
                return;
            }
            command = commands.recv() => match command {
                Some(SessionCommand::Close) | None => {
                    events.event(RemoteDesktopEvent::Ended {
                        reason: RemoteDesktopEndReason::ClosedByUser,
                        message: None,
                    });
                    return;
                }
                Some(command) => pending_commands.push_back(command),
            }
        }
    };
    let password = params.password.unwrap_or_default();
    let shared = params.shared;
    let handshake = async move {
        let state = VncConnector::new(stream)
            .set_auth_method(async move { Ok(password) })
            .add_encoding(VncEncoding::Tight)
            .add_encoding(VncEncoding::Zrle)
            .add_encoding(VncEncoding::CopyRect)
            .add_encoding(VncEncoding::Raw)
            .add_encoding(VncEncoding::CursorPseudo)
            .add_encoding(VncEncoding::DesktopSizePseudo)
            .allow_shared(shared)
            .set_pixel_format(PixelFormat::bgra())
            .build()
            .map_err(|error| (error.to_string(), false))?;
        let state = state.try_start().await.map_err(|error| {
            let retryable = !matches!(error, vnc::VncError::WrongPassword | vnc::VncError::NoPassword);
            (error.to_string(), retryable)
        })?;
        state.finish().map_err(|error| (error.to_string(), false))
    };
    tokio::pin!(handshake);
    let handshake_timeout = tokio::time::sleep(HANDSHAKE_TIMEOUT);
    tokio::pin!(handshake_timeout);
    let client = loop {
        tokio::select! {
            result = &mut handshake => match result {
                Ok(client) => break client,
                Err((message, retryable)) => {
                    finish_vnc_error(&events, message, retryable);
                    return;
                }
            },
            command = commands.recv() => match command {
                Some(SessionCommand::Close) | None => {
                    events.event(RemoteDesktopEvent::Ended {
                        reason: RemoteDesktopEndReason::ClosedByUser,
                        message: None,
                    });
                    return;
                }
                Some(command) => pending_commands.push_back(command),
            },
            _ = &mut handshake_timeout => {
                finish_vnc_error(&events, "VNC handshake timed out".to_owned(), true);
                return;
            }
        }
    };

    events.event(RemoteDesktopEvent::ConnectionState {
        state: RemoteDesktopConnectionState::Connected,
        attempt: 0,
    });
    let mut framebuffer = Framebuffer::default();
    let mut pressed_keys = HashSet::new();
    let mut visible = true;
    let mut dirty = false;
    let mut last_frame_sent = tokio::time::Instant::now() - FRAME_INTERVAL;
    let mut ticker = tokio::time::interval(Duration::from_millis(5));
    ticker.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    while let Some(command) = pending_commands.pop_front() {
        match command {
            SessionCommand::Close => {
                let _ = client.close().await;
                events.event(RemoteDesktopEvent::Ended {
                    reason: RemoteDesktopEndReason::ClosedByUser,
                    message: None,
                });
                return;
            }
            SessionCommand::SetVisible(value) => visible = value,
            command => handle_vnc_command(command, &client, &events, &mut pressed_keys).await,
        }
    }

    'session: loop {
        while let Some(command) = commands.try_recv() {
            match command {
                SessionCommand::Close => {
                    let _ = client.close().await;
                    events.event(RemoteDesktopEvent::Ended {
                        reason: RemoteDesktopEndReason::ClosedByUser,
                        message: None,
                    });
                    break 'session;
                }
                SessionCommand::SetVisible(value) => {
                    visible = value;
                    if visible {
                        let _ = client.input(X11Event::FullRefresh).await;
                        if framebuffer.is_ready() {
                            events.frame(framebuffer.data.clone(), framebuffer.width, framebuffer.height);
                            dirty = false;
                            last_frame_sent = tokio::time::Instant::now();
                        }
                    }
                }
                command => handle_vnc_command(command, &client, &events, &mut pressed_keys).await,
            }
        }

        loop {
            match client.poll_event().await {
                Ok(Some(event)) => match framebuffer.apply_vnc_event(event, &events) {
                    Ok(changed) => dirty |= changed,
                    Err(message) => events.event(RemoteDesktopEvent::Error {
                        message,
                        retryable: false,
                    }),
                },
                Ok(None) => break,
                Err(error) => {
                    finish_vnc_error(&events, error.to_string(), true);
                    break 'session;
                }
            }
        }

        if visible && dirty && last_frame_sent.elapsed() >= FRAME_INTERVAL {
            events.frame(framebuffer.data.clone(), framebuffer.width, framebuffer.height);
            dirty = false;
            last_frame_sent = tokio::time::Instant::now();
        }
        let _ = client.input(X11Event::Refresh).await;
        ticker.tick().await;
    }
}

async fn handle_vnc_command(
    command: SessionCommand,
    client: &vnc::VncClient,
    events: &EventSender,
    pressed_keys: &mut HashSet<u32>,
) {
    let input = match command {
        SessionCommand::Key { code, down, .. } => {
            if down {
                pressed_keys.insert(code);
            } else {
                pressed_keys.remove(&code);
            }
            Some(X11Event::KeyEvent(ClientKeyEvent { keycode: code, down }))
        }
        SessionCommand::UnicodeText(text) => {
            for character in text.chars() {
                let keycode = character as u32;
                let _ = client.input(X11Event::KeyEvent(ClientKeyEvent { keycode, down: true })).await;
                let _ = client.input(X11Event::KeyEvent(ClientKeyEvent { keycode, down: false })).await;
            }
            None
        }
        SessionCommand::Pointer { x, y, buttons } => Some(X11Event::PointerEvent(ClientMouseEvent {
            position_x: x,
            position_y: y,
            bottons: buttons,
        })),
        SessionCommand::Wheel {
            x,
            y,
            delta_x,
            delta_y,
        } => {
            send_vnc_wheel(client, x, y, delta_x, delta_y).await;
            None
        }
        SessionCommand::Clipboard(text) => {
            if text.chars().any(|character| u32::from(character) > 0xff) {
                events.event(RemoteDesktopEvent::Error {
                    message: "VNC clipboard only supports Latin-1 text".to_owned(),
                    retryable: false,
                });
                None
            } else {
                Some(X11Event::CopyText(text))
            }
        }
        SessionCommand::ReleaseAll => {
            for code in pressed_keys.drain() {
                let _ = client
                    .input(X11Event::KeyEvent(ClientKeyEvent { keycode: code, down: false }))
                    .await;
            }
            None
        }
        SessionCommand::Resize { .. } | SessionCommand::Close | SessionCommand::SetVisible(_) => None,
    };
    if let Some(input) = input {
        if let Err(error) = client.input(input).await {
            events.event(RemoteDesktopEvent::Error {
                message: error.to_string(),
                retryable: true,
            });
        }
    }
}

async fn send_vnc_wheel(client: &vnc::VncClient, x: u16, y: u16, delta_x: i16, delta_y: i16) {
    async fn pulse(client: &vnc::VncClient, x: u16, y: u16, button: u8, count: u16) {
        for _ in 0..count.min(32) {
            let _ = client.input(X11Event::PointerEvent(ClientMouseEvent {
                position_x: x,
                position_y: y,
                bottons: button,
            })).await;
            let _ = client.input(X11Event::PointerEvent(ClientMouseEvent {
                position_x: x,
                position_y: y,
                bottons: 0,
            })).await;
        }
    }
    if delta_y != 0 {
        pulse(client, x, y, if delta_y > 0 { 8 } else { 16 }, delta_y.unsigned_abs()).await;
    }
    if delta_x != 0 {
        pulse(client, x, y, if delta_x > 0 { 32 } else { 64 }, delta_x.unsigned_abs()).await;
    }
}

fn finish_vnc_error(events: &EventSender, message: String, retryable: bool) {
    let lower = message.to_ascii_lowercase();
    let reason = if lower.contains("password") || lower.contains("auth") {
        RemoteDesktopEndReason::AuthenticationFailed
    } else if retryable {
        RemoteDesktopEndReason::TransportError
    } else {
        RemoteDesktopEndReason::ConfigurationError
    };
    events.event(RemoteDesktopEvent::Error {
        message: message.clone(),
        retryable,
    });
    events.event(RemoteDesktopEvent::Ended {
        reason,
        message: Some(message),
    });
}

fn format_endpoint(host: &str, port: u16) -> String {
    if host.parse::<std::net::Ipv6Addr>().is_ok() {
        format!("[{host}]:{port}")
    } else {
        format!("{host}:{port}")
    }
}

#[derive(Default)]
#[flutter_rust_bridge::frb(ignore)]
struct Framebuffer {
    width: u32,
    height: u32,
    data: Vec<u8>,
}

impl Framebuffer {
    fn is_ready(&self) -> bool {
        self.width > 0 && self.height > 0 && !self.data.is_empty()
    }

    fn resize(&mut self, width: u32, height: u32) -> Result<(), String> {
        validate_size(width, height)?;
        let len = frame_len(width, height)?;
        self.width = width;
        self.height = height;
        self.data.clear();
        self.data.resize(len, 0);
        Ok(())
    }

    fn apply_vnc_event(&mut self, event: VncEvent, events: &EventSender) -> Result<bool, String> {
        match event {
            VncEvent::SetResolution(screen) => {
                self.resize(u32::from(screen.width), u32::from(screen.height))?;
                events.event(RemoteDesktopEvent::Resolution {
                    width: self.width,
                    height: self.height,
                });
                Ok(true)
            }
            VncEvent::RawImage(rect, data) => {
                self.draw_bgra(rect, &data)?;
                Ok(true)
            }
            VncEvent::Copy(destination, source) => {
                self.copy_rect(destination, source)?;
                Ok(true)
            }
            VncEvent::JpegImage(rect, data) => {
                self.draw_jpeg(rect, &data)?;
                Ok(true)
            }
            VncEvent::SetCursor(rect, data) => {
                events.event(RemoteDesktopEvent::CursorBitmap {
                    rgba: bgra_to_rgba(&data),
                    width: u32::from(rect.width),
                    height: u32::from(rect.height),
                    hotspot_x: u32::from(rect.x),
                    hotspot_y: u32::from(rect.y),
                });
                Ok(false)
            }
            VncEvent::Text(text) => {
                events.event(RemoteDesktopEvent::ClipboardText { text });
                Ok(false)
            }
            VncEvent::Error(message) => Err(message),
            VncEvent::Bell | VncEvent::SetPixelFormat(_) => Ok(false),
            _ => Ok(false),
        }
    }

    fn draw_bgra(&mut self, rect: Rect, pixels: &[u8]) -> Result<(), String> {
        self.ensure_rect(rect)?;
        let row_len = usize::from(rect.width).checked_mul(4).ok_or("rectangle row is too wide")?;
        let expected = row_len
            .checked_mul(usize::from(rect.height))
            .ok_or("rectangle is too large")?;
        if pixels.len() != expected {
            return Err(format!("invalid raw rectangle length: expected {expected}, got {}", pixels.len()));
        }
        for row in 0..usize::from(rect.height) {
            let source = row * row_len;
            let destination = ((usize::from(rect.y) + row) * self.width as usize + usize::from(rect.x)) * 4;
            self.data[destination..destination + row_len]
                .copy_from_slice(&pixels[source..source + row_len]);
            for alpha in (destination + 3..destination + row_len).step_by(4) {
                self.data[alpha] = 0xff;
            }
        }
        Ok(())
    }

    fn copy_rect(&mut self, destination: Rect, source: Rect) -> Result<(), String> {
        self.ensure_rect(destination)?;
        self.ensure_rect(source)?;
        if destination.width != source.width || destination.height != source.height {
            return Err("CopyRect source and destination sizes differ".to_owned());
        }
        let row_len = usize::from(source.width) * 4;
        let mut copied = vec![0; row_len * usize::from(source.height)];
        for row in 0..usize::from(source.height) {
            let start = ((usize::from(source.y) + row) * self.width as usize + usize::from(source.x)) * 4;
            copied[row * row_len..(row + 1) * row_len]
                .copy_from_slice(&self.data[start..start + row_len]);
        }
        for row in 0..usize::from(destination.height) {
            let start = ((usize::from(destination.y) + row) * self.width as usize + usize::from(destination.x)) * 4;
            self.data[start..start + row_len]
                .copy_from_slice(&copied[row * row_len..(row + 1) * row_len]);
        }
        Ok(())
    }

    fn draw_jpeg(&mut self, rect: Rect, encoded: &[u8]) -> Result<(), String> {
        self.ensure_rect(rect)?;
        let mut decoder = jpeg_decoder::Decoder::new(Cursor::new(encoded));
        let decoded = decoder.decode().map_err(|error| format!("Tight JPEG decode failed: {error}"))?;
        let info = decoder.info().ok_or("Tight JPEG has no image metadata")?;
        if info.width != rect.width || info.height != rect.height {
            return Err("Tight JPEG dimensions do not match its rectangle".to_owned());
        }
        let mut bgra = Vec::with_capacity(usize::from(rect.width) * usize::from(rect.height) * 4);
        match info.pixel_format {
            JpegPixelFormat::RGB24 => {
                for pixel in decoded.as_chunks::<3>().0 {
                    bgra.extend_from_slice(&[pixel[2], pixel[1], pixel[0], 0xff]);
                }
            }
            JpegPixelFormat::L8 => {
                for value in decoded {
                    bgra.extend_from_slice(&[value, value, value, 0xff]);
                }
            }
            JpegPixelFormat::CMYK32 => {
                for pixel in decoded.as_chunks::<4>().0 {
                    let convert = |component: u8, black: u8| {
                        255_u16.saturating_sub(u16::from(component).saturating_add(u16::from(black)).min(255)) as u8
                    };
                    bgra.extend_from_slice(&[
                        convert(pixel[2], pixel[3]),
                        convert(pixel[1], pixel[3]),
                        convert(pixel[0], pixel[3]),
                        0xff,
                    ]);
                }
            }
            _ => return Err("unsupported Tight JPEG pixel format".to_owned()),
        }
        self.draw_bgra(rect, &bgra)
    }

    fn ensure_rect(&self, rect: Rect) -> Result<(), String> {
        if !self.is_ready() {
            return Err("framebuffer size is not initialized".to_owned());
        }
        let right = u32::from(rect.x).saturating_add(u32::from(rect.width));
        let bottom = u32::from(rect.y).saturating_add(u32::from(rect.height));
        if rect.width == 0 || rect.height == 0 || right > self.width || bottom > self.height {
            return Err("rectangle is outside the framebuffer".to_owned());
        }
        Ok(())
    }
}

fn frame_len(width: u32, height: u32) -> Result<usize, String> {
    usize::try_from(width)
        .ok()
        .and_then(|width| usize::try_from(height).ok().and_then(|height| width.checked_mul(height)))
        .and_then(|pixels| pixels.checked_mul(4))
        .ok_or_else(|| "framebuffer size overflows memory limits".to_owned())
}

fn bgra_to_rgba(data: &[u8]) -> Vec<u8> {
    let mut rgba = Vec::with_capacity(data.len());
    for pixel in data.as_chunks::<4>().0 {
        rgba.extend_from_slice(&[pixel[2], pixel[1], pixel[0], pixel[3]]);
    }
    rgba
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rect(x: u16, y: u16, width: u16, height: u16) -> Rect {
        Rect { x, y, width, height }
    }

    #[test]
    fn rdp_pixels_are_converted_to_bgra() {
        assert_eq!(rdp_pixels_to_bgra(&[0x0011_2233]), vec![0x33, 0x22, 0x11, 0xff]);
    }

    #[test]
    fn raw_and_copy_rect_compose_a_complete_frame() {
        let mut framebuffer = Framebuffer::default();
        framebuffer.resize(3, 2).unwrap();
        framebuffer
            .draw_bgra(rect(0, 0, 2, 1), &[1, 2, 3, 4, 5, 6, 7, 8])
            .unwrap();
        framebuffer.copy_rect(rect(1, 1, 2, 1), rect(0, 0, 2, 1)).unwrap();
        assert_eq!(&framebuffer.data[16..24], &[1, 2, 3, 0xff, 5, 6, 7, 0xff]);
    }

    #[test]
    fn overlapping_copy_rect_uses_a_snapshot() {
        let mut framebuffer = Framebuffer::default();
        framebuffer.resize(3, 1).unwrap();
        framebuffer
            .draw_bgra(
                rect(0, 0, 3, 1),
                &[1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0],
            )
            .unwrap();
        framebuffer.copy_rect(rect(1, 0, 2, 1), rect(0, 0, 2, 1)).unwrap();
        assert_eq!(framebuffer.data[0], 1);
        assert_eq!(framebuffer.data[4], 1);
        assert_eq!(framebuffer.data[8], 2);
    }

    #[test]
    fn rectangles_are_bounds_checked() {
        let mut framebuffer = Framebuffer::default();
        framebuffer.resize(2, 2).unwrap();
        assert!(framebuffer.draw_bgra(rect(1, 1, 2, 1), &[0; 8]).is_err());
    }

    #[test]
    fn framebuffer_size_is_limited_by_total_bytes() {
        assert!(validate_size(8192, 8192).is_err());
        assert!(validate_size(4096, 4096).is_ok());
    }

    #[test]
    fn vnc_password_limit_is_enforced_before_spawning() {
        let result = RemoteDesktopSessionHandle::start_vnc(VncSessionParams {
            connect_host: "127.0.0.1".to_owned(),
            connect_port: 5900,
            password: Some("123456789".to_owned()),
            shared: true,
        });
        assert!(result.is_err());
    }

    #[test]
    fn certificate_fingerprints_accept_colons_and_mixed_case() {
        let parsed = parse_sha256_fingerprint(
            "00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:\
             00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF",
        )
        .unwrap();
        assert_eq!(format_sha256(&parsed), "00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF");
    }

    #[test]
    fn invalid_certificate_fingerprint_is_rejected() {
        assert!(parse_sha256_fingerprint("not-a-fingerprint").is_err());
    }

    #[tokio::test]
    async fn latest_frame_replaces_an_unread_frame() {
        let event_tx = EventQueue::new();
        let (frame_tx, mut frame_rx) = watch::channel(None);
        let sender = EventSender {
            events: event_tx,
            frames: frame_tx,
            sequence: Arc::new(std::sync::atomic::AtomicU64::new(0)),
        };
        sender.frame(vec![1; 4], 1, 1);
        sender.frame(vec![2; 4], 1, 1);
        frame_rx.changed().await.unwrap();
        let frame = frame_rx.borrow_and_update().clone().unwrap();
        assert_eq!(frame.bgra.as_ref(), &vec![2; 4]);
        assert_eq!(frame.sequence, 2);
    }

    #[tokio::test]
    #[ignore = "60-second 1080p frame-queue stress test"]
    async fn synthetic_thirty_fps_frames_keep_one_native_buffer() {
        let event_tx = EventQueue::new();
        let (frame_tx, mut frame_rx) = watch::channel(None);
        let sender = EventSender {
            events: event_tx,
            frames: frame_tx,
            sequence: Arc::new(std::sync::atomic::AtomicU64::new(0)),
        };
        let frame = vec![0_u8; 1920 * 1080 * 4];
        let start = tokio::time::Instant::now();
        let mut ticker = tokio::time::interval(FRAME_INTERVAL);
        let mut value = 0_u64;
        while start.elapsed() < Duration::from_secs(60) {
            ticker.tick().await;
            sender.frame(frame.clone(), 1920, 1080);
            value += 1;
            assert_eq!(sender.frames.receiver_count(), 1);
            assert_eq!(sender.sequence.load(std::sync::atomic::Ordering::Relaxed), value);
        }
        frame_rx.changed().await.unwrap();
        let latest = frame_rx.borrow_and_update().clone().unwrap();
        assert!(latest.sequence >= 1800);
        assert_eq!(latest.bgra.len(), 1920 * 1080 * 4);
    }
}
