import 'dart:async';

import 'package:xterm/core.dart';

/// The rows of [buffer] on screen, top first, each without its trailing
/// blanks.
List<String> viewportRows(Buffer buffer) => [
  for (var i = buffer.scrollBack; i < buffer.height; i++)
    buffer.lines[i].getText(),
];

/// The text of the row the cursor is on.
String cursorRow(Buffer buffer) {
  final y = buffer.absoluteCursorY;
  if (y < 0 || y >= buffer.height) return '';
  return buffer.lines[y].getText();
}

/// Which rows of [after] are not in [before], in order, blank ones left out.
///
/// The screen is first lined up with how far it scrolled — the shift that
/// keeps the most rows in place — so output that pushed everything up counts
/// as the new rows at the bottom, not as a whole screen that changed.
List<String> changedRows(List<String> before, List<String> after) {
  var shift = 0;
  var best = -1;
  for (var k = 0; k <= before.length; k++) {
    var same = 0;
    for (var i = 0; i < after.length && i + k < before.length; i++) {
      if (before[i + k] == after[i]) same++;
    }
    if (same > best) {
      best = same;
      shift = k;
    }
  }
  return [
    for (var i = 0; i < after.length; i++)
      if (!(i + shift < before.length && before[i + shift] == after[i]) &&
          after[i].trim().isNotEmpty)
        after[i].trim(),
  ];
}

/// What to read out after a key: the rows it changed, or, when it changed
/// none — an arrow moving through a menu — the row the cursor is on, unless
/// [cursorIfUnchanged] is false.
String? announcementFor({
  required List<String> before,
  required List<String> after,
  required String cursor,
  bool cursorIfUnchanged = true,
}) {
  final changed = changedRows(before, after);
  if (changed.isNotEmpty) return changed.join('\n');
  if (!cursorIfUnchanged) return null;
  final row = cursor.trim();
  return row.isEmpty ? null : row;
}

/// Whether what was typed is worth reading the screen out after.
///
/// Not plain characters: the keyboard already speaks those, and reading the
/// line after every letter would talk over it. Anything else — Enter, Tab,
/// Backspace, an arrow or any other escape sequence — is a key whose effect
/// is only on the screen. Space is both, and is left to
/// [TerminalAnnouncer.onTyped].
bool announcesAfter(String typed) {
  for (final unit in typed.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) return true;
  }
  return false;
}

/// Reads out what a key did to the screen, for a screen reader.
///
/// Armed by [onTyped]; the screen is read once output has stopped for
/// [quiet], or after [firstOutput] if nothing arrived, and in any case by
/// [maxWait], so a program that never stops drawing — `top` — is read every
/// so often instead of never.
///
/// Space ticks a box in a menu and separates words at a prompt. So after a
/// space alone only rows it changed are read — a ticked box, never the line
/// at a prompt, where a trailing blank changes nothing — and typing on past
/// it drops the round, since the next word would change the line.
final class TerminalAnnouncer {
  TerminalAnnouncer(
    this.terminal, {
    required this.announce,
    this.quiet = const Duration(milliseconds: 300),
    this.firstOutput = const Duration(milliseconds: 800),
    this.maxWait = const Duration(seconds: 2),
  });

  final Terminal terminal;
  final void Function(String message) announce;
  final Duration quiet;
  final Duration firstOutput;
  final Duration maxWait;

  /// The screen when the first key of this round was typed; null between
  /// rounds.
  List<String>? _before;
  bool _changed = false;

  /// Whether every key of this round was a space.
  bool _spaceOnly = false;
  Timer? _quietTimer;
  Timer? _deadline;

  void onTyped(String data) {
    final space = data == ' ';
    if (!space && !announcesAfter(data)) {
      if (_spaceOnly) _stop();
      return;
    }
    if (_before == null) {
      _before = viewportRows(terminal.buffer);
      _changed = false;
      _spaceOnly = space;
      _deadline = Timer(maxWait, _fire);
      terminal.addListener(_onChange);
    } else if (!space) {
      _spaceOnly = false;
    }
    _restart();
  }

  void _onChange() {
    _changed = true;
    _restart();
  }

  void _restart() {
    _quietTimer?.cancel();
    _quietTimer = Timer(_changed ? quiet : firstOutput, _fire);
  }

  void _fire() {
    final before = _before;
    final spaceOnly = _spaceOnly;
    _stop();
    if (before == null) return;
    final buffer = terminal.buffer;
    final message = announcementFor(
      before: before,
      after: viewportRows(buffer),
      cursor: cursorRow(buffer),
      cursorIfUnchanged: !spaceOnly,
    );
    if (message != null) announce(message);
  }

  void _stop() {
    _quietTimer?.cancel();
    _deadline?.cancel();
    _quietTimer = null;
    _deadline = null;
    if (_before != null) terminal.removeListener(_onChange);
    _before = null;
    _spaceOnly = false;
  }

  void dispose() => _stop();
}

/// Everything one [Buffer] has shown, as lines of text, for reading at a
/// screen reader's pace.
///
/// What is still in [buffer] is read again on every [sync] — a progress bar
/// redrawn with `\r` stays one line — and what leaves it off the top is kept
/// as it was when it left, told by the buffer itself: no count of the rows
/// that are left can say how many went, since a row overwritten in place, an
/// insert into a full buffer or a reflow all move or replace them as well.
///
/// Up to [maxKept] lines of that, the oldest let go of first; [letGo] says
/// how many.
final class TerminalTranscript {
  TerminalTranscript(this.buffer, {this.maxKept = 10000}) {
    buffer.lines.addEvictListener(_onEvict);
  }

  final Buffer buffer;
  final int maxKept;

  /// Lines no longer in [buffer], oldest first, a wrapped row already joined
  /// to the one it continues.
  final _gone = <String>[];

  /// How many lines were let go of off the top of what was kept.
  int get letGo => _letGo;
  var _letGo = 0;

  /// The lines at the last [sync].
  List<String> get lines => _lines;
  var _lines = const <String>[];

  void _onEvict(BufferLine line) {
    final text = line.getText();
    if (line.isWrapped && _gone.isNotEmpty) {
      _gone.last += text;
    } else {
      _gone.add(text);
    }
    // A tenth over before trimming, so a buffer scrolling at full speed does
    // not shift the whole list for every line.
    if (_gone.length > maxKept + maxKept ~/ 10) {
      final over = _gone.length - maxKept;
      _gone.removeRange(0, over);
      _letGo += over;
    }
  }

  /// Reads the rows [buffer] has now. Only these are joined again: what left
  /// it was joined as it went.
  void sync() {
    final rows = buffer.lines;
    final live = <String>[];
    // The first row may continue the last line that left.
    String? continued;
    for (var i = 0; i < buffer.height; i++) {
      final row = rows[i];
      final text = row.getText();
      if (!row.isWrapped) {
        live.add(text);
      } else if (live.isNotEmpty) {
        live.last += text;
      } else if (_gone.isNotEmpty) {
        continued = text;
      } else {
        live.add(text);
      }
    }
    while (live.isNotEmpty && live.last.trim().isEmpty) {
      live.removeLast();
    }
    _lines = [
      ..._gone.take(continued == null ? _gone.length : _gone.length - 1),
      if (continued != null) _gone.last + continued,
      ...live,
    ];
  }

  void dispose() => buffer.lines.removeEvictListener(_onEvict);
}
