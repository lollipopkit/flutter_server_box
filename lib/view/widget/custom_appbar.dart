import 'package:flutter/material.dart';
import 'package:macos_window_utils/window_manipulator.dart';

double? _titlebarHeight;

class CustomAppBar extends AppBar implements PreferredSizeWidget {
  CustomAppBar({
    super.key,
    super.title,
    super.actions,
    super.centerTitle,
    super.leading,
    super.backgroundColor,
  }) : super(toolbarHeight: (_titlebarHeight ?? 0) + kToolbarHeight);

  static Future<void> updateTitlebarHeight() async {
    final newTitlebarHeight = await WindowManipulator.getTitlebarHeight();
    if (_titlebarHeight != newTitlebarHeight) {
      _titlebarHeight = newTitlebarHeight;
    }
  }
}
