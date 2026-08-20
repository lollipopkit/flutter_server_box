import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/ish_exec.dart';

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
/// Nothing is staged: the app downloads and unpacks the userland itself, which
/// is what `realfs` bought and what the first test here exercises.
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
  ///
  /// Bytes are accumulated and decoded whole rather than per read: a console
  /// hands over whatever it had ready, so a multi-byte character can straddle
  /// two of them.
  Future<String> readTo(int session, String until) async {
    final output = <int>[];
    var text = '';
    for (var round = 0; round < 400; round++) {
      final chunk = IosRootfs.read(session, timeout: Duration.zero);
      if (chunk == null) break;
      output.addAll(chunk);
      text = utf8.decode(output, allowMalformed: true);
      if (text.contains(until)) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return text;
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
          r'echo "SBM""_NODES_OK"; '
          // Not chained to the above: each of these three answers a separate
          // question, and one failing should not hide the other two.
          r'tty; '
          r'readlink /dev/fd/1; '
          r'echo "SBM""_STDOUT" > /dev/stdout; '
          r'echo "SBM""_DEV_OK"',
    );
    expect(session, greaterThanOrEqualTo(0));
    final text = await readTo(session, 'SBM_DEV_OK');
    debugPrint('ISHPROBE dev=${text.trim()}');

    expect(text, contains('16'), reason: '/dev/urandom gave nothing');
    expect(text, contains('8'), reason: '/dev/zero gave nothing');
    expect(text, contains('SBM_NODES_OK'), reason: 'something in /dev failed');

    // The three that were wrong together, and are one thing: a session's stdio
    // is the `/dev/pts/N` it was given rather than the adhoc fd `create_stdio`
    // fell back to. `isatty` did not recognise that fd and procfs listed no
    // path for it, so `tty` answered "not a tty" and every `/dev/std*` symlink
    // — they point into `/proc/self/fd` — resolved to nothing.
    expect(text, contains('/dev/pts/'), reason: '`tty` does not name the pty');
    expect(
      RegExp(r'/dev/pts/\d+').allMatches(text).length,
      greaterThanOrEqualTo(2),
      reason: '/proc/self/fd/1 does not point at the pty',
    );
    expect(text, contains('SBM_STDOUT'), reason: '/dev/stdout did not resolve');
    expect(text, contains('SBM_DEV_OK'));
    IosRootfs.close(session);
  }, skip: !Platform.isIOS);

  // What the Agent's shell tool goes through. The terminal's backend is the
  // other half and is exercised above; this one is `ServerExec`, which promises
  // things a console cannot keep — hence the two files it runs commands with.
  testWidgets('the Agent runs its commands inside the guest', (_) async {
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install();
    const exec = IshExec();

    final release = await exec.run('cat /etc/alpine-release');
    expect(release.stdout.trim(), IosRootfs.version);
    expect(release.exitCode, 0);

    final failed = await exec.run('exit 3');
    expect(failed.exitCode, 3);
    expect(failed.succeeded, isFalse);

    // The two streams stay apart. A session's console merges them the way any
    // terminal does, which is why neither of these came from it.
    final split = await exec.run('echo out; echo err >&2');
    expect(split.stdout.trim(), 'out');
    expect(split.stderr.trim(), 'err');
    // And what arrives is not a terminal's idea of a line.
    expect(split.stdout, isNot(contains('\r')));

    // Nothing believes it is talking to one either, which is what stops `ls`
    // printing columns at a width nobody chose.
    final piped = await exec.run(r'test -t 1; echo "tty=$?"');
    expect(piped.stdout.trim(), 'tty=1');

    // The guest is the boundary, exactly as the container is on Android: a
    // guest path resolves under the root, and one that is not inside is not a
    // path this machine will expose.
    expect(await exec.hostPathOf('/etc/alpine-release'), isNotNull);
    expect(await exec.hostPathOf('etc/alpine-release'), isNull);

    // Cancelling stops waiting, and says the exit code means nothing.
    final cancel = Completer<void>();
    final running = exec.run('sleep 30', cancel: cancel.future);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    cancel.complete();
    final cancelled = await running.timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail('cancelling did not end the command'),
    );
    expect(cancelled.exitCode, isNull);

    // Nothing of its own is left in the guest's /tmp.
    final leftovers = Directory(IosRootfs.root!.joinPath('tmp'))
        .listSync()
        .where((e) => e.path.contains('.sbm-exec-'));
    expect(leftovers, isEmpty);
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 2)));

  // Where the app stops taking a command, and the reason the test after this
  // one exists. `sbm_ish_open` packs `/bin/sh`, `-c` and the command into one
  // 4096-byte block and answers `-E2BIG`; the guest's own `ARGV_MAX` is 32
  // pages and was never what stopped anything. Bracketed rather than pinned to
  // the byte — what matters is that the wall is near 4 KB and that reaching it
  // is a refusal rather than a command quietly cut short.
  testWidgets('the engine refuses a command it cannot fit', (_) async {
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install();
    IosRootfs.boot();

    // Padded with a comment, so the length is the only thing being varied.
    String ofLength(int bytes) {
      const command = 'true';
      return '$command #${'-' * (bytes - command.length - 2)}';
    }

    final fits = IosRootfs.open(command: ofLength(4000));
    expect(fits, greaterThanOrEqualTo(0), reason: '4000 bytes refused ($fits)');
    IosRootfs.close(fits);

    final over = IosRootfs.open(command: ofLength(5000));
    // Closed before the assertion: a session leaked here outlives the test.
    if (over >= 0) IosRootfs.close(over);
    debugPrint('ISHARGV 4000=$fits 5000=$over');
    // -E2BIG, from the host's errno.h. This is the number a caller sees in
    // `IshExec`'s "the guest refused a session ($id)".
    expect(over, -7, reason: '5000 bytes did not give -E2BIG');
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 2)));

  // The Agent writes the script it runs, so nothing bounds its length, and
  // 4 KB of it used to come back as "refused a session (-7)" — a sentence that
  // says nothing about length and points at the guest rather than at the app.
  testWidgets('a script the engine cannot hold still runs', (_) async {
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install();
    const exec = IshExec();

    // Well past 4 KB, and past it in the part that varies rather than in one
    // long line, which is the shape a generated script actually has.
    final script = StringBuffer();
    for (var i = 0; i < 400; i++) {
      script.writeln('# a line of padding, the ${i}th of four hundred');
    }
    script.writeln(r'echo out; echo err >&2; exit 7');
    expect(utf8.encode(script.toString()).length, greaterThan(4096));

    final long = await exec.run(script.toString());
    // Everything the short path promises, over the long one: both streams, kept
    // apart, and the script's own exit code rather than the shell's opinion of
    // being handed a file.
    expect(long.exitCode, 7, reason: long.stderr);
    expect(long.stdout.trim(), 'out');
    expect(long.stderr.trim(), 'err');

    // And the environment still arrives, which is the other half of what the
    // wrapper writes ahead of the script.
    final env = await exec.run(
      '${'# padding\n' * 600}printf %s "\$SBM_LONG"',
      env: {'SBM_LONG': 'through the file'},
    );
    expect(env.stdout, 'through the file');

    // The script file is the guest's /tmp too, and goes the way the two output
    // files do.
    final leftovers = Directory(IosRootfs.root!.joinPath('tmp'))
        .listSync()
        .where((e) => e.path.contains('.sbm-exec-'));
    expect(leftovers, isEmpty);
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 2)));

  // The three places the host's uptime reaches the guest. They disagreed:
  // `get_uptime` answered in whole seconds and two of the three divide by 100,
  // so /proc/uptime advanced by 0.01 per real second and anything timing itself
  // against it measured zero. Nothing crashed and no test failed — the numbers
  // were simply wrong, which is why all three are checked here rather than the
  // one that was noticed.
  testWidgets('the guest clock is a clock', (_) async {
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install();
    const exec = IshExec();

    final probe = await exec.run(
      r'cat /proc/uptime; sleep 1; cat /proc/uptime; '
      r'date +%s; uptime; grep btime /proc/stat',
    );
    expect(probe.exitCode, 0, reason: probe.stderr);
    final lines = const LineSplitter().convert(probe.stdout.trim());
    debugPrint('ISHCLOCK ${lines.join(" | ")}');
    expect(lines.length, greaterThanOrEqualTo(5), reason: probe.stdout);

    // 1. /proc/uptime, and that a second of sleeping is a second of it. The bug
    //    made this 0.01, so anything short of the real elapsed time fails.
    final before = double.parse(lines[0].split(' ').first);
    final after = double.parse(lines[1].split(' ').first);
    expect(
      after - before,
      inInclusiveRange(0.5, 3.0),
      reason: '/proc/uptime moved ${after - before}s while a second passed',
    );

    final now = int.parse(lines[2].trim());

    // 2. sysinfo, which is what busybox's `uptime` asks and which wants seconds
    //    where the field holds hundredths. Printed to the minute, so this is
    //    only ever going to be roughly right — but the failure it guards
    //    against is a factor of a hundred.
    //    Two shapes, because busybox drops to minutes alone under an hour:
    //    `up 5 days, 27 min` and `up 5 days, 2:15`.
    final up = RegExp(
      r'up\s+(?:(\d+)\s+days?,\s*)?(?:(\d+):(\d+)|(\d+)\s+min)',
    ).firstMatch(lines[3]);
    expect(up, isNotNull, reason: 'could not read `uptime`: ${lines[3]}');
    final reported =
        int.parse(up!.group(1) ?? '0') * 86400 +
        int.parse(up.group(2) ?? '0') * 3600 +
        int.parse(up.group(3) ?? up.group(4) ?? '0') * 60;
    expect(
      (reported - after).abs(),
      lessThan(120),
      reason: '`uptime` says ${reported}s, /proc/uptime says ${after}s',
    );

    // 3. btime, which is this same uptime subtracted from the wall clock. Its
    //    sub-second part went into a nanoseconds field unscaled, so it could be
    //    a second out — below the resolution of what is printed, and checked
    //    here only for the whole-second value being sane.
    final btime = int.parse(lines[4].split(RegExp(r'\s+'))[1]);
    expect(
      (now - btime - after).abs(),
      lessThan(5),
      reason: 'btime $btime, now $now, uptime $after',
    );
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 2)));

  // `/proc/uptime` is two decimal places on Linux, always. `proc_show_uptime`
  // printed the hundredths with `%lu`, so a value under ten lost its leading
  // zero — `.07` arrived as `.7`, which any reader takes for `.70`. One read in
  // ten, and the error is up to 0.63s in a file whose whole resolution is 0.01.
  //
  // The test above cannot see it: it samples twice around a `sleep 1` and
  // allows 0.5 to 3.0, which a 0.63 jump sits inside. What it reaches is
  // anything in the guest that measures an interval — the fork's own benchmark
  // reported a negative duration, which is what found this.
  testWidgets('/proc/uptime keeps its two decimal places', (_) async {
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    await IosRootfs.install();
    const exec = IshExec();

    // Enough reads that the hundredths land under ten several times over.
    final probe = await exec.run(
      r'i=0; while [ $i -lt 300 ]; do cat /proc/uptime; i=$((i+1)); done',
    );
    expect(probe.exitCode, 0, reason: probe.stderr);
    final lines = const LineSplitter().convert(probe.stdout.trim());
    expect(lines.length, 300, reason: 'read ${lines.length} lines');

    // Both fields, both two digits. Stated as the shape rather than as a
    // number, because what broke was the format and not the value.
    final shape = RegExp(r'^\d+\.\d{2} \d+\.\d{2}$');
    final malformed = lines.where((l) => !shape.hasMatch(l)).toList();
    debugPrint('ISHUPTIME ${lines.first} .. ${lines.last} bad=${malformed.length}');
    expect(
      malformed,
      isEmpty,
      reason: '${malformed.length}/300 lines are not `S.CC S.CC`: '
          '${malformed.take(5).join(", ")}',
    );

    // And it never goes backwards, which is the symptom the format caused.
    final seconds = lines
        .map((l) => double.parse(l.split(' ').first))
        .toList();
    for (var i = 1; i < seconds.length; i++) {
      expect(
        seconds[i],
        greaterThanOrEqualTo(seconds[i - 1]),
        reason: 'read $i went back: ${seconds[i - 1]} then ${seconds[i]}',
      );
    }
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 2)));
}
