/// A plugin on screen: loaded, opened, ticked, tapped and patched, on a real
/// QuickJS context. PLUGINS.md sections 5.2 and 5.3.
///
/// This is the one test where all the pieces are in the same place — the
/// runtime, the bridge, the surface and the renderer — so what it is for is
/// the joins between them, not any one of them.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/health.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/plugin_health.dart';
import 'package:server_box/view/widget/plugin/surface_view.dart';

import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

const _manifest = '''
{
  "id": "app.serverbox.demo",
  "version": "1.0.0",
  "abi": 1,
  "name": "Demo",
  "contributes": { "card": { "id": "demo", "label": "Demo" } }
}
''';

class _Ops implements PluginHostOps {
  final toasts = <String>[];
  Duration execDelay = Duration.zero;
  int execCalls = 0;

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
    Future<void>? cancel,
  }) async {
    execCalls++;
    if (execDelay > Duration.zero) await Future<void>.delayed(execDelay);
    return const PluginExecResult(code: 0, stdout: '', stderr: '');
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
  void toast(String text, String kind) => toasts.add('$kind:$text');

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
    PluginNode? node,
    PluginL10n strings = PluginL10n.empty,
    bool sheet = false,
  }) async => (cancelled: true, values: const <String, String>{});

  @override
  Future<String?> pickServer() async => null;

  @override
  Future<String?> clipboardRead() async => null;

  @override
  Future<void> clipboardWrite(String text) async {}

  @override
  Future<void> openServer(String serverId) async {}

  @override
  Future<void> goTab(String tab) async {}

  @override
  void crumb(String pluginId, String name, String level) {}
}

void main() {
  setUpAll(initRustLibForTest);

  late _Ops ops;
  late PluginBridge bridge;
  late PluginRuntimeService service;

  setUp(() async {
    await openTestDb();
    // The surface records what each call did, and does it through the
    // singleton rather than through `Stores` — which is not registered here.
    await PluginHealthStore.instance.init();
    ops = _Ops();
    bridge = PluginBridge(
      ops: ops,
      handles: PluginServerHandles(),
      store: PluginKvStore(),
    );
    service = PluginRuntimeService(bridge: bridge);
  });

  tearDown(() async {
    service.dispose();
    await closeTestDb();
  });

  /// Lets the real work happen, then draws what came of it.
  ///
  /// A `testWidgets` body runs in a fake-async zone, and loading a plugin is a
  /// real future: the module is compiled on a thread of its own and the answer
  /// comes back over a port. `pump` alone advances a clock that future is not
  /// waiting on, so without `runAsync` nothing here ever finishes.
  Future<void> settle(WidgetTester tester, [int ms = 200]) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pump();
  }

  Future<void> mount(
    WidgetTester tester,
    String source, {
    Duration? refreshInterval,
  }) async {
    // Inside `runAsync`, so `initState` — and the load it starts — runs in the
    // real zone from the beginning. Started in the fake one, the first `await`
    // is a continuation nothing ever delivers.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginSurfaceView(
              spec: PluginSurfaceSpec(
                pluginId: 'app.serverbox.demo',
                manifestJson: _manifest,
                source: source,
                kind: 'card',
                contributionId: 'demo',
              ),
              service: service,
              refreshInterval: refreshInterval,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('open draws what the plugin answered', (tester) async {
    await mount(tester, '''
      export function open(surface) {
        return { ui: { t: "card", v: 1, c: [
          { t: "kv", v: 2, p: { k: "Where", v: surface.kind + "/" + surface.id } },
        ] } };
      }
    ''');

    expect(find.text('Where'), findsOneWidget);
    expect(find.text('card/demo'), findsOneWidget);
  });

  test('runtime inputs decide whether an instance is replaced', () {
    const base = PluginSurfaceSpec(
      pluginId: 'app.serverbox.demo',
      manifestJson: _manifest,
      source: 'export function open() {}',
      kind: 'card',
      contributionId: 'demo',
      granted: ['server.exec', 'server.list'],
      config: {'pool': 'tank', 'depth': '2'},
    );
    const same = PluginSurfaceSpec(
      pluginId: 'app.serverbox.demo',
      manifestJson: _manifest,
      source: 'export function open() {}',
      kind: 'card',
      contributionId: 'demo',
      granted: ['server.list', 'server.exec'],
      config: {'depth': '2', 'pool': 'tank'},
    );
    const changedConfig = PluginSurfaceSpec(
      pluginId: 'app.serverbox.demo',
      manifestJson: _manifest,
      source: 'export function open() {}',
      kind: 'card',
      contributionId: 'demo',
      granted: ['server.exec', 'server.list'],
      config: {'pool': 'backup', 'depth': '2'},
    );

    expect(base.runtimeDiffersFrom(same), isFalse);
    expect(base.runtimeDiffersFrom(changedConfig), isTrue);
  });

  testWidgets('two copies of one contribution keep separate instances', (
    tester,
  ) async {
    const source = '''
      export function open() {
        return { ui: { t: "text", v: 1, p: { value: "same" } } };
      }
    ''';
    const spec = PluginSurfaceSpec(
      pluginId: 'app.serverbox.demo',
      manifestJson: _manifest,
      source: source,
      kind: 'card',
      contributionId: 'demo',
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              PluginSurfaceView(spec: spec, service: service),
              PluginSurfaceView(spec: spec, service: service),
            ],
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('same'), findsNWidgets(2));
    expect(service.loadedCount, 2);
    expect(bridge.onPatch, hasLength(2));
    expect(bridge.onAnswered, hasLength(2));
  });

  /// The half of plugin hot-reload that lives here.
  ///
  /// A development directory is re-read by `PluginInstaller.refresh`, which
  /// bumps `PluginContributions.revision`; a surface following that gets a new
  /// `source` and has to swap the instance for one compiled from it. Before
  /// this was reachable the whole path existed and nothing triggered it.
  testWidgets('a new source replaces the running instance', (tester) async {
    await mount(tester, '''
      export function open() {
        return { ui: { t: "text", v: 1, p: { value: "before" } } };
      }
    ''');
    expect(find.text('before'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginSurfaceView(
              spec: PluginSurfaceSpec(
                pluginId: 'app.serverbox.demo',
                manifestJson: _manifest,
                source: '''
                  export function open() {
                    return { ui: { t: "text", v: 1, p: { value: "after" } } };
                  }
                ''',
                kind: 'card',
                contributionId: 'demo',
              ),
              service: service,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('after'), findsOneWidget);
    expect(find.text('before'), findsNothing);
    // The old instance is gone rather than left running beside the new one.
    expect(service.loadedCount, 1);
  });

  testWidgets(
    'new config replaces the instance even when source is unchanged',
    (tester) async {
      const source = '''
      export function open() {
        return { ui: { t: "column", v: 1, c: [
          { t: "text", v: 2, p: { value: sb.config.get("pool") } },
          { t: "text", v: 3, p: { value: "l10n.label" } },
        ] } };
      }
    ''';
      const before = PluginSurfaceSpec(
        pluginId: 'app.serverbox.demo',
        manifestJson: _manifest,
        source: source,
        kind: 'card',
        contributionId: 'demo',
        config: {'pool': 'tank'},
        l10n: PluginL10n(active: {'label': 'before locale'}),
      );
      const after = PluginSurfaceSpec(
        pluginId: 'app.serverbox.demo',
        manifestJson: _manifest,
        source: source,
        kind: 'card',
        contributionId: 'demo',
        config: {'pool': 'backup'},
        l10n: PluginL10n(active: {'label': 'after locale'}),
      );

      Future<void> show(PluginSurfaceSpec spec) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: PluginSurfaceView(spec: spec, service: service),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
      }

      await show(before);
      expect(find.text('tank'), findsOneWidget);
      expect(find.text('before locale'), findsOneWidget);
      await show(after);

      expect(find.text('backup'), findsOneWidget);
      expect(find.text('after locale'), findsOneWidget);
      expect(find.text('tank'), findsNothing);
      expect(find.text('before locale'), findsNothing);
      expect(service.loadedCount, 1);
    },
  );

  /// A plugin that will not load is named rather than left as an empty space,
  /// which is indistinguishable from a card the user turned off.
  testWidgets('a plugin that does not parse says so', (tester) async {
    await mount(tester, 'export function (');

    expect(find.textContaining('app.serverbox.demo'), findsOneWidget);
  });

  testWidgets('a tap reaches onEvent and the answer redraws', (tester) async {
    await mount(tester, '''
      let taps = 0;
      const view = () => ({ t: "column", v: taps * 2 + 1, c: [
        { t: "text", v: taps * 2 + 2, p: { value: "taps: " + taps } },
        { t: "btn", p: { label: "Again" }, on: { tap: { m: "again" } } },
      ] });
      export function open() { return { ui: view() }; }
      export function onEvent(e) { if (e.msg.m === "again") taps++; return { ui: view() }; }
    ''');
    expect(find.text('taps: 0'), findsOneWidget);

    await tester.tap(find.text('Again'));
    await settle(tester);

    expect(find.text('taps: 1'), findsOneWidget);
  });

  /// The cheap path, and the common one: the shape does not change, so the
  /// plugin answers values and the app sets notifiers instead of rebuilding.
  testWidgets('a tick that answers only values moves the number', (
    tester,
  ) async {
    await mount(tester, '''
        let n = 0;
        export function open() {
          return { ui: { t: "kv", v: 1, p: { k: "CPU", v: { "\$": "cpu" } } },
                   values: { cpu: "0%" } };
        }
        export function tick() { n += 5; return { values: { cpu: n + "%" } }; }
      ''', refreshInterval: const Duration(milliseconds: 50));

    // The timer runs in real time, so what matters is not which number is
    // showing but that the number moves while the shape does not.
    String value() => tester.widget<KvRow>(find.byType(KvRow)).v;
    expect(value(), endsWith('%'));
    final before = value();

    await settle(tester);

    expect(value(), isNot(before));
    expect(
      tester.widget<KvRow>(find.byType(KvRow)).k,
      'CPU',
      reason: 'the tree was never resent',
    );
  });

  testWidgets('timer ticks coalesce while a slow tick is running', (
    tester,
  ) async {
    ops.execDelay = const Duration(milliseconds: 60);
    const manifest = '''
      {
        "id": "app.serverbox.demo",
        "version": "1.0.0",
        "abi": 1,
        "name": "Demo",
        "permissions": { "server.exec": true },
        "contributes": { "card": { "id": "demo", "label": "Demo" } }
      }
    ''';
    const source = '''
      let server;
      export function init(ctx) { server = ctx.server; }
      export function open() {
        return { ui: { t: "text", v: 1, p: { value: "ready" } } };
      }
      export async function tick() {
        await sb.server.exec({ server, script: "slow" });
        return {};
      }
    ''';
    const spec = PluginSurfaceSpec(
      pluginId: 'app.serverbox.demo',
      manifestJson: manifest,
      source: source,
      kind: 'card',
      contributionId: 'demo',
      granted: ['server.exec'],
      serverId: 'server-1',
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: PluginSurfaceView(
            spec: spec,
            service: service,
            refreshInterval: const Duration(milliseconds: 5),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tester.pumpWidget(
        MaterialApp(
          home: PluginSurfaceView(spec: spec, service: service),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();

    expect(ops.execCalls, lessThanOrEqualTo(3));
  });

  /// For a plugin streaming a log: it replaces one subtree rather than
  /// resending the page per line.
  testWidgets('a patch replaces the subtree its pointer names', (tester) async {
    await mount(tester, '''
      export function open() {
        return { ui: { t: "column", v: 1, c: [
          { t: "text", v: 2, p: { value: "first" } },
          { t: "text", v: 3, p: { value: "second" } },
        ] } };
      }
      export async function go() {
        await sb.ui.patch({ path: "/c/1", node: { t: "text", p: { value: "patched" } } });
      }
    ''');
    expect(find.text('second'), findsOneWidget);

    // Called the way a long-running task would call it, from outside a build.
    await tester.runAsync(() async {
      await service.call(_onlyInstance(service), 'go', '');
    });
    await tester.pump();

    expect(find.text('patched'), findsOneWidget);
    expect(find.text('first'), findsOneWidget, reason: 'the sibling stays');
    expect(find.text('second'), findsNothing);
  });

  /// A pointer written against a tree the surface has already replaced. Being
  /// dropped is the only safe answer — there is no node there to replace.
  testWidgets('a patch that names nothing changes nothing', (tester) async {
    await mount(tester, '''
      export function open() {
        return { ui: { t: "column", v: 1, c: [
          { t: "text", v: 2, p: { value: "only" } },
        ] } };
      }
      export async function go() {
        try {
          await sb.ui.patch({ path: "/c/9", node: { t: "text", p: { value: "x" } } });
        } catch (e) { /* the app answered, which is what matters */ }
      }
    ''');

    await tester.runAsync(() async {
      await service.call(_onlyInstance(service), 'go', '');
    });
    await tester.pump();

    expect(find.text('only'), findsOneWidget);
    expect(find.text('x'), findsNothing);
  });

  /// **A surface that stopped waiting still has to see the answer.**
  ///
  /// The host serves one call per instance, so a plugin with work too long to
  /// hold a call — a disk scan somebody may want to stop — answers with its
  /// loading state and leaves the run outstanding. Nothing then calls in: a
  /// card has no refresh interval, and the plugin cannot ask to be called.
  ///
  /// So the surface ticks when the app finishes something the plugin asked
  /// for. Without it the page draws `waiting` for ever, on a plugin that did
  /// everything right, and the only sign is a page that never changes.
  testWidgets('an answer that arrived with nobody waiting is drawn', (
    tester,
  ) async {
    // `open` starts a command and does **not** wait for it, then answers. The
    // tick is what draws whatever came back — which is the shape `surface()`
    // produces for a `background` resource, written out here so the test does
    // not depend on the SDK.
    await mount(tester, r'''
      let reading = null;
      export function open() {
        if (reading === null) {
          sb.store.get({ scope: "global", key: "anything" })
            .then(() => { reading = "arrived"; })
            .catch(() => { reading = "arrived"; });
        }
        return { ui: { t: "text", v: 1, p: { value: reading ?? "waiting" } } };
      }
      export function tick() {
        return { ui: { t: "text", v: 2, p: { value: reading ?? "waiting" } } };
      }
    ''', refreshInterval: null);

    // No timer on this surface, so the tick can only have come from the
    // answer arriving. What it answers does not matter — what is held here is
    // that an answer nobody is waiting for reaches the plugin at all.
    //
    // The loading state is not asserted on the way past: `mount` waits long
    // enough that it may already be gone, which is the mechanism working.
    await settle(tester, 400);

    expect(find.text('arrived'), findsOneWidget);
    expect(find.text('waiting'), findsNothing);
  });

  /// **Which of three things happened is the whole question.** "The plugin
  /// does nothing" is what a user reports, and it covers a collection that did
  /// not run, a plugin that threw, and a tree that never landed. From a
  /// screenshot they are the same; from here they are different stages.
  testWidgets(
    'a plugin that throws is recorded against the stage it threw in',
    (tester) async {
      await mount(tester, 'export function open() { throw new Error("no"); }');

      final one = PluginHealthStore.instance.fetch('app.serverbox.demo');
      expect(one.lastFailure?.stage, PluginStage.open);
      expect(one.lastFailure?.failure, 'threw');
      expect(one.failuresSinceOk, 1);
    },
  );

  /// And a plugin that works records that, which is what makes "it worked
  /// until Tuesday" answerable.
  testWidgets('and one that answers records the stage it answered in', (
    tester,
  ) async {
    await mount(
      tester,
      'export function open() { return { ui: { t: "spacer", v: 1 } }; }',
    );

    final one = PluginHealthStore.instance.fetch('app.serverbox.demo');
    expect(one.lastOk?.stage, PluginStage.open);
    expect(one.lastFailure, isNull);
  });

  /// The instance lives exactly as long as the widget. Without that, a surface
  /// closed and reopened would leave a thread behind each time.
  testWidgets('closing the surface unloads the instance', (tester) async {
    await mount(
      tester,
      'export function open() { return { ui: { t: "spacer", v: 1 } }; }',
    );
    final id = _onlyInstance(service);
    expect(service.exports(id), isNotEmpty);

    // In the real zone, for `mount`'s reason: `dispose` starts the unload and
    // its awaits are continuations the fake zone never delivers.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(service.exports(id), isEmpty, reason: 'the instance is gone');
  });
}

/// The one instance a surface loaded.
///
/// The service does not hand out its ids, so this walks the small range they
/// come from — which is enough for a test that loads exactly one.
BigInt _onlyInstance(PluginRuntimeService service) {
  for (var i = 0; i < 64; i++) {
    final id = BigInt.from(i);
    if (service.exports(id).isNotEmpty) return id;
  }
  throw StateError('no instance is loaded');
}
