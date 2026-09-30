import 'dart:convert';

import 'package:server_box/data/ssh/tmux/tmux_control_protocol.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:test/test.dart';

void main() {
  group('TmuxControlProtocolParser', () {
    test('scans a PTY wrapper preamble before the handshake', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('x\x04\x08\x08\x1bP1000p%sessions-changed\n'),
      );

      expect(parser.handshakeSeen, isTrue);
      expect(events.single, isA<TmuxControlProtocolNotification>());
    });

    test('parses handshake split across chunks', () {
      final parser = TmuxControlProtocolParser();
      final events = [
        ...parser.push([0x1b, 0x50]),
        ...parser.push([0x31, 0x30]),
        ...parser.push([0x30, 0x30, 0x70]),
        ...parser.push(utf8.encode('%sessions-changed\n')),
      ];

      expect(parser.handshakeSeen, isTrue);
      expect(events.single, isA<TmuxControlProtocolNotification>());
      final notification = events.single as TmuxControlProtocolNotification;
      expect(notification.name, 'sessions-changed');
      expect(notification.args, isEmpty);
    });

    test('parses command result blocks', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode(
          '\x1bP1000p'
          '%begin 1363006971 2 1\n'
          '0: ksh* (1 panes)\n'
          '%end 1363006971 2 1\n',
        ),
      );

      final result = events.single as TmuxControlProtocolCommandResult;
      expect(result.result.error, isFalse);
      expect(result.result.lines, ['0: ksh* (1 panes)']);
      expect(result.result.output, '0: ksh* (1 panes)');
    });

    test('keeps blank lines inside command output', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('\x1bP1000p%begin 1 2 1\none\n\n\ntwo\n%end 1 2 1\n'),
      );

      final result = events.single as TmuxControlProtocolCommandResult;
      expect(result.result.lines, ['one', '', '', 'two']);
    });

    test('parses command errors as failed results', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('\x1bP1000p%begin 1 2 1\nunknown command\n%error 1 2 1\n'),
      );

      final result = events.single as TmuxControlProtocolCommandResult;
      expect(result.result.error, isTrue);
      expect(result.result.output, 'unknown command');
    });

    test('decodes escaped pane output bytes', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('\x1bP1000p%output %0 hello\\033[1mworld\\015\\134\n'),
      );

      final output = events.single as TmuxControlProtocolOutput;
      expect(output.paneId, TmuxPaneId('%0'));
      expect(output.data, utf8.encode('hello\x1b[1mworld\r\\'));
    });

    test('keeps unmatched command guards as capture output', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode(
          '\x1bP1000p'
          '%begin 1 2 1\n'
          '%end 999 2 1\n'
          '%error 1 999 1\n'
          '%end 1 2 1\n',
        ),
      );

      final result = events.single as TmuxControlProtocolCommandResult;
      expect(result.result.error, isFalse);
      expect(result.result.lines, ['%end 999 2 1', '%error 1 999 1']);
    });

    test('decodes extended output emitted after a pane is resumed', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode(
          '\x1bP1000p%extended-output %9 42 future : live\\040text\n',
        ),
      );

      final output = events.single as TmuxControlProtocolOutput;
      expect(output.paneId, TmuxPaneId('%9'));
      expect(utf8.decode(output.data), 'live text');
    });

    test('preserves spaces in pane output', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('\x1bP1000p%output %3 one two  three\n'),
      );

      final output = events.single as TmuxControlProtocolOutput;
      expect(utf8.decode(output.data), 'one two  three');
    });

    test('parses a line split at every boundary', () {
      final parser = TmuxControlProtocolParser();
      final bytes = utf8.encode('\x1bP1000p%output %9 chunked\\012output\n');
      final events = <TmuxControlProtocolEvent>[];
      for (final byte in bytes) {
        events.addAll(parser.push([byte]));
      }

      final output = events.single as TmuxControlProtocolOutput;
      expect(utf8.decode(output.data), 'chunked\noutput');
    });

    test('keeps an ST byte pair inside command output', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode(
          '\x1bP1000p'
          '%begin 1 2 1\n'
          'capture\x1b\\output\n'
          '%end 1 2 1\n'
          '%sessions-changed\n',
        ),
      );

      expect(parser.terminated, isFalse);
      final result = events.first as TmuxControlProtocolCommandResult;
      expect(result.result.lines.single, 'capture\x1b\\output');
      expect(
        events.whereType<TmuxControlProtocolNotification>().single.name,
        'sessions-changed',
      );
    });

    test('stops at the CC terminating ST sequence', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('\x1bP1000p%exit\n\x1b\\%output %0 ignored\n'),
      );

      expect(parser.terminated, isTrue);
      expect(
        events.whereType<TmuxControlProtocolNotification>().single.name,
        'exit',
      );
      expect(events.whereType<TmuxControlProtocolOutput>(), isEmpty);
    });

    test('rejects output without a pane id', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(utf8.encode('\x1bP1000p%output bad\n'));

      expect(events, isEmpty);
    });

    test('decodeOutputValue leaves malformed escapes intact', () {
      expect(
        TmuxControlProtocolParser.decodeOutputValue(utf8.encode(r'\12\999x')),
        utf8.encode(r'\12\999x'),
      );
      // A sign is not an octal digit.
      expect(
        TmuxControlProtocolParser.decodeOutputValue(utf8.encode(r'\+12\-12')),
        utf8.encode(r'\+12\-12'),
      );
    });

    test('rejects a line longer than the protocol limit', () {
      final parser = TmuxControlProtocolParser();
      parser.push(utf8.encode('\x1bP1000p'));

      expect(
        () => parser.push(List<int>.filled(70 * 1024, 0x61)),
        throwsA(isA<TmuxControlProtocolOverflow>()),
      );
    });

    test('rejects a command block larger than the protocol limit', () {
      final parser = TmuxControlProtocolParser();
      parser.push(utf8.encode('\x1bP1000p%begin 1 2 1\n'));
      final line = List<int>.filled(60 * 1024, 0x61);

      expect(() {
        for (var i = 0; i < 18; i++) {
          parser.push([...line, 0x0a]);
        }
      }, throwsA(isA<TmuxControlProtocolOverflow>()));
    });

    test('counts empty lines against the command block limit', () {
      final parser = TmuxControlProtocolParser();
      parser.push(utf8.encode('\x1bP1000p%begin 1 2 1\n'));

      expect(
        () => parser.push(List<int>.filled(1024 * 1024 + 1, 0x0a)),
        throwsA(isA<TmuxControlProtocolOverflow>()),
      );
    });

    test('a trailing ESC in command output keeps its line boundary', () {
      final parser = TmuxControlProtocolParser();
      final events = parser.push(
        utf8.encode('\x1bP1000p%begin 1 2 1\na\x1b\nb\x1b\x1b[0m\n%end 1 2 1\n'),
      );

      final result = events.single as TmuxControlProtocolCommandResult;
      expect(result.result.lines, ['a\x1b', 'b\x1b\x1b[0m']);
    });
  });
}
