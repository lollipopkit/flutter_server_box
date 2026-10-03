/// One remote desktop session: the agent's half of it.
///
/// The agent understands no desktop protocol. It relays one TCP connection
/// over `/api/v1/stream/ws`, and the protocol client (noVNC) runs here. This
/// store opens that relay and hands the client a channel once the agent has
/// answered `ready`: the relay refuses bytes before then, while a VNC client
/// writes its version string the moment it is attached.

import { agentWsUrl, wsTicketProtocol } from './agentUrl'
import { api } from './api'
import { servers } from './servers.svelte'
import type { Desktop } from '../types'

export type DesktopPhase = 'idle' | 'connecting' | 'connected' | 'failed'

/// The relay's control frames (`api::ws::stream::ServerMsg`).
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

/// What `RelayChannel` keeps for a client that has not attached yet.
export const MAX_EARLY_BYTES = 64 * 1024

/// The relay socket as the WebSocket-shaped channel noVNC attaches to, with
/// the relay's own control frames taken out.
///
/// Text frames on the relay are the agent's, not the desktop's: `exit` when
/// the desktop hung up, `error` when the connection was cut — a grant taken
/// away mid-session, say. noVNC would read one as screen bytes; here an
/// `error` is kept as `reason` for the page and the channel closes.
///
/// Bytes that arrive before noVNC attaches are kept and handed over when it
/// does: a VNC server speaks first, and its version string follows `ready`
/// while noVNC is still being loaded.
export class RelayChannel {
  onopen: ((e: Event) => void) | null = null
  onclose: ((e: CloseEvent) => void) | null = null
  onerror: ((e: Event) => void) | null = null
  /// Why the agent ended the connection, when it said.
  reason: string | null = null
  private receiver: ((e: MessageEvent) => void) | null = null
  private early: MessageEvent[] = []
  private earlyBytes = 0

  constructor(private readonly socket: WebSocket) {
    socket.onmessage = (e) => {
      if (typeof e.data !== 'string') {
        if (this.receiver) {
          this.receiver(e)
          return
        }
        const size = e.data instanceof Blob ? e.data.size : (e.data as ArrayBuffer).byteLength
        // An empty frame carries nothing, and kept it would be a cost the
        // byte bound below never sees.
        if (size === 0) return
        this.earlyBytes += size
        // A VNC server says a dozen bytes and waits for the client; more than
        // this before one attaches is not a VNC server, and is not kept.
        if (this.earlyBytes > MAX_EARLY_BYTES) {
          this.early = []
          this.reason = 'The desktop sent more than expected before the client started'
          socket.close()
          return
        }
        this.early.push(e)
        return
      }
      const control = parseControl(e.data)
      if (control?.type === 'error') this.reason = control.message || control.code
      if (control?.type === 'error' || control?.type === 'exit') socket.close()
    }
    socket.onclose = (e) => this.onclose?.(e)
    socket.onerror = (e) => this.onerror?.(e)
  }

  get onmessage(): ((e: MessageEvent) => void) | null {
    return this.receiver
  }

  /// Taking the receiver delivers what came first, after the attach that set
  /// it has finished.
  set onmessage(receiver: ((e: MessageEvent) => void) | null) {
    this.receiver = receiver
    if (!receiver || this.early.length === 0) return
    const early = this.early
    this.early = []
    queueMicrotask(() => {
      for (const e of early) this.receiver?.(e)
    })
  }

  get readyState(): number {
    return this.socket.readyState
  }

  get protocol(): string {
    return this.socket.protocol
  }

  get binaryType(): BinaryType {
    return this.socket.binaryType
  }

  set binaryType(value: BinaryType) {
    this.socket.binaryType = value
  }

  send(data: ArrayBufferLike | ArrayBufferView | Blob | string) {
    this.socket.send(data)
  }

  close() {
    this.socket.close()
  }
}

export class DesktopSession {
  phase = $state<DesktopPhase>('idle')
  /// What went wrong: the agent's own message where it sent one — the only
  /// thing that tells "not on the allow list" from "nothing listens there".
  error = $state<string | null>(null)

  private socket: WebSocket | null = null
  private generation = 0
  private settle: ((value: RelayChannel | null) => void) | null = null

  /// Opens the relay to `desktop` and answers with the channel, or `null`
  /// with `phase = 'failed'` and `error` set.
  async connect(desktop: Desktop): Promise<RelayChannel | null> {
    this.close()
    const entry = servers.current
    if (!entry) {
      this.fail('No server is selected')
      return null
    }
    const generation = ++this.generation
    this.phase = 'connecting'
    this.error = null
    // Settled through `this.settle` rather than by awaiting each step, so a
    // `close()` while the ticket is minted or the socket dialled answers the
    // caller instead of leaving it waiting.
    const answered = new Promise<RelayChannel | null>((resolve) => (this.settle = resolve))

    let ticket: string
    try {
      ticket = (await api.issueWsTicket('stream')).ticket
    } catch (e) {
      if (generation === this.generation) this.fail(e instanceof Error ? e.message : String(e))
      return answered
    }
    if (generation !== this.generation) return answered

    const socket = new WebSocket(agentWsUrl(entry.url, '/api/v1/stream/ws'), [
      wsTicketProtocol(ticket),
    ])
    socket.binaryType = 'arraybuffer'
    this.socket = socket
    socket.onopen = () => {
      if (generation === this.generation) socket.send(relayOpenMessage(desktop.host, desktop.port))
    }
    socket.onmessage = (event) => {
      if (generation !== this.generation) return
      const control = parseControl(event.data)
      if (control?.type === 'ready') {
        this.phase = 'connected'
        this.answer(new RelayChannel(socket))
      } else if (control?.type === 'error') {
        this.fail(control.message || control.code)
      }
    }
    // Closing before `ready` is the relay refusing: a bad ticket, the grant
    // off, the address not allowed or not answering.
    socket.onclose = () => {
      if (generation === this.generation) this.fail(this.error ?? 'The connection ended')
    }
    return answered
  }

  /// Ends the session, whatever it is doing.
  close() {
    this.generation += 1
    const socket = this.socket
    this.socket = null
    if (socket && socket.readyState !== WebSocket.CLOSED) socket.close()
    // A failure stays readable until the next connect: the page reads `error`
    // after the answer, and may have closed the session first.
    if (this.phase !== 'failed') {
      this.phase = 'idle'
      this.error = null
    }
    this.answer(null)
  }

  private fail(message: string) {
    const socket = this.socket
    this.socket = null
    this.phase = 'failed'
    this.error = message
    if (socket && socket.readyState !== WebSocket.CLOSED) {
      socket.onclose = null
      socket.close()
    }
    this.answer(null)
  }

  private answer(value: RelayChannel | null) {
    const settle = this.settle
    this.settle = null
    settle?.(value)
  }
}

/// Where the RDP client points itself, and how to get the ticket it carries.
///
/// The RDP client opens its own socket to `/api/v1/rdp/ws` and sends the
/// ticket inside its first PDU (`proxy_auth`), so there is nothing here to
/// open. The ticket is minted when the client is ready to dial rather than
/// when the route is opened: it is single-use and good for about thirty
/// seconds, and the client has megabytes of wasm to load first.
export interface RdpEndpoint {
  proxyUrl: string
  ticket: () => Promise<string>
}

export function rdpEndpoint(): RdpEndpoint | null {
  const entry = servers.current
  if (!entry) return null
  return {
    proxyUrl: agentWsUrl(entry.url, '/api/v1/rdp/ws'),
    ticket: async () => (await api.issueWsTicket('rdp')).ticket,
  }
}
