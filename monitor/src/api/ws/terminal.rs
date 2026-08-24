//! `GET /api/v1/terminal/ws` — the panel's in-browser terminal.
//!
//! The agent acts as an SSH client to the local sshd rather than spawning a
//! shell itself, so a session carries the privileges of the SSH account the
//! browser authenticated as. The panel password alone grants no shell; see
//! `crate::ssh::client` for the full argument.
//!
//! # Wire format
//!
//! Frame type is the channel selector, so there is no framing header to get
//! wrong:
//!
//! - **Binary** — PTY bytes, both directions.
//! - **Text** — control JSON, see [`ClientMsg`] and [`ServerMsg`].
//!
//! # Reconnecting
//!
//! Sessions survive the WebSocket (`super::session`), and a client reports how
//! many bytes it has rendered when it comes back. A short outage replays only
//! the gap, so the screen is never cleared; a long one falls back to a reset
//! and says that output was lost. The counter needs no protocol support: a
//! WebSocket frame either arrives whole or not at all, so "bytes rendered" and
//! "bytes delivered" are the same number.

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;
use std::time::Duration;

use ntex::rt::spawn;
use ntex::service::{fn_factory_with_config, fn_service};
use ntex::time::sleep;
use ntex::util::{ByteString, Bytes};
use ntex::web::ws::{self, CloseCode, Frame, Message, WsSink};
use ntex::web::{self, HttpRequest, HttpResponse};
use ntex::ws::Item;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::session::{Replay, Session, SessionInput, SessionOutput, SessionStore};
use super::ticket::Purpose;
use crate::api::server::AppState;
use crate::ssh::client::{
    AuthStep, Credential, InteractivePrompt, ShellEvent, SshError, SshSession, next_shell_event,
};
use crate::ssh::local_pty::LocalShell;

/// How many output messages may queue for a slow client before the live copy
/// is dropped. Nothing is lost: the scrollback still has it, so the client
/// recovers the same way it recovers from a disconnect.
const OUTPUT_QUEUE: usize = 64;

/// Input queued towards the shell. Keystrokes are tiny and a human generates
/// them slowly; this only needs to absorb a paste.
const INPUT_QUEUE: usize = 64;

/// Application-level heartbeat. Browsers can neither send WebSocket pings nor
/// observe pongs, so without this a client cannot tell a quiet session from a
/// dead link — and it is the client noticing that starts a reconnect.
const HEARTBEAT: Duration = Duration::from_secs(15);

/// Terminal resets before a truncated replay. Not part of the replay data
/// itself, since a gap replay must *not* be preceded by one.
const RESET: &[u8] = b"\x1bc";

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ClientMsg {
    /// Start a new session.
    Open {
        user: String,
        auth: AuthPayload,
        #[serde(default = "default_cols")]
        cols: u16,
        #[serde(default = "default_rows")]
        rows: u16,
        #[serde(default = "default_term")]
        term: String,
    },
    /// Rejoin one that outlived its previous connection.
    Attach {
        session: String,
        /// Bytes already rendered — the resume point.
        #[serde(default)]
        since: u64,
        #[serde(default = "default_cols")]
        cols: u16,
        #[serde(default = "default_rows")]
        rows: u16,
    },
    /// Answers to a previous [`ServerMsg::Prompt`].
    Answer { answers: Vec<String> },
    Resize { cols: u16, rows: u16 },
    /// End the session now, as opposed to just dropping the connection.
    Close,
}

#[derive(Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
enum AuthPayload {
    Password { password: String },
    Key { pem: String, passphrase: Option<String> },
    /// Let the server drive the exchange — this is the path that supports
    /// two-factor prompts.
    Interactive,
    /// No credentials at all: run a shell as the agent's own user. Only
    /// honoured when `remote_access.full_access` is on; see
    /// `crate::ssh::local_pty` for what that costs.
    Local,
}

impl AuthPayload {
    /// The SSH credential this represents, or `None` for the local path.
    fn into_credential(self) -> Option<Credential> {
        match self {
            AuthPayload::Password { password } => Some(Credential::Password(password)),
            AuthPayload::Key { pem, passphrase } => Some(Credential::Key { pem, passphrase }),
            AuthPayload::Interactive => Some(Credential::KeyboardInteractive),
            AuthPayload::Local => None,
        }
    }
}

fn default_cols() -> u16 {
    80
}
fn default_rows() -> u16 {
    24
}
fn default_term() -> String {
    "xterm-256color".to_string()
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ServerMsg<'a> {
    /// The shell is live. `session` is the handle for reattaching later.
    Ready { session: &'a str, since: u64 },
    /// The server wants answers before it will authenticate.
    Prompt {
        instructions: &'a str,
        prompts: &'a [InteractivePrompt],
    },
    Error { code: &'a str, message: &'a str },
    Exit { status: Option<u32> },
    /// Proof of life; see [`HEARTBEAT`].
    Hb,
}

impl ServerMsg<'_> {
    fn frame(&self) -> Message {
        // Every variant is a plain struct of owned strings, so this cannot
        // fail in practice; an empty object is a harmless fallback if it ever
        // did, and is better than dropping the connection over it.
        let json = serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string());
        Message::Text(ByteString::from(json))
    }
}

pub async fn terminal_ws(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let app_state = app_state.get_ref().clone();
    let remote_ip = audit::peer_ip(&req);

    let deny = async |reason: &'static str, status: HttpResponse| {
        Event::new(Kind::Terminal, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(reason)
            .record(&app_state.db)
            .await;
        Ok(status)
    };

    let secure = super::is_secure_transport(&req, app_state.tls_active);
    if !app_state.remote_access.terminal.available(secure) {
        // Two different refusals, one status: whether the terminal is off or
        // merely unreachable over this transport is visible on /capabilities
        // to an authenticated caller, and there is no reason to spell it out
        // to an unauthenticated one here.
        return deny(
            if app_state.remote_access.terminal.enabled { "insecure transport" } else { "disabled" },
            HttpResponse::Forbidden().finish(),
        )
        .await;
    }
    if !super::origin_allowed(&req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().finish()).await;
    }

    let Some(raw_ticket) = query_param(req.query_string(), "ticket") else {
        return deny("no ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let Ok(subject) = app_state.tickets.consume(&raw_ticket, Purpose::Terminal) else {
        return deny("ticket", HttpResponse::Unauthorized().finish()).await;
    };

    let ctx = Rc::new(ConnCtx {
        state: app_state,
        subject,
        remote_ip,
        secure,
    });

    ws::start::<_, _, &str, web::Error>(
        req,
        None,
        fn_factory_with_config(move |sink: WsSink| {
            let ctx = ctx.clone();
            async move {
                start_heartbeat(sink.clone());
                Ok::<_, web::Error>(handler(ctx, sink))
            }
        }),
    )
    .await
}

/// First value of `name` in a query string.
///
/// Tickets are opaque hex values, so this intentionally avoids percent
/// decoding and its alternate spellings.
fn query_param(query: &str, name: &str) -> Option<String> {
    query.split('&').find_map(|pair| {
        let (key, value) = pair.split_once('=')?;
        (key == name).then(|| value.to_string())
    })
}

/// Everything about the connection that outlives a single frame.
struct ConnCtx {
    state: Arc<AppState>,
    /// Panel account, from the ticket. Sessions are bound to it.
    subject: String,
    remote_ip: Option<String>,
    /// Whether this connection arrived over a link that can't be read off the
    /// network. Captured at the handshake, where the peer address is known.
    secure: bool,
}

/// Where this connection is in the open/authenticate/run sequence.
enum Phase {
    /// Nothing has been claimed yet. No TCP connection has been made either:
    /// an unauthenticated socket must not be able to make the agent dial sshd.
    Idle,
    /// Mid keyboard-interactive exchange, waiting on the browser's answers.
    Authenticating {
        ssh: Box<SshSession>,
        user: String,
        term: String,
        cols: u16,
        rows: u16,
    },
    Running {
        session: Arc<Session>,
        /// Needed to drop the session from the store on an explicit close;
        /// the session itself doesn't know its own handle.
        handle: String,
    },
    /// Terminal state; further frames are ignored rather than acted on.
    Done,
}

fn handler(
    ctx: Rc<ConnCtx>,
    sink: WsSink,
) -> impl ntex::service::Service<Frame, Response = Option<Message>, Error = web::Error> {
    let phase = Rc::new(RefCell::new(Phase::Idle));

    // Detach rather than destroy when the socket dies: that is the whole
    // point of the session store. `Phase::Done` connections have nothing to
    // detach, and an explicit close already removed the session.
    {
        let phase = phase.clone();
        let disconnect = sink.on_disconnect();
        spawn(async move {
            disconnect.await;
            if let Phase::Running { session, .. } = &*phase.borrow() {
                session.detach();
            }
        });
    }

    fn_service(move |frame: Frame| {
        let ctx = ctx.clone();
        let sink = sink.clone();
        let phase = phase.clone();
        async move {
            match frame {
                Frame::Text(data) => Ok(on_control(&ctx, &sink, &phase, &data).await),
                Frame::Binary(data) => {
                    on_input(&phase, data.to_vec()).await;
                    Ok(None)
                }
                // Terminal input is a byte stream, so fragments go through in
                // order without reassembly.
                Frame::Continuation(Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data)) => {
                    on_input(&phase, data.to_vec()).await;
                    Ok(None)
                }
                Frame::Ping(payload) => Ok(Some(Message::Pong(payload))),
                Frame::Pong(_) => Ok(None),
                Frame::Close(_) => {
                    // A closing socket detaches; the session lives on for the
                    // configured grace period so a reconnect can pick it up
                    if let Phase::Running { session, .. } = &*phase.borrow() {
                        session.detach();
                    }
                    Ok(Some(Message::Close(Some(CloseCode::Normal.into()))))
                }
                Frame::Continuation(Item::FirstText(_)) => Ok(Some(Message::Close(Some(
                    CloseCode::Unsupported.into(),
                )))),
            }
        }
    })
}

async fn on_input(phase: &Rc<RefCell<Phase>>, data: Vec<u8>) {
    if data.is_empty() {
        return;
    }
    let sender = match &*phase.borrow() {
        Phase::Running { session, .. } => Some(session.input.clone()),
        _ => None,
    };
    if let Some(sender) = sender {
        let _ = sender.send(SessionInput::Data(data)).await;
    }
}

async fn on_control(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    raw: &[u8],
) -> Option<Message> {
    let Ok(msg) = serde_json::from_slice::<ClientMsg>(raw) else {
        return Some(error_frame("bad_request", "Unrecognised control message"));
    };

    match msg {
        ClientMsg::Open { user, auth, cols, rows, term } => {
            if !matches!(&*phase.borrow(), Phase::Idle) {
                return Some(error_frame("bad_request", "Session already started"));
            }
            match auth.into_credential() {
                Some(credential) => {
                    open(ctx, sink, phase, user, credential, term, cols, rows).await
                }
                None => open_local(ctx, sink, phase, term, cols, rows).await,
            }
        }
        ClientMsg::Attach { session, since, cols, rows } => {
            if !matches!(&*phase.borrow(), Phase::Idle) {
                return Some(error_frame("bad_request", "Session already started"));
            }
            attach(ctx, sink, phase, &session, since, cols, rows).await
        }
        ClientMsg::Answer { answers } => answer(ctx, sink, phase, answers).await,
        ClientMsg::Resize { cols, rows } => {
            let sender = match &*phase.borrow() {
                Phase::Running { session, .. } => Some(session.input.clone()),
                _ => None,
            };
            if let Some(sender) = sender {
                let _ = sender.send(SessionInput::Resize { cols, rows }).await;
            }
            None
        }
        ClientMsg::Close => {
            let running = match &*phase.borrow() {
                Phase::Running { session, handle } => Some((session.clone(), handle.clone())),
                _ => None,
            };
            if let Some((session, handle)) = running {
                // Dropped from the store as well as closed: an explicit close
                // must not leave something a later `attach` could rejoin
                ctx.state.sessions.remove(&handle);
                let _ = session.input.send(SessionInput::Close).await;
            }
            *phase.borrow_mut() = Phase::Done;
            Some(Message::Close(Some(CloseCode::Normal.into())))
        }
    }
}

/// Starts a shell with no authentication step, as the agent's own user.
///
/// Refused unless `remote_access.full_access` is on. The check is
/// here rather than only in the UI because the UI is not a security boundary:
/// a client can send this frame whether or not a button was rendered for it.
async fn open_local(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    term: String,
    cols: u16,
    rows: u16,
) -> Option<Message> {
    // Re-derived here rather than trusted from the handshake: the panel may
    // have switched it off in between, and this is the request that matters.
    let secure = ctx.secure;
    if !ctx.state.full_access_allowed(secure) {
        Event::new(Kind::Terminal, Action::Denied, Outcome::Denied)
            .subject(&ctx.subject)
            .remote_ip(ctx.remote_ip.clone())
            .detail("full access disabled")
            .record(&ctx.state.db)
            .await;
        return Some(error_frame(
            "full_access_disabled",
            "This agent does not allow opening a terminal without SSH credentials",
        ));
    }

    let (shell, events) = match LocalShell::spawn(&term, cols, rows) {
        Ok(started) => started,
        Err(e) => {
            Event::new(Kind::Terminal, Action::Open, Outcome::Error)
                .subject(&ctx.subject)
                .remote_ip(ctx.remote_ip.clone())
                .detail("spawn failed")
                .record(&ctx.state.db)
                .await;
            tracing::warn!("Could not start a local shell: {e}");
            return Some(error_frame("spawn_failed", &e.to_string()));
        }
    };

    let user = local_user();
    let (session, input_rx) = Session::new(
        &ctx.subject,
        &user,
        ctx.state.remote_access.terminal.scrollback_bytes,
        INPUT_QUEUE,
    );
    let inserted = match ctx.state.sessions.insert(session) {
        Ok(Some(inserted)) => inserted,
        Ok(None) => {
            shell.kill();
            return Some(error_frame(
                "at_capacity",
                "Too many terminal sessions are already open",
            ));
        }
        Err(e) => {
            shell.kill();
            tracing::error!("Could not register terminal session: {e}");
            return Some(error_frame("internal", "Could not start the session"));
        }
    };
    let (handle, session) = inserted;

    let (rx, _replay, _start) = session.attach(0, OUTPUT_QUEUE);
    drive_local_shell(
        shell,
        events,
        session.clone(),
        input_rx,
        ctx.state.sessions.clone(),
        handle.clone(),
    );

    // Before `ready`, for the reason given in `start_shell`
    *phase.borrow_mut() = Phase::Running {
        session,
        handle: handle.clone(),
    };
    let _ = sink
        .send(ServerMsg::Ready { session: &handle, since: 0 }.frame())
        .await;
    pump_output(sink.clone(), rx);

    Event::new(Kind::Terminal, Action::Open, Outcome::Ok)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .ssh_user(&user)
        .detail("full access")
        .record(&ctx.state.db)
        .await;

    None
}

/// The account an SSH-less shell runs as, for the audit log.
fn local_user() -> String {
    std::env::var("USER")
        .or_else(|_| std::env::var("USERNAME"))
        .unwrap_or_else(|_| "unknown".to_string())
}

/// Moves bytes between the session and a local shell.
///
/// The SSH twin is `drive_shell`; both end by removing the session, so a dead
/// shell's handle stops working at once rather than at the next reap.
fn drive_local_shell(
    shell: LocalShell,
    mut events: mpsc::Receiver<ShellEvent>,
    session: Arc<Session>,
    mut input_rx: mpsc::Receiver<SessionInput>,
    sessions: Arc<SessionStore>,
    handle: String,
) {
    spawn(async move {
        loop {
            tokio::select! {
                input = input_rx.recv() => match input {
                    Some(SessionInput::Data(data)) => {
                        if shell.write(&data).is_err() {
                            break;
                        }
                    }
                    Some(SessionInput::Resize { cols, rows }) => shell.resize(cols, rows),
                    Some(SessionInput::Close) | None => break,
                },
                event = events.recv() => match event {
                    Some(ShellEvent::Data(data)) => {
                        session.publish(SessionOutput::Data(data));
                    }
                    Some(ShellEvent::Exit(status)) => {
                        session.publish(SessionOutput::Exit(status));
                        break;
                    }
                    None => break,
                },
            }
        }
        shell.kill();
        sessions.remove(&handle);
    });
}

#[allow(clippy::too_many_arguments)]
async fn open(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    user: String,
    credential: Credential,
    term: String,
    cols: u16,
    rows: u16,
) -> Option<Message> {
    let addr = &ctx.state.remote_access.ssh_addr;
    let mut ssh = match SshSession::connect(ctx.state.db.clone(), addr).await {
        Ok(ssh) => ssh,
        Err(e) => return Some(fail(ctx, &user, &e).await),
    };

    match ssh.authenticate(&user, credential).await {
        Ok(AuthStep::Authenticated) => {
            start_shell(ctx, sink, phase, ssh, user, term, cols, rows).await
        }
        Ok(AuthStep::NeedsAnswers { instructions, prompts }) => {
            let frame = ServerMsg::Prompt {
                instructions: &instructions,
                prompts: &prompts,
            }
            .frame();
            *phase.borrow_mut() = Phase::Authenticating {
                ssh: Box::new(ssh),
                user,
                term,
                cols,
                rows,
            };
            Some(frame)
        }
        Ok(AuthStep::Failed) => Some(fail(ctx, &user, &SshError::AuthFailed).await),
        Err(e) => Some(fail(ctx, &user, &e).await),
    }
}

async fn answer(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    answers: Vec<String>,
) -> Option<Message> {
    // Taken out in its own statement: a `match` keeps the scrutinee's
    // temporary alive for the whole expression, so borrowing again inside an
    // arm to put the phase back would panic.
    let taken = std::mem::replace(&mut *phase.borrow_mut(), Phase::Idle);
    let (mut ssh, user, term, cols, rows) = match taken {
        Phase::Authenticating { ssh, user, term, cols, rows } => (ssh, user, term, cols, rows),
        other => {
            *phase.borrow_mut() = other;
            return Some(error_frame("bad_request", "No prompt is outstanding"));
        }
    };

    match ssh.answer_prompts(answers).await {
        Ok(AuthStep::Authenticated) => {
            start_shell(ctx, sink, phase, *ssh, user, term, cols, rows).await
        }
        Ok(AuthStep::NeedsAnswers { instructions, prompts }) => {
            let frame = ServerMsg::Prompt {
                instructions: &instructions,
                prompts: &prompts,
            }
            .frame();
            *phase.borrow_mut() = Phase::Authenticating { ssh, user, term, cols, rows };
            Some(frame)
        }
        Ok(AuthStep::Failed) => Some(fail(ctx, &user, &SshError::AuthFailed).await),
        Err(e) => Some(fail(ctx, &user, &e).await),
    }
}

#[allow(clippy::too_many_arguments)]
async fn start_shell(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    mut ssh: SshSession,
    user: String,
    term: String,
    cols: u16,
    rows: u16,
) -> Option<Message> {
    let channel = match ssh.open_shell(&term, cols, rows).await {
        Ok(channel) => channel,
        Err(e) => return Some(fail(ctx, &user, &e).await),
    };

    let (session, input_rx) = Session::new(
        &ctx.subject,
        &user,
        ctx.state.remote_access.terminal.scrollback_bytes,
        INPUT_QUEUE,
    );

    let inserted = match ctx.state.sessions.insert(session) {
        Ok(Some(inserted)) => inserted,
        Ok(None) => {
            ssh.disconnect().await;
            return Some(error_frame(
                "at_capacity",
                "Too many terminal sessions are already open",
            ));
        }
        Err(e) => {
            ssh.disconnect().await;
            tracing::error!("Could not register terminal session: {e}");
            return Some(error_frame("internal", "Could not start the session"));
        }
    };
    let (handle, session) = inserted;

    let (rx, _replay, _start) = session.attach(0, OUTPUT_QUEUE);
    drive_shell(
        ssh,
        channel,
        session.clone(),
        input_rx,
        ctx.state.sessions.clone(),
        handle.clone(),
    );

    // The phase is set before `ready` goes out, not after. ntex processes
    // frames concurrently, so a client that types the instant it sees `ready`
    // can have that frame handled while this one is still awaiting the audit
    // write below — and input arriving before the phase moves is dropped.
    *phase.borrow_mut() = Phase::Running {
        session,
        handle: handle.clone(),
    };
    let _ = sink
        .send(ServerMsg::Ready { session: &handle, since: 0 }.frame())
        .await;
    pump_output(sink.clone(), rx);

    Event::new(Kind::Terminal, Action::Open, Outcome::Ok)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .ssh_user(&user)
        .record(&ctx.state.db)
        .await;

    None
}

async fn attach(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    handle: &str,
    since: u64,
    cols: u16,
    rows: u16,
) -> Option<Message> {
    // Live revocation of full_access: a handle minted before DELETE
    // /remote-access/full-access must not be reusable after it.
    if ctx.state.full_access_off.load(std::sync::atomic::Ordering::Acquire) {
        // Local shells are the ones gated by full_access; remote SSH shells
        // remain usable. Without a per-session local flag we deny all
        // re-attaches after the switch, which is the safe side for the
        // reported issue (local shell continuing via handle).
        return Some(error_frame(
            "full_access_disabled",
            "Full access has been disabled",
        ));
    }
    let session = match ctx.state.sessions.get(handle, &ctx.subject) {
        Ok(session) => session,
        Err(reason) => {
            Event::new(Kind::Terminal, Action::Attach, Outcome::Denied)
                .subject(&ctx.subject)
                .remote_ip(ctx.remote_ip.clone())
                .detail(format!("{reason:?}"))
                .record(&ctx.state.db)
                .await;
            // One answer for all three reasons: which one it was would tell
            // someone probing handles how close they got
            return Some(error_frame(
                "session_gone",
                "That terminal session is no longer available",
            ));
        }
    };

    // Installs this connection's sender and reads the replay in one step, so
    // nothing the shell emits can fall between the two and be seen by nobody.
    // Output produced from here on queues in `rx` until the pump starts below,
    // which keeps it behind the replay.
    let (rx, replay, start_seq) = session.attach(since, OUTPUT_QUEUE);

    // `since` in `ready` is the absolute position the byte stream that follows
    // begins at, which the client uses as its counter's new base. For a
    // recoverable gap that is where the client left off; for a truncated one
    // it is wherever the buffer now starts, since everything before that is
    // gone.
    let (payload, resume_at, truncated) = match replay {
        Replay::Gap(data) => (data, since, false),
        Replay::Truncated(data) => {
            let mut out = RESET.to_vec();
            out.extend_from_slice(&data);
            (out, start_seq, true)
        }
    };

    // Before `ready`, for the reason given in `start_shell`
    *phase.borrow_mut() = Phase::Running {
        session: session.clone(),
        handle: handle.to_string(),
    };
    let _ = sink
        .send(ServerMsg::Ready { session: handle, since: resume_at }.frame())
        .await;
    if !payload.is_empty() {
        let _ = sink.send(Message::Binary(Bytes::from(payload))).await;
    }
    if truncated {
        let _ = sink
            .send(
                ServerMsg::Error {
                    code: "gap_truncated",
                    message: "Some output was lost while disconnected",
                }
                .frame(),
            )
            .await;
    }

    // Takes over from any previous connection: after a network drop the old
    // socket often isn't known to be dead yet, and refusing would leave the
    // user locked out until the timeout.
    pump_output(sink.clone(), rx);
    let _ = session.input.send(SessionInput::Resize { cols, rows }).await;

    Event::new(Kind::Terminal, Action::Attach, Outcome::Ok)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .ssh_user(&session.ssh_user)
        .record(&ctx.state.db)
        .await;

    None
}

/// Owns the SSH channel and moves bytes both ways.
///
/// One task with `select!` rather than two, because the read and write halves
/// both belong to one channel and splitting the ownership is what `split()` is
/// for; the loop ends when either side does.
fn drive_shell(
    ssh: SshSession,
    channel: russh::Channel<russh::client::Msg>,
    session: Arc<Session>,
    mut input_rx: mpsc::Receiver<SessionInput>,
    sessions: Arc<SessionStore>,
    handle: String,
) {
    let (mut read, write) = channel.split();
    spawn(async move {
        loop {
            tokio::select! {
                input = input_rx.recv() => match input {
                    Some(SessionInput::Data(data)) => {
                        if write.data_bytes(data).await.is_err() {
                            break;
                        }
                    }
                    Some(SessionInput::Resize { cols, rows }) => {
                        let _ = write.window_change(cols as u32, rows as u32, 0, 0).await;
                    }
                    Some(SessionInput::Close) => break,
                    // Every sender gone: the session was reaped
                    None => break,
                },
                event = next_shell_event(&mut read) => match event {
                    Some(ShellEvent::Data(data)) => {
                        session.publish(SessionOutput::Data(data));
                    }
                    Some(ShellEvent::Exit(status)) => {
                        session.publish(SessionOutput::Exit(status));
                        break;
                    }
                    None => break,
                },
            }
        }
        let _ = write.eof().await;
        ssh.disconnect().await;
        // Once the shell is gone there is nothing to reattach to, so the
        // handle must stop working immediately rather than at the next reap
        sessions.remove(&handle);
    });
}

/// Pumps a session's output into this WebSocket until it is taken over, the
/// shell exits, or the socket dies.
///
/// The receiver comes from [`Session::attach`], which installed the matching
/// sender atomically against `publish`. Starting the pump afterwards is safe:
/// anything produced in between simply queues in `rx`, which is what keeps it
/// behind the replay the caller writes first.
fn pump_output(sink: WsSink, mut rx: mpsc::Receiver<SessionOutput>) {
    spawn(async move {
        // True while the only way out of the loop left is the channel closing,
        // which means something took the session away from this connection.
        let mut superseded = true;
        while let Some(output) = rx.recv().await {
            let sent = match output {
                SessionOutput::Data(data) => sink.send(Message::Binary(Bytes::from(data))).await,
                SessionOutput::Error(message) => {
                    sink.send(
                        ServerMsg::Error {
                            code: "ssh_error",
                            message: &message,
                        }
                        .frame(),
                    )
                    .await
                }
                SessionOutput::Exit(status) => {
                    let _ = sink.send(ServerMsg::Exit { status }.frame()).await;
                    let _ = sink
                        .send(Message::Close(Some(CloseCode::Normal.into())))
                        .await;
                    superseded = false;
                    break;
                }
            };
            if sent.is_err() {
                superseded = false;
                break;
            }
        }

        if superseded {
            // Another connection attached, or the session was reaped. Either
            // way this socket will never see output again, and leaving it open
            // and quiet is the worst option: the heartbeat keeps arriving so
            // it looks healthy, and once that lapsed the client would
            // reconnect and take the session straight back — two duplicated
            // tabs (which share sessionStorage, handle included) would trade
            // it back and forth forever.
            let _ = sink
                .send(
                    ServerMsg::Error {
                        code: "superseded",
                        message: "This terminal was taken over by another connection",
                    }
                    .frame(),
                )
                .await;
            let _ = sink
                .send(Message::Close(Some(CloseCode::Normal.into())))
                .await;
        }
    });
}

/// Tells the client the link is alive, so it can start reconnecting promptly
/// when it stops hearing from us.
fn start_heartbeat(sink: WsSink) {
    spawn(async move {
        loop {
            sleep(HEARTBEAT).await;
            if sink.io().is_closed() || sink.send(ServerMsg::Hb.frame()).await.is_err() {
                break;
            }
        }
    });
}

/// Records a failed attempt and turns it into a frame for the client.
async fn fail(ctx: &Rc<ConnCtx>, user: &str, error: &SshError) -> Message {
    Event::new(Kind::Terminal, Action::Open, Outcome::Denied)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .ssh_user(user)
        .detail(error.code())
        .record(&ctx.state.db)
        .await;
    error_frame(error.code(), &error.message())
}

fn error_frame(code: &str, message: &str) -> Message {
    ServerMsg::Error { code, message }.frame()
}

/// Drops sessions nobody came back for.
///
/// Runs alongside the web server rather than on a timer per session: one task
/// checking a small map is cheaper than a timer per shell, and the exact
/// moment of collection doesn't matter.
pub fn start_reaper(sessions: Arc<SessionStore>, interval: Duration) {
    spawn(async move {
        loop {
            sleep(interval).await;
            let reaped = sessions.reap();
            if reaped > 0 {
                tracing::info!("Closed {reaped} terminal session(s) nobody reattached to");
            }
        }
    });
}

#[cfg(test)]
mod tests {
    /// The ticket parser, which reads a query string by hand on a security
    /// boundary.
    ///
    /// These came with `query_param` from the tunnel endpoint and were lost
    /// when it was deleted; the function was copied and the tests were not.
    /// What they pin is what a hand-rolled parser gets wrong: matching a name
    /// that merely contains the one asked for, and taking a bare key as a
    /// value. Switching `key == name` to `ends_with` passes every other test
    /// in this file.
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

    use super::*;

    fn parse(json: &str) -> ClientMsg {
        serde_json::from_str(json).expect("should parse")
    }

    #[test]
    fn open_defaults_the_terminal_geometry() {
        let ClientMsg::Open { user, cols, rows, term, .. } = parse(
            r#"{"type":"open","user":"ops","auth":{"kind":"password","password":"x"}}"#,
        ) else {
            panic!("expected open");
        };
        assert_eq!(user, "ops");
        assert_eq!((cols, rows), (80, 24));
        assert_eq!(term, "xterm-256color");
    }

    #[test]
    fn every_auth_kind_maps_to_a_credential() {
        for (json, expected) in [
            (r#"{"kind":"password","password":"x"}"#, "password"),
            (r#"{"kind":"key","pem":"-----","passphrase":null}"#, "key"),
            (r#"{"kind":"interactive"}"#, "interactive"),
            // No credential at all — the SSH-less path
            (r#"{"kind":"local"}"#, "local"),
        ] {
            let payload: AuthPayload = serde_json::from_str(json).unwrap();
            let actual = match payload.into_credential() {
                Some(Credential::Password(_)) => "password",
                Some(Credential::Key { .. }) => "key",
                Some(Credential::KeyboardInteractive) => "interactive",
                None => "local",
            };
            assert_eq!(actual, expected);
        }
    }

    #[test]
    fn attach_without_a_position_starts_from_the_beginning() {
        // An old client, or one that lost its counter, must get everything
        // rather than silently skipping to the end
        let ClientMsg::Attach { session, since, .. } =
            parse(r#"{"type":"attach","session":"a.b"}"#)
        else {
            panic!("expected attach");
        };
        assert_eq!(session, "a.b");
        assert_eq!(since, 0);
    }

    #[test]
    fn control_messages_round_trip_their_tags() {
        assert!(matches!(
            parse(r#"{"type":"resize","cols":120,"rows":40}"#),
            ClientMsg::Resize { cols: 120, rows: 40 }
        ));
        assert!(matches!(parse(r#"{"type":"close"}"#), ClientMsg::Close));
        assert!(matches!(
            parse(r#"{"type":"answer","answers":["123456"]}"#),
            ClientMsg::Answer { .. }
        ));
    }

    #[test]
    fn unknown_messages_are_rejected_rather_than_defaulted() {
        assert!(serde_json::from_str::<ClientMsg>(r#"{"type":"exec","cmd":"rm -rf /"}"#).is_err());
        assert!(serde_json::from_str::<ClientMsg>(r#"{"type":"open"}"#).is_err());
    }

    #[test]
    fn server_messages_carry_the_codes_the_panel_branches_on() {
        let ready = ServerMsg::Ready { session: "a.b", since: 42 };
        let json = serde_json::to_string(&ready).unwrap();
        assert!(json.contains(r#""type":"ready""#));
        assert!(json.contains(r#""since":42"#));

        let error = ServerMsg::Error {
            code: "host_key_mismatch",
            message: "changed",
        };
        assert!(
            serde_json::to_string(&error)
                .unwrap()
                .contains(r#""code":"host_key_mismatch""#)
        );

        assert_eq!(
            serde_json::to_string(&ServerMsg::Hb).unwrap(),
            r#"{"type":"hb"}"#
        );
    }

    #[test]
    fn the_reset_is_the_full_terminal_reset() {
        // `ESC c`, not a clear: a truncated replay may start mid escape
        // sequence, and only a full reset reliably absorbs that
        assert_eq!(RESET, b"\x1bc");
    }
}
