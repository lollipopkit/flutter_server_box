import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

import '../helpers/fake_shell.dart';
import '../helpers/test_db.dart';

/// A terminal page given `onLeave` hands its session on when it goes, still
/// running, rather than closing or releasing it — how a guest's text console
/// outlives the page showing it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('reconnect', _reenter);

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A page over a running shell, then the page gone.
  Future<(TerminalSession, FakeShellSession, bool Function())> showThenLeave(
    WidgetTester tester, {
    void Function(TerminalSession)? onLeave,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final shell = FakeShellSession();
    var shellClosed = false;
    unawaited(shell.done.then((_) => shellClosed = true));
    final session = TerminalSession(
      source: ConsoleSource(
        id: 'virt-console:s:g',
        label: 'web-01',
        connect: () async => FakeShellBackend(),
      ),
      backend: FakeShellBackend(),
    )..bindForeground(shell);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SSHPage(
            args: SshPageArgs(
              source: session.source,
              session: session,
              onLeave: onLeave,
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    return (session, shell, () => shellClosed);
  }

  testWidgets('with onLeave: handed on, still running', (tester) async {
    TerminalSession? left;
    final (session, shell, shellClosed) = await showThenLeave(
      tester,
      onLeave: (s) => left = s,
    );
    expect(left, same(session));
    expect(session.foreground, same(shell));
    expect(shellClosed(), isFalse);
    expect(session.onForegroundDone, isNull, reason: 'the page is gone');
    session.close();
    await frames(tester);
  });
}

/// A shell on the host behind a guest's console: a reconnect opens a fresh
/// one, which must be taken back into the console rather than left as the
/// host's shell under a page still showing the guest.
void _reenter() {
  testWidgets('a reconnect types the console command into the new shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final opened = <FakeShellSession>[];
    final first = FakeShellBackend();
    final first0 = FakeShellSession();
    final session = TerminalSession(
      source: ConsoleSource(
        id: 'virt-console:s:g',
        label: 'web-01',
        connect: () async => _RecordingBackend(opened),
      ),
      backend: first,
    )
      ..reenter = "virsh console 'd'"
      ..bindForeground(first0);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SSHPage(
            args: SshPageArgs(source: session.source, session: session),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The link drops: the transport is gone, and the shell with it.
    first.close();
    first0.finish();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(opened, hasLength(1));
    expect(opened.single.written.toString(), contains("virsh console 'd'"));
    session.close();
    await tester.pumpWidget(const SizedBox());
  });
}

class _RecordingBackend extends FakeShellBackend {
  _RecordingBackend(this.opened);

  final List<FakeShellSession> opened;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    final shell = FakeShellSession();
    opened.add(shell);
    return shell;
  }
}
