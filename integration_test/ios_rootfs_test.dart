import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';

/// The Linux userland on iOS, through the API the app will use.
///
/// Inside a real app, which is the only place any of this is true: the engine
/// is linked into the app binary and reached by looking its symbols up in the
/// running process, so a plain `flutter test` would find nothing to call.
///
/// Skipped where the switch is off (`SBM_ISH = 0` in
/// `ios/Flutter/Ish.xcconfig`), which is the default — a checkout that has not
/// run `scripts/build-ish-ios.sh` has no engine to link.
///
/// The filesystem is staged by the harness, exactly as the first Android
/// measurement staged proot: `fakefsify` is a host tool, and putting one on a
/// device is a separate piece of work this does not pretend to have done.
Future<void> _copyDirectory(Directory from, Directory to) async {
  await to.create(recursive: true);
  // Links are copied as links, not followed. Under `realfs` a guest symlink is
  // resolved *inside the guest*, so `/bin/sh -> /bin/busybox` means the guest's
  // busybox; followed on the host it points at the host's `/bin`, which is
  // either the wrong file or none — and a skipped one is why the first attempt
  // booted to `ENOENT` with no `/bin/sh` to run.
  await for (final entry in from.list(recursive: false, followLinks: false)) {
    final name = entry.path.split('/').last;
    if (entry is Link) {
      await Link('${to.path}/$name').create(await entry.target());
    } else if (entry is Directory) {
      await _copyDirectory(entry, Directory('${to.path}/$name'));
    } else if (entry is File) {
      await entry.copy('${to.path}/$name');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Where `scripts/build-ish-ios.sh` leaves the filesystem it built.
  ///
  /// Reachable because a simulator shares the Mac's filesystem. On a device
  /// this line is the part that does not exist yet.
  const staged = String.fromEnvironment('ISH_FAKEFS');

  setUpAll(() => IosRootfs.prepare());

  testWidgets('the engine is there, or says it is not', (_) async {
    // Not an assertion either way: this test runs on a build that may have
    // been made with the switch off, and that is a valid build.
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    expect(IosRootfs.root, isNotNull);
  }, skip: !Platform.isIOS);

  /// Everything one session prints, to a marker or until it ends.
  Future<String> readTo(int session, String until) async {
    final output = StringBuffer();
    for (var round = 0; round < 400; round++) {
      final chunk = IosRootfs.read(session, timeout: Duration.zero);
      if (chunk == null) break;
      output.write(chunk);
      if (output.toString().contains(until)) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return output.toString();
  }

  testWidgets('a guest runs inside the app and answers', (_) async {
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    if (staged.isEmpty) {
      markTestSkipped(
        'no filesystem staged; pass --dart-define=ISH_FAKEFS=<path>',
      );
      return;
    }

    // Copied into the app's own container, because that is where it will live
    // and because the guest writes to it.
    //
    // In Dart rather than `/bin/cp`: iOS refuses to start a process at all,
    // even in the simulator — "Starting new processes is not supported on
    // iOS", which is the whole reason this platform gets an interpreter
    // instead of a rootfs and proot.
    final root = Directory(IosRootfs.root!);
    if (!await root.exists()) {
      await _copyDirectory(Directory(staged), root);
    }
    expect(await IosRootfs.isInstalled, isTrue);

    final booted = IosRootfs.boot();
    expect(booted == 0 || booted == -17, isTrue, reason: 'boot returned $booted');

    // A session is a process in the machine, on a pty of its own.
    final one = IosRootfs.open(
      command: r'cat /etc/alpine-release; uname -m; id -un; echo "SBM""_IOS_OK"',
    );
    expect(one, greaterThanOrEqualTo(0), reason: 'open returned $one');
    final text = await readTo(one, 'SBM_IOS_OK');
    debugPrint('ISHPROBE one=${text.trim()}');
    expect(text, contains(IosRootfs.version));
    expect(text, contains('aarch64'));
    expect(text, contains('root'));

    // A second session, at the same time, with its own output. This is what
    // one shared console could not do, and what the Agent needs so its command
    // does not land in somebody's terminal.
    final two = IosRootfs.open(command: r'echo "SBM""_SECOND"; sleep 1');
    expect(two, greaterThanOrEqualTo(0), reason: 'open returned $two');
    expect(two, isNot(one));
    final second = await readTo(two, 'SBM_SECOND');
    debugPrint('ISHPROBE two=${second.trim()}');
    expect(second, contains('SBM_SECOND'));
    // Each session sees only its own: the first one's marker is not in here.
    expect(second, isNot(contains('SBM_IOS_OK')));

    IosRootfs.close(one);
    IosRootfs.close(two);
  }, skip: !Platform.isIOS);

  // `/dev` is the one filesystem here that is a database, and the only one
  // that can be: `realfs` cannot hold a device node and `tmpfs` has no `mknod`
  // at all. A dozen nodes is a few kilobytes of sqlite — the whole tree's
  // metadata was the part worth refusing.
  testWidgets('/dev has what a userland expects', (_) async {
    if (!IosRootfs.isAvailable || staged.isEmpty) {
      markTestSkipped('no engine, or no filesystem staged');
      return;
    }
    final root = Directory(IosRootfs.root!);
    if (!await root.exists()) {
      await _copyDirectory(Directory(staged), root);
    }
    IosRootfs.boot();

    // The root is an ordinary directory and cannot hold a device node, so
    // every one of these is a tmpfs the guest built at boot. Exercised rather
    // than listed: a node that exists and does not work is worse than none.
    final session = IosRootfs.open(
      command:
          r'echo discarded > /dev/null && '
          r'head -c 16 /dev/urandom | wc -c && '
          r'head -c 8 /dev/zero | wc -c && '
          r'test -e /dev/ptmx && test -d /dev/pts && test -d /dev/shm && '
          r'echo "SBM""_DEV_OK"',
    );
    expect(session, greaterThanOrEqualTo(0));
    final text = await readTo(session, 'SBM_DEV_OK');
    debugPrint('ISHPROBE dev=${text.trim()}');

    expect(text, contains('16'), reason: '/dev/urandom gave nothing');
    expect(text, contains('8'), reason: '/dev/zero gave nothing');
    // TODO: `/dev/stdout`, `/dev/stdin`, `/dev/stderr` and `/dev/fd` are
    // symlinks into `/proc/self/fd` and are not being created — a shell that
    // follows one gets "nonexistent directory". They are conveniences rather
    // than device nodes, so the nodes above are what this test is for; the
    // symlinks want their own look.
    // TODO: `tty` says "not a tty". Output flows and sessions are independent,
    // so `create_stdio` is reaching the driver — but through the adhoc fd it
    // falls back to rather than the `/dev/pts/N` node, which `isatty` does not
    // recognise. Interactive programs will care; a shell reading a command
    // does not, which is why it took a `tty` call to notice.
    expect(text, contains('SBM_DEV_OK'), reason: 'something in /dev failed');
    IosRootfs.close(session);
  }, skip: !Platform.isIOS);
}
