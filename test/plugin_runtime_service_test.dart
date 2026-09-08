/// A plugin calling `sb.*` on a real QuickJS context, answered by the app's
/// own bridge. PLUGINS.md sections 4.3 and 10 step 2.
///
/// What this proves that `plugin_bridge_test.dart` cannot: that the loop
/// answers, that it answers the *right* request, and that the two do not
/// deadlock — `call` waits for the plugin, which waits for this isolate.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/data/store/plugin.dart';

import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

const _manifest = '''
{
  "id": "app.serverbox.test",
  "version": "1.0.0",
  "abi": 1,
  "name": "Test",
  "permissions": { "server.exec": true }
}
''';

class _Ops implements PluginHostOps {
  final calls = <String>[];
  PluginExecResult execResult = (code: 0, stdout: 'up 3 days', stderr: '');
  String? picked;

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
  }) async {
    calls.add('exec:$serverId:$script');
    return execResult;
  }

  @override
  Future<List<PluginServerSummary>> listServers() async => const [];

  @override
  Future<void> openTerminal(
    String serverId, {
    String? cmd,
    bool run = false,
  }) async {}

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
  }) async => (
    status: 200,
    headers: const <String, String>{},
    body: '',
    bodyEncoding: 'utf8',
    cert: null,
  );

  @override
  void toast(String text, String kind) => calls.add('toast:$kind:$text');

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
  }) async {
    calls.add('prompt:$title');
    return (cancelled: false, values: {'user': 'admin'});
  }

  @override
  Future<String?> pickServer() async {
    calls.add('pickServer');
    return picked;
  }

  @override
  Future<String?> clipboardRead() async => 'clip';

  @override
  Future<void> clipboardWrite(String text) async => calls.add('write:$text');

  @override
  Future<void> openServer(String serverId) async =>
      calls.add('open:$serverId');

  @override
  Future<void> goTab(String tab) async => calls.add('tab:$tab');

  @override
  void crumb(String pluginId, String name, String level) =>
      calls.add('crumb:$name');
}

void main() {
  setUpAll(initRustLibForTest);

  late _Ops ops;
  late PluginRuntimeService service;
  late PluginBridge bridge;
  final loaded = <BigInt>[];

  setUp(() async {
    await openTestDb();
    SqliteDb.instance.execute(
      "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-1', 'one', '10.0.0.1');",
    );
    ops = _Ops();
    bridge = PluginBridge(
      ops: ops,
      handles: PluginServerHandles(),
      store: PluginKvStore(),
    );
    service = PluginRuntimeService(bridge: bridge);
  });

  tearDown(() async {
    for (final id in loaded) {
      await service.unload(id);
    }
    loaded.clear();
    service.dispose();
    await closeTestDb();
  });

  Future<BigInt> load(
    String source, {
    String? boundServerId = 'srv-1',
    List<String> granted = const ['server.exec'],
  }) async {
    final id = await service.load(
      manifestJson: _manifest,
      source: source,
      instanceId: 'inst-1',
      granted: granted,
      config: const {'addr': 'https://10.0.0.9'},
      boundServerId: boundServerId,
    );
    loaded.add(id);
    return id;
  }

  /// The one that would deadlock. Answering happens on this isolate, so it can
  /// only run if `call` is not sitting on it.
  test('a plugin awaits the app, and the app answers', () async {
    ops.picked = 'srv-1';
    final id = await load('''
      export async function go() {
        const picked = await sb.ui.pickServer();
        const r = await sb.server.exec({ server: picked.server, script: "uptime -p" });
        return r.stdout;
      }
    ''');

    expect(await service.call(id, 'go', ''), '"up 3 days"');
    expect(ops.calls, ['pickServer', 'exec:srv-1:uptime -p']);
  });

  /// The bound server's handle has to resolve before the plugin runs anything,
  /// because `init` may already use it.
  test('the bound server is usable from init onwards', () async {
    final id = await load('''
      let seen = null;
      export async function init(ctx) {
        const r = await sb.server.exec({ server: ctx.server, script: "id -u" });
        seen = r.stdout;
      }
      export function read() { return seen; }
    ''');
    await service.call(id, 'init', jsonEncode({'server': _boundHandle(bridge)}));

    expect(await service.call(id, 'read', ''), '"up 3 days"');
    expect(ops.calls.single, 'exec:srv-1:id -u');
  });

  /// The plugin's data goes to the plugin's own namespace, and reads back.
  test('what a plugin stores is there next time it asks', () async {
    final id = await load('''
      export async function put() {
        await sb.store.set({ scope: "global", key: "k", value: "v" });
      }
      export async function get() {
        return (await sb.store.get({ scope: "global", key: "k" })).value;
      }
      export async function keys() {
        return (await sb.store.list({ scope: "global", prefix: "" })).keys;
      }
    ''');

    await service.call(id, 'put', '');

    expect(await service.call(id, 'get', ''), '"v"');
    expect(await service.call(id, 'keys', ''), '["k"]');
    expect(PluginKvStore().fetch('app.serverbox.test', 'k'), 'v');
  });

  /// The runtime turns an ungranted function into a throwing stub and fails
  /// the call whatever the plugin answered — so a plugin cannot catch its way
  /// past one. The bridge is never reached.
  test('a permission the manifest did not ask for never reaches the app',
      () async {
    final id = await load('''
      export async function go() {
        try { await sb.clipboard.write({ text: "x" }); return "not refused"; }
        catch (e) { return "caught"; }
      }
    ''');

    await expectLater(
      service.call(id, 'go', ''),
      throwsA(isA<Object>()),
      reason: 'catching it does not make the call succeed',
    );
    expect(ops.calls, isEmpty);
  });

  /// A plugin blocks until its request is answered, so an app that cannot do
  /// what was asked still has to say so.
  test('a request the app cannot serve is a rejected promise', () async {
    final id = await load('''
      export async function go() {
        try { await sb.ui.patch({ path: "/c/0", node: { t: "text" } }); return "ok"; }
        catch (e) { return "rejected:" + e.kind; }
      }
    ''');

    expect(await service.call(id, 'go', ''), '"rejected:no_surface"');
  });

  /// The host says the scope and the plugin decides what to load. What is
  /// checkable here is the half the host owns: which servers it hands over.
  group('the enter hook', () {
    const echoHook = '''
      let seen = null;
      export function onHook(ev) { seen = ev; }
      export function read() { return seen; }
    ''';

    test('carries the scope the host was given', () async {
      final id = await load(echoHook, granted: const ['server.list']);
      service.serverNameLookup = (sid) => sid == 'srv-1' ? 'web' : 'db';

      await service.hook(
        id,
        kind: 'enter',
        contributionId: 'panel',
        granted: const ['server.list'],
        serverIds: const ['srv-1', 'srv-2'],
      );

      final seen = jsonDecode(await service.call(id, 'read', '')) as Map;
      expect(seen['kind'], 'enter');
      expect(seen['contribution'], 'panel');
      final servers = seen['servers'] as List;
      expect(servers.map((s) => (s as Map)['name']), ['web', 'db']);
      // Handles, never ids — the same rule `sb.server.list` follows, and for
      // the same reason: one that leaked names nothing.
      for (final s in servers) {
        expect((s as Map)['server'], isNot(anyOf('srv-1', 'srv-2')));
      }
    });

    /// The gate that matters. The payload has room for the whole fleet, so a
    /// plugin that never asked for `server.list` would learn it here — and the
    /// permission would then govern only the call, not the knowledge.
    test('hands over one machine without server.list', () async {
      final id = await load(echoHook);

      await service.hook(
        id,
        kind: 'enter',
        contributionId: 'panel',
        granted: const ['server.exec'],
        serverIds: const ['srv-1', 'srv-2'],
      );

      final seen = jsonDecode(await service.call(id, 'read', '')) as Map;
      expect(seen['servers'] as List, hasLength(1));
    });

    /// A plugin that does not want them is not called, rather than called and
    /// throwing — which would be a warning per surface entered.
    test('a plugin with no onHook is not called', () async {
      final id = await load('export function read() { return 1; }');

      await service.hook(
        id,
        kind: 'enter',
        contributionId: 'panel',
        granted: const ['server.list'],
        serverIds: const ['srv-1'],
      );

      expect(await service.call(id, 'read', ''), '1');
    });

    /// A hook a plugin threw in is a plugin that will not collect, not a
    /// surface that failed to open.
    test('a throwing hook does not throw at the host', () async {
      final id = await load('export function onHook() { throw new Error("x"); }');

      await expectLater(
        service.hook(
          id,
          kind: 'enter',
          contributionId: 'panel',
          granted: const [],
          serverIds: const ['srv-1'],
        ),
        completes,
      );
    });
  });

  test('unloading takes the handles issued to that instance', () async {
    final id = await load('export function a() {}');
    final handle = _boundHandle(bridge);
    expect(bridge.handles.resolve(handle), 'srv-1');

    await service.unload(id);
    loaded.remove(id);

    expect(bridge.handles.resolve(handle), isNull);
  });
}

/// The handle the service issued for the bound server.
String _boundHandle(PluginBridge bridge) =>
    bridge.handles.issue('inst-1', 'srv-1');
