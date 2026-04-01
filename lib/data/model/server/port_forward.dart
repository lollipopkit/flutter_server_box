import 'package:freezed_annotation/freezed_annotation.dart';

part 'port_forward.freezed.dart';
part 'port_forward.g.dart';

enum PortForwardType {
  @JsonValue('local')
  local,
  @JsonValue('remote')
  remote,
  @JsonValue('dynamic')
  dynamic,
}

@freezed
abstract class PortForwardConfig with _$PortForwardConfig {
  const factory PortForwardConfig({
    required String id,
    required String serverId,
    required String name,
    required PortForwardType type,
    String? localHost,
    @Default(0) int localPort,
    String? remoteHost,
    int? remotePort,
  }) = _PortForwardConfig;

  factory PortForwardConfig.fromJson(Map<String, dynamic> json) => _$PortForwardConfigFromJson(json);

  const PortForwardConfig._();

  String get displayAddr {
    if (type == PortForwardType.dynamic) {
      return '$localHost:$localPort (SOCKS5)';
    }
    return '$localHost:$localPort → ${remoteHost ?? "?"}:${remotePort ?? "?"}';
  }
}

@freezed
abstract class PortForwardState with _$PortForwardState {
  const factory PortForwardState({
    required String serverId,
    @Default([]) List<PortForwardConfig> configs,
    @Default({}) Map<String, PortForwardStatus> activeForwards,
  }) = _PortForwardState;
}

class PortForwardStatus {
  final String id;
  final bool isActive;
  final String? error;

  const PortForwardStatus({
    required this.id,
    this.isActive = false,
    this.error,
  });

  PortForwardStatus copyWith({
    String? id,
    bool? isActive,
    Object? error = _sentinel,
  }) {
    return PortForwardStatus(
      id: id ?? this.id,
      isActive: isActive ?? this.isActive,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();
