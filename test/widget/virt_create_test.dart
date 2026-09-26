/// Creating a guest (`VirtCreateView`): what the form offers from the host's
/// own lists and options, what it refuses before asking, and what it sends —
/// install media or a cloud image with cloud-init, the disk bus, the NIC
/// model, the firmware and the TPM. Deleting one is the Settings view's
/// (`virt_hardware_test.dart`).
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
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/virt/hardware.dart';

import '../helpers/test_db.dart';

const _host = 'srv-virt';

/// What [_FakeHost.create] was given.
final _created = <VirtCreateSpec>[];

const _pveStorages = [
  VirtStoragePool(
    id: 'pve/local',
    name: 'local',
    node: 'pve',
    type: 'dir',
    content: ['iso', 'vztmpl', 'import'],
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

const _pveContent = [
  VirtVolume(
    id: 'local:iso/debian-13.iso',
    name: 'debian-13.iso',
    content: 'iso',
  ),
  VirtVolume(
    id: 'local:iso/Win11_24H2.iso',
    name: 'Win11_24H2.iso',
    content: 'iso',
  ),
  VirtVolume(
    id: 'local:vztmpl/alpine-3.22.tar.xz',
    name: 'alpine-3.22.tar.xz',
    content: 'vztmpl',
  ),
  VirtVolume(
    id: 'local:import/debian-13-genericcloud.qcow2',
    name: 'debian-13-genericcloud.qcow2',
    content: 'import',
    format: 'qcow2',
    capacity: 3 << 30,
  ),
  // An OVA carries a machine of its own: not a disk to copy.
  VirtVolume(
    id: 'local:import/appliance.ova',
    name: 'appliance.ova',
    content: 'import',
    format: 'ova+qcow2',
  ),
];

const _libvirtPool = VirtStoragePool(
  id: 'images',
  name: 'images',
  type: 'dir',
  available: 50 << 30,
);

const _libvirtContent = [
  VirtVolume(id: 'debian.iso', name: 'debian.iso', format: 'iso', path: '/i/debian.iso'),
  VirtVolume(
    id: 'noble.img',
    name: 'noble.img',
    format: 'qcow2',
    path: '/i/noble.img',
    capacity: 3758096384,
  ),
  // A guest's disk is not an image to copy while it is written to.
  VirtVolume(
    id: 'web.qcow2',
    name: 'web.qcow2',
    format: 'qcow2',
    path: '/i/web.qcow2',
    users: [VirtGuestRef(guestId: 'u-1', device: 'vda')],
  ),
];

var _options = const VirtCreateOptions();

class _FakeHost extends VirtHostNotifier {
  _FakeHost(this.kind);

  final VirtHostKind kind;

  bool get _pve => kind == VirtHostKind.pve;

  @override
  VirtHostState build(String serverId) => VirtHostState(
    serverId: serverId,
    kind: kind,
    data: VirtSnapshot(
      host: VirtHost(
        serverId: _host,
        kind: kind,
        nodes: [if (_pve) const VirtNode(name: 'pve', maxCpu: 8)],
      ),
      guests: [
        VirtGuest(
          id: _pve ? 'qemu/100' : 'u-1',
          name: 'web-01',
          kind: VirtGuestKind.qemu,
          state: VirtGuestState.running,
          vmid: _pve ? 100 : null,
        ),
      ],
      capabilities: VirtCapabilities(lxc: _pve, create: true),
    ),
  );

  @override
  Future<void> refresh({bool auto = false}) async {}

  @override
  Future<int?> nextVmid() async => _pve ? 105 : null;

  @override
  Future<VirtCreateOptions> createOptions() async => _options;

  @override
  Future<List<VirtStoragePool>> storagePools() async =>
      _pve ? _pveStorages : const [_libvirtPool];

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async => _pve
      ? (pool.id == 'pve/local' ? _pveContent : const [])
      : _libvirtContent;

  @override
  Future<List<VirtNetwork>> networks() async => _pve
      ? const [
          VirtNetwork(id: 'pve/vmbr0', name: 'vmbr0', node: 'pve', mode: 'bridge'),
        ]
      : const [VirtNetwork(id: 'default', name: 'default', mode: 'nat')];

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
    getIt.registerSingleton<ServerStore>(ServerStore());
    _created.clear();
    _options = const VirtCreateOptions();
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<List<String>> pump(
    WidgetTester tester, {
    VirtHostKind kind = VirtHostKind.pve,
  }) async {
    tester.view.physicalSize = const Size(700, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [virtHostProvider.overrideWith2((_) => _FakeHost(kind))],
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
    await settle(tester);
    return opened;
  }

  Finder key(String k) => find.byKey(ValueKey(k), skipOffstage: false);
  Finder seg(String k, String label) => find.descendant(
    of: key('hw:seg:$k'),
    matching: find.text(label, skipOffstage: false),
  );
  Finder text(String s) => find.text(s, skipOffstage: false);
  bool enabled(WidgetTester tester) =>
      tester.widget<Btn>(key('create:submit')).onTap != null;
  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String k, String value) async {
    await tester.ensureVisible(key(k));
    await tester.enterText(key(k), value);
    await settle(tester);
  }

  Future<VirtCreateSpec> submit(WidgetTester tester) async {
    expect(enabled(tester), isTrue);
    await tap(tester, key('create:submit'));
    return _created.single;
  }

  AppLocalizations l10n() => app_locale.l10n;

  testWidgets('a VM: filled from the host, sent as chosen', (tester) async {
    _options = const VirtCreateOptions(
      buses: virtPveCreateBuses,
      nicModels: virtCreateNicModels,
      uefi: true,
      tpm: true,
      cloudImages: true,
      cloudInit: true,
    );
    final opened = await pump(tester);
    // The next VMID, the only disk storage and bridge, no media yet.
    expect(text('105'), findsOneWidget);
    expect(text('local-lvm'), findsOneWidget);
    expect(text('vmbr0'), findsOneWidget);
    expect(text('debian-13.iso'), findsOneWidget);
    // A template is not install media, nor a cloud image.
    expect(text('alpine-3.22.tar.xz'), findsNothing);
    expect(text('debian-13-genericcloud.qcow2'), findsNothing);
    // No name yet: nothing to send.
    expect(enabled(tester), isFalse);

    await type(tester, 'create:name', 'web-01');
    expect(text(l10n().virtCreateNameTaken), findsOneWidget);
    expect(enabled(tester), isFalse);
    await type(tester, 'create:name', 'web_02');
    expect(text(l10n().virtCreateNameInvalidPve), findsOneWidget);
    await type(tester, 'create:name', 'web-02');
    // No media is a choice of its own (a network boot).
    expect(key('create:media:none'), findsOneWidget);
    await tap(tester, key('create:media:local:iso/debian-13.iso'));
    await tap(tester, key('hw:step:create-cores:inc'));
    await tap(tester, key('hw:step:create-vmid:inc'));
    await tap(tester, seg('create:bus', 'sata'));
    await tap(tester, seg('create:model', 'e1000e'));
    await tap(tester, key('hw:toggle:create:tpm'));

    final spec = await submit(tester);
    expect(spec.kind, VirtGuestKind.qemu);
    expect(spec.name, 'web-02');
    expect((spec.node, spec.vmid), ('pve', 106));
    expect(spec.cores, 3);
    expect(spec.memoryMiB, 2048);
    expect(spec.storage.id, 'pve/local-lvm');
    expect(spec.diskGiB, 32);
    expect(spec.media?.id, 'local:iso/debian-13.iso');
    expect(spec.image, isNull);
    expect(spec.cloudInit, isNull);
    expect(spec.network?.name, 'vmbr0');
    expect((spec.bus, spec.nicModel), ('sata', 'e1000e'));
    // UEFI unless said otherwise, where the host has it.
    expect((spec.uefi, spec.tpm), (true, true));
    expect(spec.start, isTrue);
    expect(opened, ['qemu/106']);
  });

  testWidgets('Windows install media: UEFI and a TPM called for', (
    tester,
  ) async {
    _options = const VirtCreateOptions(uefi: true, tpm: true);
    await pump(tester);
    await tap(tester, key('create:media:local:iso/Win11_24H2.iso'));
    expect(text(l10n().virtCreateWindowsTitle), findsOneWidget);
    await tap(tester, key('hw:toggle:create:tpm'));
    expect(text(l10n().virtCreateWindowsTitle), findsNothing);
    await tap(tester, seg('create:firmware', 'BIOS'));
    expect(text(l10n().virtCreateWindowsTitle), findsOneWidget);
  });

  testWidgets('a container: a template and a root login first', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, key('create:kind:lxc'));
    // Templates, not ISOs; the first one chosen.
    expect(text('alpine-3.22.tar.xz'), findsOneWidget);
    expect(text('debian-13.iso'), findsNothing);

    await type(tester, 'create:name', 'ct-01');
    expect(text(l10n().virtCreateCredentialsMissing), findsOneWidget);
    expect(enabled(tester), isFalse);
    await type(tester, 'create:password', 'abc');
    expect(text(l10n().virtCreatePasswordShort(5)), findsOneWidget);
    await type(tester, 'create:password', 'correct horse');
    final spec = await submit(tester);
    expect(spec.kind, VirtGuestKind.lxc);
    expect(spec.media?.id, 'local:vztmpl/alpine-3.22.tar.xz');
    expect(spec.password, 'correct horse');
    expect(spec.unprivileged, isTrue);
    // A container has no bus, NIC model or firmware of its own.
    expect((spec.bus, spec.nicModel, spec.uefi), (null, null, false));
  });

  testWidgets('PVE: a cloud image with cloud-init', (tester) async {
    _options = const VirtCreateOptions(
      buses: virtPveCreateBuses,
      nicModels: virtCreateNicModels,
      uefi: true,
      tpm: true,
      cloudImages: true,
      cloudInit: true,
    );
    await pump(tester);
    await type(tester, 'create:name', 'ci-01');
    await tap(tester, seg('create:source', l10n().virtCloudImage));
    // Import content in a format QEMU reads; no OVA, no ISO.
    expect(text('debian-13-genericcloud.qcow2'), findsOneWidget);
    expect(text('appliance.ova'), findsNothing);
    expect(text('debian-13.iso'), findsNothing);
    expect(text(l10n().virtCreateImageMissing), findsOneWidget);
    await tap(tester, key('create:image:local:import/debian-13-genericcloud.qcow2'));

    // An account needs a way in.
    await type(tester, 'create:ci:user', 'Admin');
    expect(text(l10n().virtCiUserInvalid), findsOneWidget);
    await type(tester, 'create:ci:user', 'admin');
    expect(text(l10n().virtCiCredentialsMissing), findsOneWidget);
    expect(enabled(tester), isFalse);
    await type(tester, 'create:ci:keys', 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me@x');
    // PVE names the host after the VM.
    expect(key('create:ci:hostname'), findsNothing);
    expect(text(l10n().virtCiHostnamePve), findsOneWidget);
    await tap(tester, seg('create:ci:ip', l10n().virtCiStatic));
    await type(tester, 'create:ci:address', '10.0.0.5');
    expect(text(l10n().virtCiAddressInvalid), findsOneWidget);
    await type(tester, 'create:ci:address', '10.0.0.5/24');
    await type(tester, 'create:ci:gateway', '10.0.0.1');
    await type(tester, 'create:ci:dns', '1.1.1.1, 9.9.9.9');

    final spec = await submit(tester);
    expect(spec.image?.id, 'local:import/debian-13-genericcloud.qcow2');
    expect(spec.media, isNull);
    final ci = spec.cloudInit!;
    expect(ci.user, 'admin');
    expect(ci.password, isNull);
    expect(ci.keys, ['ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me@x']);
    expect(ci.hostname, isNull);
    expect((ci.address, ci.gateway), ('10.0.0.5/24', '10.0.0.1'));
    expect(ci.dns, ['1.1.1.1', '9.9.9.9']);
  });

  testWidgets('libvirt: the buses the machine has, the hostname from the name', (
    tester,
  ) async {
    _options = const VirtCreateOptions(
      buses: ['virtio', 'scsi', 'sata'],
      nicModels: virtCreateNicModels,
      uefi: true,
      cloudImages: true,
      cloudInit: true,
    );
    await pump(tester, kind: VirtHostKind.libvirt);
    // No VMID, no IDE on q35, no TPM without swtpm.
    expect(key('hw:step:create-vmid'), findsNothing);
    expect(seg('create:bus', 'ide'), findsNothing);
    expect(key('hw:toggle:create:tpm'), findsNothing);
    await type(tester, 'create:name', 'ci_vm.1');
    await tap(tester, seg('create:source', l10n().virtCloudImage));
    // An unused qcow2 only.
    expect(text('noble.img'), findsOneWidget);
    expect(text('web.qcow2'), findsNothing);
    await tap(tester, key('create:image:noble.img'));
    // The hostname follows the name, as a DNS name.
    expect(
      tester.widget<TextField>(find.descendant(of: key('create:ci:hostname'), matching: find.byType(TextField))).controller?.text,
      'ci-vm-1',
    );
    await type(tester, 'create:ci:user', 'debian');
    await type(tester, 'create:ci:password', 'hunter22');
    expect(text(l10n().virtCiSeedNote), findsOneWidget);
    // A 3.5 GiB image does not fit a 3 GiB disk.
    for (var i = 0; i < 5; i++) {
      await tap(tester, key('hw:step:create-disk:dec'));
    }
    expect(text(l10n().virtCreateImageSize(3758096384.bytes2Str)), findsOneWidget);
    expect(enabled(tester), isFalse);
    await tap(tester, key('hw:step:create-disk:inc'));
    final spec = await submit(tester);
    expect(spec.diskGiB, 4);
    expect(spec.image?.path, '/i/noble.img');
    expect(spec.cloudInit?.hostname, 'ci-vm-1');
    expect(spec.cloudInit?.password, 'hunter22');
    expect(spec.cloudInit?.address, isNull);
    expect(spec.bus, 'virtio');
  });

  testWidgets('libvirt without an ISO tool: said so, no cloud-init sent', (
    tester,
  ) async {
    _options = const VirtCreateOptions(
      buses: ['virtio'],
      cloudImages: true,
      cloudInitMissing: 'genisoimage, xorriso, mkisofs, cloud-localds',
    );
    await pump(tester, kind: VirtHostKind.libvirt);
    await type(tester, 'create:name', 'plain');
    await tap(tester, seg('create:source', l10n().virtCloudImage));
    await tap(tester, key('create:image:noble.img'));
    expect(key('create:ci:no-tool'), findsOneWidget);
    expect(key('create:ci:user'), findsNothing);
    // Neither firmware nor bus to choose: the host offers one of each.
    expect(key('hw:seg:create:firmware'), findsNothing);
    expect(key('hw:seg:create:bus'), findsNothing);
    final spec = await submit(tester);
    expect(spec.image?.id, 'noble.img');
    expect(spec.cloudInit, isNull);
    expect(spec.uefi, isFalse);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
