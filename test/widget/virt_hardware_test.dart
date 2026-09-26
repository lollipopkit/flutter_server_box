/// The Virtualization tab's Hardware and Settings views over a scripted
/// host: the groups for a VM and a container, a CPU edit held as a draft
/// until Save, pending changes shown on what they change with their revert
/// and the restart banner, a disk removed behind its confirmation, the
/// dashed add rows, the index on a wide window, and the Settings view's
/// name, note, start and protection, and its two-press delete.
///
/// As in `virt_tab_test.dart`, the providers are replaced, not the backends.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/virt/pve_resources.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
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
import 'package:server_box/view/page/virt/hardware.dart';
import 'package:server_box/view/page/virt/tab.dart';

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

VirtSnapshot _snapshot() => VirtSnapshot(
  host: const VirtHost(
    serverId: _pve,
    kind: VirtHostKind.pve,
    version: '9.2',
    nodes: [VirtNode(name: 'pve')],
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
    backup: true,
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
  support: PveResources.pveQemuSupport,
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
final _ciEdits = <(VirtCloudInitState, VirtCloudInitEdit)>[];

final _hardware = <String, VirtHardware>{};
final _changes = <(String, VirtHwChange)>[];
final _calls = <String>[];

class _FakeHosts extends VirtHosts {
  @override
  VirtHostsState build() =>
      const VirtHostsState(hosts: {_pve: VirtHostKind.pve});

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
    kind: VirtHostKind.pve,
    data: _snapshot(),
  );

  @override
  Future<void> refresh({bool auto = false}) async {}

  @override
  Future<VirtGuestDetail> detail(String guestId) async =>
      const VirtGuestDetail();

  @override
  Future<List<VirtStats>> history(
    String guestId, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => const [];

  /// ISOs only: no disk goes here.
  @override
  Future<List<VirtStoragePool>> storagePools() async => const [
    VirtStoragePool(
      id: 'pve/local',
      name: 'local',
      node: 'pve',
      type: 'dir',
      content: ['iso'],
    ),
  ];

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async => const [
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
    expect(base.revision, _hardware[guestId]!.revision);
    _changes.add((guestId, change));
    return const VirtHwOutcome();
  }

  @override
  Future<VirtHostDevices> hostDevices(String guestId) async => _hostDevs;

  @override
  Future<VirtCloudInitState> cloudInit(String guestId) async => _ci;

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
  Future<void> delete(String guestId, {bool removeDisks = true}) async =>
      _calls.add('delete $guestId disks=$removeDisks');

  @override
  Future<String> clone(String guestId, VirtCloneRequest request) async {
    _calls.add('clone $guestId ${request.name} full=${request.full}');
    return 'qemu/150';
  }

  @override
  Future<List<VirtBackup>> backups(String guestId) async =>
      guestId == 'qemu/100' || guestId == 'qemu/101'
      ? [_backup.copyWith(vmid: int.parse(guestId.split('/').last))]
      : const [];

  @override
  Future<List<VirtBackupJob>> backupJobs(String guestId) async => const [_job];

  @override
  Future<List<VirtStoragePool>> backupStorages(String guestId) async => const [
    VirtStoragePool(
      id: 'pve/local',
      name: 'local',
      node: 'pve',
      type: 'dir',
      content: ['backup', 'iso'],
    ),
  ];

  @override
  Future<void> backup(String guestId, VirtBackupRequest request) async =>
      _calls.add('backup $guestId ${request.storage} ${request.mode}');

  @override
  Future<void> restoreBackup(
    String guestId,
    VirtBackup backup, {
    int? vmid,
  }) async => _calls.add('restore $guestId vmid=$vmid');

  @override
  Future<void> deleteBackup(String guestId, VirtBackup backup) async =>
      _calls.add('delete backup $guestId');
}

void main() {
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
    _ciEdits.clear();
    _ci = _ciRead;
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> open(
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
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
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

    // Every one at once, from the banner.
    _changes.clear();
    await tester.tap(_key('hw:revert-all'));
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
      expect(text('02:00'), findsOneWidget);
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
      expect(_calls, ['restore qemu/101 vmid=null']);

      // Still open after the list is read again.
      _calls.clear();
      final delete = _key('backup:${_backup.id}:delete');
      await tap(tester, delete);
      expect(_calls, isEmpty);
      await tap(tester, delete);
      expect(_calls, ['delete backup qemu/101']);
    });
  });

  group('settings', () {
    Future<void> openSettings(WidgetTester tester, String guest) =>
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
    await tap(tester, _key('hw:dev:pick:bt'));
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
    expect(add.media?.id, 'local:iso/debian-13.iso');
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
    expect((fw.uefi, fw.secureBoot, fw.storage), (true, false, 'local-lvm'));
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
