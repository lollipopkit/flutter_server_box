@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/ssh/android_service_policy.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('${Miscs.pkgName}/main_chan');
  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );

  test('wanted terminal state updates the service', () {
    expect(
      decideAndroidSessionServiceAction(
        wanted: true,
        running: false,
        backgrounded: false,
      ),
      AndroidSessionServiceAction.update,
    );
  });

  test('idle foreground state stops a running service', () {
    expect(
      decideAndroidSessionServiceAction(
        wanted: false,
        running: true,
        backgrounded: false,
      ),
      AndroidSessionServiceAction.stop,
    );
  });

  test('idle state leaves a pending foreground start alone', () {
    expect(
      decideAndroidSessionServiceAction(
        wanted: false,
        running: false,
        backgrounded: false,
      ),
      AndroidSessionServiceAction.none,
    );
  });

  test('a wanted state followed by idle updates before stopping', () {
    final actions = [
      decideAndroidSessionServiceAction(
        wanted: true,
        running: false,
        backgrounded: false,
      ),
      decideAndroidSessionServiceAction(
        wanted: false,
        running: true,
        backgrounded: false,
      ),
    ];

    expect(actions, [
      AndroidSessionServiceAction.update,
      AndroidSessionServiceAction.stop,
    ]);
  });

  test('idle background state leaves the service unchanged', () {
    expect(
      decideAndroidSessionServiceAction(
        wanted: false,
        running: true,
        backgrounded: true,
      ),
      AndroidSessionServiceAction.none,
    );
  });

  test('unsupported platforms do not dispatch Android service calls', () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    await MethodChans.updateSessions('{"sessions":[],"keepAlive":false}');
    await MethodChans.stopService();
    expect(calls, isEmpty);
  }, skip: Platform.isAndroid);

  test('updates and stops dispatch through the platform channel', () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    const payload = '{"sessions":[],"keepAlive":true}';
    await MethodChans.updateSessions(payload);
    await MethodChans.stopService();
    expect(calls.map((call) => call.method), ['updateSessions', 'stopService']);
    expect(calls.first.arguments, payload);
  }, skip: !Platform.isAndroid ? 'Requires Android platform runtime' : false);

  test(
    'permission denial is handled without preventing a later update',
    () async {
      var attempts = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        attempts++;
        if (attempts == 1) {
          throw PlatformException(code: 'NOTIFICATION_PERMISSION_DENIED');
        }
        return null;
      });
      await MethodChans.updateSessions('{}');
      await MethodChans.updateSessions('{}');
      expect(attempts, 2);
    },
    skip: !Platform.isAndroid ? 'Requires Android platform runtime' : false,
  );
}
