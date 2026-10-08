import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:xterm/ui.dart';

void main() {
  final xterm = const TerminalStyle().fontFamilyFallback;

  group('TerminalLook.fontsFor', () {
    test('Linux asks for the system monospace font first', () {
      final fonts = TerminalLook.fontsFor(custom: null, linux: true);
      expect(fonts.first, 'monospace');
      // Ahead of the CJK fonts, which used to draw Latin text on Linux.
      expect(
        fonts.indexOf('monospace'),
        lessThan(fonts.indexOf('Noto Sans Mono CJK SC')),
      );
      expect(fonts.where((f) => f == 'monospace'), hasLength(1));
    });

    test('elsewhere the order is xterm\'s own', () {
      expect(TerminalLook.fontsFor(custom: null, linux: false), xterm);
    });

    test('a chosen font comes first, then the system monospace font', () {
      final fonts = TerminalLook.fontsFor(custom: 'Iosevka.ttf', linux: true);
      expect(fonts.take(2), ['Iosevka.ttf', 'monospace']);
    });

    test('UI fallbacks follow, each family once', () {
      final fonts = TerminalLook.fontsFor(
        custom: '',
        linux: false,
        uiFallbacks: const ['sans-serif', 'Noto Sans SC'],
      );
      expect(fonts.first, xterm.first);
      expect(fonts.last, 'Noto Sans SC');
      expect(fonts.where((f) => f == 'sans-serif'), hasLength(1));
    });
  });

  group('TerminalFont.load', () {
    test('a missing file is reported as failed', () async {
      await TerminalFont.load('/no/such/dir/font.ttf');
      expect(TerminalFont.failed.value, isTrue);
    });

    test('no file chosen is not a failure', () async {
      TerminalFont.failed.value = true;
      await TerminalFont.load('');
      expect(TerminalFont.failed.value, isFalse);
    });
  });
}
