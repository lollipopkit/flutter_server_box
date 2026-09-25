import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('the app off screen holds the countdown until it is back', () {
    run((async, container, keepAlive, closed) {
      final binding = TestWidgetsFlutterBinding.instance;
      keepAlive.setVisible('a', false);
      async.elapse(const Duration(seconds: 62));
      expect(notices(container)['a']?.deadline, isNotNull);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(notices(container)['a']?.deadline, isNull);
      async.elapse(const Duration(minutes: 10));
      expect(closed, isEmpty, reason: 'nobody could see the notice');

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(
        notices(container)['a']?.deadline,
        clock.now().add(SessionKeepAlive.grace),
        reason: 'the whole countdown, once it can be seen',
      );
      async.elapse(SessionKeepAlive.grace);
      expect(closed, ['a']);
    });
  });
}
