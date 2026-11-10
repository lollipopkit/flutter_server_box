import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/store/schema.dart';

/// [e], a reason a sync stopped (`SyncIface.lastFailure`), in the user's
/// words; null for one this does not know, which is shown as it is.
String? syncFailureText(Object e) => switch (e) {
  WrongPasswordException() || SyncPasswordMismatch() => l10n.syncPasswordMismatch,
  SchemaTooNewException() || SyncLogTooNew() => l10n.syncRemoteTooNew,
  RemoteBackupPasswordMissing() => e.toString(),
  SyncPasswordMissing() => const RemoteBackupPasswordMissing().toString(),
  SyncError(kind: SyncEngineErrorKind.remote) => l10n.syncUnreachable,
  SyncRefused(:final reason) => l10n.syncRefused(reason),
  LkcSyncError() => switch (e.exception) {
    final LkcException x => x.text(libL10n),
    _ => null,
  },
  LkcException() => e.text(libL10n),
  SocketException() || HttpException() || TimeoutException() => l10n.syncUnreachable,
  DioException(
    type: DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout,
  ) =>
    l10n.syncUnreachable,
  _ => null,
};
