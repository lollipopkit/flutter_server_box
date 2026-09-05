import 'package:flutter/services.dart' show rootBundle;
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';

/// The vendored copy of Yet Another Bench Script, and the commands that drive
/// it on a server.
///
/// **The script is shipped, not fetched.** `curl -sL yabs.sh | bash` is how
/// upstream documents it, and it pins no version and verifies nothing — the
/// server runs whatever that URL served, decided by neither the user nor this
/// app. It also fails outright on the large share of hosts that cannot reach
/// raw.githubusercontent.com, which is the same set of hosts people most want
/// to benchmark. Shipping it makes the run reproducible and makes the network a
/// dependency only of the phases that genuinely need one.
///
/// What it cannot make offline is the rest: with `-b`, or with no local fio and
/// iperf3, yabs fetches those binaries itself, and Geekbench always comes from
/// `cdn.geekbench.com`. That is upstream's business and is left alone.
///
/// Refresh with `scripts/update-yabs.sh`, which prints the three constants
/// below; the `vendored asset` group in `test/yabs_script_test.dart` fails
/// until they match the file.
class YabsScript {
  const YabsScript._();

  static const assetPath = 'assets/yabs.sh';

  /// `YABS_VERSION` inside the asset. Also the remote filename, so a server
  /// that already has this version skips the upload.
  static const upstreamVersion = 'v2026-07-24';

  /// The upstream revision the asset was taken from. A version string alone
  /// does not identify a file — upstream amends within one.
  static const upstreamCommit = 'f8c6a48cd6ff85b54c5cd2504f0807462dc58938';

  /// SHA-256 of the asset, so an accidental edit to a 1100-line vendored shell
  /// script is a failing test rather than something nobody notices.
  static const sha256Hex =
      '8d2bccbf1dd74f09e09233dc5286a13a17183bd304bc818e75b4ac6066c9e095';

  /// Upstream, for the attribution the configuration sheet shows. WTFPL.
  static const upstreamUrl =
      'https://github.com/masonr/yet-another-bench-script';

  static String? _cached;

  /// The script's bytes, read once per process.
  static Future<String> load() async {
    return _cached ??= await rootBundle.loadString(assetPath);
  }

  // --- Remote layout ---

  /// Beside the status script's own directory, and for the same reasons: it
  /// survives a reboot, it is the invoking user's, and one agent and one SSH
  /// login reach the same copy.
  static const baseDir = r'$HOME/.config/server_box/bench';

  /// The name carries the version, exactly as `srvboxm_v<N>.sh` does: it is
  /// what lets "the file is there" mean "the right file is there", so an
  /// upgraded app replaces the script without having to compare anything.
  static String get scriptPath => '$baseDir/yabs_$upstreamVersion.sh';

  /// The directory a run happens in — and therefore **the filesystem fio
  /// measures**, which is why it follows [YabsOptions.workDir] rather than
  /// always living beside the script.
  ///
  /// A fixed name per working directory rather than one per run, so a run can
  /// be found again after the app was closed, the phone changed network, or
  /// the connection dropped. Only one benchmark per server makes sense at a
  /// time, so there is nothing to collide with.
  static String runDir(YabsOptions options) {
    final work = options.workDir.trim();
    if (work.isEmpty) return '$baseDir/run';
    return '${_stripTrailingSlashes(work)}/$_runDirName';
  }

  static const _runDirName = '.server_box_bench';

  static String _stripTrailingSlashes(String path) {
    var end = path.length;
    while (end > 1 && path[end - 1] == '/') {
      end--;
    }
    return path.substring(0, end);
  }

  // --- Commands ---

  /// Whether the server already has this version.
  ///
  /// Its own round trip rather than uploading unconditionally: the script is
  /// 50 KB, and over a monitor agent that is 50 KB of JSON request body on
  /// every run.
  static String probeCommand() =>
      '[ -s ${quotePath(scriptPath)} ] && echo $scriptPresent || echo $scriptMissing';

  static const scriptPresent = 'SBM_BENCH_SCRIPT_OK';
  static const scriptMissing = 'SBM_BENCH_SCRIPT_MISSING';

  /// Reads the script on stdin and writes it — the `entry` shape, so the 50 KB
  /// of shell never has to survive a round of quoting into a command line.
  static String installEntry() =>
      'mkdir -p ${quotePath(baseDir)} && cat > ${quotePath(scriptPath)} '
      '&& chmod +x ${quotePath(scriptPath)} && echo $scriptInstalled';

  static const scriptInstalled = 'SBM_BENCH_SCRIPT_INSTALLED';

  /// The launcher, written into the run directory and started detached.
  ///
  /// A file rather than a command line because everything about this run — the
  /// flags, three redirections, and an exit code written after the fact — would
  /// otherwise have to be nested inside the quoting of a `setsid sh -c` inside
  /// the quoting of an SSH command, which is a place bugs live and cannot be
  /// tested from here.
  ///
  /// It records **its own** pid rather than the shell's `$!`: started under
  /// `setsid` it is a session leader, so that pid is also the process group
  /// every child of the run inherits, and killing the group is the only way to
  /// stop a benchmark — fio, iperf3 and Geekbench are separate processes and
  /// killing the launcher alone would orphan whichever one is running.
  static String launcher(YabsOptions options) {
    final args = [
      quotePath(scriptPath),
      ...options.flags.map(quote),
      '-w',
      'out.json',
    ].join(' ');
    return '''
#!/bin/sh
# Generated by ServerBox. Removed with the run directory.
cd "\$(dirname "\$0")" || exit 1
echo \$\$ > pid
$args > log 2>&1
echo \$? > exit
''';
  }

  /// Installs [launcher] from stdin and starts it, in one command.
  ///
  /// `setsid` is what makes the run outlive this connection: without it the
  /// benchmark dies with the SSH channel, which on a phone means it dies when
  /// the screen locks. Where `setsid` is missing, `nohup` alone still survives
  /// the channel — it only costs the process group, which [cancelCommand]
  /// handles.
  ///
  /// All three of the launcher's own streams are redirected away before it is
  /// backgrounded. A detached child that keeps stdout open holds the channel
  /// open with it, and the caller waits for a process nobody is tracking — see
  /// `ExecResult.outputIncomplete`.
  static String startEntry(YabsOptions options, String runId) {
    final dir = quotePath(runDir(options));
    return 'mkdir -p $dir && cat > $dir/run.sh && chmod +x $dir/run.sh '
        '&& cd $dir && rm -f out.json log exit pid '
        '&& printf %s ${quote(runId)} > $ownerFile '
        '&& { if command -v setsid >/dev/null 2>&1; then '
        'setsid ./run.sh >/dev/null 2>&1 </dev/null & '
        'else nohup ./run.sh >/dev/null 2>&1 </dev/null & fi; } '
        '&& echo $started';
  }

  static const started = 'SBM_BENCH_STARTED';

  /// Names the run that owns a directory.
  ///
  /// Written before the launcher is detached, and read by two things that
  /// otherwise have to guess. [cleanupCommand] will not `rm -rf` a directory
  /// this does not vouch for, which matters because the path is built from a
  /// working directory the user typed. And its presence is what separates "the
  /// run has not written its pid yet" from "the run is gone", which a poll
  /// arriving in the first moments cannot tell apart otherwise.
  static const ownerFile = 'owner';

  /// One request that answers everything the page needs: whether it is still
  /// running, what it has printed, and the result if it has one.
  ///
  /// The result is included on every poll rather than fetched afterwards. It
  /// costs nothing while the run is going — yabs writes `out.json` only at the
  /// very end — and it removes the window where a run finished, the app asked
  /// for the file, and the connection dropped in between.
  ///
  /// The log comes last so that nothing in it can be mistaken for a marker
  /// belonging to a later section; it is the only part carrying arbitrary text.
  ///
  /// Takes the directory rather than the options it could be derived from: the
  /// run's own directory is recorded on its record, and that stored value is
  /// what a later build must poll. Re-deriving it would quietly send a changed
  /// derivation looking somewhere the running benchmark is not.
  static String pollCommand(String runDir) {
    final dir = quotePath(runDir);
    return '''
d=$dir
e=`cat "\$d/exit" 2>/dev/null | tr -dc '0-9-'`
p=`cat "\$d/pid" 2>/dev/null | tr -dc '0-9'`
a=0
if [ -n "\$p" ] && kill -0 "\$p" 2>/dev/null; then a=1; fi
s=0
if [ -d "\$d" ]; then s=1; fi
f=0
if [ -f "\$d/pid" ]; then f=1; fi
echo "$stateMarker exit=\$e alive=\$a started=\$s pid=\$f"
echo $jsonMarker
cat "\$d/out.json" 2>/dev/null
echo
echo $logMarker
cat "\$d/log" 2>/dev/null
''';
  }

  static const stateMarker = 'SBM_BENCH_STATE';
  static const jsonMarker = 'SBM_BENCH_JSON';
  static const logMarker = 'SBM_BENCH_LOG';

  /// Stops a run.
  ///
  /// The negative pid is the process group, which is what actually ends a
  /// benchmark: the launcher is a shell waiting on a child, and killing it
  /// alone leaves fio writing or Geekbench running. The plain-pid fallback is
  /// for the `nohup` path in [startEntry], where there is no group of our own
  /// to signal — there the children are left to their own timeouts, which fio
  /// and iperf3 have and Geekbench does not.
  ///
  /// Writes the exit file itself, because a killed launcher never reaches the
  /// line that would have.
  static String cancelCommand(String runDir) {
    final dir = quotePath(runDir);
    return '''
d=$dir
p=`cat "\$d/pid" 2>/dev/null | tr -dc '0-9'`
if [ -n "\$p" ]; then
  kill -TERM -"\$p" 2>/dev/null || kill -TERM "\$p" 2>/dev/null
  sleep 2
  kill -KILL -"\$p" 2>/dev/null || kill -KILL "\$p" 2>/dev/null
fi
[ -f "\$d/exit" ] || echo $cancelledExitCode > "\$d/exit"
echo $cancelled
''';
  }

  /// 128 + SIGTERM, the shell's own convention for it, so a reader of the
  /// stored record sees a number that means something.
  static const cancelledExitCode = 143;
  static const cancelled = 'SBM_BENCH_CANCELLED';

  /// Removes the run directory once its result has been read.
  ///
  /// Recursive because yabs creates a timestamped working directory inside
  /// this one and only removes it when it exits normally — a cancelled run
  /// leaves a 2 GB fio file behind, which is not something to leave on
  /// someone's disk.
  ///
  /// The path is asserted rather than trusted. It is built here from
  /// [YabsOptions.workDir], which the user types, and `rm -rf` on a path
  /// assembled from user input deserves a check that it is still the directory
  /// this class names — even though the only way to reach it is through
  /// [runDir].
  static String cleanupCommand(String runDir, String runId) {
    if (!runDir.endsWith('/$_runDirName') && !runDir.endsWith('/run')) {
      throw ArgumentError.value(runDir, 'runDir', 'not a benchmark directory');
    }
    final dir = quotePath(runDir);
    // Two checks, because neither is enough on its own. The shape rules out a
    // path this class could not have produced; the marker rules out a
    // directory of that shape that some other run — or something that is not a
    // run at all — happens to own. `rm -rf` on a path assembled from a working
    // directory the user typed deserves both.
    return 'd=$dir\n'
        'if [ "`cat "\$d/$ownerFile" 2>/dev/null`" = ${quote(runId)} ]; then\n'
        '  rm -rf "\$d" && echo $cleaned\n'
        'else\n'
        '  echo $notOurs\n'
        'fi\n';
  }

  /// The directory did not carry this run's marker, so nothing was removed.
  static const notOurs = 'SBM_BENCH_NOT_OURS';

  static const cleaned = 'SBM_BENCH_CLEANED';

  /// Wraps [value] so a POSIX shell reads it as one literal word.
  ///
  /// Single quotes, because inside them the shell expands nothing at all;
  /// double quotes would still leave `$`, `` ` `` and `\` live. An embedded
  /// single quote ends the string, escapes itself outside it, and opens a new
  /// one — the standard `'\''`.
  ///
  /// Every path and flag value on the way to a server goes through this. Two of
  /// them are typed by the user: the working directory and the custom iperf
  /// server list, both of which end up on a command line on a machine they own.
  static String quote(String value) => "'${value.replaceAll("'", r"'\''")}'";

  /// [quote], except that a leading `$HOME` is left for the shell to expand.
  ///
  /// Single quotes suppress *everything*, `$HOME` included, so quoting these
  /// paths the ordinary way would send a literal `$HOME/.config/...` and every
  /// command would fail on a directory of that name. The remainder is still
  /// quoted, which is what matters: a home directory with a space in it is
  /// unusual on a server and completely ordinary on the macOS and Windows
  /// machines this also has to work against.
  ///
  /// Adjacent quoted words concatenate in the shell, so `"$HOME"'/rest'` is one
  /// argument.
  static String quotePath(String path) {
    const prefix = r'$HOME/';
    if (!path.startsWith(prefix)) return quote(path);
    return '"\$HOME"/${quote(path.substring(prefix.length))}';
  }
}

/// What one [YabsScript.pollCommand] answered.
class YabsPollState {
  const YabsPollState({
    required this.answered,
    required this.exitCode,
    required this.alive,
    required this.dirExists,
    required this.launcherStarted,
    required this.log,
    required this.resultJson,
  });

  /// Whether this is an answer to the poll at all.
  ///
  /// False when the output carried no state line — the command never ran, or
  /// what came back was not its output. A monitor agent that hits its own
  /// timeout answers with an empty body and `timed_out`, and without this the
  /// caller would read the resulting all-zero state as "the run directory is
  /// gone" and fail a benchmark that is running perfectly well.
  ///
  /// So: not answered means ask again. [dirExists] is only meaningful once
  /// this is true.
  final bool answered;

  /// Null while the run is still going: the launcher writes this file as its
  /// last act.
  final int? exitCode;

  /// Whether the launcher's process is still there.
  ///
  /// Both this and [exitCode] are needed. A run that was killed by the OOM
  /// killer — which a Geekbench run on a small VPS invites — leaves no exit
  /// file and no process, and only the pair of them tells that apart from a
  /// run still in its first second.
  final bool alive;

  /// Whether the run directory is there at all. False means nothing was ever
  /// started here, or it has been cleaned up.
  final bool dirExists;

  /// Whether the launcher has recorded its pid yet.
  ///
  /// The start command creates the directory and returns as soon as it has
  /// backgrounded the launcher, so the first poll routinely arrives before the
  /// launcher has run a single line. Without this, that moment — a directory,
  /// no process, no exit code — is indistinguishable from a run that died, and
  /// a benchmark was failed before it began.
  final bool launcherStarted;

  final String log;

  /// The raw `out.json` text, or null before yabs writes it.
  ///
  /// Raw rather than parsed: the record keeps the text, so what this build
  /// could not read is not lost — see [YabsResult].
  final String? resultJson;

  bool get finished => answered && exitCode != null;

  /// Started, no exit code, and no process left to produce one.
  bool get diedWithoutReporting =>
      answered && dirExists && launcherStarted && !alive && exitCode == null;

  /// Reads the fixed shape [YabsScript.pollCommand] prints.
  ///
  /// Tolerant of a missing section: over a monitor agent the output can be
  /// truncated at the configured cap, and half an answer is still worth more
  /// than an exception — the log is the part that grows, and it is last for
  /// exactly this reason.
  factory YabsPollState.parse(String output) {
    final stateIdx = output.indexOf(YabsScript.stateMarker);
    if (stateIdx < 0) {
      return const YabsPollState(
        answered: false,
        exitCode: null,
        alive: false,
        dirExists: false,
        launcherStarted: false,
        log: '',
        resultJson: null,
      );
    }
    final stateEnd = output.indexOf('\n', stateIdx);
    final stateLine = stateEnd < 0
        ? output.substring(stateIdx)
        : output.substring(stateIdx, stateEnd);

    int? field(String name) {
      final match = RegExp('$name=(-?\\d*)').firstMatch(stateLine);
      final raw = match?.group(1);
      if (raw == null || raw.isEmpty) return null;
      return int.tryParse(raw);
    }

    final jsonIdx = output.indexOf(YabsScript.jsonMarker, stateIdx);
    final logIdx = output.indexOf(YabsScript.logMarker, jsonIdx < 0 ? stateIdx : jsonIdx);

    String? json;
    if (jsonIdx >= 0) {
      final start = jsonIdx + YabsScript.jsonMarker.length;
      final end = logIdx >= 0 ? logIdx : output.length;
      final text = output.substring(start, end).trim();
      if (text.isNotEmpty) json = text;
    }

    final log = logIdx >= 0
        ? output.substring(logIdx + YabsScript.logMarker.length).trimLeft()
        : '';

    return YabsPollState(
      answered: true,
      exitCode: field('exit'),
      alive: field('alive') == 1,
      dirExists: field('started') == 1,
      // Absent from an older agent's answer, which reads as null. Treated as
      // "started" there, so this stays no stricter than the check it replaced.
      launcherStarted: field('pid') != 0,
      log: log,
      resultJson: json,
    );
  }
}
