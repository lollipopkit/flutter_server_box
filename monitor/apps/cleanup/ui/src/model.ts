/// Cleanup's words for what a scan found and its sums: the backend decides
/// what there is and what may go (`sbm_parser::cleanup`).

import type { Translate } from 'serverbox-desk'

export type Group = 'system' | 'account' | 'apps' | 'containers'

export interface Item {
  id: string
  group: Group
  bytes: number
  count: number | null
  detail: string | null
  cleanable: boolean
}

export interface Report {
  at: number
  items: Item[]
}

export const GROUPS: Group[] = ['system', 'account', 'apps', 'containers']

const KINDS: Record<string, string> = {
  'apt-cache': 'aptCache',
  autoremove: 'autoremove',
  journal: 'journal',
  'rotated-logs': 'rotatedLogs',
  'crash-reports': 'crashReports',
  'core-dumps': 'coreDumps',
  'snap-revisions': 'snapRevisions',
  trash: 'trash',
}

/// What [item] is, in words.
export function itemLabel(t: Translate, item: Item): string {
  const at = item.id.indexOf(':')
  const [kind, rest] = at < 0 ? [item.id, ''] : [item.id.slice(0, at), item.id.slice(at + 1)]
  if (KINDS[kind]) return t(KINDS[kind])
  switch (kind) {
    case 'cache':
      return `~/.cache/${rest}`
    case 'dev':
      return t('devCache', { tool: rest })
    case 'leftover':
      return rest
    case 'docker':
      return `Docker · ${rest}`
    default:
      return item.id
  }
}

export function groupLabel(t: Translate, group: Group): string {
  return t({ system: 'groupSystem', account: 'groupAccount', apps: 'groupApps', containers: 'groupContainers' }[group])
}

/// The sum of what [ids] free.
export function chosenBytes(items: Item[], ids: Set<string>): number {
  return items.filter((i) => ids.has(i.id)).reduce((s, i) => s + i.bytes, 0)
}
