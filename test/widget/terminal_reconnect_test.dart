import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

import '../helpers/fake_shell.dart';
import '../helpers/spi_fixture.dart';

/// The terminal's reconnect button: for a link to a server, and never one that
/// replaces a shell without asking.
void main() {
  late Directory tempDir;
  final en = AppLocalizationsEn();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-term-reconnect-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
    // The first-run help dialog would sit over the bar.
    Stores.setting.sshTermHelpShown.put(true);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<FakeShellBackend> open(WidgetTester tester, TerminalSource source) async {
    final backend = FakeShellBackend();
    // Wide enough for every app bar action to be on screen.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SSHPage(
            args: SshPageArgs(
              source: source,
              session: TerminalSession(source: source, backend: backend),
            ),
          ),
        ),
      ),
    );
    // Counted out: a terminal always has something scheduled.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return backend;
  }

  final reconnect = find.byTooltip(en.reconnect);

  testWidgets('a server terminal has it, this device\'s does not', (
    tester,
  ) async {
    await open(tester, ServerSource(spiFixture(name: 'web', ip: 'h')));
    expect(reconnect, findsOneWidget);

    await open(tester, const LocalSource());
    expect(reconnect, findsNothing);

    final local = spiFixture(name: 'here', ip: 'h').copyWith(local: true);
    await open(tester, ServerSource(local));
    expect(reconnect, findsNothing);
  });

  testWidgets('without tmux it asks, and cancelling keeps the shell', (
    tester,
  ) async {
    final backend = await open(
      tester,
      ServerSource(spiFixture(name: 'web', ip: 'h')),
    );
    await tester.tap(reconnect);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.reconnectEndsShell), findsOneWidget);

    await tester.tap(find.text(libL10n.cancel));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.reconnectEndsShell), findsNothing);
    expect(backend.isClosed, isFalse);
  });
}
