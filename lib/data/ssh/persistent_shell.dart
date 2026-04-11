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

  static const _donePrefix = '__SERVER_BOX_DONE__';

  Future<PersistentShellCommandResult> run(String command) async {
    if (_closed) {
      throw StateError('Persistent shell already closed');
    }
    if (_pending != null) {
      throw StateError(
        'Another command is already running in the persistent shell',
      );
    }

    await _ensureSession();

    final completer = Completer<PersistentShellCommandResult>();
    _pending = completer;
    _buffer.clear();
    final commandId = (++_commandId).toString();
    final wrappedCommand = _wrapCommand(command, commandId);

    try {
      _session!.stdin.add(Uint8List.fromList(utf8.encode(wrappedCommand)));
    } catch (error, stackTrace) {
      _pending = null;
      completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  Future<void> close() async {
    _closed = true;
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
  }

  Future<void> _ensureSession() async {
    if (_session != null) {
      return;
    }

    final session =
        await _sessionFactory?.call() ??
        SshPersistentShellSession(await _client!.execute('sh'));
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
    if (pending == null) {
      return;
    }

    _buffer.write(data);
    final parsed = tryParseCompletedOutput(_buffer.toString());
    if (parsed == null) {
      return;
    }

    _pending = null;
    pending.complete(
      PersistentShellCommandResult(
        output: parsed.output,
        exitCode: parsed.exitCode,
      ),
    );
    _buffer.clear();
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
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error, stackTrace ?? StackTrace.current);
    }
    _buffer.clear();
  }

  static PersistentShellCommandResult? tryParseCompletedOutput(String raw) {
    final match = RegExp(
      '(?:^|\\n)${RegExp.escape(_donePrefix)}(\\d+):(\\d+)(?:\\r?\\n|\$)',
    ).firstMatch(raw);
    if (match == null) {
      return null;
    }

    final output = raw.substring(0, match.start);
    final exitCode = int.tryParse(match.group(2)!);
    return PersistentShellCommandResult(
      output: output.trimRight(),
      exitCode: exitCode,
    );
  }
}
