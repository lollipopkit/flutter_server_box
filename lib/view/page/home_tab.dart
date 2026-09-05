import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/agent/agent.dart';
import 'package:server_box/view/page/benchmark/tab.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/tab.dart';
import 'package:server_box/view/widget/conn_count_badge.dart';

extension AppTabViewX on AppTab {
  Widget get page {
    return switch (this) {
      AppTab.server => const ServerPage(),
      AppTab.ssh => const SSHTabPage(),
      AppTab.file => const FileTabPage(),
      AppTab.snippet => const SnippetListPage(),
      AppTab.agent => const AgentPage(),
      AppTab.benchmark => const BenchmarkTabPage(),
    };
  }

  /// The tab's mark. Also what a page *listing* tabs draws — the settings page
  /// that turns them on and reorders them.
  Widget get icon {
    return switch (this) {
      AppTab.server => const Icon(BoxIcons.bx_server),
      AppTab.ssh => const Icon(Icons.terminal_outlined),
      AppTab.snippet => const Icon(Icons.code_outlined),
      AppTab.file => const Icon(Icons.folder_open),
      AppTab.agent => const Icon(Icons.auto_awesome_outlined),
      AppTab.benchmark => const Icon(Icons.speed_outlined),
    };
  }

  /// The filled form, for the tab being looked at.
  Widget get selectedIcon {
    return switch (this) {
      AppTab.server => const Icon(BoxIcons.bxs_server),
      AppTab.ssh => const Icon(Icons.terminal),
      AppTab.snippet => const Icon(Icons.code),
      AppTab.file => const Icon(Icons.folder),
      AppTab.agent => const Icon(Icons.auto_awesome),
      AppTab.benchmark => const Icon(Icons.speed),
    };
  }

  String get label {
    return switch (this) {
      AppTab.server => libL10n.server,
      // Not "SSH": a terminal is what this tab holds, and SSH is only where
      // most of them happen to come from. One already comes from a monitor
      // agent's own PTY, and the name had to stop naming the transport before
      // a shell on this device could live here too.
      AppTab.ssh => libL10n.terminal,
      AppTab.snippet => libL10n.snippet,
      AppTab.file => libL10n.file,
      AppTab.agent => 'Agent',
      AppTab.benchmark => l10n.benchmark,
    };
  }

  /// Returns a [Widget] rather than a [NavigationDestination] on purpose:
  /// `NavigationBar.destinations` is a list of widgets, so [onMenu] can wrap
  /// the whole cell. The destination still finds the bar's inherited
  /// information above the wrapper, and a long press anywhere on the item —
  /// icon, label, or the space around them — reaches the menu.
  Widget navDestination({ContextMenuOpener? onMenu}) {
    return _withMenu(
      NavigationDestination(
        icon: _counted(icon),
        selectedIcon: _counted(selectedIcon),
        label: label,
      ),
      onMenu,
    );
  }

  /// The same tab in the rail.
  ///
  /// [NavigationRail.destinations] is typed, so there is nothing to wrap the
  /// item as a whole with. The icon and the label are the two widgets it does
  /// take, and between them they are everything the item draws.
  NavigationRailDestination navRailDestination({ContextMenuOpener? onMenu}) {
    return NavigationRailDestination(
      icon: _withMenu(_counted(icon), onMenu),
      selectedIcon: _withMenu(_counted(selectedIcon), onMenu),
      label: _withMenu(Text(label), onMenu),
    );
  }

  /// Adds the connection count to the server tab, and to nothing else.
  ///
  /// Only where the tab is a control. In a list of tabs to reorder, a count
  /// would be answering a question the row is not about.
  Widget _counted(Widget icon) =>
      this == AppTab.server ? ConnCountBadge(child: icon) : icon;
}

/// Adds the long press and the right-click, and nothing when there is no menu.
///
/// Translucent, so the tap that switches tabs still reaches the ink response
/// this sits inside. A long press wins the arena over that tap by holding past
/// the timeout, which is what lets one target carry both.
Widget _withMenu(Widget child, ContextMenuOpener? onMenu) {
  if (onMenu == null) return child;
  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onLongPress: () => onMenu(null),
    child: child,
  ).onSecondary(onMenu);
}
