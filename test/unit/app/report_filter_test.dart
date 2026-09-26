import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icloud_storage_plus/models/exceptions.dart';
import 'package:server_box/core/service/report_filter.dart';

/// What reaches a crash report. The not-defects are the ones that arrived by
/// the thousand; the defects are the ones filtering must never hide.
void main() {
  DioException dio(DioExceptionType type) =>
      DioException(requestOptions: RequestOptions(), type: type);

  test("the user's network and settings are not defects", () {
    final notDefects = <Object>[
      const SocketException('Connection refused'),
      const OSError('Connection timed out', 110),
      const OSError('Host is down', 64),
      const OSError('Connection timed out', 10060),
      const OSError('nodename nor servname provided, or not known', 8),
      SSHAuthFailError('All authentication methods failed'),
      SSHAuthAbortError('Authentication timed out'),
      SSHHandshakeError('Handshake timed out'),
      SSHChannelOpenError(2, 'open failed'),
      SftpAbortError('Connection closed'),
      dio(DioExceptionType.connectionTimeout),
      dio(DioExceptionType.connectionError),
      const ICloudContainerAccessException(
        operation: 'download',
        retryable: false,
        message: 'not signed in',
      ),
    ];
    for (final e in notDefects) {
      expect(ReportFilter.isDefect(e), isFalse, reason: '$e');
    }
  });

  test('defects are still reported', () {
    final defects = <Object>[
      // Writing to a connection the app should know is gone.
      SSHStateError('Transport is closed'),
      // A file error shares `OSError` with the network codes.
      const OSError('No such file or directory', 2),
      // A timeout of the app's own could be a hang here.
      TimeoutException('something'),
      // An agent's 500 can be the agent's own defect.
      dio(DioExceptionType.badResponse),
      StateError('Bad state'),
      TypeError(),
      ArgumentError('index'),
    ];
    for (final e in defects) {
      expect(ReportFilter.isDefect(e), isTrue, reason: '$e');
    }
  });
}
