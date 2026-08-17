import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';

/// The Linux userland, through the API the app actually uses.
///
/// `android_rootfs_test.dart` measured whether the mechanism can work at all,
/// with everything staged by hand. This exercises the shipped thing:
/// [AndroidRootfs] finds proot and installs a rootfs, and
/// [LocalShellBackend] opens a shell inside it — the same call the terminal
/// tab makes.
///
/// Skipped where there is no proot to run: a build that did not run
/// `scripts/build-proot-android.sh`, or a device that is not arm64.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // `LocalShellBackend` reads `Paths.doc` for a home directory.
    await Paths.init(BuildData.name, bakName: Miscs.bakFileName);
    await AndroidRootfs.prepare();
    // A real install every run. A rootfs left by a previous run would let a
    // change to how one is unpacked pass untested for as long as the device
    // kept the old one.
    await AndroidRootfs.remove();
  });

  /// Everything [session] prints until it ends, or until [timeout] passes with
  /// [until] still unseen.
  Future<String> readUntil(
    ShellSession session,
    String until, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final seen = StringBuffer();
    final done = Completer<String>();
    void finish() {
      if (!done.isCompleted) done.complete(seen.toString());
    }

    session.stdout?.listen((chunk) {
      seen.write(utf8.decode(chunk, allowMalformed: true));
      if (seen.toString().contains(until)) finish();
    }, onDone: finish);
    unawaited(session.done.then((_) => finish()));
    return done.future.timeout(timeout, onTimeout: () => seen.toString());
  }

  testWidgets('a shell runs inside the installed rootfs', (_) async {
    if (!AndroidRootfs.isAvailable) {
      markTestSkipped('this build carries no proot');
      return;
    }

    // Downloads on the first run, and is a no-op afterwards. Not in `setUpAll`:
    // installing *is* one of the things under test.
    await AndroidRootfs.install();
    expect(await AndroidRootfs.isInstalled, isTrue);

    // What makes it a distribution rather than a directory of files.
    final root = AndroidRootfs.root!;
    expect(await File(root.joinPath('etc/alpine-release')).exists(), isTrue);
    expect(await File(root.joinPath('bin/busybox')).exists(), isTrue);
    // A symlink, not a copy. `/bin/sh` is a name for busybox, and a rootfs
    // whose links became copies is one program pretending to be two hundred.
    expect(
      await FileSystemEntity.isLink(root.joinPath('bin/sh')),
      isTrue,
      reason: 'tar did not restore the rootfs symlinks',
    );

    final backend = LocalShellBackend(inRootfs: true);
    addTearDown(backend.close);

    // The one-shot path, which is what a snippet or the agent would use.
    final exec = await backend.execute(
      'cat /etc/alpine-release; uname -m',
      width: 80,
      height: 25,
      environment: AndroidRootfs.environment,
    );
    final reported = await readUntil(exec, 'aarch64');
    expect(reported, contains(AndroidRootfs.version));
    expect(reported, contains('aarch64'));

    // The interactive path, which is what the terminal tab opens. Typed at,
    // rather than given a command, because a shell that starts and then cannot
    // read its own terminal looks identical from the outside.
    final shell = await backend.openShell(
      width: 80,
      height: 25,
      environment: AndroidRootfs.environment,
    );
    addTearDown(shell.close);
    // Split so the echo of the command itself cannot be what matches, and read
    // to a marker printed *after* everything asked for — stopping at the first
    // one would end the read before the shell had finished answering.
    shell.write(utf8.encode('echo SBM_ROOT""FS_OK; id -un; echo SBM_""DONE\n'));
    final typed = await readUntil(shell, 'SBM_DONE');
    expect(typed, contains('SBM_ROOTFS_OK'));
    // proot's `-0`: every guest process believes it is root, which is what
    // makes `apk` work without any of it being true on the host.
    expect(typed, contains('root'));
  }, skip: !Platform.isAndroid);

  testWidgets('the Agent runs its commands inside the container', (_) async {
    if (!AndroidRootfs.isAvailable) {
      markTestSkipped('this build carries no proot');
      return;
    }
    await AndroidRootfs.install();

    // `ProcessExec`, not the terminal's backend: the Agent's shell tool goes
    // through this one, and until now nothing had ever run a command on this
    // device through it — see TODOS.md, "本机 shell 与 rootfs", stage 2b.
    const exec = ProcessExec(inRootfs: true);

    final release = await exec.run('cat /etc/alpine-release');
    expect(release.stdout.trim(), AndroidRootfs.version);
    expect(release.exitCode, 0);

    // The two streams stay apart, which is the whole reason this is pipes and
    // not a pty. A pty would have merged them.
    final split = await exec.run('echo out; echo err >&2');
    expect(split.stdout.trim(), 'out');
    expect(split.stderr.trim(), 'err');

    // And it is the container, not the phone: Android's own filesystem is not
    // visible from inside.
    final android = await exec.run(r'ls /system >/dev/null 2>&1; echo rc=$?');
    expect(android.stdout.trim(), 'rc=1');

    // The file tools resolve inside it too. They are `dart:io` on the host and
    // never enter the guest, so this mapping is the only thing that keeps them
    // in the same filesystem the commands see.
    final host = await AndroidRootfs.hostPathOf('/etc/alpine-release');
    expect(host, isNotNull);
    expect(await File(host!).readAsString(), startsWith(AndroidRootfs.version));

    // Android's own `/etc/hosts` exists, and the Agent must not reach it.
    await exec.run('ln -sf / /tmp/escape');
    expect(await AndroidRootfs.hostPathOf('/tmp/escape/etc/hosts'), isNull);
  }, skip: !Platform.isAndroid);

  testWidgets('a package manager works inside it', (_) async {
    if (!AndroidRootfs.isAvailable) {
      markTestSkipped('this build carries no proot');
      return;
    }
    await AndroidRootfs.install();

    final backend = LocalShellBackend(inRootfs: true);
    addTearDown(backend.close);

    // The point of a rootfs rather than a shell: it can be given more. Needs
    // the network, the resolver and the repository list seeded at install
    // time, so this covers all three — and it is what pins the Alpine branch,
    // for the reason recorded in [AndroidRootfs.version].
    final session = await backend.execute(
      'apk update >/dev/null 2>&1 && apk add --no-progress curl >/dev/null 2>&1;'
      ' curl --version | head -1',
      width: 80,
      height: 25,
      environment: AndroidRootfs.environment,
    );
    final out = await readUntil(
      session,
      'curl ',
      timeout: const Duration(minutes: 3),
    );
    expect(out, contains('curl '));
  }, skip: !Platform.isAndroid);
}
