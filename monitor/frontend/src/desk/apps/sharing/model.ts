/// What the Sharing app changes, as the lists the agent writes whole: pure,
/// tested in `tests/sharing.test.ts`.

import type { Intent } from '../../sys'
import type { NfsExport, SmbShare, StorageView } from '../../../types'

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

export function firewallIntent(tab: 'smb' | 'nfs'): Intent {
  return {
    action: 'allowPorts',
    data: { label: tab === 'smb' ? 'SMB' : 'NFS', ports: [{ port: tab === 'smb' ? '445' : '2049', protocol: 'tcp' }] },
  }
}

export function mountedFolders(view: StorageView): string[] {
  const system = new Set(view.system ?? [])
  const paths = new Set<string>()
  const walk = (device: StorageView['disks'][number]) => {
    if (!system.has(device.path)) {
      for (const path of device.mountpoints) {
        if (path.startsWith('/') && path !== '/' && path !== '/boot' && path !== '/boot/efi') paths.add(path)
      }
    }
    device.children.forEach(walk)
  }
  view.disks.forEach(walk)
  return [...paths]
}
