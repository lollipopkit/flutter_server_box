// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'float_shell_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FloatShellWindow _$FloatShellWindowFromJson(Map<String, dynamic> json) =>
    FloatShellWindow(
      left: (json['left'] as num?)?.toDouble() ?? -1.0,
      top: (json['top'] as num?)?.toDouble() ?? -1.0,
      width: (json['width'] as num?)?.toDouble() ?? 400.0,
      height: (json['height'] as num?)?.toDouble() ?? 560.0,
    );

Map<String, dynamic> _$FloatShellWindowToJson(FloatShellWindow instance) =>
    <String, dynamic>{
      'left': instance.left,
      'top': instance.top,
      'width': instance.width,
      'height': instance.height,
    };

FloatShellPill _$FloatShellPillFromJson(Map<String, dynamic> json) =>
    FloatShellPill(
      onRight: json['onRight'] as bool? ?? true,
      y: (json['y'] as num?)?.toDouble() ?? 0.62,
      sheetHeight: (json['sheetHeight'] as num?)?.toDouble() ?? 0.62,
    );

Map<String, dynamic> _$FloatShellPillToJson(FloatShellPill instance) =>
    <String, dynamic>{
      'onRight': instance.onRight,
      'y': instance.y,
      'sheetHeight': instance.sheetHeight,
    };

FloatShellConfig _$FloatShellConfigFromJson(Map<String, dynamic> json) =>
    FloatShellConfig(
      mode: json['mode'] as String? ?? 'hidden',
      window: json['window'] == null
          ? const FloatShellWindow()
          : FloatShellWindow.fromJson(json['window'] as Map<String, dynamic>),
      pill: json['pill'] == null
          ? const FloatShellPill()
          : FloatShellPill.fromJson(json['pill'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FloatShellConfigToJson(FloatShellConfig instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'window': instance.window,
      'pill': instance.pill,
    };
