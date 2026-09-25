/// Creating a guest (`VirtCreateView`): what the form offers from the host's
/// own lists, what it refuses before asking, and what it sends. Deleting one
/// is the Settings view's (`virt_hardware_test.dart`).
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/virt/create.dart';

import '../helpers/test_db.dart';

const _host = 'srv-pve';

/// What [_FakeHost.create] was given.
final _created = <VirtCreateSpec>[];

const _storages = [
  VirtStoragePool(
    id: 'pve/local',
    name: 'local',
    node: 'pve',
    type: 'dir',
    content: ['iso', 'vztmpl'],
  ),
  VirtStoragePool(
    id: 'pve/local-lvm',
    name: 'local-lvm',
    node: 'pve',
    type: 'lvmthin',
    content: ['images', 'rootdir'],
    available: 100 << 30,
  ),
];

const _content = [
  VirtVolume(
    id: 'local:iso/debian-13.iso',
    name: 'debian-13.iso',
    content: 'iso',
  ),
  VirtVolume(
    id: 'local:vztmpl/alpine-3.22.tar.xz',
    name: 'alpine-3.22.tar.xz',
    content: 'vztmpl',
  ),
];

class _FakeHost extends VirtHostNotifier {
  @override
  VirtHostState build(String serverId) => VirtHostState(
    serverId: serverId,
    kind: VirtHostKind.pve,
    data: const VirtSnapshot(
      host: VirtHost(
        serverId: _host,
        kind: VirtHostKind.pve,
        nodes: [VirtNode(name: 'pve', maxCpu: 8)],
      ),
      guests: [
        VirtGuest(
          id: 'qemu/100',
          name: 'web-01',
          kind: VirtGuestKind.qemu,
          state: VirtGuestState.running,
          vmid: 100,
        ),
      ],
      capabilities: VirtCapabilities(lxc: true, create: true),
    ),
  );

  @override
  Future<void> refresh({bool auto = false}) async {}

  @override
  Future<int?> nextVmid() async => 105;

  @override
  Future<List<VirtStoragePool>> storagePools() async => _storages;

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async =>
      pool.id == 'pve/local' ? _content : const [];

  @override
  Future<List<VirtNetwork>> networks() async => const [
    VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
  ];

  @override
  Future<VirtCreated> create(VirtCreateSpec spec) async {
    _created.add(spec);
    return VirtCreated(id: '${spec.kind.name}/${spec.vmid}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    _created.clear();
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<List<String>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [virtHostProvider.overrideWith2((_) => _FakeHost())],
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return VirtCreateView(serverId: _host, onCreated: opened.add);
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return opened;
  }

  Finder submit() => find.byKey(const ValueKey('create:submit'));
  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submit()).onPressed != null;

  testWidgets('a VM: filled from the host, sent as chosen', (tester) async {
    final opened = await pump(tester);
    // The next VMID, the only disk storage and bridge, no media yet.
    expect(find.widgetWithText(TextField, '105'), findsOneWidget);
    expect(find.text('local-lvm'), findsOneWidget);
    expect(find.text('vmbr0'), findsOneWidget);
    expect(find.text('debian-13.iso'), findsOneWidget);
    // A template is not install media.
    expect(find.text('alpine-3.22.tar.xz'), findsNothing);
    // No name yet: nothing to send, nothing said.
    expect(enabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('create:name')), 'web-01');
    await tester.pump();
    expect(find.text(app_locale.l10n.virtCreateNameTaken), findsOneWidget);
    expect(enabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('create:name')), 'web_02');
    await tester.pump();
    expect(find.text(app_locale.l10n.virtCreateNameInvalidPve), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('create:name')), 'web-02');
    await tester.tap(find.text('debian-13.iso'));
    await tester.tap(find.byKey(const ValueKey('create:cores:plus')));
    await tester.pump();
    expect(enabled(tester), isTrue);

    await tester.tap(submit());
    await tester.pump();
    await tester.pump();
    expect(_created, hasLength(1));
    final spec = _created.single;
    expect(spec.kind, VirtGuestKind.qemu);
    expect(spec.name, 'web-02');
    expect((spec.node, spec.vmid), ('pve', 105));
    expect(spec.cores, 3);
    expect(spec.memoryMiB, 2048);
    expect(spec.storage.id, 'pve/local-lvm');
    expect(spec.diskGiB, 32);
    expect(spec.media?.id, 'local:iso/debian-13.iso');
    expect(spec.network?.name, 'vmbr0');
    expect(spec.start, isTrue);
    expect(opened, ['qemu/105']);
  });

  testWidgets('a container: a template and a root login first', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(app_locale.l10n.virtKindLxc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Templates, not ISOs; the first one chosen.
    expect(find.text('alpine-3.22.tar.xz'), findsOneWidget);
    expect(find.text('debian-13.iso'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('create:name')), 'ct-01');
    await tester.pump();
    expect(find.text(app_locale.l10n.virtCreateCredentialsMissing), findsOneWidget);
    expect(enabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('create:password')), 'abc');
    await tester.pump();
    expect(find.text(app_locale.l10n.virtCreatePasswordShort(5)), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('create:password')),
      'correct horse',
    );
    await tester.pump();
    expect(enabled(tester), isTrue);
    await tester.tap(submit());
    await tester.pump();
    await tester.pump();
    final spec = _created.single;
    expect(spec.kind, VirtGuestKind.lxc);
    expect(spec.media?.id, 'local:vztmpl/alpine-3.22.tar.xz');
    expect(spec.password, 'correct horse');
    expect(spec.unprivileged, isTrue);
  });

}
