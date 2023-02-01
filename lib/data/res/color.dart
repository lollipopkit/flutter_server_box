import 'package:flutter/material.dart';

import '../../core/utils/ui.dart';
import '../../locator.dart';
import '../store/setting.dart';

final _primaryColor = locator<SettingStore>().primaryColor.listenable();

class PrimaryColor extends StatelessWidget {
  final Widget Function(BuildContext context, Color primaryColor) builder;

  const PrimaryColor({Key? key, required this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      builder: (context, c, child) => builder(context, Color(c)),
      valueListenable: _primaryColor,
    );
  }
}

class DynamicColor {
  /// 白天模式显示的颜色
  Color light;

  /// 暗黑模式显示的颜色
  Color dark;

  DynamicColor(this.light, this.dark);

  resolve(BuildContext context) => isDarkMode(context) ? dark : light;
}

final mainColor = DynamicColor(Colors.black87, Colors.white70);
final progressColor = DynamicColor(Colors.grey.shade100, Colors.white10);
