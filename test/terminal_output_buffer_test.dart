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
  });
}
