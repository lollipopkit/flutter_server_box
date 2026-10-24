import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_platform.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:xterm/ui.dart';

import '../helpers/fake_shell.dart';
import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    Stores.setting.sshTermHelpShown.put(true);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TerminalSession> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = TerminalSession(
      source: const LocalSource(),
      backend: FakeShellBackend(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SSHPage(
            args: SshPageArgs(source: const LocalSource(), session: session),
          ),
        ),
      ),
    );
    await settle(tester);
    return session;
  }

  testWidgets('a click of the wheel scrolls the terminal back', (tester) async {
    final unit = TerminalScrollUnit.of(hostTerminalPlatform);
    if (unit == null) return;

    final session = await pump(tester);
    session.terminal.write('line\n' * 60);
    await settle(tester);

    final terminal = tester.state<TerminalViewState>(
      find.byType(TerminalView),
    );
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(TerminalView),
        matching: find.byType(Scrollable),
      ),
    );
    final lineHeight = terminal.renderTerminal.lineHeight;
    final before = scroll.position.pixels;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getRect(find.byType(TerminalView)).center,
        scrollDelta: Offset(0, -unit.pixelsPerClick),
      ),
    );
    await tester.pump();

    // A click of the wheel is worth the same three lines wherever it was
    // made, and the terminal moves by whole lines.
    expect(before - scroll.position.pixels, closeTo(3 * lineHeight, 0.001));
  });
}
