import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

int? _titlebarHeight;
bool _drawTitlebar = false;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.centerTitle,
    this.leading,
    this.backgroundColor,
  });

  final Widget? title;
  final List<Widget>? actions;
  final bool? centerTitle;
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bar = AppBar(
      key: key,
      title: title,
      actions: actions,
      centerTitle: centerTitle,
      leading: leading,
      backgroundColor: backgroundColor,
      toolbarHeight: (_titlebarHeight ?? 0) + kToolbarHeight,
    );
    if (!_drawTitlebar) return bar;
    return Stack(
      children: [
        bar,
        Positioned(
          right: 0,
          top: 0,
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.minimize),
                onPressed: () => windowManager.minimize(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.crop_square),
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => windowManager.close(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> updateTitlebarHeight() async {
    switch (Platform.operatingSystem) {
      case 'macos':
        final newTitlebarHeight = await windowManager.getTitleBarHeight();
        if (_titlebarHeight != newTitlebarHeight) {
          _titlebarHeight = newTitlebarHeight;
        }
        break;
      // Draw a titlebar on Linux
      case 'linux' || 'windows':
        _titlebarHeight = 27;
        _drawTitlebar = true;
        break;
      default:
        break;
    }
  }

  @override
  Size get preferredSize =>
      Size.fromHeight((_titlebarHeight ?? 0) + kToolbarHeight);
}
