import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'connection_stat.freezed.dart';
part 'connection_stat.g.dart';

@freezed
abstract class ConnectionStat with _$ConnectionStat {
  const factory ConnectionStat({
    required String serverId,
    required String serverName,
    required DateTime timestamp,
    required ConnectionResult result,
    @Default('') String errorMessage,
    required int durationMs,
  }) = _ConnectionStat;

  factory ConnectionStat.fromJson(Map<String, dynamic> json) =>
      _$ConnectionStatFromJson(json);
}

@freezed
abstract class ServerConnectionStats with _$ServerConnectionStats {
  const factory ServerConnectionStats({
    required String serverId,
    required String serverName,
    required int totalAttempts,
    required int successCount,
    required int failureCount,
    @Default(null) DateTime? lastSuccessTime,
    @Default(null) DateTime? lastFailureTime,
    @Default([]) List<ConnectionStat> recentConnections,
    required double successRate,
  }) = _ServerConnectionStats;

  factory ServerConnectionStats.fromJson(Map<String, dynamic> json) =>
      _$ServerConnectionStatsFromJson(json);
}

enum ConnectionResult {
  @JsonValue('success')
  success,
  @JsonValue('timeout')
  timeout,
  @JsonValue('auth_failed')
  authFailed,
  @JsonValue('network_error')
  networkError,
  @JsonValue('unknown_error')
  unknownError;

  /// What a failed connection attempt was. A dial that ran out of time is a
  /// `SocketException` saying so, so the timeout is asked first.
  static ConnectionResult fromError(Object e) {
    final said = e.toString().toLowerCase();
    if (e is TimeoutException || said.contains('timed out') || said.contains('timeout')) return timeout;
    if (e is SSHAuthError ||
        said.contains('auth') ||
        said.contains('permission denied') ||
        said.contains('access denied')) {
      return authFailed;
    }
    if (e is SocketException ||
        said.contains('connection refused') ||
        said.contains('no route to host') ||
        said.contains('network') ||
        said.contains('socket')) {
      return networkError;
    }
    return unknownError;
  }
}

extension ConnectionResultExtension on ConnectionResult {
  String get displayName {
    switch (this) {
      case ConnectionResult.success:
        return libL10n.success;
      case ConnectionResult.timeout:
        return '${libL10n.error}(timeout)';
      case ConnectionResult.authFailed:
        return '${libL10n.error}(auth)';
      case ConnectionResult.networkError:
        return '${libL10n.error}(${libL10n.network})';
      case ConnectionResult.unknownError:
        return '${libL10n.error}(${libL10n.unknown})';
    }
  }

  bool get isSuccess => this == ConnectionResult.success;
}
