/// What the Storage app draws from `/storage`: pure, tested in
/// `tests/storage.test.ts`.

import type { BlockDevice, DiskHealth, StorageView } from '../../../types'

/// The machine's disks, without optical drives and empty loop devices.
export function disksOf(view: StorageView): BlockDevice[] {
  return view.disks.filter((d) => d.kind !== 'rom' && d.size > 0)
}

/// What may be given to a new array or pool, or formatted: not in use (the
/// agent's rule, `busy`), a disk, partition or loop device.
export function freeDevices(view: StorageView): BlockDevice[] {
  const out: BlockDevice[] = []
  const walk = (d: BlockDevice) => {
    if (['disk', 'part', 'loop'].includes(d.kind) && d.size > 0 && view.busy[d.path] === undefined) out.push(d)
    d.children.forEach(walk)
  }
  disksOf(view).forEach(walk)
  return out
}

/// [a] and [b] are one device and something on it (a disk and its
/// partition): never picked together (the agent refuses `overlapping`).
export function overlaps(view: StorageView, a: string, b: string): boolean {
  const find = (ds: BlockDevice[], path: string): BlockDevice | undefined => {
    for (const d of ds) {
      if (d.path === path) return d
      const found = find(d.children, path)
      if (found) return found
    }
  }
  const under = (top: string, path: string) => !!find(find(view.disks, top)?.children ?? [], path)
  return a !== b && (under(a, b) || under(b, a))
}

/// The filesystems on a disk: its partitions, or the disk itself when it
/// carries one whole; arrays built on them are listed with RAID.
export function volumesOf(disk: BlockDevice): BlockDevice[] {
  if (disk.children.length) return disk.children.filter((c) => c.kind === 'part')
  return [disk]
}

export function isMounted(d: BlockDevice): boolean {
  return d.mountpoints.length > 0 && !d.mountpoints.includes('[SWAP]')
}

/// A filesystem one can mount: not a member of an array or pool, not swap.
export function mountable(d: BlockDevice): boolean {
  return !!d.fstype && !['swap', 'linux_raid_member', 'zfs_member', 'LVM2_member', 'crypto_LUKS'].includes(d.fstype) && !isMounted(d)
}

/// The next free `md` name.
export function nextMd(view: StorageView): string {
  const taken = new Set(view.arrays.map((a) => a.name))
  for (let n = 0; n < 1000; n++) if (!taken.has(`md${n}`)) return `md${n}`
  return 'md999'
}

/// The fewest devices an md level or a pool layout takes.
export function minimum(levelOrLayout: number | string): number {
  switch (levelOrLayout) {
    case 0:
    case 1:
    case 'mirror':
      return 2
    case 5:
    case 'raidz1':
      return 3
    case 6:
    case 10:
    case 'raidz2':
      return 4
    case 'raidz3':
      return 5
    default:
      return 1
  }
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

/// Array [name]'s own device in the tree, which holds its filesystem.
export function arrayDevice(view: StorageView, name: string): BlockDevice | undefined {
  const path = `/dev/${name}`
  const find = (ds: BlockDevice[]): BlockDevice | undefined => {
    for (const d of ds) {
      if (d.path === path) return d
      const found = find(d.children)
      if (found) return found
    }
  }
  return find(view.disks)
}

/// RAID levels that grow by one more working member (the agent's rule).
export function growableArray(level: string | null): boolean {
  return level === 'raid1' || level === 'raid5' || level === 'raid6'
}

/// A mounted ext/xfs/btrfs filesystem well smaller than its device (10%, and
/// at least 256 MiB, past what the filesystem keeps for itself): the device
/// grew under it.
export function expandable(d: BlockDevice): boolean {
  if (!d.mountpoints.some((m) => m.startsWith('/')) || !['ext2', 'ext3', 'ext4', 'xfs', 'btrfs'].includes(d.fstype ?? '') || d.fs_size == null) return false
  return d.size - d.fs_size > Math.max(d.size * 0.1, 256 * 2 ** 20)
}
