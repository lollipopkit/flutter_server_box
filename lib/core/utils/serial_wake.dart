import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

/// Presses Enter, after a visible countdown, on a serial console that has
/// connected and is waiting to be sent something.
///
/// A guest's serial port prints nothing until it is written to: its getty
/// drew the login prompt at boot, long before anyone connected. What is on
/// screen is the connection's own banner and an empty line under it, which
/// reads as a console that failed. Enter makes the getty draw the prompt again.
///
/// Armed only when all of these hold, so it never presses a key into anything
/// the user is doing:
///
/// - the cursor is on an empty line, in the main buffer (a full-screen program
///   draws in the alternate one);
/// - the last non-empty line above it, blank lines skipped, is a banner in
///   [banners] — PVE's `starting serial terminal on interface serialN` (any
///   port), libvirt's `Escape character is ^]`;
/// - the terminal has been still for [quiet].
///
/// Then [remaining] counts down from [countdown] and Enter is sent at zero.
/// Anything the terminal draws in the meantime — output, the echo of a key —
/// cancels it and the conditions are checked again. Each banner line gets at
/// most one Enter, whether sent, [cancel]led or pressed [now], for as long as
/// the terminal lives: a guest that does not answer is not pressed again and
/// again.
class SerialWake extends ChangeNotifier {
  SerialWake(
    this.terminal, {
    this.quiet = const Duration(seconds: 1),
    this.countdown = const Duration(seconds: 3),
  }) {
    terminal.addListener(_onChange);
    _onChange();
  }

  final Terminal terminal;
  final Duration quiet;
  final Duration countdown;

  /// Case-insensitive, matched against a whole trimmed line.
  static final banners = [
    RegExp(
      r'^starting serial terminal on interface serial\d+$',
      caseSensitive: false,
    ),
    RegExp(r'^Escape character is \^\](\s*\(Ctrl \+ \]\))?$'),
  ];

  /// How many lines above the cursor are searched for the banner, blank ones
  /// included. libvirt leaves one blank line under its banner.
  static const _lookBack = 4;

  /// Banner lines already answered, by identity — a line's index moves once
  /// the scrollback is full, the line object does not — and kept with the
  /// terminal rather than this: a console left and taken up again gets a new
  /// wake on the same terminal, and must not count down for a banner the
  /// last one answered.
  static final _answered = Expando<Set<BufferLine>>();

  Set<BufferLine> get _done => _answered[terminal] ??= Set.identity();

  BufferLine? _banner;
  Timer? _quietTimer;
  Timer? _tick;
  int? _remaining;

  /// Seconds until Enter is sent; null when nothing is counting down.
  int? get remaining => _remaining;

  /// Sends Enter now, instead of at the end of the countdown.
  void now() {
    final banner = _banner;
    if (banner == null || _remaining == null) return;
    _fire(banner);
  }

  /// Leaves this banner alone: no Enter for it.
  void cancel() {
    final banner = _banner;
    if (banner != null) _done.add(banner);
    _reset();
  }

  /// The banner line the cursor is waiting under, if the conditions hold.
  @visibleForTesting
  static BufferLine? waitingBanner(Terminal terminal) {
    if (terminal.isUsingAltBuffer) return null;
    final buffer = terminal.buffer;
    final cursor = buffer.absoluteCursorY;
    if (cursor < 0 || cursor >= buffer.height) return null;
    if (buffer.lines[cursor].getText().trim().isNotEmpty) return null;
    for (var i = cursor - 1; i >= 0 && i >= cursor - _lookBack; i--) {
      final line = buffer.lines[i];
      final text = line.getText().trim();
      if (text.isEmpty) continue;
      return banners.any((re) => re.hasMatch(text)) ? line : null;
    }
    return null;
  }

  void _onChange() {
    _reset();
    final banner = waitingBanner(terminal);
    if (banner == null || _done.contains(banner)) return;
    _banner = banner;
    _quietTimer = Timer(quiet, () => _start(banner));
  }

  void _start(BufferLine banner) {
    _remaining = countdown.inSeconds;
    notifyListeners();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = (_remaining ?? 1) - 1;
      if (left <= 0) {
        _fire(banner);
        return;
      }
      _remaining = left;
      notifyListeners();
    });
  }

  void _fire(BufferLine banner) {
    _done.add(banner);
    _reset();
    // Through the terminal's own key handling, as a key pressed in it: the
    // session writes whatever Enter is in the terminal's current mode.
    terminal.keyInput(TerminalKey.enter);
  }

  void _reset() {
    _quietTimer?.cancel();
    _quietTimer = null;
    _tick?.cancel();
    _tick = null;
    _banner = null;
    final was = _remaining;
    _remaining = null;
    if (was != null) notifyListeners();
  }

  @override
  void dispose() {
    terminal.removeListener(_onChange);
    _quietTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }
}
