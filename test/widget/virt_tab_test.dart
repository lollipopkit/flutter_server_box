/// The Virtualization tab over scripted hosts: its two layouts, switching
/// hosts, a power action going through its confirmation, the sections not
/// built yet, and each host failure offering the action that answers it.
///
/// The providers are replaced, not the backends: what is under test is what
/// the tab does with a host's state and which call it makes back.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redfish/redfish.dart' show CertInfo;
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/remote_desktop/viewer.dart';
import 'package:server_box/view/page/virt/common.dart';
import 'package:server_box/view/page/virt/console_connect.dart';
import 'package:server_box/view/page/virt/guest.dart';
import 'package:server_box/view/page/virt/tab.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _pve = 'srv-pve';
const _kvm = 'srv-kvm';
const _plain = 'srv-plain';

VirtGuest _guest(
  String id,
  String name,
  VirtGuestState state, {
  VirtGuestKind kind = VirtGuestKind.qemu,
  int? vmid,
  bool template = false,
}) => VirtGuest(
  id: id,
  name: name,
  kind: kind,
  state: state,
  vmid: vmid,
  vcpu: 2,
  memBytes: 2 << 30,
  template: template,
  actions: template
      ? const {}
      : VirtPowerAction.offered(state, pause: kind == VirtGuestKind.qemu),
);

final _pveSnapshot = VirtSnapshot(
  host: const VirtHost(
    serverId: _pve,
    kind: VirtHostKind.pve,
    version: '8.2',
    nodes: [VirtNode(name: 'pve', maxCpu: 8, memTotal: 32 << 30)],
  ),
  guests: [
    _guest('qemu/100', 'web-01', VirtGuestState.running, vmid: 100),
    _guest(
      'lxc/200',
      'dns-01',
      VirtGuestState.stopped,
      kind: VirtGuestKind.lxc,
      vmid: 200,
    ),
    _guest(
      'qemu/900',
      'debian-tpl',
      VirtGuestState.stopped,
      vmid: 900,
      template: true,
    ),
  ],
  stats: {
    'qemu/100': VirtStats(
      at: DateTime(2026, 9, 25, 12),
      cpu: 12,
      memUsed: 1 << 30,
      memTotal: 2 << 30,
    ),
  },
  capabilities: const VirtCapabilities(lxc: true, pause: true),
);

final _kvmSnapshot = VirtSnapshot(
  host: const VirtHost(serverId: _kvm, kind: VirtHostKind.libvirt),
  guests: [_guest('uuid-db', 'db-01', VirtGuestState.paused)],
  capabilities: const VirtCapabilities(pause: true),
);

/// What the tab asked of a host, in order.
final _calls = <String>[];

/// The state each host starts in, by server id.
final _states = <String, VirtHostState>{};

/// What `detail` answers per guest id: a [VirtGuestDetail], or an error to
/// throw. A guest not here gets [_defaultDetail].
final _details = <String, Object>{};

const _defaultDetail = VirtGuestDetail(
  disks: [VirtDisk(target: 'scsi0', source: 'local-lvm:vm-100-disk-0')],
);

/// What `console` answers per guest id; a guest not here is unreachable.
final _consoles = <String, VirtConsole>{};

class _FakeHosts extends VirtHosts {
  @override
  VirtHostsState build() => const VirtHostsState(
    hosts: {_pve: VirtHostKind.pve, _kvm: VirtHostKind.libvirt},
    others: [_plain],
    probes: {_plain: VirtProbe(status: VirtProbeStatus.absent)},
  );

  @override
  Future<void> probeAll({
    bool force = false,
    bool onlyConnected = false,
  }) async => _calls.add('probeAll onlyConnected=$onlyConnected');

  @override
  Future<void> probe(String serverId, {bool force = false}) async =>
      _calls.add('probe $serverId force=$force');

  @override
  Future<void> refresh({bool onlyConnected = false}) async =>
      _calls.add('hosts.refresh onlyConnected=$onlyConnected');
}

class _FakeHost extends VirtHostNotifier {
  @override
  VirtHostState build(String serverId) =>
      _states[serverId] ?? VirtHostState(serverId: serverId);

  @override
  Future<void> refresh({bool auto = false}) async =>
      _calls.add('$serverId.refresh');

  @override
  Future<void> reconnect() async => _calls.add('$serverId.reconnect');

  @override
  Future<void> power(String guestId, VirtPowerAction action) async =>
      _calls.add('$serverId.power $guestId ${action.name}');

  @override
  Future<VirtGuestDetail> detail(String guestId) async {
    _calls.add('$serverId.detail $guestId');
    final answer = _details[guestId] ?? _defaultDetail;
    if (answer is VirtGuestDetail) return answer;
    throw answer;
  }

  @override
  Future<VirtConsole> console(String guestId, VirtConsoleKind kind) async {
    _calls.add('$serverId.console $guestId ${kind.name}');
    return _consoles[guestId] ??
        (throw const VirtErr(
          type: VirtErrType.unreachable,
          message: 'no route to host',
        ));
  }

  @override
  Future<List<VirtStats>> history(
    String guestId, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => const [];

  @override
  Future<void> submitTfa(String code) async =>
      _calls.add('$serverId.tfa $code');

  @override
  Future<void> confirmCert(String fingerprint) async =>
      _calls.add('$serverId.cert $fingerprint');

  @override
  Future<void> provideSudoPassword(String password) async =>
      _calls.add('$serverId.sudo $password');
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
    Stores.server.put(
      spiFixture(id: _kvm, name: 'kvm-host', ip: 'h2', autoConnect: false),
    );
    Stores.server.put(
      spiFixture(id: _plain, name: 'plain-host', ip: 'h3', autoConnect: false),
    );
    Stores.pve.put(_pve, const PveConfig(addr: 'https://localhost:8006'));
    _calls.clear();
    _details.clear();
    _consoles.clear();
    _states
      ..clear()
      ..[_pve] = VirtHostState(
        serverId: _pve,
        kind: VirtHostKind.pve,
        data: _pveSnapshot,
      )
      ..[_kvm] = VirtHostState(
        serverId: _kvm,
        kind: VirtHostKind.libvirt,
        data: _kvmSnapshot,
      );
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  /// [wide] sizes the *view*, which is what `MediaQuery` reports and what the
  /// pane decides its columns by.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool wide,
    String? request,
    PageController? pages,
  }) async {
    tester.view.physicalSize = wide ? const Size(1400, 900) : const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        virtHostsProvider.overrideWith(_FakeHosts.new),
        virtHostProvider.overrideWith2((_) => _FakeHost()),
      ],
    );
    addTearDown(container.dispose);
    if (request != null) {
      container.read(virtHostRequestProvider.notifier).go(request);
    }

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
              if (pages == null) return const VirtTabPage();
              // How the home page hosts its tabs: a page off screen is
              // disposed unless it asks to be kept.
              return PageView(
                controller: pages,
                physics: const NeverScrollableScrollPhysics(),
                children: const [VirtTabPage(), Center(child: Text('other'))],
              );
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await settle(tester);
    return container;
  }

  testWidgets('the first listing probes only connected servers', (
    tester,
  ) async {
    await pump(tester, wide: true);
    expect(_calls, contains('probeAll onlyConnected=true'));
    expect(_calls, isNot(contains('probeAll onlyConnected=false')));
  });

  group('kept alive across home tabs', () {
    testWidgets('the host chosen survives a tab switch', (tester) async {
      final pages = PageController();
      addTearDown(pages.dispose);
      await pump(tester, wide: true, pages: pages);
      await tester.tap(find.text('pve-host'));
      await settle(tester);
      await tester.tap(find.text('kvm-host'));
      await settle(tester);
      expect(find.text('db-01'), findsOneWidget);

      pages.jumpToPage(1);
      await settle(tester);
      expect(find.text('other'), findsOneWidget);
      pages.jumpToPage(0);
      await settle(tester);

      expect(find.text('db-01'), findsOneWidget, reason: 'still kvm-host');
      expect(find.text('web-01'), findsNothing);
    });

    testWidgets('an open console is paused off screen, not closed', (
      tester,
    ) async {
      _details['qemu/100'] = const VirtGuestDetail(
        consoles: {VirtConsoleKind.vnc},
      );
      final pages = PageController();
      addTearDown(pages.dispose);
      final container = await pump(tester, wide: true, pages: pages);
      final tab = container.read(currentHomeTabProvider.notifier);
      tab.update(AppTab.virt);
      await tester.tap(find.text('web-01'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey(VirtGuestViewKind.console)));
      await settle(tester);
      await tester.tap(find.text(app_locale.l10n.connect));
      await settle(tester);

      final id = VirtConsoleConnect.vncSessionId(_pve, 'qemu/100');
      RemoteDesktopSessionView? view() =>
          container.read(remoteDesktopSessionsProvider).consoles[id];
      expect(view()?.visible, isTrue);

      // Another tab: the page stays, so does its session, and it stops
      // drawing.
      tab.update(AppTab.server);
      pages.jumpToPage(1);
      await settle(tester);
      expect(view(), isNotNull, reason: 'not closed with the page');
      expect(view()!.visible, isFalse);

      tab.update(AppTab.virt);
      pages.jumpToPage(0);
      await settle(tester);
      expect(view()?.visible, isTrue);
      expect(find.byType(RemoteDesktopViewer), findsOneWidget);

      // Nothing answers the console here; let its retries run out.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    });
  });

  group('layout', () {
    testWidgets('wide: the guest opens beside the list', (tester) async {
      await pump(tester, wide: true);

      expect(find.text('pve-host'), findsOneWidget);
      expect(find.text('web-01'), findsOneWidget);
      expect(find.text('dns-01'), findsOneWidget);
      // A PVE host with containers names the section for both.
      expect(find.text(app_locale.l10n.virtGuestsAndContainers), findsOneWidget);
      // Templates are their own group, not "stopped" guests.
      expect(find.textContaining(app_locale.l10n.virtTemplate.toUpperCase()), findsOneWidget);

      await tester.tap(find.text('web-01'));
      await settle(tester);

      expect(find.byType(VirtGuestView), findsOneWidget);
      expect(find.byType(VirtGuestPage), findsNothing);
      // The list is still beside it.
      expect(find.text('dns-01'), findsOneWidget);
      expect(find.text(app_locale.l10n.virtOverview), findsOneWidget);
      expect(find.text(app_locale.l10n.virtConsole), findsOneWidget);
    });

    testWidgets('narrow: the guest is pushed over the list', (tester) async {
      await pump(tester, wide: false);

      expect(find.text('web-01'), findsOneWidget);
      expect(find.byType(VirtGuestView), findsNothing);

      await tester.tap(find.text('web-01'));
      await settle(tester);

      expect(find.byType(VirtGuestPage), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('the console view offers the consoles the guest has', (
      tester,
    ) async {
      _details['qemu/100'] = const VirtGuestDetail(
        consoles: {VirtConsoleKind.text, VirtConsoleKind.vnc},
      );
      await pump(tester, wide: true);
      await tester.tap(find.text('web-01'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey(VirtGuestViewKind.console)));
      await settle(tester);

      // Both, with the screen first.
      expect(find.byKey(const ValueKey(VirtConsoleKind.vnc)), findsOneWidget);
      expect(find.byKey(const ValueKey(VirtConsoleKind.text)), findsOneWidget);
      expect(find.text(app_locale.l10n.connect), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey(VirtConsoleKind.text)));
      await settle(tester);
      expect(find.text(libL10n.open), findsOneWidget);
      // The virsh escape is libvirt's; PVE's console has none to explain.
      expect(find.text(app_locale.l10n.virtConsoleSerialTip), findsNothing);
    });
  });

  group('a PVE release older than 8', () {
    testWidgets('gets a notice beside its guests', (tester) async {
      _states[_pve] = _states[_pve]!.copyWith(
        data: _pveSnapshot.copyWith(
          host: _pveSnapshot.host.copyWith(version: '7.4-3'),
        ),
      );
      await pump(tester, wide: true);
      expect(find.textContaining(app_locale.l10n.pveVersionLow), findsOneWidget);
      // A notice, not a failure: the guests are still there.
      expect(find.text('web-01'), findsOneWidget);
    });

    testWidgets('8 and later do not', (tester) async {
      await pump(tester, wide: true);
      expect(find.textContaining(app_locale.l10n.pveVersionLow), findsNothing);
    });
  });

  testWidgets('storage and network are shown, disabled, with the reason', (
    tester,
  ) async {
    await pump(tester, wide: true);

    for (final section in [VirtSection.storage, VirtSection.network]) {
      final pill = find.byKey(ValueKey(section));
      expect(pill, findsOneWidget);
      final ink = tester.widget<InkWell>(
        find.descendant(of: pill, matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNull);
      final tip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.descendant(of: pill, matching: find.byType(Material)),
          matching: find.byType(Tooltip),
        ).first,
      );
      expect(tip.message, app_locale.l10n.virtSectionLater);
    }
  });

  group('host switching', () {
    testWidgets('wide: in the list column', (tester) async {
      await pump(tester, wide: true);

      await tester.tap(find.text('pve-host'));
      await settle(tester);
      expect(find.text(app_locale.l10n.virtHosts.toUpperCase()), findsOneWidget);

      await tester.tap(find.text('kvm-host'));
      await settle(tester);

      expect(find.text('kvm-host'), findsOneWidget);
      expect(find.text('db-01'), findsOneWidget);
      expect(find.text('web-01'), findsNothing);
    });

    testWidgets('narrow: in a sheet', (tester) async {
      await pump(tester, wide: false);

      await tester.tap(find.text('pve-host'));
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.text('kvm-host'));
      await settle(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('db-01'), findsOneWidget);
    });

    testWidgets('a server not known to be a host can be checked from it', (
      tester,
    ) async {
      await pump(tester, wide: true);
      await tester.tap(find.text('pve-host'));
      await settle(tester);

      expect(
        find.text(app_locale.l10n.virtCheckServer.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.byTooltip(app_locale.l10n.virtProbeAbsent),
        findsOneWidget,
      );

      await tester.tap(find.text('plain-host'));
      await settle(tester);

      expect(_calls, contains('probe $_plain force=true'));
    });

    testWidgets('a request from a server page selects its host', (
      tester,
    ) async {
      final container = await pump(tester, wide: true, request: _kvm);

      expect(find.text('db-01'), findsOneWidget);
      expect(container.read(virtHostRequestProvider), isNull);
    });
  });

  group('power actions', () {
    testWidgets('are confirmed, then sent', (tester) async {
      await pump(tester, wide: true);
      await tester.tap(find.text('web-01'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey(VirtPowerAction.shutdown)));
      await settle(tester);
      expect(find.text(libL10n.attention), findsOneWidget);

      await tester.tap(find.text(libL10n.ok));
      await settle(tester);

      expect(_calls, contains('$_pve.power qemu/100 shutdown'));
    });

    testWidgets('cancelled, nothing is sent', (tester) async {
      await pump(tester, wide: true);
      await tester.tap(find.text('web-01'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey(VirtPowerAction.forceStop)));
      await settle(tester);
      await tester.tap(find.text(libL10n.cancel));
      await settle(tester);

      expect(_calls.where((c) => c.contains('power')), isEmpty);
    });

    testWidgets('only what the guest offers is on the bar', (tester) async {
      await pump(tester, wide: true);
      await tester.tap(find.text('dns-01'));
      await settle(tester);

      expect(find.byKey(const ValueKey(VirtPowerAction.start)), findsWidgets);
      expect(find.byKey(const ValueKey(VirtPowerAction.shutdown)), findsNothing);
    });

    testWidgets('a guest with an action in flight offers nothing', (
      tester,
    ) async {
      _states[_pve] = _states[_pve]!.copyWith(
        busy: {'qemu/100': VirtPowerAction.reboot},
      );
      await pump(tester, wide: true);
      await tester.tap(find.text('web-01'));
      await settle(tester);

      for (final a in VirtPowerAction.values) {
        expect(find.byKey(ValueKey(a)), findsNothing);
      }
      expect(find.text(app_locale.l10n.virtRebooting), findsWidgets);
    });
  });

  group('host errors offer what answers them', () {
    Future<void> withError(
      WidgetTester tester,
      VirtErr err, {
      bool keepData = false,
    }) async {
      _states[_pve] = VirtHostState(
        serverId: _pve,
        kind: VirtHostKind.pve,
        data: keepData ? _pveSnapshot : null,
        error: err,
      );
      await pump(tester, wide: true);
      expect(find.text(err.title), findsOneWidget);
    }

    testWidgets('TOTP', (tester) async {
      await withError(
        tester,
        VirtErr(type: VirtErrType.needTfa, message: app_locale.l10n.pveOtpRequired),
      );

      await tester.tap(find.text(app_locale.l10n.pveOtpLabel));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text(libL10n.ok));
      await settle(tester);

      expect(_calls, contains('$_pve.tfa 123456'));
    });

    testWidgets('a certificate to confirm', (tester) async {
      final cert = CertInfo(
        fingerprint: 'ab' * 32,
        subject: 'CN=pve',
        issuer: 'CN=PVE Cluster CA',
        startValidity: DateTime(2026),
        endValidity: DateTime(2036),
      );
      await withError(
        tester,
        VirtErr(type: VirtErrType.certUnconfirmed, cert: cert),
      );

      await tester.tap(find.text(app_locale.l10n.bmcCert));
      await settle(tester);
      expect(find.textContaining(cert.prettyFingerprint), findsOneWidget);
      expect(find.textContaining('CN=PVE Cluster CA'), findsOneWidget);

      await tester.tap(find.text(app_locale.l10n.remoteDesktopTrustReconnect));
      await settle(tester);

      expect(_calls, contains('$_pve.cert ${cert.fingerprint}'));
    });

    testWidgets('a changed certificate shows the old one too', (tester) async {
      final cert = CertInfo(
        fingerprint: 'cd' * 32,
        subject: 'CN=pve',
        issuer: 'CN=pve',
        startValidity: DateTime(2026),
        endValidity: DateTime(2036),
      );
      await withError(
        tester,
        VirtErr(
          type: VirtErrType.certChanged,
          cert: cert,
          previousFingerprint: 'ef' * 32,
        ),
        keepData: true,
      );
      // The last listing stays under the failure.
      expect(find.text('web-01'), findsOneWidget);

      await tester.tap(find.text(app_locale.l10n.bmcCert));
      await settle(tester);
      expect(find.textContaining('EF:EF:EF'), findsOneWidget);
      expect(find.textContaining('CD:CD:CD'), findsOneWidget);

      await tester.tap(find.text(libL10n.cancel));
      await settle(tester);
      expect(_calls.where((c) => c.contains('cert')), isEmpty);
    });

    testWidgets('a sudo password', (tester) async {
      await withError(
        tester,
        const VirtErr(type: VirtErrType.sudoPasswordRequired),
      );

      await tester.tap(find.text(libL10n.sudoPassword));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(_calls, contains('$_pve.sudo hunter2'));
    });

    testWidgets('a relay the agent does not grant, with its fix', (
      tester,
    ) async {
      await withError(
        tester,
        const VirtErr(type: VirtErrType.relayNotGranted, message: 'stream off'),
      );
      expect(
        find.textContaining(app_locale.l10n.monitorNoRemoteAccess),
        findsOneWidget,
      );
      // The backend's own wording is not the user's language.
      expect(find.textContaining('stream off'), findsNothing);

      await tester.tap(find.text(libL10n.retry));
      await settle(tester);
      expect(_calls, contains('$_pve.reconnect'));
    });

    testWidgets('a server that is gone: said, and nothing to edit', (
      tester,
    ) async {
      await withError(
        tester,
        const VirtErr(type: VirtErrType.serverRemoved),
      );
      expect(
        find.text(app_locale.l10n.virtErrServerRemoved),
        findsOneWidget,
      );
      expect(find.text(libL10n.edit), findsNothing);
      expect(find.text(libL10n.retry), findsNothing);
    });

    testWidgets('anything else: the host text and a retry', (tester) async {
      await withError(
        tester,
        const VirtErr(
          type: VirtErrType.unreachable,
          message: 'connection refused',
        ),
      );
      expect(find.textContaining('connection refused'), findsOneWidget);

      await tester.tap(find.text(libL10n.retry));
      await settle(tester);
      expect(_calls, contains('$_pve.reconnect'));
    });
  });

  group('console', () {
    Future<void> openConsole(
      WidgetTester tester, {
      String host = _pve,
      String guest = 'web-01',
    }) async {
      await pump(tester, wide: true, request: host == _pve ? null : host);
      await tester.tap(find.text(guest));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey(VirtGuestViewKind.console)));
      await settle(tester);
    }

    testWidgets('libvirt serial only: no toggle, and how to leave it', (
      tester,
    ) async {
      _details['uuid-db'] = const VirtGuestDetail(
        consoles: {VirtConsoleKind.text},
      );
      await openConsole(tester, host: _kvm, guest: 'db-01');

      expect(find.byKey(const ValueKey(VirtConsoleKind.vnc)), findsNothing);
      expect(find.text(libL10n.open), findsOneWidget);
      expect(find.text(app_locale.l10n.virtConsoleSerialTip), findsOneWidget);
    });

    testWidgets('no console configured says so', (tester) async {
      _details['qemu/100'] = const VirtGuestDetail();
      await openConsole(tester);
      expect(find.text(app_locale.l10n.virtConsoleNone), findsOneWidget);
    });

    testWidgets('a detail that failed is shown, and retried', (tester) async {
      _details['qemu/100'] = const VirtErr(
        type: VirtErrType.unreachable,
        message: 'connection reset',
      );
      await openConsole(tester);
      expect(find.text(app_locale.l10n.virtErrUnreachable), findsOneWidget);
      expect(find.textContaining('connection reset'), findsOneWidget);

      _details['qemu/100'] = const VirtGuestDetail(
        consoles: {VirtConsoleKind.vnc},
      );
      final before = _calls.where((c) => c.contains('.detail ')).length;
      await tester.tap(find.text(libL10n.retry));
      await settle(tester);
      expect(
        _calls.where((c) => c.contains('.detail ')).length,
        before + 1,
      );
      expect(find.text(app_locale.l10n.connect), findsOneWidget);
    });

    testWidgets('graphical: a failed connection is shown with a retry', (
      tester,
    ) async {
      _details['qemu/100'] = const VirtGuestDetail(
        consoles: {VirtConsoleKind.vnc},
      );
      final container = await openConsole(tester).then(
        (_) => ProviderScope.containerOf(
          tester.element(find.byType(VirtGuestView)),
        ),
      );

      await tester.tap(find.text(app_locale.l10n.connect));
      await settle(tester);
      expect(find.byType(RemoteDesktopViewer), findsOneWidget);
      final id = VirtConsoleConnect.vncSessionId(_pve, 'qemu/100');
      // A console, not one of the remote desktop tab's sessions.
      final sessions = container.read(remoteDesktopSessionsProvider);
      expect(sessions.consoles.keys, [id]);
      expect(sessions.sessions, isEmpty);

      // Each attempt asks for a new ticket; the automatic retries give up.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        _calls.where((c) => c == '$_pve.console qemu/100 vnc').length,
        4,
      );
      expect(find.textContaining('no route to host'), findsOneWidget);
      expect(find.text(app_locale.l10n.remoteDesktopReconnect), findsOneWidget);

      // Leaving the console closes its session.
      await tester.tap(find.byKey(const ValueKey(VirtGuestViewKind.overview)));
      await settle(tester);
      expect(container.read(remoteDesktopSessionsProvider).consoles, isEmpty);
    });

    testWidgets('text: what the terminal page is given, per host', (
      tester,
    ) async {
      await pump(tester, wide: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VirtTabPage)),
      );

      final pve = await VirtConsoleConnect.textArgs(
        container,
        serverId: _pve,
        guest: _pveSnapshot.guests.first,
      );
      expect(pve.source, isA<ConsoleSource>());
      expect(pve.source.label, 'web-01');
      expect(pve.spi, isNull, reason: 'nothing of the host is offered');
      expect(pve.initCmd, isNull);

      _consoles['uuid-db'] = const LibvirtSerialConsole(
        command: "virsh --connect qemu:///system console --force --domain 'd'",
        needsRoot: true,
      );
      final kvm = await VirtConsoleConnect.textArgs(
        container,
        serverId: _kvm,
        guest: _kvmSnapshot.guests.first,
      );
      expect(kvm.spi?.id, _kvm);
      expect(
        kvm.initCmd,
        "sudo virsh --connect qemu:///system console --force --domain 'd'",
      );
      expect(kvm.detachInput, VirtConsoleConnect.serialEscape);
    });
  });
}

/// Frames rather than `pumpAndSettle`: a busy host draws an indeterminate
/// progress line, which never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
