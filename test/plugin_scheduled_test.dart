/// The scheduled-tasks plugin on the real host — the first one here that
/// changes a machine.
///
/// Its own tests against `MockHost` live beside it. This is where the write is
/// looked at through the app's own `sb.*`: what is sent, that nothing is sent
/// until the user says yes, and that a refusal is told apart from a failure.
///
/// Build the bundle first: cd packages/plugins/scheduled && bun run build
/// Build the native library first too: cargo build -p sbm_ffi
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';

import 'helpers/plugin_host_ops.dart';
import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

const _dir = 'packages/plugins/scheduled';

const _read = '''
cron
MAILTO=root
0 3 * * * /opt/backup.sh
cronsum
2917190459 218
hascron
yes
timers
Mon 2026-09-08 06:00:00 UTC 8h left Sun 2026-09-07 06:00:00 UTC 15h ago logrotate.timer logrotate.service
''';

void main() {
  setUpAll(initRustLibForTest);

  late FakePluginHostOps ops;
  late PluginRuntimeService service;
  late BigInt instance;
  late List<PluginPatch> patches;

  setUp(() async {
    await openTestDb();
    SqliteDb.instance.execute(
      "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-1', 'one', '10.0.0.1');",
    );
    patches = [];
    ops = FakePluginHostOps()
      ..execResult = (code: 0, stdout: _read, stderr: '');
    service = PluginRuntimeService(
      bridge: PluginBridge(ops: ops, handles: PluginServerHandles()),
    );
    await service.start();
    instance = await service.load(
      manifestJson: File('$_dir/manifest.json').readAsStringSync(),
      source: File('$_dir/dist/plugin.js').readAsStringSync(),
      instanceId: 'inst-sched',
      granted: const ['server.exec', 'ui.dialog'],
      config: const {},
      boundServerId: 'srv-1',
    );
    service.bridge.onPatch['inst-sched'] = patches.add;
  });

  tearDown(() async {
    await service.unload(instance);
    service.dispose();
    await closeTestDb();
  });

  List<String> words(PluginNode node) {
    final out = <String>[];
    void walk(PluginNode n) {
      for (final prop in const ['value', 'label']) {
        final v = n.props[prop];
        if (v is String) out.add(v);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(node);
    return out;
  }

  Future<void> enter() => service.hook(
    instance,
    kind: 'enter',
    contributionId: 'scheduled',
    granted: const ['server.exec', 'ui.dialog'],
    serverIds: const ['srv-1'],
  );

  test('it reads cron and the timers in one command', () async {
    await enter();

    expect(ops.calls, hasLength(1));
    final script = ops.calls.single;
    expect(script, contains('crontab -l'));
    expect(script, contains('systemctl list-timers'));
    // The fingerprint the next write will have to match, read in the same
    // command as the file it describes.
    expect(script, contains('cksum'));

    final drawn = words(patches.last.node);
    expect(drawn, contains('/opt/backup.sh'));
    expect(drawn, contains('logrotate.timer'));
  });

  /// A change to a machine is asked about before it happens, and nothing is
  /// sent until the answer comes back.
  test('nothing is written until the user says yes', () async {
    await enter();
    ops.calls.clear();
    // `FakePluginHostOps.prompt` answers `cancelled: false`, so this is the
    // "yes" path; the "no" path is covered against MockHost, which can script
    // a refusal.
    await service.call(
      instance,
      'onEvent',
      jsonEncode({'m': 'toggle', 'line': 1}),
    );

    expect(ops.calls.where((c) => c.startsWith('prompt:')), hasLength(1));
    // The prompt came first.
    expect(ops.calls.first, startsWith('prompt:'));
  });

  /// The property this plugin exists to demonstrate: a crontab is the only
  /// copy, so the write says what it believed it was replacing.
  test('the write is compare-and-swap over the whole file', () async {
    await enter();
    ops.calls.clear();
    await service.call(
      instance,
      'onEvent',
      jsonEncode({'m': 'toggle', 'line': 1}),
    );

    final write = ops.calls.firstWhere((c) => c.contains('crontab -'));
    // The fingerprint it read.
    expect(write, contains("!= '2917190459 218'"));
    expect(write, contains("printf 'conflict"));
    // The whole file, quoted as one word — a crontab cannot be edited a line
    // at a time.
    expect(write, contains("'MAILTO=root\n#0 3 * * * /opt/backup.sh'"));
    expect(write, contains('| crontab -'));
  });

  /// Reload, not retry. Writing anyway is what would lose somebody's change.
  test('a refusal is told apart from a failure', () async {
    await enter();
    ops.calls.clear();
    ops.execResult = (code: 0, stdout: 'conflict\n', stderr: '');

    await service.call(
      instance,
      'onEvent',
      jsonEncode({'m': 'toggle', 'line': 1}),
    );

    // The write, then a read — never a second write against a fingerprint
    // already known to be stale.
    final execs = ops.calls.where((c) => c.startsWith('exec:')).toList();
    expect(execs, hasLength(2));
    expect(execs[0], contains('| crontab -'));
    expect(execs[1], contains('systemctl list-timers'));
    expect(
      patches.any((p) => words(p.node).any((t) => t.contains('changed on the server'))),
      isTrue,
    );
  });
}
