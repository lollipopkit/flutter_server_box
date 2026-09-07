// The plugin runtime across the FFI boundary.
//
// What this proves that the Rust tests cannot: that a plugin's host call
// reaches Dart, that Dart's answer reaches the plugin, and that the two do not
// deadlock. The second is the one worth a test — `call` waits for the plugin,
// which waits for Dart to answer, so it has to run somewhere other than the
// isolate doing the answering. If `load` or `call` were ever marked
// `frb(sync)`, every test here would hang rather than fail.
//
// Build the native library first: cargo build -p sbm_ffi

import 'dart:async';
import 'dart:convert';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/src/rust/api/plugin.dart';

import 'rust_lib_helper.dart';

const _manifest = '''
{
  "id": "app.serverbox.test",
  "version": "1.0.0",
  "abi": 1,
  "name": "Test",
  "permissions": { "server.exec": true, "net.http": ["\$config.addr"] },
  "config": { "fields": [
    {"key": "addr", "type": "text", "label": "l10n.addr", "role": "address"}
  ]}
}
''';

/// A runtime plus the answering loop the app will own.
class _Fixture {
  _Fixture(this.runtime, this.requests, this.logs, this._subs);

  final PluginRuntime runtime;
  final List<PluginRequest> requests;
  final List<PluginLog> logs;
  final List<StreamSubscription<void>> _subs;

  /// Stops listening, without waiting for it.
  ///
  /// `RustStreamSink`'s stream comes from an `async*` generator sitting on a
  /// `ReceivePort`; cancelling its subscription returns a future that does not
  /// complete while the port is idle, so awaiting it hangs the test. The app
  /// has no reason to await it either: a sink stays open for the runtime's
  /// life, and what ends it is dropping the runtime.
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }

  /// Starts a runtime whose host calls are answered by [reply].
  ///
  /// [reply] returns the JSON to answer with, or throws a [_Refusal] to make
  /// the app refuse. Answering happens on this isolate, which is the whole
  /// point: it can only run if `call` is not occupying it.
  static Future<_Fixture> start(
    FutureOr<String> Function(PluginRequest req) reply,
  ) async {
    final requests = <PluginRequest>[];
    final logs = <PluginLog>[];
    final requestSink = RustStreamSink<PluginRequest>();
    final logSink = RustStreamSink<PluginLog>();

    // Listened to only after the sinks have been handed over: the stream does
    // not exist until the generated code has set it up.
    final runtime = await PluginRuntime.newInstance(
      requests: requestSink,
      logs: logSink,
    );

    final subs = <StreamSubscription<void>>[
      requestSink.stream.listen((req) async {
        requests.add(req);
        try {
          runtime.answer(callId: req.callId, ok: await reply(req));
        } on _Refusal catch (e) {
          runtime.answer(callId: req.callId, denied: e.detail);
        } catch (e) {
          runtime.answer(
            callId: req.callId,
            errorKind: 'io',
            errorMessage: '$e',
          );
        }
      }),
      logSink.stream.listen(logs.add),
    ];

    return _Fixture(runtime, requests, logs, subs);
  }
}

class _Refusal implements Exception {
  const _Refusal(this.detail);
  final String detail;
}

PluginSpec _spec(
  String source, {
  String instanceId = 'inst-1',
  List<String> granted = const ['server.exec', 'net.http'],
  String? boundServer = 'bound',
}) => PluginSpec(
  manifestJson: _manifest,
  source: source,
  instanceId: instanceId,
  granted: granted,
  config: const [('addr', 'https://10.0.0.9')],
  boundServer: boundServer,
);

void main() {
  setUpAll(initRustLibForTest);

  group('what the app can read without loading anything', () {
    test('the ABI version and the permission list come from the runtime', () {
      expect(pluginAbiVersion(), 1);
      // Read from Rust rather than restated here, so the install dialog and the
      // runtime cannot disagree about what a manifest may ask for.
      expect(
        pluginPermissions(),
        containsAll(<String>['server.exec', 'net.http', 'ui.dialog']),
      );
    });

    test('every host function the app has to implement is listed', () {
      final fns = pluginHostFunctions();
      expect(fns, contains('sb.http.fetch'));
      expect(fns, contains('sb.server.exec'));
      expect(fns.length, 14);
    });

    test('a manifest is read without running anything', () {
      final info = pluginReadManifest(manifestJson: _manifest);
      expect(info.id, 'app.serverbox.test');
      expect(info.abi, 1);
      // Sorted, because the manifest keeps permissions in a sorted map.
      expect(info.permissions, ['net.http', 'server.exec']);
    });

    test('a manifest needing a newer ABI is refused with both numbers', () {
      expect(
        () => pluginReadManifest(
          manifestJson: _manifest.replaceFirst('"abi": 1', '"abi": 99'),
        ),
        throwsA(
          isA<PluginFailure>()
              .having((e) => e.kind, 'kind', 'manifest')
              .having((e) => e.message, 'message', contains('v99')),
        ),
      );
    });
  });

  group('loading and calling', () {
    late _Fixture fx;
    tearDown(() => fx.dispose());

    test('input and the answer cross unchanged', () async {
      fx = await _Fixture.start((_) => 'null');
      final id = await fx.runtime.load(
        spec: _spec('export function echo(x) { return x; }'),
      );
      expect(
        await fx.runtime.call(
          instance: id,
          export_: 'echo',
          input: '{"a":[1,2]}',
        ),
        '{"a":[1,2]}',
      );
      expect(fx.runtime.exports(instance: id), ['echo']);
      expect(fx.runtime.hasExport(instance: id, export_: 'echo'), isTrue);
    });

    test('a plugin that does not parse fails at load', () async {
      fx = await _Fixture.start((_) => 'null');
      expect(
        () => fx.runtime.load(spec: _spec('export function (')),
        throwsA(isA<PluginFailure>().having((e) => e.kind, 'kind', 'module')),
      );
    });

    test('a missing export is named rather than hanging', () async {
      fx = await _Fixture.start((_) => 'null');
      final id = await fx.runtime.load(spec: _spec('export function a() {}'));
      expect(
        () => fx.runtime.call(instance: id, export_: 'b', input: ''),
        throwsA(
          isA<PluginFailure>().having((e) => e.kind, 'kind', 'no_such_export'),
        ),
      );
    });
  });

  group('host calls', () {
    late _Fixture fx;
    tearDown(() => fx.dispose());

    /// The one that would deadlock. Answering happens on this isolate, so it
    /// can only run if `call` is not sitting on it.
    test('a plugin awaits and this isolate answers', () async {
      fx = await _Fixture.start((req) {
        expect(req.func, 'sb.server.exec');
        expect(jsonDecode(req.request)['script'], 'uptime -p');
        return jsonEncode({'code': 0, 'stdout': 'up 3 days', 'stderr': ''});
      });

      final id = await fx.runtime.load(
        spec: _spec('''
          export async function go() {
            const r = await sb.server.exec({ server: "bound", script: "uptime -p" });
            return r.stdout;
          }
        '''),
      );

      expect(
        await fx.runtime.call(instance: id, export_: 'go', input: ''),
        '"up 3 days"',
      );
      expect(fx.requests, hasLength(1));
      expect(fx.runtime.outstanding(), 0);
    });

    /// An answer that has to be awaited on the Dart side, which is the ordinary
    /// case: every real host function does IO.
    test('an answer the app takes time over still arrives', () async {
      fx = await _Fixture.start((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return jsonEncode({'code': 0, 'stdout': 'slow', 'stderr': ''});
      });

      final id = await fx.runtime.load(
        spec: _spec('''
          export async function go() {
            const r = await sb.server.exec({ server: "bound", script: "x" });
            return r.stdout;
          }
        '''),
      );
      expect(
        await fx.runtime.call(instance: id, export_: 'go', input: ''),
        '"slow"',
      );
    });

    test('two calls awaited together are both answered', () async {
      fx = await _Fixture.start((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final script = jsonDecode(req.request)['script'] as String;
        return jsonEncode({'code': 0, 'stdout': script, 'stderr': ''});
      });

      final id = await fx.runtime.load(
        spec: _spec('''
          export async function go() {
            const [a, b] = await Promise.all([
              sb.server.exec({ server: "bound", script: "one" }),
              sb.server.exec({ server: "bound", script: "two" }),
            ]);
            return a.stdout + "," + b.stdout;
          }
        '''),
      );
      expect(
        await fx.runtime.call(instance: id, export_: 'go', input: ''),
        '"one,two"',
      );
      expect(fx.requests, hasLength(2));
    });

    /// A host that could not do the thing is an answer the plugin handles, not
    /// a plugin that dies.
    test('a failure the app reports is caught by the plugin', () async {
      fx = await _Fixture.start((_) => throw StateError('bmc unreachable'));

      final id = await fx.runtime.load(
        spec: _spec('''
          export async function go() {
            try {
              await sb.server.exec({ server: "bound", script: "x" });
              return "unreachable";
            } catch (e) { return e.kind + ": " + e.message; }
          }
        '''),
      );
      expect(
        await fx.runtime.call(instance: id, export_: 'go', input: ''),
        contains('bmc unreachable'),
      );
    });

    /// The app refusing is not catchable, so a plugin cannot carry on past a
    /// scope it was denied.
    test('the app refusing ends the call', () async {
      fx = await _Fixture.start((_) => throw const _Refusal('unknown server'));

      final id = await fx.runtime.load(
        spec: _spec('''
          export async function go() {
            try { await sb.server.exec({ server: "bound", script: "x" }); }
            catch (e) { return "swallowed"; }
          }
        '''),
      );
      expect(
        () => fx.runtime.call(instance: id, export_: 'go', input: ''),
        throwsA(
          isA<PluginFailure>()
              .having((e) => e.kind, 'kind', 'denied')
              .having((e) => e.message, 'message', contains('unknown server')),
        ),
      );
    });

    test('a permission the manifest did not ask for is denied by name', () async {
      fx = await _Fixture.start((_) => 'null');
      final id = await fx.runtime.load(
        spec: _spec('''
          export async function go() {
            await sb.ui.prompt({ title: "hi" });
          }
        '''),
      );
      expect(
        () => fx.runtime.call(instance: id, export_: 'go', input: ''),
        throwsA(
          isA<PluginFailure>()
              .having((e) => e.kind, 'kind', 'denied')
              .having((e) => e.message, 'message', contains('ui.dialog')),
        ),
      );
      expect(fx.requests, isEmpty, reason: 'the app was asked anyway');
    });

    test('logs arrive without being answered', () async {
      fx = await _Fixture.start((_) => 'null');
      final id = await fx.runtime.load(
        spec: _spec('export function go() { sb.log.warn("released"); }'),
      );
      await fx.runtime.call(instance: id, export_: 'go', input: '');

      // The stream is delivered asynchronously, so give it a turn.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fx.logs.map((l) => '${l.level}:${l.message}'), ['warn:released']);
      expect(fx.requests, isEmpty);
    });
  });

  group('instances', () {
    late _Fixture fx;
    tearDown(() => fx.dispose());

    test('two instances keep their own state', () async {
      fx = await _Fixture.start((_) => 'null');
      const src = 'let n = 0; export function bump() { return ++n; }';
      final a = await fx.runtime.load(spec: _spec(src, instanceId: 'a'));
      final b = await fx.runtime.load(spec: _spec(src, instanceId: 'b'));

      expect(await fx.runtime.call(instance: a, export_: 'bump', input: ''), '1');
      expect(await fx.runtime.call(instance: a, export_: 'bump', input: ''), '2');
      expect(await fx.runtime.call(instance: b, export_: 'bump', input: ''), '1');
    });

    test('config reaches the plugin', () async {
      fx = await _Fixture.start((_) => 'null');
      final id = await fx.runtime.load(
        spec: _spec('export function addr() { return sb.config.get("addr"); }'),
      );
      expect(
        await fx.runtime.call(instance: id, export_: 'addr', input: ''),
        '"https://10.0.0.9"',
      );
    });

    test('an unloaded instance answers rather than hanging', () async {
      fx = await _Fixture.start((_) => 'null');
      final id = await fx.runtime.load(spec: _spec('export function a() {}'));
      await fx.runtime.unload(instance: id);
      expect(
        () => fx.runtime.call(instance: id, export_: 'a', input: ''),
        throwsA(isA<PluginFailure>().having((e) => e.kind, 'kind', 'internal')),
      );
    });
  });
}
