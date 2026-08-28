import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:server_box/core/service/crash_log.dart';

/// The log this reads is the only thing a crashed run leaves behind, and it is
/// written once and read on a launch that has already gone wrong. A bug here is
/// silence — an empty report, or a crash that never announces itself — so the
/// rotation and the marker are asserted rather than assumed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  FlutterExceptionHandler? originalOnError;

  File current() => File(tmp.path.joinPath(CrashLog.currentName));
  File previous() => File(tmp.path.joinPath(CrashLog.previousName));

  /// What [CrashLog.handleErrors] plus [CrashLog.attach] do at launch.
  Future<void> launch() async {
    CrashLog.handleErrors();
    await CrashLog.attach(tmp.path);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('crash_log_test');
    // Swallowed while a test runs: `reportError` below would otherwise reach
    // the test framework's handler and fail the test for reporting an error on
    // purpose.
    originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    Logger.root.level = Level.WARNING;
  });

  tearDown(() async {
    await CrashLog.resetForTest();
    FlutterError.onError = originalOnError;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('a line logged before attach still reaches the file', () async {
    CrashLog.handleErrors();
    // Everything `RustLib.init` and `Stores.init` log happens here, before
    // there is a path — and a launch crash logs nothing else.
    Loggers.app.warning('before there was a path');

    await CrashLog.attach(tmp.path);

    expect(await current().readAsString(), contains('before there was a path'));
  });

  test('the previous run is kept whole rather than appended to', () async {
    await launch();
    Loggers.app.warning('first run');
    await CrashLog.resetForTest();

    await launch();
    Loggers.app.warning('second run');

    expect(await previous().readAsString(), contains('first run'));
    expect(await previous().readAsString(), isNot(contains('second run')));
    expect(await current().readAsString(), contains('second run'));
    expect(await current().readAsString(), isNot(contains('first run')));
  });

  test('a third run drops the first, so two files is the ceiling', () async {
    for (final run in ['first', 'second', 'third']) {
      await launch();
      Loggers.app.warning('$run run');
      await CrashLog.resetForTest();
    }

    expect(await previous().readAsString(), contains('second run'));
    expect(
      await Directory(tmp.path).list().length,
      2,
      reason: 'only the current and previous logs, nothing accumulating',
    );
  });

  test('an unhandled error marks the run, and the next launch reads it', () async {
    await launch();
    expect(CrashLog.lastRunEndedBadly, isFalse, reason: 'nothing crashed yet');

    FlutterError.reportError(FlutterErrorDetails(
      exception: StateError('boom'),
      stack: StackTrace.current,
    ));
    await CrashLog.resetForTest();

    await launch();
    expect(CrashLog.lastRunEndedBadly, isTrue);
    expect(await previous().readAsString(), contains('boom'));
  });

  test('the marker is consumed, so one crash is reported once', () async {
    await launch();
    FlutterError.reportError(FlutterErrorDetails(exception: StateError('boom')));
    await CrashLog.resetForTest();

    await launch();
    expect(CrashLog.lastRunEndedBadly, isTrue);
    await CrashLog.resetForTest();

    await launch();
    expect(
      CrashLog.lastRunEndedBadly,
      isFalse,
      reason: 'the launch that read it also cleared it',
    );
  });

  test('a run that ends normally leaves no marker', () async {
    await launch();
    // What Android reclaiming a backgrounded process looks like from here:
    // the app logged, and then was gone. That is not a crash.
    Loggers.app.warning('still running');
    await CrashLog.resetForTest();

    await launch();
    expect(CrashLog.lastRunEndedBadly, isFalse);
  });

  test('a silent FlutterError is not a crash', () async {
    await launch();
    // The framework sets `silent` for what it handles itself and for repeats of
    // an error it already reported. Marking on those would mean a crash dialog
    // after a run that was fine.
    FlutterError.reportError(FlutterErrorDetails(
      exception: StateError('handled'),
      silent: true,
    ));
    await CrashLog.resetForTest();

    await launch();
    expect(CrashLog.lastRunEndedBadly, isFalse);
  });

  test('a run that loops on an error stops growing the file', () async {
    await launch();
    // One line past the ceiling rather than a hundred thousand real ones: the
    // point is that the cap holds, not how it is reached.
    Loggers.app.warning('x' * (CrashLog.maxBytes + 1));
    Loggers.app.warning('after the ceiling');

    final content = await current().readAsString();
    expect(content.length, lessThan(CrashLog.maxBytes + 1024));
    expect(content, contains('log full'));
    expect(content, isNot(contains('after the ceiling')));
  });

  test('logging without a path never grows without bound', () async {
    CrashLog.handleErrors();
    for (var i = 0; i < 500; i++) {
      Loggers.app.warning('line $i');
    }

    await CrashLog.attach(tmp.path);
    final content = await current().readAsString();

    expect(content, contains('line 499'), reason: 'the newest is worth keeping');
    expect(content, isNot(contains('line 0')), reason: 'the buffer is bounded');
  });
}
