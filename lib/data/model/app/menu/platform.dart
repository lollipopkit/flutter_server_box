import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:url_launcher/url_launcher.dart';

/// macOS Menu Bar
class MacOSMenuBarManager {
  static List<PlatformMenu> buildMenuBar(BuildContext context, Function(int) onTabChanged) {
    final l10n = context.l10n;
    final homeTabs = Stores.setting.homeTabs.fetch();
    return [
      PlatformMenu(
        label: 'Server Box',
        menus: [
          PlatformMenuItem(
            label: libL10n.about,
            onSelected: () => _showAboutDialog(context),
          ),
          PlatformMenuItem(
            label: libL10n.menuSettings,
            shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
            onSelected: () => _openSettings(context),
          ),
          PlatformMenuItem(
            label: libL10n.menuQuit,
            shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
            onSelected: () => SystemNavigator.pop(),
          ),
        ],
      ),
      PlatformMenu(
        label: libL10n.menuNavigate,
        menus: _buildNavigateMenuItems(l10n, homeTabs, onTabChanged),
      ),
      PlatformMenu(
        label: libL10n.menuInfo,
        menus: [
          PlatformMenuItem(
            label: l10n.menuGitHubRepository,
            onSelected: () => _openURL(Urls.thisRepo),
          ),
          PlatformMenuItem(
            label: libL10n.menuWiki,
            onSelected: () => _openURL(Urls.appWiki),
          ),
          PlatformMenuItem(
            label: libL10n.menuHelp,
            onSelected: () => _openURL(Urls.appHelp),
          ),
        ],
      ),
    ];
  }

  static List<PlatformMenuItem> _buildNavigateMenuItems(
    AppLocalizations l10n,
    List<AppTab> homeTabs,
    Function(int) onTabChanged,
  ) {
    final menuItems = <PlatformMenuItem>[];
    final tabLabels = {
      AppTab.server: libL10n.server,
      AppTab.ssh: 'SSH',
      AppTab.file: libL10n.file,
      AppTab.snippet: libL10n.snippet,
    };
    for (var i = 0; i < homeTabs.length; i++) {
      final tab = homeTabs[i];
      final label = tabLabels[tab];
      if (label == null) continue;
      final shortcutKey = _getShortcutKeyForIndex(i);
      menuItems.add(PlatformMenuItem(
        label: label,
        shortcut: shortcutKey != null
            ? SingleActivator(shortcutKey, meta: true)
            : null,
        onSelected: () => onTabChanged(i),
      ));
    }
    return menuItems;
  }

  static LogicalKeyboardKey? _getShortcutKeyForIndex(int index) {
    const keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    return index < keys.length ? keys[index] : null;
  }

  static Future<void> _showAboutDialog(BuildContext context) async {
    const channel = MethodChannel('about');
    await channel.invokeMethod('showAboutPanel');
  }

  static void _openSettings(BuildContext context) {
    SettingsPage.route.go(context);
  }

  static Future<void> _openURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}