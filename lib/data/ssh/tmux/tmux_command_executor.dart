import 'dart:async';
import 'dart:collection';

import 'package:server_box/data/ssh/tmux/tmux_control_protocol.dart';

/// Owns the FIFO command queue for one tmux control-mode client.
///
/// This class is deliberately narrow: it knows how to enqueue a command,
/// complete the oldest pending command, fail every pending command, and expose
/// the startup result. It does not know about SSH, Flutter, tmux semantics, or
/// the protocol parser.
final class TmuxCommandExecutor {
  TmuxCommandExecutor({required void Function(String command) writeCommand})
    : _writeCommand = writeCommand {
    // `startup` is awaited by `initialize`, but a client can be closed before
    // that happens. Attach the same no-op error handler the old inline queue
    // used so an unobserved startup failure cannot become an unhandled future.
    unawaited(startup.then((_) {}, onError: (_) {}));
  }

  final void Function(String command) _writeCommand;
  final _pending = Queue<Completer<TmuxControlCommandResult>>();
  final _startupCompleter = Completer<TmuxControlCommandResult>();
  bool _closed = false;

  bool get isClosed => _closed;
  int get pendingCount => _pending.length;
  Future<TmuxControlCommandResult> get startup => _startupCompleter.future;

  /// Enqueues a command and writes it to the transport.
  Future<TmuxControlCommandResult> run(String command) {
    if (_closed) {
      return Future.error(StateError('tmux command executor is closed'));
    }
    final completer = Completer<TmuxControlCommandResult>();
    _pending.add(completer);
    _writeCommand(command);
    return completer.future;
  }

  /// Completes the startup command, then commands in FIFO order.
  void complete(TmuxControlCommandResult result) {
    if (_closed) return;
    if (!_startupCompleter.isCompleted) {
      _startupCompleter.complete(result);
      return;
    }
    if (_pending.isEmpty) return;
    _pending.removeFirst().complete(result);
  }

  /// Fails the startup command and every pending command.
  void fail(Object error, [StackTrace? stackTrace]) {
    if (_closed) return;
    if (!_startupCompleter.isCompleted) {
      _startupCompleter.completeError(error, stackTrace);
    }
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(error, stackTrace);
    }
  }

  /// Closes the queue and fails anything still waiting.
  void close() {
    if (_closed) return;
    final error = StateError('tmux command executor closed');
    if (!_startupCompleter.isCompleted) {
      _startupCompleter.completeError(error);
    }
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(error);
    }
    _closed = true;
  }
}
