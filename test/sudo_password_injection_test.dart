import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:xterm/core.dart';

bool hasPendingSudoPromptInOutputTail(String value) {
  final normalized = SudoPassword.normalizeOutput(value);
  final latest = normalized
      .split('\n')
      .reversed
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (latest.isEmpty) return false;
  return SudoPassword.isPromptText(latest);
}

void main() {
  group('Sudo prompt detection', () {
    test('detects standard English sudo prompt', () {
      expect(SudoPassword.isPromptText('[sudo] password for alice: '), isTrue);
    });

    test('detects sudo prompt without trailing space', () {
      expect(SudoPassword.isPromptText('[sudo] password for root:'), isTrue);
    });

    test('detects sudo prompt case insensitive', () {
      expect(SudoPassword.isPromptText('[SUDO] Password for user:'), isTrue);
    });

    test('detects password prompt ending with colon', () {
      expect(SudoPassword.isPromptText('Password:'), isTrue);
    });

    test('detects Chinese password prompt with ASCII colon', () {
      expect(SudoPassword.isPromptText('密码:'), isTrue);
    });

    test('detects Chinese prompt with full-width colon', () {
      // [sudo] 用户 alice 的密码：  — full-width '：' now also matched
      expect(
        SudoPassword.isPromptText('[sudo] 用户 alice 的密码：'),
        isTrue,
      );
    });

    test('ignores empty lines', () {
      expect(SudoPassword.isPromptText(''), isFalse);
    });

    test('ignores unrelated terminal output', () {
      expect(SudoPassword.isPromptText('gt610@host:~\$'), isFalse);
    });

    test('detects sudo prompt in SSH output tail', () {
      expect(
        hasPendingSudoPromptInOutputTail(
          'gt610@Debian1145:~\$ sudo apt update\r\n'
          '[sudo] password for gt610: ',
        ),
        isTrue,
      );
    });

    test('detects chunked sudo prompt after tail concatenation', () {
      final chunks = [
        'gt610@Debian1145:~\$ sudo apt update\r\n[sudo] pass',
        'word for gt610: ',
      ];

      expect(hasPendingSudoPromptInOutputTail(chunks.join()), isTrue);
    });

    test('detects sudo prompt wrapped in ANSI color sequence', () {
      expect(
        hasPendingSudoPromptInOutputTail(
          '\x1B[31m[sudo] password for gt610: \x1B[0m',
        ),
        isTrue,
      );
    });

    test('does not detect ordinary output in SSH output tail', () {
      expect(
        hasPendingSudoPromptInOutputTail(
          'Hit:1 http://deb.debian.org/debian bookworm InRelease\r\n'
          'Reading package lists... Done\r\n'
          'gt610@Debian1145:~\$ ',
        ),
        isFalse,
      );
    });

    test('does not detect stale sudo prompt in SSH output history', () {
      expect(
        hasPendingSudoPromptInOutputTail(
          'gt610@Debian1145:~\$ sudo apt update\r\n'
          '[sudo] password for gt610: \r\n'
          'All packages are up to date.\r\n'
          'gt610@Debian1145:~\$ ',
        ),
        isFalse,
        reason: 'Only the latest non-empty output line should be actionable.',
      );
    });
  });

  group('defaultInputHandler: Enter key with modifiers', () {
    /// The keytab has these Enter rules (no modifier constraints):
    ///   key Enter+NewLine : "\r\n"
    ///   key Enter-NewLine : "\r"
    /// They match regardless of Ctrl/Alt/Shift state because the rules
    /// don't specify modifier constraints, and insertModifiers() is a
    /// no-op when the action has no '*' placeholder.

    String? callEnterWithModifiers({
      required Terminal terminal,
      bool ctrl = false,
      bool alt = false,
      bool shift = false,
    }) {
      return defaultInputHandler.call(
        TerminalKeyboardEvent(
          key: TerminalKey.enter,
          shift: shift,
          ctrl: ctrl,
          alt: alt,
          state: terminal,
          altBuffer: false,
          platform: TerminalTargetPlatform.linux,
        ),
      );
    }

    test('Enter without modifiers returns \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(callEnterWithModifiers(terminal: terminal), equals('\r'));
    });

    test('Enter with Ctrl still returns \\r (keytab ignores modifiers)', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(
        callEnterWithModifiers(terminal: terminal, ctrl: true),
        equals('\r'),
        reason:
            'Enter keytab rules have no modifier constraints; '
            'Ctrl does NOT cause Enter to be dropped.',
      );
    });

    test('Enter with Alt still returns \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(callEnterWithModifiers(terminal: terminal, alt: true), equals('\r'));
    });

    test('Enter with Shift still returns \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(
        callEnterWithModifiers(terminal: terminal, shift: true),
        equals('\r'),
      );
    });

    test('Enter with Ctrl+Alt+Shift still returns \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(
        callEnterWithModifiers(
          terminal: terminal,
          ctrl: true,
          alt: true,
          shift: true,
        ),
        equals('\r'),
      );
    });
  });

  group('VirtKeyboard modifier merging — Enter key', () {
    /// Simulates what VirtKeyboard.call() does:
    /// merges stored modifier state into the event,
    /// then delegates to defaultInputHandler.
    String? simulateVirtKeyCall({
      required Terminal terminal,
      required TerminalKey key,
      required bool storedCtrl,
      required bool storedAlt,
      required bool storedShift,
    }) {
      return defaultInputHandler.call(
        TerminalKeyboardEvent(
          key: key,
          shift: storedShift,
          ctrl: storedCtrl,
          alt: storedAlt,
          state: terminal,
          altBuffer: false,
          platform: TerminalTargetPlatform.linux,
        ),
      );
    }

    test('Enter with stored Ctrl=true still produces \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(
        simulateVirtKeyCall(
          terminal: terminal,
          key: TerminalKey.enter,
          storedCtrl: true,
          storedAlt: false,
          storedShift: false,
        ),
        equals('\r'),
        reason:
            'VirtKeyboard merges Ctrl into Enter event, '
            'but the keytab Enter rules ignore modifiers. '
            'This means modifier pollution is NOT the root cause of #1180.',
      );
    });

    test('Enter with stored Ctrl=false produces \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      expect(
        simulateVirtKeyCall(
          terminal: terminal,
          key: TerminalKey.enter,
          storedCtrl: false,
          storedAlt: false,
          storedShift: false,
        ),
        equals('\r'),
      );
    });
  });

  group('Terminal password injection — end-to-end', () {
    test('textInput sends password bytes directly via onOutput', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      final sent = <String>[];
      terminal.onOutput = (data) => sent.add(data);

      terminal.textInput('myS3cret!');
      expect(sent, equals(['myS3cret!']));
    });

    test('keyInput(Enter) sends \\r via onOutput', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      final sent = <String>[];
      terminal.onOutput = (data) => sent.add(data);

      terminal.keyInput(TerminalKey.enter);
      expect(sent, equals(['\r']));
    });

    test('keyInput(Enter) with VirtKeyboard Ctrl=true still sends \\r', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      final sent = <String>[];
      terminal.onOutput = (data) => sent.add(data);

      terminal.inputHandler = _MockVirtKeyboard(ctrl: true, alt: false, shift: false);
      terminal.keyInput(TerminalKey.enter);
      expect(
        sent,
        equals(['\r']),
        reason: 'Enter always produces \\r regardless of modifier state',
      );
    });

    test('password + Enter: both sent correctly regardless of modifiers',
        () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      final sent = <String>[];
      terminal.onOutput = (data) => sent.add(data);

      terminal.textInput('myS3cret!');
      terminal.inputHandler = _MockVirtKeyboard(ctrl: true, alt: false, shift: false);
      terminal.keyInput(TerminalKey.enter);

      expect(
        sent,
        equals(['myS3cret!', '\r']),
        reason:
            'Both password and Enter are sent correctly. '
            'The bug is NOT about modifier pollution.',
      );
    });

    test('password + Enter: both sent correctly with clean modifiers', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      final sent = <String>[];
      terminal.onOutput = (data) => sent.add(data);

      terminal.textInput('myS3cret!');
      terminal.keyInput(TerminalKey.enter);

      expect(sent, equals(['myS3cret!', '\r']));
    });

    test('password with special characters is sent verbatim', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);
      final sent = <String>[];
      terminal.onOutput = (data) => sent.add(data);

      // Passwords with shell special chars should be sent as-is
      terminal.textInput(r'p@ss$w0rd!#%');
      expect(sent, equals([r'p@ss$w0rd!#%']));
    });

    test('sudo prompt detection works after terminal.write', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);

      // Simulate sudo prompt being written to terminal
      terminal.write('[sudo] password for user: ');

      expect(SudoPassword.isPromptText(terminal.buffer.currentLine.toString()), isTrue);
    });

    test('sudo prompt detection with buffered output', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);

      // Simulate output that arrives in chunks (like real SSH)
      terminal.write('some previous output\r\n');
      terminal.write('[sudo] password for user: ');

      expect(SudoPassword.isPromptText(terminal.buffer.currentLine.toString()), isTrue);
    });

    test('sudo prompt detection ignores terminal history', () {
      final terminal = Terminal(platform: TerminalTargetPlatform.linux);

      terminal.write('[sudo] password for user: \r\n');
      terminal.write('gt610@host:~\$ ');

      expect(SudoPassword.isPromptText(terminal.buffer.currentLine.toString()), isFalse);
    });
  });
}

/// Minimal mock of VirtKeyboard behavior for testing.
class _MockVirtKeyboard implements TerminalInputHandler {
  bool ctrl;
  bool alt;
  bool shift;

  _MockVirtKeyboard({
    required this.ctrl,
    required this.alt,
    required this.shift,
  });

  @override
  String? call(TerminalKeyboardEvent event) {
    final e = event.copyWith(
      ctrl: event.ctrl || ctrl,
      alt: event.alt || alt,
      shift: event.shift || shift,
    );
    return defaultInputHandler.call(e);
  }
}
