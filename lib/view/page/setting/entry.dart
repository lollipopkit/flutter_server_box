import 'dart:convert';
import 'dart:io';

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Which branches are open. Nothing to start with, so the menu opens as a
  /// list of subjects rather than as everything there is.
  final _expanded = <String>{};

  String? _selectedId;

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
      SettingsNode.leaf(
        id: 'app',
        title: libL10n.app,
        page: () => const AppSettingsPage(section: SettingsSection.app),
      ),
      SettingsNode.leaf(
        id: 'ai',
        title: libL10n.ai,
        page: () => const AppSettingsPage(section: SettingsSection.ai),
      ),
      SettingsNode.branch(
        id: 'server',
        title: libL10n.server,
        children: [
          SettingsNode.leaf(
            id: 'server.setting',
            title: libL10n.setting,
            page: () => const AppSettingsPage(section: SettingsSection.server),
          ),
          SettingsNode.leaf(
            id: 'server.order',
            title: l10n.serverOrder,
            page: () => const ServerOrderPage(embedded: true),
          ),
          SettingsNode.leaf(
            id: 'server.detail',
            title: l10n.serverDetailOrder,
            page: () => const ServerDetailOrderPage(embedded: true),
          ),
          SettingsNode.leaf(
            id: 'server.func',
            title: libL10n.sequence,
            page: () => const ServerFuncBtnsOrderPage(embedded: true),
          ),
        ],
      ),
      SettingsNode.branch(
        id: 'ssh',
        title: l10n.ssh,
        children: [
          SettingsNode.leaf(
            id: 'ssh.setting',
            title: libL10n.setting,
            page: () => const AppSettingsPage(section: SettingsSection.ssh),
          ),
          SettingsNode.leaf(
            id: 'ssh.knownHosts',
            title: l10n.sshKnownHostKeys,
            page: () => const KnownHostsPage(embedded: true),
          ),
          SettingsNode.leaf(
            id: 'ssh.virtKey',
            title: l10n.editVirtKeys,
            page: () => const SSHVirtKeySettingPage(embedded: true),
          ),
        ],
      ),
      SettingsNode.leaf(
        id: 'sftp',
        title: l10n.sftp,
        page: () => const AppSettingsPage(section: SettingsSection.sftp),
      ),
      SettingsNode.leaf(
        id: 'container',
        title: libL10n.container,
        page: () => const AppSettingsPage(section: SettingsSection.container),
      ),
      SettingsNode.leaf(
        id: 'editor',
        title: libL10n.editor,
        page: () => const AppSettingsPage(section: SettingsSection.editor),
      ),

      /// Fullscreen Mode is designed for old mobile phone which can be
      /// used as a status screen.
      if (isMobile)
        SettingsNode.leaf(
          id: 'fullScreen',
          title: l10n.fullScreen,
          page: () => const AppSettingsPage(section: SettingsSection.fullScreen),
        ),
      SettingsNode.leaf(
        id: 'backup',
        title: libL10n.backup,
        page: () => const BackupPage(),
      ),
      SettingsNode.leaf(
        id: 'privateKey',
        title: l10n.privateKey,
        page: () => const PrivateKeysListPage(),
      ),
      SettingsNode.leaf(
        id: 'about',
        title: libL10n.about,
        page: () => const _AppAboutPage(),
      ),
    ];
  }

  void _onSelect(SettingsNode node) {
    setState(() => _selectedId = node.id);
    // The drawer has answered what it was opened to answer.
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _onToggle(SettingsNode node) {
    setState(() {
      if (!_expanded.remove(node.id)) _expanded.add(node.id);
    });
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
        return _buildScaffold(wide: wide, menu: menu, selected: selected);
      },
    );
  }

  Widget _buildScaffold({
    required bool wide,
    required Widget menu,
    required SettingsNode selected,
  }) {
    final content = KeyedSubtree(key: ValueKey(selected.id), child: selected.builder!());

    return Scaffold(
      key: _scaffoldKey,
      // The one bar the page has, naming whatever is on the right. The pages
      // shown there are given `embedded: true` and drop their own.
      appBar: CustomAppBar(
        title: Text(selected.title, style: const TextStyle(fontSize: 20)),
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
      drawer: wide ? null : Drawer(child: SafeArea(child: menu)),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  SizedBox(width: _kMenuWidth, child: menu),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
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

