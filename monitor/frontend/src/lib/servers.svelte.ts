/// Multi-server registry with per-server sessions. The panel can be served by
/// an agent itself (same-origin, url '') or hosted statically (e.g. Cloudflare
/// Pages) and talk to several agents cross-origin — each agent must list the
/// panel origin in cors_allowed_origins and be reachable over HTTPS.

export interface ServerEntry {
  id: string
  /// Base URL of the agent ('' = same origin)
  url: string
  token: string | null
  username: string | null
}

const KEY = 'servers.v1'

function normalizeUrl(u: string): string {
  return u.trim().replace(/\/+$/, '')
}

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

  constructor() {
    const raw = window.localStorage.getItem(KEY)
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as { list?: ServerEntry[]; currentId?: string }
        this.list = parsed.list ?? []
        this.currentId = parsed.currentId ?? ''
      } catch {
        // Corrupt store: fall through to the default entry
      }
    }
    if (this.list.length === 0) {
      // Same-origin default; migrates the legacy single-server token keys
      this.list = [
        {
          id: 'local',
          url: '',
          token: window.localStorage.getItem('token'),
          username: window.localStorage.getItem('username'),
        },
      ]
      this.currentId = 'local'
      this.#persist()
    }
    if (!this.list.some((s) => s.id === this.currentId)) {
      this.currentId = this.list[0].id
    }
  }

  get current(): ServerEntry {
    return this.list.find((s) => s.id === this.currentId) ?? this.list[0]
  }

  get authenticated(): boolean {
    return !!this.current?.token
  }

  add(url: string) {
    const entry: ServerEntry = {
      id: newId(),
      url: normalizeUrl(url),
      token: null,
      username: null,
    }
    this.list.push(entry)
    this.currentId = entry.id
    this.#persist()
  }

  /// Edits the URL of an existing entry (edit-server form); re-normalizes it
  /// the same way add() does. A URL change drops the saved session (the old
  /// token belongs to whatever agent was at the old URL) so the app falls
  /// back to login.
  update(id: string, url: string) {
    const entry = this.list.find((s) => s.id === id)
    if (!entry) return
    const normalized = normalizeUrl(url)
    if (normalized !== entry.url) {
      entry.token = null
      entry.username = null
    }
    entry.url = normalized
    this.#persist()
  }

  remove(id: string) {
    if (this.list.length <= 1) return
    this.list = this.list.filter((s) => s.id !== id)
    if (this.currentId === id) this.currentId = this.list[0].id
    this.#persist()
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

  /// Like login(), but for an arbitrary entry — used by the add/edit form to
  /// save a session for a server that isn't necessarily the selected one.
  setSession(id: string, token: string, username: string) {
    const entry = this.list.find((s) => s.id === id)
    if (!entry) return
    entry.token = token
    entry.username = username
    this.#persist()
  }

  logout() {
    this.current.token = null
    this.#persist()
  }

  #persist() {
    window.localStorage.setItem(
      KEY,
      JSON.stringify({ list: $state.snapshot(this.list), currentId: this.currentId }),
    )
  }
}

export const servers = new ServersStore()
