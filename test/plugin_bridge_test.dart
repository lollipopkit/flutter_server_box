/// The app's side of the `sb` interface. PLUGINS.md section 4.3.
///
/// What is asserted here is the protocol: which JSON shape means what, what a
/// malformed one gets back, and which server a handle resolves to. The work
/// itself is behind [PluginHostOps], so none of it needs an app underneath —
/// and the encoding is the half with no other check on it, since the plugin's
/// side of it is written in TypeScript.
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/store/plugin.dart';

import 'helpers/test_db.dart';

class _Recorded {
  _Recorded(this.what, [this.detail]);
  final String what;
  final Object? detail;

  @override
  String toString() => '$what${detail == null ? '' : '($detail)'}';
}

class _FakeOps implements PluginHostOps {
  final calls = <_Recorded>[];

  PluginExecResult execResult = (code: 0, stdout: 'ok', stderr: '');
  Object? execThrows;
  PluginPromptResult promptResult = (cancelled: true, values: {});
  String? picked;
  String? clipboard = 'copied';

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
  }) async {
    calls.add(_Recorded('exec', '$serverId|$script|${timeout?.inMilliseconds}'));
    final thrown = execThrows;
    if (thrown != null) throw thrown;
    return execResult;
  }

  @override
  void toast(String text, String kind) =>
      calls.add(_Recorded('toast', '$kind|$text'));

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
  }) async {
    calls.add(
      _Recorded('prompt', '$title|${fields.map((f) => f.key).join(',')}'),
    );
    return promptResult;
  }

  @override
  Future<String?> pickServer() async {
    calls.add(_Recorded('pickServer'));
    return picked;
  }

  @override
  Future<String?> clipboardRead() async {
    calls.add(_Recorded('clipboardRead'));
    return clipboard;
  }

  @override
  Future<void> clipboardWrite(String text) async =>
      calls.add(_Recorded('clipboardWrite', text));

  @override
  Future<void> openServer(String serverId) async =>
      calls.add(_Recorded('openServer', serverId));

  @override
  Future<void> goTab(String tab) async => calls.add(_Recorded('goTab', tab));

  @override
  void crumb(String pluginId, String name, String level) =>
      calls.add(_Recorded('crumb', '$pluginId|$name|$level'));
}

void main() {
  late _FakeOps ops;
  late PluginServerHandles handles;
  late PluginBridge bridge;

  setUp(() async {
    await openTestDb();
    // A real row, because the per-server namespace has a foreign key to it —
    // which is what makes a deleted server take a plugin's data with it.
    SqliteDb.instance.execute(
      "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-1', 'one', '10.0.0.1');",
    );
    ops = _FakeOps();
    // Deterministic, so an assertion can name a handle.
    var next = 0;
    handles = PluginServerHandles(generate: () => 'h${next++}');
    bridge = PluginBridge(
      ops: ops,
      handles: handles,
      store: PluginKvStore(),
    );
  });
  tearDown(closeTestDb);

  Future<PluginAnswer> call(String func, [Object? request]) => bridge.answer(
    pluginId: 'app.serverbox.test',
    instanceId: 'inst-1',
    func: func,
    request: request == null ? '' : jsonEncode(request),
  );

  Object? decoded(PluginAnswer answer) =>
      answer.ok == null ? null : jsonDecode(answer.ok!);

  group('server handles', () {
    /// The whole of "a plugin acts only on servers it was given". The runtime
    /// refuses a handle it did not see issued; this is the mapping back, and
    /// what it must not do is resolve anything else.
    test('a handle names a server, and nothing else does', () {
      final handle = handles.bind('inst-1', 'srv-1');

      expect(handles.resolve(handle), 'srv-1');
      expect(handles.resolve('srv-1'), isNull, reason: 'not the id itself');
      expect(handles.resolve('h999'), isNull);
      expect(handles.resolve(null), isNull);
      expect(handles.resolve(42), isNull);
    });

    /// Comparing two handles is the only operation a plugin has on one, so
    /// picking the same server twice has to give the same handle.
    test('the same server gives the same handle within an instance', () {
      final first = handles.issue('inst-1', 'srv-1');
      expect(handles.issue('inst-1', 'srv-1'), first);
      expect(handles.issue('inst-1', 'srv-2'), isNot(first));
    });

    /// Generated per instance, so a handle that leaked out of one names
    /// nothing in another.
    test('two instances do not share a handle', () {
      final a = handles.issue('inst-1', 'srv-1');
      final b = handles.issue('inst-2', 'srv-1');

      expect(a, isNot(b));
      expect(handles.resolve(a), 'srv-1');

      handles.forget('inst-1');
      expect(handles.resolve(a), isNull, reason: 'unloading takes them');
      expect(handles.resolve(b), 'srv-1');
    });
  });

  group('running a command', () {
    test('it reaches the server the handle names', () async {
      final handle = handles.bind('inst-1', 'srv-1');

      final answer = await call('sb.server.exec', {
        'server': handle,
        'script': 'uptime -p',
        'timeoutMs': 2000,
      });

      expect(decoded(answer), {'code': 0, 'stdout': 'ok', 'stderr': ''});
      expect('${ops.calls.single}', 'exec(srv-1|uptime -p|2000)');
    });

    test('a handle nothing was issued for runs nothing', () async {
      final answer = await call('sb.server.exec', {
        'server': 'srv-1',
        'script': 'rm -rf /',
      });

      expect(answer.errorKind, 'bad_request');
      expect(ops.calls, isEmpty);
    });

    /// A plugin blocks until its request is answered, so a failure has to come
    /// back as one rather than as a call that never returns.
    test('a failure is a rejected promise, not a hang', () async {
      handles.bind('inst-1', 'srv-1');
      ops.execThrows = StateError('no route to host');

      final answer = await call('sb.server.exec', {
        'server': handles.issue('inst-1', 'srv-1'),
        'script': 'uptime',
      });

      expect(answer.errorKind, 'io');
      expect(answer.errorMessage, contains('no route to host'));
    });

    test('a request that is not JSON is reported as such', () async {
      final answer = await bridge.answer(
        pluginId: 'p',
        instanceId: 'inst-1',
        func: 'sb.server.exec',
        request: '{',
      );

      expect(answer.errorKind, 'bad_request');
      expect(answer.errorMessage, contains('not JSON'));
    });
  });

  group('the key-value namespaces', () {
    test('global and server are two places', () async {
      handles.bind('inst-1', 'srv-1');

      await call('sb.store.set', {
        'scope': 'global',
        'key': 'token',
        'value': 'g',
      });
      await call('sb.store.set', {
        'scope': 'server',
        'key': 'token',
        'value': 's',
      });

      expect(
        decoded(await call('sb.store.get', {'scope': 'global', 'key': 'token'})),
        {'value': 'g'},
      );
      expect(
        decoded(await call('sb.store.get', {'scope': 'server', 'key': 'token'})),
        {'value': 's'},
      );
    });

    test('a null value deletes', () async {
      await call('sb.store.set', {'scope': 'global', 'key': 'k', 'value': 'v'});
      await call('sb.store.set', {'scope': 'global', 'key': 'k'});

      expect(
        decoded(await call('sb.store.get', {'scope': 'global', 'key': 'k'})),
        {'value': null},
      );
    });

    test('list answers the keys under a prefix', () async {
      for (final key in ['acct.a', 'acct.b', 'other']) {
        await call('sb.store.set', {
          'scope': 'global',
          'key': key,
          'value': '1',
        });
      }

      expect(
        decoded(await call('sb.store.list', {
          'scope': 'global',
          'prefix': 'acct.',
        })),
        {
          'keys': ['acct.a', 'acct.b'],
        },
      );
    });

    /// Two servers' data in one namespace is a plugin reading the wrong
    /// machine's, so an instance with no server has nowhere to put it rather
    /// than falling back to the global one.
    test('server scope on an unbound instance is refused', () async {
      final answer = await call('sb.store.set', {
        'scope': 'server',
        'key': 'k',
        'value': 'v',
      });

      expect(answer.errorKind, 'bad_request');
      expect(answer.errorMessage, contains('scope'));
    });

    test('a scope nobody defined is refused', () async {
      expect(
        (await call('sb.store.get', {'scope': 'everywhere', 'key': 'k'}))
            .errorKind,
        'bad_request',
      );
      expect(
        (await call('sb.store.get', {'key': 'k'})).errorKind,
        'bad_request',
      );
    });
  });

  group('the rest of the interface', () {
    test('a picked server comes back as a handle, not an id', () async {
      ops.picked = 'srv-9';

      final answer = await call('sb.ui.pickServer');

      final handle = (decoded(answer)! as Map)['server'] as String;
      expect(handle, isNot('srv-9'));
      expect(handles.resolve(handle), 'srv-9');
    });

    test('and not picking one says so', () async {
      ops.picked = null;

      expect(decoded(await call('sb.ui.pickServer')), {'cancelled': true});
    });

    test('a prompt carries its fields and answers what was typed', () async {
      ops.promptResult = (cancelled: false, values: {'user': 'admin'});

      final answer = await call('sb.ui.prompt', {
        'title': 'Sign in',
        'fields': [
          {'key': 'user', 'label': 'User'},
          {'key': 'pwd', 'label': 'Password', 'secret': true},
          'not a field',
        ],
      });

      expect('${ops.calls.single}', 'prompt(Sign in|user,pwd)');
      expect(decoded(answer), {
        'cancelled': false,
        'values': {'user': 'admin'},
      });
    });

    test('a toast, a crumb, the clipboard and navigation', () async {
      handles.bind('inst-1', 'srv-1');
      await call('sb.ui.toast', {'text': 'done', 'kind': 'success'});
      await call('sb.diag.crumb', {'name': 'power', 'level': 'warning'});
      await call('sb.clipboard.write', {'text': 'x'});
      await call('sb.nav.goTab', {'tab': 'server'});
      await call('sb.nav.openServer', {
        'server': handles.issue('inst-1', 'srv-1'),
      });

      expect(ops.calls.map((c) => '$c'), [
        'toast(success|done)',
        'crumb(app.serverbox.test|power|warning)',
        'clipboardWrite(x)',
        'goTab(server)',
        'openServer(srv-1)',
      ]);
      expect(
        decoded(await call('sb.clipboard.read')),
        {'text': 'copied'},
      );
    });

    /// A plugin streaming a log should be able to tell that nobody is
    /// watching, rather than have every line silently succeed.
    test('a patch with no surface showing says so', () async {
      final answer = await call('sb.ui.patch', {
        'path': '/c/0',
        'node': {'t': 'text', 'p': {'value': 'line'}},
      });

      expect(answer.errorKind, 'no_surface');
    });

    test('and one with a surface reaches it', () async {
      PluginPatch? seen;
      bridge.onPatch['inst-1'] = (patch) => seen = patch;

      final answer = await call('sb.ui.patch', {
        'path': '/c/0',
        'node': {'t': 'text', 'p': {'value': 'line'}},
      });

      expect(answer.errorKind, isNull);
      expect(seen?.path, '/c/0');
      expect(seen?.node.type, 'text');
    });

    /// Not implemented rather than silently absent: the plugin gets a rejected
    /// promise naming what is missing, and can say so.
    test('http.fetch answers that this build does not have it', () async {
      final answer = await call('sb.http.fetch', {'url': 'https://x/'});

      expect(answer.errorKind, 'unsupported');
    });

    /// It can only be reached from a runtime that installed it, so the two
    /// have drifted — which is a thing to report, not to ignore.
    test('a function this build has no case for is named', () async {
      final answer = await call('sb.nothing.here');

      expect(answer.errorKind, 'unknown_function');
      expect(answer.errorMessage, 'sb.nothing.here');
    });

    test('every function refuses a request of the wrong shape', () async {
      final missing = {
        'sb.ui.toast': {'kind': 'info'},
        'sb.ui.prompt': {'message': 'hi'},
        'sb.diag.crumb': {'level': 'info'},
        'sb.nav.goTab': <String, Object?>{},
        'sb.clipboard.write': <String, Object?>{},
        'sb.ui.patch': {'path': '/c/0'},
      };

      for (final e in missing.entries) {
        final answer = await call(e.key, e.value);
        expect(
          answer.ok,
          isNull,
          reason: '${e.key} accepted a request with nothing in it',
        );
        expect(answer.errorKind, isNotNull, reason: e.key);
      }
    });
  });
}
