/// `LibvirtBackend` over a scripted `ServerExec` that answers with the
/// `sbm_parser` virt fixtures: mapping, rates across two samples, the sudo
/// retry, a server without virsh, and snapshots, storage, networks and
/// hardware against the captured script outputs.
///
/// Parsing goes through the real FFI: `cargo build -p sbm_ffi` first.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/libvirt.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/src/rust/api/virt.dart' show parseVirtHardwareJson;

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
        contains("V snapshot-delete --domain '$_run' --snapshotname 'pre-up'"),
      );
      // A name the form would not allow never reaches the host.
      final calls = exec.calls.length;
      final e = await _err(virt.createSnapshot(web, name: "x'; reboot"));
      expect(e.type, VirtErrType.unsupported);
      expect(exec.calls, hasLength(calls));
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
    VirtCreateSpec spec({bool start = true}) => VirtCreateSpec(
      kind: VirtGuestKind.qemu,
      name: 'sbm-create-test',
      cores: 1,
      memoryMiB: 256,
      storage: images,
      diskGiB: 1,
      media: const VirtVolume(
        id: 'sbm-test.iso',
        name: 'sbm-test.iso',
        path: '/var/lib/libvirt/images/sbm-test.iso',
      ),
      network: const VirtNetwork(id: 'default', name: 'default', mode: 'nat'),
      start: start,
    );

    /// The host as captured (libvirt 11.3), [volume] and [define] the
    /// answers to the second and third steps.
    _Exec createExec({
      String volume = 'script_create_volume.txt',
      String define = 'script_define_ok.txt',
    }) => _Exec((call) {
      if (call.script.contains('domcapabilities')) {
        return _ok(_fixture('script_create_host.txt'));
      }
      if (call.script.contains('vol-create-as')) return _ok(_fixture(volume));
      if (call.script.contains('define --file')) return _ok(_fixture(define));
      return _fail('unexpected script');
    });

    test('three steps: the host, the disk, the domain on its path', () async {
      final exec = createExec();
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final created = await virt.create(spec());

      expect(created.id, 'be27edda-481c-401d-88df-57e7b8756364');
      expect(created.startError, isNull);
      expect(exec.calls, hasLength(3));
      expect(exec.calls.map((c) => c.entry), everyElement('sh'));
      final volume = exec.calls[1].script;
      expect(volume, contains("--name 'sbm-create-test.qcow2' --capacity 1G --format qcow2"));
      final define = exec.calls[2].script;
      // KVM on q35 as the host said, the disk by the path it gave, the ISO
      // by its own.
      expect(define, contains('machine='));
      expect(define, contains('pc-q35-10.0'));
      expect(define, contains('/var/lib/libvirt/images/sbm-create-test.qcow2'));
      expect(define, contains('/var/lib/libvirt/images/sbm-test.iso'));
      expect(define, contains("R start --domain 'sbm-create-test'"));
    });

    test('a name already defined is exists, and nothing is defined', () async {
      final exec = createExec(volume: 'script_create_volume_exists.txt');
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(virt.create(spec()));
      expect(e.type, VirtErrType.exists);
      expect(e.message, isNull);
      expect(exec.calls, hasLength(2));
    });

    test('a define the host refuses is actionFailed, with its words', () async {
      final exec = createExec(define: 'script_define_rollback.txt');
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(virt.create(spec(start: false)));
      expect(e.type, VirtErrType.actionFailed);
      expect(e.message, contains('No PCI buses available'));
      expect(exec.calls[2].script, contains('vol-delete'));
      expect(exec.calls[2].script, isNot(contains('R start')));
    });

    test('media without a path is refused before the host is asked', () async {
      final exec = createExec();
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final s = spec();
      final e = await _err(
        virt.create(
          VirtCreateSpec(
            kind: s.kind,
            name: s.name,
            cores: 1,
            memoryMiB: 256,
            storage: images,
            diskGiB: 1,
            media: const VirtVolume(id: 'x.iso', name: 'x.iso'),
          ),
        ),
      );
      expect(e.type, VirtErrType.invalidResponse);
      expect(exec.calls, isEmpty);
    });

    test('delete: a running guest is refused, a stopped one undefined '
        'with its writable disks only', () async {
      final exec = _Exec((call) {
        if (call.script.contains('domstats')) return _ok(_overview());
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
      expect(exec.calls.where((c) => c.script.contains('dumpxml')), hasLength(1));
    });
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
      // A base image only others are layered on is not "used" by a disk.
      expect(vols.firstWhere((v) => v.name == 'cirros.img').users, isEmpty);

      final iso = await virt.volumes(pools[1]);
      expect(iso.first.name, 'my disk.qcow2');
      final tiny = iso.firstWhere((v) => v.name == 'tiny.iso');
      expect(tiny.users, [const VirtGuestRef(guestId: _odd, device: 'hdc')]);
      expect(await virt.volumes(pools.last), isEmpty);
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
      expect((s.uefi, s.secureBoot, s.tpm, s.usb, s.pci, s.listen, s.mac), (true, true, false, true, true, true, true));
      expect(hw.firmware, const VirtHwFirmware(uefi: false));
      expect(hw.display, const VirtHwDisplay(protocol: 'vnc', listen: '127.0.0.1', gpu: 'virtio'));
      // Without them: the common ground, and nothing the host may lack.
      final bare = LibvirtBackend.supportOf(null);
      expect((bare.uefi, bare.tpm, bare.pci), (false, false, false));
      expect(bare.buses, contains('virtio'));
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

    test('host devices: root hubs left out, no IOMMU said', () async {
      final exec = _Exec((_) => _ok(_fixture('script_host_devices.txt')));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final devs = await virt.hostDevices(guest);
      expect(devs.iommu, isFalse);
      expect(devs.usb, isEmpty);
      expect(devs.pci.firstWhere((p) => p.id == '0000:00:01.2').label, contains('PIIX3 USB'));
    });
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
