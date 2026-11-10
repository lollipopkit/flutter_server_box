import 'package:server_box/src/rust/api/storage.dart';

export 'package:server_box/src/rust/api/storage.dart'
    show
        BlockDevice,
        DiskHealth,
        HealthVerdict,
        MdArray,
        MdMember,
        MdSync,
        Pool,
        PoolLayoutChoice,
        RaidLevelChoice,
        Refusal,
        SelfTest,
        SmartAttribute,
        StorageAction,
        StorageError,
        StorageView,
        Vdev,
        VdevActions;

extension BlockDeviceX on BlockDevice {
  Iterable<BlockDevice> get all sync* {
    yield this;
    for (final child in children) {
      yield* child.all;
    }
  }

  bool get swap => mountpoints.contains('[SWAP]');
}

extension MdArrayX on MdArray {
  bool get degraded => raidDisks != null && workingDisks != null && workingDisks! < raidDisks!;
}

extension StorageViewX on StorageView {
  Iterable<BlockDevice> get devices sync* {
    for (final disk in disks) {
      yield* disk.all;
    }
  }

  BlockDevice? find(String path) {
    for (final device in devices) {
      if (device.path == path) return device;
    }
    return null;
  }
}
