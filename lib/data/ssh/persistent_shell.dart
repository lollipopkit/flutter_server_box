import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';

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
  int _commandId = 0;
  bool _closed = false;
  Future<void> _stateLock = Future<void>.value();
  String? _pendingCommandId;

  static const _donePrefix = '__SERVER_BOX_DONE__';

  Future<PersistentShellCommandResult> run(String command) async {
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
      final commandId = (++_commandId).toString();
      _pendingCommandId = commandId;
      final wrappedCommand = _wrapCommand(command, commandId);

      try {
        session.stdin.add(Uint8List.fromList(utf8.encode(wrappedCommand)));
      } catch (error, stackTrace) {
        _pending = null;
        _pendingCommandId = null;
        completer.completeError(error, stackTrace);
      }

      return _StartedCommand(completer.future);
    });

    return started.future;
  }

  Future<void> close() async {
    _closed = true;
    await _withStateLock(() async {
      final session = _session;
      _session = null;

      await _stdoutSub?.cancel();
      await _stderrSub?.cancel();
      _stdoutSub = null;
      _stderrSub = null;

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

      _failPending(StateError('Persistent shell closed'));
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
        .transform(const Utf8Decoder())
        .listen(
          _handleStdout,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
        );

    _stderrSub = session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder())
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
        output: parsed.result.output,
        exitCode: parsed.result.exitCode,
      ),
    );
    _buffer.clear();
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

    _buffer.write(data);
  }

  void _handleStreamDone() {
    _session = null;
    _stdoutSub = null;
    _stderrSub = null;
    _failPending(StateError('Persistent shell session ended unexpectedly'));
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    Loggers.app.warning('Persistent shell stream error', error, stackTrace);
    _session = null;
    _failPending(error, stackTrace);
  }

  void _failPending(Object error, [StackTrace? stackTrace]) {
    final pending = _pending;
    _pending = null;
    _pendingCommandId = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error, stackTrace ?? StackTrace.current);
    }
    _buffer.clear();
  }

  static PersistentShellCommandResult? tryParseCompletedOutput(
    String raw, {
    required String expectedCommandId,
  }) {
    return _parseCompletedOutput(
      raw,
      expectedCommandId: expectedCommandId,
    )?.result;
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

  const _StartedCommand(this.future);
}
