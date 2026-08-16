import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
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
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('the app installs a userland by itself', (_) async {
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    // The real path, with nothing staged: download the pinned release, check
    // its digest, unpack it in Dart. There is no `tar` here — iOS refuses to
    // start a process — and no metadata database to build, which is what
    // `realfs` bought.
    await IosRootfs.remove();
    expect(await IosRootfs.isInstalled, isFalse);

    var seen = -1.0;
    await IosRootfs.install(onProgress: (p) => seen = p ?? seen);
    expect(await IosRootfs.isInstalled, isTrue);
    expect(seen, greaterThan(0));

    // What makes it a userland rather than a directory of files: a shell, and
    // the execute bit on it. `realfs` reports the host's mode to the guest, so
    // a busybox written 0644 is one the guest cannot run.
    final root = IosRootfs.root!;
    final busybox = File(root.joinPath('bin/busybox'));
    expect(await busybox.exists(), isTrue);
    expect((await busybox.stat()).mode & 0x40, isNot(0), reason: 'not executable');
    // And the links are links: followed, `/bin/sh` would be the host's.
    expect(await FileSystemEntity.isLink(root.joinPath('bin/sh')), isTrue);
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a guest runs inside the app and answers', (_) async {
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    // Installed by the test above, or already there.
    await IosRootfs.install();
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
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install();
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
    // TODO: two gaps that look like one cause. `/dev/stdout` and its siblings
    // are symlinks to `/proc/self/fd/N` and do not resolve — "nonexistent
    // directory" — and `tty` reports "not a tty". Both are what would follow
    // from `create_stdio` having fallen back to the adhoc fd it makes when
    // `/dev/pts/N` does not open as a char device: output still reaches the
    // driver, which is why sessions work, but the fd is not in the table
    // procfs lists and `isatty` does not recognise it. Making `/dev/pts/N`
    // resolve is the one thing to try.
    // TODO: `tty` says "not a tty". Output flows and sessions are independent,
    // so `create_stdio` is reaching the driver — but through the adhoc fd it
    // falls back to rather than the `/dev/pts/N` node, which `isatty` does not
    // recognise. Interactive programs will care; a shell reading a command
    // does not, which is why it took a `tty` call to notice.
    expect(text, contains('SBM_DEV_OK'), reason: 'something in /dev failed');
    IosRootfs.close(session);
  }, skip: !Platform.isIOS);
}
