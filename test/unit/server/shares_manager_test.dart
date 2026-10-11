import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/shares.dart';
import 'package:server_box/data/service/shares_manager.dart';
import 'package:server_box/src/rust/api/shares.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

final class _QueueExec implements ServerExec {
  _QueueExec(Iterable<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final scripts = <String>[];
  final entries = <String?>[];

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
    scripts.add(script);
    entries.add(entry);
    return results.removeFirst();
  }
}

const _read = '''
### tools
smbd
testparm
smbpasswd
exportfs
### active
smbd
### smb
[media]
 path = /srv/media
 read only = no
 guest ok = yes
### smbManaged
[media]
 path = /srv/media
### nfs
/srv/other *(ro,sync,root_squash)
### nfsManaged
"/srv/managed" 192.168.1.0/24(rw,sync,no_subtree_check,root_squash)
''';

void main() {
  setUpAll(initRustLibForTest);

  test('read parses shares and managed status through Rust', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _read, stderr: ''),
    ]);

    final view = await SharesManager.read(exec);

    expect(exec.scripts, [ffi.sharesReadScript()]);
    expect(exec.entries, ['sh']);
    expect(view.smbActive, isTrue);
    expect(view.smb.single.managed, isTrue);
    expect(view.nfs.map((e) => e.managed), [false, true]);
  });

  test('setSmb sends only managed shares back', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
      const ExecResult(exitCode: 0, stdout: _read, stderr: ''),
    ]);
    const managed = SmbShare(
      name: 'photos',
      path: '/srv/photos',
      comment: null,
      readOnly: true,
      guest: false,
      users: [],
      timeMachine: false,
      recycle: false,
      managed: true,
    );
    const external = SmbShare(
      name: 'external',
      path: '/srv/external',
      comment: null,
      readOnly: true,
      guest: false,
      users: [],
      timeMachine: false,
      recycle: false,
      managed: false,
    );

    await SharesManager.setSmb(
      exec,
      [managed, external],
      isRoot: true,
    );

    expect(exec.scripts[0], ffi.sharesSmbScript(sharesJson: '[${_jsonShare(managed)}]'));
    expect(exec.scripts[1], ffi.sharesReadScript());
  });

  test('NFS writes only managed exports and maps path/refusal exit codes', () async {
    const managed = NfsExport(
      path: '/srv/managed',
      clients: [
        NfsClient(host: '*', readOnly: false, squash: 'root', options: []),
      ],
      managed: true,
    );
    const external = NfsExport(path: '/srv/external', clients: [], managed: false);
    final success = _QueueExec([
      const ExecResult(exitCode: 0, stdout: '', stderr: ''),
      const ExecResult(exitCode: 0, stdout: _read, stderr: ''),
    ]);
    await SharesManager.setNfs(success, [managed, external], isRoot: true);
    expect(success.scripts.first, contains('"/srv/managed"'));
    expect(success.scripts.first, isNot(contains('/srv/external')));

    final notFolder = _QueueExec([
      ExecResult(
        exitCode: ffi.sharesExitNotAFolder(),
        stdout: '',
        stderr: '/srv/missing\r\nmore detail\n',
      ),
    ]);
    await expectLater(
      SharesManager.setNfs(notFolder, [managed], isRoot: true),
      throwsA(
        isA<SharesManagerException>()
            .having((error) => error.code, 'code', 'notAFolder')
            .having((error) => error.path, 'path', '/srv/missing'),
      ),
    );

    final refused = _QueueExec([
      const ExecResult(
        exitCode: 4,
        stdout: '',
        stderr: 'earlier\nconfiguration rejected\n',
      ),
    ]);
    await expectLater(
      SharesManager.setNfs(refused, [managed], isRoot: true),
      throwsA(
        isA<SharesManagerException>()
            .having((error) => error.code, 'code', 'refused')
            .having((error) => error.detail, 'detail', 'configuration rejected'),
      ),
    );
  });

  test('exit code two is sudo rejection only for non-root', () async {
    const share = SmbShare(
      name: 'photos',
      path: '/srv/photos',
      comment: null,
      readOnly: true,
      guest: false,
      users: [],
      timeMachine: false,
      recycle: false,
      managed: true,
    );
    final nonRoot = _QueueExec([
      const ExecResult(exitCode: 2, stdout: '', stderr: 'ordinary failure'),
    ]);
    await expectLater(
      SharesManager.setSmb(nonRoot, [share], isRoot: false),
      throwsA(isA<SharesManagerException>().having(
        (error) => error.code,
        'code',
        'sudo_rejected',
      )),
    );

    final root = _QueueExec([
      const ExecResult(exitCode: 2, stdout: '', stderr: 'ordinary failure'),
    ]);
    await expectLater(
      SharesManager.setSmb(root, [share], isRoot: true),
      throwsA(isA<SharesManagerException>().having(
        (error) => error.code,
        'code',
        'failed',
      )),
    );
  });
}

String _jsonShare(SmbShare share) =>
    '{"name":"${share.name}","path":"${share.path}","comment":null,"read_only":true,"guest":false,"users":[],"time_machine":false,"recycle":false,"managed":true}';
