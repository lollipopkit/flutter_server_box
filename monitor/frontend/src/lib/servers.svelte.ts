/// Multi-server registry with per-server sessions. The panel can be served by
/// an agent itself (same-origin, url '') or hosted statically (e.g. Cloudflare
/// Pages) and talk to several agents cross-origin — each agent must list the
/// panel origin in cors_allowed_origins and be reachable over HTTPS.

export interface ServerEntry {
  id: string
  /// Base URL of the agent ('' = same origin)
  url: string
  /// The session in use on it (see [ServersStore.sessions] for the others).
  token: string | null
  username: string | null
}

/// An account the login screen offers for a server: remembered ("Remember
/// this account"), or signed in in this tab.
export interface ServerAccount {
  username: string
  /// When it last signed in here, Unix ms; 0 when not known.
  lastLogin: number
  /// It has a session in this tab: choosing it unlocks without a password.
  signedIn: boolean
}

import { probe } from './probe'
import { isSecureAgentUrl, normalizeAgentUrl } from './agentUrl'

const KEY = 'servers.v1'
/// TODO: remove the read of this key once no tab can still hold it (the
/// single session per server before several accounts, 2026-10-08).
const SESSION_KEY_V1 = 'servers.sessions.v1'
/// Per server: the account in use and every account's token, for this tab
/// only (`sessionStorage`: a token must not outlive the tab).
const SESSION_KEY = 'servers.sessions.v2'
/// Per server: the accounts remembered, by name — never a password or token.
const ACCOUNTS_KEY = 'servers.accounts.v1'
/// Per server: when it last answered, Unix ms, for "last online".
const ONLINE_KEY = 'servers.online.v1'

type Sessions = Record<string, { active: string | null; tokens: Record<string, string> }>

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

  /// Every account's session on every server, this tab's.
  sessions = $state<Sessions>({})
  /// The accounts remembered per server.
  remembered = $state<Record<string, { username: string; lastLogin: number }[]>>({})
  /// When each server last answered.
  lastOnline = $state<Record<string, number>>({})

  constructor() {
    this.sessions = readJson<Sessions>(window.sessionStorage, SESSION_KEY) ?? {}
    this.remembered = readJson(window.localStorage, ACCOUNTS_KEY) ?? {}
    this.lastOnline = readJson(window.localStorage, ONLINE_KEY) ?? {}
    // TODO: remove with SESSION_KEY_V1.
    const v1 = readJson<Record<string, { token: string; username: string | null }>>(window.sessionStorage, SESSION_KEY_V1) ?? {}
    window.sessionStorage.removeItem(SESSION_KEY_V1)
    const raw = window.localStorage.getItem(KEY)
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as { list?: ServerEntry[]; currentId?: string }
        this.list = (parsed.list ?? []).map((entry) => {
          const old = v1[entry.id] ?? (entry.token ? { token: entry.token, username: entry.username } : undefined)
          if (old?.token && !this.sessions[entry.id]) {
            const name = old.username ?? ''
            this.sessions[entry.id] = { active: name, tokens: { [name]: old.token } }
          }
          const session = this.sessions[entry.id]
          const active = session?.active ?? null
          const token = active !== null ? (session?.tokens[active] ?? null) : null
          return {
            id: entry.id,
            url: entry.url,
            token: isSecureAgentUrl(entry.url) ? token : null,
            username: active,
          }
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
          username: window.sessionStorage.getItem('username') ?? window.localStorage.getItem('username'),
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
    this.#persistSessions()
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
      username: null,
    }
    this.list.push(entry)
    this.currentId = entry.id
    this.#persist()
  }

  /// Edits the URL of an existing entry (edit-server form); re-normalizes it
  /// the same way add() does. A URL change drops the saved sessions and
  /// accounts (they belong to whatever agent was at the old URL) so the app
  /// falls back to login.
  update(id: string, url: string) {
    const entry = this.list.find((s) => s.id === id)
    if (!entry) return
    const normalized = normalizeAgentUrl(url)
    if (normalized !== entry.url) {
      entry.token = null
      entry.username = null
      delete this.sessions[id]
      delete this.remembered[id]
      delete this.lastOnline[id]
    }
    entry.url = normalized
    this.#persist()
  }

  /// Takes a server away, with every session and remembered account it had.
  remove(id: string) {
    this.list = this.list.filter((s) => s.id !== id)
    if (this.currentId === id) this.currentId = this.list[0]?.id ?? ''
    delete this.sessions[id]
    delete this.remembered[id]
    delete this.lastOnline[id]
    this.#persist()
  }

  /// The accounts the login screen offers for [id]: remembered ones and those
  /// signed in in this tab, the most recent first.
  accountsOf(id: string): ServerAccount[] {
    const tokens = this.sessions[id]?.tokens ?? {}
    const remembered = this.remembered[id] ?? []
    const out: ServerAccount[] = remembered.map((a) => ({
      username: a.username,
      lastLogin: a.lastLogin,
      signedIn: a.username in tokens,
    }))
    for (const username of Object.keys(tokens)) {
      if (!remembered.some((a) => a.username === username)) out.push({ username, lastLogin: 0, signedIn: true })
    }
    return out.sort((a, b) => b.lastLogin - a.lastLogin)
  }

  /// [username] signed in to [id] with [token]: its session is the one in
  /// use, and with [remember] the account is offered next time.
  signIn(id: string, username: string, token: string, remember: boolean) {
    const entry = this.list.find((s) => s.id === id)
    if (!entry) return
    entry.token = token
    entry.username = username
    const session = (this.sessions[id] ??= { active: username, tokens: {} })
    session.active = username
    session.tokens[username] = token
    const list = (this.remembered[id] ?? []).filter((a) => a.username !== username)
    if (remember || list.length !== (this.remembered[id] ?? []).length) {
      this.remembered[id] = [{ username, lastLogin: Date.now() }, ...list]
    }
    this.#persist()
  }

  /// Uses [username]'s session on [id], when this tab has one.
  useAccount(id: string, username: string): boolean {
    const entry = this.list.find((s) => s.id === id)
    const token = this.sessions[id]?.tokens[username]
    if (!entry || !token) return false
    entry.token = token
    entry.username = username
    this.sessions[id].active = username
    this.#persist()
    return true
  }

  /// No longer offers [username] for [id], and ends its session here.
  forget(id: string, username: string) {
    this.remembered[id] = (this.remembered[id] ?? []).filter((a) => a.username !== username)
    const entry = this.list.find((s) => s.id === id)
    if (entry?.username === username) this.logout(id)
    else {
      delete this.sessions[id]?.tokens[username]
      this.#persist()
    }
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

  login(token: string, username: string) {
    this.setSession(this.currentId, token, username)
  }

  /// Like login(), but for an arbitrary entry, without remembering the
  /// account (see [signIn]).
  setSession(id: string, token: string, username: string) {
    this.signIn(id, username, token, false)
  }

  /// Ends the session in use on [id] (only if it is still [expected]); the
  /// account stays remembered.
  logout(id = this.currentId, expected?: Pick<ServerEntry, 'url' | 'token'>) {
    const entry = this.list.find((server) => server.id === id)
    if (!entry) return
    if (expected && (entry.url !== expected.url || entry.token !== expected.token)) return
    const session = this.sessions[id]
    if (session && entry.username !== null) {
      delete session.tokens[entry.username]
      session.active = null
    }
    entry.token = null
    entry.username = null
    this.#persist()
  }

  #persist() {
    const list = $state.snapshot(this.list).map(({ id, url }) => ({
      id,
      url,
      token: null,
      username: null,
    }))
    window.localStorage.setItem(
      KEY,
      JSON.stringify({ list, currentId: this.currentId }),
    )
    this.#persistSessions()
  }

  #persistSessions() {
    // An entry's session is always among its server's (the legacy keys set
    // one directly), and a server no longer listed keeps none.
    for (const entry of this.list) {
      if (!entry.token) continue
      const name = entry.username ?? ''
      const session = (this.sessions[entry.id] ??= { active: name, tokens: {} })
      session.active = name
      session.tokens[name] = entry.token
    }
    const ids = new Set(this.list.map((e) => e.id))
    const sessions = Object.fromEntries(Object.entries($state.snapshot(this.sessions)).filter(([id]) => ids.has(id)))
    window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(sessions))
    const remembered = Object.fromEntries(Object.entries($state.snapshot(this.remembered)).filter(([id]) => ids.has(id)))
    window.localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(remembered))
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
