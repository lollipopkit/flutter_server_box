import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:url_launcher/url_launcher.dart';

/// macOS Menu Bar
class MacOSMenuBarManager {
  static List<PlatformMenu> buildMenuBar(BuildContext context, Function(int) onTabChanged) {
    final l10n = context.l10n;
    return [
      PlatformMenu(
        label: 'Server Box',
        menus: [
          PlatformMenuItem(
            label: l10n.menuAbout,
            onSelected: () => _showAboutDialog(context),
          ),
          PlatformMenuItem(
            label: l10n.menuSettings,
            shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
            onSelected: () => _openSettings(context),
          ),
          PlatformMenuItem(
            label: l10n.menuQuit,
            shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
            onSelected: () => exit(0),
          ),
        ],
      ),
      PlatformMenu(
        label: l10n.menuNavigate,
        menus: [
          PlatformMenuItem(
            label: l10n.server,
            shortcut: const SingleActivator(LogicalKeyboardKey.digit1, meta: true),
            onSelected: () => onTabChanged(0),
          ),
          PlatformMenuItem(
            label: 'SSH',
            shortcut: const SingleActivator(LogicalKeyboardKey.digit2, meta: true),
            onSelected: () => onTabChanged(1),
          ),
          PlatformMenuItem(
            label: libL10n.file,
            shortcut: const SingleActivator(LogicalKeyboardKey.digit3, meta: true),
            onSelected: () => onTabChanged(2),
          ),
          PlatformMenuItem(
            label: l10n.snippet,
            shortcut: const SingleActivator(LogicalKeyboardKey.digit4, meta: true),
            onSelected: () => onTabChanged(3),
          ),
        ],
      ),
      PlatformMenu(
        label: l10n.menuHelp,
        menus: [
          PlatformMenuItem(
            label: l10n.menuGitHubRepository,
            onSelected: () => _openURL('https://github.com/lollipopkit/flutter_server_box'),
          ),
          PlatformMenuItem(
            label: l10n.menuWiki,
            onSelected: () => _openURL('https://github.com/lollipopkit/flutter_server_box/wiki'),
          ),
        ],
      ),
    ];
  }

  static Future<void> _showAboutDialog(BuildContext context) async {
    const channel = MethodChannel('about');
    await channel.invokeMethod('showAboutPanel');
  }

  static Future<void> _openSettings(BuildContext context) async {
    SettingsPage.route.go(context);
  }

  static Future<void> _openURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}