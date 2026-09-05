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
    final process = await Process.start('/bin/sh', [
      '-c',
      command,
    ], environment: {'HOME': tmp.path}, includeParentEnvironment: true);
    if (stdinText != null) process.stdin.write(stdinText);
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    final err = await process.stderr.transform(utf8.decoder).join();
    return ProcessResult(process.pid, await process.exitCode, out, err);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('yabs_script_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// A stand-in for yabs: records the arguments it was given, prints something
  /// on both streams, and writes the `-w` file.
  Future<void> installFakeYabs({int exitCode = 0, String json = '{"a":1}'}) async {
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

  Future<void> runToCompletion(YabsOptions options) async {
    final start = await sh(
      YabsScript.startEntry(options, runId),
      stdinText: YabsScript.launcher(options),
    );
    expect(start.stdout, contains(YabsScript.started), reason: start.stderr);

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
        ? dir
              .listSync()
              .map((e) => e.path.split('/').last)
              .join(', ')
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

  group('the script is installed where the commands look for it', () {
    test('probe says missing, then present, and \$HOME is expanded', () async {
      await installFakeYabs();

      final probe = await sh(YabsScript.probeCommand());
      expect(probe.stdout, contains(YabsScript.scriptPresent));

      // The whole point of `quotePath`: single quotes would have sent a
      // literal `$HOME` and made a directory of that name.
      expect(
        File('${tmp.path}/.config/server_box/bench/'
                'yabs_${YabsScript.upstreamVersion}.sh')
            .existsSync(),
        isTrue,
      );
      expect(Directory('${tmp.path}/\$HOME').existsSync(), isFalse);
    });
  });

  group('a run', () {
    test('starts detached, reports an exit code, and hands back the JSON',
        () async {
      await installFakeYabs(json: '{"version":"v1","cpu":{"cores":4}}');
      const options = YabsOptions();
      await runToCompletion(options);

      final poll = await sh(YabsScript.pollCommand(YabsScript.runDir(options)));
      final state = YabsPollState.parse(poll.stdout);

      expect(state.finished, isTrue);
      expect(state.exitCode, 0);
      expect(state.alive, isFalse);
      expect(state.dirExists, isTrue);
      expect(state.resultJson, '{"version":"v1","cpu":{"cores":4}}');
      // stdout and stderr both land in the log, which is what the page shows.
      expect(state.log, contains('args:'));
      expect(state.log, contains('on stderr'));
    });

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

    test('a custom iperf list is one argument, never shell syntax', () async {
      await installFakeYabs();
      // If this were interpolated unquoted, the `;` would end the command and
      // `touch` would run.
      final options = YabsOptions(
        customIperfServers: 'h:1-2:n:l:IPv4; touch ${tmp.path}/pwned',
      );
      await runToCompletion(options);

      expect(File('${tmp.path}/pwned').existsSync(), isFalse);
      final state = YabsPollState.parse(
        (await sh(YabsScript.pollCommand(YabsScript.runDir(options)))).stdout,
      );
      expect(state.log, contains('touch ${tmp.path}/pwned'));
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
      final start = await sh(
        YabsScript.startEntry(options, runId),
        stdinText: YabsScript.launcher(options),
      );
      expect(start.stdout, contains(YabsScript.started));

      // Wait for the launcher to record its pid before asking to stop it.
      final dir = '${tmp.path}/.config/server_box/bench/run';
      for (var i = 0; i < 100 && !File('$dir/pid').existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        YabsPollState.parse(
          (await sh(YabsScript.pollCommand(YabsScript.runDir(options)))).stdout,
        ).alive,
        isTrue,
      );

      final cancel = await sh(YabsScript.cancelCommand(YabsScript.runDir(options)));
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

      final res = await sh(YabsScript.cleanupCommand(YabsScript.runDir(options), runId));
      expect(res.stdout, contains(YabsScript.cleaned));
      expect(dir.existsSync(), isFalse);
      // The script itself survives: it is versioned and shared by every run.
      expect(
        File('${tmp.path}/.config/server_box/bench/'
                'yabs_${YabsScript.upstreamVersion}.sh')
            .existsSync(),
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
      expect(() => YabsScript.cleanupCommand('/home/me', runId), throwsArgumentError);
      expect(() => YabsScript.cleanupCommand('/', runId), throwsArgumentError);
    });
  });

  group('cleanup will not delete a directory it does not own', () {
    test('a directory another run stamped is left alone', () async {
      await installFakeYabs();
      const options = YabsOptions();
      await runToCompletion(options);

      final dir = YabsScript.runDir(options);
      expect(Directory(dir.replaceFirst(r'$HOME', tmp.path)).existsSync(), isTrue);

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
      final file = File('assets/yabs.sh');
      expect(file.existsSync(), isTrue, reason: 'assets/yabs.sh is missing');

      final bytes = await file.readAsBytes();
      expect(
        sha256.convert(bytes).toString(),
        YabsScript.sha256Hex,
        reason: 'assets/yabs.sh changed. If that was deliberate, run '
            'scripts/update-yabs.sh and take the constants it prints.',
      );

      final text = utf8.decode(bytes);
      expect(
        RegExp(r'^YABS_VERSION="(.*)"$', multiLine: true)
            .firstMatch(text)
            ?.group(1),
        YabsScript.upstreamVersion,
      );
      // The remote filename carries the version, so a version string with a
      // path separator or a space in it would put the script somewhere else.
      expect(YabsScript.upstreamVersion, matches(RegExp(r'^[\w.-]+$')));
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
