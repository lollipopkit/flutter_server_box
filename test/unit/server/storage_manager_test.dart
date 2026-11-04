import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/admin/storage_manager.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/storage.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/src/rust/api/storage.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

final class _QueueExec implements CommandExec {
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

  test('every action builds a script in Rust', () {
    final actions = <StorageAction>[
      StorageAction.partition(device: '/dev/sdb'),
      StorageAction.format(device: '/dev/sdb', fstype: 'ext4', label: 'data', encrypt: true),
      StorageAction.mount(device: '/dev/sdb', mountpoint: '/mnt/data', persist: true, own: true),
      StorageAction.unmount(mountpoint: '/mnt/data'),
      StorageAction.createRaid(name: 'md0', level: 1, devices: ['/dev/sdb', '/dev/sdc']),
      StorageAction.addToRaid(array: 'md0', device: '/dev/sdb'),
      StorageAction.removeFromRaid(array: 'md0', device: '/dev/sdb'),
      StorageAction.deleteRaid(array: 'md0'),
      StorageAction.growRaid(array: 'md0', device: '/dev/sdb'),
      StorageAction.createPool(name: 'tank', layout: 'mirror', devices: ['/dev/sdb', '/dev/sdc']),
      StorageAction.addToPool(name: 'tank', layout: 'mirror', devices: ['/dev/sdb', '/dev/sdc']),
      StorageAction.scrubPool(name: 'tank'),
      StorageAction.destroyPool(name: 'tank'),
      StorageAction.replaceInPool(name: 'tank', old: '/dev/sdb', new_: '/dev/sdc'),
      StorageAction.attachToPool(name: 'tank', existing: '/dev/sdb', new_: '/dev/sdc'),
      StorageAction.addSpare(name: 'tank', devices: ['/dev/sdb']),
      StorageAction.removeFromPool(name: 'tank', device: '/dev/sdb'),
      StorageAction.onlineInPool(name: 'tank', device: '/dev/sdb'),
      StorageAction.expandFilesystem(device: '/dev/sdb'),
      StorageAction.growPartition(device: '/dev/sdb1'),
      StorageAction.unlock(device: '/dev/sdb'),
      StorageAction.lock(device: '/dev/sdb'),
      StorageAction.smartTest(device: '/dev/sdb', long: false),
    ];

    for (final action in actions) {
      expect(
        () => ffi.storageActionScript(
          action: action,
          passphrase: ffi.storageActionNeedsKey(action: action) ? 'long enough passphrase' : null,
        ),
        returnsNormally,
        reason: '$action',
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
        StorageAction.format(device: '/dev/sda1', fstype: 'ext4', encrypt: false),
        isRoot: false,
      ),
      throwsA(
        isA<StorageRefused>()
            .having((error) => error.refusal.error, 'error', 'inUse')
            .having((error) => error.refusal.device, 'device', '/dev/sda1'),
      ),
    );
    expect(exec.scripts, [ffi.storageViewScript()]);
  });

  test('sudo refusing a non-root caller is SudoRejected, an exit 2 is not', () async {
    final refused = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
      const ExecResult(exitCode: 1, stdout: '', stderr: 'sudo: a password is required'),
    ]);
    await expectLater(
      StorageManager.act(
        refused,
        StorageAction.format(device: '/dev/sdb', fstype: 'ext4', encrypt: false),
        isRoot: false,
      ),
      throwsA(isA<SudoRejected>()),
    );

    final nonRoot = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
      const ExecResult(exitCode: 2, stdout: '', stderr: 'operation failed'),
    ]);
    await expectLater(
      StorageManager.act(
        nonRoot,
        StorageAction.format(device: '/dev/sdb', fstype: 'ext4', encrypt: false),
        isRoot: false,
      ),
      throwsA(isA<StorageCommandFailed>()),
    );

    final root = _QueueExec([
      const ExecResult(exitCode: 0, stdout: _view, stderr: ''),
      const ExecResult(exitCode: 2, stdout: '', stderr: 'ordinary failure'),
    ]);
    await expectLater(
      StorageManager.act(
        root,
        StorageAction.format(device: '/dev/sdb', fstype: 'ext4', encrypt: false),
        isRoot: true,
      ),
      throwsA(isA<StorageCommandFailed>()),
    );
  });
}
