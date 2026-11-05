import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/admin/custom_cmd_manager.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

final class _QueueExec implements CommandExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

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

ExecResult _ok(String stdout) =>
    ExecResult(exitCode: 0, stdout: stdout, stderr: '');

void main() {
  setUpAll(initRustLibForTest);

  const cmds = [
    ffi.CustomCmd(name: 'up', cmd: 'uptime'),
    ffi.CustomCmd(name: 'who', cmd: 'w'),
  ];

  /// What the read command prints for [cmds], in that order.
  String listingOf(List<ffi.CustomCmd> cmds) => [
    'SrvBoxCusCmdDir',
    for (final (i, c) in cmds.indexed)
      '${'${(i + 1) * 100}'.padLeft(5, '0')}'
          '_${base64Url.encode(utf8.encode(c.name))} '
          '${base64.encode(utf8.encode(c.cmd))}',
    'SrvBoxCusCmdDirEnd',
    '',
  ].join('\n');

  test('an absent directory lists as none', () async {
    final exec = _QueueExec([_ok('')]);

    expect(await CustomCmdManager.list(exec, SystemType.linux), isEmpty);
    expect(
      exec.scripts.single,
      ffi.readCustomCmdsCommand(system: SystemType.linux.ffi),
    );
    expect(exec.entries.single, 'sh');
  });

  test('an empty directory lists as none', () async {
    final exec = _QueueExec([_ok(listingOf(const []))]);

    expect(await CustomCmdManager.list(exec, SystemType.linux), isEmpty);
  });

  test('a listing comes back in order', () async {
    final exec = _QueueExec([_ok(listingOf(cmds))]);

    final got = await CustomCmdManager.list(exec, SystemType.linux);

    expect([for (final c in got) (c.name, c.cmd)], [
      ('up', 'uptime'),
      ('who', 'w'),
    ]);
  });

  test('a save writes every command in one run', () async {
    final exec = _QueueExec([_ok('')]);

    await CustomCmdManager.save(exec, SystemType.linux, cmds);

    expect(
      exec.scripts.single,
      ffi.installCustomCmdsCommand(system: SystemType.linux.ffi, cmds: cmds),
    );
    expect(exec.entries.single, 'sh');
  });

  test('a failed read throws instead of listing none', () async {
    final exec = _QueueExec([
      ExecResult(exitCode: 1, stdout: '', stderr: 'permission denied'),
    ]);

    await expectLater(
      CustomCmdManager.list(exec, SystemType.linux),
      throwsA(
        isA<CommandFailed>().having(
          (e) => '$e',
          'message',
          'permission denied',
        ),
      ),
    );
  });

  test('a failed save throws', () async {
    final exec = _QueueExec([
      ExecResult(exitCode: 1, stdout: '', stderr: 'read-only file system'),
    ]);

    await expectLater(
      CustomCmdManager.save(exec, SystemType.linux, cmds),
      throwsA(isA<CommandFailed>()),
    );
  });

  test('Windows runs the command as it is', () async {
    final exec = _QueueExec([_ok('')]);

    await CustomCmdManager.save(exec, SystemType.windows, cmds);

    expect(exec.entries.single, isNull);
  });
}
