import 'dart:collection';

final class TerminalOutputBuffer {
  static const maxBufferedChars = 32 * 1024;

  final ListQueue<_Pending> _chunks = ListQueue<_Pending>();

  /// Output, without redraws: what [maxBufferedChars] caps.
  int _pendingChars = 0;
  int _redrawChars = 0;
  int _droppedChars = 0;

  bool get hasPending => _chunks.isNotEmpty;

  int get pendingChars => _pendingChars + _redrawChars;

  int get droppedChars => _droppedChars;

  void add(String data) {
    if (data.isEmpty) {
      return;
    }

    data = _trimLeadingToCap(data);
    if (data.isEmpty) {
      return;
    }

    final overflow = _pendingChars + data.length - maxBufferedChars;
    if (overflow > 0) {
      _dropOldestChars(overflow);
    }

    _chunks.addLast(_Pending(data));
    _pendingChars += data.length;
  }

  /// The whole terminal written over from a reset, as a tmux pane's replay is.
  /// Never cut by the cap and taken whole: without its head the terminal is not
  /// reset and the history is lost, and spread over frames the view is placed
  /// against half of it.
  void addRedraw(String data) {
    if (data.isEmpty) {
      return;
    }
    // It writes over any redraw still waiting; the output between them stays,
    // for what it does besides printing (a title, the clipboard).
    _chunks.removeWhere((pending) => pending.redraw);
    _chunks.addLast(_Pending(data, redraw: true));
    _redrawChars = data.length;
  }

  /// Up to [maxChars] of output, or a redraw whole.
  String take(int maxChars) {
    if (maxChars <= 0 || _chunks.isEmpty) {
      return '';
    }

    if (_chunks.first.redraw) {
      final redraw = _chunks.removeFirst().data;
      _redrawChars -= redraw.length;
      return redraw;
    }

    final buffer = StringBuffer();
    var remaining = maxChars;

    while (_chunks.isNotEmpty && !_chunks.first.redraw && remaining > 0) {
      final chunk = _chunks.removeFirst().data;
      if (chunk.length <= remaining) {
        buffer.write(chunk);
        _pendingChars -= chunk.length;
        remaining -= chunk.length;
        continue;
      }

      var splitAt = remaining;
      if (_isHighSurrogateBoundary(chunk, splitAt)) {
        splitAt--;
      }
      if (splitAt == 0) {
        _chunks.addFirst(_Pending(chunk));
        break;
      }

      buffer.write(chunk.substring(0, splitAt));
      _chunks.addFirst(_Pending(chunk.substring(splitAt)));
      _pendingChars -= splitAt;
      remaining = 0;
    }

    return buffer.toString();
  }

  /// Drops everything waiting, redraws too.
  void clear() {
    _chunks.clear();
    _pendingChars = 0;
    _redrawChars = 0;
  }

  bool _isHighSurrogateBoundary(String value, int index) {
    if (index <= 0 || index >= value.length) {
      return false;
    }
    final codeUnit = value.codeUnitAt(index - 1);
    return codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
  }

  bool _isLowSurrogate(String value, int index) {
    if (index < 0 || index >= value.length) {
      return false;
    }
    final codeUnit = value.codeUnitAt(index);
    return codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
  }

  String _trimLeadingToCap(String value) {
    if (value.length <= maxBufferedChars) {
      return value;
    }

    var start = value.length - maxBufferedChars;
    if (_isLowSurrogate(value, start)) {
      start++;
    }
    _droppedChars += start;
    return value.substring(start);
  }

  /// Drops the oldest output, never a redraw.
  void _dropOldestChars(int count) {
    final passed = <_Pending>[];
    while (count > 0 && _chunks.isNotEmpty) {
      final pending = _chunks.removeFirst();
      if (pending.redraw) {
        passed.add(pending);
        continue;
      }
      final chunk = pending.data;
      if (chunk.length <= count) {
        _pendingChars -= chunk.length;
        _droppedChars += chunk.length;
        count -= chunk.length;
        continue;
      }

      var splitAt = count;
      if (_isHighSurrogateBoundary(chunk, splitAt)) {
        splitAt++;
      }
      final dropped = splitAt.clamp(0, chunk.length);
      _pendingChars -= dropped;
      _droppedChars += dropped;
      if (dropped < chunk.length) {
        _chunks.addFirst(_Pending(chunk.substring(dropped)));
      }
      break;
    }
    for (final pending in passed.reversed) {
      _chunks.addFirst(pending);
    }
  }
}

final class _Pending {
  final String data;
  final bool redraw;

  const _Pending(this.data, {this.redraw = false});
}
