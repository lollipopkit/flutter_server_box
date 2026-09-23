/// The first plugin written against the host interface, run on the real host.
///
/// `packages/plugins/listening-ports` has its own tests against `MockHost`,
/// which is where a plugin author's tests go and which proves the plugin
/// agrees with the SDK. This proves something else and is the reason it is
/// worth having twice: that the SDK and the app agree — the same bundle, in
/// QuickJS, with the app's `sb.*` under it and the app's renderer over it.
///
/// It reads the built `dist/plugin.js`, so it fails if the bundle is stale.
/// Build it first: cd packages/plugins/listening-ports && bun run build
///
/// Build the native library first too: cargo build -p sbm_ffi
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';

import 'helpers/plugin_host_ops.dart';
import 'rust_lib_helper.dart';

const _dir = 'packages/plugins/listening-ports';

const _ss = '''
fmt=ss
tcp   LISTEN 0 4096 0.0.0.0:22     0.0.0.0:* users:(("sshd",pid=1,fd=3))
tcp   LISTEN 0 511  127.0.0.1:6379 0.0.0.0:* users:(("redis-server",pid=9,fd=6))
''';

void main() {
  setUpAll(initRustLibForTest);

  late FakePluginHostOps ops;
  late PluginRuntimeService service;
  late BigInt instance;
  late String manifestJson;

  setUp(() async {
    manifestJson = File('$_dir/manifest.json').readAsStringSync();
    final source = File('$_dir/dist/plugin.js').readAsStringSync();

    ops = FakePluginHostOps()
      ..execResult = PluginExecResult(code: 0, stdout: _ss, stderr: '');
    service = PluginRuntimeService(
      bridge: PluginBridge(ops: ops, handles: PluginServerHandles()),
    );
    await service.start();
    instance = await service.load(
      manifestJson: manifestJson,
      source: source,
      instanceId: 'inst-ports',
      // What the manifest asks for, which is the one thing it asks for.
      granted: const ['server.exec'],
      config: const {},
      boundServerId: 'srv-1',
    );
  });

  tearDown(() async {
    await service.unload(instance);
    service.dispose();
  });

  /// Every string the tree would put on screen, in order.
  ///
  /// Reads the props that carry text and not only `text` nodes: a `tile`'s
  /// title and a `summary`'s figure are properties, so a walker looking for
  /// `text` children alone would say a page full of rows says nothing. Matches
  /// `texts` in `@serverbox/plugin-api/test`.
  List<String> texts(PluginNode node) {
    const keys = ['value', 'title', 'subtitle', 'label', 'detail', 'k', 'v'];
    final out = <String>[];
    void walk(PluginNode n) {
      for (final key in keys) {
        final v = n.props[key];
        if (v is String && v.isNotEmpty) out.add(v);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(node);
    return out;
  }

  PluginNode nodeOf(String raw) =>
      PluginNode.fromJson(jsonDecode(raw) as Map<String, dynamic>)!;

  /// What tapping the thing labelled [label] sends, exactly as the app would.
  ///
  /// `messageOf` in `@serverbox/plugin-api/test` is the same walk on the other
  /// side. Both exist for one reason: a handler is a closure, so what crosses
  /// is a token, and a test that made up a message would be speaking a
  /// protocol the plugin does not.
  Object? tapOn(PluginNode node, String label) {
    Object? search(PluginNode n) {
      final msg = n.events['tap'];
      if (msg != null && texts(n).contains(label)) return msg;
      for (final c in n.children) {
        final hit = search(c);
        if (hit != null) return hit;
      }
      return null;
    }

    return search(node);
  }

  test('the bundle loads and exports what the app calls', () {
    final exports = service.exports(instance);

    expect(exports, containsAll(['open', 'onHook', 'onEvent']));
    expect(service.hasExport(instance, 'onHook'), isTrue);
  });

  /// The manifest and the bundle are two files that have to agree, and only
  /// this test looks at both.
  test('the manifest says what the app needs to place it', () async {
    final decoded = jsonDecode(manifestJson) as Map<String, dynamic>;
    final page = (decoded['contributes'] as Map)['page'] as Map;

    // v3, because it draws `skeleton` and `tile`'s `selected`. Declaring less
    // would let an app that has neither install it and draw "unknown widget"
    // per row — the understating trap the whole axis exists to prevent, and
    // what `every bundled plugin declares an ABI its nodes need` holds.
    expect(decoded['abi'], 3);
    expect(page['id'], 'ports');
    // `needs` is the app's own `availableWith` switch moved into data: the
    // button must not appear on a server that cannot run a command.
    expect(page['needs'], ['shell']);
    expect((decoded['permissions'] as Map).keys, ['server.exec']);
  });

  /// The card on the server detail page — the same reading, in a glance.
  ///
  /// Worth checking through the real host rather than only against the mock:
  /// a card is opened with a different `kind` and hooked with a different
  /// contribution id, and until this plugin grew one nothing had ever asked
  /// the app for that pair.
  group('the card', () {
    test('it is declared where the app looks for it', () {
      final decoded = jsonDecode(manifestJson) as Map<String, dynamic>;
      final card = (decoded['contributes'] as Map)['card'] as Map;

      expect(card['id'], 'summary');
      // Not added to every server's page on install: the plugin already puts a
      // button in the function bar, and one that takes two places by itself is
      // one that decided for the user.
      expect(card['default_on'], isFalse);
    });

    test('it summarises, and names only what is reachable', () async {
      PluginPatch? seen;
      service.bridge.onPatch['inst-ports'] = (p) => seen = p;

      await service.call(
        instance,
        'open',
        jsonEncode({'kind': 'card', 'id': 'summary'}),
      );
      await service.hook(
        instance,
        kind: 'enter',
        contributionId: 'summary',
        granted: const ['server.exec'],
        serverIds: const ['srv-1'],
      );

      final drawn = texts(seen!.node);
      // The scripted output has sshd on 0.0.0.0 and redis on loopback.
      expect(drawn, contains('22'));
      expect(drawn, isNot(contains('6379')));
    });

    /// The detail page hands every card the status refresh interval. This
    /// plugin exports no `tick`, which is how it declines — `ss` on every
    /// server every few seconds is work nobody asked for.
    test('it has nothing for the page to tick', () {
      expect(service.hasExport(instance, 'tick'), isFalse);
    });
  });

  test('open draws immediately and runs nothing', () async {
    final out = await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'ports'}),
    );

    expect(ops.calls, isEmpty);
    // The shape of what is coming rather than a word for it: a page that
    // showed a spinner and then jumped to a full list moves everything the
    // eye had settled on.
    expect(((jsonDecode(out) as Map)['ui'] as Map)['t'], 'skeleton');
  });

  /// The whole point of the hook: the host says which machines, the plugin
  /// decides what to run. Here it is one, and it runs one command.
  test('the hook collects and patches the rows in', () async {
    PluginPatch? seen;
    service.bridge.onPatch['inst-ports'] = (p) => seen = p;

    // The app opens a surface before it hooks it (`PluginSurfaceView`),
    // and a plugin holding its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'ports'}),
    );
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'ports',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );

    expect(ops.calls.single, startsWith('exec:srv-1:'));
    expect(seen, isNotNull);
    expect(seen!.path, isEmpty);

    final drawn = texts(seen!.node);
    // The port is the row's title, so it stands alone. The process shares the
    // subtitle with the protocol and the address — a row carrying only a
    // process name spent a line on "—" whenever reading it needed root.
    expect(drawn, contains('22'));
    expect(drawn, contains('6379'));
    expect(drawn.any((t) => t.contains('sshd')), isTrue);
    // The counts are translated sentences with the number as an argument, so
    // what the tree carries is the key — the app substitutes when it draws.
    expect(drawn.any((t) => t.startsWith('l10n.ports')), isTrue);
    expect(drawn.any((t) => t.startsWith('l10n.exposedCount')), isTrue);
  });

  /// The command the plugin sends is its own, and this is the only place the
  /// app ever sees it. Worth naming, because a plugin's command is the part a
  /// user consented to `server.exec` for.
  test('what it runs is a read-only probe', () async {
    // The app opens a surface before it hooks it (`PluginSurfaceView`),
    // and a plugin holding its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'ports'}),
    );
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'ports',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );

    final script = ops.calls.single;
    expect(script, contains('ss -tulnpH'));
    expect(script, contains('netstat -tulnp'));
    // Nothing that elevates or deletes, and no redirect that lands anywhere
    // but `/dev/null` or the other stream — so nothing it runs writes a file.
    expect(script, isNot(contains('sudo')));
    expect(script, isNot(contains('rm ')));
    for (final redirect in RegExp(r'>\s*([^\s;|&]+|&\d)').allMatches(script)) {
      expect(
        redirect.group(1),
        anyOf('/dev/null', '&1', '&2'),
        reason: 'a probe writes nothing: $script',
      );
    }
  });

  /// Filtering is a decision about a reading already in hand.
  test('the exposed filter answers a tree without going back out', () async {
    // The tree the app is showing, which is where the tap comes from.
    PluginPatch? seen;
    service.bridge.onPatch['inst-ports'] = (p) => seen = p;

    // The app opens a surface before it hooks it (`PluginSurfaceView`),
    // and a plugin holding its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'ports'}),
    );
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'ports',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );
    final before = ops.calls.length;

    // **The message is read off the tree, not written here.** A handler is a
    // closure now, so what crosses is a token the SDK made — a test that wrote
    // `{m: 'exposed'}` would be testing a protocol the plugin no longer
    // speaks, and would pass just as well if nothing on screen sent it.
    final out = await service.call(
      instance,
      'onEvent',
      // One object, because the host calls every export with exactly one
      // argument.
      jsonEncode({'msg': tapOn(seen!.node, 'l10n.filterAll')}),
    );

    expect(ops.calls, hasLength(before));
    final ui = (jsonDecode(out) as Map)['ui'];
    final drawn = texts(nodeOf(jsonEncode(ui)));
    expect(drawn, contains('22'));
    expect(drawn, isNot(contains('6379')));
  });

  /// The runtime installs an ungranted function as a throwing stub, so a
  /// plugin loaded without `server.exec` reaches no machine at all.
  ///
  /// It *can* catch the throw — JavaScript has no uncatchable one — and this
  /// plugin does, drawing its failure view. That is fine and is not what the
  /// permission protects: what it protects is that the app never ran a
  /// command, and the host fails the call afterwards whatever the plugin
  /// answered, so a plugin cannot swallow a refusal and carry on to the next
  /// thing.
  test('without its permission it reaches no machine', () async {
    final bare = await service.load(
      manifestJson: manifestJson,
      source: File('$_dir/dist/plugin.js').readAsStringSync(),
      instanceId: 'inst-bare',
      granted: const [],
      config: const {},
      boundServerId: 'srv-1',
    );
    addTearDown(() => service.unload(bare));

    PluginPatch? seen;
    service.bridge.onPatch['inst-bare'] = (p) => seen = p;

    // The app opens a surface before it hooks it (`PluginSurfaceView`),
    // and a plugin holding its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'ports'}),
    );
    await service.hook(
      bare,
      kind: 'enter',
      contributionId: 'ports',
      granted: const [],
      serverIds: const ['srv-1'],
    );

    // The property that matters: nothing was run.
    expect(ops.calls, isEmpty);
    // And what it drew, if anything, says why rather than showing an empty
    // list — which would read as a machine with nothing listening.
    if (seen != null) {
      expect(texts(seen!.node).join(' '), contains('server.exec'));
    }
    // One refused call is not a dead plugin.
    expect(service.hasExport(bare, 'open'), isTrue);
  });
}
