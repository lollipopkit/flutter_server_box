/// What the Storage app draws from `/storage`: pure, tested in
/// `tests/storage.test.ts`.

import type { BlockDevice, DiskHealth, StorageView } from '../../../types'

/// The machine's disks, without optical drives and empty loop devices.
export function disksOf(view: StorageView): BlockDevice[] {
  return view.disks.filter((d) => d.kind !== 'rom' && d.size > 0)
}

/// The filesystems on a disk: its partitions, or the disk itself when it
/// carries one whole; arrays built on them are listed with RAID.
export function volumesOf(disk: BlockDevice): BlockDevice[] {
  const parts = disk.children.filter((c) => c.kind === 'part')
  return parts.length ? parts : [disk]
}

/// Every md and zpool device name a path may be listed under (`sdb1` in
/// mdstat for `/dev/sdb1`).
export function shortName(path: string): string {
  return path.replace(/^\/dev\//, '')
}

/// What a disk's SMART says, for its badge.
export type HealthVerdict = 'healthy' | 'wearing' | 'failing' | 'unsupported' | 'asleep'

export function verdict(h: DiskHealth): HealthVerdict {
  if (h.asleep) return 'asleep'
  if (!h.supported) return 'unsupported'
  if (h.passed === false || h.last_test?.outcome === 'failed') return 'failing'
  if ((h.bad_sectors ?? 0) > 0) return 'wearing'
  return 'healthy'
}

/// [path]'s reading in the last one made, if it was read.
export function healthOf(view: StorageView, path: string): DiskHealth | undefined {
  return view.health?.disks.find((d) => d.device === path)
}

/// The device at [path] anywhere in the tree.
export function deviceAt(view: StorageView, path: string): BlockDevice | undefined {
  const find = (ds: BlockDevice[]): BlockDevice | undefined => {
    for (const d of ds) {
      if (d.path === path) return d
      const found = find(d.children)
      if (found) return found
    }
  }
  return find(view.disks)
}

/// Array [name]'s own device in the tree, which holds its filesystem.
export function arrayDevice(view: StorageView, name: string): BlockDevice | undefined {
  return deviceAt(view, `/dev/${name}`)
}

/// A LUKS container.
export function isLuks(d: BlockDevice): boolean {
  return d.fstype === 'crypto_LUKS'
}

/// An unlocked LUKS container's opened device (`/dev/mapper/luks-…`).
export function opened(d: BlockDevice): BlockDevice | undefined {
  return d.children.find((c) => c.kind === 'crypt')
}
