import 'package:server_box/data/model/server/storage.dart';

List<BlockDevice> storageDisks(StorageView view) => [
  for (final disk in view.disks)
    if (disk.kind != 'rom' && disk.size > 0) disk,
];

List<BlockDevice> storageVolumes(BlockDevice disk) {
  final partitions = disk.children.where((d) => d.kind == 'part').toList();
  return partitions.isEmpty ? [disk] : partitions;
}

String storageShortName(String path) => path.replaceFirst('/dev/', '');

BlockDevice? storageArrayDevice(StorageView view, String name) {
  final path = '/dev/$name';
  for (final device in view.devices) {
    if (device.path == path) return device;
  }
  return null;
}
