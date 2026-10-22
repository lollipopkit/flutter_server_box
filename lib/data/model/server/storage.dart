/// The machine's storage as `sbm_parser::storage` reports it.
final class BlockDevice {
  const BlockDevice({
    required this.name,
    required this.path,
    required this.kind,
    required this.size,
    required this.model,
    required this.serial,
    required this.rotational,
    required this.transport,
    required this.removable,
    required this.readOnly,
    required this.partType,
    required this.fstype,
    required this.label,
    required this.uuid,
    required this.mountpoints,
    required this.fsSize,
    required this.available,
    required this.used,
    required this.children,
  });

  factory BlockDevice.fromJson(Map<String, Object?> json) => BlockDevice(
    name: json['name'] as String,
    path: json['path'] as String,
    kind: json['kind'] as String,
    size: json['size'] as int,
    model: json['model'] as String?,
    serial: json['serial'] as String?,
    rotational: json['rotational'] as bool,
    transport: json['transport'] as String?,
    removable: json['removable'] as bool,
    readOnly: json['read_only'] as bool,
    partType: json['part_type'] as String?,
    fstype: json['fstype'] as String?,
    label: json['label'] as String?,
    uuid: json['uuid'] as String?,
    mountpoints: (json['mountpoints'] as List).cast<String>(),
    fsSize: json['fs_size'] as int?,
    available: json['available'] as int?,
    used: json['used'] as int?,
    children: [
      for (final child in json['children'] as List)
        BlockDevice.fromJson(child as Map<String, Object?>),
    ],
  );

  final String name;
  final String path;
  final String kind;
  final int size;
  final String? model;
  final String? serial;
  final bool rotational;
  final String? transport;
  final bool removable;
  final bool readOnly;
  final String? partType;
  final String? fstype;
  final String? label;
  final String? uuid;
  final List<String> mountpoints;
  final int? fsSize;
  final int? available;
  final int? used;
  final List<BlockDevice> children;

  Iterable<BlockDevice> get all sync* {
    yield this;
    for (final child in children) {
      yield* child.all;
    }
  }

  bool get mounted => mountpoints.any((point) => point.startsWith('/'));
  bool get swap => mountpoints.contains('[SWAP]');
}

final class MdArray {
  const MdArray({
    required this.name,
    required this.state,
    required this.level,
    required this.members,
    required this.raidDisks,
    required this.workingDisks,
    required this.sync,
  });

  factory MdArray.fromJson(Map<String, Object?> json) {
    final sync = json['sync'];
    return MdArray(
      name: json['name'] as String,
      state: json['state'] as String,
      level: json['level'] as String?,
      members: [
        for (final member in json['members'] as List)
          MdMember.fromJson(member as Map<String, Object?>),
      ],
      raidDisks: json['raid_disks'] as int?,
      workingDisks: json['working_disks'] as int?,
      sync: sync == null ? null : MdSync.fromJson(sync as Map<String, Object?>),
    );
  }

  final String name;
  final String state;
  final String? level;
  final List<MdMember> members;
  final int? raidDisks;
  final int? workingDisks;
  final MdSync? sync;

  bool get degraded => raidDisks != null && workingDisks != null && workingDisks! < raidDisks!;
}

final class MdMember {
  const MdMember({required this.name, required this.faulty, required this.spare});

  factory MdMember.fromJson(Map<String, Object?> json) => MdMember(
    name: json['name'] as String,
    faulty: json['faulty'] as bool,
    spare: json['spare'] as bool,
  );

  final String name;
  final bool faulty;
  final bool spare;
}

final class MdSync {
  const MdSync({required this.action, required this.permille, required this.finish});

  factory MdSync.fromJson(Map<String, Object?> json) => MdSync(
    action: json['action'] as String,
    permille: json['permille'] as int,
    finish: json['finish'] as String?,
  );

  final String action;
  final int permille;
  final String? finish;
}

final class StoragePool {
  const StoragePool({
    required this.name,
    required this.size,
    required this.allocated,
    required this.free,
    required this.health,
    required this.scan,
    this.scanning = false,
    required this.vdevs,
  });

  factory StoragePool.fromJson(Map<String, Object?> json) => StoragePool(
    name: json['name'] as String,
    size: json['size'] as int,
    allocated: json['allocated'] as int,
    free: json['free'] as int,
    health: json['health'] as String,
    scan: json['scan'] as String?,
    scanning: json['scanning'] as bool? ?? false,
    vdevs: [
      for (final vdev in json['vdevs'] as List)
        StorageVdev.fromJson(vdev as Map<String, Object?>),
    ],
  );

  final String name;
  final int size;
  final int allocated;
  final int free;
  final String health;
  final String? scan;

  /// A scrub or resilver is running now (Rust reads it from `scan`).
  final bool scanning;
  final List<StorageVdev> vdevs;
}

final class StorageVdev {
  const StorageVdev({
    required this.name,
    required this.state,
    required this.depth,
    required this.errors,
    required this.section,
  });

  factory StorageVdev.fromJson(Map<String, Object?> json) => StorageVdev(
    name: json['name'] as String,
    state: json['state'] as String,
    depth: json['depth'] as int,
    errors: json['errors'] as int,
    section: json['section'] as String?,
  );

  final String name;
  final String state;
  final int depth;
  final int errors;
  final String? section;
}

final class StorageView {
  const StorageView({
    required this.disks,
    required this.busy,
    required this.system,
    required this.arrays,
    required this.pools,
    required this.tools,
  });

  factory StorageView.fromJson(Map<String, Object?> json) => StorageView(
    disks: [
      for (final disk in json['disks'] as List)
        BlockDevice.fromJson(disk as Map<String, Object?>),
    ],
    busy: (json['busy'] as Map).cast<String, String>(),
    system: (json['system'] as List).cast<String>(),
    arrays: [
      for (final array in json['arrays'] as List)
        MdArray.fromJson(array as Map<String, Object?>),
    ],
    pools: [
      for (final pool in json['pools'] as List)
        StoragePool.fromJson(pool as Map<String, Object?>),
    ],
    tools: (json['tools'] as List).cast<String>(),
  );

  final List<BlockDevice> disks;
  final Map<String, String> busy;
  final List<String> system;
  final List<MdArray> arrays;
  final List<StoragePool> pools;
  final List<String> tools;

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

final class DiskHealth {
  const DiskHealth({
    required this.device,
    required this.supported,
    required this.asleep,
    required this.passed,
    required this.temperature,
    required this.powerOnHours,
    required this.badSectors,
    required this.testing,
    required this.lastTest,
    required this.attributes,
    required this.tests,
  });

  factory DiskHealth.fromJson(Map<String, Object?> json) => DiskHealth(
    device: json['device'] as String,
    supported: json['supported'] as bool,
    asleep: json['asleep'] as bool,
    passed: json['passed'] as bool?,
    temperature: (json['temperature'] as num?)?.toDouble(),
    powerOnHours: json['power_on_hours'] as int?,
    badSectors: json['bad_sectors'] as int?,
    testing: json['testing'] as int?,
    lastTest: json['last_test'] == null
        ? null
        : SelfTest.fromJson(json['last_test'] as Map<String, Object?>),
    attributes: [
      for (final item in (json['attributes'] as List? ?? const []))
        SmartAttribute.fromJson(item as Map<String, Object?>),
    ],
    tests: [
      for (final item in (json['tests'] as List? ?? const []))
        SelfTest.fromJson(item as Map<String, Object?>),
    ],
  );

  final String device;
  final bool supported;
  final bool asleep;
  final bool? passed;
  final double? temperature;
  final int? powerOnHours;
  final int? badSectors;
  final int? testing;
  final SelfTest? lastTest;
  final List<SmartAttribute> attributes;
  final List<SelfTest> tests;
}

final class SmartAttribute {
  const SmartAttribute({
    required this.id,
    required this.name,
    required this.value,
    required this.worst,
    required this.threshold,
    required this.raw,
    required this.failing,
  });

  factory SmartAttribute.fromJson(Map<String, Object?> json) => SmartAttribute(
    id: json['id'] as int?,
    name: json['name'] as String,
    value: json['value'] as int?,
    worst: json['worst'] as int?,
    threshold: json['thresh'] as int?,
    raw: json['raw'] as String,
    failing: json['failing'] as bool,
  );

  final int? id;
  final String name;
  final int? value;
  final int? worst;
  final int? threshold;
  final String raw;
  final bool failing;
}

final class SelfTest {
  const SelfTest({required this.long, required this.outcome, required this.hours});

  factory SelfTest.fromJson(Map<String, Object?> json) => SelfTest(
    long: json['long'] as bool,
    outcome: json['outcome'] as String,
    hours: json['hours'] as int?,
  );

  final bool long;
  final String outcome;
  final int? hours;
}

/// The app's storage API payload, encoded using the Rust enum's serde names.
final class StorageAction {
  const StorageAction._(this.json);

  final Map<String, Object?> json;

  factory StorageAction.partition(String device) => StorageAction._({'action': 'partition', 'device': device});
  factory StorageAction.format(String device, String fstype, {String? label, bool encrypt = false}) => StorageAction._({
    'action': 'format', 'device': device, 'fstype': fstype, 'label': label, 'encrypt': encrypt,
  });
  factory StorageAction.mount(String device, String mountpoint, {bool persist = true, bool own = true}) => StorageAction._({
    'action': 'mount', 'device': device, 'mountpoint': mountpoint, 'persist': persist, 'own': own,
  });
  factory StorageAction.unmount(String mountpoint) => StorageAction._({'action': 'unmount', 'mountpoint': mountpoint});
  factory StorageAction.createRaid(String name, int level, List<String> devices) => StorageAction._({
    'action': 'createRaid', 'name': name, 'level': level, 'devices': devices,
  });
  factory StorageAction.addToRaid(String array, String device) => StorageAction._({'action': 'addToRaid', 'array': array, 'device': device});
  factory StorageAction.removeFromRaid(String array, String device) => StorageAction._({'action': 'removeFromRaid', 'array': array, 'device': device});
  factory StorageAction.deleteRaid(String array) => StorageAction._({'action': 'deleteRaid', 'array': array});
  factory StorageAction.growRaid(String array, String device) => StorageAction._({'action': 'growRaid', 'array': array, 'device': device});
  factory StorageAction.createPool(String name, String layout, List<String> devices) => StorageAction._({
    'action': 'createPool', 'name': name, 'layout': layout, 'devices': devices,
  });
  factory StorageAction.addToPool(String name, String layout, List<String> devices) => StorageAction._({
    'action': 'addToPool', 'name': name, 'layout': layout, 'devices': devices,
  });
  factory StorageAction.scrubPool(String name) => StorageAction._({'action': 'scrubPool', 'name': name});
  factory StorageAction.destroyPool(String name) => StorageAction._({'action': 'destroyPool', 'name': name});
  factory StorageAction.replaceInPool(String name, String old, String device) => StorageAction._({
    'action': 'replaceInPool', 'name': name, 'old': old, 'new': device,
  });
  factory StorageAction.attachToPool(String name, String existing, String device) => StorageAction._({
    'action': 'attachToPool', 'name': name, 'existing': existing, 'new': device,
  });
  factory StorageAction.addSpare(String name, List<String> devices) => StorageAction._({'action': 'addSpare', 'name': name, 'devices': devices});
  factory StorageAction.removeFromPool(String name, String device) => StorageAction._({'action': 'removeFromPool', 'name': name, 'device': device});
  factory StorageAction.onlineInPool(String name, String device) => StorageAction._({'action': 'onlineInPool', 'name': name, 'device': device});
  factory StorageAction.expandFilesystem(String device) => StorageAction._({'action': 'expandFilesystem', 'device': device});
  factory StorageAction.growPartition(String device) => StorageAction._({'action': 'growPartition', 'device': device});
  factory StorageAction.unlock(String device) => StorageAction._({'action': 'unlock', 'device': device});
  factory StorageAction.lock(String device) => StorageAction._({'action': 'lock', 'device': device});
  factory StorageAction.smartTest(String device, {bool long = false}) => StorageAction._({'action': 'smartTest', 'device': device, 'long': long});

  Map<String, Object?> toJson() => Map<String, Object?>.from(json);
}

final class StorageRefusal {
  const StorageRefusal({required this.status, required this.error, this.device, this.why});

  factory StorageRefusal.fromJson(Map<String, Object?> json) => StorageRefusal(
    status: json['status'] as int,
    error: json['error'] as String,
    device: json['device'] as String?,
    why: json['why'] as String?,
  );

  final int status;
  final String error;
  final String? device;
  final String? why;
}
