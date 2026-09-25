/// The Virtualization tab's Hardware view over a scripted host: the groups
/// for a VM and a container, a CPU edit held as a draft until Save, pending
/// changes with their revert and the restart banner, a disk removed behind
/// its confirmation, and the index on a wide window.
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
  required int vmid,
}) => VirtGuest(
  id: id,
  name: name,
  kind: kind,
  state: VirtGuestState.running,
  vmid: vmid,
  node: 'pve',
  vcpu: 2,
  actions: VirtPowerAction.offered(
    VirtGuestState.running,
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
  ],
  capabilities: const VirtCapabilities(
    lxc: true,
    storage: true,
    network: true,
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
  revision: 'digest-2',
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
      ..['lxc/200'] = _ct;
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
        : const Size(400, 800);
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
      l10n.virtHwPendingTitle,
      l10n.virtHwProcessor,
      l10n.virtHwNics,
      l10n.virtHwCdrom,
      l10n.virtHwBoot,
      l10n.virtHwConfigFile,
    ]) {
      expect(title(t), findsOneWidget, reason: t);
    }
    expect(_key('hw:pending:cores'), findsOneWidget);
    expect(_key('hw:pending-banner'), findsOneWidget);

    await tap(tester, _key('hw:revert:cores'));
    final (id, change) = _changes.single;
    expect(id, 'qemu/100');
    expect((change as VirtHwRevert).keys, ['cores']);

    await tester.tap(_key('hw:restart-now'));
    await _settle(tester);
    expect(_calls, ['restart qemu/100']);
  });

  testWidgets('a CPU edit waits for Save, and Cancel drops it', (tester) async {
    await open(tester, 'web-01');
    final inc = _key('hw:step:cores:inc');
    final save = _key('hw:cpu:save');
    expect(save, findsNothing);

    await tap(tester, inc);
    debugPrint('DBG keys ${find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('hw:'), skipOffstage: false).evaluate().map((e) => (e.widget.key! as ValueKey<String>).value).toList()}');
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
    expect(title(l10n.virtHwPendingTitle), findsNothing);
    expect(_key('hw:pending-banner'), findsNothing);
  });

  testWidgets('a wide window indexes the groups', (tester) async {
    await open(tester, 'web-01', wide: true);
    for (final g in ['pending', 'cpu', 'mem', 'disks', 'nics', 'cdrom', 'boot', 'config']) {
      expect(_key('hw:index:$g'), findsOneWidget, reason: g);
    }
    expect(tester.getRect(_key('hw:disc:config')).top, greaterThan(900));
    await tester.tap(_key('hw:index:config'));
    await _settle(tester);
    // Scrolled to, in the pane: not merely built.
    expect(tester.getRect(_key('hw:disc:config')).top, lessThan(900));
  });
}

/// Built, whether scrolled to or not.
Finder _key(String key) => find.byKey(ValueKey(key), skipOffstage: false);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
