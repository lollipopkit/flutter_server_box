/// The Virtualization tab's Hardware and Settings views over a scripted
/// host: the groups for a VM and a container, a CPU edit held as a draft
/// until Save, pending changes shown on what they change with their revert
/// and the restart banner, a disk removed behind its confirmation, the
/// dashed add rows, the index on a wide window, and the Settings view's
/// name, note, start and protection, and its two-press delete.
///
/// As in `virt_tab_test.dart`, the providers are replaced, not the backends.
library;

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/hardware.dart';
import 'package:server_box/view/page/virt/tab.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/segment.dart';
import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _pve = 'srv-pve';

VirtGuest _guest(
  String id,
  String name, {
  VirtGuestKind kind = VirtGuestKind.qemu,
  VirtGuestState state = VirtGuestState.running,
  required int vmid,
}) => VirtGuest(
  id: id,
  name: name,
  kind: kind,
  state: state,
  vmid: vmid,
  node: 'pve',
  vcpu: 2,
  actions: VirtPowerAction.offered(
    state,
    pause: kind == VirtGuestKind.qemu,
  ),
);

/// The host's kind and nodes: PVE with one node unless a test says so.
var _hostKind = VirtHostKind.pve;
var _nodes = const [VirtNode(name: 'pve')];

VirtSnapshot _snapshot() => VirtSnapshot(
  host: VirtHost(
    serverId: _pve,
    kind: _hostKind,
    version: '9.2',
    nodes: _nodes,
  ),
  guests: [
    _guest('qemu/100', 'web-01', vmid: 100),
    _guest('lxc/200', 'dns-01', kind: VirtGuestKind.lxc, vmid: 200),
    _guest('qemu/101', 'db-02', state: VirtGuestState.stopped, vmid: 101),
  ],
  capabilities: const VirtCapabilities(
    lxc: true,
    storage: true,
    network: true,
    create: true,
    hardware: true,
    hardwareRevert: true,
    clone: true,
    linkedClone: true,
    cloneTarget: true,
    backup: true,
    backupJobs: true,
  ),
);

/// On `local`: one backup of `web-01`, and the job that takes it.
final _backup = VirtBackup(
  id: 'local:backup/vzdump-qemu-100-2026_09_24-02_00_00.vma.zst',
  storage: 'local',
  node: 'pve',
  vmid: 100,
  createdAt: DateTime(2026, 9, 24, 2),
  size: 18 << 30,
  format: 'vma.zst',
  kind: VirtGuestKind.qemu,
);
const _job = VirtBackupJob(
  id: 'nightly',
  schedule: '02:00',
  storage: 'local',
  mode: 'snapshot',
  compress: 'zstd',
  keep: 'keep-last=7',
  vmids: [100],
);
/// A job that takes a pool's guests: the app lists no pools, so it can only
/// keep this one.
const _poolJob = VirtBackupJob(
  id: 'by-pool',
  schedule: 'sat 03:00',
  storage: 'local',
  pool: 'prod',
);
const _pool = VirtStoragePool(
  id: 'pve/local',
  name: 'local',
  node: 'pve',
  type: 'dir',
  content: ['backup', 'iso'],
);

/// Running with a vCPU added and its boot order changed since the start.
const _vm = VirtHardware(
  kind: VirtGuestKind.qemu,
  running: true,
  cpu: VirtHwCpu(sockets: 1, cores: 2, type: 'host'),
  memory: VirtHwMemory(mib: 2048, minMib: 1024, balloon: true),
  disks: [
    VirtHwDisk(
      key: 'scsi0',
      kind: VirtHwDiskKind.disk,
      source: 'local-lvm:vm-100-disk-0',
      storage: 'local-lvm',
      size: 8 << 30,
      bus: 'scsi',
    ),
    VirtHwDisk(key: 'ide2', kind: VirtHwDiskKind.cdrom, bus: 'ide'),
  ],
  nics: [
    VirtHwNic(
      key: 'net0',
      mac: 'BC:24:11:65:B0:B5',
      source: 'vmbr0',
      model: 'virtio',
      firewall: true,
    ),
  ],
  boot: ['scsi0', 'ide2', 'net0'],
  firmware: VirtHwFirmware(uefi: true, secureBoot: true, varsStorage: 'local-lvm'),
  display: VirtHwDisplay(gpu: 'std'),
  devices: [
    VirtHwDevice(key: 'usb0', kind: VirtHwDeviceKind.usb, detail: '0bda:b023'),
    VirtHwDevice(key: 'tpmstate0', kind: VirtHwDeviceKind.tpm, detail: 'TPM v2.0'),
  ],
  support: VirtHwSupport(
    buses: ['scsi', 'virtio', 'sata', 'ide'],
    caches: ['default', 'none', 'writeback', 'writethrough', 'directsync', 'unsafe'],
    nicModels: ['virtio', 'e1000', 'e1000e', 'rtl8139', 'vmxnet3'],
    mac: true,
    gpus: ['std', 'virtio', 'qxl', 'vmware', 'cirrus', 'none'],
    uefi: true,
    secureBoot: true,
    tpm: true,
    usb: true,
    pci: true,
  ),
  pending: [
    VirtPendingField(key: 'cores', current: '1', pending: '2'),
    VirtPendingField(key: 'boot', current: 'order=scsi0', pending: 'order=scsi0;ide2;net0'),
  ],
  autostart: true,
  name: 'web-01',
  description: 'the web tier',
  protection: false,
  revision: 'digest-1',
  limits: VirtHwLimits(hostCpus: 8, hostMemoryBytes: 16 << 30),
  cpuTypes: ['host', 'x86-64-v3'],
  configText: 'boot: order=scsi0;ide2;net0\ncores: 2',
);

const _ct = VirtHardware(
  kind: VirtGuestKind.lxc,
  running: true,
  cpu: VirtHwCpu(sockets: 1, cores: 1),
  memory: VirtHwMemory(mib: 512, swapMib: 512),
  disks: [
    VirtHwDisk(
      key: 'rootfs',
      kind: VirtHwDiskKind.rootfs,
      source: 'local-lvm:vm-200-disk-0',
      storage: 'local-lvm',
      size: 4 << 30,
    ),
  ],
  nics: [VirtHwNic(key: 'net0', source: 'vmbr0', name: 'eth0')],
  name: 'dns-01',
  protection: false,
  pending: [VirtPendingField(key: 'hostname', current: 'dns', pending: 'dns-01')],
  revision: 'digest-2',
);

/// Stopped, and protected.
const _stopped = VirtHardware(
  kind: VirtGuestKind.qemu,
  running: false,
  cpu: VirtHwCpu(sockets: 1, cores: 1),
  memory: VirtHwMemory(mib: 1024, balloon: true),
  disks: [
    VirtHwDisk(
      key: 'scsi0',
      kind: VirtHwDiskKind.disk,
      source: 'local-lvm:vm-101-disk-0',
      size: 4 << 30,
      bus: 'scsi',
    ),
  ],
  boot: ['scsi0'],
  name: 'db-02',
  protection: true,
  revision: 'digest-3',
  // An EFI disk left from before: switching back finds where it goes.
  firmware: VirtHwFirmware(uefi: false, varsStorage: 'local-lvm'),
  display: VirtHwDisplay(protocol: 'vnc', listen: '0.0.0.0', gpu: 'virtio'),
  // As libvirt reports one: listen address and protocol to choose.
  support: VirtHwSupport(
    buses: ['virtio', 'scsi', 'sata'],
    caches: ['default', 'none', 'writeback'],
    nicModels: ['virtio', 'e1000e'],
    mac: true,
    protocols: ['vnc', 'spice'],
    listen: true,
    gpus: ['virtio', 'vga'],
    uefi: true,
    secureBoot: true,
    pci: true,
  ),
);

var _hostDevs = const VirtHostDevices();

/// Whether listing the host's devices fails, and how often it was asked.
VirtErr? _hostDevsError;

/// What the next hardware change fails with, once.
VirtErr? _changeError;
var _hostDevReads = 0;

/// Whether listing the storages, or a storage's volumes, fails.
var _poolsFail = false;
var _volumesFail = false;

/// The backup jobs and the storages they can write to, as the host has them
/// now; a gate holds `backup` until the test opens it.
var _jobList = const [_job];
var _backupPools = const [_pool];
Completer<void>? _backupGate;
final _jobEdits = <VirtBackupJobEdit>[];
final _clones = <VirtCloneRequest>[];

/// How often the guest's detail was read; a gate holds `delete`.
var _detailReads = 0;
Completer<void>? _deleteGate;

const _ciRead = VirtCloudInitState(
  user: 'sbxe',
  sshKeys: ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOld old@x'],
  address: '10.0.0.5/24',
  gateway: '10.0.0.1',
  passwordSet: true,
  network: true,
  revision: 'd1',
);
var _ci = _ciRead;
var _ciReads = 0;
final _ciEdits = <(VirtCloudInitState, VirtCloudInitEdit)>[];

final _hardware = <String, VirtHardware>{};
final _changes = <(String, VirtHwChange)>[];
final _calls = <String>[];

class _FakeHosts extends VirtHosts {
  @override
  VirtHostsState build() => VirtHostsState(hosts: {_pve: _hostKind});

  @override
  Future<void> probeAll({
    bool force = false,
    bool onlyConnected = false,
  }) async {}
}

class _FakeHost extends VirtHostNotifier {
  @override
  VirtHostState build(String serverId) => VirtHostState(
    serverId: _pve,
    kind: _hostKind,
    data: _snapshot(),
  );

  @override
  Future<void> refresh({bool auto = false}) async {}

  @override
  Future<VirtGuestDetail> detail(String guestId) async {
    _detailReads++;
    return const VirtGuestDetail();
  }

  @override
  Future<List<VirtStats>> history(
    String guestId, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => const [];

  /// ISOs only: no disk goes here.
  @override
  Future<List<VirtStoragePool>> storagePools() async => _poolsFail
      ? throw const VirtErr(type: VirtErrType.unreachable, message: 'pools')
      : const [
    VirtStoragePool(
      id: 'pve/local',
      name: 'local',
      node: 'pve',
      type: 'dir',
      content: ['iso'],
    ),
  ];

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async => _volumesFail
      ? throw const VirtErr(type: VirtErrType.unreachable, message: 'volumes')
      : const [
    VirtVolume(id: 'local:iso/debian-13.iso', name: 'debian-13.iso', content: 'iso'),
  ];

  @override
  Future<List<VirtNetwork>> networks() async => const [
    VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
  ];

  @override
  Future<VirtHardware> hardware(String guestId) async => _hardware[guestId]!;

  @override
  Future<VirtHwOutcome> changeHardware(
    String guestId,
    VirtHardware base,
    VirtHwChange change,
  ) async {
    // What PVE's digest and the libvirt backend's revision check do.
    // Before the digest: a host out of reach never gets to compare it.
    if (_changeError case final e?) {
      _changeError = null;
      throw e;
    }
    if (base.revision != _hardware[guestId]!.revision) {
      throw const VirtErr(type: VirtErrType.conflict);
    }
    _changes.add((guestId, change));
    return const VirtHwOutcome();
  }

  @override
  Future<VirtHostDevices> hostDevices(String guestId) async {
    _hostDevReads++;
    if (_hostDevsError case final e?) throw e;
    return _hostDevs;
  }

  @override
  Future<VirtCloudInitState> cloudInit(String guestId) async {
    _ciReads++;
    return _ci;
  }

  @override
  Future<void> setCloudInit(
    String guestId,
    VirtCloudInitState base,
    VirtCloudInitEdit edit,
  ) async => _ciEdits.add((base, edit));

  @override
  Future<void> restartToApply(String guestId) async =>
      _calls.add('restart $guestId');

  @override
  Future<void> delete(String guestId, {bool removeDisks = true}) async {
    await _deleteGate?.future;
    _calls.add('delete $guestId disks=$removeDisks');
  }

  @override
  Future<String> clone(String guestId, VirtCloneRequest request) async {
    _clones.add(request);
    _calls.add('clone $guestId ${request.name} full=${request.full}');
    return 'qemu/150';
  }

  @override
  Future<List<VirtBackup>> backups(String guestId) async =>
      guestId == 'qemu/100' || guestId == 'qemu/101'
      ? [_backup.copyWith(vmid: int.parse(guestId.split('/').last))]
      : const [];

  @override
  Future<void> makeTemplate(String guestId) async =>
      _calls.add('template $guestId');

  @override
  Future<List<VirtBackupJob>> backupJobs(String guestId) async => _jobList;

  @override
  Future<List<VirtBackupJob>> allBackupJobs() async => [..._jobList, _poolJob];

  @override
  Future<void> editBackupJob(
    VirtBackupJobEdit edit, {
    bool remove = false,
  }) async {
    _jobEdits.add(edit);
    _calls.add(
      'job ${edit.id} remove=$remove ${edit.schedule} '
      'pool=${edit.pool} all=${edit.all} vmids=${edit.vmids}',
    );
  }

  @override
  Future<VirtScheduleCheck> checkSchedule(String schedule) async =>
      const VirtScheduleCheck();

  @override
  Future<List<VirtStoragePool>> backupStorages(String guestId) async =>
      const [_pool];

  @override
  Future<List<VirtStoragePool>> allBackupStorages() async => _backupPools;

  @override
  Future<void> backup(String guestId, VirtBackupRequest request) async {
    await _backupGate?.future;
    _calls.add('backup $guestId ${request.storage} ${request.mode}');
  }

  @override
  Future<void> runBackupJob(VirtBackupJob job) async =>
      _calls.add('run job ${job.id}');

  @override
  Future<void> restoreBackup(
    String guestId,
    VirtBackup backup, {
    int? vmid,
    String? storage,
  }) async => _calls.add('restore $guestId vmid=$vmid storage=$storage');

  @override
  Future<void> editBackup(VirtBackup backup, VirtBackupEdit edit) async =>
      _calls.add('edit backup ${backup.id} protected=${edit.protected}');

  @override
  Future<void> deleteBackup(String guestId, VirtBackup backup) async =>
      _calls.add('delete backup $guestId');
}

void main() {
  setUpAll(initRustLibForTest);

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(
      spiFixture(id: _pve, name: 'pve-host', ip: 'h1', autoConnect: false),
    );
    Stores.pve.put(_pve, const PveConfig(addr: 'https://localhost:8006'));
    _hardware
      ..clear()
      ..['qemu/100'] = _vm
      ..['lxc/200'] = _ct
      ..['qemu/101'] = _stopped;
    _changes.clear();
    _calls.clear();
    _hostDevs = const VirtHostDevices();
    _hostDevsError = null;
    _changeError = null;
    _hostDevReads = 0;
    _poolsFail = false;
    _volumesFail = false;
    _jobList = const [_job];
    _backupPools = const [_pool];
    _backupGate = null;
    _jobEdits.clear();
    _clones.clear();
    _detailReads = 0;
    _deleteGate = null;
    _hostKind = VirtHostKind.pve;
    _nodes = const [VirtNode(name: 'pve')];
    _ciEdits.clear();
    _ci = _ciRead;
    _ciReads = 0;
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<ProviderContainer> open(
    WidgetTester tester,
    String guest, {
    bool wide = false,
    String? segmentLabel,
  }) async {
    tester.view.physicalSize = wide
        ? const Size(1400, 900)
        : const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        virtHostsProvider.overrideWith(_FakeHosts.new),
        virtHostProvider.overrideWith2((_) => _FakeHost()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            ...app_locale.appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const VirtTabPage();
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await _settle(tester);
    await tester.tap(find.text(guest));
    await _settle(tester);
    await tester.tap(segment(segmentLabel ?? app_locale.l10n.virtHardware));
    await _settle(tester);
    return container;
  }

  Finder text(String s) => find.text(s, skipOffstage: false);

  /// A group's heading, as `GroupTitle` prints it.
  Finder title(String s) => text(s.toUpperCase());

  /// Scrolled to first: the groups are one long list.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await _settle(tester);
  }

  testWidgets('a VM: its groups, what is pending, and the restart banner', (
    tester,
  ) async {
    await open(tester, 'web-01');
    final l10n = app_locale.l10n;
    for (final t in [
      l10n.virtHwProcessor,
      l10n.virtHwNics,
      l10n.virtHwDevices,
      l10n.virtHwDisplay,
      l10n.virtHwBoot,
      l10n.virtHwConfigFile,
    ]) {
      expect(title(t), findsOneWidget, reason: t);
    }
    // On what it changes, not in a list of its own: the pending vCPUs in
    // the processor group, the boot order's in the boot group.
    expect(_key('hw:pending:cores'), findsOneWidget);
    expect(
      tester.getRect(_key('hw:pending:cores')).top,
      lessThan(tester.getRect(_key('hw:step:memory')).top),
    );
    expect(
      tester.getRect(_key('hw:pending:boot')).top,
      greaterThan(tester.getRect(_key('hw:boot:scsi0')).top),
    );
    expect(_key('hw:pending-banner'), findsOneWidget);

    await tap(tester, _key('hw:revert:cores'));
    final (id, change) = _changes.single;
    expect(id, 'qemu/100');
    expect((change as VirtHwRevert).keys, ['cores']);

    // Every one at once, from the banner: a dialog first, showing what is
    // discarded.
    _changes.clear();
    await tester.tap(_key('hw:revert-all'));
    await _settle(tester);
    expect(find.text(libL10n.ok), findsOneWidget);
    await tester.tap(find.text(libL10n.ok));
    await _settle(tester);
    expect((_changes.single.$2 as VirtHwRevert).keys, ['cores', 'boot']);

    await tester.tap(_key('hw:restart-now'));
    await _settle(tester);
    expect(_calls, ['restart qemu/100']);
  });

  testWidgets('adding is a dashed row, as the design draws room for one', (
    tester,
  ) async {
    await open(tester, 'web-01');
    for (final k in ['hw:disk:add', 'hw:nic:add']) {
      expect(
        find.ancestor(of: _key(k), matching: find.byType(DashedBorder)),
        findsOneWidget,
        reason: k,
      );
    }
  });

  testWidgets('a CPU edit waits for Save, and Cancel drops it', (tester) async {
    await open(tester, 'web-01');
    final inc = _key('hw:step:cores:inc');
    final save = _key('hw:cpu:save');
    expect(save, findsNothing);

    await tap(tester, inc);
    expect(_changes, isEmpty, reason: 'a draft until Save');
    expect(save, findsOneWidget);
    await tap(tester, find.text(libL10n.cancel));
    expect(save, findsNothing);

    await tap(tester, inc);
    await tap(tester, save);
    final change = _changes.single.$2 as VirtHwSetCpu;
    expect((change.sockets, change.cores, change.online), (1, 3, null));
    expect(save, findsNothing);
  });

  testWidgets('a disk removed only after its confirmation, volume on request', (
    tester,
  ) async {
    await open(tester, 'web-01');
    final row = _key('hw:disc:scsi0');
    await tap(tester, row);
    final detach = _key('hw:disk:scsi0:detach');
    await tap(tester, detach);
    expect(_changes, isEmpty);
    await tester.tap(_key('hw:disk:delete-volume'));
    await _settle(tester);
    await tester.tap(find.text(libL10n.ok));
    await _settle(tester);
    final change = _changes.single.$2 as VirtHwRemoveDisk;
    expect((change.key, change.deleteVolume), ('scsi0', true));
  });

  testWidgets('a container: "Resources", no CD-ROM or boot order', (
    tester,
  ) async {
    await open(
      tester,
      'dns-01',
      segmentLabel: app_locale.l10n.virtHwResources,
    );
    final l10n = app_locale.l10n;
    expect(title(l10n.virtHwDisksLxc), findsOneWidget);
    expect(text(l10n.virtHwSwap), findsWidgets);
    expect(title(l10n.virtHwCdrom), findsNothing);
    expect(text(l10n.virtHwBootOrder), findsNothing);
    expect(_key('hw:boot:up'), findsNothing);
    // Its hostname waits for a restart: said in Settings, where it is set,
    // and above the tabs.
    expect(_key('hw:pending:hostname'), findsNothing);
    expect(_key('hw:pending-banner'), findsOneWidget);
  });

  testWidgets('a wide window indexes the groups', (tester) async {
    await open(tester, 'web-01', wide: true);
    for (final g in ['cpu', 'mem', 'disks', 'nics', 'devices', 'display', 'boot', 'config']) {
      expect(_key('hw:index:$g'), findsOneWidget, reason: g);
    }
    expect(tester.getRect(_key('hw:disc:config')).top, greaterThan(900));
    await tester.tap(_key('hw:index:config'));
    await _settle(tester);
    // Scrolled to, in the pane: not merely built.
    expect(tester.getRect(_key('hw:disc:config')).top, lessThan(900));
  });

  testWidgets('the index seam is the shared divider, and drags', (tester) async {
    await open(tester, 'web-01', wide: true);
    final seam = find.descendant(
      of: find.byType(VirtHardwareView),
      matching: find.byType(PaneDivider),
    );
    expect(seam, findsOneWidget);
    final index = _key('hw:index:cpu');
    final before = tester.getRect(index).width;
    await tester.drag(seam, const Offset(60, 0));
    await _settle(tester);
    expect(tester.getRect(index).width, closeTo(before + 60, 1));
    // Held to its bounds, however far it is pulled.
    await tester.drag(seam, const Offset(-600, 0));
    await _settle(tester);
    expect(tester.getRect(index).width, lessThan(before));
    expect(tester.getRect(index).width, greaterThan(100));
  });

  group('clone', () {
    Future<void> openSettings(WidgetTester tester, String guest) =>
        open(tester, guest, segmentLabel: libL10n.setting);
    Finder input(String key) => find.descendant(
      of: _key(key),
      matching: find.byType(TextField),
    );

    testWidgets('a full clone named after the guest; a name taken is not', (
      tester,
    ) async {
      await openSettings(tester, 'web-01');
      expect(title(libL10n.clone), findsOneWidget);
      expect(
        tester.widget<TextField>(input('clone:name')).controller!.text,
        'web-01-clone',
      );
      // Not a template: PVE links nothing to it, so full it stays.
      expect(text(app_locale.l10n.virtCloneFullOnly), findsOneWidget);
      final full = find.descendant(
        of: _key('hw:toggle:clone:full'),
        matching: find.byType(SwitchX),
      );
      expect(tester.widget<SwitchX>(full).onChanged, isNull);

      await tester.enterText(input('clone:name'), 'dns-01');
      await _settle(tester);
      expect(text(app_locale.l10n.virtCreateNameTaken), findsOneWidget);
      expect(tester.widget<Btn>(_key('clone:go')).onTap, isNull);

      await tester.enterText(input('clone:name'), 'web-02');
      await _settle(tester);
      await tap(tester, _key('clone:go'));
      expect(_calls, contains('clone qemu/100 web-02 full=true'));
    });
  });

  group('backups', () {
    Future<void> openBackups(WidgetTester tester, String guest) =>
        open(tester, guest, segmentLabel: libL10n.backup);

    testWidgets('the plan, backing up now, and a running guest not restored',
        (tester) async {
      await openBackups(tester, 'web-01');
      expect(title(app_locale.l10n.virtBackupPlan), findsOneWidget);
      // One line until opened.
      expect(text('keep-last=7'), findsNothing);
      await tap(tester, _key('hw:disc:plan:nightly'));
      expect(text('keep-last=7'), findsOneWidget);
      expect(text(app_locale.l10n.virtBackupLiveTip), findsOneWidget);

      await tap(tester, _key('backup:now'));
      expect(_calls, contains('backup qemu/100 local snapshot'));

      await tap(tester, _key('hw:disc:backup:${_backup.id}'));
      expect(text(_backup.fileName), findsOneWidget);
      expect(text(app_locale.l10n.virtBackupRestoreOverwrites), findsOneWidget);
      expect(
        tester.widget<Btn>(_key('backup:${_backup.id}:restore')).onTap,
        isNull,
        reason: 'running',
      );
    });

    testWidgets('a stopped guest: restore and delete each asked twice', (
      tester,
    ) async {
      await openBackups(tester, 'db-02');
      expect(text(app_locale.l10n.virtBackupStoppedTip), findsOneWidget);
      await tap(tester, _key('hw:disc:backup:${_backup.id}'));
      final restore = _key('backup:${_backup.id}:restore');
      await tap(tester, restore);
      expect(_calls, isEmpty, reason: 'asked first');
      expect(text(app_locale.l10n.virtBackupRestoreAgain), findsOneWidget);
      await tap(tester, restore);
      expect(_calls, ['restore qemu/101 vmid=null storage=null']);

      // Still open after the list is read again.
      _calls.clear();
      final delete = _key('backup:${_backup.id}:delete');
      await tap(tester, delete);
      expect(_calls, isEmpty);
      await tap(tester, delete);
      expect(_calls, ['delete backup qemu/101']);
    });

    Finder field(String key) => find.descendant(
      of: _key(key),
      matching: find.byType(TextField),
    );

    testWidgets('a plan for this guest alone, made in place', (tester) async {
      _jobList = const [];
      await openBackups(tester, 'dns-01');
      expect(text(app_locale.l10n.virtBackupNoPlan), findsOneWidget);

      await tap(tester, _key('plan:new'));
      // The Backup section's rows, less the node and the guests.
      expect(_key('hw:seg:plan:new:storage'), findsOneWidget);
      expect(_key('hw:seg:job:all'), findsNothing);
      expect(
        tester.widget<Btn>(_key('plan:new:save')).onTap,
        isNull,
        reason: 'no schedule yet',
      );

      await tester.enterText(field('plan:new:schedule'), 'sat 03:00');
      await _settle(tester);
      await tap(tester, _segOpt('plan:new:mode', 'stop'));
      await tester.enterText(field('plan:new:prune'), 'keep-last=3');
      await _settle(tester);
      await tap(tester, _key('plan:new:save'));

      final edit = _jobEdits.single;
      expect(edit.isNew, isTrue);
      expect(edit.id, isNull);
      expect((edit.all, edit.pool), (false, null));
      expect(edit.vmids, [200]);
      expect(edit.exclude, isEmpty);
      // Runs wherever the guest is, onto the storage its row showed.
      expect((edit.node, edit.storage), (null, 'local'));
      expect((edit.schedule, edit.mode, edit.prune), (
        'sat 03:00',
        'stop',
        'keep-last=3',
      ));
      // Closed once the host has it.
      expect(_key('plan:new:schedule'), findsNothing);
    });

    testWidgets('a plan of this guest alone: edited and deleted in place', (
      tester,
    ) async {
      await openBackups(tester, 'web-01');
      await tap(tester, _key('hw:disc:plan:nightly'));
      // Its own: no line into the datacenter's list.
      expect(_key('plan:nightly:open'), findsNothing);

      await tap(tester, _key('plan:nightly:edit'));
      expect(
        tester.widget<TextField>(field('plan:nightly:schedule')).controller!.text,
        '02:00',
      );
      await tester.enterText(field('plan:nightly:schedule'), 'sun 04:00');
      await _settle(tester);
      await tap(tester, _segOpt('plan:nightly:compress', 'gzip'));
      await tap(tester, _key('plan:nightly:save'));
      final edit = _jobEdits.single;
      expect((edit.id, edit.isNew), ('nightly', false));
      expect(edit.vmids, [100]);
      expect((edit.schedule, edit.compress), ('sun 04:00', 'gzip'));
      expect(_key('plan:nightly:schedule'), findsNothing);

      _calls.clear();
      final delete = _key('plan:nightly:delete');
      await tap(tester, delete);
      expect(_calls, isEmpty, reason: 'asked first');
      expect(_key('plan:nightly:confirm'), findsOneWidget);
      await tap(tester, delete);
      expect(_calls, [
        'job nightly remove=true 02:00 pool=null all=false vmids=[]',
      ]);
    });

    const shared = VirtBackupJob(
      id: 'shared',
      schedule: '03:00',
      storage: 'local',
      vmids: [100, 200],
    );

    testWidgets('a plan shared with other guests is read, and opens its job '
        'beside the list', (tester) async {
      _jobList = const [shared];
      await open(tester, 'web-01', wide: true, segmentLabel: libL10n.backup);
      await tap(tester, _key('hw:disc:plan:shared'));
      expect(text(app_locale.l10n.virtBackupPlanOthers(1)), findsOneWidget);
      expect(_key('plan:shared:edit'), findsNothing);
      expect(_key('plan:shared:delete'), findsNothing);
      expect(_key('plan:shared:run'), findsOneWidget);

      await tap(tester, _key('plan:shared:open'));
      expect(
        find.byWidgetPredicate(
          (w) => w is VirtBackupJobView && w.jobId == 'shared',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a plan shared with other guests opens its job page with one '
        'column', (tester) async {
      _jobList = const [shared];
      await openBackups(tester, 'web-01');
      await tap(tester, _key('hw:disc:plan:shared'));
      await tap(tester, _key('plan:shared:open'));
      expect(find.byType(VirtBackupJobPage), findsOneWidget);
    });
  });

  /// The backup job [jobId] (null: a new one) on its own, as the tab shows
  /// it beside its list.
  Future<void> openJob(WidgetTester tester, String? jobId) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        virtHostsProvider.overrideWith(_FakeHosts.new),
        virtHostProvider.overrideWith2((_) => _FakeHost()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            ...app_locale.appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return Scaffold(
                body: VirtBackupJobView(serverId: _pve, jobId: jobId),
              );
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await _settle(tester);
  }

  testWidgets('a pool job saved with a new schedule keeps its pool', (
    tester,
  ) async {
    await openJob(tester, 'by-pool');

    // The pool is the selection shown, and no guest is there to pick.
    expect(text('pool:prod'), findsWidgets);
    expect(find.byKey(const ValueKey('job:guest:qemu/100')), findsNothing);

    await tester.enterText(
      find.descendant(
        of: _key('job:schedule'),
        matching: find.byType(TextField),
      ),
      'sun 04:00',
    );
    await _settle(tester);
    await tap(tester, _key('job:save'));
    expect(
      _calls,
      contains('job by-pool remove=false sun 04:00 pool=prod all=false vmids=[]'),
    );
  });

  group('settings', () {
    Future<ProviderContainer> openSettings(WidgetTester tester, String guest) =>
        open(tester, guest, segmentLabel: libL10n.setting);

    Finder input(String key) => find.descendant(
      of: _key(key),
      matching: find.byType(TextField),
    );

    testWidgets('name, note, start with the host and protection', (
      tester,
    ) async {
      await openSettings(tester, 'web-01');
      expect(title(libL10n.general), findsOneWidget);
      expect(
        tester.widget<TextField>(input('set:name')).controller!.text,
        'web-01',
      );
      expect(
        tester.widget<TextField>(input('set:desc')).controller!.text,
        'the web tier',
      );

      // A name PVE refuses cannot be saved; one it takes can.
      await tester.enterText(input('set:name'), 'web_01');
      await _settle(tester);
      expect(
        text(app_locale.l10n.virtCreateNameInvalidPve),
        findsOneWidget,
      );
      await tester.enterText(input('set:name'), 'web-03');
      await _settle(tester);
      await tap(tester, _key('set:name:save'));
      expect((_changes.single.$2 as VirtHwSetName).name, 'web-03');

      _changes.clear();
      await tester.enterText(input('set:desc'), '');
      await _settle(tester);
      await tap(tester, _key('set:desc:save'));
      expect((_changes.single.$2 as VirtHwSetDescription).text, '');

      _changes.clear();
      await tap(tester, _key('hw:toggle:autostart'));
      expect((_changes.single.$2 as VirtHwSetAutostart).on, isFalse);
      _changes.clear();
      await tap(tester, _key('hw:toggle:protection'));
      expect((_changes.single.$2 as VirtHwSetProtection).on, isTrue);
    });

    testWidgets('a draft outlives a look at another view', (tester) async {
      await openSettings(tester, 'web-01');
      await tester.enterText(input('set:desc'), 'a draft');
      await _settle(tester);
      await tester.tap(segment(app_locale.l10n.virtOverview));
      await _settle(tester);
      expect(input('set:desc'), findsNothing, reason: 'hidden, not shown');
      await tester.tap(segment(libL10n.setting));
      await _settle(tester);
      expect(
        tester.widget<TextField>(input('set:desc')).controller!.text,
        'a draft',
      );
      expect(_key('set:desc:save'), findsOneWidget);
    });

    testWidgets('cloud-init: only with its drive; read, edited, saved', (
      tester,
    ) async {
      // No cloud-init drive: no group.
      await openSettings(tester, 'web-01');
      expect(title('cloud-init'), findsNothing);

      _hardware['qemu/100'] = _vm.copyWith(
        disks: [
          ..._vm.disks,
          const VirtHwDisk(
            key: 'scsi1',
            kind: VirtHwDiskKind.cdrom,
            source: 'local-lvm:vm-100-cloudinit',
            cloudInit: true,
          ),
        ],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await openSettings(tester, 'web-01');
      expect(title('cloud-init'), findsOneWidget);
      expect(tester.widget<TextField>(input('ci:user')).controller!.text, 'sbxe');
      expect(
        tester.widget<TextField>(input('ci:keys')).controller!.text,
        'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOld old@x',
      );
      // The password is never shown, only that there is one.
      expect(tester.widget<TextField>(input('ci:password')).controller!.text, isEmpty);
      expect(text(app_locale.l10n.virtCiPasswordKept), findsOneWidget);
      // When it applies, in PVE's terms; nothing to save yet.
      expect(
        text('${app_locale.l10n.virtCiEffectPve} ${app_locale.l10n.virtCiNewInstance}'),
        findsOneWidget,
      );
      expect(_key('ci:save'), findsNothing);
      expect(_key('ci:foreign'), findsNothing);

      // A new key and DHCP: saved with the password kept.
      await tester.enterText(input('ci:keys'), 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew new@x');
      await _settle(tester);
      await tap(tester, find.descendant(of: _key('hw:seg:ci:ip'), matching: find.text('DHCP')));
      await tap(tester, _key('ci:save'));
      final (base, edit) = _ciEdits.single;
      expect(base.revision, 'd1');
      expect(edit.values.keys, ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew new@x']);
      expect(edit.values.password, isNull);
      expect(edit.removePassword, isFalse);
      expect(edit.values.address, isNull);
      expect(edit.values.user, 'sbxe');

      // No way in left: said, and not saved.
      _ciEdits.clear();
      await tester.enterText(input('ci:keys'), '');
      await _settle(tester);
      await tap(tester, _key('hw:toggle:ci:remove-password'));
      expect(text(app_locale.l10n.virtCiCredentialsMissing), findsOneWidget);
      expect(tester.widget<Btn>(_key('ci:save')).onTap, isNull);
      // A user name useradd refuses.
      await tester.enterText(input('ci:keys'), 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew new@x');
      await tester.enterText(input('ci:user'), 'Ops');
      await _settle(tester);
      expect(text(app_locale.l10n.virtCiUserInvalid), findsOneWidget);
      expect(tester.widget<Btn>(_key('ci:save')).onTap, isNull);
      // Cancel: back to what was read.
      await tap(tester, _key('ci:cancel'));
      expect(tester.widget<TextField>(input('ci:user')).controller!.text, 'sbxe');
      expect(_ciEdits, isEmpty);
    });

    testWidgets('cloud-init: a seed with more than the app writes is said', (
      tester,
    ) async {
      _ci = VirtCloudInitState(
        user: _ci.user,
        passwordSet: true,
        foreign: true,
        revision: 'r',
      );
      _hardware['qemu/100'] = _vm.copyWith(
        disks: [
          const VirtHwDisk(key: 'scsi1', kind: VirtHwDiskKind.cdrom, cloudInit: true),
        ],
      );
      await openSettings(tester, 'web-01');
      expect(_key('ci:foreign'), findsOneWidget);
      // No NIC: no address rows.
      expect(_key('hw:seg:ci:ip'), findsNothing);
    });

    testWidgets('cloud-init: a draft is saved against the read it came from', (
      tester,
    ) async {
      _hardware['qemu/100'] = _vm.copyWith(
        disks: [
          ..._vm.disks,
          const VirtHwDisk(key: 'scsi1', kind: VirtHwDiskKind.cdrom, cloudInit: true),
        ],
      );
      final container = await openSettings(tester, 'web-01');
      const key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINew new@x';
      await tester.enterText(input('ci:keys'), key);
      await _settle(tester);

      // Changed elsewhere while the draft is open, and read again.
      _ci = const VirtCloudInitState(
        user: 'root',
        sshKeys: ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOld old@x'],
        address: '10.0.0.5/24',
        gateway: '10.0.0.1',
        passwordSet: true,
        network: true,
        revision: 'd2',
      );
      container.invalidate(virtCloudInitProvider(_pve, 'qemu/100'));
      await _settle(tester);
      expect(tester.widget<TextField>(input('ci:keys')).controller!.text, key);

      // Its own read goes back: the host, not this view, decides whether
      // the change made meanwhile is overwritten.
      await tap(tester, _key('ci:save'));
      final (base, edit) = _ciEdits.single;
      expect(base.revision, 'd1');
      expect(edit.values.user, 'sbxe');
    });

    testWidgets('cloud-init: a draft outlives the bar\'s refresh', (
      tester,
    ) async {
      _hardware['qemu/100'] = _vm.copyWith(
        disks: [
          ..._vm.disks,
          const VirtHwDisk(key: 'scsi1', kind: VirtHwDiskKind.cdrom, cloudInit: true),
        ],
      );
      await open(tester, 'web-01', wide: true, segmentLabel: libL10n.setting);
      await tester.enterText(input('ci:search'), 'lab.example');
      await _settle(tester);

      // Changed elsewhere: the configuration and its cloud-init both.
      _hardware['qemu/100'] = _hardware['qemu/100']!.copyWith(revision: 'r2');
      _ci = const VirtCloudInitState(
        user: 'sbxe',
        sshKeys: ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOld old@x'],
        address: '10.0.0.5/24',
        gateway: '10.0.0.1',
        dns: ['192.168.31.1'],
        passwordSet: true,
        network: true,
        revision: 'd2',
      );
      final reads = _ciReads;
      await tester.tap(find.byIcon(Icons.refresh).first);
      await _settle(tester);
      expect(_ciReads, reads + 1, reason: 'read again with the hardware');
      expect(
        tester.widget<TextField>(input('ci:search')).controller!.text,
        'lab.example',
      );
      // Read again, and saved against the read the draft came from: the
      // host says it changed since.
      await tap(tester, _key('ci:save'));
      expect(_ciEdits.single.$1.revision, 'd1');
    });

    testWidgets('libvirt: a clone\'s empty disks go to the pool picked', (
      tester,
    ) async {
      _hostKind = VirtHostKind.libvirt;
      await openSettings(tester, 'db-02');
      await tap(tester, _key('clone:target:pve/local'));
      await tap(tester, _key('hw:toggle:clone:full'));
      // Still offered, and not refused as PVE's linked clone would be.
      expect(_key('clone:target:pve/local'), findsOneWidget);
      expect(text(app_locale.l10n.virtCloneLinkedTarget), findsNothing);
      await tap(tester, _key('clone:go'));
      final clone = _clones.single;
      expect((clone.full, clone.targetPool), (false, 'local'));
    });

    testWidgets('a container\'s pending hostname is shown by its field', (
      tester,
    ) async {
      await openSettings(tester, 'dns-01');
      expect(_key('hw:pending:hostname'), findsOneWidget);
      await tap(tester, _key('hw:revert:hostname'));
      expect((_changes.single.$2 as VirtHwRevert).keys, ['hostname']);
    });

    testWidgets('delete: not while running, and asked twice', (tester) async {
      await openSettings(tester, 'web-01');
      expect(text(app_locale.l10n.virtSetDeleteStopFirst), findsOneWidget);
      expect(
        tester.widget<Btn>(_key('delete:go')).onTap,
        isNull,
        reason: 'running',
      );
      // PVE deletes a guest's disks with it: said, not asked.
      expect(text(app_locale.l10n.virtDeleteDisksPve), findsOneWidget);
    });

    testWidgets('delete: protection holds it back, then two presses', (
      tester,
    ) async {
      await openSettings(tester, 'db-02');
      expect(text(app_locale.l10n.virtSetDeleteProtected), findsOneWidget);
      expect(tester.widget<Btn>(_key('delete:go')).onTap, isNull);

      _hardware['qemu/101'] = _stopped.copyWith(protection: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await openSettings(tester, 'db-02');
      await tap(tester, _key('delete:go'));
      expect(_calls, isEmpty, reason: 'the first press asks');
      expect(text(app_locale.l10n.virtSetDeleteAgain), findsOneWidget);
      await tap(tester, _key('delete:go'));
      expect(_calls, ['delete qemu/101 disks=true']);
    });
  });

  testWidgets('a device\'s own rows are spaced like the group\'s', (
    tester,
  ) async {
    // The pane's gap between rows is a padding the *group* puts under each
    // element of its list. A `Reveal` is one element, so its children would
    // draw against one another with nothing between them unless they bring it
    // themselves.
    await open(tester, 'web-01');
    await tap(tester, _key('hw:disc:scsi0'));

    // Two rows of the same fold, one after the other: the capacity stepper and
    // the bus choice under it.
    final step = tester.getRect(_key('hw:step:grow:scsi0'));
    final bus = tester.getRect(_key('hw:seg:disk:scsi0:bus'));
    expect(bus.top, greaterThan(step.bottom));
    expect(
      bus.top - step.bottom,
      moreOrLessEquals(7, epsilon: 0.5),
      reason: 'the gap the group draws between rows outside a fold',
    );
  });

  testWidgets('a device\'s rows unfold rather than appearing', (tester) async {
    await open(tester, 'web-01');
    final row = _key('hw:disc:scsi0');
    await tester.ensureVisible(row);
    await tester.pump();
    // A row that is only there while the disk is open, and where the NICs
    // group sits above/below it.
    final source = text(app_locale.l10n.virtHwSource);
    expect(source, findsNothing);

    await tester.tap(row);
    await tester.pump();
    // Built at once — the fold is the space they take, not how much of each
    // row is drawn.
    expect(source, findsOneWidget);
    final below = tester.getTopLeft(_key('hw:disc:net0')).dy;
    await tester.pump(const Duration(milliseconds: 60));
    // Part way: the rows are coming in and the group below has started moving,
    // rather than the two having swapped between frames.
    final part = tester.getTopLeft(_key('hw:disc:net0')).dy;
    expect(part, greaterThan(below));

    await _settle(tester);
    expect(tester.getTopLeft(_key('hw:disc:net0')).dy, greaterThan(part));
    expect(source, findsOneWidget);
  });

  testWidgets('disks: the bus waits for a stop, the cache is set at once', (
    tester,
  ) async {
    await open(tester, 'web-01');
    await tap(tester, _key('hw:disc:scsi0'));
    // Running: the bus is shown, not offered, and says why.
    expect(text(app_locale.l10n.virtHwBusStopped), findsOneWidget);
    await tap(tester, _segOpt('disk:scsi0:bus', 'virtio'));
    expect(_changes, isEmpty);
    await tap(tester, _segOpt('disk:scsi0:cache', 'writeback'));
    final (_, change) = _changes.single;
    expect(change, isA<VirtHwUpdateDisk>());
    change as VirtHwUpdateDisk;
    expect((change.key, change.bus, change.cache), ('scsi0', null, 'writeback'));
  });

  testWidgets('NICs: the model, and a MAC checked before it is sent', (
    tester,
  ) async {
    await open(tester, 'web-01');
    await tap(tester, _key('hw:disc:net0'));
    await tap(tester, _segOpt('nic:net0:model', 'e1000'));
    final model = _changes.single.$2 as VirtHwSetNicHardware;
    expect((model.key, model.model, model.mac), ('net0', 'e1000', null));

    await tap(tester, _key('nic:net0:mac'));
    await tester.enterText(find.byType(TextField).last, '01:00:00:00:00:01');
    await _settle(tester);
    // Multicast: said, and the save refused.
    expect(text(app_locale.l10n.virtHwIssueMac), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'bc:24:11:00:00:02');
    await _settle(tester);
    await tester.tap(find.text(libL10n.save));
    await _settle(tester);
    final mac = _changes.last.$2 as VirtHwSetNicHardware;
    expect(mac.mac, 'bc:24:11:00:00:02');
  });

  testWidgets('devices: passthrough and the TPM listed, a USB device added', (
    tester,
  ) async {
    _hostDevs = const VirtHostDevices(
      usb: [VirtHostDevice(id: 'bt', label: 'bt', detail: 'node=pve,id=0bda:b023', mapping: true)],
      mappingsOnly: true,
    );
    await open(tester, 'web-01');
    expect(_key('hw:disc:usb0'), findsOneWidget);
    expect(_key('hw:disc:tpmstate0'), findsOneWidget);
    // A second TPM or CD-ROM is not offered: only USB and PCI.
    await tap(tester, _key('hw:add:dev'));
    expect(_segOpt('dev:add:kind', 'TPM'), findsNothing);
    expect(_segOpt('dev:add:kind', app_locale.l10n.virtHwCdrom), findsNothing);
    expect(text(app_locale.l10n.virtHwMappingsOnly), findsOneWidget);
    await tap(tester, _key('hw:dev:pick:mapping:bt'));
    await tap(tester, _key('hw:dev:add'));
    final add = _changes.single.$2 as VirtHwAddDevice;
    expect((add.kind, add.host?.id, add.host?.mapping), (VirtHwDeviceKind.usb, 'bt', true));
  });

  testWidgets('PCI without an IOMMU says so, as a warning, not an error', (
    tester,
  ) async {
    _hostDevs = const VirtHostDevices(
      iommu: false,
      pci: [VirtHostDevice(id: '0000:00:14.0', label: 'xHCI', detail: '0000:00:14.0')],
    );
    await open(tester, 'db-02');
    await tap(tester, _key('hw:add:dev'));
    // It has no CD-ROM: that is offered first, as the design has it.
    await tap(tester, _segOpt('dev:add:kind', app_locale.l10n.virtHwPci));
    expect(_key('hw:dev:iommu-off'), findsOneWidget);
    expect(text(app_locale.l10n.virtHwIommuOffTitle), findsOneWidget);
    // Still offered: the configuration is the user's to write.
    expect(_key('hw:dev:pick:0000:00:14.0'), findsOneWidget);
  });

  testWidgets('devices: a CD-ROM drive added where there is none', (
    tester,
  ) async {
    await open(tester, 'db-02');
    await tap(tester, _key('hw:add:dev'));
    expect(_segOpt('dev:add:kind', app_locale.l10n.virtHwCdrom), findsOneWidget);
    // Empty unless an ISO is picked; stopped, nothing waits for a restart.
    expect(_key('hw:cdrom:new:none'), findsOneWidget);
    expect(text(app_locale.l10n.virtHwCdromLater), findsNothing);
    await tap(tester, _key('hw:cdrom:new:local:iso/debian-13.iso'));
    await tap(tester, _key('hw:dev:add'));
    final add = _changes.single.$2 as VirtHwAddCdrom;
    expect(add.media?.volume.id, 'local:iso/debian-13.iso');
  });

  testWidgets('devices: a cloud-init drive is not install media', (
    tester,
  ) async {
    _hardware['qemu/101'] = _stopped.copyWith(
      disks: [
        ..._stopped.disks,
        const VirtHwDisk(
          key: 'ide2',
          kind: VirtHwDiskKind.cdrom,
          source: 'local-lvm:vm-101-cloudinit',
          bus: 'ide',
          cloudInit: true,
        ),
      ],
    );
    await open(tester, 'db-02');
    expect(text('ide2 · cloud-init'), findsOneWidget);
    await tap(tester, _key('hw:disc:ide2'));
    // Nothing to insert into it, only taking it off.
    expect(_key('hw:media:none'), findsNothing);
    expect(text(app_locale.l10n.virtHwCloudInitNote), findsOneWidget);
    expect(_key('hw:media:ide2:remove'), findsOneWidget);
    // A drive for media can still be added beside it.
    await tap(tester, _key('hw:add:dev'));
    expect(_segOpt('dev:add:kind', app_locale.l10n.virtHwCdrom), findsOneWidget);
    await tap(tester, _key('hw:dev:add'));
    expect((_changes.single.$2 as VirtHwAddCdrom).media, isNull);
  });

  testWidgets('display: listening everywhere is warned about', (tester) async {
    await open(tester, 'db-02');
    expect(_key('hw:display:exposed'), findsOneWidget);
    await tap(tester, _segOpt('display:listen', '127.0.0.1'));
    final d = _changes.single.$2 as VirtHwSetDisplay;
    expect((d.listen, d.protocol, d.gpu), ('127.0.0.1', null, null));
    await tap(tester, _segOpt('display:protocol', 'SPICE'));
    expect((_changes.last.$2 as VirtHwSetDisplay).protocol, 'spice');
  });

  testWidgets('firmware: asked first, only while stopped', (tester) async {
    await open(tester, 'web-01');
    // Running: neither choice switches.
    await tap(tester, _key('hw:fw:bios'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(text(app_locale.l10n.virtHwFirmwareStopped), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await open(tester, 'db-02');
    await tap(tester, _key('hw:fw:uefi'));
    expect(text(app_locale.l10n.virtHwFirmwareWarnBody), findsWidgets);
    await tester.tap(find.text(libL10n.ok));
    await _settle(tester);
    final fw = _changes.single.$2 as VirtHwSetFirmware;
    // Null: the new variables disk goes where the old one is.
    expect((fw.uefi, fw.secureBoot, fw.storage), (true, false, null));
  });

  group('backups: what the view reads again', () {
    Future<ProviderContainer> openBackups(WidgetTester tester, String guest) =>
        open(tester, guest, segmentLabel: libL10n.backup);

    testWidgets('the first backup takes the options too', (tester) async {
      await openBackups(tester, 'dns-01');
      expect(_key('hw:seg:opt:mode'), findsOneWidget);
      await tap(tester, _segOpt('opt:mode', 'stop'));
      await tap(tester, _key('opt:go'));
      expect(_calls, ['backup lxc/200 local stop']);
    });

    testWidgets('a pull reads the plan and the backups again', (tester) async {
      await openBackups(tester, 'web-01');
      expect(text('02:00'), findsOneWidget);
      _jobList = const [
        VirtBackupJob(
          id: 'nightly',
          schedule: 'sun 05:00',
          storage: 'local',
          vmids: [100],
        ),
      ];
      await tester.fling(
        find
            .ancestor(
              of: title(app_locale.l10n.virtBackupPlan),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, 400),
        1000,
      );
      await _settle(tester);
      expect(text('sun 05:00'), findsOneWidget);
      expect(text('02:00'), findsNothing);
    });

    testWidgets('left while a backup runs', (tester) async {
      _backupGate = Completer();
      await openBackups(tester, 'web-01');
      await tap(tester, _key('backup:now'));
      await tester.tap(segment(libL10n.setting));
      await _settle(tester);
      // Finishes with the view gone: nothing is read through it.
      _backupGate!.complete();
      await _settle(tester);
      expect(_calls, contains('backup qemu/100 local snapshot'));
    });
  });

  group('backup jobs', () {
    Finder selection() => find.descendant(
      of: _key('hw:seg:job:all'),
      matching: find.byWidgetPredicate((w) => w is SegmentedTabs),
    );

    testWidgets('a job of listed guests has the list option chosen', (
      tester,
    ) async {
      await openJob(tester, 'nightly');
      final tabs = tester.widget(selection()) as SegmentedTabs;
      expect(tabs.selected, app_locale.l10n.virtBackupSelectionList);
    });

    testWidgets('the storages are the node\'s, each once', (tester) async {
      _nodes = const [VirtNode(name: 'pve'), VirtNode(name: 'pve2')];
      _backupPools = const [
        _pool,
        VirtStoragePool(
          id: 'pve2/local',
          name: 'local',
          node: 'pve2',
          type: 'dir',
          content: ['backup'],
        ),
        VirtStoragePool(
          id: 'pve2/nas',
          name: 'nas',
          node: 'pve2',
          type: 'nfs',
          content: ['backup'],
        ),
      ];
      await openJob(tester, null);
      // On any node: every storage one of them has, once.
      expect(_segOpt('job:storage', 'local'), findsOneWidget);
      await tap(tester, _segOpt('job:storage', 'nas'));
      // Pinned to a node without it: not offered, and not kept.
      await tap(tester, _segOpt('job:node', 'pve'));
      expect(_segOpt('job:storage', 'nas'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: _key('job:schedule'),
          matching: find.byType(TextField),
        ),
        '02:00',
      );
      await _settle(tester);
      await tap(tester, _key('job:save'));
      final edit = _jobEdits.single;
      expect((edit.node, edit.storage), ('pve', 'local'));
    });

    testWidgets('a new job: the index names the storage its row shows', (
      tester,
    ) async {
      await openJob(tester, null);
      final tabs =
          tester.widget(
                find.descendant(
                  of: _key('hw:seg:job:storage'),
                  matching: find.byWidgetPredicate((w) => w is SegmentedTabs),
                ),
              )
              as SegmentedTabs;
      expect(tabs.selected, 'local');
      // The index beside the groups: the same storage, not "none".
      expect(text(app_locale.l10n.virtBackupNoStorage), findsNothing);
      expect(text('local'), findsNWidgets(2));
    });
  });

  group('drafts over a newer read', () {
    testWidgets('one whose fields changed is refused, then dropped', (
      tester,
    ) async {
      final container = await open(tester, 'web-01');
      await tap(tester, _key('hw:step:cores:inc'));
      // Someone else sets the vCPUs meanwhile; the view reads it again.
      _hardware['qemu/100'] = _vm.copyWith(
        cpu: const VirtHwCpu(sockets: 1, cores: 4, type: 'host'),
        revision: 'digest-9',
      );
      container.invalidate(virtHardwareProvider(_pve, 'qemu/100'));
      await _settle(tester);
      expect(_key('hw:cpu:save'), findsOneWidget, reason: 'still a draft');

      await tap(tester, _key('hw:cpu:save'));
      expect(_changes, isEmpty, reason: 'the host refused it');
      expect(_key('hw:cpu:save'), findsNothing);
    });

    testWidgets('one the host could not take for another reason is kept', (
      tester,
    ) async {
      final container = await open(tester, 'web-01');
      await tap(tester, _key('hw:step:cores:inc'));
      _hardware['qemu/100'] = _vm.copyWith(
        cpu: const VirtHwCpu(sockets: 1, cores: 4, type: 'host'),
        revision: 'digest-9',
      );
      container.invalidate(virtHardwareProvider(_pve, 'qemu/100'));
      await _settle(tester);

      // The host out of reach: nothing says yet that the draft's base is
      // gone, so it stays to be saved again.
      _changeError = const VirtErr(type: VirtErrType.unreachable);
      await tap(tester, _key('hw:cpu:save'));
      expect(_changes, isEmpty);
      expect(_key('hw:cpu:save'), findsOneWidget, reason: 'kept');

      // Reached, the host says it is: then it goes.
      await tap(tester, _key('hw:cpu:save'));
      expect(_changes, isEmpty, reason: 'the host refused it');
      expect(_key('hw:cpu:save'), findsNothing);
    });

    testWidgets('one whose fields did not is saved on the newer read', (
      tester,
    ) async {
      final container = await open(tester, 'web-01');
      await tap(tester, _key('hw:step:cores:inc'));
      _hardware['qemu/100'] = _vm.copyWith(
        description: 'renamed tier',
        revision: 'digest-9',
      );
      container.invalidate(virtHardwareProvider(_pve, 'qemu/100'));
      await _settle(tester);
      await tap(tester, _key('hw:cpu:save'));
      expect((_changes.single.$2 as VirtHwSetCpu).cores, 3);
    });
  });

  testWidgets('the balloon back on is held under the memory the draft gives', (
    tester,
  ) async {
    await open(tester, 'web-01');
    await tap(tester, _key('hw:toggle:balloon'));
    // 2048 → 1024 → 768 → 512 MiB, under the 1024 MiB floor it had.
    for (var i = 0; i < 3; i++) {
      await tap(tester, _key('hw:step:memory:dec'));
    }
    await tap(tester, _key('hw:toggle:balloon'));
    await tap(tester, _key('hw:memory:save'));
    final m = _changes.single.$2 as VirtHwSetMemory;
    expect((m.mib, m.minMib), (512, 512));
  });

  testWidgets('install media that could not be read: said, and retried', (
    tester,
  ) async {
    _poolsFail = true;
    await open(tester, 'web-01');
    await tap(tester, _key('hw:disc:ide2'));
    expect(_key('hw:isos:retry'), findsOneWidget);
    _poolsFail = false;
    await tap(tester, _key('hw:isos:retry'));
    expect(_key('hw:media:local:iso/debian-13.iso'), findsOneWidget);
  });

  testWidgets('a storage whose media could not be listed is said', (
    tester,
  ) async {
    _volumesFail = true;
    await open(tester, 'db-02');
    await tap(tester, _key('hw:add:dev'));
    expect(find.textContaining(RegExp('^local: '), skipOffstage: false), findsOneWidget);
    expect(_key('hw:cdrom:new:none'), findsOneWidget);
  });

  testWidgets('two USB devices alike are two choices', (tester) async {
    _hostDevs = const VirtHostDevices(
      usb: [
        VirtHostDevice(id: '0bda:b023', label: 'Bluetooth', usbBus: 1, usbPort: '1'),
        VirtHostDevice(id: '0bda:b023', label: 'Bluetooth', usbBus: 1, usbPort: '2'),
      ],
    );
    await open(tester, 'web-01');
    await tap(tester, _key('hw:add:dev'));
    await tap(
      tester,
      _segOpt('dev:add:usb-naming', app_locale.l10n.virtUsbByAddress),
    );
    await tap(tester, _key('hw:dev:pick:0bda:b023:1:2'));
    await tap(tester, _key('hw:dev:add'));
    final add = _changes.single.$2 as VirtHwAddDevice;
    expect((add.host?.usbPort, add.usbNaming), ('2', VirtUsbNaming.address));
  });

  testWidgets('a CD-ROM being added does not read the host\'s devices', (
    tester,
  ) async {
    _hostDevsError = const VirtErr(
      type: VirtErrType.unreachable,
      message: 'nodedev',
    );
    await open(tester, 'db-02');
    await tap(tester, _key('hw:add:dev'));
    expect(_hostDevReads, 0);
    // PCI reads them, and its picker says why it cannot.
    await tap(tester, _segOpt('dev:add:kind', app_locale.l10n.virtHwPci));
    expect(_hostDevReads, 1);
  });

  testWidgets('the detail is read again after a hardware change', (
    tester,
  ) async {
    final container = await open(tester, 'web-01');
    final before = _detailReads;
    _hardware['qemu/100'] = _vm.copyWith(nics: const [], revision: 'digest-9');
    container.invalidate(virtHardwareProvider(_pve, 'qemu/100'));
    await _settle(tester);
    expect(_detailReads, before + 1);
  });

  testWidgets('a deletion that ends after another guest was opened', (
    tester,
  ) async {
    _hardware['qemu/101'] = _stopped.copyWith(protection: false);
    _deleteGate = Completer();
    await open(tester, 'db-02', wide: true, segmentLabel: libL10n.setting);
    await tap(tester, _key('delete:go'));
    await tap(tester, _key('delete:go'));
    await tester.tap(find.text('web-01').first);
    await _settle(tester);
    _deleteGate!.complete();
    await _settle(tester);
    expect(_calls, ['delete qemu/101 disks=true']);
    // What was opened meanwhile stays open.
    expect(find.byType(VirtGuestView), findsOneWidget);
  });
}


/// Built, whether scrolled to or not.
Finder _key(String key) => find.byKey(ValueKey(key), skipOffstage: false);

/// An option of the segmented row [key].
Finder _segOpt(String key, String label) => find.descendant(
  of: _key('hw:seg:$key'),
  matching: find.text(label, skipOffstage: false),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
