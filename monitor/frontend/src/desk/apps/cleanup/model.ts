/// The Cleanup app's words for what a scan found and its sums: the agent
/// decides what there is and what may go (`sbm_parser::cleanup`).

import type { TranslationFunctions } from '../../../i18n/i18n-types'
import type { CleanupItem } from '../../../types'

export const GROUPS: CleanupItem['group'][] = ['system', 'account', 'apps', 'containers']

/// What [item] is, in words.
export function itemLabel(ll: TranslationFunctions, item: CleanupItem): string {
  const [kind, rest] = item.id.includes(':') ? [item.id.slice(0, item.id.indexOf(':')), item.id.slice(item.id.indexOf(':') + 1)] : [item.id, '']
  switch (kind) {
    case 'apt-cache':
      return ll.cleanupAptCache()
    case 'autoremove':
      return ll.cleanupAutoremove()
    case 'journal':
      return ll.cleanupJournal()
    case 'rotated-logs':
      return ll.cleanupRotatedLogs()
    case 'crash-reports':
      return ll.cleanupCrashReports()
    case 'core-dumps':
      return ll.cleanupCoreDumps()
    case 'snap-revisions':
      return ll.cleanupSnapRevisions()
    case 'trash':
      return ll.cleanupTrash()
    case 'cache':
      return `~/.cache/${rest}`
    case 'dev':
      return ll.cleanupDevCache({ tool: rest })
    case 'leftover':
      return rest
    case 'docker':
      return `Docker · ${rest}`
    default:
      return item.id
  }
}

export function groupLabel(ll: TranslationFunctions, group: CleanupItem['group']): string {
  return { system: ll.cleanupGroupSystem, account: ll.cleanupGroupAccount, apps: ll.cleanupGroupApps, containers: ll.cleanupGroupContainers }[group]()
}

/// The sum of what [ids] free.
export function chosenBytes(items: CleanupItem[], ids: Set<string>): number {
  return items.filter((i) => ids.has(i.id)).reduce((s, i) => s + i.bytes, 0)
}
