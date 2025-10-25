// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'proxy_command_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProxyCommandConfig _$ProxyCommandConfigFromJson(Map<String, dynamic> json) =>
    _ProxyCommandConfig(
      command: json['command'] as String,
      args: (json['args'] as List<dynamic>?)?.map((e) => e as String).toList(),
      workingDirectory: json['workingDirectory'] as String?,
      environment: (json['environment'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      timeout: json['timeout'] == null
          ? const Duration(seconds: 30)
          : Duration(microseconds: (json['timeout'] as num).toInt()),
      retryOnFailure: json['retryOnFailure'] as bool? ?? false,
      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
      requiresExecutable: json['requiresExecutable'] as bool? ?? false,
      executableName: json['executableName'] as String?,
      executableDownloadUrl: json['executableDownloadUrl'] as String?,
    );

Map<String, dynamic> _$ProxyCommandConfigToJson(_ProxyCommandConfig instance) =>
    <String, dynamic>{
      'command': instance.command,
      'args': instance.args,
      'workingDirectory': instance.workingDirectory,
      'environment': instance.environment,
      'timeout': instance.timeout.inMicroseconds,
      'retryOnFailure': instance.retryOnFailure,
      'maxRetries': instance.maxRetries,
      'requiresExecutable': instance.requiresExecutable,
      'executableName': instance.executableName,
      'executableDownloadUrl': instance.executableDownloadUrl,
    };
