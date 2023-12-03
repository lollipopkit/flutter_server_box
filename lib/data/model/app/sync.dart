import 'dart:async';

class SyncResult<T, E> {
  final List<T> up;
  final List<T> down;
  final Map<T, E> err;

  const SyncResult({
    required this.up,
    required this.down,
    required this.err,
  });

  @override
  String toString() {
    return 'SyncResult{up: $up, down: $down, err: $err}';
  }
}

abstract class SyncIface<T> {
  /// Merge [other] into [this], return [this] after merge.
  /// Data in [other] has higher priority than [this].
  FutureOr<void> sync(T other);
}
