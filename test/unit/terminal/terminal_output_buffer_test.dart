import 'package:server_box/data/ssh/terminal_output_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalOutputBuffer', () {
    test('takes pending output in order across chunk boundaries', () {
      final buffer = TerminalOutputBuffer()
        ..add('abc')
        ..add('defg');

      expect(buffer.take(5), 'abcde');
      expect(buffer.pendingChars, 2);
      expect(buffer.take(5), 'fg');
      expect(buffer.hasPending, isFalse);
    });

    test('drainAll returns the remaining buffered output', () {
      final buffer = TerminalOutputBuffer()
        ..add('hello')
        ..add('')
        ..add(' world');

      expect(buffer.drainAll(), 'hello world');
      expect(buffer.pendingChars, 0);
      expect(buffer.hasPending, isFalse);
    });

    test('does not split surrogate pairs when taking a prefix', () {
      final buffer = TerminalOutputBuffer()..add('a😀b');

      expect(buffer.take(2), 'a');
      expect(buffer.take(10), '😀b');
      expect(buffer.hasPending, isFalse);
    });

    test('caps buffered output and drops oldest data', () {
      final prefix = 'a' * (TerminalOutputBuffer.maxBufferedChars - 2);
      final buffer = TerminalOutputBuffer()
        ..add(prefix)
        ..add('bc')
        ..add('def');

      expect(buffer.pendingChars, TerminalOutputBuffer.maxBufferedChars);
      expect(buffer.droppedChars, 3);
      expect(buffer.drainAll(), '${prefix.substring(3)}bcdef');
    });

    test('preserves surrogate pairs when trimming oversized input', () {
      final oversized =
          'a' * (TerminalOutputBuffer.maxBufferedChars - 1) + '😀';
      final buffer = TerminalOutputBuffer()..add(oversized);

      expect(buffer.pendingChars, TerminalOutputBuffer.maxBufferedChars);
      expect(buffer.droppedChars, 1);
      expect(
        buffer.drainAll(),
        'a' * (TerminalOutputBuffer.maxBufferedChars - 2) + '😀',
      );
    });
  });
}
