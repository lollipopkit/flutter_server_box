/// The Reverse proxy app's list changes: ServerBox's sites of one server,
/// the whole list sent back on each change. Checks are the agent's.

import type { ProxySite } from '../../../types'

export function withSite(sites: ProxySite[], site: ProxySite, replacing: string | null): ProxySite[] {
  const own = sites.filter((s) => s.managed)
  const i = replacing === null ? -1 : own.findIndex((s) => s.name === replacing)
  return i < 0 ? [...own, site] : own.map((s, j) => (j === i ? site : s))
}

export function withoutSite(sites: ProxySite[], name: string): ProxySite[] {
  return sites.filter((s) => s.managed && s.name !== name)
}

/// A site's name from its first domain: what the files call it.
export function nameFor(domain: string): string {
  return domain.toLowerCase().replace(/^\*\./, 'wildcard-').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'site'
}
