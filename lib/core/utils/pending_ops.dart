import 'package:flutter/foundation.dart';

/// Tracks concurrent async operations by key:
/// - prevents re-entry for the same key;
/// - aggregates busy state into [loading];
/// - stops notifying after [dispose].
final class PendingOps {
  final Set<Object> _active = {};
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  var _disposed = false;

  /// Whether at least one operation is currently running.
  ValueListenable<bool> get loading => _loading;

  bool get isBusy => _active.isNotEmpty;

  bool isRunning(Object key) => _active.contains(key);

  /// Runs [fn] under [key], returning `null` without calling [fn] if [key] is
  /// already active or this instance has been disposed.
  Future<T?> run<T>(Object key, Future<T> Function() fn) async {
    if (_disposed || !_active.add(key)) return null;
    _sync();
    try {
      return await fn();
    } finally {
      _active.remove(key);
      _sync();
    }
  }

  void _sync() {
    if (_disposed) return;
    final busy = _active.isNotEmpty;
    if (_loading.value != busy) _loading.value = busy;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active.clear();
    _loading.dispose();
  }
}
