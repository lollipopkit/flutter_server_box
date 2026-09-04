import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_db.dart';

/// Remembers what reached a sink, so "was the crash uploaded" is asserted
/// rather than assumed — the local file is written either way.
final class _RecordingSink extends DiagnosticsSink {
  final errors = <({Object error, StackTrace? trace, String? source})>[];

  @override
  void error(Object error, StackTrace? stack, {String? source}) =>
      errors.add((error: error, trace: stack, source: source));
}

/// What happens on the launch after a crash, now that nothing prompts.
///
/// Two halves, and they must not be confused with each other. The report is
/// **kept** so the user can go and read it whenever they get round to it, and
/// it holds the previous run's log — which no diagnostic level uploads, at any
/// level, because the log is the one thing this app writes that nobody has
/// audited for what it might name. What is **sent** is the error alone, and
/// only for a crash nothing else already reported.
///
/// Both failures here are silent. A report that is not kept means the log is
/// gone by the launch after next and nobody notices; a report that is sent
/// means a log left the device that the settings page promised would not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _RecordingSink sink;

  Future<void> launch() async {
    CrashLog.handleErrors();
    await CrashLog.attach(tmp.path);
  }

  File saved() => File(tmp.path.joinPath(CrashReport.savedName));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    tmp = await Directory.systemTemp.createTemp('crash_report_collect_test');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    sink = _RecordingSink();
    Diag.install(FanOutSink([LocalDiagnosticsSink(), sink]));
  });

  tearDown(() async {
    Diag.uninstall();
    await CrashLog.resetForTest();
    await getIt.reset();
    await SqliteDb.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('keeping the report', () {
    test('an ordinary launch keeps nothing', () async {
      await launch();

      await CrashReport.collect();

      expect(await saved().exists(), isFalse);
      expect(await CrashReport.saved(), isNull);
    });

    test('a launch after a crash writes it where it will still be found',
        () async {
      // The point of keeping it at all: `app.log.1` holds the *previous* run,
      // so the launch after next overwrites the crashed run's log with an
      // ordinary one. Nothing prompts any more, so the report has to outlive
      // the launch that built it.
      await launch();
      Loggers.app.warning('a line from the run that died');
      await CrashLog.resetForTest();

      await launch();
      CrashLog.reportPreviousRunCrashed();
      await CrashReport.collect();

      expect(
        await CrashReport.saved(),
        contains('a line from the run that died'),
      );
    });

    test('and it survives a launch that went fine', () async {
      await launch();
      Loggers.app.warning('a line from the run that died');
      await CrashLog.resetForTest();

      await launch();
      CrashLog.reportPreviousRunCrashed();
      await CrashReport.collect();
      await CrashLog.resetForTest();

      // Nothing crashed this time, so `collect` writes nothing — and must not
      // clear what the previous launch kept either.
      await launch();
      await CrashReport.collect();

      expect(
        await CrashReport.saved(),
        contains('a line from the run that died'),
      );
    });

    test('a second crash replaces the first rather than adding to it',
        () async {
      Future<void> crashWith(String line) async {
        await launch();
        Loggers.app.warning(line);
        await CrashLog.resetForTest();
        await launch();
        CrashLog.reportPreviousRunCrashed();
        await CrashReport.collect();
        await CrashLog.resetForTest();
      }

      await crashWith('the first failure');
      await crashWith('the second failure');
      await launch();

      final report = await CrashReport.saved();
      expect(report, contains('the second failure'));
      expect(report, isNot(contains('the first failure')));
    });

    test('dropping it takes it off the device', () async {
      await launch();
      CrashLog.reportPreviousRunCrashed();
      await CrashReport.collect();
      expect(await CrashReport.saved(), isNotNull);

      await CrashReport.dropSaved();

      expect(await CrashReport.saved(), isNull);
      expect(await saved().exists(), isFalse);
    });

    test('and dropping one that is not there is not an error', () async {
      await launch();
      await CrashReport.dropSaved();
    });
  });

  group('what is sent, and what is not', () {
    /// A crash the previous run recorded and nothing uploaded, which is what
    /// the marker keeps a detail for.
    Future<void> crashUnreported() async {
      await launch();
      CrashLog.markUnhandled(StateError('boom'), StackTrace.current);
      await CrashLog.resetForTest();
      await launch();
    }

    test('nothing at all when the level does not upload', () async {
      Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.none.name);
      await crashUnreported();

      await CrashReport.collect();

      expect(sink.errors, isEmpty);
      // Kept all the same. `crashCollectNoneTip` promises exactly this: the
      // report stays on the device and can be sent by hand.
      expect(await CrashReport.saved(), isNotNull);
    });

    test('the error, when the level does upload', () async {
      Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.basic.name);
      await crashUnreported();

      await CrashReport.collect();

      expect(sink.errors, hasLength(1));
      expect(sink.errors.single.error, isA<PreviousRunError>());
      expect('${sink.errors.single.error}', contains('boom'));
      expect(sink.errors.single.source, 'previous run');
    });

    test('never the log, at any level', () async {
      Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.full.name);
      // One run writes both the line and the marker, and the next reads them:
      // a third launch in between would rotate the log this is looking for.
      await launch();
      Loggers.app.warning('a line nobody audited');
      CrashLog.markUnhandled(StateError('boom'));
      await CrashLog.resetForTest();
      await launch();

      await CrashReport.collect();

      // The kept report holds it; what went to the sink does not. That split
      // is the whole of what the level descriptions promise.
      expect(await CrashReport.saved(), contains('a line nobody audited'));
      for (final sent in sink.errors) {
        expect('${sent.error}', isNot(contains('a line nobody audited')));
        expect('${sent.trace}', isNot(contains('a line nobody audited')));
      }
    });

    test('and nothing when a sink already uploaded the error live', () async {
      Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.basic.name);
      await launch();
      // What the app sets from `DiagnosticsUpload.uploading`. The crash is on
      // its way to a backend as the marker is written, so replaying it on this
      // launch would file one bug twice.
      CrashLog.uploadsNow = () => true;
      CrashLog.markUnhandled(StateError('boom'), StackTrace.current);
      await CrashLog.resetForTest();
      await launch();

      await CrashReport.collect();

      expect(sink.errors, isEmpty);
      expect(
        await CrashReport.saved(),
        isNotNull,
        reason: 'the run still ended badly, and the log is still worth keeping',
      );
    });

    test('and nothing for a crash the platform reported on its own path',
        () async {
      // `NativeExitReport.reportPending` sends that one. It leaves no marker
      // detail, so there is nothing here to send a second time.
      Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.basic.name);
      await launch();
      CrashLog.reportPreviousRunCrashed();

      await CrashReport.collect();

      expect(sink.errors, isEmpty);
    });

    test('the stack travels separately from the message', () async {
      // A backend groups by the error's text. A stack folded into it would
      // file every occurrence of one bug as its own issue.
      Stores.setting.diagnosticsLevel.put(DiagnosticsLevel.basic.name);
      await crashUnreported();

      await CrashReport.collect();

      final sent = sink.errors.single;
      expect('${sent.error}', isNot(contains('\n')));
      expect(sent.trace, isNotNull);
    });
  });
}
