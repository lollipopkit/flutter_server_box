/// The ufw page, drawn from what a real ufw printed (`test/fixtures/ufw/`)
/// rather than from a server, and what each control asks the server to run.
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
import 'package:server_box/data/service/ufw_manager.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/firewall.dart';

import '../helpers/spi_fixture.dart';

const _sid = 'ufw-1';

/// A root account on a host with ufw, answering the read with [readout] and
/// keeping every other script it is handed.
final class _FakeExec implements ServerExec {
  _FakeExec(this.readout);

  final String readout;
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
    if (script == UfwManager.probeScript) {
      return ok('${UfwManager.installedMarker}\n${UfwManager.uidMarker}0\n');
    }
    if (script == UfwManager.readScript) return ok(readout);
    ran.add(script);
    return ok('');
  }
}

final class _FakeServerNotifier extends ServerNotifier {
  _FakeServerNotifier(this.exec);

  final _FakeExec exec;

  @override
  ServerState build(String id) =>
      ServerState(spi: spiFixture(id: id, name: 'gw', ip: '10.0.0.2'), status: InitStatus.status);

  @override
  Future<ServerExec> ensureExec({VoidCallback? onSshDial}) async => exec;
}

String _fixture(String name) =>
    File('test/fixtures/ufw/$name').readAsStringSync();

void main() {
  final page = FirewallPage(
    args: SpiRequiredArgs(spiFixture(id: _sid, name: 'gw', ip: '10.0.0.2')),
  );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_FakeExec> pump(
    WidgetTester tester, {
    String readout = '',
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final exec = _FakeExec(
      readout.isEmpty ? _fixture('active.txt') : readout,
    );
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

  Future<void> tapOk(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, libL10n.ok));
    await frames(tester);
  }

  testWidgets('lists the rules once per rule, at phone width', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(libL10n.active), findsOneWidget);
    expect(find.text('ufw 0.36.2'), findsOneWidget);
    expect(find.text('Rules · 12'), findsOneWidget);
    expect(find.text('22/tcp'), findsOneWidget);
    expect(find.text('ssh access'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('My App'), 200);
    expect(find.text('My App'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('fits a desktop window too', (tester) async {
    await pump(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Rules · 12'), findsOneWidget);
  });

  testWidgets('turning it off shows and runs ufw disable', (tester) async {
    final exec = await pump(tester);

    await tester.tap(find.byType(Switch));
    await frames(tester);
    expect(find.textContaining(UfwManager.disableCommand), findsOneWidget);
    await tapOk(tester);

    expect(exec.ran, hasLength(1));
    expect(exec.ran.single, contains('\n${UfwManager.disableCommand}\n'));
  });

  testWidgets('turning it on offers to let the SSH port in first', (
    tester,
  ) async {
    // Inactive, and with the rule that let 22 in gone.
    final readout = _fixture('inactive_no_ipv6.txt')
        .split('\n')
        .where((line) => !line.contains(' tcp 22 '))
        .join('\n');
    final exec = await pump(tester, readout: readout);

    await tester.tap(find.byType(Switch));
    await frames(tester);
    expect(find.text(app_locale.l10n.firewallAllowFirstFmt('22')), findsOne);
    await tapOk(tester);

    final script = exec.ran.single;
    final allow = script.indexOf(UfwManager.allowTcpCommand(22));
    expect(allow, greaterThan(0));
    expect(script.indexOf(UfwManager.enableCommand), greaterThan(allow));
  });

  Finder ruleMenu(String tuple) => find.descendant(
    of: find.byKey(ValueKey('ufw-rule:$tuple')),
    matching: find.byType(ContextMenuButton),
  );

  testWidgets('deleting a rule names it by its tuples', (tester) async {
    final exec = await pump(tester);

    await tester.tap(
      ruleMenu('### tuple ### deny any any 0.0.0.0/0 any 203.0.113.9 in'),
    );
    await frames(tester);
    await tester.tap(find.text(libL10n.delete));
    await frames(tester);
    // Not a rule that lets the SSH port in: nothing to warn about.
    expect(find.text(app_locale.l10n.firewallAllowFirstFmt('22')), findsNothing);
    await tapOk(tester);

    expect(
      exec.ran.single,
      contains("t='### tuple ### deny any any 0.0.0.0/0 any 203.0.113.9 in'"),
    );
    expect(exec.ran.single, contains('ufw --force delete'));
  });

  testWidgets('deleting the rule that lets SSH in warns, both families', (
    tester,
  ) async {
    final exec = await pump(tester);

    await tester.tap(
      ruleMenu(
        '### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in '
        'comment=73736820616363657373',
      ),
    );
    await frames(tester);
    await tester.tap(find.text(libL10n.delete));
    await frames(tester);
    expect(find.text(app_locale.l10n.firewallAllowFirstFmt('22')), findsOne);
    // Kept unticked here: the rule is going, and nothing takes its place.
    await tester.tap(find.byType(CheckboxListTile));
    await frames(tester);
    await tapOk(tester);

    final script = exec.ran.single;
    expect(script, isNot(contains(UfwManager.allowTcpCommand(22))));
    expect(script, contains(' 22 0.0.0.0/0 '));
    expect(script, contains(' 22 ::/0 '));
  });

  testWidgets('adding a rule runs what the form describes', (tester) async {
    final exec = await pump(tester);

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

  testWidgets('a routed rule takes both interfaces from more options', (
    tester,
  ) async {
    final exec = await pump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await frames(tester);
    // The page's routed policy row is behind the dialog.
    await tester.tap(find.text(app_locale.l10n.firewallRouted).last);
    await frames(tester);
    await tester.enterText(
      find.widgetWithText(TextField, libL10n.port),
      '8080',
    );
    await tester.ensureVisible(find.text(app_locale.l10n.firewallMoreOptions));
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
    final exec = await pump(tester);

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
}
