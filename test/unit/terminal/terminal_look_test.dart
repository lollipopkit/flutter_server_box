import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/terminal.dart';

void main() {
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

    test('a load that finishes after a later one does not report', () async {
      // The startup load of a broken file, still running when the user clears
      // the font: what the settings show is about the font chosen now.
      final stale = TerminalFont.load('/no/such/dir/font.ttf');
      await TerminalFont.load('');
      await stale;
      expect(TerminalFont.failed.value, isFalse);
    });
  });
}
