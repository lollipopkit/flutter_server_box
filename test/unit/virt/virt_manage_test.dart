/// Managing storage and networks: what crosses to the rules a change is
/// checked with (`sbm_virt::resource`, tested in Rust), and
/// `LibvirtBackend`'s side of it — a change checked against the host's lists
/// read for it, how the host's answers read, and the streamed upload over a
/// scripted byte channel: the sudo password ahead of the file, the go line,
/// a retry when sudo did not ask, a cancelled or refused upload deleting its
/// volume.
///
/// Scripts and parsers go through the real FFI: `cargo build -p sbm_ffi`
/// first.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/src/rust/api/script.dart' as script;
import 'package:server_box/src/rust/api/virt.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

const _dir = VirtStoragePool(
  id: 'images',
  name: 'images',
  type: 'dir',
  path: '/var/lib/libvirt/images',
  available: 10 << 30,
);
const _lvm = VirtStoragePool(id: 'vg', name: 'vg', type: 'logical');
const _pveDir = VirtStoragePool(
  id: 'pve/local',
  name: 'local',
  node: 'pve',
  type: 'dir',
  content: ['iso', 'vztmpl', 'images'],
);

const _fixtures = 'crates/sbm_virt/tests/fixtures/libvirt';

String _fixture(String name) => File('$_fixtures/$name').readAsStringSync();

String _marker(String key) =>
    script.scriptSegmentMarker(key: key, custom: false);

String _section(String key, String body, [int rc = 0]) =>
    '${_marker(key)}\n$body\nSbVirtRc=$rc\n';

void main() {
  setUpAll(initRustLibForTest);

  group('rules', () {
    // The rules themselves are `sbm_virt::resource`'s, tested there
    // (`crates/sbm_virt/tests/resource.rs`); this is what crosses.
    test('a change counts what it names among the host\'s lists', () {
      const used = VirtVolume(
        id: 'a',
        name: 'a',
        capacity: 1 << 30,
        users: [VirtGuestRef(guestId: 'u', device: 'vda')],
      );
      expect(
        virtResourceIssue(const VirtVolumeDelete(_dir, used), host: VirtHostKind.libvirt),
        VirtResIssue.inUse,
      );
      expect(
        virtResourceIssue(
          const VirtNetworkCreate(name: 'default', mode: 'isolated'),
          host: VirtHostKind.libvirt,
          networks: const [VirtNetwork(id: 'default', name: 'default', mode: 'nat')],
        ),
        VirtResIssue.nameTaken,
      );
      expect(
        virtResourceIssue(const VirtNetworkApply('pve'), host: VirtHostKind.libvirt),
        VirtResIssue.unsupported,
      );
      expect(
        virtResourceIssue(
          const VirtNetworkEditBridge(
            VirtNetwork(
              id: 'pve/vmbr0',
              name: 'vmbr0',
              node: 'pve',
              mode: 'bridge',
              managementEditable: false,
            ),
            ports: 'nic1',
          ),
          host: VirtHostKind.pve,
        ),
        VirtResIssue.managementIface,
      );
      expect(VirtResIssue.ofRust('management_iface'), VirtResIssue.managementIface);
      expect(VirtResIssue.ofRust(null), isNull);
    });

    test('what a form offers', () {
      expect(virtDefaultDhcpRange('192.168.150.1/24'), ('192.168.150.100', '192.168.150.200'));
      expect(virtDefaultDhcpRange('bad'), isNull);
      expect(virtVolumeFormats(_dir), ['qcow2', 'raw']);
      expect(virtVolumeFormats(_lvm), ['raw']);
      expect(virtVolumeFileName(_pveDir, 'vm-105-disk-0', 'qcow2'), 'vm-105-disk-0.qcow2');
      expect(virtPveVolumeVmid('vm-105-disk-0.qcow2'), 105);
      expect(virtPveVolumeVmid('debian.iso'), isNull);
      expect(virtUploadIssue(_dir, 'x.iso', 20 << 30), VirtResIssue.space);
      expect(virtUploadIssue(_dir, 'a b.iso', 1), VirtResIssue.nameInvalid);
      expect(virtPoolTakesMedia(_pveDir), isTrue);
      expect(virtVolumeResizable(_lvm, VirtHostKind.libvirt), isFalse);
      expect(virtVolumeResizable(_dir, VirtHostKind.libvirt), isTrue);
    });
  });

  group('libvirt', () {
    /// A host whose listings are the captured ones, answering every change
    /// with [change].
    _Exec host(ExecResult Function(_Call call) change) => _Exec((call) {
      final s = call.script;
      if (s.contains('pool-list')) return _ok(_fixture('script_storage.txt'));
      if (s.contains("vol-dumpxml --pool 'images'")) {
        return _ok(_fixture('script_volumes_images.txt'));
      }
      if (s.contains("vol-dumpxml --pool 'sbx-iso'")) {
        return _ok(_fixture('script_volumes_sbx_iso.txt'));
      }
      if (s.contains('net-list')) return _ok(_fixture('script_networks.txt'));
      return change(call);
    });

    String changeScript(_Exec exec) => exec.calls
        .map((c) => c.script)
        .lastWhere((s) => !s.contains('pool-list') && !s.contains('vol-dumpxml') && !s.contains('net-list'));

    test('a change is checked against the host\'s lists, then its script runs', () async {
      final exec = host((_) => _ok(_section('virt.res.step', '')));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      await virt.manage(const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/p'));
      expect(changeScript(exec), contains('pool-define'));
      await virt.manage(const VirtVolumeCreate(_dir, name: 'a.qcow2', gib: 2, format: 'qcow2'));
      expect(changeScript(exec), contains('--capacity ${2 << 30}B'));
      // `cirros.img` is what the guests' disks are made on: refused before
      // anything is sent.
      final calls = exec.calls.length;
      final e = await _err(
        virt.manage(const VirtVolumeDelete(_dir, VirtVolume(id: 'cirros.img', name: 'cirros.img'))),
      );
      expect(e.type, VirtErrType.unsupported);
      expect(e.message, l10n.virtVolInUse);
      expect(exec.calls.skip(calls).map((c) => c.script).where((s) => s.contains('vol-delete')), isEmpty);
      // A network the host lists by that name.
      final taken = await _err(virt.manage(const VirtNetworkCreate(name: 'default', mode: 'isolated')));
      expect(taken.type, VirtErrType.exists);
      expect(() => virt.manage(const VirtNetworkApply('pve')), throwsA(isA<VirtErr>()));
    });

    test('an existing network\'s edit is the network module\'s script', () async {
      const xml =
          '<network>\n'
          '  <name>default</name>\n'
          "  <forward mode='nat'/>\n"
          "  <bridge name='virbr0'/>\n"
          "  <ip address='192.168.122.1' prefix='24'>\n"
          '    <dhcp>\n'
          "      <range start='192.168.122.2' end='192.168.122.254'/>\n"
          '    </dhcp>\n'
          '  </ip>\n'
          '</network>\n';
      const net = VirtNetwork(id: 'default', name: 'default', mode: 'nat', active: true, xml: xml);
      final exec = host((_) => _ok(_section('virt.net.step', '')));
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      await virt.manage(
        const VirtNetworkEdit(
          net,
          mode: 'nat',
          address: '192.168.151.1',
          prefix: 24,
          dhcpStart: '192.168.151.100',
          dhcpEnd: '192.168.151.200',
          hosts: [VirtNetHost(mac: '52:54:00:AA:BB:01', ip: '192.168.151.10', name: 'h1')],
        ),
      );
      // The address moves, so the static hosts go into the definition with
      // it: `net-update` would check them against the old subnet.
      expect(changeScript(exec), contains('net-define'));
      expect(changeScript(exec), isNot(contains('net-update')));
      await virt.manage(const VirtNetworkRestart(net));
      expect(changeScript(exec), allOf(contains('net-destroy'), contains('net-start')));
    });

    test('a network change the host refuses reaches the caller', () async {
      // The start refused, and the network started again as it ran: an
      // error, never a success.
      final exec = host(
        (_) => _ok(
          [
            _section('virt.net.step', ''),
            _section(
              'virt.net.step',
              'error: Failed to start network default\nerror: internal error: Network is already in use by interface eth0',
              1,
            ),
            '${_marker('virt.net.rollback')}\n${_marker('virt.net.restored')}\n',
          ].join(),
        ),
      );
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      const net = VirtNetwork(
        id: 'default',
        name: 'default',
        mode: 'nat',
        active: true,
        xml: '<network>\n  <name>default</name>\n</network>\n',
      );
      final e = await _err(virt.manage(const VirtNetworkRestart(net)));
      expect(e.message, contains('started again as it ran before'));
    });

    test('a name taken on the host is exists; a refusal is the host\'s words', () async {
      final exec = host(
        (_) => _ok(_section('virt.res.step', "error: operation failed: pool 'p' already exists with uuid 1", 1)),
      );
      final virt = LibvirtBackend(serverId: 's', exec: () async => exec);
      final e = await _err(virt.manage(const VirtPoolCreate(name: 'p', type: 'dir', source: '/srv/p')));
      expect(e.type, VirtErrType.exists);
      expect(exec.calls.last.entry, 'sh');

      final refused = LibvirtBackend(
        serverId: 's',
        exec: () async => host(
          (_) => _ok(_section('virt.res.step', 'error: Requested operation is not valid: storage pool is not empty', 1)),
        ),
      );
      const off = VirtStoragePool(id: 'sbx-off', name: 'sbx-off', type: 'dir', active: false);
      final e2 = await _err(refused.manage(const VirtPoolDelete(off, deleteStorage: true)));
      expect(e2.type, VirtErrType.actionFailed);
      expect(e2.message, contains('not empty'));
    });

    test('upload: the go line, then the file; progress; done', () async {
      final exec = _Exec((_) => _ok(_section('virt.res.step', '')));
      final bytes = _Bytes();
      final remote = _Remote();
      final virt = _backend(exec, remote);
      final sent = <int>[];
      expect(
        await virt.upload(
          VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
          onProgress: sent.add,
        ),
        isTrue,
      );
      expect(remote.sessions.single.command, startsWith("sh -c 'eval"));
      expect(remote.sessions.single.file, bytes.all);
      expect(sent.last, bytes.size);
      // The volume first, raw and the file's size; nothing deleted after.
      expect(exec.calls.first.script, contains('vol-create-as'));
      expect(exec.calls.first.script, contains('--capacity ${bytes.size}B --format raw'));
      expect(exec.calls.map((c) => c.script).join(), isNot(contains('vol-delete')));
    });

    test('upload through sudo: the password is sudo\'s, never the volume\'s', () async {
      // Refused as this account, so sudo — with the password it was given.
      final exec = _Exec(
        (call) => call.entry == 'sh'
            ? _ok(_section('virt.res.step', 'error: authentication unavailable: polkit', 1))
            : _ok(_section('virt.res.step', '')),
      );
      final remote = _Remote(sudoAsks: true, password: 'pw');
      final virt = _backend(exec, remote)..provideSudoPassword('pw');
      final bytes = _Bytes();
      expect(
        await virt.upload(
          VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
        ),
        isTrue,
      );
      expect(remote.sessions.single.command, startsWith("sudo -S -p '' sh -c"));
      expect(remote.sessions.single.file, bytes.all);

      // sudo did not ask (cached, NOPASSWD): the script found the password
      // where the go line belongs and stopped; once more without it.
      final remote2 = _Remote(sudoAsks: false);
      final virt2 = _backend(exec, remote2)..provideSudoPassword('pw');
      expect(
        await virt2.upload(
          VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
        ),
        isTrue,
      );
      expect(remote2.sessions, hasLength(2));
      expect(remote2.sessions.first.file, isEmpty);
      expect(remote2.sessions.last.command, startsWith('sudo -n sh -c'));
      expect(remote2.sessions.last.file, bytes.all);
      expect(utf8.decode(remote2.sessions.last.file, allowMalformed: true), isNot(contains('pw\n')));
    });

    test('upload: a rejected password, a refusal and a cancel delete the volume', () async {
      final exec = _Exec(
        (call) => call.entry == 'sh'
            ? _ok(_section('virt.res.step', 'error: authentication unavailable: polkit', 1))
            : _ok(_section('virt.res.step', '')),
      );
      final bytes = _Bytes();
      final wrong = _backend(exec, _Remote(sudoAsks: true, password: 'right'))
        ..provideSudoPassword('wrong');
      final e = await _err(
        wrong.upload(VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open)),
      );
      expect(e.type, VirtErrType.sudoPasswordRejected);
      expect(exec.calls.last.script, contains('vol-delete'));

      final full = _backend(
        _Exec((_) => _ok(_section('virt.res.step', ''))),
        _Remote(refuse: 'error: cannot upload to volume x.iso: No space left on device'),
      );
      final e2 = await _err(
        full.upload(VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open)),
      );
      expect(e2.type, VirtErrType.actionFailed);
      expect(e2.message, contains('No space left'));

      final exec3 = _Exec((_) => _ok(_section('virt.res.step', '')));
      final remote3 = _Remote();
      final cancel = Completer<void>();
      final virt3 = _backend(exec3, remote3);
      final stopped = await virt3.upload(
        VirtUpload(pool: _dir, name: 'x.iso', size: bytes.size, open: bytes.open),
        cancel: cancel.future,
        onProgress: (n) {
          if (!cancel.isCompleted) cancel.complete();
        },
      );
      expect(stopped, isFalse);
      expect(remote3.sessions.single.killed, isTrue);
      expect(remote3.sessions.single.file.length, lessThan(bytes.size));
      expect(exec3.calls.last.script, contains('vol-delete'));
    });

    test('no byte channel: no upload offered, none made', () async {
      final virt = LibvirtBackend(
        serverId: 's',
        exec: () async => _Exec((_) => _ok('')),
        canStream: () => false,
        byteExec: () async => throw StateError('not called'),
      );
      final e = await _err(
        virt.upload(VirtUpload(pool: _dir, name: 'x.iso', size: 1, open: () => const Stream.empty())),
      );
      expect(e.type, VirtErrType.unsupported);
    });
  });
}

LibvirtBackend _backend(_Exec exec, _Remote remote) => LibvirtBackend(
  serverId: 's',
  exec: () async => exec,
  byteExec: () async => remote,
  canStream: () => true,
);

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
    return answer(call);
  }
}

/// A file of a few chunks.
class _Bytes {
  static const chunk = 1000;
  static const chunks = 5;
  int get size => chunk * chunks;
  List<int> get all => [
    for (var i = 0; i < size; i++) i & 0xff,
  ];
  Stream<List<int>> open() async* {
    for (var c = 0; c < chunks; c++) {
      yield [for (var i = 0; i < chunk; i++) (c * chunk + i) & 0xff];
    }
  }
}

/// The far side of the byte channel, as the upload command behaves there:
/// sudo reading its password line (when it asks), the script reading the go
/// line and saying it is ready, `vol-upload` taking the rest.
class _Remote implements ServerByteExec {
  _Remote({this.sudoAsks = false, this.password, this.refuse});

  final bool sudoAsks;
  final String? password;
  final String? refuse;
  final sessions = <_Session>[];

  @override
  Future<ExecSession> start(String command) async {
    final s = _Session(this, command);
    sessions.add(s);
    return s;
  }

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) => throw UnimplementedError();
}

class _Session implements ExecSession {
  _Session(this.remote, this.command);

  final _Remote remote;
  final String command;
  final _out = StreamController<String>.broadcast();
  final _err = StreamController<String>.broadcast();
  final _done = Completer<int?>();
  final _input = <int>[];
  final file = <int>[];
  var _phase = 0;
  var killed = false;

  bool get _sudoPassword => command.startsWith('sudo -S');

  @override
  Stream<String> get stdout => _out.stream;

  @override
  Stream<String> get stderr => _err.stream;

  @override
  Future<int?> get done => _done.future;

  String? _line() {
    final i = _input.indexOf(10);
    if (i < 0) return null;
    final line = utf8.decode(_input.sublist(0, i));
    _input.removeRange(0, i + 1);
    return line;
  }

  void _end(String out, int code) {
    if (_done.isCompleted) return;
    if (out.isNotEmpty) _out.add(out);
    scheduleMicrotask(() {
      _done.complete(code);
      unawaited(_out.close());
      unawaited(_err.close());
    });
  }

  @override
  Future<void> write(List<int> data) async {
    if (_done.isCompleted) throw StateError('closed');
    if (_phase == 2) {
      file.addAll(data);
      return;
    }
    _input.addAll(data);
    if (_phase == 0 && _sudoPassword && remote.sudoAsks) {
      final pw = _line();
      if (pw == null) return;
      if (pw != remote.password) {
        _err.add('Sorry, try again.\n');
        return;
      }
      _phase = 1;
    } else if (_phase == 0) {
      _phase = 1;
    }
    if (_phase == 1) {
      final go = _line();
      if (go == null) return;
      if (go != ffi.virtUploadGoLine()) {
        _end('${_marker('virt.upload.refused')}\n', 97);
        return;
      }
      _phase = 2;
      file.addAll(_input);
      _input.clear();
      _out.add('${ffi.virtUploadReadyMarker()}\n');
    }
  }

  @override
  Future<void> closeStdin() async {
    final refuse = remote.refuse;
    _end(
      refuse == null
          ? _section('virt.upload', '')
          : _section('virt.upload', refuse, 1),
      0,
    );
  }

  @override
  void kill() {
    if (_done.isCompleted) return;
    killed = true;
    _end('', 137);
  }
}
