import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui;

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
import 'package:server_box/core/service/app_font.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/logo_url.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/core/utils/rootfs_manifest_source.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/ai/model_context.dart';
import 'package:server_box/data/model/app/builtin_theme.dart';
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
import 'package:server_box/view/widget/themed_icon.dart';

part 'about.dart';
part 'app_page.dart';
part 'group.dart';
part 'layout.dart';
part 'level.dart';
part 'menu.dart';
part 'nodes.dart';
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
}
