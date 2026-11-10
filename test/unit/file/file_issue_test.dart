import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/file/backend/sftp_escalation.dart';
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
    expect(
      classifyFileError(SftpStatusError(SftpStatusCode.noSuchFile, 'No such file')),
      FileIssue.notFound,
    );
    expect(
      classifyFileError(SftpStatusError(SftpStatusCode.permissionDenied, '')),
      FileIssue.denied,
    );
    // What a server sends when it has decided not to be specific.
    expect(
      classifyFileError(SftpStatusError(SftpStatusCode.failure, 'Failure')),
      FileIssue.denied,
    );
    expect(
      classifyFileError(SftpStatusError(SftpStatusCode.connectionLost, '')),
      FileIssue.unknown,
    );
  });

  test('this device says it with a typed exception, not a raw errno', () {
    // dart:io maps the platform's codes: a raw number means something else on
    // Windows (13 is ERROR_INVALID_DATA there).
    expect(
      classifyFileError(
        const PathAccessException('/a', OSError('Access is denied.', 5)),
      ),
      FileIssue.denied,
    );
    expect(
      classifyFileError(
        const FileSystemException('x', '/a', OSError('The data is invalid.', 13)),
      ),
      FileIssue.unknown,
    );
  });

  test('a monitor agent says it with a status', () {
    DioException status(int code) => DioException(
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: code),
    );
    expect(classifyFileError(status(403)), FileIssue.denied);
    expect(classifyFileError(status(404)), FileIssue.notFound);
    expect(classifyFileError(status(500)), FileIssue.unknown);
    expect(
      classifyFileError(const MonitorHttpErr(type: MonitorHttpErrType.forbidden)),
      FileIssue.denied,
    );
    expect(
      classifyFileError(const MonitorHttpErr(type: MonitorHttpErrType.notFound)),
      FileIssue.notFound,
    );
    expect(
      classifyFileError(
        const MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'Connection timed out',
        ),
      ),
      FileIssue.timeout,
    );
  });

  test('a wrapped SFTP failure reads as its cause', () {
    expect(
      classifyFileError(SftpUnavailable(TimeoutException('open'))),
      FileIssue.timeout,
    );
  });

  test('numbers inside other words are not codes', () {
    expect(classifyFileError('exit code 23'), FileIssue.unknown);
    expect(classifyFileError('exit code 32'), FileIssue.unknown);
    expect(classifyFileError('connection failure'), FileIssue.unknown);
  });

  test('a refusal is told from an absence, whichever words it uses', () {
    expect(classifyFileError('Permission denied'), FileIssue.denied);
    expect(classifyFileError('Access denied'), FileIssue.denied);
    expect(
      classifyFileError(
        PathAccessException(
          '/Users/test/Documents/ServerBox',
          const OSError('Operation not permitted', 1),
        ),
      ),
      FileIssue.denied,
    );
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
      SftpStatusError(SftpStatusCode.permissionDenied, ''),
      SftpStatusError(SftpStatusCode.failure, ''),
    ]) {
      expect(isPermissionDenied(error), isTrue, reason: '$error');
    }
    for (final error in ['No such file', 'Connection closed', 'failure', null]) {
      expect(isPermissionDenied(error), isFalse, reason: '$error');
    }
  });
}
