import 'dart:async';

/// One run of [_run] at a time; the requests made while it runs become a
/// single run after it. For pushes whose every run sends the latest state,
/// so that a burst of changes costs at most two.
final class Coalesced {
  Coalesced(this._run);

  final Future<void> Function() _run;
  Future<void>? _current;

  /// The run after [_current], shared by everyone who asked during it.
  Completer<void>? _next;

  /// Asks for a run; completes with the run made for this request, the one
  /// in progress when it started before it.
  Future<void> call() {
    if (_current == null) return _current = _start();
    return (_next ??= Completer<void>()).future;
  }

  /// Drops the run that is due; one in progress finishes.
  void cancelPending() {
    final next = _next;
    _next = null;
    next?.complete();
  }

  Future<void> _start() async {
    try {
      await _run();
    } finally {
      final next = _next;
      _next = null;
      if (next == null) {
        _current = null;
      } else {
        _current = _start();
        next.complete(_current);
      }
    }
  }
}
