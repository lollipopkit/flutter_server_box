import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';

Color get primaryColor => Color(locator<SettingStore>().primaryColor.fetch()!);

class DynamicColor {
  /// 白天模式显示的颜色
  Color light;

  /// 暗黑模式显示的颜色
  Color dark;

  DynamicColor(this.light, this.dark);

  resolve(BuildContext context) => isDarkMode(context) ? dark : light;
}

final mainColor = DynamicColor(Colors.black87, Colors.white70);
final progressColor = DynamicColor(Colors.grey.shade100, Colors.grey);
