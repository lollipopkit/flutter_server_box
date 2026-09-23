/// The app's side of the `sb` interface. PLUGINS.md section 4.3.
///
/// What is asserted here is the protocol: which JSON shape means what, what a
/// malformed one gets back, and which server a handle resolves to. The work
/// itself is behind [PluginHostOps], so none of it needs an app underneath —
/// and the encoding is the half with no other check on it, since the plugin's
/// side of it is written in TypeScript.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
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

  PluginExecResult execResult = const PluginExecResult(
    code: 0,
    stdout: 'ok',
    stderr: '',
  );
  Object? execThrows;

  /// Set to have `exec` wait for the `cancel` it was given rather than answer,
  /// which is what a long command looks like from here.
  PluginExecResult Function()? execAfterCancel;
  PluginPromptResult promptResult = (cancelled: true, values: {});

  /// The body the last prompt was given, if it was given one.
  PluginNode? promptNode;
  bool promptSheet = false;
  String? picked;
  String? clipboard = 'copied';

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
    Future<void>? cancel,
  }) async {
    calls.add(_Recorded('exec', '$serverId|$script|${timeout?.inMilliseconds}'));
    final thrown = execThrows;
    if (thrown != null) throw thrown;
    final after = execAfterCancel;
    if (after != null) {
      // Answers only once the caller asks it to stop, which is the whole of
      // what a long command does here.
      await cancel;
      return after();
    }
    return execResult;
  }

  PluginFetchResult fetchResult = (
    status: 200,
    headers: {'content-type': 'application/json'},
    body: '{}',
    bodyEncoding: 'utf8',
    cert: null,
  );
  Object? fetchThrows;

  @override
  Future<PluginFetchResult> fetch({
    required String url,
    required String method,
    Map<String, String> headers = const {},
    String? body,
    String bodyEncoding = 'utf8',
    String? pinSha256,
    bool probeCert = false,
    Duration? timeout,
  }) async {
    calls.add(
      _Recorded(
        'fetch',
        '$method $url|${headers.length}|$bodyEncoding|$pinSha256|$probeCert'
            '|${timeout?.inMilliseconds}',
      ),
    );
    final thrown = fetchThrows;
    if (thrown != null) throw thrown;
    return fetchResult;
  }

  @override
  Future<List<PluginServerSummary>> listServers() async {
    calls.add(_Recorded('listServers'));
    return servers;
  }

  List<PluginServerSummary> servers = const [];

  @override
  Future<void> openTerminal(
    String serverId, {
    String? cmd,
    bool run = false,
  }) async => calls.add(_Recorded('openTerminal', '$serverId|$cmd|$run'));

  @override
  void toast(String text, String kind) =>
      calls.add(_Recorded('toast', '$kind|$text'));

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
    PluginNode? node,
    PluginL10n strings = PluginL10n.empty,
    bool sheet = false,
  }) async {
    promptNode = node;
    promptSheet = sheet;
    calls.add(
      _Recorded(
        'prompt',
        '$title|${fields.map((f) => '${f.key}=${f.label}').join(',')}',
      ),
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

      expect(handles.resolve('inst-1', handle), 'srv-1');
      expect(
        handles.resolve('inst-1', 'srv-1'),
        isNull,
        reason: 'not the id itself',
      );
      expect(handles.resolve('inst-1', 'h999'), isNull);
      expect(handles.resolve('inst-1', null), isNull);
      expect(handles.resolve('inst-1', 42), isNull);
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
      expect(handles.resolve('inst-1', a), 'srv-1');

      // The map is process-wide, so this is the check that keeps one
      // instance's handle from naming a server in another — and one plugin's
      // from naming one in a different plugin.
      expect(
        handles.resolve('inst-2', a),
        isNull,
        reason: "another instance's handle names nothing here",
      );

      handles.forget('inst-1');
      expect(handles.resolve('inst-1', a), isNull, reason: 'unloading takes them');
      expect(handles.resolve('inst-2', b), 'srv-1');
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

  /// Giving up on a command, and saying what that did to it.
  ///
  /// The second half is the one with no other check on it. Whether the command
  /// was stopped **on the server** is the transport's answer — an SSH channel
  /// carries a signal, one HTTP request to an agent does not — and a plugin
  /// that reported "stopped" for the second case would tell somebody their
  /// server is idle while it walks a filesystem.
  group('stopping a command', () {
    /// A run answers a rejection rather than an empty result on purpose: a
    /// stopped `du` has a *prefix* of its output, and a plugin that did not
    /// check an extra field would draw it as a complete reading.
    test('a stopped run rejects, saying the command was stopped', () async {
      final handle = handles.bind('inst-1', 'srv-1');
      ops.execAfterCancel = () => const PluginExecResult(
        code: -1,
        stdout: 'partial',
        stderr: '',
        end: PluginExecEnd.cancelled,
        stoppedCommand: true,
      );

      final running = call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /',
        'cancelKey': 'scan',
      });
      // The tap, which is a separate call: the plugin is not inside the one
      // above by the time somebody presses Stop.
      final stopped = await call('sb.server.cancel', {'key': 'scan'});
      final answer = await running;

      expect(decoded(stopped), {'stopped': 1});
      expect(answer.errorKind, 'cancelled');
      expect(jsonDecode(answer.errorData!), {'remote': 'stopped'});
    });

    /// The case the distinction exists for.
    test('a transport that only stopped waiting says so', () async {
      final handle = handles.bind('inst-1', 'srv-1');
      ops.execAfterCancel = () => const PluginExecResult(
        code: -1,
        stdout: '',
        stderr: '',
        end: PluginExecEnd.cancelled,
        stoppedCommand: false,
      );

      final running = call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /',
        'cancelKey': 'scan',
      });
      await call('sb.server.cancel', {'key': 'scan'});
      final answer = await running;

      expect(answer.errorKind, 'cancelled');
      expect(jsonDecode(answer.errorData!), {'remote': 'running'});
      expect(answer.errorMessage, contains('may still be running'));
    });

    /// A timeout is the same mechanism and carries the same answer, so a
    /// plugin that handles one handles the other.
    test('a timeout carries what happened to the command too', () async {
      final handle = handles.bind('inst-1', 'srv-1');
      ops.execResult = const PluginExecResult(
        code: -1,
        stdout: '',
        stderr: '',
        end: PluginExecEnd.timedOut,
        stoppedCommand: false,
      );

      final answer = await call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /',
      });

      expect(answer.errorKind, 'timeout');
      expect(jsonDecode(answer.errorData!), {'remote': 'running'});
    });

    /// **A key is scoped to the instance that issued it.** It is a string the
    /// plugin made up, not a handle the host gave out, so without this a
    /// settings surface could stop a page's reading — or one plugin could stop
    /// another's, since both may reasonably call theirs `scan`.
    test('a key reaches nothing another instance started', () async {
      final handle = handles.bind('inst-1', 'srv-1');
      ops.execAfterCancel = () => const PluginExecResult(
        code: -1,
        stdout: '',
        stderr: '',
        end: PluginExecEnd.cancelled,
        stoppedCommand: true,
      );

      final running = call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /',
        'cancelKey': 'scan',
      });

      final elsewhere = await bridge.answer(
        pluginId: 'app.serverbox.test',
        instanceId: 'inst-2',
        func: 'sb.server.cancel',
        request: jsonEncode({'key': 'scan'}),
      );
      expect(decoded(elsewhere), {'stopped': 0});

      // And its own instance still can, which is what says the run was there
      // to be reached at all.
      expect(decoded(await call('sb.server.cancel', {'key': 'scan'})), {
        'stopped': 1,
      });
      await running;
    });

    /// Not a failure: a Stop pressed as the answer came back names nothing,
    /// and the page is already showing the result.
    test('a key nothing is running under answers zero', () async {
      expect(decoded(await call('sb.server.cancel', {'key': 'scan'})), {
        'stopped': 0,
      });
    });

    test('a request with no key is refused rather than stopping everything',
        () async {
      final answer = await call('sb.server.cancel', {});
      expect(answer.errorKind, 'bad_request');
    });

    /// A surface that goes away is one nobody is waiting for. Without this its
    /// commands run to their own timeout, holding an SSH channel and — on a
    /// phone — whatever wakes the radio to read from it.
    test('unloading stops what the instance had outstanding', () async {
      final handle = handles.bind('inst-1', 'srv-1');
      ops.execAfterCancel = () => const PluginExecResult(
        code: -1,
        stdout: '',
        stderr: '',
        end: PluginExecEnd.cancelled,
        stoppedCommand: true,
      );

      final running = call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /',
        'cancelKey': 'scan',
      });
      bridge.runs.forget('inst-1');

      expect((await running).errorKind, 'cancelled');
    });

    /// One key covers several machines on purpose: a fleet-wide surface asks
    /// twenty servers the same question, and stopping is stopping all of them.
    test('one key stops every run carrying it', () async {
      final handle = handles.bind('inst-1', 'srv-1');
      ops.execAfterCancel = () => const PluginExecResult(
        code: -1,
        stdout: '',
        stderr: '',
        end: PluginExecEnd.cancelled,
        stoppedCommand: true,
      );

      final first = call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /a',
        'cancelKey': 'scan',
      });
      final second = call('sb.server.exec', {
        'server': handle,
        'script': 'du -x /b',
        'cancelKey': 'scan',
      });

      expect(decoded(await call('sb.server.cancel', {'key': 'scan'})), {
        'stopped': 2,
      });
      expect((await first).errorKind, 'cancelled');
      expect((await second).errorKind, 'cancelled');
    });
  });

  /// The protocol half of `sb.http.fetch`. What the request *means* — which
  /// addresses are in the grant, what a probe may carry, whether `via: "ssh"`
  /// is allowed — is the runtime's and is checked in `sbm_plugin::scope`; what
  /// is here is the encoding, which has no other check on it.
  group('fetching', () {
    test('the request and the answer both cross intact', () async {
      ops.fetchResult = (
        status: 201,
        headers: {'location': '/redfish/v1/Systems/1'},
        body: '{"ok":true}',
        bodyEncoding: 'utf8',
        cert: {'sha256': 'ab', 'subject': 'CN=bmc', 'expired': false},
      );

      final answer = await call('sb.http.fetch', {
        'url': 'https://10.0.0.9/redfish/v1',
        'method': 'post',
        'headers': {'accept': 'application/json', 'x-n': 3},
        'body': '{}',
        'pinSha256': 'AB12',
        'timeoutMs': 5000,
      });

      expect(decoded(answer), {
        'status': 201,
        'headers': {'location': '/redfish/v1/Systems/1'},
        'body': '{"ok":true}',
        'bodyEncoding': 'utf8',
        'cert': {'sha256': 'ab', 'subject': 'CN=bmc', 'expired': false},
      });
      // Uppercased method, the non-string header dropped rather than the
      // request refused, and the pin passed through as written.
      expect(
        '${ops.calls.single}',
        'fetch(POST https://10.0.0.9/redfish/v1|1|utf8|AB12|false|5000)',
      );
    });

    /// No certificate is the ordinary case for `http://`, and the field has to
    /// be absent rather than null — a plugin reading `res.cert.sha256` off a
    /// null gets a different error than off an undefined.
    test('an answer with no certificate carries no cert field', () async {
      final answer = await call('sb.http.fetch', {'url': 'http://127.0.0.1:8080/a'});

      expect(decoded(answer), isNot(contains('cert')));
      expect('${ops.calls.single}', startsWith('fetch(GET http://127.0.0.1:8080/a'));
    });

    test('a probe is passed on as one', () async {
      await call('sb.http.fetch', {
        'url': 'https://10.0.0.9/',
        'probeCert': true,
      });

      expect('${ops.calls.single}', contains('|true|'));
    });

    /// A refused certificate arrives like any other failure, and deliberately:
    /// what the plugin can do about it — ask the user to review the new one —
    /// is the same either way.
    test('a refused certificate is a rejected promise', () async {
      ops.fetchThrows = const TlsException('certificate not accepted');

      final answer = await call('sb.http.fetch', {
        'url': 'https://10.0.0.9/',
        'pinSha256': 'ab',
      });

      expect(answer.errorKind, 'http');
      expect(answer.errorMessage, contains('certificate not accepted'));
    });

    test('no url is a bad request, and nothing is sent', () async {
      final answer = await call('sb.http.fetch', {'method': 'GET'});

      expect(answer.errorKind, 'bad_request');
      expect(ops.calls, isEmpty);
    });

    /// This build cannot put a request through an SSH connection. Answering it
    /// over the network instead would send it somewhere the plugin did not ask
    /// for, so it is refused rather than quietly redirected.
    test('via ssh says it is unsupported rather than going direct', () async {
      final answer = await call('sb.http.fetch', {
        'url': 'https://10.0.0.9/',
        'via': 'ssh',
        'server': handles.issue('inst-1', 'srv-1'),
      });

      expect(answer.errorKind, 'unsupported');
      expect(ops.calls, isEmpty);
    });
  });

  /// A fleet-wide surface is bound to no one machine, so it has to be able to
  /// ask what exists. The protocol half: handles out, ids never.
  group('listing servers', () {
    test('answers handles and names, never ids', () async {
      ops.servers = const [
        (id: 'srv-1', name: 'web'),
        (id: 'srv-2', name: 'db'),
      ];

      final answer = await call('sb.server.list');
      final servers = (decoded(answer) as Map)['servers'] as List;

      expect(servers, hasLength(2));
      expect(servers.map((s) => (s as Map)['name']), ['web', 'db']);
      // The whole point of a handle: what crosses is opaque, so one that
      // leaked into a log or a plugin's own storage names nothing.
      for (final s in servers) {
        expect((s as Map)['server'], isNot(anyOf('srv-1', 'srv-2')));
      }
      expect(answer.ok, isNot(contains('srv-1')));
    });

    /// The same handle the instance already had, so a plugin can compare the
    /// one it was bound to against the list and find itself.
    test('reuses a handle the instance already holds', () async {
      final bound = handles.bind('inst-1', 'srv-1');
      ops.servers = const [(id: 'srv-1', name: 'web')];

      final answer = await call('sb.server.list');
      final servers = (decoded(answer) as Map)['servers'] as List;

      expect((servers.single as Map)['server'], bound);
    });

    /// A device with no servers is a state a plugin has to be able to draw,
    /// and it must not look like a failure.
    test('no servers is an empty list, not an error', () async {
      final answer = await call('sb.server.list');

      expect(answer.errorKind, isNull);
      expect((decoded(answer) as Map)['servers'], isEmpty);
    });
  });

  group('opening a terminal', () {
    /// Typed and not sent unless asked. A plugin asking for a command to be
    /// *sent* is asking for something the user did not type, so the quiet
    /// default is the safe one.
    test('does not send the command unless told to', () async {
      final handle = handles.bind('inst-1', 'srv-1');

      await call('sb.nav.openTerminal', {'server': handle, 'cmd': 'apk upgrade'});
      expect('${ops.calls.single}', 'openTerminal(srv-1|apk upgrade|false)');

      ops.calls.clear();
      await call('sb.nav.openTerminal', {
        'server': handle,
        'cmd': 'apk upgrade',
        'run': true,
      });
      expect('${ops.calls.single}', 'openTerminal(srv-1|apk upgrade|true)');
    });

    test('a handle nothing was issued for opens nothing', () async {
      final answer = await call('sb.nav.openTerminal', {'server': 'srv-1'});

      expect(answer.errorKind, 'bad_request');
      expect(ops.calls, isEmpty);
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
      expect(handles.resolve('inst-1', handle), 'srv-9');
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

      expect('${ops.calls.single}', 'prompt(Sign in|user=User,pwd=Password)');
      expect(decoded(answer), {
        'cancelled': false,
        'values': {'user': 'admin'},
      });
    });

    /// Every other surface resolves `l10n.` where it draws — the renderer does
    /// it for every node — and this was the one place a plugin's string
    /// reached a widget without passing through it. A fully translated plugin
    /// raised a dialog headed `l10n.addTitle` over boxes labelled
    /// `l10n.fieldWhen` and `l10n.fieldCommand`.
    test('a prompt is shown in the language the plugin was translated into',
        () async {
      final translating = PluginBridge(
        ops: ops,
        handles: handles,
        store: PluginKvStore(),
        strings: (id) => id == 'app.serverbox.test'
            ? const PluginL10n(
                active: {'addTitle': '新建任务', 'fieldWhen': '时间'},
                fallback: {'addTitle': 'New job', 'fieldWhen': 'When'},
              )
            : PluginL10n.empty,
      );

      await translating.answer(
        pluginId: 'app.serverbox.test',
        instanceId: 'inst-1',
        func: 'sb.ui.prompt',
        request: jsonEncode({
          'title': 'l10n.addTitle',
          'fields': [
            {'key': 'when', 'label': 'l10n.fieldWhen', 'value': '0 3 * * *'},
          ],
        }),
      );

      await translating.answer(
        pluginId: 'app.serverbox.test',
        instanceId: 'inst-1',
        func: 'sb.ui.toast',
        request: jsonEncode({'text': 'l10n.addTitle', 'kind': 'success'}),
      );

      expect(ops.calls.map((c) => '$c'), [
        'prompt(新建任务|when=时间)',
        'toast(success|新建任务)',
      ]);
    });

    /// The label is what the user reads; the value is the plugin's data on its
    /// way to a box and back. Resolving that would rewrite a crontab line that
    /// happened to start with the prefix.
    test('a prompt does not translate what is in the box', () async {
      ops.promptResult = (cancelled: false, values: {'when': 'l10n.x'});

      final answer = await call('sb.ui.prompt', {
        'title': 't',
        'fields': [
          {'key': 'when', 'label': 'When', 'value': 'l10n.notAKey'},
        ],
      });

      expect(decoded(answer), {
        'cancelled': false,
        'values': {'when': 'l10n.x'},
      });
    });

    /// The shorthand is a row of text boxes; a body is the general case. A
    /// plugin's editor needs a choice beside a command, and a list of
    /// `TextField`s cannot be one.
    test('a prompt may carry a body the plugin drew', () async {
      ops.promptResult = (cancelled: false, values: {'when': '0 3 * * *'});

      final answer = await call('sb.ui.prompt', {
        'title': 'Edit',
        'as': 'sheet',
        'node': {
          't': 'column',
          'c': [
            {
              't': 'input',
              'p': {'value': '0 3 * * *'},
              'on': {'change': 'when'},
            },
          ],
        },
      });

      expect(ops.promptNode?.type, 'column');
      expect(ops.promptSheet, isTrue);
      expect(decoded(answer), {
        'cancelled': false,
        'values': {'when': '0 3 * * *'},
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
