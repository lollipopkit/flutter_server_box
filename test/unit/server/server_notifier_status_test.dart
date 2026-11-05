import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

import '../../helpers/fake_agent_health.dart';
import '../../helpers/rust_lib_helper.dart';

/// What [ServerNotifier] does across a refresh, over a scripted [CommandExec]
/// (this device) or a loopback agent: what it runs, what it caches and what it
/// counts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    await initRustLibForTest();
    tempDir = await Directory.systemTemp.createTemp('sbm-notifier-status-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
    TryLimiter.clear();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  group('this device', () {
    const spi = Spi(name: 'me', id: 'me', local: true);
    final skip = LocalServer.isSupported
        ? null
        : 'this platform cannot read itself as a server';

    late _ScriptedExec exec;
    late ProviderContainer container;
    ServerNotifier notifier() => container.read(serverProvider(spi.id).notifier);
    ServerState state() => container.read(serverProvider(spi.id));

    setUp(() {
      exec = _ScriptedExec(spi.id);
      Stores.server.put(spi);
      container = ProviderContainer(
        overrides: [
          serverProvider(spi.id).overrideWith(() => _ExecNotifier(exec)),
        ],
      );
      container.read(serversProvider);
    });

    tearDown(() => container.dispose());

    test('an answer without segments reinstalls the script', () async {
      exec.status = [''];
      await notifier().refresh();
      expect(exec.installs, 1);
      expect(state().conn, ServerConn.failed);
      expect(
        state().status.err,
        isA<LocalServerErr>().having(
          (e) => e.type,
          'type',
          LocalServerErrType.getStatus,
        ),
      );

      exec.status = [_segment('time', '1710000000')];
      await notifier().refresh();
      expect(exec.installs, 2);
      expect(state().conn, ServerConn.finished);
      expect(state().status.err, isNull);
    }, skip: skip);

    test('failures count against the retry limit', () async {
      Stores.setting.maxRetryCount.put(2);
      exec.status = [''];
      await notifier().refresh();
      await notifier().refresh();
      expect(exec.statusRuns, 2);

      await notifier().refresh();
      expect(exec.statusRuns, 2, reason: 'the limiter stops the third');
      expect(state().conn, ServerConn.failed);

      TryLimiter.reset(spi.id);
      exec.status = [_segment('time', '1710000000')];
      await notifier().refresh();
      expect(exec.statusRuns, 3);
      expect(state().conn, ServerConn.finished);
    }, skip: skip);

    test('an edit that rewrites the script drops the cached extended '
        'output', () async {
      exec.status = [_segment('time', '1710000000')];
      exec.extended = _segment('ip', '10.0.0.9');
      await notifier().refresh();
      await notifier().refresh();
      expect(exec.extendedRuns, 1, reason: 'cached for the interval');

      notifier().updateSpi(spi.copyWith(tags: ['t']));
      await notifier().refresh();
      expect(exec.extendedRuns, 1, reason: 'a tag says nothing of the script');
      expect(exec.installs, 1);

      notifier().updateSpi(
        state().spi.copyWith(disabledCmdTypes: ['BSD.temp']),
      );
      await notifier().refresh();
      expect(exec.extendedRuns, 2);
      expect(exec.installs, 2);
    }, skip: skip);

    test('a failed install throws a ScriptErr and is tried again', () async {
      exec.installOk = false;
      await expectLater(
        notifier().ensureScriptExec(),
        throwsA(
          isA<ScriptErr>().having(
            (e) => e.type,
            'type',
            ScriptErrType.writeScript,
          ),
        ),
      );

      exec.installOk = true;
      expect(await notifier().ensureScriptExec(), same(exec));
      expect(await notifier().ensureScriptExec(), same(exec));
      expect(exec.installs, 2, reason: 'installed once it succeeded');
    });
  });

  group('history', () {
    late HttpServer agent;
    late ProviderContainer container;
    var historyAsks = 0;
    var historyFails = false;
    late Spi spi;

    setUp(() async {
      // The test binding answers every request 400.
      HttpOverrides.global = null;
      historyAsks = 0;
      historyFails = false;
      agent = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      agent.listen((request) async {
        if (await answerAgentHealth(request)) return;
        await request.drain<void>();
        final response = request.response
          ..headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/api/v1/login':
            response.write(jsonEncode({'token': 'token'}));
          case '/api/v1/metrics/history':
            historyAsks++;
            if (historyFails) {
              response.statusCode = HttpStatus.internalServerError;
            } else {
              response.write('[]');
            }
          default:
            response.statusCode = HttpStatus.notFound;
        }
        await response.close();
      });
      spi = Spi(
        name: 'agent',
        id: 'agent',
        monitorHttp: MonitorHttpCredential(
          addr: 'http://${agent.address.address}:${agent.port}',
          pwd: 'password',
        ),
      );
      Stores.server.put(spi);
      container = ProviderContainer();
      container.read(serversProvider);
    });

    tearDown(() async {
      container.dispose();
      await agent.close(force: true);
    });

    ServerNotifier notifier() => container.read(serverProvider(spi.id).notifier);

    test('is seeded once per connection', () async {
      await notifier().seedHistory();
      await notifier().seedHistory();
      expect(historyAsks, 1);

      notifier().closeConnection();
      await notifier().seedHistory();
      await notifier().seedHistory();
      expect(historyAsks, 2);
    });

    test('a failed seed is asked again', () async {
      historyFails = true;
      await notifier().seedHistory();
      expect(historyAsks, greaterThanOrEqualTo(1));
      final failedAsks = historyAsks;

      historyFails = false;
      await notifier().seedHistory();
      expect(historyAsks, failedAsks + 1);
      await notifier().seedHistory();
      expect(historyAsks, failedAsks + 1);
    });
  });
}

String _segment(String key, String body) =>
    '${ffi.scriptSegmentMarker(key: key, custom: false)}\n$body';

class _ExecNotifier extends ServerNotifier {
  _ExecNotifier(this.exec);

  final CommandExec exec;

  @override
  Future<CommandExec> ensureExec({VoidCallback? onSshDial}) async => exec;
}

/// Answers the install, the status function and the extended one, and counts
/// each.
class _ScriptedExec implements CommandExec {
  _ScriptedExec(this.id);

  final String id;
  bool installOk = true;

  /// Successive status answers; the last one repeats.
  List<String> status = [''];
  String extended = '';

  int installs = 0;
  int statusRuns = 0;
  int extendedRuns = 0;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    if (entry != null) {
      installs++;
      return ExecResult(
        exitCode: installOk ? 0 : 1,
        stdout: '',
        stderr: installOk ? '' : 'read-only file system',
      );
    }
    final system = LocalServer.systemType;
    if (script == ShellFunc.statusExt.exec(id, systemType: system, customDir: null)) {
      extendedRuns++;
      return ExecResult(exitCode: 0, stdout: extended, stderr: '');
    }
    if (script == ShellFunc.status.exec(id, systemType: system, customDir: null)) {
      final answer = status[statusRuns.clamp(0, status.length - 1)];
      statusRuns++;
      return ExecResult(exitCode: 0, stdout: answer, stderr: '');
    }
    throw StateError('unexpected command: $script');
  }
}
