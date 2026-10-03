import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { DesktopSession, MAX_EARLY_BYTES, RelayChannel, parseControl, relayOpenMessage } from '../lib/desktop.svelte'
import { agentWsUrl, wsTicketProtocol } from '../lib/agentUrl'
import { desktopDraftOf, desktopFormState } from '../components/DesktopForm.svelte'
import { servers } from '../lib/servers.svelte'
import type { Desktop } from '../types'

/// A WebSocket the test drives directly; only what the session and channel use.
class FakeSocket {
  static instances: FakeSocket[] = []
  static readonly CONNECTING = 0
  static readonly OPEN = 1
  static readonly CLOSED = 3

  readyState = FakeSocket.OPEN
  protocol = ''
  binaryType: BinaryType = 'blob'
  sent: unknown[] = []
  onopen: ((e: Event) => void) | null = null
  onmessage: ((e: { data: unknown }) => void) | null = null
  onclose: ((e: unknown) => void) | null = null
  onerror: ((e: unknown) => void) | null = null

  constructor(
    public url: string,
    public protocols?: string | string[],
  ) {
    FakeSocket.instances.push(this)
  }

  send(payload: unknown) {
    this.sent.push(payload)
  }

  close() {
    if (this.readyState === FakeSocket.CLOSED) return
    this.readyState = FakeSocket.CLOSED
    this.onclose?.({ code: 1000 })
  }

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

vi.mock('../lib/api', () => {
  class ApiError extends Error {}
  return { ApiError, api: { issueWsTicket: (...args: unknown[]) => ticketMock(...(args as [])) } }
})

const office: Desktop = {
  id: 'd1',
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
    expect(agentWsUrl('agent.example.com:3770', '/x')).toBe('ws://agent.example.com:3770/x')
    expect(wsTicketProtocol('id.secret')).toBe('sbm-ticket.id.secret')
  })
})

describe('parseControl', () => {
  it('reads control frames and nothing else', () => {
    expect(parseControl('{"type":"ready"}')).toEqual({ type: 'ready' })
    expect(parseControl(new ArrayBuffer(2))).toBeNull()
    expect(parseControl('not json')).toBeNull()
    expect(JSON.parse(relayOpenMessage('10.0.0.7', 5900))).toEqual({
      type: 'open',
      host: '10.0.0.7',
      port: 5900,
    })
  })
})

describe('RelayChannel', () => {
  it('passes the desktop bytes on and keeps the agent frames back', () => {
    const socket = new FakeSocket('ws://x')
    const channel = new RelayChannel(socket as unknown as WebSocket)
    const seen: unknown[] = []
    channel.onmessage = (e) => seen.push(e.data)
    let closed = false
    channel.onclose = () => (closed = true)

    const bytes = new ArrayBuffer(4)
    socket.onmessage?.({ data: bytes })
    expect(seen).toEqual([bytes])

    socket.control({ type: 'error', code: 'permission_revoked', message: 'grant taken away' })
    expect(seen).toEqual([bytes])
    expect(channel.reason).toBe('grant taken away')
    expect(closed).toBe(true)
  })

  it('keeps what the desktop says before noVNC attaches', async () => {
    const socket = new FakeSocket('ws://x')
    const channel = new RelayChannel(socket as unknown as WebSocket)
    const banner = new TextEncoder().encode('RFB 003.008\n').buffer
    socket.onmessage?.({ data: banner })
    const seen: unknown[] = []
    channel.onmessage = (e) => seen.push(e.data)
    await Promise.resolve()
    expect(seen).toEqual([banner])
  })

  it('closes rather than keep an unbounded amount before noVNC attaches', () => {
    const socket = new FakeSocket('ws://x')
    const channel = new RelayChannel(socket as unknown as WebSocket)
    socket.onmessage?.({ data: new ArrayBuffer(MAX_EARLY_BYTES) })
    expect(socket.readyState).toBe(FakeSocket.OPEN)
    socket.onmessage?.({ data: new ArrayBuffer(1) })
    expect(socket.readyState).toBe(FakeSocket.CLOSED)
    expect(channel.reason).not.toBeNull()
  })

  it('has every property noVNC checks before attaching', () => {
    const channel = new RelayChannel(new FakeSocket('ws://x') as unknown as WebSocket)
    const props = [...Object.keys(channel), ...Object.getOwnPropertyNames(Object.getPrototypeOf(channel))]
    for (const prop of ['send', 'close', 'binaryType', 'onerror', 'onmessage', 'onopen', 'protocol', 'readyState']) {
      expect(props).toContain(prop)
    }
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

  afterEach(() => vi.unstubAllGlobals())

  async function dial(session: DesktopSession) {
    const connecting = session.connect(office)
    await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(1))
    return { connecting, socket: FakeSocket.latest() }
  }

  it('asks for the route first and hands the channel over on ready', async () => {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    expect(ticketMock).toHaveBeenCalledWith('stream')
    expect(socket.protocols).toEqual(['sbm-ticket.id.secret'])
    socket.onopen?.(new Event('open'))
    expect(JSON.parse(socket.sent[0] as string)).toEqual({ type: 'open', host: '10.0.0.7', port: 5900 })

    socket.control({ type: 'ready' })
    expect(await connecting).toBeInstanceOf(RelayChannel)
    expect(session.phase).toBe('connected')
  })

  it('reports the relay refusing with its own words', async () => {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    socket.control({ type: 'error', code: 'not_permitted', message: 'not on the allow list' })
    expect(await connecting).toBeNull()
    expect(session.phase).toBe('failed')
    expect(session.error).toBe('not on the allow list')
  })

  it('answers a connect that was abandoned instead of leaving it waiting', async () => {
    const session = new DesktopSession()
    const { connecting, socket } = await dial(session)
    session.close()
    expect(await connecting).toBeNull()
    expect(socket.readyState).toBe(FakeSocket.CLOSED)
  })
})

describe('the form', () => {
  it('sends a whole route, with cleared fields as null and a bad port as 0', () => {
    const fields = desktopFormState(undefined, [{ id: 'vnc', default_port: 5900 }])
    expect(fields.port).toBe('5900')
    fields.name = ' office '
    fields.port = 'abc'
    const draft = desktopDraftOf(fields)
    expect(draft).toMatchObject({ name: 'office', host: '127.0.0.1', port: 0, username: null })
    expect(draft.id).not.toBe('')
  })
})
