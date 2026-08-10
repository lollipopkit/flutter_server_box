import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { TerminalSession, terminalWsUrl, type Renderer } from '../lib/terminal.svelte'
import { servers } from '../lib/servers.svelte'

/// A WebSocket stand-in the test drives directly. Only the surface the session
/// actually uses is implemented; anything more would be testing the mock.
class FakeSocket {
  static instances: FakeSocket[] = []
  static readonly OPEN = 1

  readyState = FakeSocket.OPEN
  sent: unknown[] = []
  binary: Uint8Array[] = []
  onopen: (() => void) | null = null
  onmessage: ((e: { data: string | ArrayBuffer }) => void) | null = null
  onclose: (() => void) | null = null
  onerror: (() => void) | null = null
  binaryType = 'arraybuffer'
  closed = false

  constructor(public url: string) {
    FakeSocket.instances.push(this)
  }

  send(payload: string | Uint8Array) {
    if (typeof payload === 'string') this.sent.push(JSON.parse(payload))
    else this.binary.push(payload)
  }

  close() {
    this.closed = true
    this.onclose?.()
  }

  /// Delivers a control frame from the agent.
  control(msg: unknown) {
    this.onmessage?.({ data: JSON.stringify(msg) })
  }

  /// Delivers PTY output.
  output(text: string) {
    const bytes = new TextEncoder().encode(text)
    this.onmessage?.({ data: bytes.buffer as ArrayBuffer })
  }

  static latest(): FakeSocket {
    const socket = FakeSocket.instances.at(-1)
    if (!socket) throw new Error('no socket was opened')
    return socket
  }
}

/// Records what was written and lets the test decide when it counts as
/// rendered — the whole point of the resume counter is that it advances there.
class FakeRenderer implements Renderer {
  written: string[] = []
  resets = 0
  cols = 80
  rows = 24
  private pending: (() => void)[] = []

  write(data: Uint8Array, done: () => void) {
    this.written.push(new TextDecoder().decode(data))
    this.pending.push(done)
  }

  reset() {
    this.resets += 1
  }

  /// Completes every outstanding write, as xterm does once it has painted.
  flush() {
    for (const done of this.pending) done()
    this.pending = []
  }
}

const ticketMock = vi.fn(async () => ({ ticket: 'id.secret', expires_in: 30 }))

// The factory is hoisted above the imports, so the class has to be declared
// inside it — referencing one from the module scope would be read in its
// temporal dead zone. Tests get hold of it through the mocked module below.
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

const { ApiError: FakeApiError } = await import('../lib/api')

function installSessionStorage() {
  const map = new Map<string, string>()
  const storage = {
    getItem: (k: string) => map.get(k) ?? null,
    setItem: (k: string, v: string) => void map.set(k, String(v)),
    removeItem: (k: string) => void map.delete(k),
    clear: () => map.clear(),
    key: (i: number) => [...map.keys()][i] ?? null,
    get length() {
      return map.size
    },
  } as Storage
  Object.defineProperty(window, 'sessionStorage', { value: storage, configurable: true })
  return storage
}

/// Opens a session and gets it as far as `running`.
async function connected(renderer: FakeRenderer) {
  const session = new TerminalSession()
  await session.start(renderer, 'ops', { kind: 'password', password: 'x' })
  const socket = FakeSocket.latest()
  socket.onopen?.()
  socket.control({ type: 'ready', session: 'abc.def', since: 0 })
  return { session, socket }
}

describe('terminalWsUrl', () => {
  it('upgrades the scheme and keeps the host', () => {
    expect(terminalWsUrl('https://agent.example.com:3770', 't')).toBe(
      'wss://agent.example.com:3770/api/v1/terminal/ws?ticket=t',
    )
    expect(terminalWsUrl('http://192.168.1.5:3770', 't')).toBe(
      'ws://192.168.1.5:3770/api/v1/terminal/ws?ticket=t',
    )
  })

  it('resolves an empty base against the current origin', () => {
    // The same-origin case: the panel served by the agent itself
    expect(terminalWsUrl('', 't')).toContain('/api/v1/terminal/ws?ticket=t')
    expect(terminalWsUrl('', 't').startsWith('ws')).toBe(true)
  })

  it('gives a schemeless entry the page scheme instead of reading it as one', () => {
    // `new URL` would take `agent.example.com:` for the scheme here
    expect(terminalWsUrl('agent.example.com:3770', 't')).toBe(
      'ws://agent.example.com:3770/api/v1/terminal/ws?ticket=t',
    )
  })

  it('escapes the ticket rather than splicing it in raw', () => {
    expect(terminalWsUrl('https://a.example', 'a b&c')).toContain('ticket=a%20b%26c')
  })
})

describe('TerminalSession', () => {
  let renderer: FakeRenderer

  beforeEach(() => {
    FakeSocket.instances = []
    ticketMock.mockClear()
    installSessionStorage()
    vi.stubGlobal('WebSocket', FakeSocket)
    servers.list = [{ id: 'local', url: '', token: 't', username: 'admin' }]
    servers.currentId = 'local'
    renderer = new FakeRenderer()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('takes a ticket, then opens with the supplied credentials', async () => {
    const { session, socket } = await connected(renderer)

    expect(ticketMock).toHaveBeenCalledWith('terminal')
    expect(socket.url).toContain('ticket=id.secret')
    expect(socket.sent[0]).toMatchObject({
      type: 'open',
      user: 'ops',
      auth: { kind: 'password', password: 'x' },
    })
    expect(session.phase).toBe('running')
  })

  it('advances the resume counter only once output is rendered', async () => {
    const { session, socket } = await connected(renderer)
    socket.output('hello')

    // Written but not yet painted: the counter must not have moved, or a
    // crash here would leave a hole nothing can fill
    expect(JSON.parse(window.sessionStorage.getItem('terminal.session')!).rendered).toBe(0)

    renderer.flush()
    session.flush()
    expect(JSON.parse(window.sessionStorage.getItem('terminal.session')!).rendered).toBe(5)
  })

  it('reattaches from the rendered position after a drop', async () => {
    const { session, socket } = await connected(renderer)
    socket.output('hello')
    renderer.flush()

    socket.close()
    expect(session.phase).toBe('reconnecting')

    session.reconnectNow()
    await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(2))
    const second = FakeSocket.latest()
    second.onopen?.()

    expect(second.sent[0]).toMatchObject({
      type: 'attach',
      session: 'abc.def',
      since: 5,
    })
    expect(ticketMock).toHaveBeenCalledTimes(2)
  })

  it('keeps trying while the agent is unreachable', async () => {
    const { session, socket } = await connected(renderer)

    // What a dropped link looks like from here: the socket dies and the
    // ticket request that starts the retry cannot reach the agent either
    ticketMock.mockRejectedValueOnce(new FakeApiError('Request failed'))
    socket.close()
    expect(session.phase).toBe('reconnecting')

    session.reconnectNow()
    await vi.waitFor(() => expect(ticketMock).toHaveBeenCalledTimes(2))
    // The overlay must stay up: giving up here is what made a brief outage
    // look like a dead session
    await vi.waitFor(() => expect(session.phase).toBe('reconnecting'))

    // And the next attempt still happens, with the agent back
    session.reconnectNow()
    await vi.waitFor(() => expect(FakeSocket.instances.length).toBe(2))
    FakeSocket.latest().onopen?.()
    expect(FakeSocket.latest().sent[0]).toMatchObject({ type: 'attach' })
  })

  it('stops when authorisation is refused rather than unavailable', async () => {
    const { session, socket } = await connected(renderer)

    // A 401 has already dropped the panel session; retrying would spin
    // against a dead token
    ticketMock.mockRejectedValueOnce(new FakeApiError('Session expired', 401))
    socket.close()
    session.reconnectNow()

    await vi.waitFor(() => expect(session.phase).toBe('closed'))
    expect(session.error).toBe('Session expired')
  })

  it('sets the counter from ready rather than adding to it', async () => {
    // A truncated replay resumes at the buffer's start, which is ahead of
    // where the client was; adding would double-count the replay that follows
    const { session, socket } = await connected(renderer)
    socket.output('abc')
    renderer.flush()

    socket.control({ type: 'ready', session: 'abc.def', since: 1000 })
    socket.output('xy')
    renderer.flush()
    session.flush()

    expect(JSON.parse(window.sessionStorage.getItem('terminal.session')!).rendered).toBe(1002)
  })

  it('resets the screen and flags the loss when output was truncated', async () => {
    const { session, socket } = await connected(renderer)
    socket.control({ type: 'error', code: 'gap_truncated', message: 'lost' })

    expect(renderer.resets).toBe(1)
    expect(session.truncated).toBe(true)
    // Not a failure: the session is still usable
    expect(session.phase).toBe('running')
    expect(session.error).toBeNull()
  })

  it('forwards a prompt and sends the answers back', async () => {
    const session = new TerminalSession()
    await session.start(renderer, 'ops', { kind: 'interactive' })
    const socket = FakeSocket.latest()
    socket.onopen?.()

    socket.control({
      type: 'prompt',
      instructions: 'Enter the code',
      prompts: [{ prompt: 'Code: ', echo: false }],
    })
    expect(session.phase).toBe('prompting')
    expect(session.prompts).toEqual([{ prompt: 'Code: ', echo: false }])

    session.answer(['123456'])
    expect(socket.sent.at(-1)).toMatchObject({ type: 'answer', answers: ['123456'] })
    expect(session.phase).toBe('authenticating')
  })

  it('does not reconnect after an authentication failure', async () => {
    const session = new TerminalSession()
    await session.start(renderer, 'ops', { kind: 'password', password: 'wrong' })
    const socket = FakeSocket.latest()
    socket.onopen?.()
    socket.control({ type: 'error', code: 'auth_failed', message: 'Authentication failed' })

    socket.close()
    // Retrying the same wrong password forever would only lock the account out
    expect(session.phase).toBe('idle')
    expect(FakeSocket.instances.length).toBe(1)
  })

  it('does not fight back when another connection takes over', async () => {
    const { session, socket } = await connected(renderer)
    socket.control({ type: 'error', code: 'superseded', message: 'taken over' })
    socket.close()

    expect(session.phase).toBe('closed')
    expect(FakeSocket.instances.length).toBe(1)
    // The handle survives so rejoining is still possible, but only if the
    // user asks for it — an automatic retry would start a tug of war with
    // the tab that now owns the session
    expect(session.resumable).toBe(true)
  })

  it('stops trying once the agent says the session is gone', async () => {
    const { session, socket } = await connected(renderer)
    socket.control({ type: 'error', code: 'session_gone', message: 'gone' })
    socket.close()

    expect(session.phase).toBe('closed')
    expect(session.resumable).toBe(false)
    expect(window.sessionStorage.getItem('terminal.session')).toBeNull()
    expect(FakeSocket.instances.length).toBe(1)
  })

  it('an explicit close ends the session instead of detaching', async () => {
    const { session, socket } = await connected(renderer)
    session.close()

    expect(socket.sent.at(-1)).toMatchObject({ type: 'close' })
    expect(session.phase).toBe('closed')
    expect(session.resumable).toBe(false)
    expect(window.sessionStorage.getItem('terminal.session')).toBeNull()
  })

  it('a shell that exits leaves nothing to rejoin', async () => {
    const { session, socket } = await connected(renderer)
    socket.control({ type: 'exit', status: 0 })

    expect(session.phase).toBe('closed')
    expect(session.resumable).toBe(false)
  })

  it('treats heartbeat silence as a dead link', async () => {
    vi.useFakeTimers()
    try {
      const { session, socket } = await connected(renderer)
      expect(session.phase).toBe('running')

      // Browsers can't observe WebSocket pongs, so a quiet socket is
      // indistinguishable from a dead one without the agent's heartbeat
      vi.advanceTimersByTime(40_000)
      expect(socket.closed).toBe(true)
      expect(session.phase).toBe('reconnecting')
    } finally {
      vi.useRealTimers()
    }
  })

  it('keeps the connection alive while the heartbeat arrives', async () => {
    vi.useFakeTimers()
    try {
      const { session, socket } = await connected(renderer)
      for (let i = 0; i < 4; i++) {
        vi.advanceTimersByTime(15_000)
        socket.control({ type: 'hb' })
      }
      expect(socket.closed).toBe(false)
      expect(session.phase).toBe('running')
    } finally {
      vi.useRealTimers()
    }
  })

  it('restores the handle a previous tab load left behind', () => {
    window.sessionStorage.setItem(
      'terminal.session',
      JSON.stringify({ handle: 'abc.def', rendered: 42 }),
    )
    const session = new TerminalSession()
    expect(session.resumable).toBe(true)
  })

  it('never writes the handle to localStorage', async () => {
    const { session } = await connected(renderer)
    session.flush()
    // The handle is a bearer capability for an authenticated shell; on disk it
    // would outlive the tab and be readable by anything else on the origin
    expect(window.localStorage.getItem('terminal.session')).toBeNull()
  })

  it('opens without any credential when the agent allows it', async () => {
    const session = new TerminalSession()
    await session.start(renderer, '', { kind: 'local' })
    const socket = FakeSocket.latest()
    socket.onopen?.()

    const open = socket.sent[0] as { auth: { kind: string }; user: string }
    expect(open.auth).toEqual({ kind: 'local' })
    // No password, key or passphrase may ride along on this path
    expect(JSON.stringify(open)).not.toMatch(/password|pem|passphrase/)
  })

  it('reports a refusal when the agent has passwordless turned off', async () => {
    const session = new TerminalSession()
    await session.start(renderer, '', { kind: 'local' })
    const socket = FakeSocket.latest()
    socket.onopen?.()
    socket.control({
      type: 'error',
      code: 'passwordless_disabled',
      message: 'not allowed',
    })
    socket.close()

    expect(session.error).toBe('not allowed')
    // Nothing to retry: the agent will refuse again
    expect(FakeSocket.instances.length).toBe(1)
  })

  it('sends input only while the session is running', async () => {
    const { session, socket } = await connected(renderer)
    session.input('ls\n')
    expect(socket.binary).toHaveLength(1)
    expect(new TextDecoder().decode(socket.binary[0])).toBe('ls\n')

    session.close()
    session.input('rm -rf /\n')
    expect(socket.binary).toHaveLength(1)
  })
})
