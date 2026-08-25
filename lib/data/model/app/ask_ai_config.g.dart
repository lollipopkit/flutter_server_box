// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ask_ai_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AskAiConfig _$AskAiConfigFromJson(Map<String, dynamic> json) => AskAiConfig(
  baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com',
  apiKey: json['apiKey'] as String? ?? '',
  model: json['model'] as String? ?? 'gpt-5.6-luna',
  protocol: json['protocol'] as String? ?? 'auto',
  autoRunSafeCommands: json['autoRunSafeCommands'] as bool? ?? false,
  sendOnEnter: json['sendOnEnter'] as bool? ?? true,
);

Map<String, dynamic> _$AskAiConfigToJson(AskAiConfig instance) =>
    <String, dynamic>{
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'model': instance.model,
      'protocol': instance.protocol,
      'autoRunSafeCommands': instance.autoRunSafeCommands,
      'sendOnEnter': instance.sendOnEnter,
    };
