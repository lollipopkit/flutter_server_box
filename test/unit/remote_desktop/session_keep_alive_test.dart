import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/session_keep_alive.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

/// [SessionKeepAlive] over fake time: when a session left off screen gets its
/// notice, and what closes it or keeps it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    // The binding outlives the test: one left hidden would start the next
    // with the app off screen.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await getIt.reset();
    await closeTestDb();
  });

  /// Runs [body] in fake time with a fresh container, and one session `a`
  /// registered on screen. [closed] counts its closes.
  void run(
    void Function(
      FakeAsync async,
      ProviderContainer container,
      SessionKeepAlive keepAlive,
      List<String> closed,
    )
    body, {
    int timeoutSeconds = 60,
  }) {
    fakeAsync((async) {
      Stores.setting.remoteSessionIdleTimeout.put(timeoutSeconds);
      async.flushMicrotasks();
      final container = ProviderContainer();
      final keepAlive = container.read(sessionKeepAliveProvider.notifier);
      final closed = <String>[];
      keepAlive.register(
        'a',
        name: 'web-01',
        host: 'pve',
        onClose: () => closed.add('a'),
      );
      body(async, container, keepAlive, closed);
      container.dispose();
      async.flushTimers();
    });
  }

  Map<String, SessionExpiry> notices(ProviderContainer c) =>
      c.read(sessionKeepAliveProvider);

  test('on screen, nothing happens however long it is', () {
    run((async, container, keepAlive, closed) {
      async.elapse(const Duration(hours: 1));
      expect(notices(container), isEmpty);
      expect(closed, isEmpty);
    });
  });

  test('left, then the timeout, then the notice, then closed', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 59));
      expect(notices(container), isEmpty);

      async.elapse(const Duration(seconds: 1));
      final notice = notices(container)['a'];
      expect(notice?.name, 'web-01');
      expect(notice?.host, 'pve');
      expect(notice?.deadline, clock.now().add(SessionKeepAlive.grace));

      async.elapse(SessionKeepAlive.grace - const Duration(milliseconds: 1));
      expect(closed, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(closed, ['a']);
      expect(notices(container), isEmpty);
      expect(keepAlive.isRegistered('a'), isFalse);
    });
  });

  test('keep alive starts a full timeout again', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 65));
      expect(notices(container), contains('a'));

      keepAlive.keepAlive('a');
      expect(notices(container), isEmpty);
      async.elapse(const Duration(seconds: 59));
      expect(notices(container), isEmpty);
      expect(closed, isEmpty);

      async.elapse(const Duration(seconds: 1));
      expect(notices(container), contains('a'));
      async.elapse(SessionKeepAlive.grace);
      expect(closed, ['a']);
    });
  });

  test('coming back while the notice is up cancels it', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 65));
      expect(notices(container), contains('a'));

      keepAlive.setVisible('a', true);
      expect(notices(container), isEmpty);
      async.elapse(const Duration(hours: 1));
      expect(closed, isEmpty);

      // Leaving again is a new full timeout, not the rest of the old one.
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 59));
      expect(notices(container), isEmpty);
    });
  });

  test('never: a session left is never closed', () {
    run(timeoutSeconds: 0, (async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(days: 2));
      expect(notices(container), isEmpty);
      expect(closed, isEmpty);
    });
  });

  test('a changed timeout applies to sessions already waiting', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 20));

      // Shorter than the time already waited: the notice now.
      Stores.setting.remoteSessionIdleTimeout.put(15);
      async.flushMicrotasks();
      expect(notices(container), contains('a'));

      // Longer: the notice goes, and comes at the new time from when the
      // session was left.
      Stores.setting.remoteSessionIdleTimeout.put(300);
      async.flushMicrotasks();
      expect(notices(container), isEmpty);
      async.elapse(const Duration(seconds: 279));
      expect(notices(container), isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(notices(container), contains('a'));

      // Never, with the notice up: withdrawn, and nothing closes.
      Stores.setting.remoteSessionIdleTimeout.put(0);
      async.flushMicrotasks();
      expect(notices(container), isEmpty);
      async.elapse(const Duration(hours: 1));
      expect(closed, isEmpty);
    });
  });

  test('several at once: one notice each, each on its own', () {
    run((async, container, keepAlive, closed) {
      keepAlive.register(
        'b',
        name: 'db-01',
        host: 'kvm',
        onClose: () => closed.add('b'),
        visible: false,
      );
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 60));
      expect(notices(container).keys, unorderedEquals(['a', 'b']));

      keepAlive.keepAlive('b');
      async.elapse(SessionKeepAlive.grace);
      expect(closed, ['a']);
      expect(notices(container), isEmpty);
    });
  });

  test('closed by its owner: forgotten, notice and all', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 61));
      keepAlive.unregister('a');
      expect(notices(container), isEmpty);
      async.elapse(const Duration(minutes: 5));
      expect(closed, isEmpty);
    });
  });

  void hide() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }

  void show() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  test('off screen, the countdown holds; back, it carries on', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 60 + 3));
      expect(notices(container)['a']?.deadline, isNotNull);

      hide();
      expect(notices(container)['a']?.deadline, isNull);
      expect(notices(container)['a']?.paused, const Duration(seconds: 7));
      async.elapse(const Duration(seconds: 30));
      expect(closed, isEmpty, reason: 'nobody can see the notice');

      show();
      expect(
        notices(container)['a']?.deadline,
        clock.now().add(const Duration(seconds: 7)),
        reason: 'what was left, not a fresh countdown',
      );
      async.elapse(const Duration(seconds: 7));
      expect(closed, ['a']);
    });
  });

  test('back with a second left: at least long enough to keep it', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 60 + 9));
      hide();
      async.elapse(const Duration(seconds: 5));
      show();
      expect(
        notices(container)['a']?.deadline,
        clock.now().add(SessionKeepAlive.graceOnReturn),
      );

      // Going away and back again buys nothing more.
      async.elapse(const Duration(seconds: 3));
      hide();
      show();
      expect(
        notices(container)['a']?.deadline,
        clock.now().add(SessionKeepAlive.graceOnReturn),
      );
      async.elapse(SessionKeepAlive.graceOnReturn);
      expect(closed, ['a']);
    });
  });

  test('a notice off screen for another whole timeout closes, and says so',
      () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 61));
      hide();
      async.elapse(const Duration(seconds: 59));
      expect(closed, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(closed, ['a']);
      expect(notices(container), isEmpty);
      expect(
        container.read(sessionsClosedAwayProvider),
        isEmpty,
        reason: 'said when the app is back, not while nobody can see it',
      );

      show();
      final reported = container.read(sessionsClosedAwayProvider);
      expect(reported.map((e) => (e.name, e.host)), [('web-01', 'pve')]);
    });
  });

  test('a notice that first appears off screen waits the same way', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      hide();
      async.elapse(const Duration(seconds: 60));
      expect(notices(container)['a']?.paused, SessionKeepAlive.grace);
      async.elapse(const Duration(seconds: 59));
      expect(closed, isEmpty);

      show();
      expect(
        notices(container)['a']?.deadline,
        clock.now().add(SessionKeepAlive.grace),
      );
      async.elapse(SessionKeepAlive.grace);
      expect(closed, ['a']);
      expect(container.read(sessionsClosedAwayProvider), isEmpty);
    });
  });

  test('back after the away wait ran out, its timer not yet run: closed', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 61));
      hide();
      // A suspended app: hours pass by the clock, and the away timer has
      // not had its turn when the app is shown again.
      withClock(Clock.fixed(clock.now().add(const Duration(hours: 3))), show);
      expect(closed, ['a'], reason: 'not another grace after hours away');
      expect(notices(container), isEmpty);
      expect(
        container.read(sessionsClosedAwayProvider).map((e) => e.name),
        ['web-01'],
      );
    });
  });

  test('a shorter timeout applies to a notice waiting off screen', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      // Up from 60 s, and still up at 90 s whatever the new timeout.
      async.elapse(const Duration(seconds: 61));
      hide();
      async.elapse(const Duration(seconds: 20));

      Stores.setting.remoteSessionIdleTimeout.put(30);
      async.flushMicrotasks();
      expect(notices(container), contains('a'));
      async.elapse(const Duration(seconds: 9));
      expect(closed, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(closed, ['a'], reason: '30 s from when the wait began');
    });
  });

  test('a timeout already passed closes a notice waiting off screen', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 61));
      hide();
      async.elapse(const Duration(seconds: 40));

      Stores.setting.remoteSessionIdleTimeout.put(30);
      async.flushMicrotasks();
      expect(closed, ['a']);
    });
  });

  test('off screen with no timeout, nothing closes by itself', () {
    run((async, container, keepAlive, closed) {
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 61));
      hide();
      // Set to never while the notice was up: the notice stays.
      Stores.setting.remoteSessionIdleTimeout.put(0);
      async.elapse(const Duration(hours: 2));
      expect(closed, isEmpty);
      show();
    });
  });

  test('an owner provider disposed takes its registrations with it', () {
    fakeAsync((async) {
      Stores.setting.remoteSessionIdleTimeout.put(60);
      async.flushMicrotasks();
      final container = ProviderContainer(
        overrides: [serversProvider.overrideWith(_NoServers.new)],
      );
      final keepAlive = container.read(sessionKeepAliveProvider.notifier);
      final sessions = container.read(remoteDesktopSessionsProvider.notifier);
      final profile = RemoteDesktopProfile.defaults(
        id: 'vm',
        serverId: 'server',
        name: 'vm',
        protocol: RemoteDesktopProtocol.vnc,
      );
      // Never connects: what is under test is the bookkeeping.
      sessions.openConsole(
        profile,
        target: () => Completer<RemoteDesktopTarget>().future,
      );
      expect(keepAlive.isRegistered('vm'), isTrue);

      container.invalidate(remoteDesktopSessionsProvider);
      container.read(remoteDesktopSessionsProvider);
      async.flushMicrotasks();
      expect(
        keepAlive.isRegistered('vm'),
        isFalse,
        reason: 'no notice for a desktop already closed',
      );

      // Off screen for the timeout and the grace: nothing to show or close.
      async.elapse(const Duration(minutes: 5));
      expect(container.read(sessionKeepAliveProvider), isEmpty);

      // A registration the rebuilt provider makes is its own.
      container
          .read(remoteDesktopSessionsProvider.notifier)
          .openConsole(
            profile,
            target: () => Completer<RemoteDesktopTarget>().future,
          );
      container.invalidate(remoteDesktopSessionsProvider);
      keepAlive.register(
        'vm',
        name: 'vm',
        host: 'other owner',
        onClose: () {},
      );
      async.flushMicrotasks();
      expect(keepAlive.isRegistered('vm'), isTrue);

      container.dispose();
      async.flushTimers();
    });
  });
}

final class _NoServers extends ServersNotifier {
  @override
  ServersState build() => const ServersState();
}
