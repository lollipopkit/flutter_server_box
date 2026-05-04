import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/shell_quote.dart';

void main() {
  group('shellSingleQuote', () {
    test('single-quotes values', () {
      expect(shellSingleQuote('/tmp/archive.zip'), "'/tmp/archive.zip'");
    });

    test('escapes single quotes inside values', () {
      expect(shellSingleQuote("/tmp/a'b.zip"), "'/tmp/a'\\''b.zip'");
    });

    test('keeps shell metacharacters inert inside single quotes', () {
      expect(
        shellSingleQuote('/tmp/\$(rm -rf x)`touch y`.tar.gz'),
        "'/tmp/\$(rm -rf x)`touch y`.tar.gz'",
      );
    });
  });
}
