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

  test('Android notification permission is requested at most once', () {
    final activity = File(
      'android/app/src/main/kotlin/tech/lolli/toolbox/MainActivity.kt',
    ).readAsStringSync();

    expect(activity, contains('notificationPermissionRequestInFlight'));
    expect(activity, contains('KEY_NOTIFICATION_PERMISSION_REQUESTED'));
    expect(
      activity,
      contains(
        'permissionPrefs.getBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, false)',
      ),
    );

    final persistedAt = activity.indexOf(
      'putBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, true)',
    );
    final inFlightGuardAt = activity.indexOf(
      'if (notificationPermissionRequestInFlight) return',
    );
    final persistedGuardAt = activity.indexOf(
      'permissionPrefs.getBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, false)',
    );
    final requestedAt = activity.indexOf('ActivityCompat.requestPermissions(');
    expect(inFlightGuardAt, greaterThanOrEqualTo(0));
    expect(persistedGuardAt, greaterThan(inFlightGuardAt));
    expect(persistedAt, greaterThanOrEqualTo(0));
    expect(requestedAt, greaterThan(persistedGuardAt));
    expect(requestedAt, greaterThan(persistedAt));

    final resultHandlerAt = activity.indexOf(
      'if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE)',
    );
    final clearedAt = activity.indexOf(
      'notificationPermissionRequestInFlight = false',
      resultHandlerAt,
    );
    expect(resultHandlerAt, greaterThanOrEqualTo(0));
    expect(clearedAt, greaterThan(resultHandlerAt));
    expect(activity, isNot(contains('reqPerm()')));
  });

  test('notification permission denial is not logged as a sync failure', () {
    final channel = File('lib/core/chan.dart').readAsStringSync();

    expect(channel, contains('on PlatformException catch'));
    expect(
      channel,
      contains("if (e.code == 'NOTIFICATION_PERMISSION_DENIED') return;"),
    );
  });
}
