import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/native_exit.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';
import 'helpers/tombstone_proto.dart';

/// Two decisions here fail silently in opposite directions: treating an
/// ordinary exit as a crash raises a prompt after a normal launch, which
/// teaches the user to dismiss the one that matters; treating a crash as
/// ordinary loses the only record of it. Neither shows up anywhere but here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  Map<String, Object?> record(
    String reason, {
    int timestamp = 1000,
    String? trace,
  }) => {
    'reason': reason,
    'timestamp': timestamp,
    'description': 'desc',
    'status': 0,
    'importance': 100,
    'trace': trace,
  };

  Future<String> logged() =>
      File(tmp.path.joinPath(CrashLog.currentName)).readAsString();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('native_exit_test');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    CrashLog.handleErrors();
    await CrashLog.attach(tmp.path);
    Diag.install(LocalDiagnosticsSink());
  });

  tearDown(() async {
    NativeExitReport.lastExit = null;
    NativeExitReport.lastExitTrace = null;
    Diag.uninstall();
    await CrashLog.resetForTest();
    await getIt.reset();
    await SqliteDb.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('a native crash marks the previous run', () async {
    NativeExitReport.apply(record('crash_native'));

    expect(CrashLog.lastRunEndedBadly, isTrue);
    expect(await logged(), contains('crash_native'));
  });

  test('an ANR and a Java crash count too', () {
    NativeExitReport.apply(record('anr'));
    expect(CrashLog.lastRunEndedBadly, isTrue);
  });

  test('a SIGKILL is a kill, not a crash', () {
    // REASON_SIGNALED covers both an OEM task killer's SIGKILL (9) and a real
    // fault (SIGSEGV 11, SIGABRT 6). Counting 9 would raise a crash prompt
    // after every aggressive background kill, which on some ROMs is routine.
    expect(NativeExitReport.isCrash('signaled', 9), isFalse);
    expect(NativeExitReport.isCrash('signaled', 11), isTrue);
    expect(NativeExitReport.isCrash('signaled', 6), isTrue);
    expect(NativeExitReport.isCrash('crash_native', 11), isTrue);
    expect(NativeExitReport.isCrash('low_memory', 0), isFalse);
  });

  test('a signaled kill does not raise the prompt end to end', () async {
    NativeExitReport.apply({
      'reason': 'signaled',
      'timestamp': 7000,
      'status': 9,
    });

    expect(CrashLog.lastRunEndedBadly, isFalse);
    expect(await logged(), contains('signaled'));
  });

  test('the ANR trace is kept for the report, not only for the log', () async {
    // The report is built from the *previous* run's file; this record arrives
    // into the current one. Without holding it, the trace never reaches a
    // report at all.
    NativeExitReport.apply(record('anr', timestamp: 8000, trace: 'thread dump'));

    expect(NativeExitReport.lastExitTrace, 'thread dump');
  });

  test('being reclaimed for memory is not a crash', () async {
    // The distinction a marker file alone could never make, and the reason
    // this exists: Android kills backgrounded apps as a matter of course, and
    // a prompt after every one of those is a prompt nobody reads.
    NativeExitReport.apply(record('low_memory'));

    expect(CrashLog.lastRunEndedBadly, isFalse);
    // Still recorded — it explains a session that ended on its own.
    expect(await logged(), contains('low_memory'));
  });

  test('an exit the user asked for is not a crash', () {
    for (final reason in ['user_requested', 'user_stopped', 'exit_self']) {
      NativeExitReport.apply(record(reason, timestamp: reason.hashCode.abs()));
      expect(CrashLog.lastRunEndedBadly, isFalse, reason: reason);
    }
  });

  test('the same record is reported once, however often it is handed back',
      () async {
    // Android returns the same record on every launch until another replaces
    // it, and the records carry no id. Without the timestamp check, one crash
    // would raise the prompt on every launch after it, forever.
    NativeExitReport.apply(record('crash_native', timestamp: 5000));
    expect(Stores.setting.lastExitInfoTs.fetch(), 5000);
    final afterFirst = await logged();

    NativeExitReport.apply(record('crash_native', timestamp: 5000));

    expect(
      await logged(),
      afterFirst,
      reason: 'the second pass over the same record wrote nothing',
    );
  });

  test('a newer record after an older one is still reported', () async {
    NativeExitReport.apply(record('low_memory', timestamp: 5000));
    NativeExitReport.apply(record('crash_native', timestamp: 6000));

    expect(CrashLog.lastRunEndedBadly, isTrue);
    expect(Stores.setting.lastExitInfoTs.fetch(), 6000);
  });

  test('an ANR trace is written to the log', () async {
    NativeExitReport.apply(record('anr', trace: 'main prio=5 tid=1 Blocked'));

    expect(await logged(), contains('main prio=5 tid=1 Blocked'));
  });

  group('a native crash tombstone', () {
    Map<String, Object?> nativeRecord(Object? proto, {int timestamp = 9000}) => {
      'reason': 'crash_native',
      'timestamp': timestamp,
      'description': 'desc',
      'status': 0,
      'importance': 100,
      // What the platform side actually sends for this reason: bytes, and no
      // `trace`. Spelled out rather than reusing `record` so the difference
      // between the two shapes is visible here.
      'trace': null,
      'traceProto': proto,
    };

    test('is decoded into the log and held for the report', () async {
      final proto = tombstoneBytes(
        pid: 4321,
        tid: 4330,
        signal: signalOf(
          number: 11,
          name: 'SIGSEGV',
          code: 1,
          codeName: 'SEGV_MAPERR',
          hasFaultAddress: true,
          faultAddress: Int64(0x18),
        ),
        threads: {
          4330: threadOf(
            id: 4330,
            name: '1.ui',
            frames: [
              frameOf(relPc: 0x2b4c, function: 'ssh_kex', file: 'libsbm_ffi.so'),
            ],
          ),
        },
      );

      NativeExitReport.apply(nativeRecord(proto));

      expect(CrashLog.lastRunEndedBadly, isTrue);
      // Held as well as logged: the report is assembled from the *previous*
      // run's file, and this record arrives into the current one.
      expect(NativeExitReport.lastExitTrace, contains('SIGSEGV'));
      expect(NativeExitReport.lastExitTrace, contains('ssh_kex'));
      final log = await logged();
      expect(log, contains('fault addr 0x0000000000000018'));
      expect(log, contains('libsbm_ffi.so'));
    });

    test('an unreadable one still leaves the crash reported', () async {
      // The tombstone lives in a global circular buffer another app's crash can
      // evict, so half a record is a thing that happens. Losing the stack must
      // not also lose the fact that the app died.
      NativeExitReport.apply(
        nativeRecord(Uint8List.fromList([0xff, 0xff, 0xff]), timestamp: 9100),
      );

      expect(CrashLog.lastRunEndedBadly, isTrue);
      expect(NativeExitReport.lastExitTrace, isNull);
      expect(await logged(), contains('crash_native'));
    });

    test('no tombstone at all is not an error', () async {
      NativeExitReport.apply(nativeRecord(null, timestamp: 9200));

      expect(CrashLog.lastRunEndedBadly, isTrue);
      expect(NativeExitReport.lastExitTrace, isNull);
    });
  });

  group('MetricKit', () {
    test('a crash payload marks the run and keeps its call stack', () async {
      NativeExitReport.applyDiagnostics([
        {
          'kind': 'crash',
          'appVersion': '1538',
          'signal': 11,
          'terminationReason': 'Namespace SIGNAL',
          'callStack': '{"callStacks":[]}',
        },
      ]);

      expect(CrashLog.lastRunEndedBadly, isTrue);
      final log = await logged();
      expect(log, contains('signal=11'));
      expect(log, contains('{"callStacks":[]}'));
    });

    test('a hang is recorded but is not a crash', () async {
      // The app was alive and unresponsive, which is a different bug with
      // different causes. Prompting for one would call a slow frame a crash.
      NativeExitReport.applyDiagnostics([
        {'kind': 'hang', 'appVersion': '1538', 'duration': 3.5},
      ]);

      expect(CrashLog.lastRunEndedBadly, isFalse);
      expect(await logged(), contains('metrickit hang'));
    });

    test('a crash among hangs still marks the run', () {
      NativeExitReport.applyDiagnostics([
        {'kind': 'hang', 'appVersion': '1538'},
        {'kind': 'crash', 'appVersion': '1538'},
        {'kind': 'hang', 'appVersion': '1538'},
      ]);

      expect(CrashLog.lastRunEndedBadly, isTrue);
    });

    test('nothing delivered changes nothing', () {
      NativeExitReport.applyDiagnostics([]);

      expect(CrashLog.lastRunEndedBadly, isFalse);
    });
  });

  test('a record with no usable timestamp is ignored rather than throwing', () {
    // The map crosses a platform channel, so its shape is not guaranteed by
    // the type system on this side.
    NativeExitReport.apply({'reason': 'crash_native'});
    NativeExitReport.apply({'reason': 'crash_native', 'timestamp': 'nonsense'});

    expect(CrashLog.lastRunEndedBadly, isFalse);
  });
}
