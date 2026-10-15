/// Multi-server registry with a session per server. The panel can be served by
/// an agent itself (same-origin, url '') or hosted statically (e.g. Cloudflare
/// Pages) and talk to several agents cross-origin — each agent must list the
/// panel origin in cors_allowed_origins and be reachable over HTTPS.

export interface ServerEntry {
  id: string
  /// Base URL of the agent ('' = same origin)
  url: string
  /// The session on it, this tab's.
  token: string | null
}

import { probe } from './probe'
import { isSecureAgentUrl, normalizeAgentUrl } from './agentUrl'

const KEY = 'servers.v1'
/// TODO: remove the reads of these keys once no tab can still hold them
/// (several accounts per agent, 2026-10-08 to 2026-10-14; v1 before them).
const SESSION_KEY_V1 = 'servers.sessions.v1'
const SESSION_KEY_V2 = 'servers.sessions.v2'
const ACCOUNTS_KEY = 'servers.accounts.v1'
/// Per server: its token, for this tab only (`sessionStorage`: a token must
/// not outlive the tab).
const SESSION_KEY = 'servers.sessions.v3'
/// Per server: when it last answered, Unix ms, for "last online".
const ONLINE_KEY = 'servers.online.v1'

/// The entry assumed before anything has been asked: the origin this panel was
/// served from. See confirmSameOrigin().
const LOCAL_ID = 'local'

/// No locally-editable/cached name — this is only the pre-connection
/// fallback. The real display name always comes live from the agent
/// (config.toml's `name`, or its hostname fallback) via `serverNames`; the
/// only way to change what's displayed is to change config.toml.
export function displayName(entry: ServerEntry): string {
  return entry.url || entry.id
}

function newId(): string {
  return typeof crypto.randomUUID === 'function' ? crypto.randomUUID() : String(Date.now())
}

class ServersStore {
  list = $state<ServerEntry[]>([])
  currentId = $state('')

  /// Whether this panel is the agent's own: whether the origin the page came
  /// from is an agent that serves it.
  ///
  /// The panel an agent serves is that machine's face and holds the one server
  /// it is served by; a panel hosted apart from any agent is a client of
  /// several. Which of the two it is cannot be read off the build — one `dist`
  /// is served both ways — so it is asked of the origin, by
  /// [confirmSameOrigin], and assumed until that answer arrives.
  ///
  /// The vite dev server is the one deployment the question cannot be asked of:
  /// it proxies `/api` to the agent `make monitor-dev` starts, so the probe
  /// reaches that agent and answers as though this were its own panel, while a
  /// dev server is the one deployment that does hold several. `DEV` is true
  /// there and in no shipped build — an agent's panel and a Pages panel are
  /// both production builds, so this cannot be what tells those two apart.
  servedByAgent = $state(!import.meta.env.DEV)

  /// When each server last answered.
  lastOnline = $state<Record<string, number>>({})

  constructor() {
    const sessions = readJson<Record<string, string>>(window.sessionStorage, SESSION_KEY) ?? {}
    this.lastOnline = readJson(window.localStorage, ONLINE_KEY) ?? {}
    // TODO: remove with SESSION_KEY_V1, SESSION_KEY_V2 and ACCOUNTS_KEY.
    const v1 = readJson<Record<string, { token: string }>>(window.sessionStorage, SESSION_KEY_V1) ?? {}
    const v2 = readJson<Record<string, { active: string | null; tokens: Record<string, string> }>>(window.sessionStorage, SESSION_KEY_V2) ?? {}
    for (const [id, { token }] of Object.entries(v1)) sessions[id] ??= token
    for (const [id, { active, tokens }] of Object.entries(v2)) {
      const token = active !== null ? tokens[active] : undefined
      if (token) sessions[id] ??= token
    }
    window.sessionStorage.removeItem(SESSION_KEY_V1)
    window.sessionStorage.removeItem(SESSION_KEY_V2)
    window.localStorage.removeItem(ACCOUNTS_KEY)
    const raw = window.localStorage.getItem(KEY)
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as { list?: ServerEntry[]; currentId?: string }
        this.list = (parsed.list ?? []).map((entry) => {
          const token = sessions[entry.id] ?? entry.token ?? null
          return { id: entry.id, url: entry.url, token: isSecureAgentUrl(entry.url) ? token : null }
        })
        this.currentId = parsed.currentId ?? ''
      } catch {
        // Corrupt store: fall through to the default entry
      }
    }
    if (this.list.length === 0) {
      // Same-origin default; migrates the legacy single-server token keys
      this.list = [
        {
          id: LOCAL_ID,
          url: '',
          token: window.sessionStorage.getItem('token') ?? window.localStorage.getItem('token'),
        },
      ]
      this.currentId = LOCAL_ID
      this.#persist()
    }
    if (!this.list.some((s) => s.id === this.currentId)) {
      this.currentId = this.list[0]?.id ?? ''
    }
    window.localStorage.removeItem('token')
    window.localStorage.removeItem('username')
    this.#persist()
  }

  get current(): ServerEntry | undefined {
    return this.list.find((s) => s.id === this.currentId) ?? this.list[0]
  }

  /// Whether there is nothing to show yet, which a static host starts at.
  get empty(): boolean {
    return this.list.length === 0
  }

  /// Asks the origin whether it is an agent: records the answer as
  /// [servedByAgent], and drops the assumed same-origin entry when it is not.
  ///
  /// Asked whatever the list holds, rather than only when there is an entry to
  /// drop: the same answer decides whether this panel holds one server or
  /// several, and a panel whose list is already someone else's was still served
  /// from somewhere.
  ///
  /// The entry is a guess made before anything has been asked: right when an
  /// agent serves the panel, wrong when the panel is hosted statically, where
  /// the origin answers `/api/v1/health` with the page you are reading. Only a
  /// well-formed answer from something that is not an agent counts — an agent
  /// mid-restart gives a network error, and the entry (with its saved session)
  /// stays.
  ///
  /// Cannot mistake a restarting agent for a static host in the case that
  /// matters either way: if this origin were the agent and it were down, there
  /// would be no panel here to run this.
  async confirmSameOrigin() {
    const reachable = await probe('')
    // The dev server keeps the answer it started with: reaching a second agent
    // is the reason it is there, and the probe's answer about the one it
    // proxies to is not about where the panel was served from.
    if (!import.meta.env.DEV) this.servedByAgent = reachable !== 'not-an-agent'
    const local = this.list.find((s) => s.id === LOCAL_ID)
    if (!local || local.url !== '' || this.list.length !== 1) return
    if (reachable !== 'not-an-agent') return
    this.list = []
    this.currentId = ''
    this.#persist()
  }

  get authenticated(): boolean {
    return !!this.current?.token
  }

  /// Adds a server and selects it.
  ///
  /// Refused on the panel an agent serves: that panel holds the one server it
  /// is served by, and a second is not something it has to offer. The
  /// affordances are absent there as well — this is what holds if one is
  /// reached anyway.
  add(url: string) {
    if (this.servedByAgent) return
    const entry: ServerEntry = {
      id: newId(),
      url: normalizeAgentUrl(url),
      token: null,
    }
    this.list.push(entry)
    this.currentId = entry.id
    this.#persist()
  }

  /// Edits the URL of an existing entry (edit-server form); re-normalizes it
  /// the same way add() does. A URL change drops the session (it belongs to
  /// whatever agent was at the old URL) so the app falls back to login.
  update(id: string, url: string) {
    const entry = this.list.find((s) => s.id === id)
    if (!entry) return
    const normalized = normalizeAgentUrl(url)
    if (normalized !== entry.url) {
      entry.token = null
      delete this.lastOnline[id]
    }
    entry.url = normalized
    this.#persist()
  }

  /// Takes a server away, with its session.
  remove(id: string) {
    this.list = this.list.filter((s) => s.id !== id)
    if (this.currentId === id) this.currentId = this.list[0]?.id ?? ''
    delete this.lastOnline[id]
    this.#persist()
  }

  /// [id] answered just now.
  markOnline(id: string) {
    if (!this.list.some((s) => s.id === id)) return
    this.lastOnline[id] = Date.now()
    try {
      window.localStorage.setItem(ONLINE_KEY, JSON.stringify($state.snapshot(this.lastOnline)))
    } catch {
      // Only "last online" is lost.
    }
  }

  select(id: string) {
    if (this.list.some((s) => s.id === id)) {
      this.currentId = id
      this.#persist()
    }
  }

  login(token: string) {
    this.setSession(this.currentId, token)
  }

  /// Like login(), but for an arbitrary entry.
  setSession(id: string, token: string) {
    const entry = this.list.find((s) => s.id === id)
    if (!entry) return
    entry.token = token
    this.#persist()
  }

  /// Ends the session on [id] (only if it is still [expected]).
  logout(id = this.currentId, expected?: Pick<ServerEntry, 'url' | 'token'>) {
    const entry = this.list.find((server) => server.id === id)
    if (!entry) return
    if (expected && (entry.url !== expected.url || entry.token !== expected.token)) return
    entry.token = null
    this.#persist()
  }

  #persist() {
    const list = $state.snapshot(this.list).map(({ id, url }) => ({ id, url, token: null }))
    window.localStorage.setItem(KEY, JSON.stringify({ list, currentId: this.currentId }))
    const sessions = Object.fromEntries(this.list.filter((e) => e.token).map((e) => [e.id, e.token]))
    window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(sessions))
  }
}

function readJson<T>(storage: Storage, key: string): T | null {
  try {
    const raw = storage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : null
  } catch {
    // Corrupt state is equivalent to none.
    return null
  }
}

export const servers = new ServersStore()
