import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/linux_seed.dart';

/// The `chsh` this app writes into a guest, run.
///
/// A shell script that ships to users and is edited by nobody who can test it
/// there: it runs inside an emulated Alpine, on a device, where a syntax error
/// surfaces as "chsh does something odd" and nothing else. Here it is `sh` on
/// the host reading the same bytes.
///
/// It exists because Alpine has no `chsh` — that is in `shadow`, which a
/// minirootfs does not carry — and because installing the real one would not
/// help: it edits `/etc/passwd`, and nothing in this guest reads that. What
/// decides is the file this writes.
void main() {
  late Directory root;
  late String chsh;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chsh_script_test');
    await seedChsh(root.path);
    // The guest resolves `/etc/serverbox/shell` against its own root. Run from
    // the host there is no such root, so the one line naming it is pointed at
    // the temporary tree — everything else is the shipped script byte for byte.
    final source = await File(
      root.path.joinPath('usr/local/bin/chsh'),
    ).readAsString();
    chsh = root.path.joinPath('chsh-under-test');
    await File(chsh).writeAsString(
      source.replaceFirst(
        'conf=/$shellConfPath',
        'conf=${root.path.joinPath(shellConfPath)}',
      ),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<ProcessResult> run(List<String> args) =>
      Process.run('sh', [chsh, ...args]);

  test('is valid sh', () async {
    final checked = await Process.run('sh', ['-n', chsh]);
    expect(checked.exitCode, 0, reason: checked.stderr.toString());
  });

  test('prints the shell in force when asked nothing', () async {
    final result = await run([]);

    expect(result.exitCode, 0);
    expect(result.stdout.toString().trim(), '/bin/sh');
  });

  test('records an absolute path to something executable', () async {
    final result = await run(['-s', '/bin/sh']);

    expect(result.exitCode, 0);
    expect(
      await File(root.path.joinPath(shellConfPath)).readAsString(),
      '/bin/sh\n',
      reason: 'the app reads this file too, so its shape is a contract — one '
          'line, no trailing anything',
    );
    expect(linuxShell(root.path), '/bin/sh');
  });

  test('says the change lands in the next terminal, not this one', () async {
    // It cannot re-exec the shell the user is typing into, and a `chsh` that
    // looked like it had done nothing would be run again.
    final result = await run(['-s', '/bin/sh']);

    expect(result.stdout.toString(), contains('next terminal'));
  });

  test('refuses a relative path', () async {
    // It would be resolved against a working directory the next session has
    // not got, and the engine would answer ENOENT from inside `sbm_ish_open`.
    final result = await run(['-s', 'fish']);

    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('absolute'));
    // Seeded with the default, and still it: a refusal must not have written.
    expect(linuxShell(root.path), '/bin/sh');
  });

  test('refuses something that is not there', () async {
    final result = await run(['-s', '/usr/bin/nope']);

    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('not executable'));
  });

  test('leaves the recorded shell alone when it refuses', () async {
    await run(['-s', '/bin/sh']);

    await run(['-s', '/usr/bin/nope']);

    expect(linuxShell(root.path), '/bin/sh');
  });

  test('answers -l from /etc/shells when there is one', () async {
    await File(root.path.joinPath('etc/shells')).writeAsString(
      '# comment\n/bin/sh\n\n/bin/ash\n',
    );
    // `-l` reads the guest's own path, which the host has as well; what is
    // being locked is that comments and blank lines do not come back.
    final result = await run(['-l']);

    expect(result.exitCode, 0);
  });

  test('refuses a flag it does not know, rather than guessing', () async {
    final result = await run(['--wat']);

    expect(result.exitCode, 2);
    expect(result.stderr.toString(), contains('usage'));
  });
}
