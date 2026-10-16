import 'dart:async';
import 'dart:math' as math;

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
/// none — an arrow moving through a menu — the row the cursor is on.
String? announcementFor({
  required List<String> before,
  required List<String> after,
  required String cursor,
}) {
  final changed = changedRows(before, after);
  if (changed.isNotEmpty) return changed.join('\n');
  final row = cursor.trim();
  return row.isEmpty ? null : row;
}

/// Whether what was typed is worth reading the screen out after.
///
/// Not plain characters: the keyboard already speaks those, and reading the
/// line after every letter would talk over it. Anything else — Enter, Tab,
/// Space, Backspace, an arrow or any other escape sequence — is a key whose
/// effect is only on the screen.
bool announcesAfter(String typed) {
  for (final unit in typed.codeUnits) {
    if (unit <= 0x20 || unit == 0x7f) return true;
  }
  return false;
}

/// Reads out what a key did to the screen, for a screen reader.
///
/// Armed by [onTyped]; the screen is read once output has stopped for
/// [quiet], or after [firstOutput] if nothing arrived, and in any case by
/// [maxWait], so a program that never stops drawing — `top` — is read every
/// so often instead of never.
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
  Timer? _quietTimer;
  Timer? _deadline;

  void onTyped(String data) {
    if (!announcesAfter(data)) return;
    if (_before == null) {
      _before = viewportRows(terminal.buffer);
      _changed = false;
      _deadline = Timer(maxWait, _fire);
      terminal.addListener(_onChange);
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
    _stop();
    if (before == null) return;
    final buffer = terminal.buffer;
    final message = announcementFor(
      before: before,
      after: viewportRows(buffer),
      cursor: cursorRow(buffer),
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
  }

  void dispose() => _stop();
}

/// Everything one [Buffer] has shown, as lines of text, for reading at a
/// screen reader's pace.
///
/// Kept by row rather than re-read whole: the rows the buffer still has are
/// replaced on every [sync] — a progress bar redrawn with `\r` stays one row —
/// and the rows it scrolled off the top of its scrollback are kept as they
/// were last seen, so the lines a reader is on do not move under them.
final class TerminalTranscript {
  TerminalTranscript(this.buffer);

  final Buffer buffer;

  /// Rows no longer in [buffer], oldest first: (text, wrapped onto the one
  /// before it).
  final _gone = <(String, bool)>[];

  /// The rows [buffer] had at the last [sync].
  var _live = <(String, bool)>[];

  /// The last row [buffer] had at the last [sync], and its index then: how
  /// far it moved up since is how many rows were dropped off the top.
  BufferLine? _anchor;
  var _anchorAt = 0;

  /// The size [buffer] had at the last [sync]. A resize rebuilds its rows —
  /// reflowed to the new width — so the anchor says nothing about it.
  var _width = 0;
  var _height = 0;

  /// The lines, a wrapped row joined to the one it continues.
  List<String> get lines => _join([..._gone, ..._live]);

  void sync() {
    final lines = buffer.lines;
    final live = [
      for (var i = 0; i < buffer.height; i++)
        (lines[i].getText(), lines[i].isWrapped),
    ];
    final anchor = _anchor;
    if (anchor != null) {
      if (buffer.viewWidth != _width || buffer.viewHeight != _height) {
        // Only the lines the reflow pushed out of the scrollback are history:
        // the rest are still in the buffer, wrapped differently.
        final before = _join(_live);
        final kept = _overlapStart(before, _join(live));
        _gone.addAll([for (final line in before.take(kept)) (line, false)]);
      } else if (anchor.attached) {
        final dropped = (_anchorAt - anchor.index).clamp(0, _live.length);
        _gone.addAll(_live.take(dropped));
      } else {
        // The buffer was cleared, or scrolled past its whole length since:
        // everything shown so far is history now.
        _gone.addAll(_live);
      }
    }
    _live = live;
    _width = buffer.viewWidth;
    _height = buffer.viewHeight;
    if (buffer.height == 0) {
      _anchor = null;
      return;
    }
    _anchor = lines[buffer.height - 1];
    _anchorAt = buffer.height - 1;
  }

  static List<String> _join(Iterable<(String, bool)> rows) {
    final out = <String>[];
    for (final (text, wrapped) in rows) {
      if (wrapped && out.isNotEmpty) {
        out[out.length - 1] += text;
      } else {
        out.add(text);
      }
    }
    while (out.isNotEmpty && out.last.trim().isEmpty) {
      out.removeLast();
    }
    return out;
  }

  /// Where in [before] the lines of [after] begin: the first offset from
  /// which the two agree on every line they share, or all of [before] when
  /// none does.
  ///
  /// The last line of [before] is not compared: it is the one being typed on
  /// or redrawn, and may have changed since.
  static int _overlapStart(List<String> before, List<String> after) {
    if (after.isEmpty) return before.length;
    final settled = before.length - 1;
    if (settled <= 0) return 0;
    for (var k = 0; k < settled; k++) {
      final n = math.min(settled - k, after.length);
      var same = true;
      for (var i = 0; i < n && same; i++) {
        same = before[k + i] == after[i];
      }
      if (same) return k;
    }
    return before.length;
  }
}
