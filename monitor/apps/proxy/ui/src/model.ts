/// The sites of one server, the whole list sent back on each change (the
/// backend checks them), and the firewall's types.

export type ServerId = 'nginx' | 'caddy' | 'traefik'

export interface Site {
  name: string
  domains: string[]
  upstream: string
  tls: boolean
  cert: string | null
  key: string | null
  maxBodyMb: number | null
  waf: boolean
  managed: boolean
}

export interface ServerView {
  server: ServerId
  installed: boolean
  version: string | null
  active: boolean
  writable: boolean
  tlsResolver: boolean
  sites: Site[]
}

export interface Proxies {
  servers: ServerView[]
  listening: number[]
}

export interface WafSettings {
  mode: 'off' | 'detect' | 'block'
  paranoia: number
  exclusions: number[]
}

export interface ServerWaf {
  ready: boolean
  installable: boolean
  settings: WafSettings | null
}

export interface Firewall {
  nginx: ServerWaf
  traefik: ServerWaf
  crs: string | null
}

export interface WafEvent {
  time: string
  client: string
  host: string
  method: string
  uri: string
  status: number | null
  rules: [string, string][]
}

export function withSite(sites: Site[], site: Site, replacing: string | null): Site[] {
  const own = sites.filter((s) => s.managed)
  const i = replacing === null ? -1 : own.findIndex((s) => s.name === replacing)
  return i < 0 ? [...own, site] : own.map((s, j) => (j === i ? site : s))
}

export function withoutSite(sites: Site[], name: string): Site[] {
  return sites.filter((s) => s.managed && s.name !== name)
}

/// A site's name from its first domain: what the files call it.
export function nameFor(domain: string): string {
  return domain.toLowerCase().replace(/^\*\./, 'wildcard-').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'site'
}
