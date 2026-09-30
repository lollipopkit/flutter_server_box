import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/agent/agent.dart';
import 'package:server_box/view/page/benchmark/tab.dart';
import 'package:server_box/view/page/remote_desktop/tab.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/snippet/list.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/page/storage/tab.dart';
import 'package:server_box/view/page/virt/tab.dart';
import 'package:server_box/view/widget/conn_count_badge.dart';
import 'package:server_box/view/widget/marked_title.dart';
import 'package:server_box/view/widget/nav_rail.dart';

extension AppTabViewX on AppTab {
  Widget get page {
    return switch (this) {
      AppTab.server => const ServerPage(),
      AppTab.ssh => const SSHTabPage(),
      AppTab.file => const FileTabPage(),
      AppTab.snippet => const SnippetListPage(),
      AppTab.agent => const AgentPage(),
      AppTab.benchmark => const BenchmarkTabPage(),
      AppTab.remoteDesktop => const RemoteDesktopTabPage(),
      AppTab.virt => const VirtTabPage(),
    };
  }

  /// The tab's mark. Also what a page *listing* tabs draws — the settings page
  /// that turns them on and reorders them.
  Widget get icon {
    return _AppTabIcon(tab: this, selected: false);
  }

  /// The filled form, for the tab being looked at.
  Widget get selectedIcon {
    return _AppTabIcon(tab: this, selected: true);
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
      AppTab.remoteDesktop => l10n.remoteDesktop,
      AppTab.virt => l10n.virtualization,
    };
  }

  /// Whether the tab is still in beta.
  // TODO: move to the Feature abstraction (next PR).
  bool get beta => switch (this) {
    AppTab.remoteDesktop || AppTab.agent || AppTab.benchmark || AppTab.virt =>
      true,
    _ => false,
  };

  /// The mark a tab carries, where the tab is *listed* — the settings page
  /// that arranges them, and the sheet the bar opens for the ones it cannot
  /// hold — and after its name in the open rail ([navRailItem]). The bottom
  /// bar, whose label is mostly hidden, carries it on the pill's corner while
  /// the tab is selected.
  Widget? get mark => beta ? const BetaTag() : null;

  /// [label] with [mark], for a row that lists the tab rather than opening it.
  Widget get listTitle {
    final mark_ = mark;
    if (mark_ == null) return Text(label);
    return MarkedTitle(label, mark: mark_);
  }

  /// The tab in the rail and the bottom bar.
  ///
  /// The count is not wrapped round the icon here: [AppNavRail] hangs it off
  /// the indicator's corner instead, clear of the glyph. The menu is not
  /// wrapped either — the rail carries it on the whole item, so a long press
  /// on the label reaches it too.
  NavRailItem navRailItem({ContextMenuOpener? onMenu}) {
    return NavRailItem(
      icon: _railIcon(icon),
      selectedIcon: _railIcon(selectedIcon),
      label: label,
      badge: this == AppTab.server
          ? (opacity) => ConnCountRailBadge(opacity: opacity)
          : null,
      mark: beta ? (opacity) => BetaTag(opacity: opacity) : null,
      onMenu: onMenu,
    );
  }

  Widget _railIcon(Widget icon) {
    if (this != AppTab.agent) return icon;
    return SizedBox.square(
      dimension: NavRailMetrics.iconSize,
      child: Center(
        child: IconTheme.merge(
          data: const IconThemeData(size: 22),
          child: icon,
        ),
      ),
    );
  }
}

class _AppTabIcon extends StatelessWidget {
  const _AppTabIcon({required this.tab, required this.selected});

  final AppTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Stores.setting.appIconStyle.listenable(),
        ThemePackages.preview,
      ]),
      builder: (context, _) {
        final mingcute =
            (ThemePackages.preview.value?.iconStyle ??
                Stores.setting.appIconStyle.fetch()) ==
            IconStyle.mingcute;
        final icon = mingcute
            ? switch (tab) {
                AppTab.server =>
                  selected ? MingCute.server_fill : MingCute.server_line,
                AppTab.ssh =>
                  selected ? MingCute.terminal_fill : MingCute.terminal_line,
                AppTab.file =>
                  selected
                      ? MingCute.folder_open_fill
                      : MingCute.folder_open_line,
                AppTab.snippet =>
                  selected ? MingCute.code_fill : MingCute.code_line,
                AppTab.agent =>
                  selected ? MingCute.magic_2_fill : MingCute.magic_2_line,
                AppTab.benchmark =>
                  selected ? MingCute.dashboard_fill : MingCute.dashboard_line,
                AppTab.remoteDesktop =>
                  selected ? MingCute.computer_fill : MingCute.computer_line,
                AppTab.virt =>
                  selected ? MingCute.box_3_fill : MingCute.box_3_line,
              }
            : switch (tab) {
                AppTab.server =>
                  selected ? BoxIcons.bxs_server : BoxIcons.bx_server,
                AppTab.ssh =>
                  selected ? Icons.terminal : Icons.terminal_outlined,
                AppTab.file => selected ? Icons.folder : Icons.folder_open,
                AppTab.snippet => selected ? Icons.code : Icons.code_outlined,
                AppTab.agent =>
                  selected ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                AppTab.benchmark =>
                  selected ? Icons.speed : Icons.speed_outlined,
                AppTab.remoteDesktop =>
                  selected
                      ? Icons.desktop_windows
                      : Icons.desktop_windows_outlined,
                AppTab.virt =>
                  selected ? Icons.view_in_ar : Icons.view_in_ar_outlined,
              };
        return ThemeIconAsset(
          keyName: ThemeIcons.tabKey(tab.name, selected: selected),
          fallback: Icon(icon),
        );
      },
    );
  }
}
