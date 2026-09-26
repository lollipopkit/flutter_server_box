import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:icloud_storage_plus/models/exceptions.dart';

/// Whether an error is a defect in this app, or the network's or the user's
/// account's doing: a host that does not answer, credentials it refuses,
/// iCloud signed out.
///
/// The fix for the second kind is where it is thrown — a failure the app
/// expects is handled there and never becomes uncaught. This is what those
/// places ask when they cannot tell which kind they caught (see
/// `BakSyncer.syncSoon`), and it is also the backstop in `beforeSend` for the
/// escapes whose path is not known yet: the dartssh2 handshake and auth
/// timeouts arrive with nothing but a timer on the stack.
///
/// By type, never by message: messages are localised and carry values, so
/// text breaks on the next translation. Anything not recognised is a defect —
/// letting an unknown through costs one report; filtering a real bug hides it.
abstract final class ReportFilter {
  static bool isDefect(Object error) => switch (error) {
    // Connecting: nothing listening, nothing answering, a certificate the
    // server chose. `HandshakeException` is TLS, to a monitor agent or WebDAV.
    SocketException() || HandshakeException() => false,
    // A socket failure that reached the caller without its `SocketException`.
    // Only the network codes: the same class carries file-system errors, and
    // those can be this app's.
    OSError(:final errorCode) => !_networkErrnos.contains(errorCode),
    // The SSH server refused, timed out, closed, or presented a different host
    // key. `SSHStateError` is deliberately absent: "transport is closed" is
    // this app writing to a connection it should know is gone.
    SSHAuthError() ||
    SSHHandshakeError() ||
    SSHSocketError() ||
    SSHHostkeyError() ||
    SSHChannelOpenError() ||
    SftpAbortError() => false,
    // HTTP to a sync remote, a monitor agent or an AI endpoint. `badResponse`
    // stays: a 500 from an agent can be the agent's own defect, which is ours.
    DioException(:final type) => !_dioNetwork.contains(type),
    ICloudContainerAccessException() => false,
    _ => true,
  };

  static const _dioNetwork = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.badCertificate,
  };

  /// Unreachable, reset, timed out, refused, host down, and name resolution,
  /// as each platform numbers them. The sets overlap other meanings across
  /// platforms — 8 is also `ENOEXEC` — which is accepted: a bare `OSError`
  /// reaching a report has come from a socket in every case seen so far.
  static const _networkErrnos = {
    // Linux and Android.
    101, 104, 110, 111, 112, 113,
    // Darwin.
    51, 54, 60, 61, 64, 65,
    // getaddrinfo: Darwin `EAI_NONAME`, Android `EAI_NODATA`, glibc's
    // negative codes.
    8, 7, -2, -3,
    // Winsock.
    10051, 10054, 10060, 10061, 10064, 10065, 11001, 11004,
  };
}
