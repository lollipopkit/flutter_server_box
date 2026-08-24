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
        message: 'ProxyCommand is only supported on desktop platforms.',
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
        if (chunk.isNotEmpty && !connectionReady.isCompleted) {
          connectionReady.complete();
        }
        stdoutController.add(chunk);
      },
      onError: (error, stackTrace) {
        if (!connectionReady.isCompleted) {
          connectionReady.completeError(error, stackTrace);
        }
        stdoutController.addError(error, stackTrace);
      },
      onDone: () {
        if (!connectionReady.isCompleted) {
          connectionReady.completeError(
            SSHErr(
              type: SSHErrType.connect,
              message: _explain(
                'ProxyCommand exited before connection was established.',
              ),
            ),
          );
        }
        stdoutController.close();
      },
    );

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

    unawaited(
      process.exitCode.then((code) {
        if (connectionReady.isCompleted) return;
        if (code == 0) {
          connectionReady.completeError(
            SSHErr(
              type: SSHErrType.connect,
              message: _explain(
                'ProxyCommand exited before connection was established.',
              ),
            ),
          );
          return;
        }
        connectionReady.completeError(
          SSHErr(
            type: SSHErrType.connect,
            message: _explain('ProxyCommand exited with code $code.'),
          ),
        );
      }),
    );

    if (timeout != null) {
      try {
        await connectionReady.future.timeout(timeout);
      } on TimeoutException {
        process.kill();
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

    final done = process.exitCode.then((code) {
      if (code != 0) {
        throw SSHErr(
          type: SSHErrType.connect,
          message: _explain('ProxyCommand exited with code $code.'),
        );
      }
    });

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

  /// Everything a hostname, an IPv4 or IPv6 literal, or a POSIX user name is
  /// made of, and nothing a shell reads as syntax. `%` is absent on purpose:
  /// a value carrying one could introduce a placeholder of its own.
  static final _substitutable = RegExp(r'^[A-Za-z0-9._:@\-\[\]\\]*$');

  /// Refuses a value that `/bin/sh` would not read as one word.
  ///
  /// The expansion below is textual and the result is handed to `sh -c`, so a
  /// host of `h; curl … | sh` is a local command that runs before anything has
  /// been authenticated. That the ProxyCommand itself is the user's own is not
  /// the answer: the address it expands is not necessarily — it arrives from
  /// an imported `~/.ssh/config`, a restored backup or a synced peer.
  ///
  /// Rejected rather than quoted. Quoting correctly means knowing which
  /// context the placeholder sits in — bare, inside `"…"`, inside `'…'` — and
  /// guessing that wrong is how a quoting fix becomes the next injection.
  /// Nothing that names a real host or user is refused here.
  @visibleForTesting
  static String checkSubstitutable(String what, String value) {
    if (_substitutable.hasMatch(value)) return value;
    throw SSHErr(
      type: SSHErrType.connect,
      message:
          'ProxyCommand cannot use this $what: "$value" contains characters '
          'a shell would read as syntax.',
    );
  }

  static String _resolveCommand({
    required String command,
    required String host,
    required int port,
    required String user,
  }) {
    const percentPlaceholder = '\u0000PERCENT\u0000';
    return command
        .replaceAll('%%', percentPlaceholder)
        .replaceAll('%h', checkSubstitutable('host', host))
        .replaceAll('%p', port.toString())
        .replaceAll('%r', checkSubstitutable('user', user))
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

  @override
  Future<void> close() async {
    await _sink.close();
    if (_process.kill()) {
      await _done.catchError((_) {});
      return;
    }
    await _done.catchError((_) {});
  }

  @override
  Future<void> flush() => _sink.flush();

  @override
  void destroy() {
    _process.kill();
  }

  @override
  String toString() => 'ProxyCommandSocket(pid: ${_process.pid})';
}
