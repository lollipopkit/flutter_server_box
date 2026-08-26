import 'dart:async';

/// Serializes filesystem mutations that belong to one rootfs container.
final class RootfsLifecycle {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    try {
      await previous.catchError((_) {});
      return await action();
    } finally {
      release.complete();
    }
  }
}
