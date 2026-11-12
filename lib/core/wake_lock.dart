import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The one holder of the screen wake lock: held while the general setting is
/// on, or while a terminal is open and the terminal's setting is on.
final class WakeLock {
  WakeLock({required this.general, required this.terminal, required this.apply});

  static final instance = WakeLock(
    general: Stores.setting.generalWakeLock.listenable(),
    terminal: Stores.setting.sshWakeLock.listenable(),
    apply: (held) => unawaited(WakelockPlus.toggle(enable: held)),
  );

  final ValueListenable<bool> general;
  final ValueListenable<bool> terminal;
  final void Function(bool held) apply;

  var _listening = false;
  var _terminals = 0;
  var _held = false;

  void start() {
    if (!_listening) {
      _listening = true;
      general.addListener(_sync);
      terminal.addListener(_sync);
    }
    _sync();
  }

  /// Releases the lock: the app is going.
  void stop() {
    if (_listening) {
      _listening = false;
      general.removeListener(_sync);
      terminal.removeListener(_sync);
    }
    _set(false);
  }

  void terminalOpened() {
    _terminals++;
    start();
  }

  void terminalClosed() {
    if (_terminals > 0) _terminals--;
    _sync();
  }

  void _sync() => _set(general.value || (_terminals > 0 && terminal.value));

  void _set(bool held) {
    if (held == _held) return;
    _held = held;
    apply(held);
  }
}
