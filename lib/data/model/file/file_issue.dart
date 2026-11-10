import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:server_box/data/model/app/error.dart';

/// What a failed file operation actually means.
///
/// The same four answers arrive as `PathNotFoundException` from `dart:io`, as
/// `SftpStatusError` from a server, and as an HTTP status from a monitor agent.
/// A page that wants to say "this folder is gone" should not have to know which
/// of those it is looking at. Read off the error's type where it has one; only
/// what a shell printed (SCP's commands, sudo) is read by its words.
enum FileIssue {
  /// Nothing there — deleted, renamed, or never existed.
  notFound,

  /// This user is not allowed to. The one that has a way past it, where the
  /// backend has a shell behind it.
  denied,

  /// The far side stopped answering.
  timeout,

  unknown,
}

FileIssue classifyFileError(Object? error) => switch (error) {
  SftpUnavailable(:final cause) => classifyFileError(cause),
  TimeoutException() => FileIssue.timeout,
  // dart:io maps each platform's codes onto these; macOS TCC's EPERM for
  // protected folders such as Documents is a PathAccessException too.
  PathNotFoundException() => FileIssue.notFound,
  PathAccessException() => FileIssue.denied,
  SftpStatusError(:final code) => switch (code) {
    SftpStatusCode.noSuchFile => FileIssue.notFound,
    SftpStatusCode.permissionDenied => FileIssue.denied,
    // `SSH_FX_FAILURE` is what a server sends when it has decided not to be
    // specific, which for a write it refused usually means the same thing.
    SftpStatusCode.failure => FileIssue.denied,
    _ => FileIssue.unknown,
  },
  // 403 is a monitor agent refusing a path outside the roots it serves.
  MonitorHttpErr(type: MonitorHttpErrType.forbidden) => FileIssue.denied,
  MonitorHttpErr(type: MonitorHttpErrType.notFound) => FileIssue.notFound,
  // A transport failure carries the client's words (a Dio timeout, say).
  MonitorHttpErr(type: MonitorHttpErrType.net) => _classifyText('$error'),
  MonitorHttpErr() => FileIssue.unknown,
  DioException(type: DioExceptionType.connectionTimeout) ||
  DioException(type: DioExceptionType.sendTimeout) ||
  DioException(type: DioExceptionType.receiveTimeout) => FileIssue.timeout,
  DioException(:final response?) => switch (response.statusCode) {
    403 => FileIssue.denied,
    404 => FileIssue.notFound,
    _ => FileIssue.unknown,
  },
  DioException() => FileIssue.unknown,
  _ => _classifyText('$error'),
};

/// What a shell printed, which has no type to go by.
FileIssue _classifyText(String text) {
  final message = text.toLowerCase();

  // First, because a "no such file" is often reported with words that the
  // refusal test below would also match.
  if (message.contains('no such file')) return FileIssue.notFound;

  if (message.contains('timed out') || message.contains('timeout')) {
    return FileIssue.timeout;
  }

  if (message.contains('permission denied') ||
      message.contains('access denied') ||
      message.contains('operation not permitted')) {
    return FileIssue.denied;
  }

  return FileIssue.unknown;
}

/// The SFTP subsystem would not open on a connection that is otherwise up.
///
/// [toString] is the original's, so the detail shown on screen is unchanged;
/// [classifyFileError] reads its [cause].
final class SftpUnavailable implements Exception {
  const SftpUnavailable(this.cause);

  final Object cause;

  @override
  String toString() => '$cause';
}
