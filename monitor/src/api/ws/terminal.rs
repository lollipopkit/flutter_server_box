//! `GET /api/v1/terminal/ws` — the terminal.
//!
//! A session is a shell the agent starts itself, as its own user, for an
//! account that holds `shell`; no sshd is involved.
//!
//! # Wire format
//!
//! Frame type is the channel selector, so there is no framing header to get
//! wrong:
//!
//! - **Binary** — PTY bytes, both directions.
//! - **Text** — control JSON, see [`ClientMsg`] and [`ServerMsg`].
//!
//! # Where the shell runs
//!
//! `auth: {"kind":"local"}` starts one as the agent's own user. It is the only
//! kind: the SSH credentials this endpoint once took are refused by parsing,
//! so a client that sends one is told rather than handed a shell as a
//! different user than the one it named. An optional `target` narrows it: a
//! shell inside a container (`sbm_parser::container`), by the id its listing
//! gave it; an iperf client (`sbm_parser::iperf`), by the host and port a user
//! typed; or a tmux session (`sbm_parser::tmux`), by its `$` id or by a new
//! session's name, attached with tmux's own UI since the panel's xterm.js
//! cannot decode control mode the way the app's client does. All build their
//! command here, and no frame can carry one. Whether an agent understands a
//! target is `container_exec`, `iperf` or `tmux` in `/capabilities`; an older
//! agent would ignore the field and open a host shell, so the panel sends one
//! only where it is listed.
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
use ntex::web::ws::{self, CloseCode, Frame, Message};

use super::upgrade::WsSink;
use ntex::web::{self, HttpRequest, HttpResponse};
use ntex::ws::Item;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

use super::audit::{self, Action, Event, Kind, Outcome};
use super::session::{
    AttachmentId, Replay, Session, SessionInput, SessionOutput, SessionStore,
};
use super::ticket::Purpose;
use crate::api::authz;
use crate::api::server::AppState;
use crate::core::permissions::Grant;
use crate::pty::{LocalShell, ShellEvent};

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
const TICKET_PROTOCOL_PREFIX: &str = "sbm-ticket.";

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ClientMsg {
    /// Start a new session.
    ///
    /// A `user` field, which clients sent while there were SSH logins, is
    /// ignored like any other unknown field.
    Open {
        auth: AuthPayload,
        /// Where the shell runs. Absent is the login shell this endpoint has
        /// always started.
        #[serde(default)]
        target: Option<TerminalTarget>,
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
    Resize {
        cols: u16,
        rows: u16,
    },
    /// End the session now, as opposed to just dropping the connection.
    Close,
}

/// Where a local shell runs, when it is not the agent's own login shell.
///
/// No variant carries a command: the command is built here from the id, the
/// host and port, or the session, so a client can name what to open but never a
/// command line. An unknown `kind` fails to parse and is refused — an agent that
/// silently fell back to a host shell would leave the user believing they are
/// inside a container. `deny_unknown_fields` closes the same hole for an extra
/// field.
#[derive(Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
enum TerminalTarget {
    /// A shell inside a container, by the id its listing gave it.
    Container { id: String },
    /// An iperf client run on this machine, against `host:port`.
    ///
    /// The port is a `u32` rather than the `u16` the command takes, so a value
    /// out of range is refused by `sbm_parser::iperf` — with a code the panel
    /// phrases — instead of failing to deserialize into a generic bad request.
    Iperf { host: String, port: u32 },
    /// A tmux session, by its `$` id, attached with tmux's own UI.
    ///
    /// The panel's xterm.js cannot decode control mode, so this is the plain
    /// client where the app's attach commands use `-CC`.
    Tmux { session: String },
    /// A tmux session attached, created when the name does not exist yet.
    TmuxNew { name: String },
}

/// How the shell is opened. One kind, kept as a field so that a frame naming
/// any other (`password`, `key`, `interactive`, from the SSH logins this
/// endpoint no longer offers) fails to parse and is refused.
#[derive(Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
enum AuthPayload {
    /// A shell as the agent's own user; needs `shell`. A struct variant so
    /// that `deny_unknown_fields` applies to it (serde skips it for a unit
    /// variant of an internally tagged enum).
    Local {},
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
    Ready {
        session: &'a str,
        since: u64,
    },
    Error {
        code: &'a str,
        message: &'a str,
        /// A stable issue code, where the panel phrases the refusal in the
        /// viewer's language rather than showing the message. Absent for
        /// every other error.
        #[serde(skip_serializing_if = "Option::is_none")]
        issue: Option<&'a str>,
    },
    Exit {
        status: Option<u32>,
    },
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
    let Ok(reservation) = app_state.tickets.reserve(raw_ticket, Purpose::Terminal) else {
        return deny("ticket", HttpResponse::Unauthorized().finish()).await;
    };
    let subject = reservation.subject().to_string();
    let tickets = app_state.tickets.clone();

    // Checked here as well as at the ticket, so the answer cannot be stale by
    // the time the socket opens: the account's role may have changed in
    // between. Checked again when a frame asks for a shell.
    let admitted = authz::caller_named(&app_state, &subject)
        .await
        .filter(|caller| caller.check(Grant::Shell, &app_state, secure).is_ok());
    let Some(admitted) = admitted else {
        tickets.rollback(reservation);
        return deny("not granted", HttpResponse::Forbidden().finish()).await;
    };

    let ctx = Rc::new(ConnCtx {
        state: app_state,
        subject,
        remote_ip,
        secure,
        since: admitted.since,
    });

    let upgraded = super::upgrade::start::<_, _, web::Error>(
        req,
        Some(&protocol),
        fn_factory_with_config(move |sink: WsSink| {
            let ctx = ctx.clone();
            async move {
                start_heartbeat(sink.clone());
                Ok::<_, web::Error>(handler(ctx, sink))
            }
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

/// Everything about the connection that outlives a single frame.
struct ConnCtx {
    state: Arc<AppState>,
    /// Panel account, from the ticket. Sessions are bound to it.
    subject: String,
    remote_ip: Option<String>,
    /// Whether this connection arrived over a link that can't be read off the
    /// network. Captured at the handshake, where the peer address is known.
    secure: bool,
    /// The account's password as of the upgrade (`Caller::since`): a socket
    /// that outlived a password change opens nothing more under it.
    since: i64,
}

impl ConnCtx {
    /// Whether this connection's account may use [grant] now: its role read
    /// again, not trusted from the handshake — an admin may have changed it
    /// since.
    async fn may(&self, grant: Grant) -> Result<(), &'static str> {
        match authz::caller_named(&self.state, &self.subject)
            .await
            .filter(|caller| caller.since == self.since)
        {
            Some(caller) => caller
                .check(grant, &self.state, self.secure)
                .map_err(|why| why.as_str()),
            None => Err("not_granted"),
        }
    }
}

/// What a client is told when the frame it sent needs a grant its account
/// does not have.
fn not_permitted(grant: Grant, why: &str) -> Message {
    error_frame(
        "forbidden",
        &format!("This account may not use {} here ({why})", grant.as_str()),
    )
}

/// Where this connection is in the open/authenticate/run sequence.
enum Phase {
    /// Nothing has been claimed yet.
    Idle,
    /// An async open or attach owns the connection.
    Opening,
    Running {
        session: Arc<Session>,
        attachment: AttachmentId,
        /// Needed to drop the session from the store on an explicit close;
        /// the session itself doesn't know its own handle.
        handle: String,
    },
    /// Terminal state; further frames are ignored rather than acted on.
    Done,
}

fn claim_idle(phase: &Rc<RefCell<Phase>>) -> bool {
    let previous = std::mem::replace(&mut *phase.borrow_mut(), Phase::Opening);
    if matches!(previous, Phase::Idle) {
        true
    } else {
        *phase.borrow_mut() = previous;
        false
    }
}

fn reset_opening(phase: &Rc<RefCell<Phase>>) {
    let mut phase = phase.borrow_mut();
    if matches!(*phase, Phase::Opening) {
        *phase = Phase::Idle;
    }
}

fn set_if_opening(phase: &Rc<RefCell<Phase>>, next: Phase) -> bool {
    let mut phase = phase.borrow_mut();
    if !matches!(*phase, Phase::Opening) {
        return false;
    }
    *phase = next;
    true
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
            if let Phase::Running {
                session,
                attachment,
                ..
            } = &*phase.borrow()
            {
                session.detach(*attachment);
            }
            *phase.borrow_mut() = Phase::Done;
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
                Frame::Continuation(
                    Item::FirstBinary(data) | Item::Continue(data) | Item::Last(data),
                ) => {
                    on_input(&phase, data.to_vec()).await;
                    Ok(None)
                }
                Frame::Ping(payload) => Ok(Some(Message::Pong(payload))),
                Frame::Pong(_) => Ok(None),
                Frame::Close(_) => {
                    // A closing socket detaches; the session lives on for the
                    // configured grace period so a reconnect can pick it up
                    if let Phase::Running {
                        session,
                        attachment,
                        ..
                    } = &*phase.borrow()
                    {
                        session.detach(*attachment);
                    }
                    *phase.borrow_mut() = Phase::Done;
                    Ok(Some(Message::Close(Some(CloseCode::Normal.into()))))
                }
                Frame::Continuation(Item::FirstText(_)) => {
                    Ok(Some(Message::Close(Some(CloseCode::Unsupported.into()))))
                }
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
        ClientMsg::Open {
            auth: AuthPayload::Local {},
            target,
            cols,
            rows,
            term,
        } => {
            if !claim_idle(phase) {
                return Some(error_frame("bad_request", "Session already started"));
            }
            open_local(ctx, sink, phase, target, term, cols, rows).await
        }
        ClientMsg::Attach {
            session,
            since,
            cols,
            rows,
        } => {
            if !claim_idle(phase) {
                return Some(error_frame("bad_request", "Session already started"));
            }
            attach(ctx, sink, phase, &session, since, cols, rows).await
        }
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
                Phase::Running {
                    session, handle, ..
                } => Some((session.clone(), handle.clone())),
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
/// Refused unless the account holds `shell`. The check is
/// here rather than only in the UI because the UI is not a security boundary:
/// a client can send this frame whether or not a button was rendered for it.
///
/// A [target] narrows what that shell runs: a container's id, from which the
/// command is built here (`sbm_parser::container::shell_command`). The id is
/// validated with the same rules the container page's actions use, and the
/// runtime is detected with the same probe the page runs, so a machine with no
/// runtime answers `no_container_runtime` rather than starting a host shell.
async fn open_local(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    target: Option<TerminalTarget>,
    term: String,
    cols: u16,
    rows: u16,
) -> Option<Message> {
    // Re-derived here rather than trusted from the handshake: the account's
    // role may have changed in between, and this is the request that matters.
    if let Err(why) = ctx.may(Grant::Shell).await {
        Event::new(Kind::Terminal, Action::Denied, Outcome::Denied)
            .subject(&ctx.subject)
            .remote_ip(ctx.remote_ip.clone())
            .detail(format!("shell: {why}"))
            .record(&ctx.state.db)
            .await;
        reset_opening(phase);
        return Some(not_permitted(Grant::Shell, why));
    }

    // What the audit row calls this session, and what the target contributes
    // to it. Never the command line.
    let detail = match &target {
        None => "shell".to_owned(),
        Some(TerminalTarget::Container { id }) => format!("container {id}"),
        Some(TerminalTarget::Iperf { host, port }) => format!("iperf {host}:{port}"),
        Some(TerminalTarget::Tmux { session }) => format!("tmux {session}"),
        Some(TerminalTarget::TmuxNew { name }) => format!("tmux new {name}"),
    };

    let started = match target {
        None => LocalShell::spawn(&term, cols, rows),
        Some(TerminalTarget::Container { id }) => {
            if let Err(issue) = sbm_parser::container::validate_identifier(&id) {
                Event::new(Kind::Terminal, Action::Denied, Outcome::Denied)
                    .subject(&ctx.subject)
                    .remote_ip(ctx.remote_ip.clone())
                    .detail(format!("container: {}", issue.code()))
                    .record(&ctx.state.db)
                    .await;
                reset_opening(phase);
                return Some(error_frame("bad_request", &issue.to_string()));
            }
            match crate::api::containers::detect_runtime(&ctx.state.remote_access.exec).await {
                Some(runtime) => LocalShell::spawn_command(
                    &term,
                    cols,
                    rows,
                    &sbm_parser::container::shell_command(runtime, &id),
                ),
                None => {
                    Event::new(Kind::Terminal, Action::Open, Outcome::Error)
                        .subject(&ctx.subject)
                        .remote_ip(ctx.remote_ip.clone())
                        .detail("container: no runtime")
                        .record(&ctx.state.db)
                        .await;
                    reset_opening(phase);
                    return Some(error_frame(
                        "no_container_runtime",
                        "This machine has no container runtime to run a shell in",
                    ));
                }
            }
        }
        Some(TerminalTarget::Iperf { host, port }) => {
            // The port first, then the host: `client_command` takes the `u16`
            // `valid_port` answers with, and validates the host again itself.
            let command = sbm_parser::iperf::valid_port(&port.to_string())
                .ok_or(sbm_parser::iperf::IperfError::InvalidPort)
                .and_then(|port| sbm_parser::iperf::client_command(&host, port));
            match command {
                Ok(command) => LocalShell::spawn_command(&term, cols, rows, &command),
                Err(issue) => {
                    Event::new(Kind::Terminal, Action::Denied, Outcome::Denied)
                        .subject(&ctx.subject)
                        .remote_ip(ctx.remote_ip.clone())
                        .detail(format!("iperf: {}", issue.code()))
                        .record(&ctx.state.db)
                        .await;
                    reset_opening(phase);
                    // The panel phrases the issue itself; `invalid_input` is
                    // the code that tells it to.
                    return Some(error_frame_issue(
                        "invalid_input",
                        &issue.to_string(),
                        issue.code(),
                    ));
                }
            }
        }
        Some(TerminalTarget::Tmux { session }) => {
            // The id is checked before tmux is looked for, so a malformed one
            // is refused as itself rather than as "tmux is not installed".
            if let Err(issue) = sbm_parser::tmux::validate_session_id(&session) {
                return tmux_refused(ctx, phase, "tmux", issue).await;
            }
            match find_tmux(&ctx.state.remote_access.exec).await {
                Some(bin) => LocalShell::spawn_command(
                    &term,
                    cols,
                    rows,
                    &sbm_parser::tmux::attach_session_plain_command(&bin, &session),
                ),
                None => return no_tmux(ctx, phase).await,
            }
        }
        Some(TerminalTarget::TmuxNew { name }) => {
            // The trimmed value is what reaches the command, so the check and
            // the command cannot disagree about what the name is.
            let name = match sbm_parser::tmux::normalize_session_name(&name) {
                Ok(name) => name,
                Err(issue) => return tmux_refused(ctx, phase, "tmux new", issue).await,
            };
            match find_tmux(&ctx.state.remote_access.exec).await {
                Some(bin) => LocalShell::spawn_command(
                    &term,
                    cols,
                    rows,
                    &sbm_parser::tmux::new_session_plain_command(&bin, &name),
                ),
                None => return no_tmux(ctx, phase).await,
            }
        }
    };

    let (shell, events) = match started {
        Ok(started) => started,
        Err(e) => {
            Event::new(Kind::Terminal, Action::Open, Outcome::Error)
                .subject(&ctx.subject)
                .remote_ip(ctx.remote_ip.clone())
                .detail(format!("{detail}: spawn failed"))
                .record(&ctx.state.db)
                .await;
            reset_opening(phase);
            tracing::warn!("Could not start a local shell: {e}");
            return Some(error_frame("spawn_failed", &e.to_string()));
        }
    };

    let user = local_user();
    let (mut session, input_rx) = Session::new(
        &ctx.subject,
        &user,
        ctx.state.remote_access.terminal.scrollback_bytes,
        INPUT_QUEUE,
    );
    session.since = ctx.since;
    let inserted = match ctx.state.sessions.insert(session) {
        Ok(Some(inserted)) => inserted,
        Ok(None) => {
            shell.kill();
            reset_opening(phase);
            return Some(error_frame(
                "at_capacity",
                "Too many terminal sessions are already open",
            ));
        }
        Err(e) => {
            shell.kill();
            reset_opening(phase);
            tracing::error!("Could not register terminal session: {e}");
            return Some(error_frame("internal", "Could not start the session"));
        }
    };
    let (handle, session) = inserted;

    // A role change can race the spawn above on another worker. Once
    // registered, either this recheck rejects it or the revocation sweep sees
    // it.
    if let Err(why) = ctx.may(Grant::Shell).await {
        ctx.state.sessions.remove(&handle);
        shell.kill();
        reset_opening(phase);
        return Some(not_permitted(Grant::Shell, why));
    }
    let Some((attachment, rx, _replay, _start)) = session.attach(0, OUTPUT_QUEUE) else {
        ctx.state.sessions.remove(&handle);
        shell.kill();
        reset_opening(phase);
        return Some(error_frame(
            "permission_revoked",
            "This account's permissions changed",
        ));
    };
    drive_local_shell(
        shell,
        events,
        session.clone(),
        input_rx,
        ctx.state.sessions.clone(),
        handle.clone(),
    );

    // The phase is set before `ready` goes out, not after. ntex processes
    // frames concurrently, so a client that types the instant it sees `ready`
    // can have that frame handled while this one is still awaiting the audit
    // write below — and input arriving before the phase moves is dropped.
    if !set_if_opening(
        phase,
        Phase::Running {
            session: session.clone(),
            attachment,
            handle: handle.clone(),
        },
    ) {
        let _ = session.input.send(SessionInput::Close).await;
        ctx.state.sessions.remove(&handle);
        return None;
    }
    let _ = sink
        .send(
            ServerMsg::Ready {
                session: &handle,
                since: 0,
            }
            .frame(),
        )
        .await;
    pump_output(sink.clone(), rx);

    Event::new(Kind::Terminal, Action::Open, Outcome::Ok)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .ssh_user(&user)
        .detail(&detail)
        .record(&ctx.state.db)
        .await;

    None
}

/// Locates tmux as `/api/v1/tmux` does, through the agent's own command. Never
/// from the client: a binary path in a frame would be a way to run something
/// else.
async fn find_tmux(exec: &crate::api::exec::Limits) -> Option<String> {
    let out = crate::api::exec::run(sbm_parser::tmux::FIND_COMMAND, None, None, exec)
        .await
        .ok()?;
    sbm_parser::tmux::parse_find(&out.stdout, out.exit_code == Some(0))
}

/// Records a refused tmux value and answers with the code the panel phrases.
/// Runs nothing.
async fn tmux_refused(
    ctx: &Rc<ConnCtx>,
    phase: &Rc<RefCell<Phase>>,
    what: &str,
    issue: sbm_parser::tmux::TmuxError,
) -> Option<Message> {
    Event::new(Kind::Terminal, Action::Denied, Outcome::Denied)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .detail(format!("{what}: {}", issue.code()))
        .record(&ctx.state.db)
        .await;
    reset_opening(phase);
    Some(error_frame_issue(
        "invalid_input",
        &issue.to_string(),
        issue.code(),
    ))
}

/// tmux is not installed on the machine, which is its own code rather than a
/// generic failure: the remedy is on the machine, not in the panel.
async fn no_tmux(ctx: &Rc<ConnCtx>, phase: &Rc<RefCell<Phase>>) -> Option<Message> {
    Event::new(Kind::Terminal, Action::Open, Outcome::Error)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .detail("tmux: not installed")
        .record(&ctx.state.db)
        .await;
    reset_opening(phase);
    Some(error_frame(
        "no_tmux",
        "This machine has no tmux to attach to",
    ))
}

/// The account an SSH-less shell runs as, for the audit log.
fn local_user() -> String {
    std::env::var("USER")
        .or_else(|_| std::env::var("USERNAME"))
        .unwrap_or_else(|_| "unknown".to_string())
}

/// Moves bytes between the session and a local shell.
///
/// Ends by removing the session, so a dead shell's handle stops working at
/// once rather than at the next reap.
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

async fn attach(
    ctx: &Rc<ConnCtx>,
    sink: &WsSink,
    phase: &Rc<RefCell<Phase>>,
    handle: &str,
    since: u64,
    cols: u16,
    rows: u16,
) -> Option<Message> {
    let session = match ctx.state.sessions.get(handle, &ctx.subject) {
        Ok(session) => session,
        Err(reason) => {
            Event::new(Kind::Terminal, Action::Attach, Outcome::Denied)
                .subject(&ctx.subject)
                .remote_ip(ctx.remote_ip.clone())
                .detail(format!("{reason:?}"))
                .record(&ctx.state.db)
                .await;
            reset_opening(phase);
            // One answer for all three reasons: which one it was would tell
            // someone probing handles how close they got
            return Some(error_frame(
                "session_gone",
                "That terminal session is no longer available",
            ));
        }
    };
    // The session was opened under `shell`; rejoining it needs it still, or
    // taking it away would only end the sessions nobody rejoined.
    if let Err(why) = ctx.may(Grant::Shell).await {
        reset_opening(phase);
        return Some(not_permitted(Grant::Shell, why));
    }

    // Installs this connection's sender and reads the replay in one step, so
    // nothing the shell emits can fall between the two and be seen by nobody.
    // Output produced from here on queues in `rx` until the pump starts below,
    // which keeps it behind the replay.
    let Some((attachment, rx, replay, start_seq)) = session.attach(since, OUTPUT_QUEUE) else {
        reset_opening(phase);
        return Some(error_frame(
            "session_gone",
            "That terminal session is no longer available",
        ));
    };

    // `since` in `ready` is the absolute position the byte stream that follows
    // begins at, which the client uses as its counter's new base. For a
    // recoverable gap that is where the client left off; for a truncated one
    // it is wherever the buffer now starts, since everything before that is
    // gone.
    let (payload, resume_at, truncated) = match replay {
        Replay::Gap(data) => (data, since, false),
        Replay::Truncated(data) => (data, start_seq, true),
    };

    // Before `ready`, for the reason given in `open_local`
    if !set_if_opening(
        phase,
        Phase::Running {
            session: session.clone(),
            attachment,
            handle: handle.to_string(),
        },
    ) {
        session.detach(attachment);
        return None;
    }
    let _ = sink
        .send(
            ServerMsg::Ready {
                session: handle,
                since: resume_at,
            }
            .frame(),
        )
        .await;
    if truncated {
        let _ = sink
            .send(error_frame(
                "gap_truncated",
                "Some output was lost while disconnected",
            ))
            .await;
    }
    if !payload.is_empty() {
        let _ = sink.send(Message::Binary(Bytes::from(payload))).await;
    }

    // Takes over from any previous connection: after a network drop the old
    // socket often isn't known to be dead yet, and refusing would leave the
    // user locked out until the timeout.
    pump_output(sink.clone(), rx);
    let _ = session
        .input
        .send(SessionInput::Resize { cols, rows })
        .await;

    Event::new(Kind::Terminal, Action::Attach, Outcome::Ok)
        .subject(&ctx.subject)
        .remote_ip(ctx.remote_ip.clone())
        .ssh_user(&session.user)
        .record(&ctx.state.db)
        .await;

    None
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
                    sink.send(error_frame("ssh_error", &message)).await
                }
                SessionOutput::Exit(status) => {
                    let _ = sink.send(ServerMsg::Exit { status }.frame()).await;
                    let _ = sink
                        .send(Message::Close(Some(CloseCode::Normal.into())))
                        .await;
                    superseded = false;
                    break;
                }
                SessionOutput::Revoked(code) => {
                    let _ = sink
                        .send(error_frame(
                            code,
                            "This account may no longer use this terminal",
                        ))
                        .await;
                    let _ = sink
                        .send(Message::Close(Some(CloseCode::Normal.into())))
                        .await;
                    superseded = false;
                    break;
                }
                SessionOutput::ReplayRequired => {
                    let _ = sink
                        .send(error_frame(
                            "output_lagged",
                            "Terminal output fell behind; reconnecting to replay it",
                        ))
                        .await;
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
                .send(error_frame(
                    "superseded",
                    "This terminal was taken over by another connection",
                ))
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

fn error_frame(code: &str, message: &str) -> Message {
    ServerMsg::Error {
        code,
        message,
        issue: None,
    }
    .frame()
}

/// A refusal a client is expected to phrase itself: the message is a fallback,
/// the issue is the code the panel translates.
fn error_frame_issue(code: &str, message: &str, issue: &str) -> Message {
    ServerMsg::Error {
        code,
        message,
        issue: Some(issue),
    }
    .frame()
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
    use super::*;

    fn parse(json: &str) -> ClientMsg {
        serde_json::from_str(json).expect("should parse")
    }

    #[test]
    fn open_defaults_the_terminal_geometry() {
        // `user` is what clients sent while there were SSH logins: ignored.
        let ClientMsg::Open {
            cols, rows, term, ..
        } = parse(r#"{"type":"open","user":"","auth":{"kind":"local"}}"#)
        else {
            panic!("expected open");
        };
        assert_eq!((cols, rows), (80, 24));
        assert_eq!(term, "xterm-256color");
    }

    #[test]
    fn an_ssh_credential_is_refused_rather_than_opened_as_the_agent() {
        // A client asking for a shell as an SSH account must not be handed one
        // as the agent's user instead.
        for auth in [
            r#"{"kind":"password","password":"x"}"#,
            r#"{"kind":"key","pem":"-----","passphrase":null}"#,
            r#"{"kind":"interactive"}"#,
            r#"{"kind":"local","password":"x"}"#,
        ] {
            let frame = format!(r#"{{"type":"open","user":"ops","auth":{auth}}}"#);
            assert!(serde_json::from_str::<ClientMsg>(&frame).is_err(), "{auth}");
        }
        // As is the answer to a keyboard-interactive prompt.
        assert!(
            serde_json::from_str::<ClientMsg>(r#"{"type":"answer","answers":["123456"]}"#)
                .is_err()
        );
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
            ClientMsg::Resize {
                cols: 120,
                rows: 40
            }
        ));
        assert!(matches!(parse(r#"{"type":"close"}"#), ClientMsg::Close));
    }

    #[test]
    fn unknown_messages_are_rejected_rather_than_defaulted() {
        assert!(serde_json::from_str::<ClientMsg>(r#"{"type":"exec","cmd":"rm -rf /"}"#).is_err());
        assert!(serde_json::from_str::<ClientMsg>(r#"{"type":"open"}"#).is_err());
    }

    #[test]
    fn an_open_target_names_a_container_and_nothing_else() {
        let ClientMsg::Open { target, .. } = parse(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"container","id":"abc"}}"#,
        ) else {
            panic!("expected open");
        };
        assert!(matches!(
            target,
            Some(TerminalTarget::Container { id }) if id == "abc"
        ));

        // An open with no target is the login shell, unchanged.
        let ClientMsg::Open { target, .. } = parse(r#"{"type":"open","auth":{"kind":"local"}}"#)
        else {
            panic!("expected open");
        };
        assert!(target.is_none());

        // An unknown kind is refused rather than ignored: falling back to a
        // host shell would leave the user thinking they are in a container.
        assert!(serde_json::from_str::<ClientMsg>(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"vm","id":"abc"}}"#
        )
        .is_err());
        // And a target carries no command: an extra field is refused too.
        assert!(serde_json::from_str::<ClientMsg>(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"container","id":"abc","cmd":"rm -rf /"}}"#
        )
        .is_err());
    }

    #[test]
    fn an_open_target_can_name_an_iperf_host() {
        let ClientMsg::Open { target, .. } = parse(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"iperf","host":"example.com","port":5201}}"#,
        ) else {
            panic!("expected open");
        };
        assert!(matches!(
            target,
            Some(TerminalTarget::Iperf { host, port }) if host == "example.com" && port == 5201
        ));

        // The same rule as the container variant: no free-form command.
        assert!(serde_json::from_str::<ClientMsg>(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"iperf","host":"example.com","port":5201,"cmd":"rm -rf /"}}"#
        )
        .is_err());
        // A port the `u32` cannot hold fails to parse rather than reaching the
        // command builder.
        assert!(serde_json::from_str::<ClientMsg>(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"iperf","host":"example.com","port":-1}}"#
        )
        .is_err());
    }

    #[test]
    fn an_open_target_can_name_a_tmux_session() {
        let ClientMsg::Open { target, .. } = parse(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"tmux","session":"$3"}}"#,
        ) else {
            panic!("expected open");
        };
        assert!(matches!(target, Some(TerminalTarget::Tmux { session }) if session == "$3"));

        // A new session is its own kind, since `-A` attaches to an existing
        // one rather than failing.
        let ClientMsg::Open { target, .. } = parse(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"tmux_new","name":"work"}}"#,
        ) else {
            panic!("expected open");
        };
        assert!(matches!(target, Some(TerminalTarget::TmuxNew { name }) if name == "work"));

        // The same rule as the other targets: no free-form command.
        assert!(serde_json::from_str::<ClientMsg>(
            r#"{"type":"open","user":"","auth":{"kind":"local"},"target":{"kind":"tmux","session":"$3","cmd":"rm -rf /"}}"#
        )
        .is_err());
    }

    #[test]
    fn server_messages_carry_the_codes_the_panel_branches_on() {
        let ready = ServerMsg::Ready {
            session: "a.b",
            since: 42,
        };
        let json = serde_json::to_string(&ready).unwrap();
        assert!(json.contains(r#""type":"ready""#));
        assert!(json.contains(r#""since":42"#));

        let error = ServerMsg::Error {
            code: "no_tmux",
            message: "missing",
            issue: None,
        };
        assert!(
            serde_json::to_string(&error)
                .unwrap()
                .contains(r#""code":"no_tmux""#)
        );

        assert_eq!(
            serde_json::to_string(&ServerMsg::Hb).unwrap(),
            r#"{"type":"hb"}"#
        );
    }
}
