import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/ish_exec.dart';

/// What the Linux guest costs the app while it is working.
///
/// Half of M2. The other half is thermals, which only Instruments can see —
/// there is no API a Dart test can ask, and a phone that is throttling looks
/// from in here exactly like a phone that is slow. So this measures what it
/// can measure and leaves a number to compare the Instruments run against.
///
/// An interpreter with a 256 KB output ring and a guest heap is a different
/// proposition on a phone than on a Mac, and the question is not how fast it
/// is — `ios_bench_test.dart` answers that — but whether the app is still
/// standing afterwards and how much it is holding.
///
///     flutter test integration_test/ios_load_test.dart -d <device>
///
/// Nothing here asserts a byte count. What a phone holds depends on what else
/// is running and on when the allocator felt like returning pages, and a test
/// that failed the build on a number like that would be turned off within a
/// week. It asserts the guest survived the work and reports what it cost, on
/// `ISHLOAD|` lines.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => IosRootfs.prepare());

  /// The app's resident size, in MB, as the VM reports it.
  double rss() => ProcessInfo.currentRss / 1024 / 1024;

  testWidgets('the guest works hard and the app is still there', (_) async {
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install(distro: LinuxDistro.alpine);
    const exec = IshExec();

    // Booted and idle, before any work: what the engine costs simply for
    // existing, which is the number the rest is read against.
    await exec.run('true');
    final idle = rss();
    debugPrint('ISHLOAD|idle|${idle.toStringAsFixed(1)} MB');

    // Sustained work of three kinds, because they cost differently: a lot of
    // small processes, one long computation, and a file big enough that the
    // guest's own buffers matter.
    final work = await exec.run(r'''
set -e
cd /tmp
dd if=/dev/urandom of=load.bin bs=1M count=64 2>/dev/null
for i in $(seq 1 3); do sha256sum load.bin >/dev/null; done
i=0
while [ $i -lt 400 ]; do echo $i | wc -c >/dev/null; i=$((i+1)); done
seq 1 200000 | sort -rn | tail -1
rm -f load.bin
echo DONE
''');
    expect(work.exitCode, 0, reason: work.stderr);
    expect(work.stdout, contains('DONE'));

    final after = rss();
    debugPrint('ISHLOAD|after|${after.toStringAsFixed(1)} MB');
    debugPrint('ISHLOAD|grew|${(after - idle).toStringAsFixed(1)} MB');
    debugPrint(
      'ISHLOAD|peak|${(ProcessInfo.maxRss / 1024 / 1024).toStringAsFixed(1)} MB',
    );

    // The one thing worth asserting: the guest is still a guest. An
    // interpreter that had been killed, or whose kernel state had been
    // corrupted by the work, would answer this differently or not at all —
    // and it is one process per app, so there is no second one to fall back
    // to.
    final alive = await exec.run('echo STILL; uname -m');
    expect(alive.exitCode, 0, reason: alive.stderr);
    expect(alive.stdout, contains('STILL'));
    expect(alive.stdout, contains('aarch64'));
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('a package manager, over the network, in the guest', (_) async {
    // `apk add` is on M2's list of real workloads, and it is the one that
    // found something: the guest could open sockets and fetch an address
    // literal, but the minirootfs ships no `/etc/resolv.conf` and nothing
    // wrote one, so every mirror answered "temporary error (try again later)"
    // and every package was missing. `IosRootfs` seeds one now — at install,
    // and at startup for a userland unpacked before it did.
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.prepare();
    await IosRootfs.install(distro: LinuxDistro.alpine);
    const exec = IshExec();

    final before = rss();
    // No pipe: a pipeline's status is the last command's, so `| tail` would
    // report success for every failure apk can have.
    final add = await exec.run('apk add --no-cache file');
    debugPrint('ISHLOAD|apk exit|${add.exitCode}');
    debugPrint('ISHLOAD|apk cost|${(rss() - before).toStringAsFixed(1)} MB');

    if (add.exitCode != 0) {
      // How far it got decides what the fix is, and printing that here is
      // worth more than the failure alone: a guest with no resolver fails at
      // the name, and a guest whose sockets do not reach the network fails at
      // the address too. `apk` says the same thing for both.
      final why = await exec.run(r'''
echo "resolv: $(cat /etc/resolv.conf 2>&1 | tr '\n' ' ')"
echo "repos: $(cat /etc/apk/repositories 2>&1 | tr '\n' ' ')"
wget -q -T 8 -O /dev/null http://dl-cdn.alpinelinux.org/ 2>&1 && echo "name: ok" || echo "name: no"
wget -q -T 8 -O /dev/null http://151.101.194.132/ 2>&1 && echo "addr: ok" || echo "addr: no"
''');
      fail('apk add failed:\n${add.stdout}${add.stderr}\n${why.stdout}');
    }

    // Not just installed — run, on a file inside the guest. A package that
    // unpacked but cannot be executed is the failure this platform is most
    // likely to have, since nothing here is handed to the kernel.
    final ran = await exec.run('file /bin/busybox');
    debugPrint('ISHLOAD|installed|${ran.stdout.trim()}');
    expect(ran.exitCode, 0, reason: ran.stderr);
    expect(ran.stdout, contains('ELF'));
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 10)));
}
