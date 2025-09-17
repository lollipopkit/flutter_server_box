import 'package:freezed_annotation/freezed_annotation.dart';

part 'discovery_result.freezed.dart';
part 'discovery_result.g.dart';

@freezed
abstract class SshDiscoveryResult with _$SshDiscoveryResult {
  const factory SshDiscoveryResult({
    required String ip,
    required int port,
    String? banner,
    @Default(false) bool isSelected,
  }) = _SshDiscoveryResult;

  factory SshDiscoveryResult.fromJson(Map<String, dynamic> json) => _$SshDiscoveryResultFromJson(json);
}

@freezed
abstract class SshDiscoveryReport with _$SshDiscoveryReport {
  const factory SshDiscoveryReport({
    required String generatedAt,
    required int durationMs,
    required int count,
    required List<SshDiscoveryResult> items,
  }) = _SshDiscoveryReport;

  factory SshDiscoveryReport.fromJson(Map<String, dynamic> json) => _$SshDiscoveryReportFromJson(json);
}

@freezed
abstract class SshDiscoveryConfig with _$SshDiscoveryConfig {
  const factory SshDiscoveryConfig({
    @Default(700) int timeoutMs,
    @Default(128) int maxConcurrency,
    @Default(false) bool enableMdns,
  }) = _SshDiscoveryConfig;
}

extension SshDiscoveryConfigX on SshDiscoveryConfig {
  List<String> toArgs() {
    final args = <String>[];
    args.add('--timeout-ms=$timeoutMs');
    args.add('--max-concurrency=$maxConcurrency');
    if (enableMdns) args.add('--enable-mdns');
    return args;
  }
}
