import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/logo_url.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/core/utils/rootfs_manifest_source.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/geo_manifest.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/res/github_id.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/bmc_credential/list.dart';
import 'package:server_box/view/page/private_key/list.dart';
import 'package:server_box/view/page/server/connection_stats.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';
import 'package:server_box/view/page/setting/platform/desktop.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:server_box/view/page/setting/seq/known_hosts.dart';
import 'package:server_box/view/page/setting/seq/srv_orders.dart';
import 'package:server_box/view/page/setting/seq/virt_key.dart';
import 'package:server_box/view/widget/crash_debug.dart';
import 'package:server_box/view/widget/crash_report_dialog.dart';
import 'package:server_box/view/widget/diagnostics_level_picker.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/dmg_notice.dart';
import 'package:server_box/view/widget/geo_data_install.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/rootfs_install.dart';
import 'package:server_box/view/widget/server_share.dart';

part 'about.dart';
part 'menu.dart';
part 'entries/ai.dart';
part 'entries/app.dart';
part 'entries/container.dart';
part 'entries/editor.dart';
part 'entries/full_screen.dart';
part 'entries/globe.dart';
part 'entries/linux.dart';
part 'entries/server.dart';
part 'entries/sftp.dart';
part 'entries/ssh.dart';

const _kIconSize = 23.0;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const route = AppRouteNoArg(page: SettingsPage.new, path: '/settings');

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

// `_kMenuWidth` was here, at 232. The menu is laid out by `AdaptivePanes`
// now and takes the width every other list column in the app has — the one the
// user drags, stored in `paneListWidth`.

/// How wide the content beside that menu is allowed to get.
///
/// Left to fill a desktop window, a settings row put its label against one
/// edge and its control against the other, a hand's width apart, and stopped
/// reading as one thing. Two [PageColumns] columns' worth stops that without
/// making the pane a narrow strip in the middle of a wide window — and it is
/// also what lets the pages here that are a grid rather than a list keep two
/// columns.
const _kContentMaxWidth = 900.0;

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// Which branches are open in the wide menu. Nothing to start with, so it
  /// opens as a list of subjects rather than as everything there is.
  final _expanded = <String>{};

  /// Which branch the narrow tabs are inside, innermost last.
  ///
  /// The wide menu shows every level at once and needs no such thing; the tabs
  /// show one level and walk between them. Both read the same tree, and both
  /// point at the same [_selectedId].
  final _path = <SettingsNode>[];

  String? _selectedId;

  /// A wide window has to be showing something from the start, so it opens on
  /// the first group with its branch unfolded. A narrow one opens on the list
  /// and [_path] stays empty until a row is picked.
  @override
  void initState() {
    super.initState();
    final first = _buildNodes().firstWhereOrNull((e) => !e.isLeaf);
    if (first == null) return;
    _expanded.add(first.id);
    _selectedId = first.firstLeaf?.id;
  }

  Future<void> _clearAllSettings() async {
    try {
      if (!await SettingStore.instance.clear()) {
        Toast.error(libL10n.fail);
        return;
      }
      Toast.success(libL10n.success);
    } catch (e, s) {
      Loggers.app.warning('Failed to clear settings', e, s);
      Toast.error(libL10n.fail);
    }
  }

  /// The menu, built here because every title comes from the l10n of the
  /// moment. A group with settings of its own carries them in a leaf under
  /// itself, so that opening a branch and showing a page stay separate.
  List<SettingsNode> _buildNodes() {
    return [
      // Grouped by what a setting belongs to, using the same names the app's
      // own tabs do — so "is SFTP under connections or under files" is not a
      // question anyone has to answer. Two levels throughout: a third made
      // reaching a page two taps of guessing.
      SettingsNode.branch(
        id: 'app',
        title: libL10n.app,
        icon: Icons.tune,
        children: [
          SettingsNode.leaf(
            id: 'app.setting',
            title: libL10n.general,
            icon: Icons.settings_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.app),
          ),
          SettingsNode.leaf(
            id: 'app.privacy',
            title: l10n.privacy,
            icon: Icons.privacy_tip_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.privacy),
          ),
          SettingsNode.leaf(
            id: 'app.ai',
            title: libL10n.ai,
            icon: Icons.auto_awesome_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.ai),
          ),
          // A tab of its own rather than a row leading out of the general
          // page: pushed from there it drew a second title bar under the one
          // this page already has, naming the same thing twice.
          SettingsNode.leaf(
            id: 'app.homeTabs',
            title: l10n.homeTabs,
            icon: Icons.tab_outlined,
            page: () => const HomeTabsConfigPage(embedded: true),
          ),
          if (isIOS)
            SettingsNode.leaf(
              id: 'app.ios',
              title: 'iOS',
              icon: MingCute.apple_fill,
              page: () => const IosSettingsPage(embedded: true),
            ),
          // Named after the desktop it is running on, like the iOS page above:
          // what is in there is about the platform rather than about the app.
          if (isDesktop)
            SettingsNode.leaf(
              id: 'app.desktop',
              title: DesktopSettingsPage.platformName,
              icon: DesktopSettingsPage.platformIcon,
              page: () => const DesktopSettingsPage(embedded: true),
            ),

          /// Fullscreen Mode is designed for old mobile phone which can be
          /// used as a status screen.
          if (isMobile)
            SettingsNode.leaf(
              id: 'app.fullScreen',
              title: l10n.fullScreen,
              icon: Icons.fullscreen,
              page: () =>
                  const AppSettingsPage(section: SettingsSection.fullScreen),
            ),
        ],
      ),
      SettingsNode.branch(
        id: 'server',
        title: libL10n.server,
        icon: Icons.dns_outlined,
        children: [
          SettingsNode.leaf(
            id: 'server.setting',
            title: libL10n.general,
            icon: Icons.settings_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.server),
          ),
          // One row for all three orderings. Apart they read alike — the row
          // could not say which list it opened — and side by side as tabs each
          // is named by what the other two are not.
          SettingsNode.leaf(
            id: 'server.order',
            title: libL10n.sequence,
            icon: Icons.sort,
            page: () => const ServerOrdersPage(embedded: true),
          ),
        ],
      ),
      SettingsNode.branch(
        id: 'terminal',
        title: libL10n.terminal,
        icon: Icons.terminal,
        children: [
          SettingsNode.leaf(
            id: 'terminal.setting',
            title: libL10n.general,
            icon: Icons.settings_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.ssh),
          ),
          // Under the terminal because that is where a Linux system is
          // reached from, and absent when this build carries none — the same
          // question the terminal's own tab asks before it offers to install
          // one. Named for Linux rather than for the distribution: which one
          // is installed is allowed to change, and none of what is on that
          // page is about which.
          if (Rootfs.isAvailable)
            SettingsNode.leaf(
              id: 'terminal.linux',
              // Not localized, and not searched for either: the id above is
              // what the settings search matches on, and "Linux" is the same
              // word in every locale this ships in.
              title: 'Linux (Beta)',
              icon: Icons.layers_outlined,
              page: () => const AppSettingsPage(section: SettingsSection.linux),
            ),
          SettingsNode.leaf(
            id: 'terminal.knownHosts',
            title: l10n.sshKnownHostKeys,
            icon: Icons.verified_user_outlined,
            page: () => const KnownHostsPage(embedded: true),
          ),
          SettingsNode.leaf(
            id: 'terminal.virtKey',
            title: l10n.editVirtKeys,
            icon: Icons.keyboard_outlined,
            page: () => const SSHVirtKeySettingPage(embedded: true),
          ),
        ],
      ),
      SettingsNode.branch(
        id: 'file',
        title: libL10n.file,
        icon: Icons.folder_outlined,
        children: [
          SettingsNode.leaf(
            id: 'file.sftp',
            title: 'SFTP',
            icon: Icons.cloud_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.sftp),
          ),
          // Under files rather than under the app: it is what opens one.
          SettingsNode.leaf(
            id: 'file.editor',
            title: libL10n.editor,
            icon: Icons.edit_note,
            page: () => const AppSettingsPage(section: SettingsSection.editor),
          ),
        ],
      ),
      SettingsNode.leaf(
        id: 'container',
        title: libL10n.container,
        icon: Icons.inbox_outlined,
        page: () => const AppSettingsPage(section: SettingsSection.container),
      ),
      SettingsNode.branch(
        id: 'backup',
        title: libL10n.backup,
        icon: Icons.backup_outlined,
        children: [
          SettingsNode.leaf(
            id: 'backup.sync',
            title: libL10n.sync,
            icon: Icons.cloud_sync_outlined,
            page: () => const BackupPage(section: BackupSection.sync),
          ),
          SettingsNode.leaf(
            id: 'backup.import',
            title: libL10n.import,
            icon: Icons.file_download_outlined,
            page: () => const BackupPage(section: BackupSection.import),
          ),
        ],
      ),
      SettingsNode.leaf(
        id: 'privateKey',
        title: l10n.privateKey,
        icon: Icons.key_outlined,
        page: () => const PrivateKeysListPage(),
      ),
      SettingsNode.leaf(
        id: 'bmcCredential',
        title: l10n.bmcAccounts,
        icon: Icons.developer_board,
        page: () => const BmcCredentialsListPage(),
      ),
      SettingsNode.leaf(
        id: 'about',
        title: libL10n.about,
        icon: Icons.info_outline,
        page: () => const _AppAboutPage(),
      ),
    ];
  }

  void _onSelect(SettingsNode node) {
    _dropPushedPages();
    setState(() => _selectedId = node.id);
  }

  void _onToggle(SettingsNode node) {
    setState(() {
      if (!_expanded.remove(node.id)) _expanded.add(node.id);
    });
  }

  /// The navigator holding the right-hand side, so a selection can reach it.
  final _contentNav = GlobalKey<NavigatorState>();

  /// Discards anything pushed on top of the levels [_path] describes.
  ///
  /// The content navigator is driven declaratively — the pages come from the
  /// selection — but a page inside it may push a route by hand: the raw
  /// settings editor does, from `entries/app.dart`. A pushed route sits above
  /// every declarative page, so changing the selection rebuilt the pages
  /// underneath one and left it on screen. Tapping the menu looked like it did
  /// nothing at all, and the editor stayed put whichever section was picked.
  ///
  /// `route.settings is Page` is what tells the two apart: the declarative ones
  /// each come from a `MaterialPage`, and a hand-pushed one does not.
  void _dropPushedPages() {
    final nav = _contentNav.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.settings is Page);
  }

  /// A tab is a tab: it shows something. Tapping a branch goes into it *and*
  /// selects what is first inside, rather than leaving a row of tabs with none
  /// of them on. The same applies to a row of the list.
  void _onTab(SettingsNode node) {
    _dropPushedPages();
    setState(() {
      if (node.isLeaf && _path.isNotEmpty) {
        _selectedId = node.id;
        return;
      }
      _path.add(node);
      // Unfolded in the wide menu too. The two navigations share [_selectedId]
      // but not their shape, and only the menu's own toggle used to write here
      // — so a branch entered while narrow was still folded if the window then
      // grew, leaving the page on screen with no row anywhere pointing at it.
      _expanded.add(node.id);
      final leaf = node.firstLeaf;
      if (leaf != null) _selectedId = leaf.id;
    });
  }

  /// Out one level. What was selected stays selected — it is inside the branch
  /// just left, and that branch is a tab here, lit to say so.
  void _onTabBack() {
    if (_path.isEmpty) return;
    // The back button lives in the `Scaffold`'s app bar, outside the content
    // navigator — so with the raw editor pushed on top it is still visible and
    // still tappable, and rebuilding the pages underneath would leave the
    // editor on screen describing a level that is no longer showing.
    _dropPushedPages();
    setState(_path.removeLast);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _buildNodes();
    final leaves = [
      for (final node in nodes) ...node.flattened.where((e) => e.isLeaf),
    ];
    // Falls back rather than asserts: a node can go away between builds — the
    // fullscreen one does, on a window that stops being narrow.
    final selected = leaves.firstWhereOrNull((e) => e.id == _selectedId) ?? leaves.first;

    final menu = _SettingsMenu(
      nodes: nodes,
      selectedId: selected.id,
      expandedIds: _expanded,
      onSelect: _onSelect,
      onToggle: _onToggle,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The width `AdaptivePanes` splits at, so that a window wide enough for
        // two columns gets two columns here as well.
        final wide = constraints.maxWidth >= AdaptivePanes.kSplitWidth;
        return _buildScaffold(
          wide: wide,
          menu: menu,
          nodes: nodes,
          selected: selected,
        );
      },
    );
  }

  /// The leaves beside [id] — the ones its own level holds.
  static List<SettingsNode>? _groupOf(List<SettingsNode> level, String id) {
    final leaves = level.where((e) => e.isLeaf).toList();
    if (leaves.any((e) => e.id == id)) return leaves;
    for (final node in level) {
      if (node.children.isEmpty) continue;
      final found = _groupOf(node.children, id);
      if (found != null) return found;
    }
    return null;
  }

  /// The level [node] leads to: what is inside a branch, and a leaf alone.
  ///
  /// A leaf on its own gets no tabs. There is one page and nothing to move
  /// between, and a bar with a single tab on it says only what the title bar
  /// above it already said.
  static List<SettingsNode> _levelOf(SettingsNode node) {
    return node.isLeaf ? [node] : node.children;
  }

  Widget _buildScaffold({
    required bool wide,
    required Widget menu,
    required List<SettingsNode> nodes,
    required SettingsNode selected,
  }) {
    final content = _buildContent(wide: wide, nodes: nodes, selected: selected);

    return Scaffold(
      // The one bar the page has, naming whatever is being shown. The pages in
      // it are given `embedded: true` and drop their own.
      appBar: CustomAppBar(
        // The list names itself; everything else is named by what it shows.
        title: Text(
          !wide && _path.isEmpty ? libL10n.setting : selected.title,
          style: const TextStyle(fontSize: 20),
        ),
        // Out of the level rather than out of the settings, while there is a
        // level to leave. A leaf shown on its own has no tabs and so no other
        // way back to the list.
        leading: !wide && _path.isNotEmpty
            ? BackButton(onPressed: _onTabBack)
            : null,
        actions: [
          // `kDebugMode` is a const, so this and everything it reaches is tree
          // shaken out of a release rather than shipped and hidden.
          if (kDebugMode)
            Btn.text(
              text: 'Crash',
              onTap: () => CrashDebugMenu.show(context),
            ),
          Btn.text(
            text: context.libL10n.logs,
            onTap: () => DebugPage.route.go(
              context,
              args: DebugPageArgs(
                title: '${context.libL10n.logs}(${BuildData.build})',
              ),
            ),
          ),
          Btn.icon(text: libL10n.delete, 
            icon: const Icon(Icons.delete),
            onTap: () => context.showRoundDialog(
              title: libL10n.attention,
              child: SimpleMarkdown(
                data: libL10n.askContinue(
                  '${libL10n.delete} **${libL10n.all}** ${libL10n.setting}',
                ),
              ),
              actions: [
                CountDownBtn(
                  onTap: () {
                    context.popDialog();
                    _clearAllSettings();
                  },
                  afterColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
      // The same column every other list-beside-content page has, rather than
      // a `Row` of its own. It used to be one, at a fixed 232 and with a plain
      // divider — so this was the one such column in the app that could not be
      // resized and, once folding arrived, the one that could not be folded.
      // Nothing about a menu of settings makes it a different kind of column.
      //
      // `minWidthForSide: 0` hands the decision to [wide], which is read from
      // the `LayoutBuilder` above and is what the app bar and the content are
      // already built from. Left to decide for itself it would be measuring
      // inside the `SafeArea` — a few points narrower — and a window sitting
      // on the breakpoint would get a title naming a page the layout was not
      // showing.
      body: SafeArea(
        child: PaneSettings.listenAll(
          (paneWidth, paneCollapsed) => AdaptivePanes.surface(
            enabled: wide,
            minWidthForSplit: 0,
            listWidth: paneWidth,
            onListWidthChanged: PaneSettings.saveWidth,
            collapsed: paneCollapsed,
            onCollapsedChanged: PaneSettings.saveCollapsed,
            collapseTooltip: libL10n.fold,
            expandTooltip: libL10n.open,
            listBuilder: (_, _) => menu,
            // A `Builder` so the insets read below are the ones this body
            // actually has: the state's own context is above the `Scaffold`,
            // where `padding` is still the whole window's — the status bar the
            // app bar already covers, and the home indicator the `SafeArea`
            // just above here already cleared.
            surfaceBuilder: (ctx, split) => split
                ? content
                : Builder(
                    builder: (ctx) => _buildNarrow(ctx, nodes, content),
                  ),
          ),
        ),
      ),
    );
  }

  /// The levels, as pages of a navigator.
  ///
  /// Declarative rather than pushed by hand: [_path] already says which levels
  /// are open, and letting the navigator read it means the two cannot disagree.
  /// A level arriving or leaving the list is a `MaterialPage` doing so, which is
  /// where the transition comes from.
  Widget _buildContent({
    required bool wide,
    required List<SettingsNode> nodes,
    required SettingsNode selected,
  }) {
    // A route sliding in has to be opaque, or what it is covering shows
    // through it for the length of the transition. The pages under here are
    // `embedded: true` and drop their own `Scaffold`, so without this nothing
    // gives them a background at all — the one behind belongs to the
    // `Scaffold` this whole page is in, and both routes were letting it, and
    // each other, through.
    //
    // The `Scaffold`'s colour and not `colorScheme.surface`: that is the slot
    // `toAmoled` overrides, and the surface one it leaves alone.
    // The cap goes on what is *in* the page, never on the page. A route
    // sliding in is as wide as the pane; a navigator inside a narrower box
    // slides the whole transition inside that box, so the page appeared to
    // come out of a panel in the middle rather than in from the edge.
    //
    // The `Material` stays full width for the same reason — it is the
    // background the transition is drawn against.
    Widget opaque(Widget child) => Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      // Told to expand inside the cap: a `Center` hands down loose
      // constraints, under which a page's list takes the height of its
      // content rather than the height of the pane.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
          child: SizedBox.expand(child: child),
        ),
      ),
    );

    /// Keyed by the group it shows, never by what is selected inside it.
    ///
    /// Selecting is what a drag *does*: `onPageChanged` fires mid-settle and
    /// changes the selection, so a key naming the selection made every swipe
    /// throw away the state — and with it the `PageController` — that the
    /// settle was running on. It reappeared at the new page with the movement
    /// cut off, which is the swipe not feeling like a swipe.
    Widget pagesOf(List<SettingsNode> level) {
      final leaves = level.where((e) => e.isLeaf).toList();
      return _SettingsPages(
        key: ValueKey('pages_${leaves.firstOrNull?.id ?? 'none'}'),
        leaves: leaves,
        selectedId: selected.id,
        onChanged: _onSelect,
      );
    }

    final navigator = Navigator(
      key: _contentNav,
      pages: [
        if (wide)
          MaterialPage<void>(
            key: ValueKey(_groupOf(nodes, selected.id)?.firstOrNull?.id ?? 'root'),
            child: opaque(pagesOf(_groupOf(nodes, selected.id) ?? const [])),
          )
        else ...[
          // What settings there are, which is where a narrow window starts.
          MaterialPage<void>(
            key: const ValueKey('root'),
            child: opaque(_SettingsList(nodes: nodes, onTap: _onTab)),
          ),
          for (final entered in _path)
            MaterialPage<void>(
              key: ValueKey(entered.id),
              child: opaque(pagesOf(_levelOf(entered))),
            ),
        ],
      ],
      onDidRemovePage: (page) {
        // A page can also go because the system back gesture took it. What the
        // tabs show comes from [_path], so it has to hear about that.
        if (_path.isEmpty) return;
        if ((page.key as ValueKey?)?.value == _path.last.id) {
          setState(_path.removeLast);
        }
      },
    );

    // Platform back belongs to this stack while it has somewhere to go. Without
    // a pop handler the enclosing navigator removes the whole settings route,
    // skipping whichever level or manually pushed page is currently on top.
    return NavigatorPopHandler(
      onPopWithResult: (_) => _contentNav.currentState?.pop(),
      child: navigator,
    );
  }

  /// The content with the tabs floating over its foot.
  ///
  /// The content fills the body and the bar sits over it, so what is on the page
  /// carries on under the bar instead of stopping at a bare strip above it. The
  /// room a list needs to bring its last row into the clear arrives as
  /// [MediaQuery] padding, which `context.padBottom` puts on the scrollable —
  /// padding a list can scroll through, rather than a strip taken out of the
  /// page's box.
  ///
  /// [context] has to be one from inside the body — see where this is called.
  Widget _buildNarrow(
    BuildContext context,
    List<SettingsNode> nodes,
    Widget content,
  ) {
    final mediaQuery = MediaQuery.of(context);
    // Nothing over the list — a bar of tabs there would be the same names
    // twice — and nothing over a leaf, which has no level under it to show.
    final entered = _path.lastOrNull;
    final level = entered == null || entered.isLeaf ? null : entered;
    final space = level == null ? 0.0 : _kTabsHeight + _kTabsMargin * 2;

    return Stack(
      // Nothing here should reach past the floor of this box — the page is
      // pushed into the home tab's navigator, and the `Scaffold` paints its
      // bottom bar after the body, so anything that does is covered rather than
      // shown. `none` only keeps the clip from being what cuts it: the bar
      // carries its own margin, so it stops short of the floor on its own.
      clipBehavior: Clip.none,
      children: [
        MediaQuery(
          data: mediaQuery.copyWith(
            padding: mediaQuery.padding.copyWith(
              bottom: mediaQuery.padding.bottom + space,
            ),
          ),
          child: content,
        ),
        // Edge to edge, and the bar centres itself within that: it is as wide
        // as the level it is showing, and only scrolls when that is too wide.
        //
        // Flush with the floor, because the gap the bar stands in is padding
        // inside it now. Lifting it from here as well would move it up by that
        // much again, and put the shadow back outside the clip it just left.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: Durations.medium2,
            // Springs up past its place and settles, as displacement does
            // elsewhere. No fade with it: the curve overshoots, and an opacity
            // past 1 asserts.
            switchInCurve: _kTabsCurve,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(
                // Far enough to take the shadow with it.
                begin: const Offset(0, 1.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
            child: level == null
                ? const SizedBox(key: ValueKey('no_tabs'), width: double.infinity)
                : _SettingsTabs(
                    key: ValueKey(level.id),
                    nodes: _levelOf(level),
                    selectedId: _selectedId,
                    onTap: _onTab,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Which group of settings [AppSettingsPage] is showing.
///
/// One page rather than one per group, so that the state — and the four text
/// controllers on it — survives moving between them.
enum SettingsSection {
  app,
  privacy,
  ai,
  server,
  ssh,
  linux,
  sftp,
  container,
  editor,
  fullScreen,
}

final class AppSettingsPage extends ConsumerStatefulWidget {
  final SettingsSection section;

  const AppSettingsPage({super.key, required this.section});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  final _setting = Stores.setting;

  /// The kept crash report, read once — see `_buildLastCrashReport`. Null
  /// again after it is dropped, which is what makes the row disappear.
  Future<String?>? _savedCrashReport;

  late final _sshOpacityCtrl = TextEditingController(
    text: _setting.sshBgOpacity.fetch().toString(),
  );
  late final _sshBlurCtrl = TextEditingController(
    text: _setting.sshBlurRadius.fetch().toString(),
  );
  late final _textScalerCtrl = TextEditingController(
    // `.fetch()`, as the three above: without it the field opened showing
    // `Instance of 'SqlitePropDefault<double>'` and handed that to be parsed.
    text: _setting.textFactor.fetch().toString(),
  );
  late final _serverLogoCtrl = TextEditingController(
    text: _setting.serverLogoUrl.fetch(),
  );
  late final _serverMarkCtrl = TextEditingController(
    text: _setting.serverMarkUrl.fetch(),
  );

  @override
  void initState() {
    super.initState();
    // Which releases are installable is fetched rather than compiled in, and
    // this page is where someone is about to act on the answer: the version
    // beside "add", the update button on a profile. Launch already tries once;
    // this catches the case where it failed or the release moved since.
    //
    // Not awaited and not shown. What is in force already works, and a refresh
    // that changes nothing — the ordinary case — should look like nothing.
    if (widget.section == SettingsSection.linux && Rootfs.isAvailable) {
      RootfsManifestSource.refresh().then((changed) {
        if (changed && mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _sshOpacityCtrl.dispose();
    _sshBlurCtrl.dispose();
    _textScalerCtrl.dispose();
    _serverLogoCtrl.dispose();
    _serverMarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No heading over it: the menu says which group this is, and the bar above
    // repeats it. A `CenterGreyTitle` here would be the third time.
    final group = switch (widget.section) {
      SettingsSection.app => _buildApp(),
      SettingsSection.privacy => _buildPrivacy(),
      SettingsSection.ai => _buildAskAiConfig(),
      SettingsSection.server => _buildServer(),
      SettingsSection.ssh => _buildSSH(),
      SettingsSection.linux => _buildLinux(),
      SettingsSection.sftp => _buildSFTP(),
      SettingsSection.container => _buildContainer(),
      SettingsSection.editor => _buildEditor(),
      SettingsSection.fullScreen => _buildFullScreen(),
    };

    return ListView(
      padding: context.padBottom(UIs.roundRectCardPadding),
      children: [group],
    );
  }

  /// Redraws after something a listenable does not cover.
  ///
  /// The Linux page reads `Rootfs.profiles`, which is built by scanning a
  /// directory rather than from a store key, so nothing notifies when an
  /// install or a removal changes it.
  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> showTextSettingDialog({
    required String title,
    required String initialValue,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onSave,
    bool suggestion = false,
  }) {
    return Future<void>.sync(
      () => withTextFieldController((ctrl) async {
        ctrl.text = initialValue;

        void save() {
          onSave(ctrl.text.trim());
          context.popDialog();
        }

        await context.showRoundDialog<bool>(
          title: title,
          child: Input(
            controller: ctrl,
            autoFocus: true,
            label: label,
            hint: hint,
            icon: icon,
            suggestion: suggestion,
            onSubmitted: (_) => save(),
          ),
          actions: Btn.ok(onTap: save).toList,
        );
      }),
    );
  }
}

