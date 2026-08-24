// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_shell_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentShellWindow _$AgentShellWindowFromJson(Map<String, dynamic> json) =>
    AgentShellWindow(
      left: (json['left'] as num?)?.toDouble() ?? -1.0,
      top: (json['top'] as num?)?.toDouble() ?? -1.0,
      width: (json['width'] as num?)?.toDouble() ?? 400.0,
      height: (json['height'] as num?)?.toDouble() ?? 560.0,
    );

Map<String, dynamic> _$AgentShellWindowToJson(AgentShellWindow instance) =>
    <String, dynamic>{
      'left': instance.left,
      'top': instance.top,
      'width': instance.width,
      'height': instance.height,
    };

AgentShellPill _$AgentShellPillFromJson(Map<String, dynamic> json) =>
    AgentShellPill(
      onRight: json['onRight'] as bool? ?? true,
      y: (json['y'] as num?)?.toDouble() ?? 0.62,
      sheetHeight: (json['sheetHeight'] as num?)?.toDouble() ?? 0.62,
    );

Map<String, dynamic> _$AgentShellPillToJson(AgentShellPill instance) =>
    <String, dynamic>{
      'onRight': instance.onRight,
      'y': instance.y,
      'sheetHeight': instance.sheetHeight,
    };

AgentShellConfig _$AgentShellConfigFromJson(Map<String, dynamic> json) =>
    AgentShellConfig(
      mode: json['mode'] as String? ?? 'hidden',
      window: json['window'] == null
          ? const AgentShellWindow()
          : AgentShellWindow.fromJson(json['window'] as Map<String, dynamic>),
      pill: json['pill'] == null
          ? const AgentShellPill()
          : AgentShellPill.fromJson(json['pill'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AgentShellConfigToJson(AgentShellConfig instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'window': instance.window,
      'pill': instance.pill,
    };
