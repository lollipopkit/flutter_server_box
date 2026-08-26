import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';

void main() {
  test('an initial rename timeout starts no fallback or cleanup', () async {
    final calls = <String>[];

    await expectLater(
      replaceSftpPath(
        staging: 'new',
        destination: 'dest',
        aside: 'old',
        rename: (from, to) async {
          calls.add('$from->$to');
          throw TimeoutException('late rename');
        },
        remove: (path) async => calls.add('remove:$path'),
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(calls, ['new->dest']);
  });

  test('a fallback rename timeout starts no replacement', () async {
    final calls = <String>[];

    await expectLater(
      replaceSftpPath(
        staging: 'new',
        destination: 'dest',
        aside: 'old',
        rename: (from, to) async {
          calls.add('$from->$to');
          if (calls.length == 1) {
            throw SftpStatusError(SftpStatusCode.failure, 'destination exists');
          }
          throw TimeoutException('late rename');
        },
        remove: (path) async => calls.add('remove:$path'),
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(calls, ['new->dest', 'dest->old']);
  });

  test('a replacement timeout is not followed by rollback', () async {
    final calls = <String>[];

    await expectLater(
      replaceSftpPath(
        staging: 'new',
        destination: 'dest',
        aside: 'old',
        rename: (from, to) async {
          calls.add('$from->$to');
          if (calls.length == 1) {
            throw SftpStatusError(SftpStatusCode.failure, 'destination exists');
          }
          if (calls.length == 3) throw TimeoutException('late rename');
        },
        remove: (path) async => calls.add('remove:$path'),
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(calls, ['new->dest', 'dest->old', 'new->dest']);
  });

  test('a definite replacement failure restores the old destination', () async {
    final calls = <String>[];

    await expectLater(
      replaceSftpPath(
        staging: 'new',
        destination: 'dest',
        aside: 'old',
        rename: (from, to) async {
          calls.add('$from->$to');
          if (calls.length == 1) {
            throw SftpStatusError(SftpStatusCode.failure, 'destination exists');
          }
          if (calls.length == 3) {
            throw SftpStatusError(SftpStatusCode.failure, 'replacement failed');
          }
        },
        remove: (path) async => calls.add('remove:$path'),
      ),
      throwsA(isA<SftpStatusError>()),
    );

    expect(calls, ['new->dest', 'dest->old', 'new->dest', 'old->dest']);
  });

  test('a transport failure starts no fallback rename', () async {
    final calls = <String>[];

    await expectLater(
      replaceSftpPath(
        staging: 'new',
        destination: 'dest',
        aside: 'old',
        rename: (from, to) async {
          calls.add('$from->$to');
          throw SSHSocketError('connection lost');
        },
        remove: (path) async => calls.add('remove:$path'),
      ),
      throwsA(isA<SSHSocketError>()),
    );

    expect(calls, ['new->dest']);
  });
}
