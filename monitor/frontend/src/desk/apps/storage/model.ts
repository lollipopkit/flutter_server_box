/// What the Storage app draws from `/storage`: pure, tested in
/// `tests/storage.test.ts`.

import type { BlockDevice, StorageView } from '../../../types'

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
