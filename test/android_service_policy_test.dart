@TestOn('vm') // Reads the Android and Dart source trees through dart:io.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/android_service_policy.dart';

void main() {
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

  test('terminal-page source wiring does not own the Android service', () {
    final source = File('lib/view/page/ssh/page/page.dart').readAsStringSync();

    expect(source, isNot(contains('MethodChans.startService')));
    expect(source, isNot(contains('MethodChans.stopService')));
  });

  test('Android source wiring dispatches stop through a service action', () {
    final activity = File(
      'android/app/src/main/kotlin/tech/lolli/toolbox/MainActivity.kt',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/tech/lolli/toolbox/ForegroundService.kt',
    ).readAsStringSync();

    expect(activity, isNot(contains('"startService" ->')));
    expect(activity, isNot(contains('stopService(serviceIntent)')));
    expect(
      activity,
      contains('action = ForegroundService.ACTION_STOP_SERVICE'),
    );
    expect(service, contains('intent?.action == ACTION_STOP_SERVICE'));
  });
}
