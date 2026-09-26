import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:icloud_storage_plus/models/exceptions.dart';
import 'package:server_box/data/model/app/error.dart';

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
    // A bare `OSError` is not here: the same class carries file-system errors,
    // and the network failures seen so far all arrived as the
    // `SocketException` wrapping one.
    SocketException() || HandshakeException() => false,
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
    // A password removed between `BakSyncer.sync`'s check and the upload.
    RemoteBackupPasswordMissing() => false,
    _ => true,
  };

  static const _dioNetwork = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.badCertificate,
  };
}
