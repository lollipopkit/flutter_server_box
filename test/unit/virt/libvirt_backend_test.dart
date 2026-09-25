/// `LibvirtBackend` over a scripted `ServerExec` that answers with the
/// `sbm_parser` virt fixtures: mapping, rates across two samples, the sudo
/// retry, and a server without virsh.
///
/// Parsing goes through the real FFI: `cargo build -p sbm_ffi` first.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/src/rust/api/script.dart' as script;

import '../../helpers/rust_lib_helper.dart';

const _dir = 'crates/sbm_parser/tests/fixtures/virt';

String _fixture(String name) => File('$_dir/$name').readAsStringSync();

String _marker(String key) =>
    script.scriptSegmentMarker(key: key, custom: false);

/// One `virsh` call's section, as the scripts print it.
String _section(String key, String body, [int rc = 0]) =>
    '${_marker(key)}\n$body\nSbVirtRc=$rc\n';

String _overview({String? domstats}) => [
  _section('virt.version', _fixture('version_libvirt11.txt')),
  _section('virt.list', _fixture('list_uuid_name.txt')),
  _section('virt.autostart', _fixture('list_autostart.txt')),
  _section('virt.persistent', _fixture('list_persistent.txt')),
  _section('virt.stats', domstats ?? _fixture('domstats.txt')),
].join();

/// Every call refused, as a user outside the `libvirt` group sees it.
String _refused() {
  final e = _fixture('error_permission.txt');
  return [
    for (final key in [
      'virt.version',
      'virt.list',
      'virt.autostart',
      'virt.persistent',
      'virt.stats',
    ])
      _section(key, e, 1),
  ].join();
}

// Guests in the captured fixtures (libvirt 11.3.0).
const _run = '8a2ed2a2-83e1-4c41-ad0a-a57d54d0d649'; // cirros-run
const _paused = '24a8bbc6-deaa-4be0-9699-a1d801faa927'; // cirros-paused
const _odd = '1438b9e3-f647-47ee-8ed2-6dbc3adccd68'; // it's-"odd"

void main() {
  setUpAll(initRustLibForTest);

  test('the overview maps to guests, states and actions', () async {
    final exec = _Exec((call) => _ok(_overview()));
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    final snap = await virt.load();

    expect(snap.host.kind, VirtHostKind.libvirt);
    expect(snap.host.version, '11.3.0');
    expect(snap.host.hypervisor, 'QEMU 10.0.13');
    expect(snap.capabilities.lxc, isFalse);
    expect(snap.capabilities.pause, isTrue);
    expect(snap.guests, hasLength(3));

    final web = snap.guests.firstWhere((g) => g.id == _run);
    expect(web.name, 'cirros-run');
    expect(web.state, VirtGuestState.running);
    expect(web.vcpu, 2);
    expect(web.memBytes, 262144 * 1024);
    expect(web.autostart, isTrue);
    expect(web.actions, {
      VirtPowerAction.shutdown,
      VirtPowerAction.reboot,
      VirtPowerAction.forceStop,
      VirtPowerAction.suspend,
    });

    final db = snap.guests.firstWhere((g) => g.id == _paused);
    expect(db.state, VirtGuestState.paused);
    expect(db.actions, {VirtPowerAction.resume, VirtPowerAction.forceStop});

    final odd = snap.guests.firstWhere((g) => g.id == _odd);
    expect(odd.state, VirtGuestState.stopped);
    expect(odd.stateReason, 'failed');
    expect(odd.actions, {VirtPowerAction.start});

    // Every script goes to `sh` on stdin, never to the login shell.
    expect(exec.calls.map((c) => c.entry), everyElement('sh'));
  });

  test('rates across two samples', () async {
    var now = DateTime(2026, 1, 1);
    var stats = _fixture('domstats.txt');
    final exec = _Exec((call) => _ok(_overview(domstats: stats)));
    final virt = LibvirtBackend(
      serverId: 's',
      exec: () async => exec,
      now: () => now,
    );
    final first = await virt.load();
    expect(first.stats[_run]!.cpu, isNull, reason: 'nothing to diff');
    expect(first.stats[_run]!.memUsed, (198384 - 151264) * 1024);

    now = now.add(const Duration(seconds: 2));
    stats = stats
        // +2 s of CPU over 2 s on 2 vCPUs: 50 %.
        .replaceFirst('cpu.time=7550532000', 'cpu.time=9550532000')
        .replaceFirst(
          'block.0.rd.bytes=26923008',
          'block.0.rd.bytes=28923008',
        )
        .replaceFirst('net.0.rx.bytes=13386', 'net.0.rx.bytes=23386');
    final second = await virt.load();
    final web = second.stats[_run]!;
    expect(web.cpu, closeTo(50, 1e-9));
    expect(web.diskRead, 1e6);
    expect(web.diskWrite, 0);
    expect(web.netIn, 5000);
    expect(web.netOut, 0);
  });

  group('permission', () {
    test('refused, then passwordless sudo: later calls go straight to sudo',
        () async {
      final exec = _Exec((call) {
        if (call.entry == 'sh') return _ok(_refused());
        if (call.entry == 'sudo -n sh' && call.script == 'true') return _ok('');
        if (call.entry == 'sudo -n sh') return _ok(_overview());
        return _fail('unexpected $call');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      expect((await virt.load()).guests, hasLength(3));
      expect(exec.calls.map((c) => c.entry), [
        'sh',
        'sudo -n sh',
        'sudo -n sh',
      ]);
      expect(virt.needsSudo, isTrue);

      exec.calls.clear();
      await virt.load();
      expect(exec.calls.map((c) => c.entry), ['sudo -n sh', 'sudo -n sh']);

      final console = await virt.console(
        (await virt.load()).guests.first,
        VirtConsoleKind.text,
      );
      expect((console as LibvirtSerialConsole).needsRoot, isTrue);
    });

    test('sudo wants a password: asked for, sent on stdin only', () async {
      const password = 'hunter2';
      final exec = _Exec((call) {
        if (call.entry == 'sh') return _ok(_refused());
        if (call.entry == 'sudo -n sh') {
          return _fail('sudo: a password is required\n');
        }
        if (call.entry == "sudo -S -p '' sh") {
          if (call.stdin != '$password\n') {
            return _fail('Sorry, try again.\n');
          }
          return _ok(_overview());
        }
        return _fail('unexpected $call');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      expect(
        (await _err(virt.load())).type,
        VirtErrType.sudoPasswordRequired,
      );

      virt.provideSudoPassword('wrong');
      expect(
        (await _err(virt.load())).type,
        VirtErrType.sudoPasswordRejected,
      );
      // A rejected password is forgotten.
      expect(
        (await _err(virt.load())).type,
        VirtErrType.sudoPasswordRequired,
      );

      virt.provideSudoPassword(password);
      expect((await virt.load()).guests, hasLength(3));
      for (final call in exec.calls) {
        expect(call.script, isNot(contains(password)));
        expect(call.entry, isNot(contains(password)));
      }
    });

    test('no sudo at all is permissionDenied with virsh\'s words', () async {
      final exec = _Exec((call) {
        if (call.entry == 'sh') return _ok(_refused());
        return ExecResult(
          exitCode: 127,
          stdout: '',
          stderr: 'sh: 1: sudo: not found\n',
        );
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(virt.load());
      expect(e.type, VirtErrType.permissionDenied);
      expect(e.message, contains('Permission denied'));
      expect(e.message, contains('sudo: not found'));
    });
  });

  test('no virsh is notInstalled, for the probe and the overview', () async {
    final exec = _Exec((call) => _ok('${_marker('virt.missing')}\n'));
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    expect((await _err(virt.probe())).type, VirtErrType.notInstalled);
    expect((await _err(virt.load())).type, VirtErrType.notInstalled);
  });

  test('the probe reads the version', () async {
    final exec = _Exec(
      (call) => _ok(_section('virt.version', _fixture('version_libvirt12.txt'))),
    );
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    expect((await virt.probe()).libvirt, '12.0.0');
  });

  test('a transport failure is unreachable', () async {
    final virt = LibvirtBackend(
      serverId: 's',
      exec: () async => throw const SocketException('down'),
    );
    expect((await _err(virt.load())).type, VirtErrType.unreachable);
  });

  // Found against a real agent with `full_access` off: the tab said the host
  // could not be reached, when the agent had answered and refused.
  test('an agent that will not run commands is execNotGranted', () async {
    final exec = _Exec(
      (_) => throw const MonitorHttpErr(
        type: MonitorHttpErrType.notGranted,
        message: 'full access is off',
      ),
    );
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    final e = await _err(virt.load());
    expect(e.type, VirtErrType.execNotGranted);
    expect(e.solution, isNotNull, reason: 'says where the switch is');
    // Not retried through sudo: the agent refused before any shell ran.
    expect(exec.calls, hasLength(1));
    expect(virt.needsSudo, isFalse);
  });

  group('states the mapped state hides', () {
    LibvirtDomain domain(int code, String state) => LibvirtDomain(
      uuid: _odd,
      name: 'x',
      state: state,
      stateCode: code,
    );

    test('pmsuspended is paused without resume', () {
      final g = LibvirtBackend.guestOf(domain(7, 'paused'));
      expect(g.state, VirtGuestState.paused);
      expect(g.stateReason, 'pmsuspended');
      expect(g.actions, {VirtPowerAction.forceStop});
    });

    test('crashed and preserved: start destroys it first', () async {
      final crashed = _fixture('domstats.txt').replaceFirst(
        '  state.state=5\n  state.reason=6',
        '  state.state=6\n  state.reason=1',
      );
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) {
          return _ok(_overview(domstats: crashed));
        }
        return _ok(_section('virt.action', 'Domain done'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final odd = (await virt.load()).guests.firstWhere((g) => g.id == _odd);
      expect(odd.state, VirtGuestState.stopped);
      expect(odd.stateReason, 'crashed');
      expect(odd.actions, {VirtPowerAction.start, VirtPowerAction.forceStop});

      exec.calls.clear();
      await virt.power(odd, VirtPowerAction.start);
      expect(exec.calls, hasLength(2));
      expect(exec.calls.first.script, contains('V destroy --domain'));
      expect(exec.calls.last.script, contains('V start --domain'));
    });

    test('migration shows as migrating and offers nothing', () {
      final g = LibvirtBackend.guestOf(
        const LibvirtDomain(
          uuid: _odd,
          name: 'x',
          state: 'paused',
          stateCode: 3,
          reasonCode: 2,
        ),
      );
      expect(g.state, VirtGuestState.migrating);
      expect(g.actions, isEmpty);
    });
  });

  test('a refused action is actionFailed with virsh\'s text', () async {
    final exec = _Exec((call) {
      if (call.script.contains('domstats')) return _ok(_overview());
      return _ok(
        _section('virt.action', _fixture('error_already_active.txt'), 1),
      );
    });
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
    final e = await _err(virt.power(web, VirtPowerAction.shutdown));
    expect(e.type, VirtErrType.actionFailed);
    expect(e.message, isNotEmpty);
  });

  test('detail and the VNC console', () async {
    final exec = _Exec((call) {
      if (call.script.contains('domstats')) return _ok(_overview());
      return _ok(
        _section('virt.display', _fixture('domdisplay_cirros_run.txt')) +
            _section('virt.xml', _fixture('dumpxml_cirros_run.xml')),
      );
    });
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
    final detail = await virt.detail(web);
    expect(detail.disks, isNotEmpty);
    expect(detail.nics, isNotEmpty);
    expect(detail.display?.protocol, 'vnc');
    expect(detail.consoles, contains(VirtConsoleKind.vnc));
    expect(exec.calls.last.script, contains(_run));

    final vnc = await virt.console(web, VirtConsoleKind.vnc);
    expect(vnc, isA<LibvirtVncConsole>());
    expect((vnc as LibvirtVncConsole).port, 5900);
    expect(vnc.host, '127.0.0.1');
  });
}

Future<VirtErr> _err(Future<Object?> future) async {
  try {
    await future;
  } on VirtErr catch (e) {
    return e;
  }
  fail('expected a VirtErr');
}

ExecResult _ok(String stdout) =>
    ExecResult(exitCode: 0, stdout: stdout, stderr: '');

ExecResult _fail(String stderr) =>
    ExecResult(exitCode: 1, stdout: '', stderr: stderr);

typedef _Call = ({String script, String? entry, String? stdin});

class _Exec implements ServerExec {
  _Exec(this.answer);

  final ExecResult Function(_Call call) answer;
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
    final result = answer(call);
    if (result.stdout.isNotEmpty) onStdout?.call(result.stdout);
    if (result.stderr.isNotEmpty) onStderr?.call(result.stderr);
    return result;
  }
}
