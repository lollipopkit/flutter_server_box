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

  List<ScreenRow> rows(List<String> texts) => [
    for (final text in texts) ScreenRow(text),
  ];

  test('announcementFor falls back to the cursor row', () {
    expect(
      announcementFor(
        before: rows(['a', 'b']),
        after: rows(['a', 'b']),
        cursor: ' b ',
      ),
      'b',
    );
    expect(
      announcementFor(before: rows(['']), after: rows(['']), cursor: ''),
      isNull,
    );
  });

  group('restyledRow', () {
    // A dialog menu: the items, then the buttons the cursor stays on.
    const menu = '[ ] a Apple\r\n[ ] b Banana\r\n[ ] c Cherry\r\n  <OK>';

    /// [menu] with item [selected] drawn as [highlight] and the cursor on the
    /// OK button.
    Terminal drawn(int selected, String highlight) {
      final terminal = _terminal(cols: 16, rows: 4);
      final lines = menu.split('\r\n');
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) terminal.write('\r\n');
        terminal.write(
          i == selected ? '$highlight${lines[i]}\x1b[0m' : lines[i],
        );
      }
      terminal.write('\x1b[4;4H');
      return terminal;
    }

    for (final (name, highlight) in [
      ('inverse video', '\x1b[7m'),
      ('a colour pair', '\x1b[37;44m'),
    ]) {
      test('an arrow that moved the $name highlight reads the new item', () {
        final before = viewportRows(drawn(0, highlight).buffer);
        final down = drawn(1, highlight).buffer;
        expect(
          announcementFor(
            before: before,
            after: viewportRows(down),
            cursor: cursorRow(down),
          ),
          '[ ] b Banana',
        );
        final up = viewportRows(drawn(0, highlight).buffer);
        expect(restyledRow(viewportRows(down), up), '[ ] a Apple');
      });
    }

    test('a screen drawn the same is not a restyle', () {
      final screen = viewportRows(drawn(2, '\x1b[7m').buffer);
      expect(restyledRow(screen, screen), isNull);
    });

    test('a changed text still wins over a restyle', () {
      final before = viewportRows(drawn(0, '\x1b[7m').buffer);
      final terminal = drawn(1, '\x1b[7m')..write('\x1b[2;2H*');
      expect(
        announcementFor(
          before: before,
          after: viewportRows(terminal.buffer),
          cursor: cursorRow(terminal.buffer),
        ),
        '[*] b Banana',
      );
    });
  });

  test('announcesAfter skips plain characters', () {
    expect(announcesAfter('a'), isFalse);
    expect(announcesAfter('ls'), isFalse);
    for (final key in ['\r', '\t', '\x7f', '\x1b', '\x1b[A']) {
      expect(announcesAfter(key), isTrue, reason: key);
    }
    // Left to the announcer, which reads a space only by what it changed.
    expect(announcesAfter(' '), isFalse);
    expect(announcesAfter('git commit '), isFalse);
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

    test('a space at a prompt reads nothing, word after word', () {
      fakeAsync((async) {
        final terminal = _terminal()..write(r'$ git');
        final said = <String>[];
        final announcer = TerminalAnnouncer(terminal, announce: said.add);
        announcer.onTyped(' ');
        terminal.write(' ');
        async.elapse(const Duration(seconds: 1));
        for (final c in 'commit'.split('')) {
          announcer.onTyped(c);
          terminal.write(c);
        }
        announcer.onTyped(' ');
        terminal.write(' ');
        announcer.onTyped('-');
        terminal.write('-');
        async.elapse(const Duration(seconds: 3));
        expect(said, isEmpty);
      });
    });

    test('a key that is not a space still reads the cursor row', () {
      fakeAsync((async) {
        final terminal = _terminal()..write('> one\r\n  two\x1b[1;1H');
        final said = <String>[];
        final announcer = TerminalAnnouncer(terminal, announce: said.add);
        announcer.onTyped(' ');
        announcer.onTyped('\x1b[A');
        async.elapse(const Duration(seconds: 1));
        expect(said, ['> one']);
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

    test('keeps what scrolled away between two syncs', () {
      final terminal = _terminal(rows: 3, maxLines: 5);
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      terminal.write([for (var i = 0; i < 40; i++) 'line $i'].join('\r\n'));
      transcript.sync();
      expect(transcript.lines, [for (var i = 0; i < 40; i++) 'line $i']);
    });

    test('a scroll region over a full buffer loses no line', () {
      // apt's progress bar: a region above a footer row. Each new line is an
      // insert under the region, which trims the oldest line of a full buffer
      // while the rows below it keep their indexes.
      final terminal = _terminal(rows: 4, maxLines: 6)
        ..write('\x1b[1;3r\x1b[4;1Hfooter\x1b[3;1H');
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      final n = terminal.buffer.lines.maxLength * 2;
      for (var i = 0; i < n; i++) {
        terminal.write('\r\nline $i');
        transcript.sync();
      }
      final lines = transcript.lines;
      for (var i = 0; i < n; i++) {
        expect(lines.where((l) => l == 'line $i'), hasLength(1), reason: '$i');
      }
      expect(lines.last, 'footer');
    });

    test('a reverse scroll over the last row repeats nothing', () {
      // less or vim going back: each row moves down one, and the last is
      // overwritten by the one above it.
      final terminal = _terminal(rows: 3, maxLines: 10)
        ..write([for (var i = 0; i < 5; i++) 'line $i'].join('\r\n'));
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      for (var i = 0; i < 3; i++) {
        terminal.write('\x1b[H\x1bM');
        transcript.sync();
      }
      final lines = transcript.lines;
      expect(lines.take(2), ['line 0', 'line 1']);
      for (var i = 0; i < 5; i++) {
        expect(
          lines.where((l) => l == 'line $i').length,
          lessThanOrEqualTo(1),
          reason: '$i',
        );
      }
    });

    test('lets go of the oldest lines past its limit, and says how many', () {
      final terminal = _terminal(rows: 2, maxLines: 2);
      final held = terminal.buffer.lines.maxLength;
      final transcript = TerminalTranscript(terminal.buffer, maxKept: 10);
      const n = 200;
      terminal.write([for (var i = 0; i < n; i++) 'line $i'].join('\r\n'));
      transcript.sync();
      final lines = transcript.lines;
      expect(transcript.letGo, greaterThan(0));
      expect(lines, [for (var i = transcript.letGo; i < n; i++) 'line $i']);
      expect(lines.length, lessThanOrEqualTo(10 + 1 + held));
    });

    test('stops listening once disposed', () {
      final terminal = _terminal(rows: 2, maxLines: 2);
      final held = terminal.buffer.lines.maxLength;
      final transcript = TerminalTranscript(terminal.buffer)..dispose();
      final n = held + 5;
      terminal.write([for (var i = 0; i < n; i++) 'line $i'].join('\r\n'));
      transcript.sync();
      expect(transcript.lines.first, 'line 5');
      expect(transcript.lines, hasLength(held));
    });

    test('a row wrapped onto a line that left is joined to it', () {
      final terminal = _terminal(cols: 4, rows: 2, maxLines: 2);
      final transcript = TerminalTranscript(terminal.buffer);
      terminal.write('abcdefghij');
      transcript.sync();
      expect(transcript.lines, ['abcdefghij']);
    });

    test('a wrapped row is joined to the line it continues', () {
      final terminal = _terminal(cols: 5)..write('abcdefgh');
      final transcript = TerminalTranscript(terminal.buffer)..sync();
      expect(transcript.lines, ['abcdefgh']);
    });
  });
}
