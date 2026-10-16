import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/terminal_a11y.dart';
import 'package:xterm/core.dart';

Terminal _terminal({int cols = 20, int rows = 4, int maxLines = 1000}) =>
    Terminal(maxLines: maxLines)..resize(cols, rows);

void main() {
  group('changedRows', () {
    test('nothing changed', () {
      expect(changedRows(['a', 'b'], ['a', 'b']), isEmpty);
    });

    test('a scroll counts only the rows it brought in', () {
      expect(changedRows(['a', 'b', 'c'], ['b', 'c', 'd']), ['d']);
    });

    test('a row edited in place is the one read', () {
      expect(
        changedRows(['[ ] one', '[ ] two'], ['[*] one', '[ ] two']),
        ['[*] one'],
      );
    });

    test('rows that became blank are not read', () {
      expect(changedRows([r'$ ls', 'x'], [r'$ ls', '']), isEmpty);
    });
  });

  test('announcementFor falls back to the cursor row', () {
    expect(
      announcementFor(before: ['a', 'b'], after: ['a', 'b'], cursor: ' b '),
      'b',
    );
    expect(announcementFor(before: [''], after: [''], cursor: ''), isNull);
  });

  test('announcesAfter skips plain characters', () {
    expect(announcesAfter('a'), isFalse);
    expect(announcesAfter('ls'), isFalse);
    for (final key in ['\r', ' ', '\t', '\x7f', '\x1b', '\x1b[A']) {
      expect(announcesAfter(key), isTrue, reason: key);
    }
  });

  group('TerminalAnnouncer', () {
    test('reads the output an Enter produced', () {
      fakeAsync((async) {
        final terminal = _terminal()..write(r'$ ls');
        final said = <String>[];
        final announcer = TerminalAnnouncer(terminal, announce: said.add);
        announcer.onTyped('\r');
        terminal.write('\r\nfile1\r\n\$ ');
        async.elapse(const Duration(milliseconds: 400));
        expect(said, ['file1\n\$']);
        announcer.dispose();
      });
    });

    test('reads the cursor row when nothing changed', () {
      fakeAsync((async) {
        final terminal = _terminal()..write('one\r\ntwo\x1b[1;1H');
        final said = <String>[];
        TerminalAnnouncer(terminal, announce: said.add).onTyped('\x1b[A');
        async.elapse(const Duration(milliseconds: 500));
        expect(said, isEmpty);
        async.elapse(const Duration(milliseconds: 400));
        expect(said, ['one']);
      });
    });

    test('reads only the menu item that changed', () {
      fakeAsync((async) {
        final terminal = _terminal()..write('[ ] one\r\n[ ] two\x1b[1;2H');
        final said = <String>[];
        TerminalAnnouncer(terminal, announce: said.add).onTyped(' ');
        terminal.write('*');
        async.elapse(const Duration(milliseconds: 400));
        expect(said, ['[*] one']);
      });
    });

    test('a screen that never settles is read by the deadline', () {
      fakeAsync((async) {
        final terminal = _terminal();
        final said = <String>[];
        TerminalAnnouncer(terminal, announce: said.add).onTyped('\r');
        for (var i = 0; i < 25; i++) {
          terminal.write('\r$i');
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(said, hasLength(1));
      });
    });

    test('typing letters says nothing', () {
      fakeAsync((async) {
        final terminal = _terminal();
        final said = <String>[];
        TerminalAnnouncer(terminal, announce: said.add).onTyped('a');
        terminal.write('a');
        async.elapse(const Duration(seconds: 3));
        expect(said, isEmpty);
      });
    });
  });

  group('TerminalTranscript', () {
    test('keeps the rows the scrollback dropped', () {
      final terminal = _terminal(rows: 3, maxLines: 5);
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      for (var i = 0; i < 12; i++) {
        terminal.write('line $i\r\n');
        transcript.sync();
      }
      expect(transcript.lines, [for (var i = 0; i < 12; i++) 'line $i']);
    });

    test('a row redrawn with a carriage return stays one line', () {
      final terminal = _terminal()..write('get 10%');
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      terminal.write('\rget 50%');
      transcript.sync();
      terminal.write('\rget 100%\r\ndone');
      transcript.sync();
      expect(transcript.lines, ['get 100%', 'done']);
    });

    test('a reflow to another width repeats nothing', () {
      final terminal = _terminal(cols: 10, rows: 3);
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      final written = [for (var i = 0; i < 5; i++) 'abcdefg$i'];
      terminal.write(written.join('\r\n'));
      transcript.sync();
      for (final cols in [4, 10, 6]) {
        terminal.resize(cols, 3);
        transcript.sync();
        expect(transcript.lines, written, reason: '$cols columns');
      }
      terminal.write('\r\nmore');
      transcript.sync();
      expect(transcript.lines, [...written, 'more']);
    });

    test('keeps what a reflow pushed out of the scrollback', () {
      final terminal = _terminal(cols: 10, rows: 3, maxLines: 6);
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      final written = [for (var i = 0; i < 5; i++) 'abcdefg$i'];
      terminal.write(written.join('\r\n'));
      transcript.sync();
      // Two rows a line now: twice what the scrollback holds.
      terminal.resize(4, 3);
      transcript.sync();
      expect(transcript.lines, written);
    });

    test('repeated lines a reflow pushed out are kept, each once', () {
      final terminal = _terminal(cols: 10, rows: 3, maxLines: 6);
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      final written = List.filled(5, 'abcdefghi');
      terminal.write(written.join('\r\n'));
      transcript.sync();
      terminal.resize(4, 3);
      transcript.sync();
      expect(transcript.lines, written);
    });

    test('droppedByReflow takes the longest overlap', () {
      int dropped(List<String> before, List<String> after) =>
          TerminalTranscript.droppedByReflow(before, after);
      // The first X is not the one left: both old ones are gone but the last.
      expect(dropped(['A', 'X', 'X'], ['X']), 2);
      expect(dropped(['p', '', 'q', '', 'q'], ['', 'q']), 3);
      expect(dropped(['a', 'b', 'c'], ['a', 'b', 'c']), 0);
      // The last line was redrawn since.
      expect(dropped(['a', 'b', r'$ l'], ['a', 'b', r'$ ls']), 0);
      expect(dropped(['a', 'b'], ['c']), 2);
    });

    test('droppedByReflow agrees with trying every overlap', () {
      // The quadratic version it replaced, as the reference.
      int reference(List<String> before, List<String> after) {
        bool tail(int end, int m) {
          for (var i = 0; i < m; i++) {
            if (before[end - m + i] != after[i]) return false;
          }
          return true;
        }

        for (var m = math.min(before.length, after.length); m > 0; m--) {
          if (tail(before.length, m)) return before.length - m;
          if (m < before.length && tail(before.length - 1, m)) {
            return before.length - 1 - m;
          }
        }
        return before.length;
      }

      final random = math.Random(1528);
      List<String> lines(int n) => [
        for (var i = 0; i < n; i++) ['', 'a', 'b'][random.nextInt(3)],
      ];
      for (var run = 0; run < 2000; run++) {
        final before = lines(random.nextInt(9));
        final after = lines(random.nextInt(9));
        expect(
          TerminalTranscript.droppedByReflow(before, after),
          reference(before, after),
          reason: '$before / $after',
        );
      }
    });

    test('droppedByReflow is linear', () {
      final before = [for (var i = 0; i < 10000; i++) 'old $i'];
      final after = [for (var i = 0; i < 10000; i++) 'new $i'];
      final watch = Stopwatch()..start();
      expect(TerminalTranscript.droppedByReflow(before, after), 10000);
      final repeated = List.filled(10000, 'x');
      expect(
        TerminalTranscript.droppedByReflow(repeated, [...repeated, 'y']),
        0,
      );
      expect(watch.elapsedMilliseconds, lessThan(200));
    });

    test('a wrapped row is joined to the line it continues', () {
      final terminal = _terminal(cols: 5)..write('abcdefgh');
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      expect(transcript.lines, ['abcdefgh']);
    });
  });
}
