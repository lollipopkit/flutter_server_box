import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_terminal.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

/// End-to-end against a live `monitor` agent with
/// `remote_access.passwordless_terminal` on.
///
/// This path has no SSH in it: the agent runs the PTY itself, so the only
/// thing that can prove the client speaks the protocol correctly is a real
/// agent on the other end.
///
/// ```sh
/// SBM_E2E_MONITOR_URL=http://127.0.0.1:3771 \
/// SBM_E2E_MONITOR_USER=admin \
/// SBM_E2E_MONITOR_PASSWORD=... \
/// flutter test test/monitor_terminal_e2e_test.dart
/// ```
///
/// Credentials come from the environment, never from the repo. Silently
/// skipped when unset.
void main() {
  final env = Platform.environment;
  final url = env['SBM_E2E_MONITOR_URL'];
  final user = env['SBM_E2E_MONITOR_USER'];
  final pwd = env['SBM_E2E_MONITOR_PASSWORD'];

  if (url == null || user == null || pwd == null) {
    test(
      'monitor terminal e2e (skipped: SBM_E2E_MONITOR_* unset)',
      () {},
      skip: true,
    );
    return;
  }

  late MonitorHttpCredential monitor;

  setUpAll(() {
    monitor = MonitorHttpCredential(addr: url, user: user, pwd: pwd);
  });

  /// Opens a shell and returns it together with a buffer of everything it has
  /// written so far.
  Future<(ShellBackend, ShellSession, StringBuffer)> open() async {
    final backend = MonitorShellBackend(monitor);
    final session = await backend.openShell(width: 80, height: 24);
    final seen = StringBuffer();
    session.stdout?.listen((data) => seen.write(utf8.decode(data, allowMalformed: true)));
    return (backend, session, seen);
  }

  /// Polls rather than matching a single frame: a PTY splits output wherever
  /// it likes, so the marker can arrive across two of them.
  Future<void> waitFor(StringBuffer seen, String marker, {String? because}) {
    return Future.doWhile(() async {
      if (seen.toString().contains(marker)) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }).timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          fail('${because ?? 'expected "$marker"'}; saw "$seen"'),
    );
  }

  test('opens a shell with no credentials at all', () async {
    final (backend, session, seen) = await open();
    addTearDown(backend.close);

    session.write(utf8.encode('echo passwordless-marker\n'));
    await waitFor(seen, 'passwordless-marker');

    // The shell runs as the agent's own account — the whole reason this needs
    // the agent to be an ordinary user rather than root. Which account that is
    // depends on where the agent was installed, so it is named explicitly
    // rather than guessed from this machine's environment.
    final shellUser = env['SBM_E2E_SHELL_USER'];
    if (shellUser != null) {
      session.write(utf8.encode('id -un\n'));
      await waitFor(seen, shellUser,
          because: 'the shell should be the agent account');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('carries a resize to the shell', () async {
    final (backend, session, seen) = await open();
    addTearDown(backend.close);

    session.write(utf8.encode('echo ready\n'));
    await waitFor(seen, 'ready');

    session.resizeTerminal(100, 40);
    // Asked of the shell rather than assumed: a resize is a control message,
    // so nothing in the byte stream would otherwise show it arrived. `stty`
    // rather than `tput`, which needs ncurses and is absent on a stock Alpine.
    session.write(utf8.encode('stty size\n'));
    await waitFor(seen, '40 100',
        because: 'the shell should see the new size as rows then columns');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ends the session when the shell exits', () async {
    final (backend, session, _) = await open();
    addTearDown(backend.close);

    session.write(utf8.encode('exit\n'));
    await session.done.timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('the page must learn the shell is gone, not hang'),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('closing ends it too, and reports the source as unusable', () async {
    final (backend, session, seen) = await open();
    addTearDown(backend.close);

    session.write(utf8.encode('echo alive\n'));
    await waitFor(seen, 'alive');

    session.close();
    await session.done.timeout(const Duration(seconds: 10));
    // The keep-alive must fail once the session is over, or the page would
    // sit on a dead terminal believing it is healthy
    await expectLater(backend.ping(), throwsA(isA<StateError>()));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('refuses to run a second command on the one PTY', () async {
    final backend = MonitorShellBackend(monitor);
    addTearDown(backend.close);

    expect(backend.supportsExec, isFalse);
    expect(
      () => backend.execute('id', width: 80, height: 24),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
