import 'package:server_box/data/terminal/terminal_output_buffer.dart';
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

    test('takes all remaining output and ignores empty chunks', () {
      final buffer = TerminalOutputBuffer()
        ..add('hello')
        ..add('')
        ..add(' world');

      expect(buffer.take(buffer.pendingChars), 'hello world');
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
      expect(buffer.take(buffer.pendingChars), '${prefix.substring(3)}bcdef');
    });

    test('preserves surrogate pairs when trimming oversized input', () {
      final oversized =
          'a' * (TerminalOutputBuffer.maxBufferedChars - 1) + '😀';
      final buffer = TerminalOutputBuffer()..add(oversized);

      expect(buffer.pendingChars, TerminalOutputBuffer.maxBufferedChars);
      expect(buffer.droppedChars, 1);
      expect(
        buffer.take(buffer.pendingChars),
        'a' * (TerminalOutputBuffer.maxBufferedChars - 2) + '😀',
      );
    });

    test('takes a redraw whole, past the cap, after the output before it', () {
      final redraw = '\x1bc${'r' * (TerminalOutputBuffer.maxBufferedChars * 3)}';
      final buffer = TerminalOutputBuffer()
        ..add('before')
        ..addRedraw(redraw)
        ..add('after');

      expect(buffer.take(100), 'before');
      expect(buffer.take(10), redraw);
      expect(buffer.take(10), 'after');
      expect(buffer.hasPending, isFalse);
      expect(buffer.droppedChars, 0);
    });

    test('output past the cap never drops a redraw', () {
      final buffer = TerminalOutputBuffer()
        ..addRedraw('\x1bcscreen')
        ..add('a' * TerminalOutputBuffer.maxBufferedChars)
        ..add('tail');

      expect(buffer.take(10), '\x1bcscreen');
      expect(buffer.droppedChars, 'tail'.length);
      expect(buffer.take(TerminalOutputBuffer.maxBufferedChars * 2), endsWith('tail'));
    });

    test('a later redraw replaces one still waiting, not the output between', () {
      final buffer = TerminalOutputBuffer()
        ..addRedraw('\x1bcfirst')
        ..add('\x1b]0;title\x07')
        ..addRedraw('\x1bcsecond');

      expect(buffer.take(100), '\x1b]0;title\x07');
      expect(buffer.take(100), '\x1bcsecond');
      expect(buffer.hasPending, isFalse);
      expect(buffer.pendingChars, 0);
    });

    test('takes nothing when asked for nothing, a redraw neither', () {
      final buffer = TerminalOutputBuffer()..addRedraw('\x1bcscreen');

      expect(buffer.take(0), '');
      buffer.clear();
      expect(buffer.hasPending, isFalse);
      expect(buffer.pendingChars, 0);
    });
  });
}
