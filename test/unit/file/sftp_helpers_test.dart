import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';
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

  test('a resource that arrives after an SFTP timeout is cleaned up', () async {
    final opened = Completer<Object>();
    final cleaned = Completer<Object>();

    await expectLater(
      withSftpLateCleanupTimeout(
        'open test resource',
        opened.future,
        const Duration(milliseconds: 1),
        cleanup: cleaned.complete,
      ),
      throwsA(isA<TimeoutException>()),
    );

    final resource = Object();
    opened.complete(resource);
    expect(await cleaned.future.timeout(const Duration(seconds: 1)), resource);
  });
}
