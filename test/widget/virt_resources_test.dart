/// The Virtualization tab's snapshots, storage and network views over
/// scripted hosts: the sections enabled by capability, the snapshot tree,
/// each snapshot action behind its confirmation, and pools and networks in
/// both layouts.
///
/// As in `virt_tab_test.dart`, the providers are replaced, not the backends.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/resources.dart';
import 'package:server_box/view/page/virt/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _pve = 'srv-pve';

VirtGuest _guest(
  String id,
  String name,
  VirtGuestState state, {
  VirtGuestKind kind = VirtGuestKind.qemu,
  required int vmid,
}) => VirtGuest(
  id: id,
  name: name,
  kind: kind,
  state: state,
  vmid: vmid,
  node: 'pve',
  actions: VirtPowerAction.offered(state, pause: kind == VirtGuestKind.qemu),
);

VirtSnapshot _snapshot(VirtCapabilities caps) => VirtSnapshot(
  host: const VirtHost(
    serverId: _pve,
    kind: VirtHostKind.pve,
    version: '9.2',
    nodes: [VirtNode(name: 'pve')],
  ),
  guests: [
    _guest('qemu/100', 'web-01', VirtGuestState.running, vmid: 100),
    _guest(
      'lxc/200',
      'dns-01',
      VirtGuestState.running,
      kind: VirtGuestKind.lxc,
      vmid: 200,
    ),
  ],
  capabilities: caps,
);

const _allCaps = VirtCapabilities(
  lxc: true,
  pause: true,
  snapshots: true,
  storage: true,
  network: true,
);

final _snaps = <String, List<VirtGuestSnapshot>>{};
final _calls = <String>[];
late VirtHostState _state;

final _pools = [
  const VirtStoragePool(
    id: 'pve/local-lvm',
    name: 'local-lvm',
    node: 'pve',
    type: 'lvmthin',
    path: 'pve/data',
    capacity: 100 << 30,
    used: 25 << 30,
    available: 75 << 30,
    content: ['images', 'rootdir'],
  ),
  const VirtStoragePool(
    id: 'pve/nfs',
    name: 'nfs',
    node: 'pve',
    type: 'nfs',
    active: false,
  ),
];

final _volumes = <String, List<VirtVolume>>{
  'pve/local-lvm': [
    const VirtVolume(
      id: 'local-lvm:vm-100-disk-0',
      name: 'vm-100-disk-0',
      format: 'raw',
      content: 'images',
      capacity: 8 << 30,
      users: [VirtGuestRef(vmid: 100)],
    ),
    const VirtVolume(
      id: 'local-lvm:vm-999-disk-0',
      name: 'vm-999-disk-0',
      format: 'raw',
      capacity: 1 << 30,
    ),
  ],
};

const _networks = [
  VirtNetwork(
    id: 'pve/vmbr0',
    name: 'vmbr0',
    node: 'pve',
    mode: 'bridge',
    cidrs: ['192.168.31.20/24'],
    gateway: '192.168.31.1',
    ports: ['nic0'],
    autostart: true,
    users: [
      VirtGuestRef(
        guestId: 'qemu/100',
        vmid: 100,
        device: 'net0',
        mac: 'bc:24:11:65:b0:b5',
      ),
    ],
  ),
  VirtNetwork(id: 'pve/nic0', name: 'nic0', node: 'pve', mode: 'eth'),
];

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
  VirtHostState build(String serverId) => _state;

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
  Future<List<VirtGuestSnapshot>> snapshots(String guestId) async {
    _calls.add('snapshots $guestId');
    return _snaps[guestId] ?? const [];
  }

  @override
  Future<void> createSnapshot(
    String guestId, {
    required String name,
    String? description,
    bool memory = false,
  }) async => _calls.add('create $guestId $name $description memory=$memory');

  @override
  Future<void> revertSnapshot(
    String guestId,
    String name, {
    bool start = false,
  }) async => _calls.add('revert $guestId $name start=$start');

  @override
  Future<void> deleteSnapshot(String guestId, String name) async =>
      _calls.add('delete $guestId $name');

  @override
  Future<List<VirtStoragePool>> storagePools() async {
    _calls.add('pools');
    if (_failPools) {
      throw const VirtErr(type: VirtErrType.unreachable, message: 'timeout');
    }
    return _pools;
  }

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async {
    _calls.add('volumes ${pool.id}');
    return _volumes[pool.id] ?? const [];
  }

  @override
  Future<List<VirtNetwork>> networks() async {
    _calls.add('networks');
    return _networks;
  }
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
    _calls.clear();
    _snaps
      ..clear()
      ..['qemu/100'] = [
        VirtGuestSnapshot(
          name: 'base',
          createdAt: DateTime(2026, 9, 1),
          description: 'fresh install',
        ),
        VirtGuestSnapshot(
          name: 'disk-only',
          parent: 'base',
          createdAt: DateTime(2026, 9, 2),
        ),
        VirtGuestSnapshot(
          name: 'with-mem',
          parent: 'disk-only',
          createdAt: DateTime(2026, 9, 3),
          withMemory: true,
          current: true,
        ),
      ];
    _state = VirtHostState(
      serverId: _pve,
      kind: VirtHostKind.pve,
      data: _snapshot(_allCaps),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> pump(WidgetTester tester, {required bool wide}) async {
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
  }

  Future<void> openSnapshots(WidgetTester tester, String guest) async {
    await tester.tap(find.text(guest));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey(VirtGuestViewKind.snapshots)));
    await _settle(tester);
  }

  group('snapshots', () {
    testWidgets('only where the host has them', (tester) async {
      _state = _state.copyWith(
        data: _snapshot(const VirtCapabilities(lxc: true)),
      );
      await pump(tester, wide: true);
      await tester.tap(find.text('web-01'));
      await _settle(tester);
      expect(
        find.byKey(const ValueKey(VirtGuestViewKind.snapshots)),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey(VirtGuestViewKind.overview)),
        findsOneWidget,
      );
    });

    testWidgets('a tree, the current one marked', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');

      expect(_calls, contains('snapshots qemu/100'));
      expect(find.text('${app_locale.l10n.virtSnapshots} · 3'), findsOneWidget);
      // Depth-first from the root, each child indented further.
      double left(String name) => tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(ValueKey('snapshot:$name')),
              matching: find.byType(ListTile),
            ),
          )
          .dx;
      expect(left('base'), lessThan(left('disk-only')));
      expect(left('disk-only'), lessThan(left('with-mem')));
      expect(find.text(libL10n.current), findsOneWidget);
      expect(
        find.textContaining(app_locale.l10n.virtSnapshotWithMemory),
        findsOneWidget,
      );
      expect(
        find.textContaining(app_locale.l10n.virtSnapshotDiskOnly),
        findsNWidgets(2),
      );
    });

    testWidgets('create: a free name offered, a bad one refused', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');

      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      final name = find.descendant(
        of: find.byKey(const ValueKey('snapshot:name')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(name).controller!.text, 'snap-4');
      // A running VM on PVE: memory is the user's choice, on by default.
      final memory = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('snapshot:memory')),
      );
      expect(memory.value, isTrue);
      expect(memory.onChanged, isNotNull);

      FilledButton create() => tester.widget<FilledButton>(
        find.byKey(const ValueKey('snapshot:create')),
      );
      await tester.enterText(name, 'base');
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtSnapshotNameTaken), findsOneWidget);
      expect(create().onPressed, isNull);
      await tester.enterText(name, '1st try');
      await _settle(tester);
      expect(
        find.text(app_locale.l10n.virtSnapshotNameInvalid),
        findsOneWidget,
      );
      expect(create().onPressed, isNull);

      await tester.enterText(name, 'pre-upgrade');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('snapshot:desc')),
          matching: find.byType(TextField),
        ),
        'before 9.3',
      );
      await tester.tap(find.byKey(const ValueKey('snapshot:memory')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('snapshot:create')));
      await _settle(tester);

      expect(
        _calls,
        contains('create qemu/100 pre-upgrade before 9.3 memory=false'),
      );
      // Listed again after it.
      expect(_calls.where((c) => c == 'snapshots qemu/100').length, 2);
    });

    testWidgets('create: a container has no memory to offer', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'dns-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('snapshot:memory')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('snapshot:create')));
      await _settle(tester);
      expect(_calls, contains('create lxc/200 snap-1 null memory=false'));
    });

    testWidgets('create: libvirt always takes an active guest\'s memory', (
      tester,
    ) async {
      _state = _state.copyWith(
        data: _snapshot(_allCaps.copyWith(snapshotMemoryRequired: true)),
      );
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      final memory = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('snapshot:memory')),
      );
      expect(memory.value, isTrue);
      expect(memory.onChanged, isNull);
      expect(
        find.text(app_locale.l10n.virtSnapshotMemoryAlways),
        findsOneWidget,
      );
    });

    testWidgets('revert without memory warns it stops the guest, and can '
        'start it again', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.text('disk-only'));
      await _settle(tester);
      // Said before the button, too.
      expect(
        find.text(app_locale.l10n.virtSnapshotRevertStops('web-01')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('snapshot:revert:disk-only')));
      await _settle(tester);
      expect(find.text(libL10n.attention), findsOneWidget);
      expect(
        find.text(app_locale.l10n.virtSnapshotRevertStops('web-01')),
        findsNWidgets(2),
      );
      final start = find.byKey(const ValueKey('snapshot:startAfter'));
      expect(tester.widget<CheckboxListTile>(start).value, isTrue);

      // Cancelled: nothing sent.
      await tester.tap(find.text(libL10n.cancel));
      await _settle(tester);
      expect(_calls.where((c) => c.startsWith('revert')), isEmpty);

      await tester.tap(find.byKey(const ValueKey('snapshot:revert:disk-only')));
      await _settle(tester);
      await tester.tap(start);
      await _settle(tester);
      await tester.tap(find.text(libL10n.ok));
      await _settle(tester);
      expect(_calls, contains('revert qemu/100 disk-only start=false'));
    });

    testWidgets('revert with memory offers no start', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.text('with-mem'));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('snapshot:revert:with-mem')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('snapshot:startAfter')), findsNothing);
      await tester.tap(find.text(libL10n.ok));
      await _settle(tester);
      expect(_calls, contains('revert qemu/100 with-mem start=false'));
    });

    testWidgets('delete is confirmed', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.text('base'));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('snapshot:delete:base')));
      await _settle(tester);
      await tester.tap(find.text(libL10n.cancel));
      await _settle(tester);
      expect(_calls.where((c) => c.startsWith('delete')), isEmpty);

      await tester.tap(find.byKey(const ValueKey('snapshot:delete:base')));
      await _settle(tester);
      await tester.tap(find.text(libL10n.ok));
      await _settle(tester);
      expect(_calls, contains('delete qemu/100 base'));
    });

    testWidgets('a guest with an operation in flight offers none', (
      tester,
    ) async {
      _state = _state.copyWith(snapshotOps: {'qemu/100': VirtSnapshotOp.create});
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      final add = tester.widget<Btn>(find.byKey(const ValueKey('snapshot:new')));
      expect(add.onTap, isNull);
      // No power action either while it runs.
      for (final a in VirtPowerAction.values) {
        expect(find.byKey(ValueKey(a)), findsNothing);
      }
    });

    testWidgets('none says so', (tester) async {
      _snaps.remove('qemu/100');
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      expect(find.text(app_locale.l10n.virtSnapshotNone), findsOneWidget);
    });
  });

  group('storage', () {
    testWidgets('wide: pools in the list, one beside it with its volumes', (
      tester,
    ) async {
      await pump(tester, wide: true);
      final pill = find.byKey(const ValueKey(VirtSection.storage));
      final ink = tester.widget<InkWell>(
        find.descendant(of: pill, matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNotNull);
      await tester.tap(pill);
      await _settle(tester);

      expect(find.byKey(const ValueKey('pool:pve/local-lvm')), findsOneWidget);
      expect(find.byKey(const ValueKey('pool:pve/nfs')), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      // The guests are not listed in this section.
      expect(find.text('web-01'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pool:pve/local-lvm')));
      await _settle(tester);
      expect(find.byType(VirtPoolView), findsOneWidget);
      expect(find.byType(VirtPoolPage), findsNothing);
      expect(_calls, contains('volumes pve/local-lvm'));
      expect(find.text('${app_locale.l10n.virtVolumes} · 2'), findsOneWidget);
      // The owner by name; a volume nobody uses says so.
      expect(find.textContaining('web-01'), findsOneWidget);
      expect(find.textContaining(app_locale.l10n.unused), findsOneWidget);
      expect(find.text('pve/data'), findsOneWidget);
    });

    testWidgets('an inactive pool lists no volumes, and says why', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await tester.tap(find.byKey(const ValueKey(VirtSection.storage)));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('pool:pve/nfs')));
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtPoolInactive), findsOneWidget);
      expect(_calls, isNot(contains('volumes pve/nfs')));
    });

    testWidgets('narrow: a pool is pushed over the list', (tester) async {
      await pump(tester, wide: false);
      await tester.tap(find.byKey(const ValueKey(VirtSection.storage)));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('pool:pve/local-lvm')));
      await _settle(tester);
      expect(find.byType(VirtPoolPage), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('network', () {
    testWidgets('wide: a bridge with its guests; a guest opens in place', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await tester.tap(find.byKey(const ValueKey(VirtSection.network)));
      await _settle(tester);
      expect(find.byKey(const ValueKey('net:pve/vmbr0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('net:pve/vmbr0')));
      await _settle(tester);
      expect(find.byType(VirtNetworkView), findsOneWidget);
      expect(find.text('192.168.31.20/24'), findsOneWidget);
      expect(find.text('nic0'), findsWidgets);
      expect(
        find.text('${app_locale.l10n.virtAttachedGuests} · 1'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('netguest:0')));
      await _settle(tester);
      // Back in the guests section, with that guest beside the list.
      expect(find.byType(VirtGuestView), findsOneWidget);
      expect(find.text('dns-01'), findsOneWidget);
    });

    testWidgets('a port is not somewhere guests attach', (tester) async {
      await pump(tester, wide: true);
      await tester.tap(find.byKey(const ValueKey(VirtSection.network)));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('net:pve/nic0')));
      await _settle(tester);
      expect(find.textContaining(app_locale.l10n.virtAttachedGuests), findsNothing);
    });

    testWidgets('narrow: pushed, and a guest on it is pushed too', (
      tester,
    ) async {
      await pump(tester, wide: false);
      await tester.tap(find.byKey(const ValueKey(VirtSection.network)));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('net:pve/vmbr0')));
      await _settle(tester);
      expect(find.byType(VirtNetworkPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('netguest:0')));
      await _settle(tester);
      expect(find.byType(VirtGuestPage), findsOneWidget);
    });
  });

  testWidgets('a failure to list pools is shown in the column', (
    tester,
  ) async {
    _failPools = true;
    addTearDown(() => _failPools = false);
    await pump(tester, wide: true);
    await tester.tap(find.byKey(const ValueKey(VirtSection.storage)));
    await _settle(tester);
    expect(find.text(app_locale.l10n.virtErrUnreachable), findsOneWidget);
    expect(find.byTooltip(libL10n.retry), findsOneWidget);

    // Asked again on the retry, and listed once it answers.
    _failPools = false;
    await tester.tap(find.byTooltip(libL10n.retry));
    await _settle(tester);
    expect(find.byKey(const ValueKey('pool:pve/local-lvm')), findsOneWidget);
    expect(_calls.where((c) => c == 'pools').length, 2);
  });
}

bool _failPools = false;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
