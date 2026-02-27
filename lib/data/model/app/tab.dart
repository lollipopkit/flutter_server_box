import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
// import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/local.dart';

part 'tab.g.dart';

@HiveType(typeId: 103)
enum AppTab {
  @HiveField(0)
  server,
  @HiveField(1)
  ssh,
  @HiveField(2)
  file,
  @HiveField(3)
  snippet
  //settings,
  ;

  Widget get page {
    return switch (this) {
      server => const ServerPage(),
      //settings => const SettingsPage(),
      ssh => const SSHTabPage(),
      file => const LocalFilePage(),
      snippet => const SnippetListPage(),
    };
  }

  NavigationDestination get navDestination {
    return switch (this) {
      server => NavigationDestination(
        icon: const Icon(BoxIcons.bx_server),
        label: libL10n.server,
        selectedIcon: const Icon(BoxIcons.bxs_server),
      ),
      // settings => NavigationDestination(
      //     icon: const Icon(Icons.settings),
      //     label: libL10n.setting,
      //     selectedIcon: const Icon(Icons.settings),
      //   ),
      ssh => const NavigationDestination(
        icon: Icon(Icons.terminal_outlined),
        label: 'SSH',
        selectedIcon: Icon(Icons.terminal),
      ),
      snippet => NavigationDestination(
        icon: const Icon(Icons.code),
        label: libL10n.snippet,
        selectedIcon: const Icon(Icons.code),
      ),
      file => NavigationDestination(
        icon: const Icon(Icons.folder_open),
        label: libL10n.file,
        selectedIcon: const Icon(Icons.folder),
      ),
    };
  }

  NavigationRailDestination get navRailDestination {
    return switch (this) {
      server => NavigationRailDestination(
        icon: const Icon(BoxIcons.bx_server),
        label: Text(libL10n.server),
        selectedIcon: const Icon(BoxIcons.bxs_server),
      ),
      // settings => NavigationRailDestination(
      //     icon: const Icon(Icons.settings),
      //     label: libL10n.setting,
      //     selectedIcon: const Icon(Icons.settings),
      //   ),
      ssh => const NavigationRailDestination(
        icon: Icon(Icons.terminal_outlined),
        label: Text('SSH'),
        selectedIcon: Icon(Icons.terminal),
      ),
      snippet => NavigationRailDestination(
        icon: const Icon(Icons.code),
        label: Text(libL10n.snippet),
        selectedIcon: const Icon(Icons.code),
      ),
      file => NavigationRailDestination(
        icon: const Icon(Icons.folder_open),
        label: Text(libL10n.file),
        selectedIcon: const Icon(Icons.folder),
      ),
    };
  }

  static List<NavigationDestination> get navDestinations {
    return AppTab.values.map((e) => e.navDestination).toList();
  }

  static List<NavigationRailDestination> get navRailDestinations {
    return AppTab.values.map((e) => e.navRailDestination).toList();
  }



  /// Helper function to parse AppTab list from stored object
  static List<AppTab> parseAppTabsFromObj(dynamic val) {
    if (val is List) {
      final tabs = <AppTab>[];
      for (final e in val) {
        final tab = _parseAppTabFromElement(e);
        if (tab != null) {
          tabs.add(tab);
        }
      }
      if (tabs.isNotEmpty) return tabs;
    }
    return AppTab.values;
  }

  /// Helper function to parse a single AppTab from various element types
  static AppTab? _parseAppTabFromElement(dynamic e) {
    if (e is AppTab) {
      return e;
    } else if (e is String) {
      return AppTab.values.firstWhereOrNull((t) => t.name == e);
    } else if (e is int) {
      if (e >= 0 && e < AppTab.values.length) {
        return AppTab.values[e];
      }
    }
    return null;
  }
}
