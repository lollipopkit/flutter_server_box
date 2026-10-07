/// The browser side of `/api/v1/terminal/ws`.
///
/// Deliberately knows nothing about xterm.js: it owns the connection, the
/// protocol and the reconnect policy, and hands bytes to whatever renderer the
/// page provides. That keeps the part worth testing free of a DOM.
///
/// # Reconnecting
///
/// The agent keeps a session alive after the socket drops, so a phone changing
/// networks rejoins the same shell. Getting that to feel seamless rather than
/// merely possible is what most of this file is about:
///
/// - `rendered` counts bytes actually written to the terminal, and is sent as
///   `since` when reattaching. The agent replays only the gap, so the screen is
///   never cleared for a short outage.
/// - The counter advances in the renderer's write callback and is persisted at
///   most every 250ms. It is therefore allowed to lag, never to lead: a stale
///   value replays a little already-seen output, whereas a value ahead of what
///   was drawn would leave a hole nothing can fill.
/// - Browsers cannot see WebSocket pings, so the agent sends an application
///   heartbeat and a gap in it is what triggers a reconnect.

import { ApiError, api } from './api'
import { agentWsUrl, wsTicketProtocol } from './agentUrl'
import { servers } from './servers.svelte'

/// Missing this many milliseconds of heartbeat means the link is gone. The
/// agent sends one every 15s, so this tolerates a single missed beat.
const HEARTBEAT_TIMEOUT_MS = 35_000

const BACKOFF_MS = [500, 1_000, 2_000, 4_000, 8_000]
/// Up to ±25% of jitter, so several tabs reconnecting after the same outage
/// don't all hit the agent on the same tick.
const JITTER = 0.25

/// How often the resume point may be written to sessionStorage. Persisting on
/// every frame would be a storage write per keystroke of output.
const PERSIST_INTERVAL_MS = 250

const SESSION_KEY = 'terminal.session'

export type Phase =
  | 'idle'
  | 'connecting'
  | 'authenticating'
  /// Waiting on answers to a keyboard-interactive prompt (2FA and friends).
  | 'prompting'
  | 'running'
  | 'reconnecting'
  | 'closed'

export interface Prompt {
  prompt: string
  echo: boolean
}

export type Credential =
  | { kind: 'password'; password: string }
  | { kind: 'key'; pem: string; passphrase?: string }
  | { kind: 'interactive' }
  /// No credentials: the agent runs a shell as its own user. Only accepted
  /// when the agent reports `remote_access.full_access`.
  | { kind: 'local' }

/// Where a local shell runs, when it is not the agent's own login shell.
///
/// Carries no command: the agent builds one from the id, the host and port, or
/// the session. Only sent to an agent that lists the matching feature
/// (`container_exec`, `iperf`, `tmux`) — an older agent ignores the field and
/// would open a host shell instead.
export type TerminalTarget =
  | { kind: 'container'; id: string }
  | { kind: 'iperf'; host: string; port: number }
  /// A tmux session, by its `$` id, attached with tmux's own UI — the app's
  /// control-mode client is not what a browser can render.
  | { kind: 'tmux'; session: string }
  /// A tmux session attached, created when the name does not exist yet.
  | { kind: 'tmux_new'; name: string }

interface ServerMessage {
  type: 'ready' | 'prompt' | 'error' | 'exit' | 'hb'
  session?: string
  since?: number
  instructions?: string
  prompts?: Prompt[]
  code?: string
  message?: string
  /// A stable issue code, for a refusal the client is meant to phrase itself
  /// (`invalid_input` names the code, this names the issue).
  issue?: string
  status?: number | null
}

/// What the page must provide to render a session.
export interface Renderer {
  /// Writes PTY output. `done` must run once the bytes are on screen — the
  /// resume counter advances there, which is what keeps it from leading.
  write(data: Uint8Array, done: () => void): void
  /// Full reset, for the case where the agent had to truncate the replay.
  reset(): void
  readonly cols: number
  readonly rows: number
}

/// Session identity kept for the lifetime of the tab.
///
/// `sessionStorage`, never `localStorage`: the handle is a bearer capability
/// for an authenticated shell, so it must not outlive the tab or be readable
/// by another one.
function loadSession(key: string): { handle: string; rendered: number } | null {
  try {
    const raw = window.sessionStorage.getItem(key)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { handle?: string; rendered?: number }
    if (typeof parsed.handle !== 'string') return null
    // Sent back as `since`, a `u64` on the agent: anything else would make
    // the attach frame invalid, so it resumes from the start instead.
    const rendered =
      Number.isSafeInteger(parsed.rendered) && (parsed.rendered as number) >= 0
        ? (parsed.rendered as number)
        : 0
    return { handle: parsed.handle, rendered }
  } catch {
    return null
  }
}

function saveSession(key: string, handle: string, rendered: number) {
  try {
    window.sessionStorage.setItem(key, JSON.stringify({ handle, rendered }))
  } catch {
    // Private-browsing quota errors only cost the resume-after-reload path
  }
}

function clearSession(key: string) {
  try {
    window.sessionStorage.removeItem(key)
  } catch {
    // Nothing to recover from; the handle simply expires on the agent
  }
}

/// The terminal endpoint as a WebSocket URL — see `agentWsUrl`.
export function terminalWsUrl(base: string): string {
  return agentWsUrl(base, '/api/v1/terminal/ws')
}

export const terminalWsProtocol = wsTicketProtocol

export interface TerminalSessionOptions {
  /// Whether the resume handle is kept in `sessionStorage`. Default `true`:
  /// the terminal page survives a tab reload. A session embedded in a page
  /// that owns its own handle — the container shell dialog — passes `false` so
  /// it never reads, writes or clears the key the terminal page uses. It still
  /// reconnects from the in-memory handle while the dialog is open.
  persist?: boolean
  /// Which stored handle is this session's: one per terminal window, so each
  /// window rejoins its own shell after a reload. Unset: the one key.
  key?: string
}

export class TerminalSession {
  phase = $state<Phase>('idle')
  /// User-facing failure, cleared on the next successful connection.
  error = $state<string | null>(null)
  /// The agent's stable code for the last error, where it sent one — a page
  /// that knows the code can say something better than the agent's sentence.
  errorCode = $state<string | null>(null)
  /// The issue behind [`errorCode`], for a refusal the client phrases itself.
  issueCode = $state<string | null>(null)
  /// Set while the agent is waiting on keyboard-interactive answers.
  prompts = $state<Prompt[]>([])
  instructions = $state('')
  /// Whether output was lost because the outage outlasted the agent's buffer.
  truncated = $state(false)
  /// The status the shell exited with, once it has. `null` while running, and
  /// for a shell killed by a signal (the agent reports no code).
  exitStatus = $state<number | null>(null)

  private socket: WebSocket | null = null
  private renderer: Renderer | null = null
  private credential: Credential | null = null
  private target: TerminalTarget | null = null
  private user = ''
  private handle: string | null = null
  /// Absolute position of the next byte to be rendered. Only ever advanced by
  /// the renderer's completion callback.
  private rendered = 0
  /// Set while an attach asks for the whole buffer on a fresh renderer: a gap
  /// before it is old scrollback, not output lost in an outage.
  private replayAll = false
  private persistedAt = 0
  private attempt = 0
  private reconnectTimer: number | null = null
  private heartbeatTimer: number | null = null
  /// Invalidates socket events and renderer callbacks from older attempts.
  private connectionGeneration = 0
  /// Set by close()/exit so the disconnect handler doesn't try to reconnect.
  private finished = false
  /// Whether `sessionStorage` is this session's to use — see
  /// [`TerminalSessionOptions`].
  private readonly persistent: boolean
  private readonly storageKey: string

  constructor(options: TerminalSessionOptions = {}) {
    this.persistent = options.persist !== false
    this.storageKey = options.key ? `${SESSION_KEY}:${options.key}` : SESSION_KEY
    if (!this.persistent) return
    const saved = loadSession(this.storageKey)
    if (saved) {
      this.handle = saved.handle
      this.rendered = saved.rendered
    }
  }

  /// Writes the handle out, unless this session must not touch the key.
  private saveStored() {
    if (this.persistent && this.handle) saveSession(this.storageKey, this.handle, this.rendered)
  }

  /// Drops the stored handle, unless this session must not touch the key.
  private clearStored() {
    if (this.persistent) clearSession(this.storageKey)
  }

  /// Whether a previous connection left a session worth rejoining.
  get resumable(): boolean {
    return this.handle !== null
  }

  /// Starts a new session, or rejoins the stored one when there is no
  /// credential to open with. [target] narrows a local shell to something on
  /// the machine — a container, iperf, a tmux session — and is sent in the open
  /// frame only.
  ///
  /// A credential is an explicit open, so whatever this tab was attached to is
  /// forgotten: `connect` sends `attach` whenever a handle is stored, and
  /// reusing a dropped shell for a container or a tmux session would show
  /// something other than what was asked for. Passing `null` — Resume — keeps
  /// attaching, and that is the way back to the old session. The agent is not
  /// told to close it: it is not this tab's to end, and it times out.
  async start(
    renderer: Renderer,
    user: string,
    credential: Credential | null,
    target: TerminalTarget | null = null,
  ) {
    // A renderer this session has not drawn on yet (a reload rejoining the
    // stored handle) holds none of what was rendered before, so it asks for
    // the agent's whole buffer rather than only what follows.
    this.replayAll = this.renderer !== renderer && !credential
    if (this.replayAll) this.rendered = 0
    this.renderer = renderer
    this.user = user
    this.credential = credential
    this.target = target
    this.finished = false
    if (credential) {
      this.clearStored()
      this.handle = null
      this.rendered = 0
    }
    await this.connect()
  }

  /// Ends the session for good, as opposed to just dropping the connection.
  close() {
    this.finished = true
    this.send({ type: 'close' })
    this.teardown()
    this.clearStored()
    this.handle = null
    this.rendered = 0
    this.phase = 'closed'
  }

  /// Answers an outstanding keyboard-interactive prompt.
  answer(answers: string[]) {
    this.prompts = []
    this.phase = 'authenticating'
    this.send({ type: 'answer', answers })
  }

  resize(cols: number, rows: number) {
    if (this.phase === 'running') this.send({ type: 'resize', cols, rows })
  }

  input(data: string) {
    if (this.phase !== 'running' || !this.socket) return
    this.socket.send(new TextEncoder().encode(data))
  }

  /// Called from `online` and `visibilitychange`: a user who just came back
  /// should not wait out a backoff timer that was scheduled while the device
  /// was asleep.
  reconnectNow() {
    if (this.phase !== 'reconnecting') return
    this.clearReconnect()
    void this.connect()
  }

  /// Releases timers and the socket. Safe to call more than once.
  dispose() {
    this.finished = true
    this.teardown()
  }

  private async connect() {
    const generation = ++this.connectionGeneration
    const entry = servers.list.find((s) => s.id === servers.currentId)
    if (!entry) {
      this.fail('No server selected')
      return
    }
    this.phase = this.handle ? 'reconnecting' : 'connecting'

    let ticket: string
    try {
      ticket = (await api.issueWsTicket('terminal')).ticket
    } catch (e) {
      if (generation !== this.connectionGeneration || this.finished) return
      // Not being able to reach the agent is the ordinary case here — it is
      // exactly what a dropped link looks like from this side — so it must
      // keep retrying rather than end the session. Only a refused
      // authorisation is final: `request` has already dropped the session on
      // a 401 and App is showing the login screen, so retrying would spin
      // against a dead token. With no session to rejoin there is likewise
      // nothing a retry could recover.
      const refused = e instanceof ApiError && (e.status === 401 || e.status === 429)
      if (refused || !this.handle) {
        this.fail(e instanceof Error ? e.message : 'Could not authorise the terminal')
      } else {
        this.phase = 'reconnecting'
        this.scheduleReconnect()
      }
      return
    }

    if (generation !== this.connectionGeneration || this.finished) return

    const socket = new WebSocket(terminalWsUrl(entry.url), [terminalWsProtocol(ticket)])
    socket.binaryType = 'arraybuffer'
    this.socket = socket

    socket.onopen = () => {
      if (!this.isCurrentConnection(generation, socket)) return
      this.error = null
      this.attempt = 0
      this.armHeartbeat(generation, socket)
      if (this.handle) {
        this.send({
          type: 'attach',
          session: this.handle,
          since: this.rendered,
          cols: this.renderer?.cols ?? 80,
          rows: this.renderer?.rows ?? 24,
        })
      } else if (this.credential) {
        this.phase = 'authenticating'
        this.send({
          type: 'open',
          user: this.user,
          auth: this.credential,
          ...(this.target ? { target: this.target } : {}),
          cols: this.renderer?.cols ?? 80,
          rows: this.renderer?.rows ?? 24,
        })
      } else {
        this.fail('No credentials to open a session with')
      }
    }

    socket.onmessage = (event) => {
      if (!this.isCurrentConnection(generation, socket)) return
      this.armHeartbeat(generation, socket)
      if (typeof event.data === 'string') {
        this.onControl(event.data)
      } else {
        this.onOutput(new Uint8Array(event.data as ArrayBuffer), generation)
      }
    }

    socket.onclose = () => this.onDisconnect(generation, socket)
    socket.onerror = () => this.onDisconnect(generation, socket)
  }

  private onControl(raw: string) {
    let msg: ServerMessage
    try {
      msg = JSON.parse(raw) as ServerMessage
    } catch {
      return
    }

    switch (msg.type) {
      case 'ready':
        if (msg.session) this.handle = msg.session
        // `since` is the absolute position the stream that follows starts at,
        // so the counter is set from it rather than added to — on a truncated
        // replay it moves forward past output nobody will ever see.
        this.rendered = msg.since ?? 0
        this.saveStored()
        this.prompts = []
        this.error = null
        this.errorCode = null
        this.issueCode = null
        this.exitStatus = null
        this.phase = 'running'
        break
      case 'prompt':
        this.instructions = msg.instructions ?? ''
        this.prompts = msg.prompts ?? []
        this.phase = 'prompting'
        break
      case 'error':
        this.onError(msg)
        break
      case 'exit':
        this.finished = true
        this.exitStatus = msg.status ?? null
        this.clearStored()
        this.handle = null
        this.phase = 'closed'
        break
      case 'hb':
        break
    }
  }

  private onError(msg: ServerMessage) {
    this.errorCode = msg.code ?? null
    this.issueCode = msg.issue ?? null
    if (msg.code === 'gap_truncated') {
      // Not a failure: the session is fine, only the scrollback fell behind
      if (!this.replayAll) this.truncated = true
      this.renderer?.reset()
      return
    }
    if (msg.code === 'superseded') {
      // Another connection has the session. Reconnecting would take it
      // straight back, and since a duplicated tab shares this one's
      // sessionStorage — handle included — the two would trade it forever.
      // The handle is kept so rejoining stays an explicit choice.
      this.finished = true
      this.phase = 'closed'
      this.error = msg.message ?? 'Taken over by another connection'
      return
    }
    if (msg.code === 'session_gone') {
      // Nothing left to rejoin. Keep whatever is on screen — it is still the
      // last thing the user saw, and may be worth copying out of.
      this.clearStored()
      this.handle = null
      this.rendered = 0
      this.finished = true
      this.phase = 'closed'
    }
    this.error = msg.message ?? 'Terminal error'
    if (msg.code === 'auth_failed' || msg.code === 'bad_key') {
      // Recoverable by re-entering credentials rather than by reconnecting
      this.credential = null
      this.finished = true
      this.phase = 'idle'
    }
  }

  private onOutput(data: Uint8Array, generation: number) {
    const renderer = this.renderer
    if (!renderer) return
    renderer.write(data, () => {
      if (generation !== this.connectionGeneration || renderer !== this.renderer) return
      this.rendered += data.length
      this.persist()
    })
  }

  /// Throttled so a chatty shell doesn't turn into a storage write per frame.
  /// Lagging is safe; leading is not — see the module comment.
  private persist() {
    if (!this.persistent || !this.handle) return
    const now = Date.now()
    if (now - this.persistedAt < PERSIST_INTERVAL_MS) return
    this.persistedAt = now
    saveSession(this.storageKey, this.handle, this.rendered)
  }

  /// Writes the exact resume point out, ignoring the throttle. For `pagehide`,
  /// where there is no later chance.
  flush() {
    if (this.handle) this.saveStored()
  }

  private onDisconnect(generation: number, socket: WebSocket) {
    if (!this.isCurrentConnection(generation, socket)) return
    // The `gap_truncated` that follows `ready` has come by now; a gap on the
    // reconnect after an outage is lost output again.
    this.replayAll = false
    this.clearHeartbeat()
    this.socket = null
    socket.close()
    if (this.finished) {
      if (this.phase !== 'closed' && this.phase !== 'idle') this.phase = 'closed'
      return
    }
    if (!this.handle) {
      // Never got a session; reconnecting would just repeat the same failure.
      // Said, because a socket refused at the handshake carries no reason and
      // would otherwise read as a session that ended normally.
      if (this.phase === 'connecting' || this.phase === 'authenticating') {
        this.fail(this.error ?? 'The terminal connection closed before a session started')
      } else {
        this.phase = 'closed'
      }
      return
    }
    this.flush()
    this.phase = 'reconnecting'
    this.scheduleReconnect()
  }

  private scheduleReconnect() {
    const base = BACKOFF_MS[Math.min(this.attempt, BACKOFF_MS.length - 1)]
    this.attempt += 1
    const jittered = base * (1 + (Math.random() * 2 - 1) * JITTER)
    this.clearReconnect()
    this.reconnectTimer = window.setTimeout(() => {
      this.reconnectTimer = null
      void this.connect()
    }, jittered)
  }

  /// Restarts the silence timer. Any traffic counts as proof of life, not just
  /// the heartbeat itself.
  private armHeartbeat(generation: number, socket: WebSocket) {
    this.clearHeartbeat()
    this.heartbeatTimer = window.setTimeout(() => {
      if (!this.isCurrentConnection(generation, socket)) return
      this.heartbeatTimer = null
      // The socket may still look open to us while the link is long gone;
      // closing it ourselves is what starts the reconnect.
      socket.close()
    }, HEARTBEAT_TIMEOUT_MS)
  }

  private isCurrentConnection(generation: number, socket: WebSocket): boolean {
    return generation === this.connectionGeneration && socket === this.socket
  }

  private clearHeartbeat() {
    if (this.heartbeatTimer !== null) {
      window.clearTimeout(this.heartbeatTimer)
      this.heartbeatTimer = null
    }
  }

  private clearReconnect() {
    if (this.reconnectTimer !== null) {
      window.clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
  }

  private teardown() {
    this.connectionGeneration += 1
    this.clearReconnect()
    this.clearHeartbeat()
    const socket = this.socket
    this.socket = null
    socket?.close()
  }

  private fail(message: string) {
    this.error = message
    this.finished = true
    this.phase = 'closed'
    this.teardown()
  }

  private send(payload: unknown) {
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(payload))
    }
  }
}
