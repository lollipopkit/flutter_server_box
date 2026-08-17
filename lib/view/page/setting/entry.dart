import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/github_id.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/private_key/list.dart';
import 'package:server_box/view/page/server/connection_stats.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:server_box/view/page/setting/seq/known_hosts.dart';
import 'package:server_box/view/page/setting/seq/srv_detail_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_seq.dart';
import 'package:server_box/view/page/setting/seq/virt_key.dart';
import 'package:server_box/view/widget/dmg_notice.dart';

part 'about.dart';
part 'menu.dart';
part 'entries/ai.dart';
part 'entries/app.dart';
part 'entries/container.dart';
part 'entries/editor.dart';
part 'entries/full_screen.dart';
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

/// Below this the menu is a drawer rather than a column beside the content.
///
/// The width `AdaptivePanes` splits at, so that a window wide enough for two
/// columns gets two columns here as well.
const _kMenuBreakpoint = 800.0;

/// How wide the menu is when it is beside the content.
const _kMenuWidth = 232.0;

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

  void _clearAllSettings() {
    final keys = SettingStore.instance.box.keys;
    SettingStore.instance.box.deleteAll(keys);
    Toast.success(libL10n.success);
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
            title: libL10n.setting,
            icon: Icons.settings_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.app),
          ),
          SettingsNode.leaf(
            id: 'app.ai',
            title: libL10n.ai,
            icon: Icons.auto_awesome_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.ai),
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
            title: libL10n.setting,
            icon: Icons.settings_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.server),
          ),
          SettingsNode.leaf(
            id: 'server.order',
            title: l10n.serverOrder,
            icon: Icons.sort,
            page: () => const ServerOrderPage(embedded: true),
          ),
          SettingsNode.leaf(
            id: 'server.detail',
            title: l10n.serverDetailOrder,
            icon: Icons.dashboard_customize_outlined,
            page: () => const ServerDetailOrderPage(embedded: true),
          ),
          SettingsNode.leaf(
            id: 'server.func',
            title: libL10n.sequence,
            icon: Icons.reorder,
            page: () => const ServerFuncBtnsOrderPage(embedded: true),
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
            title: libL10n.setting,
            icon: Icons.settings_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.ssh),
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
            title: l10n.sftp,
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
      SettingsNode.leaf(
        id: 'backup',
        title: libL10n.backup,
        icon: Icons.backup_outlined,
        page: () => const BackupPage(),
      ),
      SettingsNode.leaf(
        id: 'privateKey',
        title: l10n.privateKey,
        icon: Icons.key_outlined,
        page: () => const PrivateKeysListPage(),
      ),
      SettingsNode.leaf(
        id: 'about',
        title: libL10n.about,
        icon: Icons.info_outline,
        page: () => const _AppAboutPage(),
      ),
    ];
  }

  void _onSelect(SettingsNode node) => setState(() => _selectedId = node.id);

  void _onToggle(SettingsNode node) {
    setState(() {
      if (!_expanded.remove(node.id)) _expanded.add(node.id);
    });
  }

  /// A tab is a tab: it shows something. Tapping a branch goes into it *and*
  /// selects what is first inside, rather than leaving a row of tabs with none
  /// of them on. The same applies to a row of the list.
  void _onTab(SettingsNode node) {
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
        final wide = constraints.maxWidth >= _kMenuBreakpoint;
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

  /// The level [node] leads to: what is inside a branch, and what stands beside
  /// a leaf.
  static List<SettingsNode> _levelOf(SettingsNode node, List<SettingsNode> nodes) {
    return node.isLeaf ? nodes : node.children;
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
        actions: [
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
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  SizedBox(width: _kMenuWidth, child: menu),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              )
            : _buildNarrow(nodes, content),
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
    Widget pagesOf(String id, List<SettingsNode> level) {
      return _SettingsPages(
        key: ValueKey('pages_$id'),
        leaves: level.where((e) => e.isLeaf).toList(),
        selectedId: selected.id,
        onChanged: _onSelect,
      );
    }

    return Navigator(
      pages: [
        if (wide)
          MaterialPage<void>(
            key: ValueKey(_groupOf(nodes, selected.id)?.firstOrNull?.id ?? 'root'),
            child: pagesOf(selected.id, _groupOf(nodes, selected.id) ?? const []),
          )
        else ...[
          // What settings there are, which is where a narrow window starts.
          MaterialPage<void>(
            key: const ValueKey('root'),
            child: _SettingsList(nodes: nodes, onTap: _onTab),
          ),
          for (final entered in _path)
            MaterialPage<void>(
              key: ValueKey(entered.id),
              child: pagesOf(entered.id, _levelOf(entered, nodes)),
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
  }

  /// The content with the tabs floating over its foot.
  ///
  /// The content is told to keep clear of them through the [MediaQuery] its own
  /// `SafeArea` reads, so a list scrolls to its end above the bar rather than
  /// under it.
  Widget _buildNarrow(List<SettingsNode> nodes, Widget content) {
    // The list is the whole of what it has to say; a bar of tabs over it would
    // be the same names twice.
    if (_path.isEmpty) return content;

    final mediaQuery = MediaQuery.of(context);
    final level = _levelOf(_path.last, nodes);

    return Stack(
      children: [
        MediaQuery(
          data: mediaQuery.copyWith(
            padding: mediaQuery.padding.copyWith(
              bottom: mediaQuery.padding.bottom + _kTabsHeight + _kTabsMargin * 2,
            ),
          ),
          child: SafeArea(top: false, child: content),
        ),
        // Edge to edge, and the bar centres itself within that: it is as wide
        // as the level it is showing, and only scrolls when that is too wide.
        Positioned(
          left: 0,
          right: 0,
          bottom: _kTabsMargin,
          child: _SettingsTabs(
            nodes: level,
            selectedId: _selectedId,
            canGoBack: _path.isNotEmpty,
            onTap: _onTab,
            onBack: _onTabBack,
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
enum SettingsSection { app, ai, server, ssh, sftp, container, editor, fullScreen }

final class AppSettingsPage extends ConsumerStatefulWidget {
  final SettingsSection section;

  const AppSettingsPage({super.key, required this.section});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  final _setting = Stores.setting;

  late final _sshOpacityCtrl = TextEditingController(
    text: _setting.sshBgOpacity.fetch().toString(),
  );
  late final _sshBlurCtrl = TextEditingController(
    text: _setting.sshBlurRadius.fetch().toString(),
  );
  late final _textScalerCtrl = TextEditingController(
    text: _setting.textFactor.toString(),
  );
  late final _serverLogoCtrl = TextEditingController(
    text: _setting.serverLogoUrl.fetch(),
  );

  @override
  void dispose() {
    _sshOpacityCtrl.dispose();
    _sshBlurCtrl.dispose();
    _textScalerCtrl.dispose();
    _serverLogoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No heading over it: the menu says which group this is, and the bar above
    // repeats it. A `CenterGreyTitle` here would be the third time.
    final group = switch (widget.section) {
      SettingsSection.app => _buildApp(),
      SettingsSection.ai => _buildAskAiConfig(),
      SettingsSection.server => _buildServer(),
      SettingsSection.ssh => _buildSSH(),
      SettingsSection.sftp => _buildSFTP(),
      SettingsSection.container => _buildContainer(),
      SettingsSection.editor => _buildEditor(),
      SettingsSection.fullScreen => _buildFullScreen(),
    };

    return ListView(
      padding: MultiList.kOuterPadding,
      children: [group],
    );
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

