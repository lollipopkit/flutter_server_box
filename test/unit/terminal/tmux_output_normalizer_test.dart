import 'dart:convert';

import 'package:server_box/data/ssh/tmux/tmux_output_normalizer.dart';
import 'package:test/test.dart';
import 'package:xterm/core.dart';

void main() {
  test('removes terminal queries answered by tmux', () {
    final normalizer = TmuxOutputNormalizer();
    expect(
      utf8.decode(
        normalizer(
          utf8.encode('a\x1b[cb\x1b[>cc\x1b[=cd\x1b[5ne\x1b[6nf\x1b[?6ng'),
        ),
      ),
      'abcdefg',
    );
  });

  test('keeps device attributes and status responses', () {
    final normalizer = TmuxOutputNormalizer();
    final data = utf8.encode(
      '\x1b[?1;2c\x1b[>84;0;0c\x1b[0n\x1b[1;27R\x1b[?25h',
    );

    expect(normalizer(data), data);
  });

  test('keeps terminal control sequences other than queries', () {
    final normalizer = TmuxOutputNormalizer();
    final data = utf8.encode('\x1b[1;31mred\x1b[0m\x1b]0;title\x07');

    expect(normalizer(data), data);
  });

  test('keeps OSC 52 for the terminal integration', () {
    final normalizer = TmuxOutputNormalizer();
    final data = utf8.encode(
      '\x1b]52;c;aGk=\x07'
      '\x1b]52;c;?\x07',
    );

    expect(normalizer(data), data);
  });

  test('translates tmux title sequences to OSC title', () {
    final normalizer = TmuxOutputNormalizer();

    expect(
      utf8.decode(normalizer(utf8.encode('prefix\x1bkecho\x1b\\1suffix'))),
      'prefix\x1b]0;echo\x1b\\1suffix',
    );
    expect(
      utf8.decode(normalizer(utf8.encode('\x1bkvim\x07%'))),
      '\x1b]0;vim\x07%',
    );
  });

  test('normalizes sequences split across output chunks', () {
    final normalizer = TmuxOutputNormalizer();
    final input = 'a\x1bkecho\x1b\\1\x1b[cb';
    final output = <int>[];
    for (final byte in utf8.encode(input)) {
      output.addAll(normalizer([byte]));
    }

    expect(utf8.decode(output), 'a\x1b]0;echo\x1b\\1b');
  });

  test(
    'consumes unsupported escape introducers instead of printing payload',
    () {
      final unknown = <String>[];
      final normalizer = TmuxOutputNormalizer()..onUnknownEscape = unknown.add;

      expect(utf8.decode(normalizer(utf8.encode('a\x1bqpayload'))), 'apayload');
      expect(unknown, ['ESC 0x71']);
    },
  );

  test('suppresses queries that modern terminals also answer', () {
    final normalizer = TmuxOutputNormalizer();
    final input =
        '\x1b]10;?\x1b\\'
        '\x1b]11;?\x07'
        '\x1b]4;0;?\x1b\\'
        '\x1bP+q6b69747ty\x1b\\'
        '\x1bP\$qm\x1b\\'
        '\x1b[18t'
        '\x1b[?u';

    expect(normalizer(utf8.encode(input)), isEmpty);
  });

  test('resets a partial sequence at a pane or replay boundary', () {
    final normalizer = TmuxOutputNormalizer();

    expect(utf8.decode(normalizer(utf8.encode('old\x1b]0;partial'))), 'old');
    normalizer.reset();
    expect(
      utf8.decode(normalizer(utf8.encode('\x1b]0;new\x1b\\'))),
      '\x1b]0;new\x1b\\',
    );
  });

  test('unwraps and normalizes tmux passthrough sequences', () {
    final normalizer = TmuxOutputNormalizer();
    final input = '\x1bPtmux;\x1bkinner-title\x1b\\\x1b\\';

    expect(
      utf8.decode(normalizer(utf8.encode(input))),
      '\x1b]0;inner-title\x1b\\',
    );
  });

  test('unwraps passthrough with the doubled ESCs tmux sends', () {
    final normalizer = TmuxOutputNormalizer();
    final input = '\x1bPtmux;\x1b\x1b[?2004h\x1b\x1b]0;t\x07\x1b\\';

    expect(
      utf8.decode(normalizer(utf8.encode(input))),
      '\x1b[?2004h\x1b]0;t\x07',
    );
  });

  test('keeps an escape with intermediates whole', () {
    final unknown = <String>[];
    final normalizer = TmuxOutputNormalizer()..onUnknownEscape = unknown.add;
    const input = 'a\x1b(Bb\x1b)0c\x1b#8d\x1b%Ge\x1b F';

    expect(utf8.decode(normalizer(utf8.encode(input))), input);
    expect(unknown, isEmpty);
    // Split between the intermediate and its final byte.
    expect(utf8.decode(normalizer(utf8.encode('x\x1b('))), 'x');
    expect(utf8.decode(normalizer(utf8.encode('By'))), '\x1b(By');
  });

  test('flushes a truncated sequence instead of dropping it', () {
    final normalizer = TmuxOutputNormalizer();
    expect(utf8.decode(normalizer(utf8.encode('text'))), 'text');
    expect(normalizer(utf8.encode('\x1b]0;partial')), isEmpty);
    expect(utf8.decode(normalizer.close()), '\x1b]0;partial');
  });

  test('prevents xterm from answering a tmux-answered query', () {
    final normalizer = TmuxOutputNormalizer();
    final responses = <String>[];
    final terminal = Terminal(onOutput: responses.add);
    terminal.write(utf8.decode(normalizer(utf8.encode('before\x1b[cafter'))));

    expect(responses, isEmpty);

    // Without normalizing, the same query makes xterm emit the exact answer
    // whose tail appears as stray `1;2c` input after Vim exits.
    terminal.write('\x1b[c');
    expect(responses.single, '\x1b[?1;2c');
  });

  test('drops an oversized string sequence and recovers', () {
    final normalizer = TmuxOutputNormalizer();
    final oversized = '\x1b]52;c;${'A' * 3 * 1024 * 1024}\x07';

    expect(normalizer(utf8.encode(oversized)), isEmpty);
    expect(utf8.decode(normalizer(utf8.encode('after'))), 'after');
  });

  test('drops an oversized CSI sequence and recovers', () {
    final normalizer = TmuxOutputNormalizer();
    final oversized = '\x1b[${'0' * 5 * 1024}m';

    expect(normalizer(utf8.encode(oversized)), isEmpty);
    expect(utf8.decode(normalizer(utf8.encode('after'))), 'after');
  });

  group('program status', () {
    test('passes through while nothing reads it', () {
      final normalizer = TmuxOutputNormalizer();
      final data = utf8.encode('\x1b]7501;state=done\x1b\\\x1b]133;A\x07');
      expect(normalizer(data), data);
    });

    test('takes status out of the stream', () {
      final events = <TerminalStatusEvent>[];
      final normalizer = TmuxOutputNormalizer()..onStatus = events.add;
      final output = normalizer(
        utf8.encode(
          'a\x1b]7501;state=done\x1b\\b\x1b]9;4;3\x07c\x1b]133;D;1\x07'
          '\x1b]9;note\x07',
        ),
      );
      expect(utf8.decode(output), 'abc\x1b]9;note\x07');
      expect(events.map((e) => e.runtimeType), [
        ProgramStatusReport,
        TerminalProgress,
        ShellMark,
      ]);
    });

    test('reads a report split across chunks and wrapped for passthrough', () {
      final events = <TerminalStatusEvent>[];
      final normalizer = TmuxOutputNormalizer()..onStatus = events.add;
      normalizer(utf8.encode('\x1bPtmux;\x1b\x1b]7501;state=bl'));
      normalizer(utf8.encode('ocked\x1b\x1b\\\x1b\\'));
      expect((events.single as ProgramStatusReport).state, ProgramState.blocked);
    });

    test('drops the query, which only tmux could answer in time', () {
      final normalizer = TmuxOutputNormalizer();
      expect(normalizer(utf8.encode('\x1b]7501;?\x1b\\')), isEmpty);
    });
  });
}
