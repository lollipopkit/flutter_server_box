import 'dart:collection';

final class TerminalOutputBuffer {
  final ListQueue<String> _chunks = ListQueue<String>();
  int _pendingChars = 0;

  bool get hasPending => _pendingChars > 0;

  int get pendingChars => _pendingChars;

  void add(String data) {
    if (data.isEmpty) {
      return;
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

      buffer.write(chunk.substring(0, remaining));
      _chunks.addFirst(chunk.substring(remaining));
      _pendingChars -= remaining;
      remaining = 0;
    }

    return buffer.toString();
  }

  String drainAll() {
    return take(_pendingChars);
  }
}
