import 'package:flutter/material.dart';

import '../../data/store/setting.dart';
import '../../locator.dart';

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
