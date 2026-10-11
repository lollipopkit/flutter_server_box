import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/storage.dart';
import 'package:server_box/data/service/storage_manager.dart';
import 'package:server_box/src/rust/api/storage.dart' as ffi;

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

const _view = '''
### lsblk
{"blockdevices":[
 {"name":"sda","path":"/dev/sda","type":"disk","size":500000000000,"model":"Test SSD","serial":"S1","rota":false,"tran":"nvme","rm":false,"ro":false,"fstype":null,"label":null,"uuid":null,"mountpoints":[null],"fsavail":null,"fsused":null,"children":[
  {"name":"sda1","path":"/dev/sda1","type":"part","size":500000000000,"fstype":"ext4","label":"root","uuid":"u1","mountpoints":["/"],"fsavail":"400000000000","fsused":"100000000000","rota":false,"rm":false,"ro":false}
 ]},
 {"name":"sdb","path":"/dev/sdb","type":"disk","size":4000000000,"rota":false,"rm":false,"ro":false,"mountpoints":[null]}
]}
### mdstat
### zpool
### zstatus
### tools
sfdisk
mkfs.ext4
''';

void main() {
  setUpAll(initRustLibForTest);

  test('view runs the Rust script through sh and parses a real view', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
    ]);

    final view = await StorageManager.view(exec);

    expect(exec.scripts, [ffi.storageViewScript()]);
    expect(exec.entries, ['sh']);
    expect(view.disks, hasLength(2));
    expect(view.disks.first.model, 'Test SSD');
    expect(view.find('/dev/sda1')?.fstype, 'ext4');
    expect(view.system, ['/dev/sda1']);
    expect(view.busy['/dev/sda1'], 'mounted');
  });

  test('every action constructor serializes to a Rust-recognized payload', () {
    final actions = <StorageAction>[
      StorageAction.partition('/dev/sdb'),
      StorageAction.format('/dev/sdb', 'ext4', label: 'data', encrypt: true),
      StorageAction.mount('/dev/sdb', '/mnt/data'),
      StorageAction.unmount('/mnt/data'),
      StorageAction.createRaid('md0', 1, ['/dev/sdb', '/dev/sdc']),
      StorageAction.addToRaid('md0', '/dev/sdb'),
      StorageAction.removeFromRaid('md0', '/dev/sdb'),
      StorageAction.deleteRaid('md0'),
      StorageAction.growRaid('md0', '/dev/sdb'),
      StorageAction.createPool('tank', 'mirror', ['/dev/sdb', '/dev/sdc']),
      StorageAction.addToPool('tank', 'mirror', ['/dev/sdb', '/dev/sdc']),
      StorageAction.scrubPool('tank'),
      StorageAction.destroyPool('tank'),
      StorageAction.replaceInPool('tank', '/dev/sdb', '/dev/sdc'),
      StorageAction.attachToPool('tank', '/dev/sdb', '/dev/sdc'),
      StorageAction.addSpare('tank', ['/dev/sdb']),
      StorageAction.removeFromPool('tank', '/dev/sdb'),
      StorageAction.onlineInPool('tank', '/dev/sdb'),
      StorageAction.expandFilesystem('/dev/sdb'),
      StorageAction.growPartition('/dev/sdb1'),
      StorageAction.unlock('/dev/sdb'),
      StorageAction.lock('/dev/sdb'),
      StorageAction.smartTest('/dev/sdb'),
    ];

    for (final action in actions) {
      final json = jsonEncode(action.toJson());
      expect(action.toJson()['action'], isA<String>());
      expect(
        () => ffi.storageActionScript(
          actionJson: json,
          passphrase: action.json['encrypt'] == true ||
                  action.json['action'] == 'unlock'
              ? 'long enough passphrase'
              : null,
        ),
        returnsNormally,
        reason: json,
      );
    }
  });

  test('act refuses a fresh view that says a device is in use', () async {
    final exec = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
    ]);

    await expectLater(
      StorageManager.act(
        exec,
        StorageAction.format('/dev/sda1', 'ext4'),
        isRoot: false,
      ),
      throwsA(
        isA<StorageManagerException>()
            .having((error) => error.code, 'code', 'inUse')
            .having((error) => error.device, 'device', '/dev/sda1'),
      ),
    );
    expect(exec.scripts, [ffi.storageViewScript()]);
  });

  test('exit code two is sudo rejection only for a non-root caller', () async {
    final nonRoot = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
      const ExecResult(exitCode: 2, stdout: '', stderr: 'operation failed'),
    ]);
    await expectLater(
      StorageManager.act(
        nonRoot,
        StorageAction.format('/dev/sdb', 'ext4'),
        isRoot: false,
      ),
      throwsA(isA<StorageManagerException>().having(
        (error) => error.code,
        'code',
        'sudo_rejected',
      )),
    );

    final root = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
      const ExecResult(exitCode: 2, stdout: '', stderr: 'ordinary failure'),
    ]);
    await expectLater(
      StorageManager.act(
        root,
        StorageAction.format('/dev/sdb', 'ext4'),
        isRoot: true,
      ),
      throwsA(isA<StorageManagerException>().having(
        (error) => error.code,
        'code',
        'failed',
      )),
    );
  });
}
