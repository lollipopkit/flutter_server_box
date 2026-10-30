import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

import '../helpers/fake_shell.dart';
import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The terminal's reconnect button: for a link to a server or a console, and
/// never one that replaces a shell without asking, or closes a link that still
/// answers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = AppLocalizationsEn();
  final reconnect = find.byTooltip(en.reconnect);

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<SnippetStore>(SnippetStore());
    // The first-run help dialog would sit over the bar, and tmux discovery
    // has nothing to discover on a fake shell.
    Stores.setting.sshTermHelpShown.put(true);
    Stores.setting.tmuxAuto.put(false);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> frames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(
    WidgetTester tester,
    SshPageArgs args, {
    List<Override> overrides = const [],
  }) async {
    // Wide enough for every app bar action to be on screen.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SSHPage(args: args),
        ),
      ),
    );
    await frames(tester);
  }

  /// A console page over a running shell, whose reconnects open shells into
  /// [opened].
  Future<(TerminalSession, FakeShellBackend, FakeShellSession)> console(
    WidgetTester tester,
    List<FakeShellSession> opened,
  ) async {
    final backend = FakeShellBackend();
    final shell = FakeShellSession();
    final session = TerminalSession(
      source: ConsoleSource(
        id: 'virt-console:s:g',
        label: 'web-01',
        connect: () async => _RecordingBackend(opened),
      ),
      backend: backend,
    )..bindForeground(shell);
    await show(tester, SshPageArgs(source: session.source, session: session));
    return (session, backend, shell);
  }

  Future<void> leave(WidgetTester tester, TerminalSession session) async {
    session.close();
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
  }

  testWidgets('a server or console terminal has it, this device\'s does not', (
    tester,
  ) async {
    for (final (source, shown) in [
      (ServerSource(spiFixture(name: 'web', ip: 'h')), true),
      (
        ServerSource(spiFixture(name: 'here', ip: 'h').copyWith(local: true)),
        false,
      ),
      (const LocalSource(), false),
    ]) {
      final session = TerminalSession(
        source: source,
        backend: FakeShellBackend(),
      );
      await show(tester, SshPageArgs(source: source, session: session));
      expect(reconnect, shown ? findsOneWidget : findsNothing, reason: '$source');
      await leave(tester, session);
    }

    final (session, _, _) = await console(tester, []);
    expect(reconnect, findsOneWidget);
    await leave(tester, session);
  });

  testWidgets('without tmux it asks, and cancelling keeps the shell', (
    tester,
  ) async {
    final opened = <FakeShellSession>[];
    final (session, backend, shell) = await console(tester, opened);

    await tester.tap(reconnect);
    await frames(tester, 6);
    expect(find.text(en.reconnectEndsShell), findsOneWidget);

    await tester.tap(find.text(libL10n.cancel));
    await frames(tester, 6);
    expect(find.text(en.reconnectEndsShell), findsNothing);
    expect(backend.isClosed, isFalse);
    expect(session.foreground, same(shell));
    expect(opened, isEmpty);
    await leave(tester, session);
  });

  testWidgets('confirmed, a link that answers is kept and the shell replaced', (
    tester,
  ) async {
    final opened = <FakeShellSession>[];
    final (session, backend, shell) = await console(tester, opened);
    var shellEnded = false;
    unawaited(shell.done.then((_) => shellEnded = true));

    await tester.tap(reconnect);
    await frames(tester, 6);
    await tester.tap(find.text(libL10n.ok));
    await frames(tester, 40);

    // Borrowed and still answering: it may be serving other tabs.
    expect(backend.isClosed, isFalse);
    expect(shellEnded, isTrue);
    expect(opened, hasLength(1));
    expect(session.foreground, same(opened.single));
    await leave(tester, session);
  });

  testWidgets('before the first connection, it is the overlay\'s retry', (
    tester,
  ) async {
    final opened = <FakeShellSession>[];
    var attempts = 0;
    final source = ConsoleSource(
      id: 'virt-console:s:g',
      label: 'web-01',
      connect: () async {
        // Not retryable, so the first open fails at once and stays failed.
        if (attempts++ == 0) throw const TerminalSessionClosed();
        return _RecordingBackend(opened);
      },
    );
    await show(tester, SshPageArgs(source: source));
    expect(opened, isEmpty);

    await tester.tap(reconnect);
    await frames(tester, 40);
    expect(find.text(en.reconnectEndsShell), findsNothing);
    expect(attempts, 2);
    expect(opened, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
  });

  /// A server page whose shell is on the status poller's [client], adopted,
  /// with the poller still holding it for a reconnect to adopt again.
  Future<TerminalSession> onPoller(WidgetTester tester, _PollerClient client) async {
    final spi = spiFixture(id: 'srv', name: 'web-01', ip: '10.0.0.1', user: 'u');
    final session = TerminalSession(source: ServerSource(spi))
      ..adopt(client)
      ..bindForeground(FakeShellSession());
    await show(
      tester,
      SshPageArgs(source: session.source, session: session),
      overrides: [
        serversProvider.overrideWith(() => _Servers(spi)),
        serverProvider(spi.id).overrideWith(() => _Poller(spi, client)),
      ],
    );
    return session;
  }

  // #1782: the reconnect adopts the poller's connection again, and opening the
  // shell on it fails. The connection still answers, so it stays open.
  testWidgets('a failed reconnect keeps the poller\'s connection that answers', (
    tester,
  ) async {
    final client = _PollerClient(answers: true);
    final session = await onPoller(tester, client);

    await tester.tap(reconnect);
    await frames(tester, 6);
    await tester.tap(find.text(libL10n.ok));
    await frames(tester, 40);

    expect(client.shellsAsked, 1);
    expect(client.isClosed, isFalse);
    expect(session.backend, isNull);
    await leave(tester, session);
  });

  // One that does not answer is closed, or the next attempt would adopt the
  // same dead connection and the poller would never dial a new one.
  testWidgets('a failed reconnect closes the poller\'s connection that does not', (
    tester,
  ) async {
    // Answers when asked whether to keep it, and goes with the shell.
    final client = _PollerClient(answers: true, diesWithShell: true);
    final session = await onPoller(tester, client);

    await tester.tap(reconnect);
    await frames(tester, 6);
    await tester.tap(find.text(libL10n.ok));
    await frames(tester, 40);

    expect(client.shellsAsked, 1);
    expect(client.isClosed, isTrue);
    await leave(tester, session);
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

/// The status poller's connection: answers a ping while [answers], and turns
/// down every shell asked of it.
class _PollerClient implements SSHClient {
  _PollerClient({required this.answers, this.diesWithShell = false});

  bool answers;

  /// Stops answering when a shell is turned down.
  final bool diesWithShell;
  int shellsAsked = 0;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  void close() => _closed = true;

  @override
  Future<void> ping() async {
    if (!answers) throw StateError('no reply');
  }

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty = const SSHPtyConfig(),
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    shellsAsked++;
    if (diesWithShell) answers = false;
    throw StateError('channel refused');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Servers extends ServersNotifier {
  _Servers(this.spi);

  final Spi spi;

  @override
  ServersState build() => ServersState(servers: {spi.id: spi}, serverOrder: [spi.id]);
}

class _Poller extends ServerNotifier {
  _Poller(this.spi, this.client);

  final Spi spi;
  final SSHClient client;

  @override
  ServerState build(String serverId) => ServerState(
    spi: spi,
    status: InitStatus.status,
    client: client,
    conn: ServerConn.finished,
  );
}
