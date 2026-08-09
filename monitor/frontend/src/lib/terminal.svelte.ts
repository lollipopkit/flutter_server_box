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

import { api } from './api'
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
  /// when the agent reports `remote_access.passwordless`.
  | { kind: 'local' }

interface ServerMessage {
  type: 'ready' | 'prompt' | 'error' | 'exit' | 'hb'
  session?: string
  since?: number
  instructions?: string
  prompts?: Prompt[]
  code?: string
  message?: string
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
function loadSession(): { handle: string; rendered: number } | null {
  try {
    const raw = window.sessionStorage.getItem(SESSION_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { handle?: string; rendered?: number }
    if (typeof parsed.handle !== 'string') return null
    return { handle: parsed.handle, rendered: parsed.rendered ?? 0 }
  } catch {
    return null
  }
}

function saveSession(handle: string, rendered: number) {
  try {
    window.sessionStorage.setItem(SESSION_KEY, JSON.stringify({ handle, rendered }))
  } catch {
    // Private-browsing quota errors only cost the resume-after-reload path
  }
}

function clearSession() {
  try {
    window.sessionStorage.removeItem(SESSION_KEY)
  } catch {
    // Nothing to recover from; the handle simply expires on the agent
  }
}

/// Turns the agent's base URL into the WebSocket URL for the terminal.
///
/// Built by string surgery rather than through `URL`, which would read a bare
/// `agent.example.com:3770` as the scheme `agent.example.com:`. An entry
/// without a scheme inherits the page's, so a panel served over HTTPS never
/// silently downgrades its terminal to `ws:`.
///
/// Exported for its own test: getting the scheme wrong on a same-origin panel
/// is the kind of thing that only shows up in production.
export function terminalWsUrl(base: string, ticket: string): string {
  const origin = (base || window.location.origin).trim().replace(/\/+$/, '')
  const ws = /^https?:\/\//i.test(origin)
    ? origin.replace(/^http/i, 'ws')
    : `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${origin}`
  return `${ws}/api/v1/terminal/ws?ticket=${encodeURIComponent(ticket)}`
}

export class TerminalSession {
  phase = $state<Phase>('idle')
  /// User-facing failure, cleared on the next successful connection.
  error = $state<string | null>(null)
  /// Set while the agent is waiting on keyboard-interactive answers.
  prompts = $state<Prompt[]>([])
  instructions = $state('')
  /// Whether output was lost because the outage outlasted the agent's buffer.
  truncated = $state(false)

  private socket: WebSocket | null = null
  private renderer: Renderer | null = null
  private credential: Credential | null = null
  private user = ''
  private handle: string | null = null
  /// Absolute position of the next byte to be rendered. Only ever advanced by
  /// the renderer's completion callback.
  private rendered = 0
  private persistedAt = 0
  private attempt = 0
  private reconnectTimer: number | null = null
  private heartbeatTimer: number | null = null
  /// Set by close()/exit so the disconnect handler doesn't try to reconnect.
  private finished = false

  constructor() {
    const saved = loadSession()
    if (saved) {
      this.handle = saved.handle
      this.rendered = saved.rendered
    }
  }

  /// Whether a previous connection left a session worth rejoining.
  get resumable(): boolean {
    return this.handle !== null
  }

  /// Starts a new session, or rejoins the stored one when there is no
  /// credential to open with.
  async start(renderer: Renderer, user: string, credential: Credential | null) {
    this.renderer = renderer
    this.user = user
    this.credential = credential
    this.finished = false
    await this.connect()
  }

  /// Ends the session for good, as opposed to just dropping the connection.
  close() {
    this.finished = true
    this.send({ type: 'close' })
    this.teardown()
    clearSession()
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
      // A 401 already dropped the session in `request`, so App falls back to
      // the login screen; retrying here would spin against a dead token.
      this.fail(e instanceof Error ? e.message : 'Could not authorise the terminal')
      return
    }

    const socket = new WebSocket(terminalWsUrl(entry.url, ticket))
    socket.binaryType = 'arraybuffer'
    this.socket = socket

    socket.onopen = () => {
      this.error = null
      this.attempt = 0
      this.armHeartbeat()
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
          cols: this.renderer?.cols ?? 80,
          rows: this.renderer?.rows ?? 24,
        })
      } else {
        this.fail('No credentials to open a session with')
      }
    }

    socket.onmessage = (event) => {
      this.armHeartbeat()
      if (typeof event.data === 'string') {
        this.onControl(event.data)
      } else {
        this.onOutput(new Uint8Array(event.data as ArrayBuffer))
      }
    }

    socket.onclose = () => this.onDisconnect()
    socket.onerror = () => this.onDisconnect()
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
        if (this.handle) saveSession(this.handle, this.rendered)
        this.prompts = []
        this.error = null
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
        clearSession()
        this.handle = null
        this.phase = 'closed'
        break
      case 'hb':
        break
    }
  }

  private onError(msg: ServerMessage) {
    if (msg.code === 'gap_truncated') {
      // Not a failure: the session is fine, only the scrollback fell behind
      this.truncated = true
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
      clearSession()
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

  private onOutput(data: Uint8Array) {
    const renderer = this.renderer
    if (!renderer) return
    renderer.write(data, () => {
      this.rendered += data.length
      this.persist()
    })
  }

  /// Throttled so a chatty shell doesn't turn into a storage write per frame.
  /// Lagging is safe; leading is not — see the module comment.
  private persist() {
    if (!this.handle) return
    const now = Date.now()
    if (now - this.persistedAt < PERSIST_INTERVAL_MS) return
    this.persistedAt = now
    saveSession(this.handle, this.rendered)
  }

  /// Writes the exact resume point out, ignoring the throttle. For `pagehide`,
  /// where there is no later chance.
  flush() {
    if (this.handle) saveSession(this.handle, this.rendered)
  }

  private onDisconnect() {
    this.clearHeartbeat()
    this.socket = null
    if (this.finished) {
      if (this.phase !== 'closed' && this.phase !== 'idle') this.phase = 'closed'
      return
    }
    if (!this.handle) {
      // Never got a session; reconnecting would just repeat the same failure
      this.phase = 'closed'
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
  private armHeartbeat() {
    this.clearHeartbeat()
    this.heartbeatTimer = window.setTimeout(() => {
      this.heartbeatTimer = null
      // The socket may still look open to us while the link is long gone;
      // closing it ourselves is what starts the reconnect.
      this.socket?.close()
    }, HEARTBEAT_TIMEOUT_MS)
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
