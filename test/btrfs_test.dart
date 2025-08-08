// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk.dart';

void main() {
  group('BTRFS RAID1 disk parsing', () {
    test('correctly handles BTRFS RAID1 with same UUID', () {
      final disks = Disk.parse(_btrfsRaidJsonOutput);
      expect(disks, isNotEmpty);
      expect(disks.length, 4); // Should have 2 parent disks + 2 BTRFS partitions

      // We should get two distinct disks with the same UUID but different paths
      final nvme1Disk = disks.firstWhere((disk) => disk.path == '/dev/nvme1n1p1');
      final nvme2Disk = disks.firstWhere((disk) => disk.path == '/dev/nvme2n1p1');

      // Both should exist
      expect(nvme1Disk, isNotNull);
      expect(nvme2Disk, isNotNull);

      // They should have the same UUID (since they're part of the same BTRFS volume)
      expect(nvme1Disk.uuid, nvme2Disk.uuid);

      // But they should be treated as distinct disks
      expect(identical(nvme1Disk, nvme2Disk), isFalse);

      // Verify DiskUsage counts physical disks correctly
      final usage = DiskUsage.parse(disks);
      // With our unique path+kname identifier, both disks should be counted
      expect(usage.size, nvme1Disk.size + nvme2Disk.size);
      expect(usage.used, nvme1Disk.used + nvme2Disk.used);
    });
  });
}

// Simulated BTRFS RAID1 lsblk JSON output
const _btrfsRaidJsonOutput = '''
{
  "blockdevices": [
    {
      "name": "nvme1n1",
      "kname": "nvme1n1",
      "path": "/dev/nvme1n1",
      "fstype": null,
      "mountpoint": null,
      "fssize": null,
      "fsused": null,
      "fsavail": null,
      "fsuse%": null,
      "children": [
        {
          "name": "nvme1n1p1",
          "kname": "nvme1n1p1",
          "path": "/dev/nvme1n1p1",
          "fstype": "btrfs",
          "mountpoint": "/mnt/raid",
          "fssize": "500000000000",
          "fsused": "100000000000",
          "fsavail": "400000000000",
          "fsuse%": "20%",
          "uuid": "btrfs-raid-uuid-1234-5678"
        }
      ]
    },
    {
      "name": "nvme2n1",
      "kname": "nvme2n1",
      "path": "/dev/nvme2n1",
      "fstype": null,
      "mountpoint": null,
      "fssize": null,
      "fsused": null,
      "fsavail": null,
      "fsuse%": null,
      "children": [
        {
          "name": "nvme2n1p1",
          "kname": "nvme2n1p1",
          "path": "/dev/nvme2n1p1",
          "fstype": "btrfs",
          "mountpoint": "/mnt/raid",
          "fssize": "500000000000",
          "fsused": "100000000000",
          "fsavail": "400000000000",
          "fsuse%": "20%",
          "uuid": "btrfs-raid-uuid-1234-5678"
        }
      ]
    }
  ]
}
''';
