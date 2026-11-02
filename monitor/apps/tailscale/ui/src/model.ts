/// The settings form: what the page shows from Tailscale's prefs, and what
/// it sends back (only what changed). The backend checks it
/// (`sbm_parser::tailscale::check`).

export interface Peer {
  id: string
  name: string
  dnsName: string | null
  ips: string[]
  os: string | null
  online: boolean
  active: boolean
  exitNodeOption: boolean
  exitNode: boolean
  routes: string[]
  direct: string | null
  relay: string | null
  rxBytes: number
  txBytes: number
}

export interface Prefs {
  controlUrl: string
  hostname: string
  acceptRoutes: boolean
  acceptDns: boolean
  ssh: boolean
  shieldsUp: boolean
  wantRunning: boolean
  loggedOut: boolean
  exitNodeId: string
  exitNodeIp: string
  exitNodeAllowLan: boolean
  advertiseRoutes: string[]
  advertiseExitNode: boolean
  operator: string
}

export interface Status {
  installable: boolean
  version: string | null
  daemon: boolean
  state: string | null
  authUrl: string | null
  name: string | null
  dnsName: string | null
  ips: string[]
  tailnet: string | null
  user: string | null
  health: string[]
  peers: Peer[]
  prefs: Prefs | null
}

/// What `tailscale set` changes; absent stays.
export interface Settings {
  exitNode?: string
  exitNodeAllowLan?: boolean
  acceptRoutes?: boolean
  acceptDns?: boolean
  ssh?: boolean
  shieldsUp?: boolean
  hostname?: string
  advertiseExitNode?: boolean
  advertiseRoutes?: string[]
}

export interface Draft {
  exitNode: string
  exitNodeAllowLan: boolean
  acceptRoutes: boolean
  acceptDns: boolean
  ssh: boolean
  shieldsUp: boolean
  hostname: string
  advertiseExitNode: boolean
  advertiseRoutes: string
}

/// The exit node in use, as a peer id ('' for none).
export function exitNodeOf(v: Status): string {
  return v.peers.find((p) => p.exitNode)?.id ?? v.prefs?.exitNodeId ?? ''
}

export function draftOf(v: Status, p: Prefs): Draft {
  return {
    exitNode: exitNodeOf(v),
    // On by default: an exit node without it cuts this machine's LAN off.
    exitNodeAllowLan: p.exitNodeAllowLan || !exitNodeOf(v),
    acceptRoutes: p.acceptRoutes,
    acceptDns: p.acceptDns,
    ssh: p.ssh,
    shieldsUp: p.shieldsUp,
    hostname: p.hostname,
    advertiseExitNode: p.advertiseExitNode,
    advertiseRoutes: p.advertiseRoutes.join(', '),
  }
}

export function routesOf(text: string): string[] {
  return text.split(/[\s,]+/).map((r) => r.trim()).filter(Boolean)
}

/// What changed from [before] to [after], as `tailscale set` takes it.
export function changes(before: Draft, after: Draft): Settings {
  const s: Settings = {}
  if (after.exitNode !== before.exitNode) s.exitNode = after.exitNode
  if (after.exitNodeAllowLan !== before.exitNodeAllowLan || (after.exitNode && after.exitNode !== before.exitNode)) s.exitNodeAllowLan = after.exitNodeAllowLan
  for (const k of ['acceptRoutes', 'acceptDns', 'ssh', 'shieldsUp', 'advertiseExitNode'] as const) if (after[k] !== before[k]) s[k] = after[k]
  if (after.hostname.trim() !== before.hostname) s.hostname = after.hostname.trim()
  const routes = routesOf(after.advertiseRoutes)
  if (routes.join(',') !== routesOf(before.advertiseRoutes).join(',')) s.advertiseRoutes = routes
  return s
}
