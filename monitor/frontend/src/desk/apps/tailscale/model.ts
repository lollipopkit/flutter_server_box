/// The Tailscale app's settings form: what the page shows from the agent's
/// prefs, and what it sends back (only what changed). The agent checks it
/// (`sbm_parser::tailscale::check`).

import type { TailscalePrefs, TailscaleSettings, TailscaleView } from '../../../types'

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
export function exitNodeOf(v: TailscaleView): string {
  return v.peers.find((p) => p.exitNode)?.id ?? v.prefs?.exitNodeId ?? ''
}

export function draftOf(v: TailscaleView, p: TailscalePrefs): Draft {
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
export function changes(before: Draft, after: Draft): TailscaleSettings {
  const s: TailscaleSettings = {}
  if (after.exitNode !== before.exitNode) s.exitNode = after.exitNode
  if (after.exitNodeAllowLan !== before.exitNodeAllowLan || (after.exitNode && after.exitNode !== before.exitNode)) s.exitNodeAllowLan = after.exitNodeAllowLan
  for (const k of ['acceptRoutes', 'acceptDns', 'ssh', 'shieldsUp', 'advertiseExitNode'] as const) if (after[k] !== before[k]) s[k] = after[k]
  if (after.hostname.trim() !== before.hostname) s.hostname = after.hostname.trim()
  const routes = routesOf(after.advertiseRoutes)
  if (routes.join(',') !== routesOf(before.advertiseRoutes).join(',')) s.advertiseRoutes = routes
  return s
}
