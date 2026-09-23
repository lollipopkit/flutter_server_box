/// One remote desktop session: the relay connection the panel opens onto a
/// saved route, and what it is doing.
///
/// This is the counterpart of `terminal.svelte.ts`, and deliberately much
/// smaller. The terminal *is* the client — the agent gives it a PTY and the
/// panel renders the bytes — so its store owns a protocol, a renderer and a
/// reconnect policy. A desktop is not: VNC and RDP are protocols with clients
/// of their own, and the agent understands neither. So what is owned here is
/// only the part that is the agent's: minting the ticket, opening
/// `/api/v1/stream/ws`, asking it to dial the route and waiting for it to say
/// the connection is up. The socket is then handed to the protocol client,
/// which takes over its handlers and speaks for itself from that point on.
///
/// The order matters and is the whole reason this is a module rather than four
/// lines in the page: the relay accepts binary bytes only once it has answered
/// `ready`, and refuses them with `No connection is open` before that — while a
/// VNC client writes its version string the instant it is attached. So the
/// socket is opened here, the request sent, `ready` awaited, and only then is
/// the socket given out.

import { servers } from './servers.svelte'
import { agentWsUrl, wsTicketProtocol } from './agentWs'
import { api } from './api'
import type { DesktopTarget } from '../types'

/// Where a session is in its life. `failed` is a state with an `error` beside
/// it rather than a thrown exception: the page draws it, and the operator's
/// next move is to try the route again.
export type DesktopPhase = 'idle' | 'connecting' | 'connected' | 'failed'

/// The relay's control frames, as `api::ws::stream` defines them.
type Control =
  | { type: 'ready' }
  | { type: 'error'; code: string; message: string }
  | { type: 'exit' }
  | { type: 'pong' }

export function parseControl(raw: unknown): Control | null {
  if (typeof raw !== 'string') return null
  try {
    const msg = JSON.parse(raw) as Control
    return typeof msg?.type === 'string' ? msg : null
  } catch {
    return null
  }
}

/// The request that has to be the first text frame on the socket.
export function relayOpenMessage(host: string, port: number): string {
  return JSON.stringify({ type: 'open', host, port })
}

export class DesktopSession {
  phase = $state<DesktopPhase>('idle')
  /// What went wrong, in the operator's words. The agent's own message where it
  /// sent one: it is the only thing that distinguishes "the desktop refused the
  /// connection" from "the address is not reachable from the agent".
  error = $state<string | null>(null)

  /// The socket, once a client has been handed it. Kept so the page can close
  /// it when it leaves — the client's own disconnect goes through here too, so
  /// there is one way out of a session.
  private socket: WebSocket | null = null
  private generation = 0
  /// Answers the `connect` still waiting, if there is one.
  private settle: ((value: WebSocket | null) => void) | null = null

  /// Opens a relay connection to `route` and answers with a socket that the
  /// relay has accepted, or `null` with `phase = 'failed'` and `error` set.
  ///
  /// The caller hands the socket to a protocol client and listens to *that* for
  /// the session ending: from the moment it is attached, the socket's handlers
  /// are the client's, and a second listener here would be a second opinion
  /// about the same connection.
  async connect(route: DesktopTarget): Promise<WebSocket | null> {
    this.close()
    const entry = servers.current
    if (!entry) {
      this.fail('No server is selected')
      return null
    }

    const generation = ++this.generation
    this.phase = 'connecting'
    this.error = null

    // Answered through `this.settle` rather than by `await`ing each step: the
    // page may end the session while the ticket is being minted or the socket
    // is being dialled, and a promise nothing settles is a caller that never
    // returns — with its busy flag still set and nothing on screen to say why.
    const answered = new Promise<WebSocket | null>((resolve) => (this.settle = resolve))

    let ticket: string
    try {
      // Minted per session, not per route: it is single-use and good for about
      // thirty seconds, and the agent refuses to mint one at all when the relay
      // is off — which is why a failure here is the panel's answer for "this
      // agent will not relay", and is reported as such rather than as a
      // connect failure.
      ticket = (await api.issueWsTicket('stream')).ticket
    } catch (e) {
      this.fail(messageOf(e))
      return answered
    }
    if (generation !== this.generation) return answered

    const socket = new WebSocket(agentWsUrl(entry.url, '/api/v1/stream/ws'), [
      wsTicketProtocol(ticket),
    ])
    socket.binaryType = 'arraybuffer'
    this.socket = socket

    socket.onopen = () => {
      if (generation !== this.generation) return
      // Sent once the socket is open — a WebSocket refuses `send` before that —
      // and before any client exists to write anything else.
      socket.send(relayOpenMessage(route.host, route.port))
    }
    socket.onmessage = (event) => {
      if (generation !== this.generation) return
      const control = parseControl(event.data)
      if (control?.type === 'ready') {
        // Handed over: the client attaches to an already-open socket and
        // replaces these handlers with its own, which is why they are not
        // cleared — there is nothing of this store's left for them to reach.
        this.phase = 'connected'
        this.answer(socket)
      } else if (control?.type === 'error') {
        this.fail(control.message || control.code)
      }
    }
    // A socket that closes before `ready` is the relay refusing the connection:
    // a bad ticket, the grant turned off, or the handshake failing. It is
    // reported as a failure of the session rather than left as a pending
    // promise.
    socket.onclose = () => {
      if (generation !== this.generation) return
      this.fail(this.error ?? 'The connection ended')
    }
    socket.onerror = () => {
      if (generation !== this.generation) return
      this.fail('The connection ended')
    }

    return answered
  }

  /// Ends the session, whatever it is doing. Safe to call at any point: the
  /// generation counter is what makes a connect still in flight land nowhere.
  close() {
    this.generation += 1
    if (this.socket) {
      detach(this.socket)
      if (this.socket.readyState !== WebSocket.CLOSED) this.socket.close()
      this.socket = null
    }
    if (this.phase !== 'failed') this.phase = 'idle'
    this.error = null
    this.answer(null)
  }

  private fail(message: string) {
    const socket = this.socket
    this.socket = null
    this.phase = 'failed'
    this.error = message
    // A half-open socket is stopped here rather than left for the garbage
    // collector: `failed` is a state the page draws with Try again beside it,
    // and a connection still open underneath would make the second attempt two.
    if (socket && socket.readyState !== WebSocket.CLOSED) {
      detach(socket)
      socket.close()
    }
    this.answer(null)
  }

  /// Settles the `connect` that is waiting, once. A later answer is ignored
  /// rather than reported: the first one is the outcome of the attempt, and a
  /// second is the same attempt being torn down.
  private answer(value: WebSocket | null) {
    const settle = this.settle
    this.settle = null
    settle?.(value)
  }
}

/// Takes this store's handlers off a socket, leaving whoever has it next to
/// decide what its closing means.
function detach(socket: WebSocket) {
  socket.onopen = null
  socket.onmessage = null
  socket.onclose = null
  socket.onerror = null
}

function messageOf(e: unknown): string {
  return e instanceof Error ? e.message : String(e)
}
