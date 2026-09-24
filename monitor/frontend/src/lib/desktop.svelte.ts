/// One remote desktop session: the part of it the agent answers for, and what
/// it is doing.
///
/// This is the counterpart of `terminal.svelte.ts`, and deliberately much
/// smaller. The terminal *is* the client — the agent gives it a PTY and the
/// panel renders the bytes — so its store owns a protocol, a renderer and a
/// reconnect policy. A desktop is not: VNC and RDP are protocols with clients
/// of their own, and the agent understands neither. What is owned here is only
/// the ticket and the endpoint, and then the two protocols part company,
/// because the two agent endpoints are not the same shape:
///
/// - **VNC** goes through `/api/v1/stream/ws`, which is one relay for any
///   protocol and authenticates on the upgrade. The order matters and is the
///   whole reason this is a module rather than four lines in the page: the
///   relay accepts binary bytes only once it has answered `ready`, and refuses
///   them with `No connection is open` before that — while a VNC client writes
///   its version string the instant it is attached. So the socket is opened
///   here, the request sent, `ready` awaited, and only then is the socket given
///   out, already accepted, for the client to attach to.
/// - **RDP** goes through `/api/v1/rdp/ws`, which is an RDCleanPath proxy and
///   authenticates inside the first PDU its client writes. So there is nothing
///   here to open or to accept: what this store produces is where the client
///   must point itself and how to get the ticket it must carry, and the client
///   dials itself. `markConnected` is then how it says the session is up, which
///   an endpoint that hands over no socket has no other way of reporting.

import { servers } from './servers.svelte'
import { agentWsUrl, wsTicketProtocol } from './agentWs'
import { api } from './api'
import type { DesktopTarget, WsTicketPurpose } from '../types'

/// The agent's RDCleanPath endpoint. Reached over a WebSocket, but not as a
/// relay: an RDP client speaks its own protocol on it.
const RDP_PATH = '/api/v1/rdp/ws'

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

/// Where an RDP client must point itself, and how to get what it must carry
/// there.
export interface RdpEndpoint {
  /// The agent's RDCleanPath endpoint, as a WebSocket URL — the whole address,
  /// path included, because the client opens the socket with it as given.
  proxyUrl: string
  /// Mints the ticket to carry there, called when the client is ready to dial.
  ///
  /// A function rather than a value because a ticket is single-use and good for
  /// about thirty seconds, and an RDP client has several megabytes of wasm to
  /// fetch and initialize before it can write anything. Minting at the moment
  /// the route is opened spends that window on the download, and a session on a
  /// slow link is then refused for a ticket that was never used. The ticket is
  /// the one thing this store's two protocols do not share: an RDP client sends
  /// it inside its first PDU (`proxy_auth`) rather than offering it as a
  /// subprotocol, which is why it cannot be a bearer on the upgrade and why the
  /// endpoint gives a socket with no ticket a deadline instead of keeping it.
  ticket: () => Promise<string>
}

/// What `connect` answers with: the agent's half of a session, in whichever
/// shape the protocol that route speaks needs. `vnc` hands over a socket and
/// `rdp` hands over an address, and the page draws a different client for each.
export type DesktopChannel =
  | { protocol: 'vnc'; socket: WebSocket }
  | { protocol: 'rdp'; endpoint: RdpEndpoint }

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
  private settle: ((value: DesktopChannel | null) => void) | null = null

  /// Prepares a session on `route` and answers with what the protocol client
  /// needs, or `null` with `phase = 'failed'` and `error` set.
  ///
  /// The caller hands the result to a protocol client and listens to *that* for
  /// the session ending: a VNC client takes the socket's handlers from the
  /// moment it is attached and noVNC ends the session on its own, and an RDP
  /// client owns the connection it dialled.
  async connect(route: DesktopTarget): Promise<DesktopChannel | null> {
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
    const answered = new Promise<DesktopChannel | null>((resolve) => (this.settle = resolve))

    if (route.protocol === 'rdp') {
      // Nothing is dialled here and no ticket is minted here. The ticket travels
      // in the first PDU the client writes, so the socket it opens carries no
      // proof of anything until that PDU arrives, and a socket this store opened
      // and held would be a connection it could do nothing with. The client
      // opens its own — and it mints its own, because between here and that PDU
      // it has megabytes of wasm to fetch.
      this.answer({
        protocol: 'rdp',
        endpoint: {
          proxyUrl: agentWsUrl(entry.url, RDP_PATH),
          ticket: () => this.mint('rdp'),
        },
      })
      return answered
    }

    let ticket: string
    try {
      ticket = await this.mint('stream')
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
        this.answer({ protocol: 'vnc', socket })
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

  /// Asks the agent for a ticket to one of its session endpoints.
  ///
  /// Per session, never stored: it is single-use, good for about thirty seconds,
  /// and the agent refuses to mint one at all when the grant behind the endpoint
  /// is off — which is why a caller reports a failure here as the panel's answer
  /// for "this agent will not relay it", rather than as a connect failure. The
  /// purpose is what pins it to an endpoint: a stream ticket is refused by the
  /// RDP endpoint and the other way round.
  private async mint(purpose: WsTicketPurpose): Promise<string> {
    return (await api.issueWsTicket(purpose)).ticket
  }

  /// Records that the protocol client has the session up.
  ///
  /// Called by the viewer, and only for a protocol whose client is the one that
  /// dialled: an RDP client opens its own socket, so this store has no moment
  /// of its own at which it could know, and the alternative — reporting
  /// `connected` as the endpoint is handed over — would put the page's
  /// connecting spinner behind the session instead of in front of it.
  markConnected() {
    if (this.phase === 'connecting') this.phase = 'connected'
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
  private answer(value: DesktopChannel | null) {
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
