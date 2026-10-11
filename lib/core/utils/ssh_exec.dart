import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/server/server_exec.dart';

typedef SshExecCollectedOutput = ({
  String stdout,
  String stderr,
  bool outputIncomplete,
  Object? streamError,
  StackTrace? streamErrorStackTrace,
});

/// Collects both SSH output streams until the command and streams have ended.
///
/// The completion futures are registered before [commandDone] is awaited. A
/// fast command can close stdout and stderr before its SSH exit status arrives;
/// registering `asFuture` afterwards misses that already-delivered done event
/// and falsely turns an ordinary command into a drain timeout.
///
/// Once [cancel] completes, [commandDone] gets [drainTimeout] and no more.
/// sshd answers a channel close only after the process has exited and its
/// output has closed, so a signal the server refuses (OpenSSH before 7.9,
/// some Dropbear builds, a forced command) or a child that left the process
/// group would otherwise hold the result until the command finishes on its
/// own.
Future<SshExecCollectedOutput> collectSshExecOutput({
  required Stream<List<int>> stdout,
  required Stream<List<int>> stderr,
  required Future<void> commandDone,
  required Duration drainTimeout,
  OnExecOutput? onStdout,
  OnExecOutput? onStderr,
  Future<void>? cancel,
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final decoder = const Utf8Decoder(allowMalformed: true);

  Object? streamError;
  StackTrace? streamErrorStackTrace;

  // A callback that throws is the caller's error, not the stream's: kept as
  // [streamError] like one, rather than escaping into the zone from inside
  // the subscription while the output goes on being collected.
  void deliver(OnExecOutput? callback, String chunk) {
    if (callback == null) return;
    try {
      callback(chunk);
    } catch (error, trace) {
      streamError ??= error;
      streamErrorStackTrace ??= trace;
    }
  }

  // Subscriptions rather than `forEach`, so that giving up on the drain can
  // actually let go of the streams instead of leaving them writing into
  // buffers nobody will read.
  final outSub = decoder.bind(stdout).listen((chunk) {
    out.write(chunk);
    deliver(onStdout, chunk);
  });
  final errSub = decoder.bind(stderr).listen((chunk) {
    err.write(chunk);
    deliver(onStderr, chunk);
  });

  // These must be obtained while the subscriptions are still live. Calling
  // asFuture after a done event has already been delivered creates futures
  // that can no longer complete. `asFuture` also replaces the subscription's
  // error callback, so catch its error here and keep the output buffered up to
  // that point instead of letting the collector throw it away.
  Future<void> captureDone(StreamSubscription<String> subscription) async {
    try {
      await subscription.asFuture<void>();
    } catch (error, trace) {
      streamError ??= error;
      streamErrorStackTrace ??= trace;
    }
  }

  final outDone = captureDone(outSub);
  final errDone = captureDone(errSub);

  var abandoned = false;
  await Future.any([
    commandDone,
    if (cancel != null)
      cancel.then(
        (_) => commandDone.timeout(
          drainTimeout,
          onTimeout: () => abandoned = true,
        ),
      ),
  ]);

  var incomplete = false;
  if (abandoned) {
    incomplete = true;
    await outSub.cancel();
    await errSub.cancel();
  } else {
    await Future.wait([outDone, errDone]).timeout(
      drainTimeout,
      onTimeout: () async {
        incomplete = true;
        await outSub.cancel();
        await errSub.cancel();
        return const <void>[];
      },
    );
  }

  return (
    stdout: out.toString(),
    stderr: err.toString(),
    outputIncomplete: incomplete,
    streamError: streamError,
    streamErrorStackTrace: streamErrorStackTrace,
  );
}

/// The id of the session a command runs in, printed by the command itself.
///
/// sshd starts every command in a session of its own (`setsid()`), so its
/// login shell's pid is the session id, and an `exec` keeps the pid. That id
/// reaches every process the command started that did not leave the session
/// — which a process group does not: `set -m`, a build tool or a shell's job
/// control moves children into groups of their own, out of reach of the
/// signal SSH delivers.
abstract final class SshSessionId {
  /// The line [wrap] prints on stderr before anything of the command runs.
  static final marker = RegExp('\x1esbm-sid:(\\d+)\x1e\n');

  /// [command] run as before — by the login shell, `$SHELL` — after `sh` has
  /// printed [marker].
  ///
  /// The login shell need not be a POSIX one, so what it is handed is valid
  /// in fish as well: one single-quoted program, and [command] single-quoted
  /// with every `'` and `\` written as a `printf %b` escape — inside single
  /// quotes fish reads only `\'` and `\\`, POSIX shells nothing at all. A
  /// shell that rejects it anyway (cmd.exe, PowerShell, csh with a newline in
  /// quotes) runs none of [command]: the marker is printed before it starts.
  static String wrap(String command) {
    final arg = command
        .replaceAll(r'\', r'\0134')
        .replaceAll("'", r'\0047');
    return r'''exec sh -c 'printf "\036sbm-sid:%s\036\n" $$ >&2; '''
        r'''exec "${SHELL:-sh}" -c "$(printf %b "$1")"' sbm '''
        "'$arg'";
  }

  /// Kills every process left in session [id] and prints [gone] when none
  /// is: POSIX `sh`, handed over in single quotes as [wrap] does, so that a
  /// fish login shell can run it too. Signals the process group as well, for
  /// a `pkill` without `-s`.
  ///
  /// Waits a moment only when there was something to kill, for it to be
  /// gone from the process table.
  static String kill(int id) =>
      "sh -c 'kill -KILL -- -$id 2>/dev/null; "
      'pkill -KILL -s $id 2>/dev/null && sleep 1; '
      'pgrep -s $id >/dev/null 2>&1; '
      "[ \$? -eq 1 ] && echo $gone'";

  static const gone = 'sbm-session-gone';
}

/// [ServerExec] over an SSH connection.
///
/// One command, one channel — which is what SSH multiplexing is for, and why
/// running a command has never needed the interactive shell the terminal page
/// holds open.
///
/// Cancelling here really stops the command: the channel carries a signal,
/// and what the signal missed is killed by its session id from a channel of
/// its own — see [SshSessionId]. What is left of the output is what had
/// already arrived.
class SshExec implements ServerByteExec {
  const SshExec(this.client, {this.sudoPassword});

  final SSHClient client;

  /// The account's sudo password, for what a cancelled command left running
  /// as root; null, or a null answer, tries `sudo -n`.
  final Future<String?> Function()? sudoPassword;

  /// How long to keep reading once the command itself has finished.
  ///
  /// `session.done` completes when the process exits, which is not when the
  /// channel goes quiet: anything it left running still holds stdout open.
  /// Without a bound here a finished command reads as a hung one, and the only
  /// thing that ends it is whatever timeout the caller happens to have — five
  /// minutes, for the Agent.
  static const drainTimeout = Duration(seconds: 5);

  /// How long the signal gets to end a cancelled command before what is left
  /// of its session is killed from another channel.
  static const signalGrace = Duration(seconds: 2);

  /// How long each of those kills gets.
  static const _killTimeout = Duration(seconds: 10);

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
    // With no [entry] the script *is* the command, which leaves the channel's
    // stdin free to be stdin — where a sudo password belongs. With one, the
    // entry is the command and the script is what it reads.
    final command = entry ?? script;
    Future<_Run> exec(String command, {bool track = false}) => _exec(
      command,
      script: script,
      entry: entry,
      env: env,
      stdin: stdin,
      onStdout: onStdout,
      onStderr: onStderr,
      cancel: cancel,
      track: track,
    );
    // Nothing to stop, so no session id to know.
    if (cancel == null) return (await exec(command)).result;

    var cancelled = false;
    unawaited(cancel.then((_) => cancelled = true));
    final tracked = await exec(SshSessionId.wrap(command), track: true);
    if (!tracked.refused || cancelled) return tracked.result;
    // The login shell could not run the wrapper, and so ran none of the
    // command: run it as it is, stopped by the signal alone.
    return (await exec(command)).result;
  }

  Future<_Run> _exec(
    String command, {
    required String script,
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
    bool track = false,
  }) async {
    final session = await client.execute(command, environment: env);

    // Until the marker has come or stderr has ended without it, nothing is
    // passed on: output before then may be a login shell refusing the
    // wrapper, which is not the command's, and is run again without it.
    // Refused only on that end: stderr cut short any other way — cancelled,
    // or failed — says nothing about whether the command started.
    int? sessionId;
    var refused = false;
    final decided = Completer<void>();
    Stream<List<int>> stdout = session.stdout;
    Stream<List<int>> stderr = session.stderr;
    if (track) {
      stderr = _stripSessionId(
        session.stderr,
        decided,
        onId: (id) => sessionId = id,
        onRefused: () => refused = true,
      );
      stdout = _after(decided.future, stdout);
    } else {
      decided.complete();
    }
    bool started() => !track || sessionId != null;
    OnExecOutput? gated(OnExecOutput? callback) => callback == null
        ? null
        : (chunk) {
            if (started()) callback(chunk);
          };

    // Registered rather than awaited: this races the command, and a signal
    // that never comes must not hold the result up. Not after the channel has
    // closed: a signal on a channel the server has freed ends the whole
    // connection (OpenSSH: "server_input_channel_req: unknown channel"),
    // every other channel on it included.
    // `ignore`: a `done` that fails is the collector's to report, not this
    // flag's to raise again as an uncaught error.
    var ended = false;
    session.done.whenComplete(() => ended = true).ignore();
    var stopped = false;
    Future<bool?>? reaped;
    unawaited(
      cancel?.then((_) {
        if (ended) return;
        stopped = true;
        try {
          session.kill(SSHSignal.KILL);
        } catch (_) {
          // Already gone. Closing below is still what releases the channel.
        }
        session.close();
        reaped = _reap(session, () => sessionId);
      }),
    );

    final output = collectSshExecOutput(
      stdout: stdout,
      stderr: stderr,
      commandDone: session.done,
      drainTimeout: drainTimeout,
      onStdout: gated(onStdout),
      onStderr: gated(onStderr),
      cancel: cancel,
    );

    try {
      if (stdin != null) {
        session.stdin.add(Uint8List.fromList(utf8.encode(stdin)));
      }
      if (entry != null) {
        session.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
      }
      // Closed either way: a command that reads stdin would otherwise wait for
      // input nobody is going to send.
      await session.stdin.close();

      final collected = await output;
      final gone = await reaped;
      return (
        result: ExecResult(
          exitCode: session.exitCode,
          stdout: collected.stdout,
          stderr: collected.stderr,
          outputIncomplete: collected.outputIncomplete,
          streamError: collected.streamError,
          streamErrorStackTrace: collected.streamErrorStackTrace,
          // Either says so: a channel still open is held by something alive
          // — a process that left the session included — and a closed one
          // only means nothing holds the output any more.
          mayStillRun: stopped && (!ended || gone == false),
        ),
        refused: refused,
      );
    } finally {
      session.close();
    }
  }

  /// Kills what is left of a cancelled command's session — as the account,
  /// then through sudo for what runs as root — once the signal has had
  /// [signalGrace] to end it, and gives the channel as long again to close.
  ///
  /// Whether the session is empty; null with no session id to ask about.
  /// Asked even when the channel has closed: that only says nothing holds the
  /// output, and a child that let go of it can outlive the signal.
  Future<bool?> _reap(SSHSession session, int? Function() sessionId) async {
    Future<void> closed() async {
      try {
        await session.done.timeout(signalGrace);
      } catch (_) {
        // Timed out: held open, by a process the signal missed or a server
        // that refused it. What the session holds is asked below either way.
      }
    }

    await closed();
    final id = sessionId();
    if (id == null) return null;
    final kill = SshSessionId.kill(id);
    var gone = await _killed(kill);
    if (!gone) {
      final password = await sudoPassword?.call();
      gone = password == null
          ? await _killed('sudo -n $kill')
          : await _killed("sudo -S -p '' $kill", stdin: '$password\n');
    }
    await closed();
    return gone;
  }

  Future<bool> _killed(String command, {String? stdin}) async {
    try {
      final r = await _exec(
        command,
        script: command,
        stdin: stdin,
        // Not tracked: stopped by the signal, the most a kill needs.
        cancel: Future<void>.delayed(_killTimeout),
      );
      return r.result.stdout.contains(SshSessionId.gone);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ExecSession> start(String command) async =>
      _SshExecSession(await client.execute(command));
}

typedef _Run = ({ExecResult result, bool refused});

/// [stderr] without the [SshSessionId.marker] line, held back until it has
/// come or the stream has ended; [onId] gets the id it carried, [onRefused]
/// is told when the stream ended without it.
///
/// Looked for anywhere rather than on the first line: a login shell's rc file
/// can print before it. Whatever surrounds it is passed on as it was.
///
/// A transformer rather than an `async*` generator, here and in [_after]: a
/// generator waiting in `await for` or on a future finishes cancelling only
/// once it next yields, and a stream the server holds open never lets it.
Stream<List<int>> _stripSessionId(
  Stream<Uint8List> stderr,
  Completer<void> decided, {
  required void Function(int id) onId,
  required void Function() onRefused,
}) {
  final head = <int>[];
  return stderr.transform(
    StreamTransformer<Uint8List, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        if (decided.isCompleted) return sink.add(chunk);
        head.addAll(chunk);
        // Latin-1: one char per byte, so the match's offsets are byte offsets.
        final match = SshSessionId.marker.firstMatch(latin1.decode(head));
        if (match == null) return;
        onId(int.parse(match[1]!));
        decided.complete();
        final rest = [
          ...head.sublist(0, match.start),
          ...head.sublist(match.end),
        ];
        if (rest.isNotEmpty) sink.add(rest);
      },
      handleDone: (sink) {
        // Ended without it: what was held is the login shell's.
        if (!decided.isCompleted) {
          onRefused();
          decided.complete();
          if (head.isNotEmpty) sink.add(List.of(head));
        }
        sink.close();
      },
    ),
  );
}

/// [stream], from once [gate] completes; never listened to when cancelled
/// before that.
Stream<List<int>> _after(Future<void> gate, Stream<List<int>> stream) {
  StreamSubscription<List<int>>? sub;
  var cancelled = false;
  late final StreamController<List<int>> out;
  out = StreamController(
    onListen: () => gate.then((_) {
      if (cancelled) return;
      sub = stream.listen(out.add, onError: out.addError, onDone: out.close);
    }),
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () {
      cancelled = true;
      return sub?.cancel();
    },
  );
  return out.stream;
}

/// A command on an SSH channel, fed as it runs.
final class _SshExecSession implements ExecSession {
  _SshExecSession(this._session) {
    _session.done.whenComplete(() => _ended = true).ignore();
  }

  final SSHSession _session;

  /// The channel has closed: a signal on it now names a channel the server
  /// has freed, and OpenSSH ends the whole connection for that.
  var _ended = false;

  /// Bytes handed to the channel since it last caught up: past this, a write
  /// waits for the channel to send what it holds (the remote side's window),
  /// so a file is not read into memory faster than it leaves.
  static const _flushEvery = 1 << 20;
  var _unflushed = 0;

  static const _decoder = Utf8Decoder(allowMalformed: true);

  @override
  late final Stream<String> stdout = _decoder
      .bind(_session.stdout)
      .asBroadcastStream();

  @override
  late final Stream<String> stderr = _decoder
      .bind(_session.stderr)
      .asBroadcastStream();

  @override
  Future<void> write(List<int> data) async {
    _session.stdin.add(data is Uint8List ? data : Uint8List.fromList(data));
    _unflushed += data.length;
    if (_unflushed >= _flushEvery) {
      _unflushed = 0;
      await _session.flush();
    }
  }

  @override
  Future<void> closeStdin() async {
    await _session.flush();
    await _session.stdin.close();
  }

  @override
  Future<int?> get done async {
    await _session.done;
    return _session.exitCode;
  }

  @override
  void kill() {
    if (_ended) return;
    try {
      _session.kill(SSHSignal.KILL);
    } catch (_) {
      // Already gone; closing is still what releases the channel.
    }
    _session.close();
  }
}
