/// What the Sharing app changes, as the lists the agent writes whole: pure,
/// tested in `tests/sharing.test.ts`.

import type { NfsExport, SmbShare } from '../../../types'

/// ServerBox's shares with [draft] in place of [original] (by name), or
/// added when [original] is null.
export function withShare(shares: SmbShare[], draft: SmbShare, original: string | null): SmbShare[] {
  const mine = shares.filter((s) => s.managed)
  const next = { ...draft, managed: true, comment: draft.comment?.trim() || null }
  if (original === null) return [...mine, next]
  return mine.map((s) => (s.name === original ? next : s))
}

export function withoutShare(shares: SmbShare[], name: string): SmbShare[] {
  return shares.filter((s) => s.managed && s.name !== name)
}

/// ServerBox's exports with [draft] in place of [original] (by path), or
/// added when [original] is null.
export function withExport(exports: NfsExport[], draft: NfsExport, original: string | null): NfsExport[] {
  const mine = exports.filter((e) => e.managed)
  const next = { ...draft, managed: true, clients: draft.clients.map((c) => ({ ...c, host: c.host.trim() })).filter((c) => c.host) }
  if (original === null) return [...mine, next]
  return mine.map((e) => (e.path === original ? next : e))
}

export function withoutExport(exports: NfsExport[], path: string): NfsExport[] {
  return exports.filter((e) => e.managed && e.path !== path)
}

/// A share name Samba and the agent take: letters, digits, `_.-`, 32 at most.
export function shareNameOk(name: string): boolean {
  return /^[A-Za-z0-9_.-]{1,32}$/.test(name) && !['global', 'homes', 'printers', 'ipc$'].includes(name.toLowerCase())
}
