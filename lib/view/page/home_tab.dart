import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/local.dart';

extension AppTabViewX on AppTab {
  Widget get page {
    return switch (this) {
      AppTab.server => const ServerPage(),
      AppTab.ssh => const SSHTabPage(),
      AppTab.file => const LocalFilePage(),
      AppTab.snippet => const SnippetListPage(),
    };
  }

  NavigationDestination get navDestination {
    return switch (this) {
      AppTab.server => NavigationDestination(
        icon: const Icon(BoxIcons.bx_server),
        label: libL10n.server,
        selectedIcon: const Icon(BoxIcons.bxs_server),
      ),
      AppTab.ssh => const NavigationDestination(
        icon: Icon(Icons.terminal_outlined),
        label: 'SSH',
        selectedIcon: Icon(Icons.terminal),
      ),
      AppTab.snippet => NavigationDestination(
        icon: const Icon(Icons.code_outlined),
        label: libL10n.snippet,
        selectedIcon: const Icon(Icons.code),
      ),
      AppTab.file => NavigationDestination(
        icon: const Icon(Icons.folder_open),
        label: libL10n.file,
        selectedIcon: const Icon(Icons.folder),
      ),
    };
  }

  NavigationRailDestination get navRailDestination {
    return switch (this) {
      AppTab.server => NavigationRailDestination(
        icon: const Icon(BoxIcons.bx_server),
        label: Text(libL10n.server),
        selectedIcon: const Icon(BoxIcons.bxs_server),
      ),
      AppTab.ssh => const NavigationRailDestination(
        icon: Icon(Icons.terminal_outlined),
        label: Text('SSH'),
        selectedIcon: Icon(Icons.terminal),
      ),
      AppTab.snippet => NavigationRailDestination(
        icon: const Icon(Icons.code_outlined),
        label: Text(libL10n.snippet),
        selectedIcon: const Icon(Icons.code),
      ),
      AppTab.file => NavigationRailDestination(
        icon: const Icon(Icons.folder_open),
        label: Text(libL10n.file),
        selectedIcon: const Icon(Icons.folder),
      ),
    };
  }
}
