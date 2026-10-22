import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// One server's agent read on a timer while a provider is alive: the server's
/// shared client ([MonitorClientLease]), one read at a time, none while the
/// app is in the background, and an answer for a disposed provider dropped.
///
/// The provider makes one in `build`, hands [dispose] to `ref.onDispose`,
/// and writes its state in [read] only while the `current` it is given
/// answers true.
final class AgentPoll {
  AgentPoll(
    MonitorHttpCredential cred, {
    required Duration every,
    required Future<void> Function(MonitorHttpClient client, bool Function() current) read,
  }) : _lease = MonitorClientLease(cred),
       _read = read {
    // After `build` has returned its state: [read] may write it at once.
    scheduleMicrotask(() => unawaited(refresh()));
    _timer = Timer.periodic(every, (_) {
      // Polled for what is on screen; a resumed app is read again by then.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      // A tick with a read in flight has nothing to add to it.
      if (_reading == null) unawaited(refresh());
    });
  }

  final MonitorClientLease _lease;
  final Future<void> Function(MonitorHttpClient client, bool Function() current) _read;
  late final Timer _timer;
  Future<void>? _reading;
  Future<void>? _again;
  var _disposed = false;

  MonitorHttpClient get client => _lease.client;

  /// Reads now. With a read in flight — sent before whatever this is asked
  /// after (a change, a pull to refresh) — one more follows it, shared by
  /// everyone who asks meanwhile; never two at once.
  Future<void> refresh() {
    if (_disposed) return Future.value();
    final reading = _reading;
    if (reading == null) {
      return _reading = _read(client, () => !_disposed).whenComplete(() => _reading = null);
    }
    // After it however it ended: its failure is its own caller's.
    return _again ??= reading.then<void>((_) {}, onError: (_) {}).then((_) {
      _again = null;
      return refresh();
    });
  }

  void dispose() {
    _disposed = true;
    _timer.cancel();
    _lease.release();
  }
}
