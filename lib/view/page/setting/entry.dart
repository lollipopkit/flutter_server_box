import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/rootfs.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/net_view.dart';
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
import 'package:server_box/view/page/private_key/list.dart';
import 'package:server_box/view/page/server/connection_stats.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:server_box/view/page/setting/seq/known_hosts.dart';
// Still reached on its own from the server settings page, which links straight
// at it rather than at the tabs.
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_orders.dart';
import 'package:server_box/view/page/setting/seq/virt_key.dart';
import 'package:server_box/view/widget/dmg_notice.dart';
import 'package:server_box/view/widget/rootfs_install.dart';

part 'about.dart';
part 'menu.dart';
part 'entries/ai.dart';
part 'entries/app.dart';
part 'entries/container.dart';
part 'entries/editor.dart';
part 'entries/full_screen.dart';
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
              title: 'Linux',
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
                  // Not Material's default: that one is drawn for a light
                  // background and reads as a bright seam on a dark one, which
                  // is why every other seam in the app goes through [Hairline]
                  // — including the one `AdaptivePanes` draws, which this line
                  // sits at the same corners as.
                  VerticalDivider(
                    width: Hairline.thickness,
                    thickness: Hairline.thickness,
                    color: Hairline.color(context),
                  ),
                  Expanded(child: content),
                ],
              )
            // A `Builder` so the insets read below are the ones this body
            // actually has: the state's own context is above the `Scaffold`,
            // where `padding` is still the whole window's — the status bar the
            // app bar already covers, and the home indicator the `SafeArea`
            // just above here already cleared.
            : Builder(builder: (context) => _buildNarrow(context, nodes, content)),
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
    Widget opaque(Widget child) => Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );

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
            child: opaque(
              pagesOf(selected.id, _groupOf(nodes, selected.id) ?? const []),
            ),
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
              child: opaque(pagesOf(entered.id, _levelOf(entered))),
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
        Positioned(
          left: 0,
          right: 0,
          bottom: _kTabsMargin,
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
      SettingsSection.linux => _buildLinux(),
      SettingsSection.sftp => _buildSFTP(),
      SettingsSection.container => _buildContainer(),
      SettingsSection.editor => _buildEditor(),
      SettingsSection.fullScreen => _buildFullScreen(),
    };

    return ListView(
      padding: context.padBottom(MultiList.kOuterPadding),
      children: [group],
    );
  }

  /// Redraws after something a listenable does not cover.
  ///
  /// The Linux page reads `Rootfs.installed`, which is a file on disk and not
  /// a store key, so nothing notifies when an install or a removal changes it.
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

