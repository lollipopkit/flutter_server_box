/// The firewall page, drawn from what a real ufw and a real firewalld
/// printed (`test/fixtures/ufw/`, `test/fixtures/firewalld/`) rather than
/// from a server, and what each control asks the server to run.
///
/// The connection is SSH from 192.0.2.1 to port 22, arriving on eth0, as
/// the probe reports it.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/service/firewall.dart';
import 'package:server_box/data/service/firewalld_manager.dart';
import 'package:server_box/data/service/ufw_manager.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/firewall/firewall.dart';

import '../helpers/spi_fixture.dart';

const _sid = 'fw-1';

String _fixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

String _probe({String? ufw, String? firewalld}) => [
  if (ufw != null) '${FirewallProbe.ufwMarker}$ufw',
  if (firewalld != null) '${FirewallProbe.firewalldMarker}$firewalld',
  '${FirewallProbe.uidMarker}0',
  '${FirewallProbe.sshMarker}192.0.2.1 51000 198.51.100.2 22',
  '${FirewallProbe.ifaceMarker}eth0',
  '',
].join('\n');

/// A root account answering the probe and the reads, and keeping every
/// other script it is handed.
final class _FakeExec implements ServerExec {
  _FakeExec({required this.probe, this.ufw = '', this.firewalld = ''});

  final String probe;
  final String ufw;
  final String firewalld;
  final ran = <String>[];

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    ExecResult ok(String stdout) =>
        ExecResult(exitCode: 0, stdout: stdout, stderr: '');
    if (script == FirewallProbe.script) return ok(probe);
    if (script == UfwManager.readScript) return ok(ufw);
    if (script == FirewalldManager.readScript) return ok(firewalld);
    ran.add(script);
    return ok('');
  }
}

final class _FakeServerNotifier extends ServerNotifier {
  _FakeServerNotifier(this.exec);

  final _FakeExec exec;

  @override
  ServerState build(String id) => ServerState(
    spi: spiFixture(id: id, name: 'gw', ip: '10.0.0.2'),
    status: InitStatus.status,
  );

  @override
  Future<ServerExec> ensureExec({VoidCallback? onSshDial}) async => exec;
}

void main() {
  final page = FirewallPage(
    args: SpiRequiredArgs(spiFixture(id: _sid, name: 'gw', ip: '10.0.0.2')),
  );

  Future<void> frames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_FakeExec> pump(
    WidgetTester tester,
    _FakeExec exec, {
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverProvider(_sid).overrideWith(() => _FakeServerNotifier(exec)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            ...app_locale.appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return page;
            },
          ),
        ),
      ),
    );
    await frames(tester);
    return exec;
  }

  Future<_FakeExec> pumpUfw(
    WidgetTester tester, {
    String? readout,
    Size size = const Size(393, 852),
  }) => pump(
    tester,
    _FakeExec(
      probe: _probe(ufw: 'yes'),
      ufw: readout ?? _fixture('ufw/active.txt'),
    ),
    size: size,
  );

  Future<void> tapOk(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, libL10n.ok));
    await frames(tester);
  }

  /// A change that shuts this app out asks with a countdown.
  Future<void> waitAndTapOk(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tapOk(tester);
  }

  String willRefuse() =>
      app_locale.l10n.firewallWillRefuseFmt('SSH (TCP 22)');

  group('ufw', () {
    Finder ruleMenu(String tuple) => find.descendant(
      of: find.byKey(ValueKey('ufw-rule:$tuple')),
      matching: find.byType(ContextMenuButton),
    );

    testWidgets('lists the rules once per rule, at phone width', (
      tester,
    ) async {
      await pumpUfw(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(libL10n.active), findsOneWidget);
      expect(find.text('ufw 0.36.2'), findsOneWidget);
      expect(find.text('Rules · 12'), findsOneWidget);
      expect(find.text('22/tcp'), findsOneWidget);
      expect(find.text('ssh access'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('My App'), 200);
      expect(find.text('My App'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // Only one firewall: nothing to switch to.
      expect(find.text('firewalld'), findsNothing);
    });

    testWidgets('fits a desktop window too', (tester) async {
      await pumpUfw(tester, size: const Size(1280, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('Rules · 12'), findsOneWidget);
    });

    testWidgets('turning it off shows and runs ufw disable', (tester) async {
      final exec = await pumpUfw(tester);

      await tester.tap(find.byType(Switch));
      await frames(tester);
      expect(find.textContaining(UfwManager.disableCommand), findsOneWidget);
      await tapOk(tester);

      expect(exec.ran.single, contains('\n${UfwManager.disableCommand}\n'));
    });

    testWidgets('turning it on lets the SSH port in first, at the top', (
      tester,
    ) async {
      // Inactive, and with the rule that let 22 in gone.
      final readout = _fixture('ufw/inactive_no_ipv6.txt')
          .split('\n')
          .where((line) => !line.contains(' tcp 22 '))
          .join('\n');
      final exec = await pumpUfw(tester, readout: readout);

      await tester.tap(find.byType(Switch));
      await frames(tester);
      expect(find.text(willRefuse()), findsOneWidget);
      expect(find.text(app_locale.l10n.firewallKeepAccess), findsOneWidget);
      // Shutting this app out is not one tap away: OK counts down first.
      expect(find.widgetWithText(TextButton, libL10n.ok), findsNothing);
      await waitAndTapOk(tester);

      final script = exec.ran.single;
      final allow = script.indexOf(UfwManager.allowTcpCommand(22));
      expect(allow, greaterThan(0));
      expect(script.indexOf(UfwManager.enableCommand), greaterThan(allow));
    });

    testWidgets('deleting a rule that is not the way in asks nothing more', (
      tester,
    ) async {
      final exec = await pumpUfw(tester);

      await tester.tap(
        ruleMenu('### tuple ### deny any any 0.0.0.0/0 any 203.0.113.9 in'),
      );
      await frames(tester);
      await tester.tap(find.text(libL10n.delete));
      await frames(tester);
      expect(find.text(willRefuse()), findsNothing);
      await tapOk(tester);

      expect(
        exec.ran.single,
        contains("t='### tuple ### deny any any 0.0.0.0/0 any 203.0.113.9 in'"),
      );
    });

    testWidgets('deleting the rule that lets SSH in warns, both families', (
      tester,
    ) async {
      final exec = await pumpUfw(tester);

      await tester.tap(
        ruleMenu(
          '### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in '
          'comment=73736820616363657373',
        ),
      );
      await frames(tester);
      await tester.tap(find.text(libL10n.delete));
      await frames(tester);
      expect(find.text(willRefuse()), findsOneWidget);
      // Unticked here: the rule is going, and nothing takes its place.
      await tester.tap(find.byType(CheckboxListTile));
      await frames(tester);
      await waitAndTapOk(tester);

      final script = exec.ran.single;
      expect(script, isNot(contains(UfwManager.allowTcpCommand(22))));
      expect(script, contains(' 22 0.0.0.0/0 '));
      expect(script, contains(' 22 ::/0 '));
    });

    testWidgets('a rule that only lets something in is added at once', (
      tester,
    ) async {
      final exec = await pumpUfw(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await frames(tester);
      await tester.enterText(
        find.widgetWithText(TextField, libL10n.port),
        '8443',
      );
      await tapOk(tester);

      expect(
        exec.ran.single,
        contains('ufw allow in proto tcp from any to any port 8443\n'),
      );
    });

    testWidgets('a deny put first, on the SSH port, asks', (tester) async {
      final exec = await pumpUfw(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await frames(tester);
      // The page's policy rows say deny too, behind the dialog.
      await tester.tap(find.text('deny').last);
      await tester.enterText(
        find.widgetWithText(TextField, libL10n.port),
        '20:30',
      );
      await tester.ensureVisible(find.text(app_locale.l10n.firewallPrepend));
      await tester.tap(find.text(app_locale.l10n.firewallPrepend));
      await frames(tester);
      await tapOk(tester);

      expect(exec.ran, isEmpty);
      expect(find.text(willRefuse()), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, libL10n.cancel));
      await frames(tester);
      expect(exec.ran, isEmpty);
    });

    testWidgets('a routed rule takes both interfaces from more options', (
      tester,
    ) async {
      final exec = await pumpUfw(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await frames(tester);
      // The page's routed policy row is behind the dialog.
      await tester.tap(find.text(app_locale.l10n.firewallRouted).last);
      await frames(tester);
      await tester.enterText(
        find.widgetWithText(TextField, libL10n.port),
        '8080',
      );
      await tester.ensureVisible(
        find.text(app_locale.l10n.firewallMoreOptions),
      );
      await tester.tap(find.text(app_locale.l10n.firewallMoreOptions));
      await frames(tester);
      await tester.ensureVisible(
        find.widgetWithText(TextField, app_locale.l10n.firewallInterfaceOut),
      );
      await tester.enterText(
        find.widgetWithText(TextField, app_locale.l10n.firewallInterfaceIn),
        'eth0',
      );
      await tester.enterText(
        find.widgetWithText(TextField, app_locale.l10n.firewallInterfaceOut),
        'eth1',
      );
      await tapOk(tester);

      expect(
        exec.ran.single,
        contains(
          "ufw route allow in on 'eth0' out on 'eth1' proto tcp "
          'from any to any port 8080\n',
        ),
      );
    });

    testWidgets('a port list without a protocol is refused in the form', (
      tester,
    ) async {
      final exec = await pumpUfw(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await frames(tester);
      await tester.tap(find.text('any').first);
      await tester.enterText(
        find.widgetWithText(TextField, libL10n.port),
        '80,443',
      );
      await tapOk(tester);

      expect(exec.ran, isEmpty);
      // Asked again, with what was typed.
      expect(find.text('80,443'), findsOneWidget);
    });
  });

  group('firewalld', () {
    Future<_FakeExec> pumpFirewalld(
      WidgetTester tester, {
      String fixture = 'firewalld/running.txt',
      String state = 'active',
    }) => pump(
      tester,
      _FakeExec(
        probe: _probe(firewalld: state),
        firewalld: _fixture(fixture),
      ),
    );

    Finder itemRemove(String section, String item) => find.descendant(
      of: find.byKey(ValueKey('firewalld:$section:$item')),
      matching: find.byTooltip(libL10n.delete),
    );

    testWidgets("opens on this connection's zone, and says what differs", (
      tester,
    ) async {
      await pumpFirewalld(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('firewalld 1.3.4'), findsOneWidget);
      // eth0 is in internal; public is the default.
      expect(find.text('internal'), findsWidgets);
      expect(find.text(app_locale.l10n.firewallThisConnection), findsOneWidget);
      expect(find.text('public'), findsOneWidget);
      // 7777 in force, 5555 saved: the two differ.
      expect(find.text(app_locale.l10n.firewallSaveRuntime), findsOneWidget);
      await tester.scrollUntilVisible(find.text('ssh'), 200);
      expect(find.text('22/tcp'), findsWidgets);
    });

    testWidgets('removing ssh from this zone warns, now and after a reload', (
      tester,
    ) async {
      final exec = await pumpFirewalld(tester);
      final remove = itemRemove(app_locale.l10n.firewallServices, 'ssh');

      await tester.ensureVisible(remove);
      await frames(tester);
      await tester.tap(remove);
      await frames(tester);
      expect(find.text(willRefuse()), findsOneWidget);
      expect(
        find.text(app_locale.l10n.firewallDriftLockoutFmt('SSH (TCP 22)')),
        findsOneWidget,
      );
      await waitAndTapOk(tester);

      final script = exec.ran.single;
      final keep = script.indexOf(
        "firewall-cmd --permanent --zone='internal' --add-rich-rule="
        '\'rule priority="-32768" port port="22" protocol="tcp" accept\'',
      );
      expect(keep, greaterThan(0));
      expect(
        script.indexOf(
          "firewall-cmd --permanent --zone='internal' --remove-service='ssh'",
        ),
        greaterThan(keep),
      );
    });

    testWidgets('a port is added to both configurations at once', (
      tester,
    ) async {
      final exec = await pumpFirewalld(tester);
      final header = find.textContaining(
        '${app_locale.l10n.firewallPorts} · ',
      );

      await tester.scrollUntilVisible(header, 200);
      await tester.ensureVisible(header);
      await frames(tester);
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: header, matching: find.byType(Row)).first,
          matching: find.byTooltip(libL10n.add),
        ),
      );
      await frames(tester);
      await tester.enterText(find.byType(TextField).last, '8443/tcp');
      await tapOk(tester);

      expect(
        exec.ran.single,
        allOf(
          contains("firewall-cmd --zone='internal' --add-port='8443/tcp'"),
          contains(
            "firewall-cmd --permanent --zone='internal' --add-port='8443/tcp'",
          ),
        ),
      );
    });

    testWidgets('stopped: the saved configuration, and a note', (
      tester,
    ) async {
      await pumpFirewalld(
        tester,
        fixture: 'firewalld/stopped.txt',
        state: 'inactive',
      );

      expect(tester.takeException(), isNull);
      expect(find.text(libL10n.stopped), findsOneWidget);
      expect(find.text(app_locale.l10n.firewallStoppedNote), findsOneWidget);
      expect(find.text(app_locale.l10n.firewallRuntimeOnly), findsNothing);
    });
  });

  testWidgets('both on: firewalld first, a warning, and a way to switch', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeExec(
        probe: _probe(ufw: 'yes', firewalld: 'active'),
        ufw: _fixture('ufw/active.txt'),
        firewalld: _fixture('firewalld/running.txt'),
      ),
    );

    expect(find.text('firewalld 1.3.4'), findsOneWidget);
    expect(find.text(app_locale.l10n.firewallConflict), findsOneWidget);
    await tester.tap(find.byTooltip(app_locale.l10n.firewall));
    await frames(tester);
    await tester.tap(find.text('ufw').last);
    await frames(tester);
    expect(find.text('ufw 0.36.2'), findsOneWidget);
  });

  testWidgets('neither installed says so, without asking for a password', (
    tester,
  ) async {
    final exec = await pump(tester, _FakeExec(probe: _probe()));
    expect(find.text(app_locale.l10n.firewallNoneInstalled), findsOneWidget);
    expect(exec.ran, isEmpty);
  });
}
