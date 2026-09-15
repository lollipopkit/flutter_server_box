import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';
import 'package:server_box/data/model/file/file_issue.dart';

void main() {
  test('what this device says when a directory is gone', () {
    // Verbatim from a file tab reopened into a download folder that had been
    // cleared out since.
    final error = const PathNotFoundException(
      '/Users/x/Documents/file/host/home/u',
      OSError('No such file or directory', 2),
      'Directory listing failed',
    );

    expect(classifyFileError(error), FileIssue.notFound);
  });

  test('what a server says, in its own numbers', () {
    // `SftpStatusError.toString()` is 'SftpStatusError: <message>(code N)'.
    expect(
      classifyFileError('SftpStatusError: No such file(code 2)'),
      FileIssue.notFound,
    );
    expect(
      classifyFileError('SftpStatusError: Permission denied(code 3)'),
      FileIssue.denied,
    );
  });

  test('a refusal is told from an absence, whichever words it uses', () {
    expect(classifyFileError('Permission denied'), FileIssue.denied);
    expect(classifyFileError('Access denied'), FileIssue.denied);
    // What a server sends when it has decided not to be specific.
    expect(classifyFileError('failure'), FileIssue.denied);
    expect(classifyFileError('No such file'), FileIssue.notFound);
  });

  test('a timeout is neither', () {
    expect(
      classifyFileError(TimeoutException('SFTP list directory timed out')),
      FileIssue.timeout,
    );
    expect(classifyFileError('SFTP stat timeout'), FileIssue.timeout);
  });

  test('anything else stays unknown rather than being guessed at', () {
    expect(classifyFileError('Connection closed'), FileIssue.unknown);
    expect(classifyFileError(null), FileIssue.unknown);
  });

  test('the sudo retry and the page agree about the same error', () {
    // Two callers, one classifier: "offer sudo" and "say permission denied"
    // must not be able to disagree.
    for (final error in [
      'Permission denied',
      'Access denied',
      'SftpStatusError: (code 3)',
      'failure',
    ]) {
      expect(isPermissionDenied(error), isTrue, reason: error);
    }
    for (final error in ['No such file', 'Connection closed', null]) {
      expect(isPermissionDenied(error), isFalse, reason: '$error');
    }
  });
}
