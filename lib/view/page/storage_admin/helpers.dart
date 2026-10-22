import 'package:server_box/data/model/server/storage.dart';

List<BlockDevice> storageDisks(StorageView view) => [
  for (final disk in view.disks)
    if (disk.kind != 'rom' && disk.size > 0) disk,
];

List<BlockDevice> freeStorageDevices(StorageView view) {
  final out = <BlockDevice>[];
  void walk(BlockDevice device) {
    if (const {'disk', 'part', 'loop'}.contains(device.kind) &&
        device.size > 0 &&
        !view.busy.containsKey(device.path)) {
      out.add(device);
    }
    for (final child in device.children) {
      walk(child);
    }
  }

  for (final disk in storageDisks(view)) {
    walk(disk);
  }
  return out;
}

bool storageOverlaps(StorageView view, String a, String b) {
  if (a == b) return false;
  BlockDevice? find(List<BlockDevice> devices, String path) {
    for (final device in devices) {
      if (device.path == path) return device;
      final child = find(device.children, path);
      if (child != null) return child;
    }
    return null;
  }

  bool under(String top, String path) =>
      find(find(view.disks, top)?.children ?? const [], path) != null;
  return under(a, b) || under(b, a);
}

List<BlockDevice> storageVolumes(BlockDevice disk) {
  final partitions = disk.children.where((d) => d.kind == 'part').toList();
  return partitions.isEmpty ? [disk] : partitions;
}

bool storageMounted(BlockDevice device) =>
    device.mountpoints.any((path) => path.startsWith('/'));

bool storageMountable(BlockDevice device) =>
    device.fstype != null &&
    !const {
      'swap',
      'linux_raid_member',
      'zfs_member',
      'LVM2_member',
      'crypto_LUKS',
    }.contains(device.fstype) &&
    !storageMounted(device);

bool storageExpandable(BlockDevice device) {
  if (!storageMounted(device) ||
      !const {'ext2', 'ext3', 'ext4', 'xfs', 'btrfs'}.contains(device.fstype) ||
      device.fsSize == null) {
    return false;
  }
  return device.size - device.fsSize! >
      (device.size * .1 > 256 * 1024 * 1024
          ? device.size * .1
          : 256 * 1024 * 1024);
}

bool storageGrowablePartition(BlockDevice disk, BlockDevice partition) {
  final parts = disk.children.where((d) => d.kind == 'part').toList();
  if (partition.kind != 'part' || parts.lastOrNull?.path != partition.path) {
    return false;
  }
  final free = disk.size - parts.fold<int>(0, (total, part) => total + part.size);
  return free >
      (disk.size * .01 > 64 * 1024 * 1024
          ? disk.size * .01
          : 64 * 1024 * 1024);
}

int storageMinimum(Object level) => switch (level) {
  0 || 1 || 'mirror' => 2,
  5 || 'raidz1' => 3,
  6 || 10 || 'raidz2' => 4,
  'raidz3' => 5,
  _ => 1,
};

String storageShortName(String path) => path.replaceFirst('/dev/', '');

BlockDevice? storageArrayDevice(StorageView view, String name) {
  final path = '/dev/$name';
  for (final device in view.devices) {
    if (device.path == path) return device;
  }
  return null;
}

bool storageGrowableRaid(String? level) =>
    const {'raid1', 'raid5', 'raid6'}.contains(level);

({bool replace, bool attach, bool remove, bool online}) storagePoolActions(
  StoragePool pool,
  int index,
) {
  const none = (replace: false, attach: false, remove: false, online: false);
  if (index < 0 || index >= pool.vdevs.length) return none;
  final vdev = pool.vdevs[index];
  if (!vdev.name.startsWith('/')) return none;
  if (vdev.section != null) {
    return (
      replace: false,
      attach: false,
      remove: vdev.section == 'spares' || vdev.section == 'cache',
      online: vdev.state == 'OFFLINE',
    );
  }
  final parent = vdev.depth == 0
      ? null
      : pool.vdevs
            .take(index)
            .toList()
            .reversed
            .where((item) => item.depth < vdev.depth && item.section == null)
            .firstOrNull;
  return (
    replace: true,
    attach: vdev.depth == 0 || (parent?.name.startsWith('mirror') ?? false),
    remove: false,
    online: vdev.state == 'OFFLINE',
  );
}
