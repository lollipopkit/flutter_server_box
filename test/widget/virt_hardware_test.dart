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
import 'package:server_box/data/model/virt/virt.dart';
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
  ),
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
);

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

  @override
  Future<List<VirtStoragePool>> storagePools() async => const [];

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
  Future<void> restartToApply(String guestId) async =>
      _calls.add('restart $guestId');

  @override
  Future<void> delete(String guestId, {bool removeDisks = true}) async =>
      _calls.add('delete $guestId disks=$removeDisks');
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
      l10n.virtHwCdrom,
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
    for (final g in ['cpu', 'mem', 'disks', 'nics', 'cdrom', 'boot', 'config']) {
      expect(_key('hw:index:$g'), findsOneWidget, reason: g);
    }
    expect(tester.getRect(_key('hw:disc:config')).top, greaterThan(900));
    await tester.tap(_key('hw:index:config'));
    await _settle(tester);
    // Scrolled to, in the pane: not merely built.
    expect(tester.getRect(_key('hw:disc:config')).top, lessThan(900));
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
}


/// Built, whether scrolled to or not.
Finder _key(String key) => find.byKey(ValueKey(key), skipOffstage: false);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
