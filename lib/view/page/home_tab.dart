import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/agent/agent.dart';
import 'package:server_box/view/page/benchmark/tab.dart';
import 'package:server_box/view/page/pkg/tab.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/tab.dart';
import 'package:server_box/view/widget/conn_count_badge.dart';

/// One entry of the home bar, resolved from the id the arrangement stores.
///
/// The bar holds ids since m023, because a plugin's tab is not a case of
/// [AppTab] and a list typed by that enum has nowhere to put one. Everything
/// the home page needs of a tab — what it is called, what it draws, what it
/// puts in the bar and the rail — is asked of this instead of of the enum, so
/// the page does not have to know which kind it is looking at.
sealed class HomeTab {
  const HomeTab();

  /// Null for an id this build has nothing for: a tab removed in an upgrade,
  /// or one a plugin contributed and is no longer installed. The arrangement
  /// keeps such an id and every reader skips it — see
  /// `FeatureSlot.putEnabledIds`.
  static HomeTab? of(String id) {
    final builtIn = AppTab.fromId(id);
    if (builtIn != null) return BuiltInHomeTab(builtIn);
    return null;
  }

  String get id;
  String get label;
  IconData get iconData;
  IconData get selectedIconData;

  /// The page itself. Built once and kept alive behind the others, so this is
  /// asked for on every build and must return the same kind of thing each
  /// time.
  Widget get page;

  Widget get icon => Icon(iconData);
  Widget get selectedIcon => Icon(selectedIconData);

  Widget navDestination({ContextMenuOpener? onMenu});
  NavigationRailDestination navRailDestination({ContextMenuOpener? onMenu});
}

/// One of the app's own.
final class BuiltInHomeTab extends HomeTab {
  const BuiltInHomeTab(this.tab);

  final AppTab tab;

  @override
  String get id => tab.name;
  @override
  String get label => tab.label;
  @override
  IconData get iconData => tab.iconData;
  @override
  IconData get selectedIconData => tab.selectedIconData;
  @override
  Widget get page => tab.page;
  @override
  Widget navDestination({ContextMenuOpener? onMenu}) =>
      tab.navDestination(onMenu: onMenu);
  @override
  NavigationRailDestination navRailDestination({ContextMenuOpener? onMenu}) =>
      tab.navRailDestination(onMenu: onMenu);
}

extension AppTabViewX on AppTab {
  Widget get page {
    return switch (this) {
      AppTab.server => const ServerPage(),
      AppTab.ssh => const SSHTabPage(),
      AppTab.file => const FileTabPage(),
      AppTab.snippet => const SnippetListPage(),
      AppTab.agent => const AgentPage(),
      AppTab.benchmark => const BenchmarkTabPage(),
      AppTab.pkg => const PkgTabPage(),
    };
  }

  /// The tab's mark. Also what a page *listing* tabs draws — the settings page
  /// that turns them on and reorders them.
  ///
  /// The names and the icons themselves are on [AppTab], so the feature
  /// registry can list a tab without reaching into `view/`.
  Widget get icon => Icon(iconData);

  /// The filled form, for the tab being looked at.
  Widget get selectedIcon => Icon(selectedIconData);

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
