/// The Virtualization tab's snapshots, storage and network views over
/// scripted hosts: the sections enabled by capability, the snapshot tree,
/// each snapshot action behind its confirmation, and pools and networks in
/// both layouts.
///
/// As in `virt_tab_test.dart`, the providers are replaced, not the backends.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
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
import 'package:server_box/view/page/virt/resources.dart';
import 'package:server_box/view/page/virt/tab.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/segment.dart';
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

/// What PVE offers for managing them.
const _manageCaps = VirtCapabilities(
  lxc: true,
  pause: true,
  snapshots: true,
  storage: true,
  network: true,
  storageEdit: true,
  poolTypes: ['dir', 'lvmthin', 'nfs', 'zfspool'],
  upload: true,
  networkEdit: true,
  networkEditExisting: true,
  networkRestart: true,
  networkModes: ['bridge'],
  networkApply: true,
);

/// A node's pending network configuration, when set.
List<VirtNetworkChanges> _changes = const [];

final _snaps = <String, List<VirtGuestSnapshot>>{};
final _calls = <String>[];

/// Every change `manage` was handed, whole: what a form sent.
final _sent = <VirtResourceChange>[];

/// What `manage` throws after taking a change, when set.
VirtErr? _manageErr;
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

/// The host's networks, as the fake backend lists them; a test that needs
/// others replaces this and puts it back.
List<VirtNetwork> _networks = _defaultNetworks;

const _defaultNetworks = [
  VirtNetwork(
    id: 'pve/vmbr0',
    name: 'vmbr0',
    node: 'pve',
    mode: 'bridge',
    cidrs: ['192.168.31.20/24'],
    gateway: '192.168.31.1',
    ports: ['nic0'],
    autostart: true,
    // It carries the host's own address: the app does not edit it.
    managementEditable: false,
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

  /// Scripted per guest, for the chain, its refusal and a snapshot's diff.
  static final _chain = <String, VirtSnapChain>{};
  static final _refusals = <String, String?>{};
  static final _diffs = <String, List<VirtSnapDiff>>{};

  @override
  Future<void> createSnapshot(
    String guestId, {
    required String name,
    String? description,
    bool memory = false,
    VirtSnapshotForm form = VirtSnapshotForm.internal,
    String? overlayPool,
  }) async => _calls.add(
    'create $guestId $name $description memory=$memory form=${form.name} '
    'pool=$overlayPool',
  );

  @override
  Future<VirtSnapChain> snapshotChain(String guestId) async {
    _calls.add('chain $guestId');
    return _chain[guestId] ?? const VirtSnapChain();
  }

  @override
  Future<String?> snapshotRefusal(String guestId) async {
    _calls.add('refusal $guestId');
    return _refusals[guestId];
  }

  @override
  Future<List<VirtSnapDiff>> snapshotDiff(String guestId, String name) async {
    _calls.add('diff $guestId $name');
    return _diffs['$guestId/$name'] ?? const [];
  }

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
    if (_failVolumes) {
      throw const VirtErr(type: VirtErrType.unreachable, message: 'timeout');
    }
    return _volumes[pool.id] ?? const [];
  }

  @override
  Future<List<VirtNetwork>> networks() async {
    _calls.add('networks');
    return _networks;
  }

  @override
  Future<List<VirtNetworkChanges>> networkChanges() async => _changes;

  @override
  Future<int?> nextVmid() async => 105;

  @override
  Future<void> manage(VirtResourceChange change) async {
    _sent.add(change);
    if (_manageErr case final e?) throw e;
    _calls.add(switch (change) {
      VirtVolumeCreate(:final name, :final gib, :final format) =>
        'manage volume $name $gib $format',
      VirtVolumeDelete(:final volume) => 'manage delete ${volume.id}',
      VirtPoolCreate(:final name, :final type, :final source) =>
        'manage pool $name $type $source',
      VirtNetworkCreate(:final name, :final node) => 'manage bridge $name $node',
      VirtNetworkApply(:final node) => 'manage apply $node',
      _ => 'manage ${change.runtimeType} ${change.scope}',
    });
  }
}

void main() {
  // The snapshot form asks `sbm_virt` its rules (a name, the memory).
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
    _calls.clear();
    _sent.clear();
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
  }

  Future<void> openSnapshots(WidgetTester tester, String guest) async {
    await tester.tap(find.text(guest));
    await _settle(tester);
    await tester.tap(segment(app_locale.l10n.virtSnapshots));
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
        segment(app_locale.l10n.virtSnapshots),
        findsNothing,
      );
      expect(
        segment(app_locale.l10n.virtOverview),
        findsOneWidget,
      );
    });

    testWidgets('narrow: a long name deep in the tree is cut, not overflowed', (
      tester,
    ) async {
      final long = 'a-snapshot-with-a-name-this-long-${'x' * 6}';
      _snaps['qemu/100'] = [
        ..._snaps['qemu/100']!.map((s) => s.copyWith(current: false)),
        VirtGuestSnapshot(
          name: long,
          parent: 'with-mem',
          createdAt: DateTime(2026, 9, 4),
          withMemory: true,
          current: true,
        ),
      ];
      await pump(tester, wide: false);
      await openSnapshots(tester, 'web-01');
      expect(tester.takeException(), isNull);
      expect(find.byKey(ValueKey('hw:disc:snapshot:$long')), findsOneWidget);
    });

    testWidgets('a tree, the current one marked', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');

      expect(_calls, contains('snapshots qemu/100'));
      expect(find.text(app_locale.l10n.virtSnapshotCount(3)), findsOneWidget);
      // Depth-first from the root, each child indented further.
      double left(String name) =>
          tester.getTopLeft(find.byKey(ValueKey('hw:disc:snapshot:$name'))).dx;
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
      final memory = _memorySwitch(tester);
      expect(memory.value, isTrue);
      expect(memory.onChanged, isNotNull);

      Btn create() =>
          tester.widget<Btn>(find.byKey(const ValueKey('snapshot:create')));
      await tester.enterText(name, 'base');
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtSnapshotNameTaken), findsOneWidget);
      expect(create().onTap, isNull);
      await tester.enterText(name, '1st try');
      await _settle(tester);
      expect(
        find.text(app_locale.l10n.virtSnapshotNameInvalid),
        findsOneWidget,
      );
      expect(create().onTap, isNull);

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
        contains('create qemu/100 pre-upgrade before 9.3 memory=false form=internal pool=null'),
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
      expect(_calls, contains('create lxc/200 snap-1 null memory=false form=internal pool=null'));
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
      final memory = _memorySwitch(tester);
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
      await tester.tap(segment(libL10n.storage));
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
      expect(find.text(app_locale.l10n.virtVolumes), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // The owner by name; a volume nobody uses says so.
      expect(find.textContaining('web-01'), findsOneWidget);
      expect(find.textContaining(app_locale.l10n.unused), findsOneWidget);
      expect(find.text('pve/data'), findsOneWidget);
    });

    testWidgets('an inactive pool lists no volumes, and says why', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await tester.tap(segment(libL10n.storage));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('pool:pve/nfs')));
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtPoolInactive), findsOneWidget);
      expect(_calls, isNot(contains('volumes pve/nfs')));
    });

    testWidgets('narrow: a pool is pushed over the list', (tester) async {
      await pump(tester, wide: false);
      await tester.tap(segment(libL10n.storage));
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
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      expect(find.byKey(const ValueKey('net:pve/vmbr0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('net:pve/vmbr0')));
      await _settle(tester);
      expect(find.byType(VirtNetworkView), findsOneWidget);
      expect(find.text('192.168.31.20/24'), findsOneWidget);
      expect(find.text('nic0'), findsWidgets);
      expect(
        find.text(app_locale.l10n.virtAttachedGuests.toUpperCase()),
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
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('net:pve/nic0')));
      await _settle(tester);
      expect(find.textContaining(app_locale.l10n.virtAttachedGuests), findsNothing);
    });

    testWidgets('narrow: pushed, and a guest on it is pushed too', (
      tester,
    ) async {
      await pump(tester, wide: false);
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('net:pve/vmbr0')));
      await _settle(tester);
      expect(find.byType(VirtNetworkPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('netguest:0')));
      await _settle(tester);
      expect(find.byType(VirtGuestPage), findsOneWidget);
    });
  });

  group('managing', () {
    setUp(() {
      _state = _state.copyWith(data: _snapshot(_manageCaps));
      _changes = const [];
    });

    Future<void> openPool(WidgetTester tester) async {
      await tester.tap(segment(libL10n.storage));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('pool:pve/local-lvm')));
      await _settle(tester);
    }

    Btn btn(WidgetTester tester, String key) =>
        tester.widget<Btn>(find.byKey(ValueKey(key)));

    testWidgets('a volume a guest uses cannot be deleted, nor the pool stopped', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await openPool(tester);
      await tester.tap(find.byKey(const ValueKey('hw:disc:vol:local-lvm:vm-100-disk-0')));
      await _settle(tester);
      expect(btn(tester, 'pool:vol:vm-100-disk-0:delete').onTap, isNull);
      expect(find.text(app_locale.l10n.virtVolInUse), findsOneWidget);
      expect(btn(tester, 'pool:stop').onTap, isNull);
      expect(btn(tester, 'pool:delete').onTap, isNull);
      expect(find.text(app_locale.l10n.virtPoolInUse), findsOneWidget);
    });

    testWidgets('a pool whose volumes are not known cannot be stopped', (
      tester,
    ) async {
      // A failed listing is no proof nothing on it is used.
      _failVolumes = true;
      addTearDown(() => _failVolumes = false);
      await pump(tester, wide: true);
      await openPool(tester);
      expect(btn(tester, 'pool:stop').onTap, isNull);
      expect(btn(tester, 'pool:delete').onTap, isNull);
    });

    testWidgets('PVE: a storage used on another node cannot be disabled', (
      tester,
    ) async {
      // `/storage/local-lvm` is the cluster's: nothing used on this node,
      // a guest's disk on the other.
      final saved = _volumes['pve/local-lvm'];
      _volumes['pve/local-lvm'] = [saved!.last];
      _volumes['pve2/local-lvm'] = [
        const VirtVolume(
          id: 'local-lvm:vm-100-disk-1',
          name: 'vm-100-disk-1',
          format: 'raw',
          users: [VirtGuestRef(vmid: 100)],
        ),
      ];
      _pools.add(
        const VirtStoragePool(
          id: 'pve2/local-lvm',
          name: 'local-lvm',
          node: 'pve2',
          type: 'lvmthin',
        ),
      );
      addTearDown(() {
        _volumes['pve/local-lvm'] = saved;
        _volumes.remove('pve2/local-lvm');
        _pools.removeLast();
      });
      await pump(tester, wide: true);
      await openPool(tester);
      expect(_calls, contains('volumes pve2/local-lvm'));
      expect(btn(tester, 'pool:stop').onTap, isNull);
      expect(btn(tester, 'pool:delete').onTap, isNull);
      expect(find.text(app_locale.l10n.virtPoolInUse), findsOneWidget);
    });

    testWidgets('PVE: disabling a storage says it is the cluster\'s', (
      tester,
    ) async {
      // Nothing on it used anywhere: the switch is offered, and asks.
      final saved = _volumes['pve/local-lvm'];
      _volumes['pve/local-lvm'] = [saved!.last];
      addTearDown(() => _volumes['pve/local-lvm'] = saved);
      await pump(tester, wide: true);
      await openPool(tester);
      expect(btn(tester, 'pool:stop').onTap, isNotNull);
      // A verb on the button, not the state it would leave.
      expect(btn(tester, 'pool:stop').text, app_locale.l10n.virtStorageDisable);
      await tester.tap(find.byKey(const ValueKey('pool:stop')));
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtStorageClusterWide), findsOneWidget);
      await tester.tap(find.text(libL10n.cancel));
      await _settle(tester);
    });

    testWidgets('a base image others are made on is in use', (tester) async {
      // Attached to no guest, and still what other disks are made on.
      final saved = _volumes['pve/local-lvm'];
      _volumes['pve/local-lvm'] = [
        saved!.first,
        const VirtVolume(
          id: 'local-lvm:base-9000-disk-0',
          name: 'base-9000-disk-0',
          format: 'raw',
          content: 'images',
          capacity: 1 << 30,
          backs: ['/dev/pve/vm-101-disk-0'],
        ),
      ];
      addTearDown(() => _volumes['pve/local-lvm'] = saved);
      await pump(tester, wide: true);
      await openPool(tester);
      await tester.tap(find.byKey(const ValueKey('hw:disc:vol:local-lvm:base-9000-disk-0')));
      await _settle(tester);
      expect(btn(tester, 'pool:vol:base-9000-disk-0:delete').onTap, isNull);
      expect(find.byKey(const ValueKey('pool:vol:base-9000-disk-0:attach')), findsNothing);
      expect(find.text(app_locale.l10n.virtVolIsBase), findsOneWidget);
      expect(
        find.textContaining(app_locale.l10n.virtVolBackingOf('vm-101-disk-0')),
        findsWidgets,
      );
      expect(btn(tester, 'pool:stop').onTap, isNull);
    });

    testWidgets('a left-over volume is deleted, never attached', (
      tester,
    ) async {
      // VMID 999 has no guest: the volume is unused, and still 999's.
      final saved = _volumes['pve/local-lvm'];
      _volumes['pve/local-lvm'] = [
        saved!.first,
        const VirtVolume(
          id: 'local-lvm:vm-999-disk-0',
          name: 'vm-999-disk-0',
          format: 'raw',
          content: 'images',
          capacity: 1 << 30,
          users: [VirtGuestRef(vmid: 999)],
        ),
      ];
      addTearDown(() => _volumes['pve/local-lvm'] = saved);
      await pump(tester, wide: true);
      await openPool(tester);
      await tester.tap(find.byKey(const ValueKey('hw:disc:vol:local-lvm:vm-999-disk-0')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('pool:vol:vm-999-disk-0:attach')), findsNothing);
      expect(btn(tester, 'pool:vol:vm-999-disk-0:delete').onTap, isNotNull);
    });

    testWidgets('narrow: switching pools leaves the last one\'s form behind', (
      tester,
    ) async {
      _pools.add(
        const VirtStoragePool(
          id: 'pve/local',
          name: 'local',
          node: 'pve',
          type: 'dir',
          content: ['images'],
        ),
      );
      addTearDown(_pools.removeLast);
      await pump(tester, wide: false);
      await openPool(tester);
      await tester.tap(find.byKey(const ValueKey('pool:vol:new')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('pool:vol:create')), findsOneWidget);

      await tester.tap(find.byType(SessionSwitcherLabel).last);
      await _settle(tester);
      await tester.tap(find.text('local'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('pool:vol:create')), findsNothing);
    });

    testWidgets('an unused volume is deleted after a red confirmation', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await openPool(tester);
      await tester.tap(find.byKey(const ValueKey('hw:disc:vol:local-lvm:vm-999-disk-0')));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('pool:vol:vm-999-disk-0:delete')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('pool:vol:vm-999-disk-0:delete')));
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtVolDeleteAsk('vm-999-disk-0', 'local-lvm')), findsOneWidget);
      await tester.tap(find.text(libL10n.cancel));
      await _settle(tester);
      expect(_calls.where((c) => c.startsWith('manage')), isEmpty);
      await tester.tap(find.byKey(const ValueKey('pool:vol:vm-999-disk-0:delete')));
      await _settle(tester);
      await tester.tap(find.text(libL10n.ok));
      await _settle(tester);
      expect(_calls, contains('manage delete local-lvm:vm-999-disk-0'));
    });

    testWidgets('a new volume: named for the next VMID, raw on thin LVM', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await openPool(tester);
      await tester.tap(find.byKey(const ValueKey('pool:vol:new')));
      await _settle(tester);
      expect(find.text('vm-105-disk-0'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('pool:vol:create')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('pool:vol:create')));
      await _settle(tester);
      expect(_calls, contains('manage volume vm-105-disk-0 20 raw'));
    });

    testWidgets('a new storage: the form beside the list, then the storage', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await tester.tap(segment(libL10n.storage));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('virt:create')));
      await _settle(tester);
      expect(find.byType(VirtPoolCreateView), findsOneWidget);
      final create = find.byKey(const ValueKey('pool:new:create'));
      expect(tester.widget<Btn>(create).onTap, isNull);
      await tester.enterText(find.byKey(const ValueKey('pool:new:name')), 'Bad Name');
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtResNameInvalid), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('pool:new:name')), 'data-2');
      await tester.enterText(find.byKey(const ValueKey('pool:new:source')), '/srv/data');
      await _settle(tester);
      await tester.tap(create);
      await _settle(tester);
      expect(_calls, contains('manage pool data-2 dir /srv/data'));
      expect(find.byType(VirtPoolCreateView), findsNothing);
    });

    testWidgets('narrow: the new network form is pushed over the list', (
      tester,
    ) async {
      await pump(tester, wide: false);
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('virt:create')));
      await _settle(tester);
      expect(find.byType(VirtResourceCreatePage), findsOneWidget);
      expect(find.byType(VirtNetworkCreateView), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('a network in use cannot be deleted', (tester) async {
      await pump(tester, wide: true);
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('net:pve/vmbr0')));
      await _settle(tester);
      expect(btn(tester, 'net:delete').onTap, isNull);
      expect(find.text(app_locale.l10n.virtNetInUse(1)), findsOneWidget);
    });

    testWidgets('PVE: a new bridge, the pending changes, applied after asking', (
      tester,
    ) async {
      _changes = const [
        VirtNetworkChanges(node: 'pve', diff: '+auto vmbr1\n+iface vmbr1 inet manual'),
      ];
      await pump(tester, wide: true);
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtNetPendingTitle('pve')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('virt:create')));
      await _settle(tester);
      expect(find.byType(VirtNetworkCreateView), findsOneWidget);
      // The next free name, as the design fills it in.
      expect(find.text('vmbr1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('net:new:create')));
      await _settle(tester);
      expect(_calls, contains('manage bridge vmbr1 pve'));

      await tester.tap(find.byKey(const ValueKey('net:pending:pve:apply')).first);
      await _settle(tester);
      expect(find.text(app_locale.l10n.virtNetApplyAsk('pve')), findsOneWidget);
      await tester.tap(find.text(libL10n.ok));
      await _settle(tester);
      expect(_calls, contains('manage apply pve'));
    });
  });

  testWidgets('a failure to list pools is shown in the column', (
    tester,
  ) async {
    _failPools = true;
    addTearDown(() => _failPools = false);
    await pump(tester, wide: true);
    await tester.tap(segment(libL10n.storage));
    await _settle(tester);
    expect(find.text(app_locale.l10n.virtErrUnreachable), findsOneWidget);
    expect(find.byTooltip(libL10n.retry), findsOneWidget);

    // A retry that fails again is shown in the card again, not thrown.
    await tester.tap(find.byTooltip(libL10n.retry));
    await _settle(tester);
    expect(find.text(app_locale.l10n.virtErrUnreachable), findsOneWidget);
    expect(_calls.where((c) => c == 'pools').length, 2);

    // Asked again on the retry, and listed once it answers.
    _failPools = false;
    await tester.tap(find.byTooltip(libL10n.retry));
    await _settle(tester);
    expect(find.byKey(const ValueKey('pool:pve/local-lvm')), findsOneWidget);
    expect(_calls.where((c) => c == 'pools').length, 3);
  });

  _phase10(pump);
  _phase8(pump, openSnapshots);
}

bool _failPools = false;
bool _failVolumes = false;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// --- Snapshots, phase 8: the external form, the chain, the diff -----------

/// What a libvirt host offers: snapshots, internal and external.
const _libvirtCaps = VirtCapabilities(
  pause: true,
  snapshots: true,
  snapshotMemoryRequired: true,
  snapshotExternal: true,
  storage: true,
  network: true,
  networkEdit: true,
  networkEditExisting: true,
  networkRestart: true,
);

/// A guest on a two-layer chain, as an external snapshot leaves it.
VirtSnapChain _chainOf({
  String? refusal,
  String? externalRefusal,
  List<String> pools = const ['images'],
}) => VirtSnapChain(
      pools: pools,
      refusal: refusal,
      externalRefusal: externalRefusal ?? refusal,
      disks: [
        const VirtSnapChainDisk(
          target: 'vda',
          pool: 'images',
          files: [
            VirtSnapChainFile(
              path: '/var/lib/libvirt/images/web.qcow2.snap-1',
              format: 'qcow2',
              allocation: 1048576,
              backing: '/var/lib/libvirt/images/web.qcow2',
              snap: 'snap-1',
              active: true,
            ),
            VirtSnapChainFile(
              path: '/var/lib/libvirt/images/web.qcow2',
              format: 'qcow2',
              allocation: 5242880,
            ),
          ],
        ),
      ],
    );

/// Editing an existing network in place: its configuration rows are a
/// draft, held in the view until Save and dropped by Revert.
void _phase10(
  Future<void> Function(WidgetTester, {required bool wide}) pump,
) {
  group('network editing', () {
    setUp(() {
      _state = VirtHostState(
        serverId: _pve,
        kind: VirtHostKind.libvirt,
        data: _snapshot(_libvirtCaps),
      );
    });
    tearDown(() {
      _networks = _defaultNetworks;
      _manageErr = null;
    });

    /// Built rows, on screen or not: the pane is one scrolling column.
    Finder key(String k) => find.byKey(ValueKey(k), skipOffstage: false);

    Future<void> tap(WidgetTester tester, String k) async {
      await tester.ensureVisible(key(k));
      await _settle(tester);
      await tester.tap(key(k));
      await _settle(tester);
    }

    Future<void> type(WidgetTester tester, String k, String text) async {
      await tester.ensureVisible(key(k));
      await _settle(tester);
      await tester.enterText(key(k), text);
      await _settle(tester);
    }

    String text(WidgetTester tester, String k) =>
        tester.widget<Input>(key(k)).controller!.text;

    Btn btn(WidgetTester tester, String k) => tester.widget<Btn>(key(k));

    Future<void> open(WidgetTester tester, String id) async {
      await pump(tester, wide: true);
      await tester.tap(segment(libL10n.network));
      await _settle(tester);
      await tester.tap(find.byKey(ValueKey('net:$id')));
      await _settle(tester);
    }

    /// A libvirt NAT network with a DHCP range and a static host.
    VirtNetwork lab({bool active = true, List<VirtGuestRef> users = const []}) =>
        VirtNetwork(
          id: 'lab',
          name: 'lab',
          // No node: a libvirt network.
          mode: 'nat',
          active: active,
          cidrs: const ['192.168.150.1/24'],
          dhcpRanges: const ['192.168.150.100-192.168.150.200'],
          bridge: 'virbr1',
          hosts: const [
            VirtNetHost(mac: '52:54:00:aa:bb:01', ip: '192.168.150.10', name: 'h1'),
          ],
          xml:
              '<network>\n'
              '  <name>lab</name>\n'
              "  <forward mode='nat'/>\n"
              '  <ip address=\'192.168.150.1\' prefix=\'24\'>\n'
              '    <dhcp>\n'
              '      <range start=\'192.168.150.100\' end=\'192.168.150.200\'/>\n'
              '    </dhcp>\n'
              '  </ip>\n'
              '</network>\n',
          users: users,
        );

    testWidgets('the rows, the definition, and the restart', (tester) async {
      _networks = [
        lab(
          users: const [
            VirtGuestRef(guestId: 'qemu/100', device: 'vnet0', mac: '52:54:00:11:22:33'),
          ],
        ),
      ];
      await open(tester, 'lab');
      // The configuration is its rows, edited in place: no form to open,
      // and nothing to save until something changes.
      for (final k in [
        'net:edit:mode:nat',
        'net:edit:cidr',
        'hw:toggle:net:edit:dhcp',
        'net:edit:dhcp:start',
        'net:edit:host:0:mac',
      ]) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(text(tester, 'net:edit:cidr'), '192.168.150.1/24');
      expect(key('net:edit:save'), findsNothing);
      // Its own definition, folded in a group of its own.
      expect(key('hw:disc:config'), findsOneWidget);
      await tap(tester, 'hw:disc:config');
      expect(find.textContaining("<forward mode='nat'/>"), findsOneWidget);

      // An address that is not one: Save is held back, and says why.
      await type(tester, 'net:edit:cidr', 'garbage');
      expect(btn(tester, 'net:edit:save').onTap, isNull);
      expect(_sent, isEmpty);
      // Back to what it was, and only the static host's name changed: valid
      // as the network is, and no restart — `net-update` takes a host live.
      await type(tester, 'net:edit:cidr', '192.168.150.1/24');
      await type(tester, 'net:edit:host:0:name', 'h2');
      expect(key('hw:toggle:net:edit:restart'), findsNothing);
      await tap(tester, 'net:edit:save');
      final sent = _sent.single as VirtNetworkEdit;
      expect((sent.address, sent.prefix), ('192.168.150.1', 24));
      expect((sent.dhcpStart, sent.dhcpEnd), ('192.168.150.100', '192.168.150.200'));
      expect(sent.hosts.single.name, 'h2');
      // Saved: no draft is left, and the rows are the network's again.
      expect(key('net:edit:save'), findsNothing);
      expect(text(tester, 'net:edit:host:0:name'), 'h1');

      // A new address: now a restart is offered and says what it costs, and
      // the range and the host must move with it.
      _sent.clear();
      await type(tester, 'net:edit:cidr', '192.168.151.1/24');
      expect(key('hw:toggle:net:edit:restart'), findsOneWidget);
      expect(
        find.text(app_locale.l10n.virtNetEditRestartNote, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(app_locale.l10n.virtNetEditAsk(1), skipOffstage: false),
        findsOneWidget,
      );
      // The old range is outside the new subnet: refused until it moves.
      expect(btn(tester, 'net:edit:save').onTap, isNull);
      await tap(tester, 'net:edit:revert');
      expect(text(tester, 'net:edit:cidr'), '192.168.150.1/24');
      expect(key('hw:toggle:net:edit:restart'), findsNothing);
      expect(_sent, isEmpty, reason: 'reverted');
    });

    testWidgets('an edit is a draft until Save; Revert discards it', (
      tester,
    ) async {
      _networks = [lab(active: false)];
      await open(tester, 'lab');
      await tap(tester, 'net:edit:mode:isolated');
      await type(tester, 'net:edit:cidr', '10.9.0.1/24');
      await tap(tester, 'hw:toggle:net:edit:dhcp');
      // Nothing is sent while it is edited.
      expect(_sent, isEmpty);
      expect(key('net:edit:revert'), findsOneWidget);
      expect(key('hw:toggle:net:edit:dhcp'), findsOneWidget);

      await tap(tester, 'net:edit:revert');
      expect(_sent, isEmpty);
      expect(key('net:edit:save'), findsNothing);
      expect(text(tester, 'net:edit:cidr'), '192.168.150.1/24');
      expect(key('net:edit:dhcp:start'), findsOneWidget, reason: 'DHCP on again');

      // Made again and saved: sent once, as the rows say.
      await tap(tester, 'net:edit:mode:isolated');
      await tap(tester, 'net:edit:save');
      final sent = _sent.single as VirtNetworkEdit;
      expect((sent.mode, sent.address, sent.prefix), ('isolated', '192.168.150.1', 24));
      // Inactive: nothing runs to restart.
      expect(key('hw:toggle:net:edit:restart'), findsNothing);
    });

    testWidgets('a failed save keeps the draft; a conflict drops it', (
      tester,
    ) async {
      _networks = [lab(active: false)];
      await open(tester, 'lab');
      _manageErr = const VirtErr(type: VirtErrType.unreachable, message: 'timeout');
      await type(tester, 'net:edit:cidr', '192.168.152.1/24');
      await type(tester, 'net:edit:dhcp:start', '192.168.152.100');
      await type(tester, 'net:edit:dhcp:end', '192.168.152.200');
      await type(tester, 'net:edit:host:0:ip', '192.168.152.10');
      await tap(tester, 'net:edit:save');
      expect(_sent, hasLength(1));
      expect(text(tester, 'net:edit:cidr'), '192.168.152.1/24', reason: 'kept to retry');
      expect(key('net:edit:save'), findsOneWidget);

      // Changed on the host since it was read: the draft's base is gone.
      _manageErr = const VirtErr(type: VirtErrType.conflict);
      await tap(tester, 'net:edit:save');
      expect(_sent, hasLength(2));
      expect(text(tester, 'net:edit:cidr'), '192.168.150.1/24');
      expect(key('net:edit:save'), findsNothing);
    });

    testWidgets('bridge mode sends no static hosts, and keeps them', (
      tester,
    ) async {
      _networks = const [
        VirtNetwork(
          id: 'lab',
          name: 'lab',
          mode: 'nat',
          cidrs: ['192.168.150.1/24'],
          hosts: [
            VirtNetHost(mac: '52:54:00:aa:bb:01', ip: '192.168.150.10'),
          ],
        ),
      ];
      await open(tester, 'lab');
      await tap(tester, 'net:edit:mode:bridge');
      // Bridge mode serves no DHCP: the static hosts are not shown…
      expect(key('net:edit:host:0:mac'), findsNothing);
      // …and are still there when it switches back.
      await tap(tester, 'net:edit:mode:nat');
      expect(text(tester, 'net:edit:host:0:mac'), '52:54:00:aa:bb:01');
      await tap(tester, 'net:edit:mode:bridge');
      await type(tester, 'net:edit:bridge', 'br0');
      await tap(tester, 'net:edit:save');
      final sent = _sent.single as VirtNetworkEdit;
      expect((sent.mode, sent.bridge), ('bridge', 'br0'));
      expect(sent.hosts, isEmpty);
    });

    testWidgets('PVE: a bridge with only IPv6 has no IPv4 address to fix', (
      tester,
    ) async {
      _state = VirtHostState(serverId: _pve, kind: VirtHostKind.pve, data: _snapshot(_manageCaps));
      _networks = const [
        VirtNetwork(
          id: 'pve/vmbr6',
          name: 'vmbr6',
          node: 'pve',
          mode: 'bridge',
          active: true,
          cidrs: ['fd00:6::1/64'],
          ports: ['nic2'],
        ),
      ];
      await open(tester, 'pve/vmbr6');
      expect(text(tester, 'net:edit:cidr'), isEmpty);
      // The IPv6 address is shown, and is the host's to keep.
      expect(find.text('fd00:6::1/64', skipOffstage: false), findsOneWidget);
      // A ports-only edit goes through.
      await type(tester, 'net:edit:ports', 'nic2 nic3');
      await tap(tester, 'net:edit:save');
      final sent = _sent.single as VirtNetworkEditBridge;
      expect((sent.ports, sent.cidr), ('nic2 nic3', ''));
    });

    testWidgets('PVE: the address goes with its prefix; the host\'s own is not offered', (
      tester,
    ) async {
      _state = VirtHostState(serverId: _pve, kind: VirtHostKind.pve, data: _snapshot(_manageCaps));
      _networks = const [
        VirtNetwork(
          id: 'pve/vmbr7',
          name: 'vmbr7',
          node: 'pve',
          mode: 'bridge',
          active: true,
          cidrs: ['10.89.0.1/24'],
          ports: ['nic1'],
        ),
        VirtNetwork(
          id: 'pve/vmbr0',
          name: 'vmbr0',
          node: 'pve',
          mode: 'bridge',
          active: true,
          cidrs: ['192.168.31.20/24'],
          gateway: '192.168.31.1',
          managementEditable: false,
        ),
      ];
      await open(tester, 'pve/vmbr7');
      // As the design has it: saved as pending, applied with ifreload.
      expect(find.text(app_locale.l10n.virtNetPveApplyNote, skipOffstage: false), findsOneWidget);
      await type(tester, 'net:edit:cidr', '10.89.0.1/16');
      await tap(tester, 'net:edit:save');
      final sent = _sent.single as VirtNetworkEditBridge;
      expect(sent.cidr, '10.89.0.1/16');
      expect(sent.ports, 'nic1');

      // The management bridge: no rows to edit, no delete, and why.
      await tester.tap(find.byKey(const ValueKey('net:pve/vmbr0')));
      await _settle(tester);
      expect(key('net:edit:ports'), findsNothing);
      expect(key('net:edit:cidr'), findsNothing);
      expect(find.text(app_locale.l10n.virtNetManagementTip, skipOffstage: false), findsOneWidget);
    });

    testWidgets('PVE: nothing is edited while the node\'s networks are busy', (
      tester,
    ) async {
      _state = VirtHostState(
        serverId: _pve,
        kind: VirtHostKind.pve,
        data: _snapshot(_manageCaps),
        resourceOps: {VirtResourceChange.netNodeScope('pve')},
      );
      _networks = const [
        VirtNetwork(
          id: 'pve/vmbr7',
          name: 'vmbr7',
          node: 'pve',
          mode: 'bridge',
          cidrs: ['10.89.0.1/24'],
          ports: ['nic1'],
        ),
      ];
      await open(tester, 'pve/vmbr7');
      expect(tester.widget<Input>(key('net:edit:ports')).enabled, isFalse);
      expect(tester.widget<Input>(key('net:edit:cidr')).enabled, isFalse);
      expect(
        tester
            .widget<SwitchX>(
              find.descendant(
                of: key('hw:toggle:net:edit:vlan'),
                matching: find.byType(SwitchX),
              ),
            )
            .onChanged,
        isNull,
      );
    });
  });
}

void _phase8(
  Future<void> Function(WidgetTester, {required bool wide}) pump,
  Future<void> Function(WidgetTester, String) openSnapshots,
) {
  group('snapshots: external form and the chain', () {
    setUp(() {
      _state = VirtHostState(
        serverId: _pve,
        kind: VirtHostKind.libvirt,
        data: _snapshot(_libvirtCaps),
      );
      _FakeHost._chain['qemu/100'] = _chainOf();
    });

    tearDown(() {
      _FakeHost._chain.clear();
      _FakeHost._refusals.clear();
      _FakeHost._diffs.clear();
    });

    testWidgets('the chain is drawn: depth, which file, and the base', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');

      expect(_calls, contains('chain qemu/100'));
      // The group's title, drawn upper-case as every group title is.
      expect(
        find.text(app_locale.l10n.virtSnapshotChain.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(app_locale.l10n.virtSnapshotChainDepth('2')),
        findsOneWidget,
      );
      // The overlay the guest writes to now, and the base image below it.
      expect(find.text('web.qcow2.snap-1'), findsOneWidget);
      expect(find.text('web.qcow2'), findsOneWidget);
      expect(
        find.text(app_locale.l10n.virtSnapshotChainActive),
        findsOneWidget,
      );
      expect(find.text(app_locale.l10n.virtSnapshotChainBase), findsOneWidget);
    });

    testWidgets('a raw disk is refused before the form offers one', (
      tester,
    ) async {
      _FakeHost._chain['qemu/100'] = _chainOf(
        refusal: 'disk vda is raw: an external snapshot needs a qcow2 image',
      );
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      // Said once, at the top; neither kind of snapshot is offered.
      expect(
        find.textContaining('disk vda is raw'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('snapshot:new')), findsNothing);
    });

    testWidgets('a pull reads the chain and the refusal again', (
      tester,
    ) async {
      _FakeHost._chain['qemu/100'] = _chainOf(
        refusal: 'disk vda is raw: an external snapshot needs a qcow2 image',
      );
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      expect(find.byKey(const ValueKey('snapshot:new')), findsNothing);

      // Converted on the host since: a pull says so, not only the list.
      _FakeHost._chain['qemu/100'] = _chainOf();
      _calls.clear();
      await tester.fling(
        find
            .ancestor(
              of: find.textContaining('disk vda is raw'),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, 400),
        1000,
      );
      await _settle(tester);
      expect(_calls, contains('chain qemu/100'));
      expect(find.textContaining('disk vda is raw'), findsNothing);
      expect(find.byKey(const ValueKey('snapshot:new')), findsWidgets);
    });

    testWidgets('the form offers the external kind and the overlay pool', (
      tester,
    ) async {
      _snaps['qemu/100'] = [
        ..._snaps['qemu/100']!.map((s) => s.copyWith(current: false)),
        VirtGuestSnapshot(
          name: 'sx1',
          parent: 'with-mem',
          createdAt: DateTime(2026, 9, 4),
          external: true,
          current: true,
        ),
      ];
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);

      // The guest already has an external snapshot, so that kind is what
      // opens.
      expect(_selected(_formKind(VirtSnapshotForm.external)), isTrue);
      // An external snapshot holds no memory, so the switch is gone.
      expect(find.byKey(const ValueKey('snapshot:memory')), findsNothing);
      expect(
        find.text(app_locale.l10n.virtSnapshotExternalExists('2')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('snapshot:pool')), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('snapshot:name')),
          matching: find.byType(TextField),
        ),
        'pre-upgrade',
      );
      await _settle(tester);
      // Nothing picked: the picker says "beside each disk", and that is what
      // is sent — no pool, so libvirt places each overlay by its disk.
      expect(
        find.text(app_locale.l10n.virtSnapshotOverlayBeside),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('snapshot:create')));
      await _settle(tester);
      expect(
        _calls,
        contains(
          'create qemu/100 pre-upgrade null memory=false '
          'form=external pool=null',
        ),
      );
    });

    testWidgets('a picked overlay pool is the one sent', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      await tester.tap(_formKind(VirtSnapshotForm.external));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('snapshot:pool:images')));
      await _settle(tester);
      expect(_selected(find.byKey(const ValueKey('snapshot:pool:images'))), isTrue);
      await tester.tap(find.byKey(const ValueKey('snapshot:create')));
      await _settle(tester);
      expect(
        _calls.where((c) => c.startsWith('create ')).single,
        endsWith('form=external pool=images'),
      );
    });

    testWidgets('an unreadable chain refuses only the external kind', (
      tester,
    ) async {
      const why = "disk vda: qemu-img: Could not open 'x': Permission denied";
      _FakeHost._chain['qemu/100'] = _chainOf(externalRefusal: why);
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      // The form is still offered, and opens on the internal kind.
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      final external = _formKind(VirtSnapshotForm.external);
      expect(_choiceTap(tester, external), isNull);
      expect(_selected(external), isFalse);
      expect(find.byKey(const ValueKey('snapshot:memory')), findsOneWidget);
      // Said in the form and in the chain group.
      expect(find.text(why), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('snapshot:create')));
      await _settle(tester);
      expect(
        _calls.where((c) => c.startsWith('create ')).single,
        contains('form=internal'),
      );
    });

    testWidgets('a thin clone of a base image opens on the internal kind', (
      tester,
    ) async {
      // The disk has a backing file (the chain has two layers) but the guest
      // has no external snapshot: the backing file is a base image, not a
      // snapshot's overlay, so nothing asks for the external kind.
      expect(_snaps['qemu/100']!.any((s) => s.external), isFalse);
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      expect(_selected(_formKind(VirtSnapshotForm.internal)), isTrue);
      expect(_selected(_formKind(VirtSnapshotForm.external)), isFalse);
      expect(find.byKey(const ValueKey('snapshot:memory')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('snapshot:create')));
      await _settle(tester);
      expect(
        _calls.where((c) => c.startsWith('create ')).single,
        contains('form=internal'),
      );
    });

    testWidgets('the external kind says nothing about a stopped guest', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      await tester.tap(_formKind(VirtSnapshotForm.external));
      await _settle(tester);
      // web-01 is running: "not running, only disks" would be false, and the
      // external kind's own line already says it keeps no memory.
      expect(find.text(app_locale.l10n.virtSnapshotMemoryOff), findsNothing);
      expect(find.text(app_locale.l10n.virtSnapshotExternalTip), findsWidgets);
      // The line about the external kind is that option's own, not a note
      // under the internal one.
      expect(
        find.descendant(
          of: _formKind(VirtSnapshotForm.external),
          matching: find.text(app_locale.l10n.virtSnapshotExternalNoMemory),
        ),
        findsOneWidget,
      );
      await tester.tap(_formKind(VirtSnapshotForm.internal));
      await _settle(tester);
      expect(
        find.text(app_locale.l10n.virtSnapshotMemoryAlways),
        findsOneWidget,
      );
    });

    testWidgets('the internal kind keeps the memory switch', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:new')));
      await _settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('snapshot:form:VirtSnapshotForm.internal')),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('snapshot:memory')), findsOneWidget);
      expect(find.byKey(const ValueKey('snapshot:pool')), findsNothing);
    });

    testWidgets('a snapshot with children refuses a revert', (tester) async {
      _snaps['qemu/100'] = [
        VirtGuestSnapshot(
          name: 'sx1',
          createdAt: DateTime(2026, 9, 1),
          external: true,
        ),
        VirtGuestSnapshot(
          name: 'sx2',
          parent: 'sx1',
          createdAt: DateTime(2026, 9, 2),
          external: true,
          current: true,
        ),
      ];
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      // sx1 has a child: its revert is refused, with the reason.
      await tester.tap(find.byKey(const ValueKey('snapshot:sx1')));
      await _settle(tester);
      expect(
        find.text(app_locale.l10n.virtSnapshotRevertHasChildren),
        findsOneWidget,
      );
      final refused = tester.widget<Btn>(
        find.byKey(const ValueKey('snapshot:revert:sx1')),
      );
      expect(refused.onTap, isNull);
      // The newest one is a leaf: it can be reverted to.
      await tester.tap(find.byKey(const ValueKey('snapshot:sx2')));
      await _settle(tester);
      final ok = tester.widget<Btn>(
        find.byKey(const ValueKey('snapshot:revert:sx2')),
      );
      expect(ok.onTap, isNotNull);
    });

    testWidgets('a storage without support says so and offers no form', (
      tester,
    ) async {
      _state = _state.copyWith(data: _snapshot(_allCaps));
      _FakeHost._refusals['qemu/100'] =
          'snapshot feature is not available: local';
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      expect(
        find.textContaining(app_locale.l10n.virtSnapshotNoSupport),
        findsOneWidget,
      );
      expect(find.textContaining('local'), findsWidgets);
      expect(find.byKey(const ValueKey('snapshot:new')), findsNothing);
    });

    testWidgets('the diff is read and shown, grouped', (tester) async {
      _FakeHost._diffs['qemu/100/base'] = const [
        VirtSnapDiff(
          group: VirtSnapDiffGroup.memory,
          key: 'memory',
          before: '262144',
          after: '524288',
        ),
        VirtSnapDiff(
          group: VirtSnapDiffGroup.nics,
          key: '52:54:00:06:83:c9',
          after: 'e1000e · network=default',
        ),
      ];
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:base')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('snapshot:diff:base')));
      await _settle(tester);

      expect(_calls, contains('diff qemu/100 base'));
      expect(find.text(app_locale.l10n.virtSnapshotDiff), findsOneWidget);
      // Once as the group heading, once as the key of its own row.
      expect(
        find.text(app_locale.l10n.virtSnapshotDiffGroupMemory),
        findsNWidgets(2),
      );
      expect(
        find.text(app_locale.l10n.virtSnapshotDiffGroupNic),
        findsOneWidget,
      );
      expect(
        find.text(
          app_locale.l10n.virtSnapshotDiffValue('262144', '524288'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(app_locale.l10n.virtSnapshotDiffAdded),
        findsOneWidget,
      );
    });

    testWidgets('nothing changed says so', (tester) async {
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:base')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('snapshot:diff:base')));
      await _settle(tester);
      expect(
        find.text(app_locale.l10n.virtSnapshotDiffNone),
        findsOneWidget,
      );
    });

    testWidgets('the revert dialog shows the diff first', (tester) async {
      _FakeHost._diffs['qemu/100/base'] = const [
        VirtSnapDiff(
          group: VirtSnapDiffGroup.cpu,
          key: 'vcpu',
          before: '1',
          after: '4',
        ),
      ];
      await pump(tester, wide: true);
      await openSnapshots(tester, 'web-01');
      await tester.tap(find.byKey(const ValueKey('snapshot:base')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('snapshot:revert:base')));
      await _settle(tester);

      expect(
        find.text(app_locale.l10n.virtSnapshotDiffAsk('base')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          app_locale.l10n.virtSnapshotDiffValue('1', '4'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(libL10n.cancel));
      await _settle(tester);
    });
  });
}

/// A kind in the snapshot form's choice.
Finder _formKind(VirtSnapshotForm form) =>
    find.byKey(ValueKey('snapshot:form:$form'));

/// An option of an edit-pane choice is selected: it carries the check.
bool _selected(Finder option) => find
    .descendant(of: option, matching: find.byIcon(Icons.check))
    .evaluate()
    .isNotEmpty;

/// What tapping an edit-pane choice's option does; null where it is refused.
VoidCallback? _choiceTap(WidgetTester tester, Finder option) => tester
    .widget<InkWell>(
      find.descendant(of: option, matching: find.byType(InkWell)).first,
    )
    .onTap;

/// The snapshot form's memory switch.
SwitchX _memorySwitch(WidgetTester tester) => tester.widget<SwitchX>(
  find.descendant(
    of: find.byKey(const ValueKey('snapshot:memory')),
    matching: find.byType(SwitchX),
  ),
);
