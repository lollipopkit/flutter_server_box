import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import {
  DesktopSession,
  parseControl,
  relayOpenMessage,
  type DesktopPhase,
} from '../lib/desktop.svelte'
import { agentWsUrl, wsTicketProtocol } from '../lib/agentWs'
import { servers } from '../lib/servers.svelte'
import type { DesktopTarget } from '../types'

/// A WebSocket stand-in the test drives directly. Only the surface the session
/// actually uses is implemented; anything more would be testing the mock.
///
/// It is its own class rather than the terminal suite's, because what the relay
/// sends first is what matters here: the desktop suite hands the socket over
/// while the terminal suite never does.
class FakeSocket {
  static instances: FakeSocket[] = []
  static readonly OPEN = 1
  static readonly CLOSED = 3

  readyState = FakeSocket.OPEN
  sent: string[] = []
  onopen: (() => void) | null = null
  onmessage: ((e: { data: string | ArrayBuffer }) => void) | null = null
  onclose: (() => void) | null = null
  onerror: (() => void) | null = null
  binaryType = 'arraybuffer'
  closed = false

  constructor(
    public url: string,
    public protocols?: string | string[],
  ) {
    FakeSocket.instances.push(this)
  }

  send(payload: string) {
    this.sent.push(payload)
  }

  close() {
    this.closed = true
    this.readyState = FakeSocket.CLOSED
    this.onclose?.()
  }

  /// Delivers a control frame from the relay.
  control(msg: unknown) {
    this.onmessage?.({ data: JSON.stringify(msg) })
  }

  static latest(): FakeSocket {
    const socket = FakeSocket.instances.at(-1)
    if (!socket) throw new Error('no socket was opened')
    return socket
  }
}

const ticketMock = vi.fn(async () => ({ ticket: 'id.secret', expires_in: 30 }))

// The factory is hoisted above the imports, so the class has to be declared
// inside it — referencing one from the module scope would be read in its
// temporal dead zone.
vi.mock('../lib/api', () => {
  class ApiError extends Error {
    status?: number
    constructor(message: string, status?: number) {
      super(message)
      this.status = status
    }
  }
  return {
    ApiError,
    api: { issueWsTicket: (...args: unknown[]) => ticketMock(...(args as [])) },
  }
})

const route: DesktopTarget = {
  name: 'office',
  protocol: 'vnc',
  host: '10.0.0.7',
  port: 5900,
  username: null,
  domain: null,
  view_only: false,
  shared: true,
}

describe('agentWsUrl', () => {
  it('upgrades the scheme and keeps the host', () => {
    expect(agentWsUrl('https://agent.example.com:3770', '/api/v1/stream/ws')).toBe(
      'wss://agent.example.com:3770/api/v1/stream/ws',
    )
    expect(agentWsUrl('http://192.168.1.5:3770', '/api/v1/stream/ws')).toBe(
      'ws://192.168.1.5:3770/api/v1/stream/ws',
    )
  })

  it('gives a schemeless entry the page scheme instead of reading it as one', () => {
    // `new URL` would take `agent.example.com:` for the scheme here
    expect(agentWsUrl('agent.example.com:3770', '/api/v1/stream/ws')).toBe(
      'ws://agent.example.com:3770/api/v1/stream/ws',
    )
  })

  it('carries the ticket only in the websocket subprotocol', () => {
    expect(agentWsUrl('https://a.example', '/api/v1/stream/ws')).not.toContain('ticket')
    expect(wsTicketProtocol('id.secret')).toBe('sbm-ticket.id.secret')
  })
})

describe('parseControl', () => {
  it('reads the relay control frames', () => {
    expect(parseControl('{"type":"ready"}')).toEqual({ type: 'ready' })
    expect(parseControl('{"type":"error","code":"bad_request","message":"no"}')).toMatchObject({
      type: 'error',
    })
    expect(parseControl('{"type":"exit"}')).toEqual({ type: 'exit' })
  })

  it('answers null for anything that is not one', () => {
    // Binary frames are the connection's bytes and are never parsed: a desktop
    // that sends a `{` as its first byte must not be read as a control frame.
    expect(parseControl(new ArrayBuffer(2))).toBeNull()
    expect(parseControl('not json')).toBeNull()
    expect(parseControl('{"type":7}')).toBeNull()
  })

  it('builds the request the relay requires first', () => {
    expect(JSON.parse(relayOpenMessage('10.0.0.7', 5900))).toEqual({
      type: 'open',
      host: '10.0.0.7',
      port: 5900,
    })
  })
})

describe('DesktopSession', () => {
  beforeEach(() => {
    FakeSocket.instances = []
    ticketMock.mockClear()
    vi.stubGlobal('WebSocket', FakeSocket)
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  /// Starts a connect and gets the socket it has just opened. The ticket is
  /// minted over an awaited call, so the socket does not exist until that
  /// resolves.
  async function dial(session: DesktopSession) {
    const connecting = session.connect(route)
    await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(1))
    return { connecting, socket: FakeSocket.latest() }
  }

  /// Opens a session and gets it to `ready`, the point at which the socket is
  /// handed over.
  async function opened() {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    socket.onopen?.()
    socket.control({ type: 'ready' })
    return { session, socket, channel: await connecting }
  }

  it('asks for a stream ticket and names the route in the first frame', async () => {
    const { socket, channel } = await opened()

    // A stream ticket, not a terminal one: they are separately revocable, and
    // the relay refuses the other purpose.
    expect(ticketMock).toHaveBeenCalledWith('stream')
    expect(socket.url).toContain('/api/v1/stream/ws')
    expect(socket.protocols).toEqual(['sbm-ticket.id.secret'])
    expect(JSON.parse(socket.sent[0])).toEqual({ type: 'open', host: '10.0.0.7', port: 5900 })
    expect(channel).toBe(socket)
  })

  it('answers only once the relay says the connection is up', async () => {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    socket.onopen?.()

    // Bytes written before `ready` are refused by the relay with "No connection
    // is open", and a VNC client writes its version string the instant it is
    // attached — so the socket must not be handed out yet.
    expect(session.phase).toBe<DesktopPhase>('connecting')

    socket.control({ type: 'ready' })
    expect(await connecting).toBe(socket)
    expect(session.phase).toBe('connected')
  })

  it('reports what the relay said when it refuses the connection', async () => {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    socket.onopen?.()
    socket.control({ type: 'error', code: 'refused', message: 'Connection refused' })

    expect(await connecting).toBeNull()
    expect(session.phase).toBe('failed')
    expect(session.error).toBe('Connection refused')
    // The half-open socket is closed rather than kept: a still-open connection
    // under a Try again button would make the second attempt two.
    expect(socket.closed).toBe(true)
  })

  it('fails rather than hanging when the socket dies before ready', async () => {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    socket.onopen?.()
    socket.close()

    expect(await connecting).toBeNull()
    expect(session.phase).toBe('failed')
    expect(session.error).toBe('The connection ended')
  })

  it('reports a ticket the agent would not mint', async () => {
    // What an agent with the relay off answers — which is the panel's only way
    // to tell "this agent will not relay" from "the desktop refused".
    ticketMock.mockRejectedValueOnce(new Error('Relay is not enabled'))
    const session = new DesktopSession()

    expect(await session.connect(route)).toBeNull()
    expect(session.phase).toBe('failed')
    expect(session.error).toBe('Relay is not enabled')
    expect(FakeSocket.instances.length).toBe(0)
  })

  it('answers a connect that is ended while it is still dialling', async () => {
    // The whole reason `connect` settles through a resolver rather than by
    // awaiting each step: a promise nothing answers is a caller that never
    // returns, with its busy flag set and nothing on screen saying why.
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    socket.onopen?.()
    session.close()
    socket.control({ type: 'ready' })

    expect(await connecting).toBeNull()
    expect(session.phase).toBe('idle')
  })

  it('takes its handlers off the socket it hands over', async () => {
    const { session, socket } = await opened()
    // The client owns the connection from here, and a second listener would be
    // a second opinion about the same connection.
    session.close()

    expect(socket.onmessage).toBeNull()
    expect(socket.onclose).toBeNull()
    expect(socket.closed).toBe(true)
  })
})
