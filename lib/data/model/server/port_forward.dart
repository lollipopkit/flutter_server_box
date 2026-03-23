import 'package:freezed_annotation/freezed_annotation.dart';

part 'port_forward.freezed.dart';
part 'port_forward.g.dart';

@freezed
abstract class PortForwardConfig with _$PortForwardConfig {
  const factory PortForwardConfig({
    required String id,
    required String serverId,
    required String name,
    @Default('localhost') String localHost,
    required int localPort,
    required String remoteHost,
    required int remotePort,
    String? description,
  }) = _PortForwardConfig;

  factory PortForwardConfig.fromJson(Map<String, dynamic> json) => _$PortForwardConfigFromJson(json);

  const PortForwardConfig._();

  String get displayAddr => '$localHost:$localPort → $remoteHost:$remotePort';
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
