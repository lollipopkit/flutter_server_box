import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/agent/agent.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/tab.dart';

extension AppTabViewX on AppTab {
  Widget get page {
    return switch (this) {
      AppTab.server => const ServerPage(),
      AppTab.ssh => const SSHTabPage(),
      AppTab.file => const FileTabPage(),
      AppTab.snippet => const SnippetListPage(),
      AppTab.agent => const AgentPage(),
    };
  }

  NavigationDestination get navDestination {
    return switch (this) {
      AppTab.server => NavigationDestination(
        icon: const Icon(BoxIcons.bx_server),
        label: libL10n.server,
        selectedIcon: const Icon(BoxIcons.bxs_server),
      ),
      // Not "SSH": a terminal is what this tab holds, and SSH is only where
      // most of them happen to come from. One already comes from a monitor
      // agent's own PTY, and the name had to stop naming the transport before
      // a shell on this device could live here too.
      AppTab.ssh => NavigationDestination(
        icon: const Icon(Icons.terminal_outlined),
        label: libL10n.terminal,
        selectedIcon: const Icon(Icons.terminal),
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
      AppTab.agent => NavigationDestination(
        icon: const Icon(Icons.auto_awesome_outlined),
        label: 'Agent',
        selectedIcon: const Icon(Icons.auto_awesome),
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
      AppTab.ssh => NavigationRailDestination(
        icon: const Icon(Icons.terminal_outlined),
        label: Text(libL10n.terminal),
        selectedIcon: const Icon(Icons.terminal),
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
      AppTab.agent => NavigationRailDestination(
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text('Agent'),
        selectedIcon: const Icon(Icons.auto_awesome),
      ),
    };
  }
}
