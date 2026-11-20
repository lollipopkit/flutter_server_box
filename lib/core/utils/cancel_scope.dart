import 'dart:async';

/// Cooperative cancellation scope separating immediate local resource teardown
/// from background remote reclamation.
///
/// Each scope instance has its own identity (`identical(current, scope)`) so
/// callbacks from superseded operations cannot mutate state owned by a newer
/// operation.
final class CancelScope {
  var _canceled = false;
  final _onLocal = <FutureOr<void> Function()>[];
  final _onRemote = <Future<void> Function()>[];
  final _canceledCompleter = Completer<void>();
  Future<void>? _localFuture;
  Future<void>? _remoteFuture;

  bool get isCanceled => _canceled;

  /// Completes as soon as [cancel] is invoked.
  Future<void> get onCanceled => _canceledCompleter.future;

  /// Completes once all registered remote cleanup tasks have settled after
  /// [cancel]. Returns an already-completed future if none were registered.
  Future<void> get remoteDone => _remoteFuture ?? Future.value();

  /// Registers a fast local teardown step (e.g. closing a local listener or
  /// destroying local sockets). Runs immediately if already canceled.
  void onLocalDispose(FutureOr<void> Function() fn) {
    if (_canceled) {
      unawaited(Future<void>.sync(fn).catchError((_) {}));
      return;
    }
    _onLocal.add(fn);
  }

  /// Registers a potentially slow remote reclamation step (e.g. WebSocket or
  /// SSH close handshake). Initiated on [cancel], awaited only when
  /// `waitRemote: true` or via [remoteDone].
  void onRemoteDispose(Future<void> Function() fn) {
    if (_canceled) {
      final f = Future<void>.sync(fn).catchError((_) {});
      final prev = _remoteFuture;
      _remoteFuture = prev == null ? f : Future.wait([prev, f]).then((_) {});
      return;
    }
    _onRemote.add(fn);
  }

  /// Cancels this scope.
  ///
  /// Local teardowns always complete before returning. Remote cleanups are
  /// started immediately and only awaited when [waitRemote] is true.
  Future<void> cancel({bool waitRemote = false}) async {
    if (!_canceled) {
      _canceled = true;
      if (!_canceledCompleter.isCompleted) _canceledCompleter.complete();

      final locals = _onLocal.toList();
      _onLocal.clear();
      _localFuture = Future.wait([
        for (final fn in locals) Future<void>.sync(fn).catchError((_) {}),
      ]).then((_) {});

      final remotes = _onRemote.toList();
      _onRemote.clear();
      if (remotes.isNotEmpty) {
        _remoteFuture = Future.wait([
          for (final fn in remotes) Future<void>.sync(fn).catchError((_) {}),
        ]).then((_) {});
        unawaited(_remoteFuture);
      }
    }

    await _localFuture;
    if (waitRemote) await _remoteFuture;
  }
}
