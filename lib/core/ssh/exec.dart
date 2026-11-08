import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/src/rust/api/exec_session.dart' as es;

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

/// The session a command runs in, which it prints itself: the programs are
/// `sbm_parser::exec_session`'s ([es]); the nonce that ties a printed id to
/// this run is drawn here.
abstract final class SshSessionId {
  /// A fresh value for `exec_session::ENV_NAME`.
  static String nonce() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}

/// [CommandExec] over an SSH connection.
///
/// One command, one channel — which is what SSH multiplexing is for, and why
/// running a command has never needed the interactive shell the terminal page
/// holds open.
///
/// Cancelling here really stops the command: the channel carries a signal,
/// and what the signal missed is killed by its session id from a channel of
/// its own — see `sbm_parser::exec_session`. What is left of the output is what had
/// already arrived.
class SshExec implements CommandByteExec {
  const SshExec(this.client, {this.sudoPassword});

  final SSHClient client;

  /// The account's sudo password, for what a cancelled command left running
  /// as root; null, or a null answer, tries `sudo -n`.
  final String? Function()? sudoPassword;

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

  /// How long each of the commands that stop one gets.
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
    Future<_Run> exec(String command, {String? nonce}) => _exec(
      command,
      script: script,
      entry: entry,
      env: env,
      stdin: stdin,
      onStdout: onStdout,
      onStderr: onStderr,
      cancel: cancel,
      nonce: nonce,
    );
    // Nothing to stop, so no session id to know.
    if (cancel == null) return (await exec(command)).result;

    var cancelled = false;
    unawaited(cancel.then((_) => cancelled = true));
    final nonce = SshSessionId.nonce();
    final tracked = await exec(
      es.execSessionWrap(command: command, nonce: nonce),
      nonce: nonce,
    );
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
    String? nonce,
  }) async {
    final session = await client.execute(command, environment: env);
    // Tracked: run through `exec_session::wrap` with this [nonce].
    final track = nonce != null;

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
        reaped = _stop(
          session,
          ended: () => ended,
          decided: decided.future,
          sessionId: () => sessionId,
          refused: () => refused,
          nonce: nonce,
        );
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

  /// Stops a cancelled command: the signal first, then — once it has had
  /// [signalGrace] — what is left of its session, as the account and, for
  /// what runs as root, through sudo. Gives the channel as long again to
  /// close.
  ///
  /// Whether the session is empty: false when it could not be confirmed this
  /// run's or emptied, or its id did not come in time to ask. Null with no
  /// session to ask about — untracked, or stderr ended without the marker,
  /// which the wrapper prints before the command starts — where the channel
  /// is what says.
  /// Asked even when the channel has closed: that only says nothing holds the
  /// output, and a child that let go of it can outlive the signal.
  Future<bool?> _stop(
    SSHSession session, {
    required bool Function() ended,
    required Future<void> decided,
    required int? Function() sessionId,
    required bool Function() refused,
    required String? nonce,
  }) async {
    Future<void> settled() async {
      try {
        await decided.timeout(signalGrace);
      } catch (_) {
        // Neither the marker nor the end of stderr in time.
      }
    }

    // A marker on its way is read rather than missed.
    await settled();
    final id = sessionId();
    // Before the signal, which ends what carries the nonce — see
    // `exec_session::owns_command`.
    final owned =
        id != null &&
        nonce != null &&
        await _confirms(es.execSessionOwnsCommand(id: id, nonce: nonce), es.execSessionOwned());
    // Not on a channel that has closed meanwhile: see [_exec].
    if (!ended()) {
      try {
        session.kill(SSHSignal.KILL);
      } catch (_) {
        // Already gone. Closing below is still what releases the channel.
      }
    }
    session.close();

    Future<void> closed() async {
      try {
        await session.done.timeout(signalGrace);
      } catch (_) {
        // Timed out: held open, by a process the signal missed or a server
        // that refused it. What the session holds is asked below either way.
      }
    }

    await closed();
    if (nonce == null) return null;
    if (id == null) {
      // Started for all that is known, unless stderr ended without the
      // marker; a late one arrived after the signal, too late to confirm.
      await settled();
      return refused() ? null : false;
    }
    if (!owned) return false;
    String kill(es.SudoEntry entry) => es.execSessionKillCommand(id: id, entry: entry);
    final goneMark = es.execSessionGone();
    var gone = await _confirms(kill(es.SudoEntry.direct), goneMark);
    if (!gone) {
      final password = sudoPassword?.call();
      gone = password == null
          ? await _confirms(kill(es.SudoEntry.sudoNoPassword), goneMark)
          : await _confirms(
              kill(es.SudoEntry.sudoPassword),
              goneMark,
              stdin: '$password\n',
            );
    }
    await closed();
    return gone;
  }

  /// Whether [command], run on a channel of its own, printed [answer].
  Future<bool> _confirms(String command, String answer, {String? stdin}) async {
    try {
      final r = await _exec(
        command,
        script: command,
        stdin: stdin,
        // Not tracked: stopped by the signal, the most these need.
        cancel: Future<void>.delayed(_killTimeout),
      );
      return r.result.stdout.contains(answer);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ExecSession> start(String command) async =>
      _SshExecSession(await client.execute(command));
}

typedef _Run = ({ExecResult result, bool refused});

/// [stderr] without the session marker line, held back until it has
/// come or the stream has ended; [onId] gets the id it carried, [onRefused]
/// is told when the stream ended without it.
///
/// Looked for anywhere rather than on the first line: a login shell's rc file
/// can print before it. Whatever surrounds it is passed on as it was.
///
/// A transformer rather than an `async*` generator, here and in [_after]: a
/// generator waiting in `await for` or on a future finishes cancelling only
/// once it next yields, and a stream the server holds open never lets it.
final _markerMax = es.execSessionMarkerMax();

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
        // The new chunk and what of the old a split marker can still need:
        // searching all of what was held each time would be quadratic in it.
        final from = max(0, head.length - _markerMax);
        head.addAll(chunk);
        final match = es.execSessionFindMarker(head: Uint8List.fromList(head.sublist(from)));
        if (match == null) return;
        onId(match.id);
        decided.complete();
        final rest = [
          ...head.sublist(0, from + match.start),
          ...head.sublist(from + match.end),
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
