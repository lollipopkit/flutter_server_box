import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/scp_protocol.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';
import 'package:server_box/core/utils/shell_file_ops.dart';
import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// [FileBackend] over `scp` and a shell.
///
/// The third way to a server's files, and the one for a host that cannot offer
/// the second: SFTP is a subsystem sshd is built and configured to serve, and
/// an OpenWrt router running dropbear, or an embedded box whose firmware ships
/// one static `scp`, has no such thing (#1288). What it does have is a shell,
/// which is all this needs.
///
/// The split is the protocol's own. SCP moves the bytes of one file and says
/// nothing else — no listing, no stat, no rename — so [read] and [write] go
/// over `scp` and everything else is a command. That is not a workaround: `scp`
/// itself is started by running a command, so a host that can do the one can do
/// the other.
///
/// Wraps a client somebody else opened, like [SftpFileBackend], and for the
/// same reason: who owns the SSH connection is not a question this answers.
/// Unlike that one it holds no channel of its own — every operation opens one,
/// uses it and closes it — so [close] has nothing to do.
class ScpFileBackend implements FileBackend {
  ScpFileBackend(this._client, {this.escalation, this.timeout});

  final SSHClient _client;

  /// What to do when the server refuses. Null means take no for an answer,
  /// which is right for a transfer running in an isolate with nobody to ask.
  final SftpEscalation? escalation;

  /// How long any one operation may take. Null waits forever, which is right
  /// inside a transfer that has its own progress to show.
  final Duration? timeout;

  /// What bounds a step of a *transfer*, as opposed to a command.
  ///
  /// A command answers at once or not at all, so [timeout] — five seconds by
  /// default — is the right bound for one. A transfer is bounded by the gap
  /// between bytes, and five seconds of silence on a slow link is not a stall,
  /// it is a slow link: bounding a download that way would abort every large
  /// file over a bad connection. The SFTP download path draws the same
  /// distinction, and settles on the same floor.
  Duration? get _streamTimeout {
    final bound = timeout;
    if (bound == null) return null;
    return bound < _minStreamTimeout ? _minStreamTimeout : bound;
  }

  static const _minStreamTimeout = Duration(seconds: 60);

  /// The `scp` channels this backend has open right now.
  ///
  /// Held so [close] can end them. Every operation opens a channel of its own
  /// and closes it, which is why this class holds none in the ordinary case —
  /// but a caller that gives up on a `write` (the Agent's `write_file` bounds
  /// itself with `.timeout`) abandons the future, not the transfer: the remote
  /// `scp -t` goes on writing its staging file with nobody left to rename or
  /// remove it. `close` is the one thing such a caller does next, so it is what
  /// has to mean "stop".
  final _open = <ScpChannel>{};

  /// Whether [close] has been called. Once it has, this backend opens nothing
  /// more.
  ///
  /// Registering a channel is not enough on its own: opening one is itself an
  /// `await`, and a `close` that landed during it found [_open] empty and left
  /// the channel that arrived afterwards running with nobody holding it. That
  /// is the exact case `close` exists for — a caller that bounded a `write`
  /// with `.timeout` and gave up — so it is the one that must not slip through.
  var _closed = false;

  /// The channel [open] makes, registered so [close] can end it.
  ///
  /// [open] is a closure rather than a future already in flight, so that a
  /// backend already closed starts nothing: `client.execute` is what runs
  /// `scp` on the far side, and passing the future in meant the remote process
  /// had begun — for `scp -t`, with a staging file to show for it — before
  /// anything here got to look at [_closed]. Checked again afterwards, since
  /// `close` can also land while the channel is being opened.
  Future<ScpChannel> _opened(Future<ScpChannel> Function() open) async {
    if (_closed) throw const ScpShellException('The connection was closed');
    final channel = await open();
    if (_closed) {
      channel.close();
      throw const ScpShellException('The connection was closed');
    }
    _open.add(channel);
    return channel;
  }

  Future<T> _through<T>(
    Future<ScpChannel> Function() open,
    Future<T> Function(ScpChannel channel) run,
  ) async {
    final channel = await _opened(open);
    try {
      return await run(channel);
    } finally {
      _open.remove(channel);
    }
  }

  /// Whatever the SSH account can reach, which the far side decides per path
  /// rather than by a list anything here could enumerate.
  @override
  Future<List<String>> reachableRoots() async => const [];

  @override
  FileBackendTraits get traits => FileBackendTraits(
    // Both from `stat -c %a` and to `chmod`. This is the one thing SCP is
    // better at than the local backend, which has no `chmod` at all.
    permissions: true,
    symlinks: true,
    // Not a property of SCP but of this connection: escalating means running a
    // shell command, and a session already root has nowhere to escalate to.
    sudoFallback: escalation?.available ?? false,
  );

  @override
  Future<List<FileEntry>> list(String path) => escalate(
    escalation: escalation,
    normal: () async => parseShellFileRecords(
      await _run('list directory', shellListCommand(path)),
    ),
    // The same command, run by somebody else. A directory this user may not
    // list is exactly the case sudo exists for.
    sudoCommand: () => shellListCommand(path),
    fromOutput: parseShellFileRecords,
  );

  @override
  Future<FileEntry?> stat(String path) async {
    final result = await _exec('stat', shellStatCommand(path));
    // What the command said, before what the channel said: a host that reports
    // no exit status at all still printed its answer, and reading only the
    // exit code would leave every such host unable to say "nothing there" —
    // which is the answer a copy into a directory that does not exist yet
    // depends on.
    final entries = parseShellFileRecords(result.stdout);
    if (entries.isNotEmpty) return entries.first;

    final said = result.stdout.trim();
    // Absent is null; anything else — including a directory on the way this
    // user may not search — is an error, because a caller that reads a refusal
    // as "nothing there" goes on to create something over it.
    if (said == kShellStatAbsentMark || result.code == kShellStatAbsent) {
      return null;
    }
    if (said == kShellStatDeniedMark || result.code == kShellStatDenied) {
      throw ScpShellException('Permission denied: $path');
    }
    throw ScpShellException(result.describe('stat'));
  }

  @override
  Future<void> mkdir(String path) => runWithEscalation(
    escalation: escalation,
    // No `-p`: the other two backends refuse to create a directory that is
    // already there, and a browser that silently succeeded would leave the
    // user thinking the name was free.
    normal: () => _run('mkdir', 'mkdir -- ${shellSingleQuote(path)}'),
    // `-p` here, unchanged from what the SFTP backend escalates: this arrives
    // through `sudo`, where a second attempt after a partial failure is worth
    // more than the distinction above.
    sudoCommand: () => 'mkdir -p -- ${shellSingleQuote(path)}',
  );

  @override
  Future<void> remove(String path, {bool recursive = false}) {
    final quoted = shellSingleQuote(path);
    // One command whichever it turns out to be, rather than a stat and then a
    // decision: two round trips over a link this backend exists because it is
    // slow, to answer a question the shell can answer where the file is.
    //
    // `-L` before `-d`, so a symlink to a directory is unlinked rather than
    // handed to `rmdir`, which every system refuses.
    final command = recursive
        ? 'rm -r -- $quoted'
        : 'if [ -d $quoted ] && [ ! -L $quoted ]; '
              'then rmdir -- $quoted; else rm -- $quoted; fi';
    return runWithEscalation(
      escalation: escalation,
      normal: () => _run('remove', command),
      sudoCommand: () => command,
    );
  }

  @override
  Future<void> rename(String from, String to) {
    final command = shellRenameCommand(from, to);
    return runWithEscalation(
      escalation: escalation,
      normal: () => _run('rename', command),
      sudoCommand: () => command,
    );
  }

  @override
  Future<void> chmod(String path, int mode) {
    final command =
        'chmod ${mode.toRadixString(8)} -- ${shellSingleQuote(path)}';
    return runWithEscalation(
      escalation: escalation,
      normal: () => _run('chmod', command),
      sudoCommand: () => command,
    );
  }

  @override
  Stream<List<int>> read(String path, {int offset = 0}) async* {
    // Opened when the stream is listened to rather than when it is built, so a
    // caller that never reads never starts a process on the far side.
    final channel = await _opened(() => SshScpChannel.source(_client, path));
    try {
      yield* scpRead(channel, path, offset: offset, timeout: _streamTimeout);
    } finally {
      _open.remove(channel);
    }
  }

  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    void Function(String staging)? onStaging,
    // Never consumed, as on the local and SFTP backends: this makes one
    // attempt. Replaying would mean opening a second `scp -t` for a staging
    // file whose first writer may still be holding it.
    Stream<List<int>> Function()? replayData,
  }) async {
    // Beside the destination, as the other two backends do: `mv` within one
    // directory is atomic, so nothing ever reads a half-written file under the
    // name it is about to have.
    final staging = stagingNameFor(path);
    onStaging?.call(staging);
    try {
      if (size != null) {
        await _through(
          () => SshScpChannel.sink(_client, staging),
          (channel) => scpWrite(
            channel,
            staging,
            data,
            size: size,
            timeout: _streamTimeout,
          ),
        );
      } else {
        await _writeUnsized(staging, data);
      }
      await carryModeToStaging(this, staging, path);
      // Plain `mv`, where SFTP needs a dance: `SSH_FXP_RENAME` is specified to
      // fail when the destination exists and only some servers replace it,
      // while `rename(2)` — which is what `mv` does within one directory —
      // always has.
      //
      // Shared with [rename], so the guard below cannot be in one and not the
      // other, and escalated for the same reason [rename] is: the bytes are
      // already across by now, and a destination directory this user may not
      // write to is precisely what sudo is offered for. Without it an upload
      // into a root-owned directory staged its copy, carried the mode over and
      // then failed on the last step with no way forward.
      final command = shellRenameCommand(staging, path);
      await runWithEscalation(
        escalation: escalation,
        normal: () => _run('rename', command),
        sudoCommand: () => command,
      );
    } catch (_) {
      try {
        // `-f`, because the failure may well be that the staged copy was never
        // created. The write's own error is the one worth reporting.
        await _run('remove', 'rm -f -- ${shellSingleQuote(staging)}');
      } catch (_) {}
      rethrow;
    }
  }

  /// [scpWrite] for a caller that could not say how many bytes it has.
  ///
  /// The size is a hint everywhere else in the app and a contract in SCP — the
  /// sink is told the length before the contents start. So a stream of unknown
  /// length is spooled to this device first, purely to measure it. Every
  /// backend the app copies *from* reports a size, so this is the path nothing
  /// normally takes; it exists because the alternative is refusing the write.
  Future<void> _writeUnsized(String staging, Stream<List<int>> data) async {
    final dir = await Directory.systemTemp.createTemp('sb-scp');
    final spool = File('${dir.path}/spool');
    try {
      final sink = spool.openWrite();
      try {
        // Bounded like the sized path's own `await for`: this runs before SCP
        // is involved at all, so nothing else here would ever notice a
        // producer that stopped emitting.
        final source = data.map(
          (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
        );
        final bound = _streamTimeout;
        await sink.addStream(bound == null ? source : source.timeout(bound));
        await sink.close();
      } catch (_) {
        // Closing a sink whose stream failed throws "File closed", which would
        // replace the error worth reporting with one about the cleanup.
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
      final length = await spool.length();
      await _through(
        () => SshScpChannel.sink(_client, staging),
        (channel) => scpWrite(
          channel,
          staging,
          spool.openRead(),
          size: length,
          timeout: _streamTimeout,
        ),
      );
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (e, s) {
        Loggers.app.warning('Failed to remove an SCP spool', e, s);
      }
    }
  }

  /// Ends whatever is still running, and leaves the connection alone — it
  /// belongs to whoever handed it over.
  ///
  /// Not a no-op, which is what this was. A caller that stops waiting on an
  /// operation has no other way to stop the operation itself: `FileBackend` has
  /// no cancellation, so `close` is it, and the SFTP backend has always meant
  /// the same thing by closing its channel.
  @override
  Future<void> close() async {
    _closed = true;
    for (final channel in _open.toList()) {
      try {
        channel.close();
      } catch (e, s) {
        Loggers.app.warning('Failed to close an scp channel', e, s);
      }
    }
    _open.clear();
  }

  /// Runs [command] and answers what it printed, or throws what it said.
  ///
  /// Success is proved rather than inferred. Reading it off the exit status
  /// alone cannot work here — some hosts, dropbear among them, close the
  /// channel without an exit-status message, and that is most of the reason
  /// this backend exists — while treating a missing status as success unless
  /// something was written to stderr is a guess that a silent failure passes:
  /// a `mkdir`, `mv` or `chmod` that did nothing then reported that it had.
  /// So the command appends a marker of its own, which only runs if the
  /// command before it succeeded, and its absence is the failure.
  Future<String> _run(String what, String command) async {
    final result = await _exec(what, '{ $command; } && printf "%s" $_okMark');
    final said = result.stdout;
    final code = result.code;
    if (!said.endsWith(_okMark) || (code != null && code != 0)) {
      throw ScpShellException(result.describe(what));
    }
    return said.substring(0, said.length - _okMark.length);
  }

  /// What [_run] appends to a command that worked. Not a word anybody types,
  /// because a listing's output is checked for it.
  static const _okMark = '__sb_ok__';

  Future<_ShellResult> _exec(String what, String command) async {
    final session = await _client.execute(command);
    try {
      final out = BytesBuilder(copy: false);
      final err = BytesBuilder(copy: false);
      final gathered = Future.wait([
        session.stdout.forEach(out.add),
        session.stderr.forEach(err.add),
      ]);
      final bound = timeout;
      if (bound == null) {
        await gathered;
        await session.waitForExit();
      } else {
        try {
          await gathered.timeout(bound);
        } on TimeoutException catch (e, s) {
          final error = TimeoutException('SCP $what timed out', bound);
          Loggers.app.warning(error.message, e, s);
          throw error;
        }
        await session.waitForExit(timeout: bound);
      }
      return _ShellResult(
        session.exitCode,
        utf8.decode(out.takeBytes(), allowMalformed: true),
        utf8.decode(err.takeBytes(), allowMalformed: true),
      );
    } finally {
      session.close();
    }
  }
}

/// What a command run for [ScpFileBackend] reported.
///
/// Readable rather than a class name in a snackbar, and carrying the far side's
/// own words: `classifyFileError` reads those to tell a refusal from an absence,
/// which is what decides whether the browser offers sudo.
final class ScpShellException implements Exception {
  const ScpShellException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class _ShellResult {
  const _ShellResult(this.code, this.stdout, this.stderr);

  final int? code;
  final String stdout;
  final String stderr;

  String describe(String what) {
    final said = stderr.trim();
    if (said.isNotEmpty) return said;
    return 'Failed to $what${code == null ? '' : ' (exit $code)'}';
  }
}
