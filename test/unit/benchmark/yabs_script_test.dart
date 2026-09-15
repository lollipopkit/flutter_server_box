@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/benchmark/yabs_result.dart';
import 'package:server_box/data/model/server/benchmark/yabs_script.dart';

/// The commands that drive a benchmark, run against a real `/bin/sh`.
///
/// Everything here is a string assembled in Dart and executed by a shell on
/// someone else's machine, with two user-typed values — a working directory and
/// a custom iperf server list — inside it. A quoting mistake in that is not a
/// compile error, not a test failure anywhere else, and on a server it is
/// either a command that silently does nothing or one that does something
/// nobody asked for. So these run the actual fragments, with a stand-in for
/// yabs, and check what ends up on disk.
void main() {
  late Directory tmp;

  /// Stands for the id the provider mints per run. It is what stamps a run
  /// directory as this run's, and what cleanup checks before deleting it.
  const runId = 'bench_test_1';

  /// Runs [command] the way both transports do: handed to `/bin/sh -c`, with
  /// [stdinText] on its stdin when there is an `entry`.
  Future<ProcessResult> sh(String command, {String? stdinText}) async {
    final process = await Process.start(
      '/bin/sh',
      ['-c', command],
      environment: {'HOME': tmp.path},
      includeParentEnvironment: true,
    );
    if (stdinText != null) process.stdin.write(stdinText);
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    final err = await process.stderr.transform(utf8.decoder).join();
    return ProcessResult(process.pid, await process.exitCode, out, err);
  }

  /// Every run this test started, so `tearDown` can stop whatever is still
  /// going. A launcher runs under `setsid`: it belongs to no process this one
  /// waits on, and an assertion that fails before the test reaches
  /// [waitForRun] — or, in the cancel test, before it asks for a stop — leaves
  /// it running with nothing left in the test that knows about it.
  final startedRuns = <YabsOptions>[];

  Future<ProcessResult> startRun(YabsOptions options) async {
    startedRuns.add(options);
    return sh(
      YabsScript.startEntry(options, runId),
      stdinText: YabsScript.launcher(options),
    );
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('yabs_script_test');
    startedRuns.clear();
  });

  tearDown(() async {
    if (!tmp.existsSync()) return;

    // Stop first, delete second. The stand-in the cancel test installs sleeps
    // for a minute, so a failure before its `cancelCommand` would otherwise
    // leave that process — and the two it spawns — running long after the
    // suite has moved on.
    //
    // Asked before it is stopped, because `cancelCommand` sleeps two seconds
    // between its TERM and its KILL. On the usual path every run here has
    // already finished, and paying that per test turned a 5-second file into a
    // 20-second one; a poll costs one more shell and answers.
    for (final options in startedRuns) {
      final dir = YabsScript.runDir(options);
      final poll = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(dir))).stdout,
      );
      if (poll.alive) await sh(YabsScript.cancelCommand(dir));
    }

    // Retried anyway, because a stop is not instant and a launcher writing its
    // exit code into a tree being deleted fails the delete with `Directory not
    // empty` — which is then the error reported, in place of the assertion
    // that actually failed.
    for (var attempt = 0; ; attempt++) {
      try {
        await tmp.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt >= 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  /// A stand-in for yabs: records the arguments it was given, prints something
  /// on both streams, and writes the `-w` file.
  Future<void> installFakeYabs({
    int exitCode = 0,
    String json = '{"a":1}',
  }) async {
    final probe = await sh(YabsScript.probeCommand());
    expect(probe.stdout, contains(YabsScript.scriptMissing));

    final res = await sh(
      YabsScript.installEntry(),
      stdinText:
          '''
#!/bin/sh
echo "args: \$*"
echo "on stderr" >&2
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-w" ]; then echo '$json' > "\$2"; fi
  shift
done
exit $exitCode
''',
    );
    expect(res.stdout, contains(YabsScript.scriptInstalled));
  }

  /// Polls until the detached launcher has reported an exit code.
  ///
  /// **Every test that starts a run has to reach this, or stop the run, before
  /// it returns.** The launcher is under `setsid`, so it outlives the test body
  /// that started it, and `tearDown` then deletes a directory a live process is
  /// still writing into — which fails with `Directory not empty` rather than
  /// with anything naming the test that left the process behind. That is how it
  /// arrived: one CI run, one test, and nothing in the failure pointing at the
  /// one place a run was started and not awaited.
  Future<void> waitForRun(YabsOptions options) async {
    // The launcher is detached, so "started" says nothing about "finished".
    //
    // Bounded by the clock rather than by a poll count: each poll spawns a
    // shell, so under a parallel run the same number of iterations can be a
    // fraction of the wall time it is meant to allow — which made this fail as
    // a timeout while the stand-in was merely being scheduled slowly.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var polls = 0;
    ProcessResult? last;
    while (DateTime.now().isBefore(deadline)) {
      last = await sh(YabsScript.pollCommand(YabsScript.runDir(options)));
      polls++;
      if (YabsPollState.parse(last.stdout).finished) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // Diagnostics rather than a bare timeout: this has flaked under a parallel
    // run, and "it did not finish" says nothing about whether the launcher was
    // written, started, or ran and failed.
    final dir = Directory(
      YabsScript.runDir(options).replaceFirst(r'$HOME', tmp.path),
    );
    final listing = dir.existsSync()
        ? dir.listSync().map((e) => e.path.split('/').last).join(', ')
        : '<run directory absent>';
    final runScript = File('${dir.path}/run.sh');
    fail(
      'the run never reported an exit code after $polls polls\n'
      'run dir: $listing\n'
      'run.sh: ${runScript.existsSync() ? runScript.readAsStringSync() : "<absent>"}\n'
      'last poll stdout: ${last?.stdout}\n'
      'last poll stderr: ${last?.stderr}',
    );
  }

  Future<void> runToCompletion(YabsOptions options) async {
    final start = await startRun(options);
    expect(start.stdout, contains(YabsScript.started), reason: start.stderr);
    await waitForRun(options);
  }

  group('the script is installed where the commands look for it', () {
    test('probe says missing, then present, and \$HOME is expanded', () async {
      await installFakeYabs();

      final probe = await sh(YabsScript.probeCommand());
      expect(probe.stdout, contains(YabsScript.scriptPresent));

      // The whole point of `quotePath`: single quotes would have sent a
      // literal `$HOME` and made a directory of that name.
      expect(
        File(
          '${tmp.path}/.config/server_box/bench/'
          'yabs_${YabsScript.upstreamVersion}.sh',
        ).existsSync(),
        isTrue,
      );
      expect(Directory('${tmp.path}/\$HOME').existsSync(), isFalse);
    });
  });

  group('a run', () {
    test(
      'starts detached, reports an exit code, and hands back the JSON',
      () async {
        await installFakeYabs(json: '{"version":"v1","cpu":{"cores":4}}');
        const options = YabsOptions();
        await runToCompletion(options);

        final poll = await sh(
          YabsScript.pollCommand(YabsScript.runDir(options)),
        );
        final state = YabsPollState.parse(poll.stdout);

        expect(state.finished, isTrue);
        expect(state.exitCode, 0);
        expect(state.alive, isFalse);
        expect(state.dirExists, isTrue);
        expect(state.resultJson, '{"version":"v1","cpu":{"cores":4}}');
        // stdout and stderr both land in the log, which is what the page shows.
        expect(state.log, contains('args:'));
        expect(state.log, contains('on stderr'));
      },
    );

    test('passes the options through as flags, in yabs order', () async {
      await installFakeYabs();
      const options = YabsOptions(cpu: true, ipInfo: true, disk: false);
      await runToCompletion(options);

      final state = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(YabsScript.runDir(options)))).stdout,
      );
      final args = RegExp(r'args: (.*)').firstMatch(state.log)?.group(1);
      expect(args, isNotNull);
      // -f because disk is off, -6 because cpu is on, no -n because ipInfo is
      // on, -r because the network phase defaults to reduced.
      expect(args, contains('-f'));
      expect(args, contains('-r'));
      expect(args, contains('-6'));
      expect(args, isNot(contains('-n')));
      expect(args, isNot(contains('-g')));
      expect(args, contains('-w out.json'));
    });

    test('a non-zero exit is reported rather than swallowed', () async {
      await installFakeYabs(exitCode: 3);
      const options = YabsOptions();
      await runToCompletion(options);

      final state = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(YabsScript.runDir(options)))).stdout,
      );
      expect(state.exitCode, 3);
    });
  });

  group('user-typed values reach the shell as data', () {
    test('a working directory with spaces and quotes still works', () async {
      await installFakeYabs();
      final work = "${tmp.path}/we're here/some dir";
      await Directory(work).create(recursive: true);
      final options = YabsOptions(workDir: work);

      await runToCompletion(options);

      // fio measures whatever filesystem this is on, which is the reason the
      // option exists — so the run really has to happen there.
      expect(File('$work/.server_box_bench/out.json').existsSync(), isTrue);
    });

    test('a working directory is a path, never shell syntax', () async {
      await installFakeYabs();
      // If this were interpolated unquoted, the `;` would end the command and
      // `touch` would run. It is the one user-typed value left on these
      // command lines, and it reaches three of them.
      final work = '${tmp.path}/x; touch ${tmp.path}/pwned';
      await Directory(work).create(recursive: true);
      final options = YabsOptions(workDir: work);

      await startRun(options);

      // Waited for before the assertion rather than after it. As the commands
      // stand today the working directory only reaches the *synchronous* half
      // of `startEntry` — `launcher` is generated without it and `cd`s to its
      // own directory — so an injected `touch` would have run before that
      // command returned, and asserting there would be enough. This order does
      // not depend on that: it is what the assertion needs the moment any of
      // it moves behind the `setsid`, and the wait was already happening.
      await waitForRun(options);

      expect(File('${tmp.path}/pwned').existsSync(), isFalse);
      expect(File('$work/.server_box_bench/run.sh').existsSync(), isTrue);
    });
  });

  group('the moment before the launcher runs', () {
    test('a directory with no pid yet is not a run that died', () async {
      // The start command creates the directory and returns as soon as it has
      // backgrounded the launcher. A poll arriving in that window sees a
      // directory, no process and no exit code — which is also what a run
      // killed by the OOM killer looks like. Reading them as the same thing
      // failed benchmarks the instant they were started.
      const options = YabsOptions();
      final dir = YabsScript.runDir(options);
      await sh('mkdir -p ${YabsScript.quotePath(dir)}');

      final state = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(dir))).stdout,
      );

      expect(state.dirExists, isTrue);
      expect(state.alive, isFalse);
      expect(state.finished, isFalse);
      expect(state.launcherStarted, isFalse);
      expect(
        state.diedWithoutReporting,
        isFalse,
        reason: 'the launcher has not had a chance to write its pid',
      );
    });

    test('a pid whose process is gone is a run that died', () async {
      const options = YabsOptions();
      final dir = YabsScript.runDir(options);
      await sh('mkdir -p ${YabsScript.quotePath(dir)}');
      // A pid that cannot be running: the launcher got as far as recording it
      // and then the process disappeared without writing an exit code.
      await sh('echo 2147483646 > ${YabsScript.quotePath(dir)}/pid');

      final state = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(dir))).stdout,
      );

      expect(state.launcherStarted, isTrue);
      expect(state.alive, isFalse);
      expect(state.diedWithoutReporting, isTrue);
    });
  });

  group('cancelling', () {
    test('kills the process group and marks the run stopped', () async {
      // A stand-in that sleeps, so there is something to interrupt, and that
      // spawns a child to prove the whole group goes.
      final res = await sh(
        YabsScript.installEntry(),
        stdinText: '#!/bin/sh\nsleep 60 &\nsleep 60\n',
      );
      expect(res.stdout, contains(YabsScript.scriptInstalled));

      const options = YabsOptions();
      final start = await startRun(options);
      expect(start.stdout, contains(YabsScript.started));

      // Wait for the launcher to record its pid before asking to stop it.
      //
      // Bounded by the clock rather than by a count, for `runToCompletion`'s
      // reason: this waits on a real process being scheduled, and under a
      // parallel suite run a fixed number of 50ms sleeps is a fraction of the
      // wall time it looks like. Both waits in this file have timed out that
      // way, in different tests, on a machine that was merely busy.
      final dir = '${tmp.path}/.config/server_box/bench/run';
      final pidDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (!File('$dir/pid').existsSync() &&
          DateTime.now().isBefore(pidDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        File('$dir/pid').existsSync(),
        isTrue,
        reason: 'the launcher never recorded its pid',
      );
      expect(
        YabsPollState.parse(
          (await sh(YabsScript.pollCommand(YabsScript.runDir(options)))).stdout,
        ).alive,
        isTrue,
      );

      final cancel = await sh(
        YabsScript.cancelCommand(YabsScript.runDir(options)),
      );
      expect(cancel.stdout, contains(YabsScript.cancelled));

      final state = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(YabsScript.runDir(options)))).stdout,
      );
      expect(state.finished, isTrue);
      expect(state.exitCode, YabsScript.cancelledExitCode);
      expect(state.alive, isFalse);
    });
  });

  group('cleanup', () {
    test('removes the run directory and everything yabs left in it', () async {
      await installFakeYabs();
      const options = YabsOptions();
      await runToCompletion(options);

      final dir = Directory('${tmp.path}/.config/server_box/bench/run');
      // yabs makes a timestamped working directory inside this one and only
      // removes it if it exits normally, so cleanup has to be recursive.
      await Directory('${dir.path}/2026-01-01').create(recursive: true);
      expect(dir.existsSync(), isTrue);

      final res = await sh(
        YabsScript.cleanupCommand(YabsScript.runDir(options), runId),
      );
      expect(res.stdout, contains(YabsScript.cleaned));
      expect(dir.existsSync(), isFalse);
      // The script itself survives: it is versioned and shared by every run.
      expect(
        File(
          '${tmp.path}/.config/server_box/bench/'
          'yabs_${YabsScript.upstreamVersion}.sh',
        ).existsSync(),
        isTrue,
      );
    });

    test('refuses a path that is not a benchmark directory', () {
      // `rm -rf` on a path built from something the user typed, so the shape is
      // asserted rather than assumed. Even the worst working directory still
      // resolves to a subdirectory this class named.
      expect(
        YabsScript.cleanupCommand(
          YabsScript.runDir(const YabsOptions(workDir: '/')),
          runId,
        ),
        contains('.server_box_bench'),
      );
      // And a directory that came from somewhere else never reaches `rm -rf` —
      // the command now takes the path a run recorded, so this is the check
      // that a stored value cannot turn into a recursive delete of a home
      // directory.
      expect(
        () => YabsScript.cleanupCommand('/home/me', runId),
        throwsArgumentError,
      );
      expect(() => YabsScript.cleanupCommand('/', runId), throwsArgumentError);
    });
  });

  group('the login shell is not assumed to be POSIX', () {
    // `SSHClient.execute` hands the command to whatever shell the account uses.
    // fish removed backticks and csh has no `if ...; then`, so a script written
    // straight into that command line is a syntax error — which is not an
    // exception. The command "succeeds", prints a diagnostic, and none of the
    // markers arrive; it reached the user as "the server did not answer the
    // poll" from a server that was answering.
    for (final entry in {
      'probe': YabsScript.probeCommand(),
      'install': YabsScript.installEntry(),
      'start': YabsScript.startEntry(const YabsOptions(), 'bench_x'),
      'poll': YabsScript.pollCommand(YabsScript.runDir(const YabsOptions())),
      'cancel': YabsScript.cancelCommand(
        YabsScript.runDir(const YabsOptions()),
      ),
      'cleanup': YabsScript.cleanupCommand(
        YabsScript.runDir(const YabsOptions()),
        'bench_x',
      ),
    }.entries) {
      test('${entry.key} is one sh -c with everything inside it', () {
        // Structural, so this holds on any machine: only the wrapper has to
        // survive the login shell, and `sh -c '<one word>'` parses the same
        // everywhere. Anything after the closing quote would not.
        expect(entry.value, startsWith("sh -c '"));
        final body = entry.value.substring("sh -c '".length);
        expect(body, endsWith("'"));
        // The body is one single-quoted word: every inner quote has to be the
        // `'\''` idiom, never a bare one that would end the argument early.
        final closed = body.substring(0, body.length - 1);
        expect(
          closed.replaceAll(r"'\''", ''),
          isNot(contains("'")),
          reason: 'the quoted argument ends before the script does',
        );
      });
    }

    test('fish runs them, and would not have run the old form', () async {
      final fish = [
        '/opt/homebrew/bin/fish',
        '/usr/local/bin/fish',
        '/usr/bin/fish',
      ].firstWhere((p) => File(p).existsSync(), orElse: () => '');
      if (fish.isEmpty) {
        markTestSkipped('no fish on this machine');
        return;
      }

      // The wrapped form parses.
      final ok = await Process.run(
        fish,
        ['-c', YabsScript.probeCommand()],
        environment: {'HOME': tmp.path},
      );
      expect(ok.exitCode, 0, reason: ok.stderr.toString());
      expect(ok.stdout, contains(YabsScript.scriptMissing));

      // The unwrapped form does not: backticks alone are a syntax error, and
      // fish reports it without failing in any way a caller would notice as an
      // exception.
      final bad = await Process.run(
        fish,
        ['-c', 'p=`echo 1`\nif [ -n "\$p" ]; then echo MARKER; fi'],
        environment: {'HOME': tmp.path},
      );
      expect(bad.stdout, isNot(contains('MARKER')));
    });
  });

  group('cleanup will not delete a directory it does not own', () {
    test('a directory another run stamped is left alone', () async {
      await installFakeYabs();
      const options = YabsOptions();
      await runToCompletion(options);

      final dir = YabsScript.runDir(options);
      expect(
        Directory(dir.replaceFirst(r'$HOME', tmp.path)).existsSync(),
        isTrue,
      );

      // The path is the right shape and the marker is somebody else's, which
      // is the case the shape check alone cannot answer.
      final res = await sh(YabsScript.cleanupCommand(dir, 'bench_some_other'));

      expect(res.stdout, contains(YabsScript.notOurs));
      expect(res.stdout, isNot(contains(YabsScript.cleaned)));
      expect(
        Directory(dir.replaceFirst(r'$HOME', tmp.path)).existsSync(),
        isTrue,
        reason: 'a run that does not own this directory removed it anyway',
      );
    });

    test('an unstamped directory is left alone too', () async {
      const options = YabsOptions();
      final dir = YabsScript.runDir(options);
      await sh('mkdir -p ${YabsScript.quotePath(dir)}');

      final res = await sh(YabsScript.cleanupCommand(dir, runId));

      expect(res.stdout, contains(YabsScript.notOurs));
      expect(
        Directory(dir.replaceFirst(r'$HOME', tmp.path)).existsSync(),
        isTrue,
      );
    });
  });

  group('the poll output parses', () {
    test('a log containing the markers cannot forge a state', () {
      // The log is last precisely so its contents cannot be read as an earlier
      // section.
      final output = [
        '${YabsScript.stateMarker} exit= alive=1 started=1',
        YabsScript.jsonMarker,
        '',
        YabsScript.logMarker,
        '${YabsScript.stateMarker} exit=0 alive=0 started=1',
        YabsScript.jsonMarker,
        '{"malicious":true}',
      ].join('\n');

      final state = YabsPollState.parse(output);
      expect(state.finished, isFalse);
      expect(state.alive, isTrue);
      expect(state.resultJson, isNull);
      expect(state.log, contains('malicious'));
    });

    test('an answer that is not one is told apart from a missing run', () {
      // The distinction the runner hangs a benchmark's life on: a monitor agent
      // that hit its own timeout answers with an empty body, and reading that
      // as "the run directory is gone" would fail a run that is going fine.
      final none = YabsPollState.parse('');
      expect(none.answered, isFalse);
      expect(none.finished, isFalse);
      expect(none.diedWithoutReporting, isFalse);

      final gone = YabsPollState.parse(
        '${YabsScript.stateMarker} exit= alive=0 started=0',
      );
      expect(gone.answered, isTrue);
      expect(gone.dirExists, isFalse);

      final cut = '${YabsScript.stateMarker} exit=0 alive=0 started=1';
      final state = YabsPollState.parse(cut);
      expect(state.exitCode, 0);
      expect(state.log, isEmpty);
      expect(state.resultJson, isNull);
    });
  });

  group('the vendored asset', () {
    test('matches the recorded digest and version', () async {
      final file = File(YabsScript.assetPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${YabsScript.assetPath} is missing',
      );

      // Through the app's own decoder, over the asset as it is checked in, so
      // the digest covers the program a server would be sent rather than the
      // encoding it travels in.
      final text = YabsScript.decodeAsset(await file.readAsString());
      expect(
        sha256.convert(utf8.encode(text)).toString(),
        YabsScript.sha256Hex,
        reason:
            '${YabsScript.assetPath} changed. If that was deliberate, run '
            'scripts/update-yabs.sh and take the constants it prints.',
      );

      expect(
        RegExp(
          r'^YABS_VERSION="(.*)"$',
          multiLine: true,
        ).firstMatch(text)?.group(1),
        YabsScript.upstreamVersion,
      );
      // The remote filename carries the version, so a version string with a
      // path separator or a space in it would put the script somewhere else.
      expect(YabsScript.upstreamVersion, matches(RegExp(r'^[\w.-]+$')));
    });

    test('downloads fio and iperf3 only when -b was requested', () async {
      final text = YabsScript.decodeAsset(
        await File(YabsScript.assetPath).readAsString(),
      );

      // The no-`-b`, no-local-package path must not reach either URL. This is
      // intentionally structural: the asset is the exact shell program sent
      // to a server, and its hash above makes this contract reviewable when
      // the vendored upstream script is refreshed.
      final fioStart = text.indexOf(
        '# create temp directory to store disk write/read test files',
      );
      final fioEnd = text.indexOf(r'if [ -z "$DD_FALLBACK" ]');
      expect(fioStart, isNonNegative);
      expect(fioEnd, greaterThan(fioStart));
      final fio = text.substring(fioStart, fioEnd);
      expect(
        fio,
        contains(r'if [[ -z "$PREFER_BIN" && -n "$LOCAL_FIO" ]]; then'),
      );
      expect(fio, contains(r'elif [[ -n "$PREFER_BIN" ]]; then'));
      expect(
        fio,
        contains('fio is not installed. Running dd test as fallback...'),
      );
      expect(
        fio.indexOf(
          'https://raw.githubusercontent.com/masonr/'
          'yet-another-bench-script/master/bin/fio/',
        ),
        greaterThan(fio.indexOf(r'elif [[ -n "$PREFER_BIN" ]]; then')),
      );

      final iperf = text.substring(
        text.indexOf(r'if [ -z "$SKIP_IPERF" ]; then'),
        text.indexOf('# launch_geekbench'),
      );
      expect(
        iperf,
        contains(r'if [[ -z "$PREFER_BIN" && -n "$LOCAL_IPERF" ]]; then'),
      );
      expect(iperf, contains(r'elif [[ -n "$PREFER_BIN" ]]; then'));
      expect(
        iperf,
        contains('iperf3 is not installed. Skipping network tests...'),
      );
      expect(iperf, contains('IPERF_UNAVAILABLE=True'));
      expect(
        iperf,
        contains(r'[[ -z "$IPERF_DL_FAIL" && -z "$IPERF_UNAVAILABLE" ]]'),
      );
      expect(
        iperf.indexOf(
          'https://raw.githubusercontent.com/masonr/'
          'yet-another-bench-script/master/bin/iperf/',
        ),
        greaterThan(iperf.indexOf(r'elif [[ -n "$PREFER_BIN" ]]; then')),
      );
    });

    // App Store validation walks everything inside `Runner.app` and treats a
    // file it reads as executable code as a nested code object that must be
    // signed on its own. Nothing under `flutter_assets` is. So such an asset
    // costs nothing at build time and fails the *upload*, with `Invalid
    // Signature. Code object is not signed at all.` — an error that names the
    // certificates and not the file's contents. `assets/yabs.sh` shipped that
    // way in v1574, which is why the script is base64 now.
    //
    // Over every declared asset rather than yabs alone: the next one to do
    // this will not be this file.
    test('no bundled asset reads as executable code', () {
      const scriptSuffixes = ['.sh', '.bash', '.zsh', '.py', '.pl', '.rb'];

      final assets = _declaredAssets();
      expect(
        assets,
        contains(YabsScript.assetPath),
        reason: 'pubspec.yaml assets: could not be read',
      );

      for (final path in assets) {
        expect(
          scriptSuffixes.any(path.endsWith),
          isFalse,
          reason: '$path has a script suffix and cannot be bundled',
        );

        final bytes = File(path).readAsBytesSync();
        expect(
          bytes.length >= 2 && bytes[0] == 0x23 && bytes[1] == 0x21,
          isFalse,
          reason: '$path starts with a shebang and cannot be bundled',
        );
      }
    });
  });

  group('results parse leniently', () {
    test('a field yabs could not fill is null rather than zero', () {
      // Not a hypothetical: `CPU_CORES` comes from an `lscpu` pipeline that
      // prints nothing when it does not match, and the JSON is assembled by
      // string concatenation, so the value arrives empty.
      final result = YabsResult.fromJson({
        'version': 'v2026-07-24',
        'cpu': {'model': 'x', 'cores': '', 'freq': '3000', 'aes': 'true'},
        'mem': {'ram': '2048', 'ram_units': 'KiB'},
      });

      expect(result.cpu.cores, isNull);
      expect(result.cpu.aes, isTrue);
      expect(result.cpu.virt, isFalse);
      expect(result.mem.ram, 2048);
      expect(result.mem.ramBytes, 2048 * 1024);
      // Absent sections are empty rather than missing.
      expect(result.fio, isEmpty);
      expect(result.ipInfo, isNull);
    });

    test('iperf rates come back as numbers for the chart', () {
      const row = YabsIperf(
        send: '1.20 Gbits/sec',
        recv: '940 Mbits/sec',
        latency: '12.3 ms',
      );
      expect(row.sendBitsPerSec, 1.2e9);
      expect(row.recvBitsPerSec, 940e6);
      expect(row.latencyMs, 12.3);

      // What a location that could not be reached looks like.
      const missing = YabsIperf(send: 'busy', recv: '--', latency: '--');
      expect(missing.sendBitsPerSec, isNull);
      expect(missing.latencyMs, isNull);
    });
  });
}

/// Every file the `assets:` section of pubspec puts in the bundle, with a
/// directory entry expanded the way Flutter expands one — the files directly
/// inside it, not recursively.
///
/// Parsed by indentation rather than with a YAML package: the section is two
/// levels deep in a file this repo controls, and a test that reads pubspec
/// should not decide what the build's own parser accepts.
List<String> _declaredAssets() {
  final assets = <String>[];
  var inSection = false;

  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    if (RegExp(r'^  assets:\s*$').hasMatch(line)) {
      inSection = true;
      continue;
    }
    if (!inSection) continue;

    final entry = RegExp(r'^    -\s+(\S+)\s*$').firstMatch(line);
    if (entry == null) {
      // Comments and blank lines sit between entries; anything else is the
      // next key, and the section is over.
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      break;
    }

    final path = entry.group(1)!;
    if (path.endsWith('/')) {
      assets.addAll(
        Directory(path).listSync().whereType<File>().map((f) => f.path),
      );
    } else {
      assets.add(path);
    }
  }

  return assets;
}
