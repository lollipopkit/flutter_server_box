import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart';

import 'helpers/fake_shell.dart';

/// Right-click in the terminal, which is copy or paste depending on nothing
/// but whether anything is selected.
///
/// The convention every terminal on every platform keeps, and the one part of
/// the context-menu work that no test reached: `TerminalView.onSecondaryTapUp`
/// is wired directly rather than through `onSecondary`, so `fl_lib`'s tests do
/// not cover it either.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final clipboard = <String>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-term-');
    SqliteDb.openInMemory();
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());

    clipboard.clear();
    // The real channel would reach a platform that is not here. Recorded
    // rather than stubbed away, because what is copied is the assertion.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboard.add((call.arguments as Map)['text'] as String);
              return null;
            case 'Clipboard.getData':
              return {'text': 'pasted from the clipboard'};
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Everything the terminal was told to send upstream, which is where a
  /// paste lands: `_onTerminalPaste` calls `Terminal.textInput`.
  late List<String> typed;

  Future<TerminalSession> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = TerminalSession.over(
      const LocalSource(),
      FakeShellBackend(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // A session passed in is one the page adopts: already connected and
          // already running something, so it opens no shell of its own. That
          // is what keeps this test off a socket.
          home: SSHPage(
            args: SshPageArgs(source: const LocalSource(), session: session),
          ),
        ),
      ),
    );
    // Counted out rather than settled: a terminal always has something
    // scheduled, so `pumpAndSettle` would wait out its ten-minute default.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    typed = <String>[];
    session.terminal.onOutput = typed.add;
    return session;
  }

  /// The right-click, called the way the terminal calls it.
  ///
  /// Invoked on the callback the page handed to `TerminalView` rather than by
  /// synthesising a pointer. xterm's gesture handler is
  /// `HitTestBehavior.deferToChild` over a render object that a widget test's
  /// synthetic mouse does not reach, so a real secondary tap never arrives —
  /// which would make this a test of the arena instead of a test of what the
  /// app decides when one does. The wiring itself is one line
  /// (`page.dart:433`) and is visible in the widget below.
  Future<void> secondaryTap(WidgetTester tester) async {
    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(
      view.onSecondaryTapUp,
      isNotNull,
      reason: 'the page stopped handing the terminal a right-click handler',
    );
    view.onSecondaryTapUp!(
      TapUpDetails(kind: PointerDeviceKind.mouse),
      CellOffset(0, 0),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the page builds on a backend that is not a connection', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(SSHPage), findsOneWidget);
    expect(find.byType(TerminalView), findsOneWidget);
  });

  testWidgets('with nothing selected, a right-click pastes', (tester) async {
    await pump(tester);

    await secondaryTap(tester);

    expect(typed.join(), contains('pasted from the clipboard'));
    expect(clipboard, isEmpty, reason: 'it copied instead of pasting');
  });

  /// The page's own controller, reached through the widget it handed it to.
  TerminalController controllerOf(WidgetTester tester) =>
      tester.widget<TerminalView>(find.byType(TerminalView)).controller!;

  /// Selects everything on screen, through the render object the page built —
  /// so the selection is the one `_onClipboardAction` reads, not a copy.
  void selectAll(WidgetTester tester) => tester
      .state<TerminalViewState>(find.byType(TerminalView))
      .renderTerminal
      .selectAll();

  testWidgets('with text selected, a right-click copies it', (tester) async {
    final session = await pump(tester);
    session.terminal.write('the selected line\r\n');
    await tester.pump(const Duration(milliseconds: 50));

    selectAll(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controllerOf(tester).selection, isNotNull, reason: 'nothing selected');

    await secondaryTap(tester);

    expect(clipboard, hasLength(1));
    expect(clipboard.single, contains('the selected line'));
    // And it did not also paste: the two branches are exclusive.
    expect(typed, isEmpty);
  });

  testWidgets('and clears the selection afterwards', (tester) async {
    // Otherwise the next right-click copies the same text again instead of
    // pasting, which is the shape every other terminal has.
    final session = await pump(tester);
    session.terminal.write('the selected line\r\n');
    await tester.pump(const Duration(milliseconds: 50));
    selectAll(tester);
    await tester.pump(const Duration(milliseconds: 50));

    await secondaryTap(tester);

    expect(controllerOf(tester).selection, isNull);

    // Proved by the second one pasting.
    await secondaryTap(tester);
    expect(typed.join(), contains('pasted from the clipboard'));
  });

  testWidgets('an empty clipboard types nothing', (tester) async {
    // `Clipboard.getData` answers null when there is nothing to paste, and
    // `textInput('')` would be a no-op anyway — but the guard is what stops a
    // null reaching the terminal as the string "null".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    await pump(tester);

    await secondaryTap(tester);

    expect(typed, isEmpty);
  });

  testWidgets('the right-click handler is the page\'s, not the terminal\'s', (
    tester,
  ) async {
    // What makes the two branches reachable at all. `TerminalView` takes the
    // callback rather than deciding for itself, so copy-or-paste is this app's
    // choice and stays testable from here.
    await pump(tester);

    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(view.onSecondaryTapUp, isNotNull);
  });
}
