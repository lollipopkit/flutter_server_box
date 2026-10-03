import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/session_keep_alive.dart';
import 'package:server_box/data/provider/virt/text_consoles.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/fake_shell.dart';
import '../../helpers/test_db.dart';

/// A guest's text console with no page showing it: kept while it runs, handed
/// back to the next page, and closed by [SessionKeepAlive] once left long
/// enough.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    // Never is the default; these are about a console that is closed.
    Stores.setting.remoteSessionIdleTimeout.put(60);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  const id = 'virt-text:s:g';

  (TerminalSession, FakeShellSession?) session({bool running = true}) {
    final shell = running ? FakeShellSession() : null;
    final s = TerminalSession(
      source: ConsoleSource(
        id: 'virt-console:s:g',
        label: 'web-01',
        connect: () async => FakeShellBackend(),
      ),
      backend: FakeShellBackend(),
    );
    if (shell != null) s.bindForeground(shell);
    return (s, shell);
  }

  void run(
    void Function(
      FakeAsync async,
      ProviderContainer container,
      VirtTextConsoles consoles,
    )
    body,
  ) {
    fakeAsync((async) {
      final container = ProviderContainer();
      body(async, container, container.read(virtTextConsolesProvider.notifier));
      container.dispose();
      async.flushTimers();
    });
  }

  test('parked, it is kept and counted as off screen', () {
    run((async, container, consoles) {
      final (s, _) = session();
      consoles.park(id, s, name: 'web-01', host: 'pve');
      expect(container.read(virtTextConsolesProvider), {id});
      // Tracked: left off screen, its notice comes at the timeout.
      async.elapse(const Duration(seconds: 61));
      expect(container.read(sessionKeepAliveProvider), contains(id));
    });
  });

  test('a shell that already ended is closed, not kept', () {
    run((async, container, consoles) {
      final (s, _) = session(running: false);
      consoles.park(id, s, name: 'web-01', host: 'pve');
      expect(container.read(virtTextConsolesProvider), isEmpty);
    });
  });

  test('taken back: out of the list and out of the timeout', () {
    run((async, container, consoles) {
      final (s, shell) = session();
      consoles.park(id, s, name: 'web-01', host: 'pve');
      expect(consoles.take(id), same(s));
      expect(consoles.take(id), isNull);
      expect(container.read(virtTextConsolesProvider), isEmpty);
      // Out of the timeout with it: no notice ever arrives.
      async.elapse(const Duration(hours: 1));
      expect(container.read(sessionKeepAliveProvider), isEmpty);
      expect(s.foreground, same(shell), reason: 'still running');
    });
  });

  test('left long enough, it is closed after the notice', () {
    run((async, container, consoles) {
      final (s, shell) = session();
      var shellClosed = false;
      unawaited(shell!.done.then((_) => shellClosed = true));
      consoles.park(id, s, name: 'web-01', host: 'pve');

      async.elapse(const Duration(seconds: 60));
      expect(container.read(sessionKeepAliveProvider), contains(id));
      async.elapse(SessionKeepAlive.grace);
      expect(container.read(virtTextConsolesProvider), isEmpty);
      expect(shellClosed, isTrue);
    });
  });

  test('replaced by one that has ended: neither is kept, nor counted', () {
    run((async, container, consoles) {
      final (first, _) = session();
      consoles.park(id, first, name: 'web-01', host: 'pve');
      final (second, _) = session(running: false);
      consoles.park(id, second, name: 'web-01', host: 'pve');

      expect(first.foreground, isNull, reason: 'the first was closed');
      expect(container.read(virtTextConsolesProvider), isEmpty);
      // No notice later for a console that no longer exists.
      async.elapse(const Duration(hours: 1));
      expect(container.read(sessionKeepAliveProvider), isNot(contains(id)));
    });
  });

  test('closed while a page showed it: closed as that page parks it', () {
    run((async, container, consoles) {
      // On screen when its guest stopped: nothing parked for close to end.
      final (shown, shell) = session();
      var shellClosed = false;
      unawaited(shell!.done.then((_) => shellClosed = true));
      consoles.close(id);

      // The page goes after, and hands it over.
      consoles.park(id, shown, name: 'web-01', host: 'pve');
      async.flushMicrotasks();
      expect(shellClosed, isTrue);
      expect(container.read(virtTextConsolesProvider), isEmpty);
      // And out of the timeout: nothing follows it.
      async.elapse(const Duration(hours: 1));
      expect(container.read(sessionKeepAliveProvider), isEmpty);

      // A console opened after the guest started again is kept as usual.
      final (next, _) = session();
      consoles.park(id, next, name: 'web-01', host: 'pve');
      expect(container.read(virtTextConsolesProvider), {id});
    });
  });

  test('its shell ending while parked ends the console', () {
    run((async, container, consoles) {
      final (s, shell) = session();
      consoles.park(id, s, name: 'web-01', host: 'pve');
      shell!.finish();
      async.flushMicrotasks();
      expect(container.read(virtTextConsolesProvider), isEmpty);
      // Nothing left to warn about later.
      async.elapse(const Duration(hours: 1));
      expect(container.read(sessionKeepAliveProvider), isEmpty);
    });
  });
}
