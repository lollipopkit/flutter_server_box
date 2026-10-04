/// `LibvirtBackend` over a scripted `ServerExec` that answers with the
/// `sbm_virt` libvirt fixtures: mapping, rates across two samples, the sudo
/// retry, a server without virsh, and snapshots, storage, networks and
/// hardware against the captured script outputs.
///
/// Parsing goes through the real FFI: `cargo build -p sbm_ffi` first.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/src/rust/api/virt.dart'
    show parseVirtHardwareJson, virtUploadGoLine, virtUploadReadyMarker;

import '../../helpers/rust_lib_helper.dart';

const _dir = 'crates/sbm_virt/tests/fixtures/libvirt';

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
      // The refused overview, sudo's check, the overview again; then the
      // pool types (read once), after sudo's check as every call.
      expect(exec.calls.map((c) => c.entry), [
        'sh',
        'sudo -n sh',
        'sudo -n sh',
        'sudo -n sh',
        'sudo -n sh',
      ]);
      expect(exec.calls.last.script, contains('pool-capabilities'));
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

    test('a password already known for the server is used without asking',
        () async {
      const password = 'hunter2';
      final exec = _Exec((call) {
        if (call.entry == 'sh') return _ok(_refused());
        if (call.entry == 'sudo -n sh') {
          return _fail('sudo: a password is required\n');
        }
        if (call.entry == "sudo -S -p '' sh") {
          if (call.stdin != '$password\n') return _fail('Sorry, try again.\n');
          return _ok(_overview());
        }
        return _fail('unexpected $call');
      });
      var reads = 0;
      final virt = LibvirtBackend(
        serverId: 's',
        exec: () async => exec,
        // One typed for this server elsewhere this session.
        knownSudoPassword: () async {
          reads++;
          return password;
        },
      );
      expect((await virt.load()).guests, hasLength(3));
      await virt.load();
      expect(reads, 1, reason: 'read once, not on every call');

      // A known one sudo refuses is forgotten where it is kept, and asked for.
      var forgotten = 0;
      final wrong = LibvirtBackend(
        serverId: 's',
        exec: () async => exec,
        knownSudoPassword: () async => 'stale',
        onSudoRejected: () => forgotten++,
      );
      expect((await _err(wrong.load())).type, VirtErrType.sudoPasswordRejected);
      expect(forgotten, 1);
      expect((await _err(wrong.load())).type, VirtErrType.sudoPasswordRequired);
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

  test('no virsh: the probe says so, the overview is notInstalled', () async {
    final exec = _Exec((call) => _ok('${_marker('virt.missing')}\n'));
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    expect(await virt.probe(), const VirtHostProbeResult());
    expect((await _err(virt.load())).type, VirtErrType.notInstalled);
  });

  test('the probe reads the version', () async {
    final exec = _Exec(
      (call) => _ok(_section('virt.version', _fixture('version_libvirt12.txt'))),
    );
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    expect((await virt.probe()).libvirt?.libvirt, '12.0.0');
  });

  test('the probe finds PVE, and a container', () async {
    var out = '${_marker('virt.pve')}\npve-manager/9.2.2/b9984c6d90a4bd80\n';
    final exec = _Exec((call) => _ok(out));
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    expect(
      await virt.probe(),
      const VirtHostProbeResult(pve: 'pve-manager/9.2.2/b9984c6d90a4bd80'),
    );
    out = '${_marker('virt.container')}\nnone\n\nLXC\n'
        '${_marker('virt.missing')}\n';
    expect(await virt.probe(), const VirtHostProbeResult(container: 'lxc'));
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

  // pmsuspended and migration are `sbm_virt`'s mapping:
  // crates/sbm_virt/tests/libvirt.rs (`host`).
  group('states the mapped state hides', () {
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
    // What `--security-info` adds to the same document; a made-up password.
    final secured = _fixture(
      'dumpxml_cirros_run.xml',
    ).replaceFirst("<graphics type='vnc'", "<graphics type='vnc' passwd='fake-pw1'");
    var secureRefused = false;
    final exec = _Exec((call) {
      if (call.script.contains('domstats')) return _ok(_overview());
      if (call.script.contains('--security-info')) {
        return _ok(
          _section('virt.display', _fixture('domdisplay_cirros_run.txt')) +
              (secureRefused
                  ? _section(
                      'virt.secure_xml',
                      'error: operation forbidden: read only access prevents '
                          'virDomainGetXMLDesc with secure flag',
                      1,
                    )
                  : _section('virt.secure_xml', secured)),
        );
      }
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
    expect(vnc.password, 'fake-pw1');
    expect(vnc.passwordKnown, isTrue);
    expect('$vnc', isNot(contains('fake-pw1')), reason: 'never printed');

    // Refused the password: the console is still offered, and says it does
    // not know.
    secureRefused = true;
    final unknown =
        await virt.console(web, VirtConsoleKind.vnc) as LibvirtVncConsole;
    expect(unknown.port, 5900);
    expect(unknown.password, isNull);
    expect(unknown.passwordKnown, isFalse);
  });
  group('snapshots', () {
    test('listed with parent, time, memory and the current one', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        return _ok(_fixture('script_snapshots_cirros_run.txt'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final snap = await virt.load();
      expect(snap.capabilities.snapshots, isTrue);
      expect(snap.capabilities.snapshotMemoryRequired, isTrue);
      final web = snap.guests.firstWhere((g) => g.id == _run);
      final list = await virt.snapshots(web);
      // By UUID, never by name.
      expect(exec.calls.last.script, contains("--domain '$_run'"));
      expect(list.map((s) => s.name), ['sbx-a', 'sbx-b', 'sbx-off']);
      final a = list.first;
      expect(a.current, isTrue);
      expect(a.withMemory, isTrue);
      expect(a.description, 'first one');
      expect(
        a.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1790335495 * 1000),
      );
      expect(list.last.withMemory, isFalse);
      expect(list.last.parent, 'sbx-a');
      expect(
        virtSnapshotTree(list).map((e) => (e.$1.name, e.$2)),
        [('sbx-a', 0), ('sbx-off', 1), ('sbx-b', 2)],
      );
    });

    test('create, revert and delete run their virsh command', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        // The check a revert and a delete make first: a host that allows
        // both (the chain in the default pool's directory).
        if (call.script.contains('snapshot-dumpxml')) {
          return _ok(
            _fixture('script_snap_delete_running_clear.txt').replaceAll(
              '/var/lib/libvirt/sbxe2e-exp/',
              '/var/lib/libvirt/images/sbxe2e-exp/',
            ),
          );
        }
        return _ok(_section('virt.action', 'ok'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);

      await virt.createSnapshot(web, name: 'pre-up', description: 'a b');
      expect(
        exec.calls.last.script,
        contains(
          "V snapshot-create-as --domain '$_run' --name 'pre-up' "
          "--description 'a b'\n",
        ),
      );
      await virt.revertSnapshot(web, 'pre-up', start: true);
      expect(exec.calls.last.script, contains('--snapshotname \'pre-up\' --running'));
      await virt.revertSnapshot(web, 'pre-up');
      expect(exec.calls.last.script, isNot(contains('--running')));
      await virt.deleteSnapshot(web, 'pre-up');
      expect(
        exec.calls.last.script,
        contains("R snapshot-delete --domain '$_run' --snapshotname 'pre-up'"),
      );
      expect(
        exec.calls[exec.calls.length - 2].script,
        contains("snapshot-dumpxml --domain '$_run' --snapshotname 'pre-up'"),
      );
      // A name the form would not allow never reaches the host.
      final calls = exec.calls.length;
      final e = await _err(virt.createSnapshot(web, name: "x'; reboot"));
      expect(e.type, VirtErrType.unsupported);
      expect(exec.calls, hasLength(calls));
    });

    test('a revert AppArmor would fail is refused before it is sent', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (call.script.contains('snapshot-dumpxml')) {
          return _ok(_fixture('script_snap_delete_running_clear.txt'));
        }
        return _fail('unexpected script');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
      final e = await _err(virt.revertSnapshot(web, 'ext2', start: true));
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, contains('/var/lib/libvirt/images'));
      expect(exec.calls.where((c) => c.script.contains('snapshot-revert')), isEmpty);
    });

    test('a delete AppArmor would refuse is refused before it is sent',
        () async {
      for (final f in [
        'script_snap_delete_running_denied.txt',
        'script_snap_delete_shut_off.txt',
      ]) {
        final exec = _Exec((call) {
          if (call.script.contains('domstats')) return _ok(_overview());
          if (call.script.contains('snapshot-dumpxml')) return _ok(_fixture(f));
          return _fail('unexpected script');
        });
        final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
        final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
        final e = await _err(virt.deleteSnapshot(web, 'ext2'));
        expect(e.type, VirtErrType.unsupported, reason: f);
        expect(e.message, contains('#932456'), reason: f);
        expect(
          exec.calls.where((c) => c.script.contains('snapshot-delete')),
          isEmpty,
          reason: f,
        );
      }
    });

    test('a snapshot off the chain is deleted with the overlay libvirt '
        'leaves', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (call.script.contains('snapshot-dumpxml')) {
          return _ok(_fixture('script_snap_delete_off_chain.txt'));
        }
        if (call.script.contains('pool-list')) {
          return _ok(_fixture('script_storage.txt'));
        }
        return _ok(_section('virt.action', 'ok'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
      await virt.deleteSnapshot(web, 'm2');
      final del = exec.calls.last.script;
      expect(del, contains("R snapshot-delete --domain '$_run' --snapshotname 'm2'"));
      expect(del, contains("R vol-delete --vol '/var/lib/libvirt/sbxe2e-exp/ov2.qcow2'"));
      expect(
        del.indexOf('snapshot-delete'),
        lessThan(del.indexOf('vol-delete')),
      );
    });

    test('the chain is read back, and a raw disk is refused', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (call.script.contains('qemu-img')) {
          return _ok(_fixture('script_snap_chain_overlay.txt'));
        }
        if (call.script.contains('pool-list')) {
          return _ok(_fixture('script_storage.txt'));
        }
        return _ok(_fixture('script_snapshots_external.txt'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
      final chain = await virt.snapshotChain(web);
      expect(chain.depth, 2);
      expect(chain.hasOverlays, isTrue);
      expect(chain.refusal, isNull);
      expect(chain.externalRefusal, isNull);
      final disk = chain.disks.first;
      expect(disk.target, 'vda');
      // The overlay is in /var/lib/libvirt/sbxe2e-p8q, which is no pool the
      // listing has: named by the pool list, never guessed from the path.
      expect(disk.pool, isNull);
      expect(disk.files.first.active, isTrue);
      expect(disk.files.first.snap, 'sx1');
      // The base image is not anyone's snapshot.
      expect(disk.files.last.snap, isNull);
      // Only pools of files are offered for an overlay.
      expect(chain.pools, contains('images'));

      // A raw disk: the read says so and no external form is offered.
      final raw = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (call.script.contains('qemu-img')) {
          return _ok(_fixture('script_snap_chain_raw.txt'));
        }
        if (call.script.contains('pool-list')) {
          return _ok(_fixture('script_storage.txt'));
        }
        return _ok(_fixture('script_snapshots_none.txt'));
      });
      final virt2 = LibvirtBackend(serverId: 's', exec: () async => raw);
      final web2 = (await virt2.load()).guests.firstWhere((g) => g.id == _run);
      final rawChain = await virt2.snapshotChain(web2);
      expect(rawChain.refusal, contains('raw'));
      expect(rawChain.externalRefusal, contains('raw'));
      expect(await virt2.snapshotSupported(web2), isFalse);
    });

    test('an external snapshot names an overlay per disk', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (call.script.contains('pool-list')) {
          return _ok(_fixture('script_storage.txt'));
        }
        if (call.script.contains('qemu-img')) {
          return _ok(_fixture('script_snap_chain_overlay.txt'));
        }
        if (call.script.contains('snapshot-create-as')) {
          return _ok(_section('virt.action', 'ok'));
        }
        return _ok(_fixture('script_snapshots_external.txt'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
      await virt.createSnapshot(
        web,
        name: 'pre-up',
        form: VirtSnapshotForm.external,
      );
      String last() => exec.calls
          .map((c) => c.script)
          .lastWhere((s) => s.contains('snapshot-create-as'));
      final byDefault = last();
      expect(byDefault, contains('--disk-only --atomic'));
      expect(byDefault, isNot(contains('--no-metadata')));
      // No pool picked: libvirt names the overlay itself, beside the disk it
      // backs, so there is no `--diskspec` to get wrong.
      expect(byDefault, isNot(contains('--diskspec')));

      // A pool picked: the overlay goes in its directory, by path.
      await virt.createSnapshot(
        web,
        name: 'pre-up',
        form: VirtSnapshotForm.external,
        overlayPool: 'images',
      );
      final picked = last();
      expect(picked, contains('--diskspec'));
      expect(picked, contains('snapshot=external'));
      // One argument, quoted whole: virsh splits it at its commas.
      expect(
        picked,
        contains("--diskspec 'vda,file=/var/lib/libvirt/images/sx1.qcow2.pre-up,snapshot=external'"),
      );

      // A name that is no pool of files is refused before the host is asked.
      final calls = exec.calls.length;
      final e = await _err(
        virt.createSnapshot(
          web,
          name: 'pre-up',
          form: VirtSnapshotForm.external,
          overlayPool: 'sbxe2e-p8q',
        ),
      );
      expect(e.type, VirtErrType.unsupported);
      expect(
        exec.calls.skip(calls).where((c) => c.script.contains('snapshot-create-as')),
        isEmpty,
      );
    });

    test('an overlay goes only in an active pool of files', () {
      VirtStoragePool pool(String type, String? path, {bool active = true}) =>
          VirtStoragePool(
            id: type,
            name: type,
            type: type,
            path: path,
            active: active,
          );
      final dir = pool('dir', '/var/lib/libvirt/images/');
      final netfs = pool('netfs', '/mnt/nfs');
      final lvm = pool('logical', '/dev/vg0');
      final off = pool('fs', '/mnt/off', active: false);
      expect(virtPoolHoldsFiles(dir), isTrue);
      expect(virtPoolHoldsFiles(netfs), isTrue);
      // An LVM pool's target is its /dev directory: no file goes there.
      expect(virtPoolHoldsFiles(lvm), isFalse);
      expect(virtPoolHoldsFiles(off), isFalse);
      final pools = [dir, netfs, lvm, off];
      // By the directory the file is in, trailing slash or not.
      expect(virtPoolOfFile(pools, '/var/lib/libvirt/images/a.qcow2'), dir);
      expect(virtPoolOfFile(pools, '/var/lib/libvirt/images/sub/a.qcow2'), isNull);
      expect(virtPoolOfFile(pools, '/dev/vg0/lv'), isNull);
      expect(virtPoolOfFile(pools, '/mnt/off/a.qcow2'), off);
    });

    test('a diff is read and grouped by what changed', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        return _ok(_fixture('script_snap_diff.txt'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
      final diff = await virt.snapshotDiff(web, 's1');
      expect(exec.calls.last.script, contains('snapshot-dumpxml'));
      expect(exec.calls.last.script, contains('--inactive'));
      expect(
        diff.map((d) => (d.group, d.key)),
        containsAll([
          (VirtSnapDiffGroup.cpu, 'vcpu'),
          (VirtSnapDiffGroup.memory, 'memory'),
        ]),
      );
      final mem = diff.firstWhere((d) => d.key == 'memory');
      // KiB, as libvirt writes `<memory unit='KiB'>` and the parser converts
      // to bytes before dividing back: the numbers are the definition's.
      expect((mem.before, mem.after), ('262144', '524288'));
      expect(mem.added, isFalse);
      final nic = diff.singleWhere((d) => d.group == VirtSnapDiffGroup.nics);
      expect(nic.added, isTrue);
      expect(nic.after, contains('e1000e'));
      // No disk row: its source file always differs under an external
      // snapshot and is never a configuration change.
      expect(diff.any((d) => d.group == VirtSnapDiffGroup.disks), isFalse);
    });

    test('libvirt refusing one is actionFailed with its words', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        return _ok(_fixture('script_snapshot_error_raw.txt'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final web = (await virt.load()).guests.firstWhere((g) => g.id == _run);
      final e = await _err(virt.createSnapshot(web, name: 'snap1'));
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, contains('unsupported for storage type raw'));
    });
  });

  group('create and delete', () {
    const images = VirtStoragePool(
      id: 'images',
      name: 'images',
      type: 'dir',
      path: '/var/lib/libvirt/images',
    );
    const isos = VirtStoragePool(id: 'sbx-iso', name: 'sbx-iso', type: 'dir');
    const defaultNet = VirtNetwork(id: 'default', name: 'default', mode: 'nat');
    VirtCreateSpec spec({bool start = true, String name = 'sbm-create-test'}) => VirtCreateSpec(
      kind: VirtGuestKind.qemu,
      name: name,
      cores: 1,
      memoryMiB: 256,
      storage: images,
      diskGiB: 1,
      media: (
        pool: isos,
        volume: const VirtVolume(id: 'tiny.iso', name: 'tiny.iso'),
      ),
      network: defaultNet,
      start: start,
    );

    /// The host as captured (libvirt 11.3): what a create reads first (the
    /// domains, the storage, the networks, `domcapabilities`, the firmware),
    /// then [volume] and [define], the answers to the two steps.
    _Exec createExec({
      String host = 'script_create_host.txt',
      ExecResult Function()? volume,
      String define = 'script_define_ok.txt',
    }) => _Exec((call) {
      if (call.script.contains('domcapabilities')) return _ok(_fixture(host));
      if (call.script.contains('vol-create')) {
        return volume?.call() ?? _ok(_fixture('script_create_volume.txt'));
      }
      if (call.script.contains('define --file')) return _ok(_fixture(define));
      if (call.script.contains('domstats')) return _ok(_overview());
      if (call.script.contains('net-list')) return _ok(_fixture('script_networks.txt'));
      if (call.script.contains('/usr/share/qemu/firmware')) return _fail('no descriptors');
      if (_storageAnswer(call) case final r?) return r;
      return _fail('unexpected script');
    });

    String step(_Exec exec, String what) =>
        exec.calls.map((c) => c.script).firstWhere((s) => s.contains(what));

    test('the host read, then the disk, then the domain on its path', () async {
      final exec = createExec();
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final created = await virt.create(spec());

      expect(created.id, 'be27edda-481c-401d-88df-57e7b8756364');
      expect(created.startError, isNull);
      expect(exec.calls.map((c) => c.entry), everyElement('sh'));
      final volume = step(exec, 'vol-create');
      expect(volume, contains("--name 'sbm-create-test.qcow2' --capacity 1G --format qcow2"));
      final define = step(exec, 'define --file');
      // KVM on q35 as the host said, the disk by the path it gave, the ISO
      // by its own.
      expect(define, contains('pc-q35-10.0'));
      expect(define, contains('/var/lib/libvirt/images/sbm-create-test.qcow2'));
      expect(define, contains('/var/lib/libvirt/sbx-iso/tiny.iso'));
      expect(define, contains("R start --domain 'sbm-create-test'"));
    });

    test('a name already defined is exists, and nothing is defined', () async {
      final exec = createExec(volume: () => _ok(_fixture('script_create_volume_exists.txt')));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(virt.create(spec()));
      expect(e.type, VirtErrType.exists);
      expect(exec.calls.where((c) => c.script.contains('define --file')), isEmpty);
    });

    test('a name the host has, or media it does not list: refused before any '
        'step', () async {
      final exec = createExec();
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final taken = await _err(virt.create(spec(name: 'cirros-run')));
      expect(taken.type, VirtErrType.exists);
      expect(taken.message, l10n.virtCreateNameTaken);
      final s = spec();
      final gone = await _err(
        virt.create(
          VirtCreateSpec(
            kind: s.kind,
            name: s.name,
            cores: 1,
            memoryMiB: 256,
            storage: images,
            diskGiB: 1,
            media: (pool: isos, volume: const VirtVolume(id: 'x.iso', name: 'x.iso')),
          ),
        ),
      );
      expect(gone.message, l10n.virtCreateMediaMissing);
      expect(exec.calls.where((c) => c.script.contains('vol-create')), isEmpty);
    });

    test('a define the host refuses is actionFailed, with its words', () async {
      final exec = createExec(define: 'script_define_rollback.txt');
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(virt.create(spec(start: false)));
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, contains('No PCI buses available'));
      final define = step(exec, 'define --file');
      expect(define, contains('vol-delete'));
      expect(define, isNot(contains('R start')));
    });

    test('create options: what the machine offers, and the seed tool', () async {
      final full = createExec(host: 'script_create_host_full.txt');
      final o = await LibvirtBackend(serverId: 's', exec: () async => full).createOptions();
      // q35 has no IDE; OVMF is there, swtpm is not; no firmware
      // descriptors read: no Secure Boot.
      expect(o.buses, ['virtio', 'scsi', 'sata']);
      expect(o.nicModels.first, 'virtio');
      expect((o.uefi, o.tpm, o.secureBoot, o.cloudImages, o.cloudInit), (true, false, false, true, true));
      expect(o.cloudInitMissing, isNull);
      // The trimmed capture asked for no tool: none, and which to install.
      final old = createExec();
      final o2 = await LibvirtBackend(serverId: 's', exec: () async => old).createOptions();
      expect(o2.cloudInit, isFalse);
      expect(o2.cloudInitMissing, contains('genisoimage'));
    });

    test('a cloud image with cloud-init: a copy, a seed, only a hash', () async {
      const password = 'correct horse battery';
      String copied = '3758096384';
      final exec = createExec(
        host: 'script_create_host_full.txt',
        volume: () => _ok(
          [
            _section('virt.vol.create', ''),
            _section('virt.vol.info', 'Capacity:       $copied bytes\n'),
            _section('virt.vol.resize', ''),
            _section('virt.vol.path', '/var/lib/libvirt/images/ci-01.qcow2'),
            _section('virt.seed.iso', ''),
            _section('virt.seed.vol', ''),
            _section('virt.seed.upload', ''),
            _section('virt.seed.path', '/var/lib/libvirt/images/ci-01-cidata.iso'),
          ].join(),
        ),
      );
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      const ci = VirtCreateSpec(
        kind: VirtGuestKind.qemu,
        name: 'ci-01',
        cores: 1,
        memoryMiB: 1024,
        storage: images,
        diskGiB: 8,
        image: (pool: images, volume: VirtVolume(id: 'cirros.img', name: 'cirros.img')),
        network: defaultNet,
        bus: 'scsi',
        nicModel: 'e1000e',
        uefi: true,
        cloudInit: VirtCloudInit(
          user: 'admin',
          password: password,
          sshKeys: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me@x',
        ),
      );
      final created = await virt.create(ci);
      expect(created.diskKeptBytes, isNull);
      final volume = step(exec, 'vol-create');
      expect(volume, contains("--vol '/var/lib/libvirt/images/cirros.img'"));
      expect(volume, contains(r'hashed_passwd: "$6$'));
      // The password itself goes nowhere.
      for (final c in exec.calls) {
        expect(c.script, isNot(contains(password)));
      }
      final define = step(exec, 'define --file');
      expect(define, contains('/var/lib/libvirt/images/ci-01-cidata.iso'));
      expect(define, contains('https://serverbox.app/xmlns/libvirt/cloud-init/1'));
      expect(define, contains('firmware='));
      // The NIC cloud-init finds by its MAC is the one defined with it.
      final mac = RegExp(r'52:54:00(:[0-9a-f]{2}){3}').allMatches(volume).map((m) => m[0]).toSet();
      expect(mac, hasLength(1));
      expect(define, contains(mac.single));
      // A copy bigger than the disk asked for keeps its own size.
      copied = '${10 << 30}';
      expect((await virt.create(ci)).diskKeptBytes, 10 << 30);
    });

    test('delete: the seed the domain names goes with it, after it', () async {
      const seed = '/var/lib/libvirt/images/it-cidata.iso';
      final xml = _fixture('dumpxml_win11.xml').replaceFirst(
        '<name>',
        "<metadata><sbx:cloud-init xmlns:sbx='https://serverbox.app/xmlns/libvirt/cloud-init/1' seed='$seed'/></metadata><name>",
      );
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (_storageAnswer(call) case final r?) return r;
        if (call.script.contains('snapshot-list')) {
          return _ok(_fixture('script_snapshots_none.txt'));
        }
        if (call.script.contains('dumpxml')) {
          return _ok(
            _section('virt.display', _fixture('error_display_not_running.txt'), 1) +
                _section('virt.xml', xml),
          );
        }
        if (call.script.contains('undefine')) {
          return _ok(_section('virt.action', '') + _section('virt.seed.delete', ''));
        }
        return _fail('unexpected script');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final odd = (await virt.load()).guests.firstWhere((g) => g.id == _odd);
      await virt.delete(odd);
      expect(exec.calls.last.script, contains("vol-delete --vol '$seed'"));
      // Kept with the disks.
      await virt.delete(odd, removeDisks: false);
      expect(exec.calls.last.script, isNot(contains('vol-delete')));
    });

    test('delete: a running guest is refused, a stopped one undefined '
        'with its writable disks only', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (_storageAnswer(call) case final r?) return r;
        if (call.script.contains('snapshot-list')) {
          return _ok(_fixture('script_snapshots_none.txt'));
        }
        if (call.script.contains('dumpxml')) {
          return _ok(
            _section(
                  'virt.display',
                  _fixture('error_display_not_running.txt'),
                  1,
                ) +
                _section('virt.xml', _fixture('dumpxml_win11.xml')),
          );
        }
        if (call.script.contains('undefine')) {
          return _ok(_fixture('script_undefine.txt'));
        }
        return _fail('unexpected script');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final guests = (await virt.load()).guests;
      final running = guests.firstWhere((g) => g.id == _run);
      expect((await _err(virt.delete(running))).type, VirtErrType.unsupported);

      final odd = guests.firstWhere((g) => g.id == _odd);
      await virt.delete(odd);
      final undefine = exec.calls.last.script;
      expect(undefine, contains("undefine --domain '$_odd'"));
      // Not the CD-ROM.
      expect(undefine, contains('--nvram --storage sda,sdb,vdb,vdc'));

      await virt.delete(odd, removeDisks: false);
      expect(exec.calls.last.script, contains('--keep-nvram'));
      expect(exec.calls.last.script, isNot(contains('--storage')));
      expect(
        exec.calls.where(
          (c) => c.script.contains('V dumpxml --domain'),
        ),
        hasLength(1),
      );
    });

    test('delete: the files external snapshots left under a disk go with '
        'it, down to the disk the first one was taken of', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
        if (call.script.contains('qemu-img')) {
          // The overlay's disk is one of the guest's writable ones.
          return _ok(
            _fixture('script_snap_chain_overlay.txt').replaceAll("dev='vda'", "dev='vdb'"),
          );
        }
        if (_storageAnswer(call) case final r?) return r;
        if (call.script.contains('snapshot-list')) {
          return _ok(_fixture('script_snapshots_external.txt'));
        }
        if (call.script.contains('dumpxml')) {
          return _ok(
            _section('virt.display', _fixture('error_display_not_running.txt'), 1) +
                _section('virt.xml', _fixture('dumpxml_win11.xml')),
          );
        }
        if (call.script.contains('undefine')) {
          return _ok(_fixture('script_undefine.txt'));
        }
        return _fail('unexpected script');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final odd = (await virt.load()).guests.firstWhere((g) => g.id == _odd);
      await virt.delete(odd);
      final undefine = exec.calls.last.script;
      // The overlay is what vdb is on: `--storage` deletes it. Below it,
      // the disk the snapshot was taken of, in the `images` pool.
      expect(undefine, contains('--storage sda,sdb,vdb,vdc'));
      expect(undefine, contains("pool-refresh --pool 'images'"));
      expect(
        undefine,
        contains("vol-delete --vol '/var/lib/libvirt/images/sbxe2e-f1.qcow2'"),
      );
      expect(undefine, isNot(contains("vol-delete --vol '/var/lib/libvirt/sbxe2e-p8q/sx1.qcow2'")));

      // Kept with the disks: nothing is read, nothing deleted.
      final calls = exec.calls.length;
      await virt.delete(odd, removeDisks: false);
      expect(exec.calls, hasLength(calls + 1));
      expect(exec.calls.last.script, isNot(contains('vol-delete')));
    });
  });

  test('delete: a volume another guest has, or is made on, stays', () async {
    // it's-"odd"'s sda is the file cirros-run's vdb is on; its sdb is the
    // base image cirros-run's and others' disks are made on.
    final storage = _fixture('script_storage.txt').replaceFirst(
      ' file   disk    vda   /var/lib/libvirt/images/off1.qcow2',
      ' file   disk    sda   /var/lib/libvirt/images/extra.qcow2\n'
          ' file   disk    sdb   /var/lib/libvirt/images/cirros.img\n'
          ' file   disk    vdc   /var/lib/libvirt/images/off1.qcow2',
    );
    final exec = _Exec((call) {
      if (call.script.contains('domstats')) return _ok(_overview());
      if (call.script.contains('pool-list')) return _ok(storage);
      if (_storageAnswer(call) case final r?) return r;
      if (call.script.contains('snapshot-list')) {
        return _ok(_fixture('script_snapshots_none.txt'));
      }
      if (call.script.contains('dumpxml')) {
        return _ok(
          _section('virt.display', _fixture('error_display_not_running.txt'), 1) +
              _section('virt.xml', _fixture('dumpxml_win11.xml')),
        );
      }
      if (call.script.contains('undefine')) {
        return _ok(_fixture('script_undefine.txt'));
      }
      return _fail('unexpected script');
    });
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    final odd = (await virt.load()).guests.firstWhere((g) => g.id == _odd);
    await virt.delete(odd);
    final undefine = exec.calls.last.script;
    expect(undefine, contains("undefine --domain '$_odd'"));
    // off1.qcow2 is its own and made on cirros.img, which stays: only what
    // nothing else needs goes.
    expect(undefine, contains('--storage vdb,vdc'));
  });

  group('storage', () {
    _Exec storageExec() => _Exec((call) {
      if (call.script.contains('domstats')) return _ok(_overview());
      if (call.script.contains('pool-list')) {
        return _ok(_fixture('script_storage.txt'));
      }
      if (call.script.contains("vol-dumpxml --pool 'images'")) {
        return _ok(_fixture('script_volumes_images.txt'));
      }
      if (call.script.contains("vol-dumpxml --pool 'sbx-iso'")) {
        return _ok(_fixture('script_volumes_sbx_iso.txt'));
      }
      return _fail('unexpected ${call.script}');
    });

    test('pools, with an inactive one read as unknown rather than empty', () async {
      final virt = LibvirtBackend(serverId: 's', exec: () async => storageExec());
      final pools = await virt.storagePools();
      expect(pools.map((p) => p.id), ['images', 'sbx-iso', 'sbx-off']);
      final images = pools.first;
      expect(images.type, 'dir');
      expect(images.path, '/var/lib/libvirt/images');
      expect(images.capacity, 20922114048);
      expect(images.used, 1152606208);
      expect(images.autostart, isTrue);
      expect(images.volumeCount, 6);
      final off = pools.last;
      expect(off.active, isFalse);
      expect(off.capacity, isNull);
      expect(off.usedFraction, isNull);
      expect(off.volumeCount, isNull);
    });

    test('volumes with their format and the guests using them', () async {
      final exec = storageExec();
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final pools = await virt.storagePools();
      final vols = await virt.volumes(pools.first);
      // The names come from the listing, not a second one.
      expect(exec.calls.where((c) => c.script.contains('pool-list')), hasLength(1));
      expect(vols.map((v) => v.name), [
        'cirros.img',
        'data1.qcow2',
        'extra.qcow2',
        'off1.qcow2',
        'paused1.qcow2',
        'run1.qcow2',
      ]);
      final run1 = vols.firstWhere((v) => v.name == 'run1.qcow2');
      expect(run1.format, 'qcow2');
      expect(run1.capacity, 117440512);
      expect(run1.backing, '/var/lib/libvirt/images/cirros.img');
      expect(run1.users, [const VirtGuestRef(guestId: _run, device: 'vda')]);
      expect(
        vols.firstWhere((v) => v.name == 'off1.qcow2').users.single.guestId,
        _odd,
      );
      // A base image only others are layered on is not "used" by a disk —
      // but it is what they are made on, which is as good as in use.
      final base = vols.firstWhere((v) => v.name == 'cirros.img');
      expect(base.users, isEmpty);
      expect(
        base.backs.map((p) => p.split('/').last),
        unorderedEquals([
          'data1.qcow2',
          'off1.qcow2',
          'paused1.qcow2',
          'run1.qcow2',
        ]),
      );
      expect(base.inUse, isTrue);
      expect(
        virtResourceIssue(
          VirtVolumeDelete(pools.first, base),
          host: VirtHostKind.libvirt,
        ),
        VirtResIssue.inUse,
      );
      expect(vols.firstWhere((v) => v.name == 'extra.qcow2').backs, isEmpty);

      final iso = await virt.volumes(pools[1]);
      expect(iso.first.name, 'my disk.qcow2');
      final tiny = iso.firstWhere((v) => v.name == 'tiny.iso');
      expect(tiny.users, [const VirtGuestRef(guestId: _odd, device: 'hdc')]);
      expect(await virt.volumes(pools.last), isEmpty);
    });

    test('a listed volume that does not read refreshes the pool, once', () async {
      final full = _fixture('script_volumes_images.txt');
      // `cirros.img` gone behind libvirt's back: `vol-dumpxml` refuses it.
      final at = full.indexOf('SrvBoxSep', 1);
      final stale =
          'SrvBoxSep.b64.dmlydC52b2wueG1s\ncirros.img\n'
          "error: Storage volume not found: no storage vol with matching path '/var/lib/libvirt/images/cirros.img'\n"
          '\nSbVirtRc=1\n${full.substring(at)}';
      var refreshed = false;
      final exec = _Exec((call) {
        if (call.script.contains('pool-refresh')) {
          refreshed = true;
          return _ok(_section('virt.res.step', 'Pool images refreshed'));
        }
        if (call.script.contains('pool-list')) return _ok(_fixture('script_storage.txt'));
        if (call.script.contains("vol-dumpxml --pool 'images'")) {
          return _ok(refreshed ? full : stale);
        }
        // Read too, for what is made on a volume here.
        if (call.script.contains("vol-dumpxml --pool 'sbx-iso'")) {
          return _ok(_fixture('script_volumes_sbx_iso.txt'));
        }
        return _fail('unexpected ${call.script}');
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final pools = await virt.storagePools();
      final vols = await virt.volumes(pools.first);
      expect(refreshed, isTrue);
      expect(exec.calls.where((c) => c.script.contains('pool-refresh')), hasLength(1));
      expect(vols, hasLength(6));
    });

    test('volumes without a listing first list the pools', () async {
      final exec = storageExec();
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final vols = await virt.volumes(
        const VirtStoragePool(id: 'sbx-iso', name: 'sbx-iso', type: 'dir'),
      );
      expect(vols, hasLength(2));
      expect(exec.calls.first.script, contains('pool-list'));
    });
  });

  test('networks with modes, addresses and the guests on each', () async {
    final exec = _Exec((call) => _ok(_fixture('script_networks.txt')));
    final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
    final nets = await virt.networks();
    expect(nets.map((n) => n.name), ['default', 'sbx-bridge', 'sbx-isolated']);
    final def = nets.first;
    expect(def.mode, 'nat');
    expect(def.bridge, 'virbr0');
    expect(def.cidrs, ['192.168.122.1/24']);
    expect(def.dhcpRanges, ['192.168.122.2-192.168.122.254']);
    expect(def.autostart, isTrue);
    // Every domain's NICs on it, running or not, with a leased address.
    expect(def.users.map((u) => u.guestId), [_paused, _run, _run, _odd]);
    final leased = def.users.firstWhere((u) => u.mac == '52:54:00:6e:d2:3c');
    expect(leased.ip, '192.168.122.202/24');
    expect(leased.device, isNotNull);
    expect(def.users.last.device, isNull, reason: 'shut off: no vnetN');
    final iso = nets.last;
    expect(iso.mode, 'isolated');
    expect(iso.cidrs, ['10.99.0.1/24', 'fd00:99::1/64']);
    expect(iso.users.single.guestId, _odd);
    expect(nets[1].active, isFalse);
    expect(nets[1].users, isEmpty);
  });

  group('hardware', () {
    // `sbhw-test`, captured running with 3 of 4 vCPUs online and 2 in the
    // persistent definition: the one change waiting for the next start.
    const hwId = '34d2450f-095b-496c-91fe-c8c99b912ae8';
    const guest = VirtGuest(
      id: hwId,
      name: 'sbhw-test',
      kind: VirtGuestKind.qemu,
      state: VirtGuestState.running,
    );
    const pool = VirtStoragePool(id: 'images', name: 'images', type: 'dir');
    const net = VirtNetwork(id: 'isolated', name: 'isolated', mode: 'isolated');

    ({LibvirtBackend virt, _Exec exec}) backend(
      ExecResult Function(_Call call) change,
    ) {
      var reads = 0;
      final exec = _Exec((call) {
        if (call.script.contains('dumpxml --inactive') && reads++ == 0) {
          return _ok(_fixture('script_hardware_running.txt'));
        }
        return change(call);
      });
      return (
        virt: LibvirtBackend(serverId: 's', exec: () async => exec),
        exec: exec,
      );
    }

    test('both definitions: the next start\'s, and what differs now', () async {
      final (:virt, :exec) = backend((_) => fail('no change'));
      final hw = await virt.hardware(guest);
      expect(exec.calls.single.script, contains("'$hwId'"));
      expect(hw.running, isTrue);
      expect((hw.cpu.sockets, hw.cpu.cores, hw.cpu.threads, hw.cpu.online), (4, 1, 1, 2));
      // No `<topology>`: libvirt gives each vCPU a socket of its own.
      expect((hw.memory.mib, hw.memory.minMib, hw.memory.balloon), (512, 384, true));
      final vda = hw.disk('vda')!;
      expect((vda.kind, vda.bus, vda.size), (VirtHwDiskKind.disk, 'virtio', 117440512));
      expect(vda.source, '/var/lib/libvirt/images/sbhw-root.qcow2');
      final cd = hw.disk('hdc')!;
      expect((cd.kind, cd.source), (VirtHwDiskKind.cdrom, null));
      final nic = hw.nics.single;
      expect((nic.key, nic.type, nic.source, nic.linkUp), ('52:54:00:b9:34:c3', 'network', 'default', true));
      expect(hw.boot, ['vda']);
      expect(hw.limits.hostCpus, 4);
      expect(hw.revision, startsWith("<domain type='kvm'>"));
      // Online vCPUs differ; the balloon's current size moves by itself and
      // is not a change.
      final p = hw.pending.single;
      expect((p.key, p.current, p.pending), ('cpu', '3/4 (4×1×1)', '2/4 (4×1×1)'));
    });

    test('clone: disks copied from the definition, then the copy defined',
        () async {
      final exec = _Exec((call) {
        if (call.script.contains('vol-clone')) {
          return _ok(_fixture('script_clone_volumes_full.txt'));
        }
        if (call.script.contains('define --file')) {
          return _ok(_fixture('script_clone_define.txt'));
        }
        if (call.script.contains('domstats')) return _ok(_overview());
        if (_storageAnswer(call) case final r?) return r;
        return _ok(_fixture('script_hardware_stopped.txt'));
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final off = guest.copyWith(state: VirtGuestState.stopped);
      final id = await virt.clone(off, const VirtCloneRequest(name: 'sbcl-full'));
      expect(id, 'b0352bd8-52ad-4cf7-875c-7ceb45b0d751');
      final scripts = exec.calls.map((c) => c.script).toList();
      final vols = scripts.firstWhere((s) => s.contains('vol-clone'));
      expect(vols, contains("--vol '/var/lib/libvirt/images/off1.qcow2'"));
      expect(vols, contains("--newname 'sbcl-full.qcow2'"));
      // The copy on the volume the first step made, named as asked.
      final define = scripts.firstWhere((s) => s.contains('define --file'));
      // Shell-quoted: each `'` of the XML is `'\''` in the script.
      expect(define, contains("<source file='\\''/var/lib/libvirt/images/sbcl-full.qcow2'\\''/>"));
      expect(define, contains('<name>sbcl-full</name>'));

      // Running: refused before anything reaches the host.
      final calls = exec.calls.length;
      final e = await _err(virt.clone(guest, const VirtCloneRequest(name: 'x')));
      expect(e.type, VirtErrType.unsupported);
      expect(exec.calls, hasLength(calls));
    });

    test('shut off: one definition, nothing pending', () async {
      final exec = _Exec((_) => _ok(_fixture('script_hardware_stopped.txt')));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final hw = await virt.hardware(guest.copyWith(state: VirtGuestState.stopped));
      expect(hw.running, isFalse);
      expect(hw.pending, isEmpty);
    });

    test('changes are addressed by what each definition has', () async {
      final info = LibvirtHardwareInfo.fromJson(
        jsonDecode(
              await parseVirtHardwareJson(
                raw: _fixture('script_hardware_running.txt'),
              ),
            )
            as Map<String, dynamic>,
      );
      final hw = LibvirtBackend.hardwareOf(info);
      Map<String, Object?> json(VirtHwChange c) => LibvirtBackend.changeJson(
        info,
        hw,
        c,
        guestName: 'sbhw-test',
        mac: () => '52:54:00:00:00:01',
      );
      // A CD-ROM drive: IDE on `pc`, beside the one there is.
      expect(json(const VirtHwAddCdrom()), {
        'op': 'add_cdrom',
        'target': 'hda',
        'bus': 'ide',
        'source': null,
      });
      expect(
        json(const VirtHwAddCdrom(media: VirtVolume(id: 'a.iso', name: 'a.iso', path: '/iso/a.iso')))['source'],
        '/iso/a.iso',
      );
      expect(
        () => json(const VirtHwAddCdrom(media: VirtVolume(id: 'a.iso', name: 'a.iso'))),
        throwsA(isA<VirtErr>()),
      );
      expect(json(const VirtHwAddDisk(storage: pool, gib: 2)), {
        'op': 'add_disk',
        'pool': 'images',
        // `hdc` is the CD-ROM's; a new disk takes the first disk's bus.
        'volume': 'sbhw-test-vdb.qcow2',
        'gib': 2,
        'format': 'qcow2',
        'target': 'vdb',
        'bus': 'virtio',
      });
      expect(json(const VirtHwRemoveDisk(key: 'vda', deleteVolume: true)), {
        'op': 'remove_disk',
        'target': 'vda',
        'delete_path': '/var/lib/libvirt/images/sbhw-root.qcow2',
        'config': true,
        'live': true,
      });
      // A CD-ROM's image is never deleted with it.
      expect(json(const VirtHwRemoveDisk(key: 'hdc', deleteVolume: true))['delete_path'], isNull);
      // Ejecting an empty drive: nothing to do in either definition.
      expect(json(const VirtHwSetMedia(key: 'hdc')), containsPair('config', false));
      expect(json(const VirtHwSetMedia(key: 'hdc')), containsPair('live', false));
      expect(
        json(const VirtHwSetMedia(key: 'hdc', media: VirtVolume(id: 'a.iso', name: 'a.iso', path: '/isos/a.iso'))),
        {'op': 'set_media', 'target': 'hdc', 'source': '/isos/a.iso', 'config': true, 'live': true},
      );
      expect(json(const VirtHwUpdateNic(key: '52:54:00:b9:34:c3', linkUp: false, network: net)), {
        'op': 'update_nic',
        'mac': '52:54:00:b9:34:c3',
        'kind': 'network',
        'source': 'isolated',
        'model': 'virtio',
        'link_up': false,
        'boot_order': null,
        'live_boot_order': null,
        'config': true,
        'live': true,
      });
      expect(json(const VirtHwAddNic(network: net)), {
        'op': 'add_nic',
        'kind': 'network',
        'source': 'isolated',
        'model': 'virtio',
        'mac': '52:54:00:00:00:01',
      });
      expect(json(const VirtHwGrowDisk(key: 'vda', bytes: 1 << 30)), {
        'op': 'grow_disk',
        'target': 'vda',
        'bytes': 1 << 30,
        'path': '/var/lib/libvirt/images/sbhw-root.qcow2',
        'live': true,
      });
      // The definition put another file at vda while it runs: `blockresize`
      // would grow the running, old one. The configured file, offline.
      final swapped = info.copyWith(
        config: info.config.copyWith(
          disks: [
            for (final d in info.config.disks)
              d.target == 'vda' ? d.copyWith(source: '/var/lib/libvirt/images/new.qcow2') : d,
          ],
        ),
      );
      final grown = LibvirtBackend.changeJson(
        swapped,
        LibvirtBackend.hardwareOf(swapped),
        const VirtHwGrowDisk(key: 'vda', bytes: 1 << 30),
        guestName: 'sbhw-test',
        mac: () => '52:54:00:00:00:01',
      );
      expect((grown['path'], grown['live']), ('/var/lib/libvirt/images/new.qcow2', false));
      // A disk with no file to `vol-resize` is not offered for growing.
      final byRef = info.copyWith(
        config: info.config.copyWith(
          disks: [
            for (final d in info.config.disks)
              d.target == 'vda' ? d.copyWith(sourceType: 'volume', source: 'images/root') : d,
          ],
        ),
      );
      final refHw = LibvirtBackend.hardwareOf(byRef);
      expect(virtHwDiskGrowable(refHw.disk('vda')!), isFalse);
      expect(
        virtHwIssue(refHw, const VirtHwGrowDisk(key: 'vda', bytes: 1 << 40)),
        VirtHwIssue.diskSize,
      );
      expect(virtHwDiskGrowable(hw.disk('vda')!), isTrue);
      expect(
        () => json(const VirtHwRevert(['cpu'])),
        throwsA(isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unsupported)),
      );
      // Settings: the note and a new name; libvirt has no protection.
      expect(json(const VirtHwSetDescription('a & b')), {
        'op': 'description',
        'text': 'a & b',
      });
      expect(json(const VirtHwSetName('sbhw-2')), {'op': 'rename', 'name': 'sbhw-2'});
      expect(
        () => json(const VirtHwSetProtection(true)),
        throwsA(isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unsupported)),
      );
    });

    test('settings as read: the domain\'s name, its note, no protection, and '
        'a rename that waits for it to stop', () async {
      final info = LibvirtHardwareInfo.fromJson(
        jsonDecode(
              await parseVirtHardwareJson(
                raw: _fixture('script_hardware_running.txt'),
              ),
            )
            as Map<String, dynamic>,
      ).copyWith(description: 'the web tier');
      final hw = LibvirtBackend.hardwareOf(info, name: 'sbhw-test');
      expect((hw.name, hw.description, hw.protection), ('sbhw-test', 'the web tier', null));
      expect(hw.renameRunning, isFalse);
    });

    test('the running half refused: saved for the next start, in the host\'s words',
        () async {
      final (:virt, :exec) = backend(
        (_) => _ok(_fixture('script_hw_add_disk_ide_live_refused.txt')),
      );
      final hw = await virt.hardware(guest);
      final out = await virt.changeHardware(guest, hw, const VirtHwAddDisk(storage: pool, gib: 1));
      expect(out.liveError, contains("disk bus 'ide' cannot be hotplugged"));
      expect(out.volumeKept, isFalse);
      final change = exec.calls.last;
      expect(change.entry, 'sh');
      expect(change.script, contains('attach-disk'));
    });

    test('a disk the running guest keeps: its volume is kept too', () async {
      final (:virt, exec: _) = backend(
        (_) => _ok(_fixture('script_hw_remove_disk_kept.txt')),
      );
      final hw = await virt.hardware(guest);
      final out = await virt.changeHardware(
        guest,
        hw,
        const VirtHwRemoveDisk(key: 'vda', deleteVolume: true),
      );
      expect(out.volumeKept, isTrue);
    });

    test('discarding the pending changes: a refusal reaches the caller', () async {
      // The host answers the revert with a conflict (the definition, or the
      // running domain, is not the one read): an error, never a success.
      final (:virt, :exec) = backend((_) => _ok(_fixture('script_hw_conflict.txt')));
      final hw = await virt.hardware(guest);
      final err = await _err(virt.revertPending(guest, hw));
      expect(err.type, VirtErrType.conflict);
      final script = exec.calls.last.script;
      expect(script, contains('domid'));
      expect(script, contains('define'));
    });

    test('a definition changed since the read is a conflict', () async {
      final (:virt, :exec) = backend((_) => _ok(_fixture('script_hw_conflict.txt')));
      final hw = await virt.hardware(guest);
      final err = await _err(virt.changeHardware(guest, hw, const VirtHwSetBoot(['hdc', 'vda'])));
      expect(err.type, VirtErrType.conflict);
      // Made from the definition read, compared on the host before `define`.
      expect(exec.calls.last.script, contains('<boot order='));

      // Not from this backend's last read: refused before reaching the host.
      final calls = exec.calls.length;
      final stale = hw.copyWith(revision: '<domain/>');
      final err2 = await _err(virt.changeHardware(guest, stale, const VirtHwSetAutostart(true)));
      expect(err2.type, VirtErrType.conflict);
      expect(exec.calls, hasLength(calls));
    });

    Future<LibvirtHardwareInfo> info(String fixture) async => LibvirtHardwareInfo.fromJson(
      jsonDecode(await parseVirtHardwareJson(raw: _fixture(fixture))) as Map<String, dynamic>,
    );

    test('what the host offers comes from its domcapabilities', () async {
      // A q35 domain on a host with OVMF but no swtpm, a QEMU without SPICE.
      final hw = LibvirtBackend.hardwareOf(await info('script_hardware_caps_stopped.txt'));
      final s = hw.support;
      expect(s.buses, ['virtio', 'scsi', 'sata']);
      expect(s.protocols, ['vnc']);
      expect(s.gpus, ['virtio', 'vga', 'cirrus', 'bochs', 'none']);
      // A secure loader but no descriptor with enrolled keys: a domain
      // with Secure Boot on would not start, so it is not offered.
      expect((s.uefi, s.secureBoot, s.tpm, s.usb, s.pci, s.listen, s.mac), (true, false, false, true, true, true, true));
      expect(hw.firmware, const VirtHwFirmware(uefi: false));
      final enrolled = LibvirtBackend.hardwareOf(
        (await info('script_hardware_caps_stopped.txt')).copyWith(
          firmware: const [
            LibvirtFirmware(name: '60-edk2-x86_64-secure.json', secureBoot: true),
            LibvirtFirmware(name: '40-edk2-x86_64-secure-enrolled.json', secureBoot: true, enrolledKeys: true),
          ],
        ),
      );
      expect(enrolled.support.secureBoot, isTrue);
      expect(hw.display, const VirtHwDisplay(protocol: 'vnc', listen: '127.0.0.1', gpu: 'virtio'));
      // Without them: the common ground, and nothing the host may lack.
      final bare = LibvirtBackend.supportOf(null);
      expect((bare.uefi, bare.tpm, bare.pci), (false, false, false));
      expect(bare.buses, contains('virtio'));
    });

    test('the definition shown carries no display password', () async {
      // `dumpxml --security-info`, as the read makes it: the password is in
      // the definition a change is made from, never in what is shown.
      final raw = _fixture('script_hardware_running.txt').replaceAll(
        "<graphics type='vnc' port='-1'",
        "<graphics type='vnc' passwd='s3cret' port='-1'",
      );
      final i = LibvirtHardwareInfo.fromJson(
        jsonDecode(await parseVirtHardwareJson(raw: raw)) as Map<String, dynamic>,
      );
      expect(i.configXml, contains("passwd='s3cret'"));
      final hw = LibvirtBackend.hardwareOf(i);
      expect(hw.configText, isNot(contains('passwd=')));
      expect(hw.configText, isNot(contains('s3cret')));
      expect(hw.configText, contains("<graphics type='vnc' port='-1'"));
    });

    test('a cache mode changed while running is pending', () async {
      final hw = LibvirtBackend.hardwareOf(await info('script_hardware_caps_running.txt'));
      expect(hw.firmware, const VirtHwFirmware(uefi: true, secureBoot: true));
      final p = hw.pending.singleWhere((p) => p.key == 'sda');
      expect((p.current, p.pending), ('sata writeback', 'sata none'));
    });

    test('the second part of the changes, as JSON', () async {
      final i = await info('script_hardware_caps_stopped.txt');
      final hw = LibvirtBackend.hardwareOf(i);
      Map<String, Object?> json(VirtHwChange c) =>
          LibvirtBackend.changeJson(i, hw, c, guestName: 'sbhwb-test', mac: () => '52:54:00:00:00:01');
      // q35: a new CD-ROM drive on SATA.
      expect(json(const VirtHwAddCdrom()), {
        'op': 'add_cdrom',
        'target': 'sda',
        'bus': 'sata',
        'source': null,
      });
      // Another bus is another name on it.
      expect(json(const VirtHwUpdateDisk(key: 'vda', bus: 'sata')), {
        'op': 'update_disk',
        'target': 'vda',
        'new_target': 'sda',
        'bus': 'sata',
        'cache': null,
      });
      // The same bus is no bus change.
      expect(json(const VirtHwUpdateDisk(key: 'vda', bus: 'virtio', cache: 'none'))['new_target'], isNull);
      expect(json(const VirtHwSetNicHardware(key: '52:54:00:5b:00:01', mac: 'BC:24:11:00:00:09')), {
        'op': 'update_nic_hardware',
        'mac': '52:54:00:5b:00:01',
        'new_mac': 'bc:24:11:00:00:09',
        'model': null,
      });
      expect(json(const VirtHwSetFirmware(uefi: false, secureBoot: true)), {
        'op': 'firmware',
        'efi': false,
        'secure_boot': false,
      });
      expect(
        json(
          const VirtHwAddDevice(
            kind: VirtHwDeviceKind.usb,
            host: VirtHostDevice(id: '0bda:b023', label: 'bt'),
          ),
        )['device'],
        {'kind': 'usb', 'vendor': '0bda', 'product': 'b023'},
      );
      expect(json(const VirtHwAddDevice(kind: VirtHwDeviceKind.tpm))['device'], {'kind': 'tpm', 'model': 'tpm-crb'});
      expect(json(const VirtHwRemoveDevice(key: 'pci:0000:00:01.2')), {
        'op': 'remove_device',
        'key': 'pci:0000:00:01.2',
      });
    });

    test('cloud-init: read back from the seed, written anew in place', () async {
      const seed = '/var/lib/libvirt/images/sbhw-test-cidata.iso';
      // The captured domain, named as having the app's seed.
      final hwOut = _fixture('script_hardware_stopped.txt').replaceAll(
        '</name>\n',
        "</name>\n  <metadata><sbx:cloud-init xmlns:sbx='https://serverbox.app/xmlns/libvirt/cloud-init/1' seed='$seed'/></metadata>\n",
      );
      final iso = File('$_dir/seed_genisoimage.iso').readAsBytesSync();
      final seedOut = [
        _section('virt.seed.read', ''),
        _section('virt.seed.sum', '4155283651 69632'),
        _section('virt.seed.data', base64.encode(iso)),
      ].join();
      var updateOut = [
        _section('virt.seed.backup', ''),
        _section('virt.seed.iso', ''),
        _section('virt.seed.info', 'Capacity:       376832 bytes'),
        _section('virt.seed.upload', ''),
      ].join();
      final exec = _Exec((call) {
        if (call.script.contains('vol-upload')) return _ok(updateOut);
        if (call.script.contains('vol-download')) return _ok(seedOut);
        return _ok(hwOut);
      });
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final off = guest.copyWith(state: VirtGuestState.stopped);
      final hw = await virt.hardware(off);
      expect(hw.disks.where((d) => d.cloudInit), isEmpty, reason: 'no CD-ROM on that path');

      final ci = await virt.cloudInit(off);
      expect(ci.user, 'debian');
      expect(ci.hostname, 'sbx-web');
      expect(ci.sshKeys, hasLength(2));
      expect((ci.address, ci.gateway), ('10.231.80.5/24', '10.231.80.1'));
      expect(ci.dns, ['10.231.80.1', '2606:4700:4700::1111']);
      expect(ci.searchDomains, ['lab.example']);
      expect((ci.passwordSet, ci.network, ci.foreign), (true, true, false));
      expect(ci.revision, '4155283651 69632');
      // The hash is not what the view gets.
      expect('$ci', isNot(contains(r'$6$')));
      expect(exec.calls.last.script, contains("--vol '$seed'"));

      // Saved without a new password: the seed's hash kept, a new hostname
      // and instance, the NIC the domain has (the seed's MAC is gone).
      await virt.setCloudInit(
        off,
        ci,
        const VirtCloudInitEdit(
          VirtCloudInit(user: 'debian', sshKeys: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEW new', hostname: 'sbx-new'),
        ),
      );
      final update = exec.calls.last.script;
      expect(update, contains("'4155283651 69632'"));
      expect(update, contains(r'hashed_passwd: "$6$0123456789abcdef$lDHz'));
      expect(update, contains('hostname: "sbx-new"'));
      expect(update, contains('52:54:00:90:2c:99'));
      expect(update, isNot(contains('52:54:00:12:34:56')));
      expect(update, isNot(contains('iid-sbx-web-9f')));

      // A new password: hashed here, never in the script.
      await virt.cloudInit(off);
      await virt.setCloudInit(
        off,
        ci,
        const VirtCloudInitEdit(VirtCloudInit(user: 'debian', password: 'hunter2 new', hostname: 'sbx-new')),
      );
      expect(exec.calls.last.script, isNot(contains('hunter2 new')));
      expect(exec.calls.last.script, isNot(contains(r'$6$0123456789abcdef$lDHz')));

      // Removed: keys only, no hash at all.
      await virt.cloudInit(off);
      await virt.setCloudInit(
        off,
        ci,
        const VirtCloudInitEdit(
          VirtCloudInit(user: 'debian', sshKeys: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEW new', hostname: 'sbx-new'),
          removePassword: true,
        ),
      );
      expect(exec.calls.last.script, contains('lock_passwd: true'));
      expect(exec.calls.last.script, isNot(contains('hashed_passwd')));

      // Changed on the host since it was read: refused there.
      await virt.cloudInit(off);
      updateOut = [
        _section('virt.seed.backup', ''),
        '${_marker('virt.seed.conflict')}\n',
      ].join();
      final e = await _err(
        virt.setCloudInit(off, ci, const VirtCloudInitEdit(VirtCloudInit(user: 'debian', hostname: 'x'))),
      );
      expect(e.type, VirtErrType.conflict);
      // Not read by this backend at all: refused before the host.
      final calls = exec.calls.length;
      final other = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e2 = await _err(other.setCloudInit(off, ci, const VirtCloudInitEdit(VirtCloudInit(user: 'debian'))));
      expect(e2.type, VirtErrType.conflict);
      expect(exec.calls, hasLength(calls));
    });

    test('host devices: root hubs left out, no IOMMU said', () async {
      final exec = _Exec((_) => _ok(_fixture('script_host_devices.txt')));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final devs = await virt.hostDevices(guest);
      expect(devs.iommu, isFalse);
      expect(devs.usb, isEmpty);
      expect(devs.pci.firstWhere((p) => p.id == '0000:00:01.2').label, contains('PIIX3 USB'));
    });

    test('host devices: a USB device carries where it sits', () async {
      // `nodedev-dumpxml` of one device, as the host prints it.
      const usb = '''
SrvBoxSep.b64.dmlydC5ob3N0LnVzYg==
usb_device_1a86_7523_2_1_2
<device>
  <name>usb_device_1a86_7523_2_1_2</name>
  <capability type='usb_device'>
    <bus>2</bus>
    <device>7</device>
    <port>1.2</port>
    <product id='0x7523'>CH340 serial converter</product>
    <vendor id='0x1a86'>QinHeng Electronics</vendor>
  </capability>
</device>

SbVirtRc=0
''';
      final exec = _Exec((_) => _ok(usb));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final d = (await virt.hostDevices(guest)).usb.single;
      expect((d.usbBus, d.usbDevice, d.usbPort), (2, 7, '1.2'));
      // So it is offered by address, as libvirt writes one.
      expect(virtUsbHasAddress(d), isTrue);
      expect(virtUsbAddress(d, VirtHostKind.libvirt), '2:7');
    });
  });

  test('upload: a command that never gets ready is a timeout, not a refusal', () async {
    final exec = _Exec((_) => _ok(_section('virt.res.step', 'Vol made')));
    final session = _SilentSession();
    final virt = LibvirtBackend(
      serverId: 's',
      exec: () async => exec,
      byteExec: () async => _ByteExec(exec, session),
      canStream: () => true,
      uploadReadyTimeout: const Duration(milliseconds: 50),
    );
    final e = await _err(
      virt.upload(
        VirtUpload(
          pool: const VirtStoragePool(id: 'images', name: 'images', type: 'dir', path: '/i', active: true),
          name: 'a.iso',
          size: 3,
          open: () => Stream.value(const [1, 2, 3]),
        ),
      ),
    );

    expect(e.message, contains('not ready within'));
    expect(session.killed, isTrue);
    expect(session.written, everyElement(isNot(equals(const [1, 2, 3]))), reason: 'no file sent');
    expect(exec.calls.last.script, contains('vol-delete'), reason: 'the volume made for it is removed');
  });

  test('upload: a cancel ends it while the file waits for its next chunk', () async {
    final exec = _Exec((_) => _ok(_section('virt.res.step', 'Vol made')));
    final session = _ReadySession();
    final virt = LibvirtBackend(
      serverId: 's',
      exec: () async => exec,
      byteExec: () async => _ByteExec(exec, session),
      canStream: () => true,
    );
    // One chunk, then open and silent: a stalled read.
    final source = StreamController<List<int>>()..add(const [1, 2, 3]);
    final cancel = Completer<void>();
    final uploading = virt.upload(
      VirtUpload(
        pool: const VirtStoragePool(id: 'images', name: 'images', type: 'dir', path: '/i', active: true),
        name: 'a.iso',
        size: 6,
        open: () => source.stream,
      ),
      cancel: cancel.future,
      onProgress: (_) {
        if (!cancel.isCompleted) cancel.complete();
      },
    );

    final uploaded = await uploading.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the cancel waited for a chunk that never came'),
    );
    expect(uploaded, isFalse);
    expect(session.killed, isTrue);
    expect(exec.calls.last.script, contains('vol-delete'));
    expect(source.hasListener, isFalse, reason: 'the read is let go');
  });
}

/// The storage scripts' answers from the captured fixtures; null for any
/// other script.
ExecResult? _storageAnswer(_Call call) {
  if (call.script.contains('pool-list')) {
    return _ok(_fixture('script_storage.txt'));
  }
  if (call.script.contains("vol-dumpxml --pool 'images'")) {
    return _ok(_fixture('script_volumes_images.txt'));
  }
  if (call.script.contains("vol-dumpxml --pool 'sbx-iso'")) {
    return _ok(_fixture('script_volumes_sbx_iso.txt'));
  }
  return null;
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

/// Streams through [_Exec] for everything but [start].
class _ByteExec implements ServerByteExec {
  _ByteExec(this.exec, this.session);

  final _Exec exec;
  final ExecSession session;

  @override
  Future<ExecSession> start(String command) async => session;

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) => exec.run(script, entry: entry, env: env, stdin: stdin, onStdout: onStdout, onStderr: onStderr, cancel: cancel);
}

/// A command that prints nothing, and ends only when killed.
class _SilentSession implements ExecSession {
  final _out = StreamController<String>();
  final _err = StreamController<String>();
  final _done = Completer<int?>();
  final written = <List<int>>[];
  var killed = false;

  @override
  Stream<String> get stdout => _out.stream;

  @override
  Stream<String> get stderr => _err.stream;

  @override
  Future<void> write(List<int> data) async => written.add(data);

  @override
  Future<void> closeStdin() async {}

  @override
  Future<int?> get done => _done.future;

  @override
  void kill() {
    if (killed) return;
    killed = true;
    unawaited(_out.close());
    unawaited(_err.close());
    _done.complete(null);
  }
}

/// A command that says it is ready once it reads the go line.
class _ReadySession extends _SilentSession {
  @override
  Future<void> write(List<int> data) async {
    await super.write(data);
    if (utf8.decode(data, allowMalformed: true) == '${virtUploadGoLine()}\n') {
      _out.add('${virtUploadReadyMarker()}\n');
    }
  }
}

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
