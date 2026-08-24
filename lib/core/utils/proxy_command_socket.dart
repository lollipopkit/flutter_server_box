import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';

class ProxyCommandSocket implements SSHSocket {
  ProxyCommandSocket._({
    required Process process,
    required Stream<Uint8List> stream,
    required IOSink sink,
    required Future<void> done,
  }) : _process = process,
       _stream = stream,
       _sink = sink,
       _done = done;

  final Process _process;
  final Stream<Uint8List> _stream;
  final IOSink _sink;
  final Future<void> _done;

  static Future<SSHSocket> connect({
    required String command,
    required String host,
    required int port,
    required String user,
    Duration? timeout,
  }) async {
    if (!isDesktop) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: l10n.proxyCommandOnlySupportedOnDesktop,
      );
    }
    if (command.length > 4096) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'ProxyCommand too long (${command.length} chars, max 4096)',
      );
    }

    final resolvedCommand = _resolveCommand(
      command: command,
      host: host,
      port: port,
      user: user,
    );
    final shellCommand = _buildShellCommand(resolvedCommand);

    Loggers.app.info('Starting ProxyCommand for $user@$host:$port');

    final process = await Process.start(
      shellCommand.executable,
      shellCommand.arguments,
      mode: ProcessStartMode.normal,
    );
    final connectionReady = Completer<void>();
    final stdoutController = StreamController<Uint8List>();

    process.stdout.listen(
      (data) {
        final chunk = Uint8List.fromList(data);
        stdoutController.add(chunk);
      },
      onError: (error, stackTrace) {
        stdoutController.addError(error, stackTrace);
      },
      onDone: () {
        stdoutController.close();
      },
    );
    // The transport is the stdio pair, not an unsolicited banner. Commands
    // like `ssh -W %h:%p` or `nc %h %p` wait for the caller's SSH handshake
    // on stdin before emitting anything, so waiting for a first stdout chunk
    // deadlocks: genClient cannot send the handshake until connect returns.
    // Consider the socket ready as soon as the child is spawned; early exits
    // will surface via stdoutController.done / process exit and the
    // subsequent SSH handshake failure rather than via a hanging connect.
    if (!connectionReady.isCompleted) connectionReady.complete();

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => Loggers.app.warning('ProxyCommand stderr: $line'),
          onError: (error, stackTrace) {
            Loggers.app.warning(
              'ProxyCommand stderr stream error',
              error,
              stackTrace,
            );
          },
        );

    // Early process exit before the handshake is still a connect failure,
    // but surfacing it via connectionReady is now covered by the immediate
    // completion above; the handshake will fail promptly when the stream
    // closes.
    unawaited(
      process.exitCode.then((code) {
        if (stdoutController.isClosed) return;
        if (code != 0) {
          // Non-zero exit after the stream is still open is worth surfacing
          // on stderr for diagnostics, but not as a transport failure for
          // the SSH handshake that may have already succeeded.
          Loggers.app.warning('ProxyCommand exited with code $code');
        }
      }),
    );

    if (timeout != null) {
      try {
        await connectionReady.future.timeout(timeout);
      } on TimeoutException {
        _killProcessTree(process);
        throw SSHErr(
          type: SSHErrType.connect,
          message: _explain(
            'ProxyCommand timed out after ${timeout.inSeconds}s.',
          ),
        );
      }
    } else {
      await connectionReady.future;
    }

    // The SSH socket's lifecycle is the byte stream, not the helper process.
    // A proxy that keeps its process alive after closing the transport would
    // otherwise leave SSHSocket.done pending forever, while a shell that
    // exits non-zero after forwarding ended would incorrectly report a
    // transport failure.
    final done = stdoutController.done;

    return ProxyCommandSocket._(
      process: process,
      stream: stdoutController.stream,
      sink: process.stdin,
      done: done,
    );
  }

  /// [message], plus what a sandboxed build has almost certainly done to it.
  ///
  /// Measured on a build signed with `app-sandbox`, against the same binary
  /// signed without it: the child does not merely lose access to `~/.ssh`, its
  /// `$HOME` is replaced by the app's container. So `~` silently points
  /// somewhere else and only an absolute path into the real home reports
  /// `Operation not permitted`.
  ///
  /// Which makes the failure unrecognisable. `ssh -W %h:%p alias` cannot read
  /// `~/.ssh/config`, so the alias is never resolved, ssh takes it for a literal
  /// hostname and reports `connect to host alias port 22: Operation timed
  /// out` — a network fault, naming the user's jump host, with nothing anywhere
  /// saying "sandbox".
  ///
  /// Appended rather than substituted, and hedged: a command that touches no
  /// home-directory path works there (`nc %h %p` was measured working, network
  /// access being granted), so this is the likely cause and not the certain one.
  static String _explain(String message) =>
      _explainFor(message, sandboxed: Pfs.isMacSandboxed);

  static String _explainFor(String message, {required bool sandboxed}) {
    if (!sandboxed) return message;
    return '$message\n\n${l10n.proxyCommandSandboxed}';
  }

  /// [_explainFor] with the confinement stated rather than asked of the
  /// process, since a test runs in neither of the two builds this is about.
  @visibleForTesting
  static String debugExplain(String message, {required bool sandboxed}) =>
      _explainFor(message, sandboxed: sandboxed);

  static String _resolveCommand({
    required String command,
    required String host,
    required int port,
    required String user,
  }) {
    const percentPlaceholder = '\u0000PERCENT\u0000';
    // Host/user/port are untrusted connection fields; interpolating them
    // raw into `/bin/sh -c` or `cmd /C` would let shell metacharacters in a
    // malicious imported config execute additional commands.
    String shellQuote(String value) {
      if (Platform.isWindows) {
        // Double-quote for cmd.exe; escape inner double quotes by doubling.
        return '"${value.replaceAll('"', '""')}"';
      }
      return "'${value.replaceAll("'", "'\\''")}'";
    }

    return command
        .replaceAll('%%', percentPlaceholder)
        .replaceAll('%h', shellQuote(host))
        .replaceAll('%p', port.toString())
        .replaceAll('%r', shellQuote(user))
        .replaceAll(percentPlaceholder, '%');
  }

  static ({String executable, List<String> arguments}) _buildShellCommand(
    String command,
  ) {
    if (Platform.isWindows) {
      return (executable: 'cmd', arguments: ['/C', command]);
    }
    return (executable: '/bin/sh', arguments: ['-c', command]);
  }

  @override
  Stream<Uint8List> get stream => _stream;

  @override
  StreamSink<List<int>> get sink => _sink;

  @override
  Future<void> get done => _done;

  static void _killProcessTree(Process process) {
    // Process.kill only signals the immediate child (usually /bin/sh); a
    // command like `ssh -W` or `nc` is a descendant and would be orphaned.
    // On Unix, try to kill the process group; fall back to the pid.
    try {
      if (!Platform.isWindows) {
        // Negative pid = process group (set via Process.start with detached?).
        // Dart's Process does not expose pgroup, so attempt killPid with
        // the child's pid; if the shell was started with setpgid, this may
        // miss the group, but is still better than signalling only the shell.
        Process.killPid(-process.pid);
      }
    } catch (_) {}
    process.kill(ProcessSignal.sigterm);
    // Give it a moment before SIGKILL
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
      try {
        if (!Platform.isWindows) Process.killPid(-process.pid, ProcessSignal.sigkill);
      } catch (_) {}
    });
  }

  @override
  Future<void> close() async {
    // Kill first so a child that ignores stdin EOF does not block close().
    _killProcessTree(_process);
    try {
      await _sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await _done.timeout(const Duration(seconds: 2)).catchError((_) {});
    } catch (_) {}
    // Ensure the process is gone even if the above timed out.
    _process.kill(ProcessSignal.sigkill);
    try {
      if (!Platform.isWindows) Process.killPid(-_process.pid, ProcessSignal.sigkill);
    } catch (_) {}
  }

  @override
  Future<void> flush() => _sink.flush();

  @override
  void destroy() {
    _killProcessTree(_process);
  }

  @override
  String toString() => 'ProxyCommandSocket(pid: ${_process.pid})';
}
