import 'dart:collection';

final class TerminalOutputBuffer {
  static const maxBufferedChars = 32 * 1024;

  final ListQueue<String> _chunks = ListQueue<String>();
  int _pendingChars = 0;
  int _droppedChars = 0;

  bool get hasPending => _pendingChars > 0;

  int get pendingChars => _pendingChars;

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

    _chunks.addLast(data);
    _pendingChars += data.length;
  }

  String take(int maxChars) {
    if (maxChars <= 0 || _pendingChars == 0) {
      return '';
    }

    final buffer = StringBuffer();
    var remaining = maxChars;

    while (_chunks.isNotEmpty && remaining > 0) {
      final chunk = _chunks.removeFirst();
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
        _chunks.addFirst(chunk);
        break;
      }

      buffer.write(chunk.substring(0, splitAt));
      _chunks.addFirst(chunk.substring(splitAt));
      _pendingChars -= splitAt;
      remaining = 0;
    }

    return buffer.toString();
  }

  String drainAll() {
    return take(_pendingChars);
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

  void _dropOldestChars(int count) {
    while (count > 0 && _chunks.isNotEmpty) {
      final chunk = _chunks.removeFirst();
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
      _chunks.addFirst(chunk.substring(dropped));
      break;
    }
  }
}
