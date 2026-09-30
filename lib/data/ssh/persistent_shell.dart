import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

final class PersistentShellCommandResult {
  final String output;
  final int? exitCode;

  const PersistentShellCommandResult({
    required this.output,
    required this.exitCode,
  });
}

abstract interface class PersistentShellSession {
  StreamSink<Uint8List> get stdin;
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;

  void close();
}

final class SshPersistentShellSession implements PersistentShellSession {
  final SSHSession _session;

  SshPersistentShellSession(this._session);

  @override
  StreamSink<Uint8List> get stdin => _session.stdin;

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  void close() {
    _session.close();
  }
}

/// [PersistentShellSession] over a command run on a pseudo-terminal.
///
/// [PersistentShell] writes a command and reads until a marker it appended,
/// which an SSH `exec` channel carries as is. A pseudo-terminal does not: it
/// echoes what is written into it, turns `\n` into `\r\n`, and a `sh` whose
/// stdin is a terminal is interactive and prints prompts — all of it landing
/// in the output being parsed. So [command] puts the terminal in raw mode
/// without echo and runs `sh` behind `cat`, whose stdin is then a pipe.
///
/// Nothing is written until [readyMarker] arrives: bytes written before `stty`
/// has run would still be echoed.
final class PtyPersistentShellSession implements PersistentShellSession {
  PtyPersistentShellSession._(this._session);

  final ShellSession _session;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  late final _stdin = StreamController<Uint8List>(sync: true)
    ..stream.listen(_session.write);
  StreamSubscription<Uint8List>? _sub;

  static const readyMarker = '__SERVER_BOX_PTY_READY__';

  /// Passed as the command's own argument, never typed into the terminal, so
  /// [readyMarker] cannot arrive as an echo of it.
  static const command =
      "stty raw -echo && printf '$readyMarker\\n' && cat | sh 2>&1";

  /// Runs [command] through [execute] and waits for it to be ready.
  static Future<PtyPersistentShellSession> open(
    Future<ShellSession> Function(String command) execute, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final session = await execute(command);
    final stdout = session.stdout;
    if (stdout == null) {
      session.close();
      throw StateError('The pseudo-terminal has no output');
    }
    final pty = PtyPersistentShellSession._(session);
    final ready = Completer<void>();
    final marker = utf8.encode('$readyMarker\n');
    final pending = <int>[];
    pty._sub = stdout.listen(
      (data) {
        if (ready.isCompleted) {
          pty._stdout.add(data);
          return;
        }
        pending.addAll(data);
        final at = _indexOf(pending, marker);
        if (at < 0) return;
        ready.complete();
        final rest = pending.sublist(at + marker.length);
        if (rest.isNotEmpty) pty._stdout.add(Uint8List.fromList(rest));
      },
      onError: (Object e, StackTrace st) {
        if (!ready.isCompleted) ready.completeError(e, st);
        if (!pty._stdout.isClosed) pty._stdout.addError(e, st);
      },
      onDone: () {
        if (!ready.isCompleted) {
          // `stty` or `cat` missing, or a shell that is not POSIX.
          ready.completeError(
            StateError(
              'The pseudo-terminal ended before it was ready: '
              '${utf8.decode(pending, allowMalformed: true).trim()}',
            ),
          );
        }
        pty._stdout.close();
      },
    );
    try {
      await ready.future.timeout(timeout);
    } catch (_) {
      pty.close();
      rethrow;
    }
    return pty;
  }

  static int _indexOf(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  /// Silent: a pseudo-terminal merges the two, and [command] sends `sh`'s
  /// stderr to the same place. Open until [close], since [PersistentShell]
  /// takes either stream ending for the shell ending.
  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  void close() {
    unawaited(_sub?.cancel());
    unawaited(_stdin.close());
    if (!_stdout.isClosed) unawaited(_stdout.close());
    unawaited(_stderr.close());
    _session.close();
  }
}

final class PersistentShell {
  PersistentShell(
    SSHClient? client, {
    Future<PersistentShellSession> Function()? sessionFactory,
  }) : _client = client,
       _sessionFactory = sessionFactory,
       assert(
         client != null || sessionFactory != null,
         'Either client or sessionFactory must be provided',
       );

  final SSHClient? _client;
  final Future<PersistentShellSession> Function()? _sessionFactory;

  PersistentShellSession? _session;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<PersistentShellCommandResult>? _pending;
  final StringBuffer _buffer = StringBuffer();
  final StringBuffer _stderrBuffer = StringBuffer();
  int _commandId = 0;
  bool _closed = false;
  Future<void> _stateLock = Future<void>.value();
  String? _pendingCommandId;

  static const _donePrefix = '__SERVER_BOX_DONE__';

  Future<PersistentShellCommandResult> run(
    String command, {
    Duration? timeout,
  }) async {
    final started = await _withStateLock(() async {
      if (_closed) {
        throw StateError('Persistent shell already closed');
      }
      if (_pending != null) {
        throw StateError(
          'Another command is already running in the persistent shell',
        );
      }

      final session = await _ensureSessionLocked();

      if (_closed) {
        throw StateError('Persistent shell already closed');
      }
      if (_pending != null) {
        throw StateError(
          'Another command is already running in the persistent shell',
        );
      }

      final completer = Completer<PersistentShellCommandResult>();
      _pending = completer;
      _buffer.clear();
      _stderrBuffer.clear();
      final commandId = (++_commandId).toString();
      _pendingCommandId = commandId;
      final wrappedCommand = _wrapCommand(command, commandId);

      try {
        session.stdin.add(Uint8List.fromList(utf8.encode(wrappedCommand)));
      } catch (error, stackTrace) {
        _pending = null;
        _pendingCommandId = null;
        await _disposeSession();
        return _StartedCommand(
          Future<PersistentShellCommandResult>.error(error, stackTrace),
          commandId,
        );
      }

      return _StartedCommand(completer.future, commandId);
    });

    if (timeout == null) {
      return started.future;
    }

    try {
      return await started.future.timeout(timeout);
    } on TimeoutException {
      final error = TimeoutException(
        'Persistent shell command timed out',
        timeout,
      );
      await _withStateLock(() async {
        if (_pendingCommandId == started.commandId) {
          await _disposeSession(pendingError: error);
        }
      });
      throw error;
    }
  }

  /// Opens the shell session if it is not open already.
  ///
  /// [run] does this on its first call after every connect, which puts a
  /// channel open and the remote shell's startup inside whatever that call is
  /// being timed for. A caller that times a command asks for the session
  /// first, so what it measures is the command.
  Future<void> ensureSession() async {
    await _withStateLock(() async {
      if (_closed) {
        throw StateError('Persistent shell already closed');
      }
      await _ensureSessionLocked();
    });
  }

  Future<void> close() async {
    _closed = true;
    await _withStateLock(() async {
      await _disposeSession(
        pendingError: StateError('Persistent shell closed'),
      );
    });
  }

  Future<PersistentShellSession> _ensureSessionLocked() async {
    if (_session != null) {
      return _session!;
    }

    final session =
        await _sessionFactory?.call() ??
        SshPersistentShellSession(await _client!.execute('sh'));

    if (_closed) {
      session.close();
      throw StateError('Persistent shell already closed');
    }

    _session = session;

    _stdoutSub = session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          _handleStdout,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
        );

    _stderrSub = session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          _handleStderr,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
        );

    return session;
  }

  String _wrapCommand(String command, String commandId) {
    return '''
(
$command
) 2>&1
__server_box_exit=\$?
printf '\\n$_donePrefix$commandId:%s\\n' "\$__server_box_exit"
''';
  }

  void _handleStdout(String data) {
    final pending = _pending;
    final pendingCommandId = _pendingCommandId;
    if (pending == null || pendingCommandId == null) {
      return;
    }

    _buffer.write(data);
    final raw = _buffer.toString();
    final parsed = _parseCompletedOutput(
      raw,
      expectedCommandId: pendingCommandId,
    );
    if (parsed == null) {
      return;
    }

    _pending = null;
    _pendingCommandId = null;
    pending.complete(
      PersistentShellCommandResult(
        output: [
          parsed.result.output,
          _stderrBuffer.toString().trim(),
        ].where((part) => part.isNotEmpty).join('\n'),
        exitCode: parsed.result.exitCode,
      ),
    );
    _buffer.clear();
    _stderrBuffer.clear();
    final remaining = raw.substring(parsed.consumedLength);
    if (remaining.isNotEmpty) {
      _buffer.write(remaining);
    }
  }

  void _handleStderr(String data) {
    final pending = _pending;
    if (pending == null) {
      return;
    }

    _stderrBuffer.write(data);
  }

  void _handleStreamDone() {
    unawaited(
      _disposeSession(
        pendingError: StateError('Persistent shell session ended unexpectedly'),
      ),
    );
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    Loggers.app.warning('Persistent shell stream error', error, stackTrace);
    unawaited(
      _disposeSession(pendingError: error, pendingStackTrace: stackTrace),
    );
  }

  Future<void> _disposeSession({
    Object? pendingError,
    StackTrace? pendingStackTrace,
  }) async {
    final session = _session;
    final stdoutSub = _stdoutSub;
    final stderrSub = _stderrSub;
    final pending = _pending;

    _session = null;
    _stdoutSub = null;
    _stderrSub = null;
    _pending = null;
    _pendingCommandId = null;

    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        pendingError ?? StateError('Persistent shell session disposed'),
        pendingStackTrace ?? StackTrace.current,
      );
    }
    _buffer.clear();

    await stdoutSub?.cancel();
    await stderrSub?.cancel();

    if (session != null) {
      try {
        session.close();
      } catch (error, stackTrace) {
        Loggers.app.warning(
          'Failed to close persistent shell',
          error,
          stackTrace,
        );
      }
    }
  }

  static _ParsedCompletedOutput? _parseCompletedOutput(
    String raw, {
    required String expectedCommandId,
  }) {
    final match = RegExp(
      '(?:^|\\n)${RegExp.escape(_donePrefix)}${RegExp.escape(expectedCommandId)}:(\\d+)(?:\\r?\\n|\$)',
    ).firstMatch(raw);
    if (match == null) {
      return null;
    }

    final output = raw.substring(0, match.start);
    final exitCode = int.tryParse(match.group(1)!);
    return _ParsedCompletedOutput(
      result: PersistentShellCommandResult(
        output: output.trimRight(),
        exitCode: exitCode,
      ),
      consumedLength: match.end,
    );
  }

  Future<T> _withStateLock<T>(Future<T> Function() fn) async {
    final previous = _stateLock;
    final release = Completer<void>();
    _stateLock = release.future;
    await previous;
    try {
      return await fn();
    } finally {
      release.complete();
    }
  }
}

final class _ParsedCompletedOutput {
  final PersistentShellCommandResult result;
  final int consumedLength;

  const _ParsedCompletedOutput({
    required this.result,
    required this.consumedLength,
  });
}

final class _StartedCommand {
  final Future<PersistentShellCommandResult> future;
  final String commandId;

  const _StartedCommand(this.future, this.commandId);
}
