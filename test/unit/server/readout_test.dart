import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/server/detail/readout.dart';

/// The lines a card row draws from a command's output.
///
/// The output is served exactly as the command printed it, so a single-line
/// `echo` ends in `\n`. Reading that ending as a second line makes the row
/// tappable and opens a dialog holding the one line the row already shows, so
/// one trailing line ending is dropped before the output is split.
void main() {
  test('a single line ending in a newline is one line', () {
    expect(readoutCommandLines('single line\n'), ['single line']);
    expect(readoutCommandLines('single line\r\n'), ['single line']);
  });

  test('a multi-line output ending in a newline keeps its lines', () {
    expect(readoutCommandLines('first line\nsecond line\n'), [
      'first line',
      'second line',
    ]);
  });

  test('only the ending at the very end is dropped', () {
    // An inner blank line is part of the output.
    expect(readoutCommandLines('a\n\n'), ['a', '']);
    expect(readoutCommandLines('\n'), ['']);
  });

  test('an output with no trailing ending is unchanged', () {
    expect(readoutCommandLines('no newline'), ['no newline']);
    expect(readoutCommandLines('a\nb'), ['a', 'b']);
    expect(readoutCommandLines(''), ['']);
  });
}
