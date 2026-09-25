/// The Virtualization providers over a scripted `ensureExec()`: host
/// detection, and one host's refresh, busy tracking and sudo prompt.
///
/// Parsing goes through the real FFI: `cargo build -p sbm_ffi` first.
library;

import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart' show SSHClient;
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';
import 'package:server_box/data/provider/virt/virt.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/view/page/virt/console_connect.dart';

import '../../helpers/rust_lib_helper.dart';

const _dir = 'crates/sbm_parser/tests/fixtures/virt';

String _fixture(String name) => File('$_dir/$name').readAsStringSync();

String _section(String key, String body, [int rc = 0]) =>
    '${script.scriptSegmentMarker(key: key, custom: false)}\n$body\nSbVirtRc=$rc\n';

String _overview() => [
  _section('virt.version', _fixture('version_libvirt11.txt')),
  _section('virt.list', _fixture('list_uuid_name.txt')),
  _section('virt.autostart', _fixture('list_autostart.txt')),
  _section('virt.persistent', _fixture('list_persistent.txt')),
  _section('virt.stats', _fixture('domstats.txt')),
].join();

const _run = '8a2ed2a2-83e1-4c41-ad0a-a57d54d0d649'; // cirros-run

Spi _spi(String id) =>
    Spi(id: id, name: id, ssh: const SshCredential(ip: '10.0.0.1'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    await initRustLibForTest();
    tempDir = await Directory.systemTemp.createTemp('sbm-virt-provider-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  ProviderContainer container(
    Map<String, _Exec> execs, {
    Map<String, ServerConn> conns = const {},
  }) {
    final c = ProviderContainer(
      overrides: [
        for (final MapEntry(:key, :value) in execs.entries)
          serverProvider(key).overrideWith(
            () => _FakeServer(value, conn: conns[key] ?? ServerConn.connected),
          ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('hosts: PVE by its row, libvirt by probing, the rest aside', () async {
    for (final id in ['pve', 'kvm', 'plain']) {
      Stores.server.put(_spi(id));
    }
    Stores.pve.put('pve', const PveConfig(addr: 'https://localhost:8006'));
    final pveExec = _Exec((_) => fail('a PVE host is not probed'));
    final c = container({
      'pve': pveExec,
      'kvm': _Exec(
        (_) => _ok(_section('virt.version', _fixture('version_libvirt11.txt'))),
      ),
      'plain': _Exec(
        (_) => _ok(
          '${script.scriptSegmentMarker(key: 'virt.missing', custom: false)}\n',
        ),
      ),
    });
    final sub = c.listen(virtHostsProvider, (_, _) {});
    addTearDown(sub.close);

    var hosts = c.read(virtHostsProvider);
    expect(hosts.hosts, {'pve': VirtHostKind.pve});
    expect(hosts.others, unorderedEquals(['kvm', 'plain']));

    await c.read(virtHostsProvider.notifier).probeAll();
    hosts = c.read(virtHostsProvider);
    expect(hosts.hosts, {'pve': VirtHostKind.pve, 'kvm': VirtHostKind.libvirt});
    expect(hosts.others, ['plain']);
    expect(hosts.probes['kvm']?.version, '11.3.0');
    expect(hosts.probes['plain']?.status, VirtProbeStatus.absent);
    expect(pveExec.calls, isEmpty);
  });

  test('a host: loads, tracks an action in flight, refreshes after', () async {
    Stores.server.put(_spi('kvm'));
    final gate = Completer<void>();
    final exec = _Exec((call) async {
      if (call.script.contains('V shutdown')) {
        await gate.future;
        return _ok(_section('virt.action', "Domain 'cirros-run' is being shutdown"));
      }
      return _ok(_overview());
    });
    final c = container({'kvm': exec});
    final provider = virtHostProvider('kvm');
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await _until(() => c.read(provider).data != null);
    final state = c.read(provider);
    expect(state.kind, VirtHostKind.libvirt);
    expect(state.error, isNull);
    expect(state.samples[_run], hasLength(1));

    final notifier = c.read(provider.notifier);
    final action = notifier.power(_run, VirtPowerAction.shutdown);
    await _until(() => c.read(provider).busy.isNotEmpty);
    final busy = c.read(provider);
    final web = busy.guest(_run)!;
    expect(busy.displayState(web), VirtGuestState.stopping);
    // Only the way out of a shutdown the guest may ignore.
    expect(busy.actionsOf(web), {VirtPowerAction.forceStop});
    await expectLater(
      notifier.power(_run, VirtPowerAction.reboot),
      throwsA(
        isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unsupported),
      ),
    );

    gate.complete();
    await action;
    expect(c.read(provider).busy, isEmpty);
    await _until(() => c.read(provider).samples[_run]!.length >= 2);
  });

  test('force stop takes over from a shutdown still waiting', () async {
    Stores.server.put(_spi('kvm'));
    final shutdownGate = Completer<void>();
    final exec = _Exec((call) async {
      if (call.script.contains('V shutdown')) {
        await shutdownGate.future;
        // What the aborted shutdown answers once the stop has run.
        return _ok(
          _section('virt.action', 'error: domain is not running', 1),
        );
      }
      if (call.script.contains('V destroy')) {
        return _ok(_section('virt.action', "Domain 'cirros-run' destroyed"));
      }
      return _ok(_overview());
    });
    final c = container({'kvm': exec});
    final provider = virtHostProvider('kvm');
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await _until(() => c.read(provider).data != null);

    final notifier = c.read(provider.notifier);
    final shutdown = notifier.power(_run, VirtPowerAction.shutdown);
    await _until(() => c.read(provider).busy.isNotEmpty);
    // Nothing else may overrule it.
    await expectLater(
      notifier.power(_run, VirtPowerAction.suspend),
      throwsA(isA<VirtErr>()),
    );

    await notifier.power(_run, VirtPowerAction.forceStop);
    expect(c.read(provider).busy, isEmpty);

    // The shutdown's own failure, once it comes back, is not reported: it
    // was overruled on purpose. Nor does it take anything off the state.
    shutdownGate.complete();
    await shutdown;
    expect(c.read(provider).busy, isEmpty);
  });

  test('a refresh asked for during another waits for its own run', () async {
    Stores.server.put(_spi('kvm'));
    var gate = Completer<void>();
    var loads = 0;
    final exec = _Exec((call) async {
      loads++;
      await gate.future;
      return _ok(_overview());
    });
    final c = container({'kvm': exec});
    final provider = virtHostProvider('kvm');
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await _until(() => loads == 1);

    // Asked while the first load is in flight: done only after a second one,
    // which reads the host as it is after the ask.
    var done = false;
    final asked = c.read(provider.notifier).refresh().whenComplete(
      () => done = true,
    );
    final first = gate;
    gate = Completer<void>();
    first.complete();
    await _until(() => loads == 2);
    expect(done, isFalse);
    gate.complete();
    await asked;
    expect(c.read(provider).data, isNotNull);
    expect(c.read(provider).samples[_run], hasLength(2));
  });

  test('a snapshot operation: one per guest, power included; lists follow',
      () async {
    Stores.server.put(_spi('kvm'));
    final gate = Completer<void>();
    final exec = _Exec((call) async {
      if (call.script.contains('V snapshot-create-as')) {
        await gate.future;
        return _ok(_section('virt.action', 'Domain snapshot snap-1 created'));
      }
      if (call.script.contains('snapshot-list')) {
        return _ok(_fixture('script_snapshots_cirros_run.txt'));
      }
      if (call.script.contains('net-list')) {
        return _ok(_fixture('script_networks.txt'));
      }
      return _ok(_overview());
    });
    final c = container({'kvm': exec});
    final provider = virtHostProvider('kvm');
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await _until(() => c.read(provider).data != null);

    final snaps = await c.read(virtSnapshotsProvider('kvm', _run).future);
    expect(snaps.map((s) => s.name), ['sbx-a', 'sbx-b', 'sbx-off']);
    final nets = await c.read(virtNetworksProvider('kvm').future);
    expect(nets.first.name, 'default');

    final notifier = c.read(provider.notifier);
    final create = notifier.createSnapshot(_run, name: 'snap-1');
    await _until(() => c.read(provider).snapshotOps.isNotEmpty);
    final st = c.read(provider);
    expect(st.snapshotOps[_run], VirtSnapshotOp.create);
    expect(st.isBusy(_run), isTrue);
    expect(st.actionsOf(st.guest(_run)!), isEmpty);
    for (final second in [
      () => notifier.power(_run, VirtPowerAction.reboot),
      () => notifier.deleteSnapshot(_run, 'sbx-a'),
    ]) {
      await expectLater(
        second(),
        throwsA(
          isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unsupported),
        ),
      );
    }

    gate.complete();
    await create;
    expect(c.read(provider).snapshotOps, isEmpty);
  });

  group('what is probed without being asked', () {
    Spi spi({bool autoConnect = true}) => Spi(
      id: 's',
      name: 's',
      ssh: const SshCredential(ip: '10.0.0.1'),
      autoConnect: autoConnect,
    );
    ServerState st(ServerConn conn) =>
        ServerState(spi: spi(), status: InitStatus.status, conn: conn);

    test('connected or connecting: yes', () {
      for (final conn in [
        ServerConn.connecting,
        ServerConn.connected,
        ServerConn.loading,
        ServerConn.finished,
      ]) {
        expect(
          VirtHosts.autoProbeable(
            spi(autoConnect: false),
            st(conn),
            manuallyDisconnected: false,
          ),
          isTrue,
          reason: conn.name,
        );
      }
    });

    test('disconnected: only when the server list connects it anyway', () {
      final off = st(ServerConn.disconnected);
      expect(
        VirtHosts.autoProbeable(spi(), off, manuallyDisconnected: false),
        isTrue,
      );
      expect(
        VirtHosts.autoProbeable(
          spi(autoConnect: false),
          off,
          manuallyDisconnected: false,
        ),
        isFalse,
      );
    });

    test('failed, or disconnected by hand: no', () {
      expect(
        VirtHosts.autoProbeable(
          spi(),
          st(ServerConn.failed),
          manuallyDisconnected: false,
        ),
        isFalse,
      );
      expect(
        VirtHosts.autoProbeable(
          spi(),
          st(ServerConn.finished),
          manuallyDisconnected: true,
        ),
        isFalse,
      );
    });

    test('the first listing probes only those; "Check all" probes the rest', () async {
      Stores.server.put(_spi('up'));
      Stores.server.put(
        Spi(
          id: 'closed',
          name: 'closed',
          ssh: const SshCredential(ip: '10.0.0.2'),
          autoConnect: false,
        ),
      );
      final version = _section('virt.version', _fixture('version_libvirt11.txt'));
      final up = _Exec((_) => _ok(version));
      final closed = _Exec((_) => _ok(version));
      final c = container(
        {'up': up, 'closed': closed},
        conns: {'closed': ServerConn.disconnected},
      );
      final sub = c.listen(virtHostsProvider, (_, _) {});
      addTearDown(sub.close);
      final hosts = c.read(virtHostsProvider.notifier);

      await hosts.probeAll(onlyConnected: true);
      expect(up.calls, hasLength(1));
      expect(closed.calls, isEmpty, reason: 'autoConnect off, not connected');
      expect(c.read(virtHostsProvider).others, ['closed']);

      await hosts.refresh();
      expect(closed.calls, hasLength(1));
      expect(c.read(virtHostsProvider).hosts.keys, containsAll(['up', 'closed']));
    });
  });

  test('a console opened on a host not built yet loads it once', () async {
    Stores.server.put(_spi('kvm'));
    final exec = _Exec((_) => _ok(_overview()));
    final c = container({'kvm': exec});
    // Every exec is the overview script: one per load.
    int loads() => exec.calls.length;

    // Nothing watches the host: this call is what builds it, and building it
    // starts a load. Asking for a second on top of it was two full loads per
    // console opened.
    final name = await VirtConsoleConnect.withHost(
      c,
      'kvm',
      _run,
      (host) async => c.read(virtHostProvider('kvm')).guest(_run)?.name,
    );
    expect(name, 'cirros-run');
    expect(loads(), 1);

    // A guest the loaded host does not have is worth one more load.
    final sub = c.listen(virtHostProvider('kvm'), (_, _) {});
    addTearDown(sub.close);
    await VirtConsoleConnect.withHost(c, 'kvm', 'no-such-guest', (_) async {});
    expect(loads(), 2);
  });

  group('the backend follows the PVE row', () {
    test('gaining one makes a PVE host, losing it a libvirt one', () async {
      Stores.server.put(_spi('kvm'));
      final c = container({'kvm': _Exec((_) => _ok(_overview()))});
      final provider = virtHostProvider('kvm');
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final hostsSub = c.listen(virtHostsProvider, (_, _) {});
      addTearDown(hostsSub.close);

      expect(c.read(provider).kind, VirtHostKind.libvirt);

      Stores.pve.put('kvm', const PveConfig(addr: 'https://127.0.0.1:1'));
      await _until(() => c.read(provider).kind == VirtHostKind.pve);
      expect(c.read(provider.notifier).backend.kind, VirtHostKind.pve);
      expect(c.read(virtHostsProvider).hosts['kvm'], VirtHostKind.pve);

      Stores.pve.remove('kvm');
      await _until(() => c.read(provider).kind == VirtHostKind.libvirt);
      expect(c.read(virtHostsProvider).hosts['kvm'], isNot(VirtHostKind.pve));
    });

    test('an edit reaches the running backend without a rebuild', () async {
      Stores.server.put(_spi('pve'));
      Stores.pve.put('pve', const PveConfig(addr: 'https://127.0.0.1:1'));
      final c = container({'pve': _Exec((_) => fail('not probed'))});
      final provider = virtHostProvider('pve');
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final backend = c.read(provider.notifier).backend as PveBackend;

      const edited = PveConfig(
        addr: 'https://127.0.0.1:1',
        auth: PveAuth.token,
        tokenId: 'root@pam!sb',
        tokenSecret: 's',
      );
      Stores.pve.put('pve', edited);
      await _until(() => backend.config == edited);
      expect(identical(c.read(provider.notifier).backend, backend), isTrue);
    });
  });

  test('a server that is gone is not "not configured"', () async {
    final c = container({});
    final sub = c.listen(virtHostProvider('gone'), (_, _) {});
    addTearDown(sub.close);
    final st = c.read(virtHostProvider('gone'));
    expect(st.error?.type, VirtErrType.serverRemoved);
    expect(st.kind, isNull);
    // Nothing to do for it; a refresh asks nobody.
    await c.read(virtHostProvider('gone').notifier).refresh();
    expect(c.read(virtHostProvider('gone')).error?.type, VirtErrType.serverRemoved);
  });

  test('a host that needs a sudo password waits for it', () async {
    Stores.server.put(_spi('kvm'));
    final refused = [
      for (final key in [
        'virt.version',
        'virt.list',
        'virt.autostart',
        'virt.persistent',
        'virt.stats',
      ])
        _section(key, _fixture('error_permission.txt'), 1),
    ].join();
    final exec = _Exec((call) {
      if (call.entry == 'sh') return _ok(refused);
      if (call.entry == 'sudo -n sh') {
        return _fail('sudo: a password is required\n');
      }
      return _ok(_overview());
    });
    final c = container({'kvm': exec});
    final provider = virtHostProvider('kvm');
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await _until(() => c.read(provider).error != null);
    expect(c.read(provider).error!.type, VirtErrType.sudoPasswordRequired);
    expect(c.read(provider).error!.needsInput, isTrue);

    // The timer's refresh does not repeat the refused question.
    final before = exec.calls.length;
    await c.read(provider.notifier).refresh(auto: true);
    expect(exec.calls.length, before);

    await c.read(provider.notifier).provideSudoPassword('pw');
    expect(c.read(provider).error, isNull);
    expect(c.read(provider).data?.guests, hasLength(3));
    expect(exec.calls.last.stdin, 'pw\n');
  });
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

ExecResult _ok(String stdout) =>
    ExecResult(exitCode: 0, stdout: stdout, stderr: '');

ExecResult _fail(String stderr) =>
    ExecResult(exitCode: 1, stdout: '', stderr: stderr);

typedef _Call = ({String script, String? entry, String? stdin});

class _Exec implements ServerExec {
  _Exec(this.answer);

  final FutureOr<ExecResult> Function(_Call call) answer;
  final calls = <_Call>[];

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
    final call = (script: script, entry: entry, stdin: stdin);
    calls.add(call);
    final result = await answer(call);
    if (result.stderr.isNotEmpty) onStderr?.call(result.stderr);
    return result;
  }
}

class _FakeServer extends ServerNotifier {
  _FakeServer(this.exec, {this.conn = ServerConn.connected});

  final ServerExec exec;
  final ServerConn conn;

  @override
  ServerState build(String serverId) =>
      ServerState(spi: _spi(serverId), status: InitStatus.status, conn: conn);

  @override
  Future<ServerExec> ensureExec({VoidCallback? onSshDial}) async => exec;

  /// No network in these tests: a PVE backend dials through this.
  @override
  Future<SSHClient> ensureShellClient({VoidCallback? onDial}) async =>
      throw StateError('no network in this test');
}
