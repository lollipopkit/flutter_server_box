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
import 'package:flutter/services.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/diag.dart';
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
import 'package:server_box/data/model/ai/model_context.dart';
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
import 'package:server_box/view/widget/edge_fade_scroll.dart';
import 'package:server_box/view/widget/geo_data_install.dart';
import 'package:server_box/view/widget/group_title.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/progress_line.dart';
import 'package:server_box/view/widget/rootfs_install.dart';

part 'about.dart';
part 'group.dart';
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
///
/// Written as the grid's own arithmetic rather than as a number, so that the
/// form inside really does get its second column: a cap a few points under
/// this one leaves [PageColumns] measuring room for one and laying the whole
/// form out in a single column the width of two.
final _kContentMaxWidth = PageColumns.widthFor(
  2,
  padding: _kGridPadding,
  spacing: _kGridSpacing,
);

/// What the form is spaced by, which is the design's 17 minus what a `CardX`
/// already carries: a `Card` brings a margin of 4 on every side, so 13 here is
/// 17 on screen at the edges and 9 between two columns is 17 between them.
const _kGridPadding = EdgeInsets.all(13);
const _kGridSpacing = 9.0;

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// Which branch the narrow tabs are inside, innermost last.
  ///
  /// The wide menu is one flat column of subjects and needs no such thing —
  /// what is inside the one being read is a row of tabs over the content. The
  /// tabs show one level and walk between them. Both read the same tree, and
  /// both point at the same [_selectedId].
  final _path = <SettingsNode>[];

  String? _selectedId;

  /// What the search field holds, trimmed. Empty is the ordinary state.
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  bool get _searching => _query.isNotEmpty;

  /// A wide window has to be showing something from the start, so it opens on
  /// the first page there is. A narrow one opens on the list and [_path] stays
  /// empty until a row is picked.
  @override
  void initState() {
    super.initState();
    _selectedId = _buildNodes().firstOrNull?.firstLeaf?.id;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _clearAllSettings() async {
    try {
      if (!await Stores.setting.clear()) {
        Toast.error(libL10n.fail);
        return;
      }
      RNodes.app.notify();
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

  /// A row of the flat menu, which names a subject rather than a page.
  ///
  /// Picking one shows what is first inside it; the rest of what it holds is
  /// the row of tabs over the content.
  void _onMenuTap(SettingsNode node) {
    final leaf = node.firstLeaf;
    if (leaf != null) _onSelect(leaf);
  }

  void _onSearch(String value) {
    final query = value.trim();
    if (query == _query) return;
    setState(() {
      _query = query;
      // A narrow window shows the results where the list is, which is the
      // root — so a search started there cannot leave a level open under it.
      if (query.isNotEmpty) _path.clear();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _onSearch('');
  }

  /// Every page whose own name, the subject it is under, or the id the code
  /// knows it by carries [query].
  ///
  /// The id is matched deliberately. Three pages are called "General" and
  /// `app.setting` is what tells them apart; it is also the only thing that
  /// answers an untranslated word — `privacy`, `sftp` — in a locale that
  /// spells the title differently.
  List<SettingsHit> _hits(List<SettingsNode> nodes) {
    final needle = _query.toLowerCase();
    bool matches(SettingsNode leaf, SettingsNode? parent) =>
        leaf.title.toLowerCase().contains(needle) ||
        leaf.id.toLowerCase().contains(needle) ||
        (parent?.title.toLowerCase().contains(needle) ?? false);

    final hits = <SettingsHit>[];
    for (final node in nodes) {
      if (node.isLeaf) {
        if (matches(node, null)) hits.add(SettingsHit(leaf: node));
        continue;
      }
      for (final child in node.children) {
        if (child.isLeaf && matches(child, node)) {
          hits.add(SettingsHit(leaf: child, parent: node));
        }
      }
    }
    return hits;
  }

  /// Goes to what was found, and drops the search on the way.
  ///
  /// The search is a way *to* a page, not a place — leaving it up behind the
  /// page it just opened would mean two things on screen claiming to be what
  /// the content is showing.
  void _onHit(SettingsHit hit) {
    _dropPushedPages();
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _selectedId = hit.leaf.id;
      // Where the narrow tabs have to be for the page to be on screen: inside
      // its subject, or on the page itself when it has no subject over it.
      _path
        ..clear()
        ..add(hit.parent ?? hit.leaf);
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
    final selected =
        leaves.firstWhereOrNull((e) => e.id == _selectedId) ?? leaves.first;

    final hits = _searching ? _hits(nodes) : const <SettingsHit>[];

    final menu = _SettingsMenu(
      nodes: nodes,
      selectedId: selected.id,
      onSelect: _onMenuTap,
      search: _buildSearchField(),
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
          hits: hits,
        );
      },
    );
  }

  /// The subject [id] is under, and null for a page that is its own subject.
  static SettingsNode? _branchOf(List<SettingsNode> nodes, String id) {
    for (final node in nodes) {
      if (node.isLeaf) continue;
      if (node.children.any((e) => e.id == id)) return node;
    }
    return null;
  }

  /// The pages shown beside the one selected: what its subject holds, or it
  /// alone.
  ///
  /// A top-level page gets no tabs. It used to be given the other top-level
  /// pages as siblings — Container, Private key, BMC accounts and About in one
  /// row — which is the menu's job and not a level's.
  static List<SettingsNode> _levelFor(List<SettingsNode> nodes, String id) {
    final branch = _branchOf(nodes, id);
    if (branch != null) return branch.children.where((e) => e.isLeaf).toList();
    final leaf = nodes.firstWhereOrNull((e) => e.isLeaf && e.id == id);
    return leaf == null ? const [] : [leaf];
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
    required List<SettingsHit> hits,
  }) {
    // What the search found, built here because both layouts need it and
    // neither may build the other's: only one of the two is in the tree.
    //
    // Drawn by [AppSettingsPage] rather than by this page, because what it
    // looks through is the rows that page builds — and it draws them as they
    // are drawn on their own page, so a switch found by searching is a switch.
    final results = _searching
        ? AppSettingsPage(
            // Ignored while searching, which looks at every section. It is
            // still the one this page would otherwise have been showing.
            section: SettingsSection.app,
            search: SettingsSearch(
              query: _query,
              pages: hits,
              onPage: _onHit,
            ),
          )
        : null;

    final content = _buildContent(
      wide: wide,
      nodes: nodes,
      selected: selected,
      results: results,
    );

    // The subject being read, and what else is in it. Its own row over the
    // content rather than the bar's title: the bar spans the menu column too,
    // and a row of tabs starting above the menu points at nothing there.
    final level = _levelFor(nodes, selected.id);
    final actions = _buildActions();
    final header = _SettingsContentHeader(
      title: _branchOf(nodes, selected.id)?.title ?? selected.title,
      nodes: level,
      selectedId: selected.id,
      onTap: _onSelect,
      actions: actions,
    );

    final scaffold = Scaffold(
      // None on a wide window. The menu says which subject, the header over
      // the content says which page and carries the two buttons that act on
      // the settings as a whole, and the settings are shown beside the rail
      // rather than over it — so a bar here named the page a third time and
      // spent 46 points saying it.
      //
      // A narrow one keeps it: there is no menu column beside the content to
      // name anything, and the way back out of a level is its button.
      appBar: wide
          ? null
          : CustomAppBar(
              // The list names itself; everything else is named by what it
              // shows.
              title: Text(
                // The count is a heading over the results, where the design
                // puts it — and it is one this page cannot work out anyway,
                // since most of what matched is rows rather than pages.
                _searching
                    ? libL10n.search
                    : (_path.isEmpty ? libL10n.setting : selected.title),
              ),
              // Out of the level rather than out of the settings, while there
              // is a level to leave. A leaf shown on its own has no tabs and
              // so no other way back to the list. A search is left the same
              // way, since on a narrow window it took the list's place.
              leading: _searching || _path.isNotEmpty
                  ? BackButton(
                      onPressed: _searching ? _clearSearch : _onTabBack,
                    )
                  : null,
              actions: actions,
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
                ? Column(
                    children: [
                      // Hidden rather than taken out of the tree: `Offstage`
                      // in a column takes no height, and a `Column` whose
                      // children come and go rebuilds what is under them —
                      // which here is the navigator, and rebuilding that is
                      // losing every page in it.
                      Offstage(offstage: _searching, child: header),
                      Expanded(
                        child: Stack(
                          children: [
                            // Still laid out under the results, which is what
                            // keeps the navigator and every page in it alive.
                            // Taken out of the focus chain though: Tab walking
                            // into a form nobody can see is the same bug as
                            // the caret leaving the field.
                            ExcludeFocus(excluding: _searching, child: content),
                            // Over the content rather than a page *of* it.
                            //
                            // As a page it was a route arriving, and a route
                            // arriving takes the focus — `ModalRoute.didPush`
                            // hands it to the new route's own scope. The field
                            // that put it there is in the menu column, outside
                            // this navigator, so the first character typed
                            // pushed a route and the field lost the caret.
                            if (results != null)
                              Positioned.fill(
                                // Faded in, because it arrives over a page
                                // that stays where it is: without it the first
                                // character typed replaced the form in one
                                // frame and read as the page having changed
                                // rather than as a search having started.
                                child: FadeIn(
                                  duration: Durations.short3,
                                  child: _opaque(
                                    ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        13,
                                        13,
                                        13,
                                        17,
                                      ),
                                      children: [results],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Builder(
                    builder: (ctx) => _buildNarrow(ctx, nodes, content),
                  ),
          ),
        ),
      ),
    );

    // The chord the field advertises, actually bound. `Focus` so the binding
    // has somewhere on this page to be reached from — `CallbackShortcuts`
    // reads the focus chain, and a page nobody has clicked in yet has nothing
    // on it. Traversal skipped, so Tab still walks the real controls.
    if (!isDesktop) return scaffold;
    return CallbackShortcuts(
      bindings: {_kSearchShortcut: _searchFocus.requestFocus},
      child: Focus(autofocus: true, skipTraversal: true, child: scaffold),
    );
  }

  /// What acts on the settings as a whole: the log, and clearing everything.
  List<Widget> _buildActions() {
    return [
      Btn.text(
        text: context.libL10n.logs,
        onTap: () => DebugPage.route.go(
          context,
          args: DebugPageArgs(
            title: '${context.libL10n.logs}(${BuildData.build})',
          ),
        ),
        // The crash menu, behind a long press on the button next to the thing
        // it is for, rather than a second button in a bar that is already four
        // wide.
        //
        // `kDebugMode` is a const, so a release does not register the gesture
        // and `CrashDebugMenu` — with everything it reaches — is tree shaken
        // out rather than shipped behind a gesture nobody is told about.
        onLongTap: kDebugMode ? () => CrashDebugMenu.show(context) : null,
      ),
      Btn.icon(
        text: libL10n.delete,
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
    ];
  }

  /// A background and the width cap, round whatever the content pane shows.
  ///
  /// A route sliding in has to be opaque, or what it is covering shows through
  /// it for the length of the transition. The pages under here are
  /// `embedded: true` and drop their own `Scaffold`, so without this nothing
  /// gives them a background at all — the one behind belongs to the `Scaffold`
  /// this whole page is in, and both routes were letting it, and each other,
  /// through.
  ///
  /// The `Scaffold`'s colour and not `colorScheme.surface`: that is the slot
  /// `toAmoled` overrides, and the surface one it leaves alone.
  ///
  /// The cap goes on what is *in* the page, never on the page. A route sliding
  /// in is as wide as the pane; a navigator inside a narrower box slides the
  /// whole transition inside that box, so the page appeared to come out of a
  /// panel in the middle rather than in from the edge. The `Material` stays
  /// full width for the same reason — it is the background the transition is
  /// drawn against.
  Widget _opaque(Widget child) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    // Told to expand inside the cap: a `Center` hands down loose constraints,
    // under which a page's list takes the height of its content rather than
    // the height of the pane.
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _kContentMaxWidth),
        child: SizedBox.expand(child: child),
      ),
    ),
  );

  Widget _buildSearchField() => _SettingsSearchField(
    controller: _searchCtrl,
    focusNode: _searchFocus,
    onChanged: _onSearch,
    onClear: _clearSearch,
  );

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
    required Widget? results,
  }) {
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

    final level = _levelFor(nodes, selected.id);

    final navigator = Navigator(
      key: _contentNav,
      pages: [
        if (wide)
          // Never keyed by the search: the results are drawn over this
          // navigator, not as a page of it — see where they are laid out.
          MaterialPage<void>(
            key: ValueKey(level.firstOrNull?.id ?? 'root'),
            child: _opaque(pagesOf(level)),
          )
        else ...[
          // What settings there are, which is where a narrow window starts.
          MaterialPage<void>(
            key: const ValueKey('root'),
            child: _opaque(
              _SettingsList(
                nodes: nodes,
                onTap: _onTab,
                search: _buildSearchField(),
                results: results,
              ),
            ),
          ),
          for (final entered in _path)
            MaterialPage<void>(
              key: ValueKey(entered.id),
              child: _opaque(pagesOf(_levelOf(entered))),
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
  fullScreen;

  /// What this group is called when it is a page of its own.
  ///
  /// The *subject's* name rather than the leaf's. Inside the settings the menu
  /// beside a group already says which subject you are in, so three of those
  /// leaves are called "General" — which on a page with nothing beside it names
  /// nothing at all.
  String get title => switch (this) {
    SettingsSection.app => libL10n.app,
    SettingsSection.privacy => l10n.privacy,
    SettingsSection.ai => libL10n.ai,
    SettingsSection.server => libL10n.server,
    SettingsSection.ssh => libL10n.terminal,
    // Not localized: the id is what the settings search matches on, and Linux
    // is the same word in every locale this ships in.
    SettingsSection.linux => 'Linux (Beta)',
    SettingsSection.sftp => 'SFTP',
    SettingsSection.container => libL10n.container,
    SettingsSection.editor => libL10n.editor,
    SettingsSection.fullScreen => l10n.fullScreen,
  };

  /// The page this group is, inside the subject it is under.
  ///
  /// What the search puts over a row it found: three of these pages are called
  /// "General", and the subject is the half that tells them apart.
  String get breadcrumb => switch (this) {
    SettingsSection.app => '${libL10n.app} › ${libL10n.general}',
    SettingsSection.privacy => '${libL10n.app} › ${l10n.privacy}',
    SettingsSection.ai => '${libL10n.app} › ${libL10n.ai}',
    SettingsSection.fullScreen => '${libL10n.app} › ${l10n.fullScreen}',
    SettingsSection.server => '${libL10n.server} › ${libL10n.general}',
    SettingsSection.ssh => '${libL10n.terminal} › ${libL10n.general}',
    SettingsSection.linux => '${libL10n.terminal} › Linux (Beta)',
    SettingsSection.sftp => '${libL10n.file} › SFTP',
    SettingsSection.editor => '${libL10n.file} › ${libL10n.editor}',
    SettingsSection.container => libL10n.container,
  };

  /// Whether this build has this group at all.
  ///
  /// The search walks every one of them, and a group the menu never offers is
  /// one whose rows cannot be reached from a result either.
  bool get available => switch (this) {
    SettingsSection.fullScreen => isMobile,
    SettingsSection.linux => Rootfs.isAvailable,
    _ => true,
  };
}

/// One settings group as a page of its own.
///
/// For the places outside the settings tree that lead into it — the terminal
/// tab's "add a Linux system" is the one there is.
///
/// A wrapper rather than an `embedded` flag on [AppSettingsPage], which is what
/// the three sibling pages in the menu use: that page is a group's rows and
/// nothing else, on nine call sites, because the settings' own layout supplies
/// the bar, the title and the surface. Pushed as a route it was a `ListView` on
/// an empty one — a black screen with settings on it.
final class SettingsSectionPage extends StatelessWidget {
  const SettingsSectionPage({super.key, required this.args});

  final SettingsSection args;

  /// A route rather than a `Navigator.push` written at the call site, and the
  /// difference is not bookkeeping: `AppRoute` decides *which* navigator the
  /// page lands on and puts the desktop window frame round it when that is the
  /// root one. On the nearest navigator — what a bare push finds — a page
  /// opened from a tab lands inside that tab, so the settings replaced the
  /// terminal's contents with the navigation still under them, and from the
  /// side bar beside the terminals they opened in that narrow column. A caller
  /// that means the whole window says [NavTarget.root].
  static const route = AppRouteArg<void, SettingsSection>(
    page: SettingsSectionPage.new,
    path: '/settings/section',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(args.title)),
      body: AppSettingsPage(section: args),
    );
  }
}

/// What the page shows instead of its own group while a search is on.
///
/// The search is rendered here and not beside the menu, because what it looks
/// through is the rows this page builds — and those are built from a state
/// with five text controllers on it, which nothing outside can construct.
final class SettingsSearch {
  const SettingsSearch({
    required this.query,
    required this.pages,
    required this.onPage,
  });

  final String query;

  /// Pages whose own names match, found by the menu rather than here.
  final List<SettingsHit> pages;

  final void Function(SettingsHit hit) onPage;
}

final class AppSettingsPage extends ConsumerStatefulWidget {
  final SettingsSection section;

  /// When set, every section's matching rows instead of this one's own.
  final SettingsSearch? search;

  const AppSettingsPage({super.key, required this.section, this.search});

  /// No route of its own — see [SettingsSectionPage], which is what a caller
  /// outside the settings tree pushes. This builds a group's rows and nothing
  /// else: no bar, no background, no scaffold.

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  final _setting = Stores.setting;

  /// The kept crash report, read once in [initState]. Null again after it is
  /// dropped, which is what makes its group disappear.
  String? _savedCrashReport;

  /// Whether this device can ask for a fingerprint or a face. Null until the
  /// platform has answered, which is not a row and not a group.
  bool? _bioAuthAvail;

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

    // Both of these decide whether a whole group exists, so they are answered
    // once here rather than by a builder inside a row: a row that arrived a
    // frame later left a heading and a hairline with nothing under them.
    unawaited(
      CrashReport.saved().then((report) {
        if (!mounted || report == null) return;
        setState(() => _savedCrashReport = report);
      }),
    );
    unawaited(
      PlatformPublicSettings.bioAuthAvailable.then((avail) {
        if (!mounted || !avail) return;
        setState(() => _bioAuthAvail = true);
      }),
    );
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

  /// What a group of settings is made of, named and in order.
  ///
  /// A function of the section rather than a field, because the search walks
  /// every one of them — see [_buildSearch].
  List<SettingsGroup> _groupsOf(SettingsSection section) => switch (section) {
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

  /// Every row of every group there is, that [query] names.
  ///
  /// The rows themselves, drawn as they are drawn on their own page — so a
  /// switch found by searching is a switch, and flipping it here is flipping
  /// it. Each section's matches carry its own heading, which is where the row
  /// lives; a breadcrumb repeated on every row would say it once per line.
  List<SettingsGroup> _matchingGroups(String query) {
    final needle = query.toLowerCase();
    final groups = <SettingsGroup>[];
    for (final section in SettingsSection.values) {
      if (!section.available) continue;
      final rows = [
        for (final group in _groupsOf(section))
          ...group.rows.where((row) => row.matches(needle)),
      ];
      if (rows.isNotEmpty) groups.add(SettingsGroup(section.breadcrumb, rows));
    }
    return groups;
  }

  Widget _buildSearch(SettingsSearch search) {
    final groups = _matchingGroups(search.query);
    final pages = search.pages;
    final total = groups.fold<int>(pages.length, (n, g) => n + g.rows.length);

    // The pages themselves, under the settings on them: somebody typing
    // "sequence" means the page, and somebody typing "font" means a row.
    final pageGroup = pages.isEmpty
        ? null
        : SettingsGroup(libL10n.setting, [
            for (final hit in pages)
              SettingsRow(
                hit.leaf.title,
                () => ListTile(
                  leading: Icon(hit.leaf.icon),
                  title: Text(hit.leaf.title),
                  subtitle: hit.parent == null
                      ? null
                      : Text(hit.parent!.title, style: UIs.text11Grey),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: () => search.onPage(hit),
                ),
              ),
          ]);

    return Column(
      key: settingsResultsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupTitle(
          '$total ${libL10n.result}',
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 7),
        ),
        // A keystroke rewrites this whole list, and which of it changed is
        // the one thing that cannot be read off the result. So a section that
        // stops matching shrinks away and one that starts matching grows in,
        // and the rest of the column flows around it.
        AnimatedColumn(
          children: [
            for (final group in [...groups, ?pageGroup])
              Padding(
                key: ValueKey('group:${group.title}'),
                padding: const EdgeInsets.only(bottom: 13),
                child: SettingsGroupView(group, animated: true),
              ),
            // An entry like any other, so that it grows in as the last group
            // shrinks out. Returned early instead, it replaced the column —
            // state and all — and the groups it was replacing had nothing
            // left to leave from.
            if (total == 0)
              Padding(
                key: const ValueKey('empty'),
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Center(child: Text(libL10n.empty, style: UIs.textGrey)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.search case final search?) return _buildSearch(search);

    // The grid rather than one tall column. A settings row is a label at one
    // end and a control at the other, and on a desktop window a single column
    // of them put the two a hand's width apart and made the page a screen and
    // a half of scrolling. [PageColumns] is what the rest of the app's forms
    // are laid out in, at a width chosen for exactly this kind of row.
    //
    // No heading over the grid itself: the menu says which group this is, and
    // the header above the content repeats it. The headings inside are the
    // groups' own.
    Widget grid() => PageColumns(
      padding: _kGridPadding,
      spacing: _kGridSpacing,
      bottomInset: MediaQuery.paddingOf(context).bottom,
      children: [
        // A group can come out empty — every row in it is behind a platform
        // test — and an empty one is a heading with a rule and nothing under.
        for (final group in _groupsOf(widget.section))
          if (group.rows.isNotEmpty) SettingsGroupView(group),
      ],
    );

    // See [_Linux._buildLinux]: its rows are about whichever profile is
    // selected, and nothing else here notifies when that changes.
    if (widget.section != SettingsSection.linux) return grid();
    return ValBuilder(
      listenable: _setting.linuxProfile.listenable(),
      builder: (_) => grid(),
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

