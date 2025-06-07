import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/github_id.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/private_key/list.dart';
import 'package:server_box/view/page/setting/platform/android.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:server_box/view/page/setting/seq/srv_detail_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_seq.dart';
import 'package:server_box/view/page/setting/seq/virt_key.dart';

part 'about.dart';
part 'entries/app.dart';
part 'entries/container.dart';
part 'entries/editor.dart';
part 'entries/full_screen.dart';
part 'entries/server.dart';
part 'entries/sftp.dart';
part 'entries/ssh.dart';

const _kIconSize = 23.0;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const route = AppRouteNoArg(page: SettingsPage.new, path: '/settings');

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late final _tabCtrl = TabController(length: SettingsTabs.values.length, vsync: this);

  @override
  void dispose() {
    super.dispose();
    _tabCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(libL10n.setting, style: const TextStyle(fontSize: 20)),
        bottom: TabBar(
          controller: _tabCtrl,
          dividerHeight: 0,
          tabAlignment: TabAlignment.center,
          isScrollable: true,
          tabs: SettingsTabs.values.map((e) => Tab(text: e.i18n)).toList(growable: false),
        ),
        actions: [
          Btn.text(
            text: 'Logs',
            onTap: () =>
                DebugPage.route.go(context, args: const DebugPageArgs(title: 'Logs(${BuildData.build})')),
          ),
          Btn.icon(
            icon: const Icon(Icons.delete),
            onTap: () => context.showRoundDialog(
              title: libL10n.attention,
              child: SimpleMarkdown(
                data: libL10n.askContinue('${libL10n.delete} **${libL10n.all}** ${libL10n.setting}'),
              ),
              actions: [
                CountDownBtn(
                  onTap: () {
                    context.pop();
                    final keys = SettingStore.instance.box.keys;
                    SettingStore.instance.box.deleteAll(keys);
                    context.showSnackBar(libL10n.success);
                  },
                  afterColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(controller: _tabCtrl, children: SettingsTabs.pages),
    );
  }
}

final class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends State<AppSettingsPage> {
  final _setting = Stores.setting;

  late final _sshOpacityCtrl = TextEditingController(text: _setting.sshBgOpacity.fetch().toString());
  late final _sshBlurCtrl = TextEditingController(text: _setting.sshBlurRadius.fetch().toString());
  late final _textScalerCtrl = TextEditingController(text: _setting.textFactor.toString());
  late final _serverLogoCtrl = TextEditingController(text: _setting.serverLogoUrl.fetch());

  @override
  Widget build(BuildContext context) {
    return MultiList(
      children: [
        [const CenterGreyTitle('App'), _buildApp()],
        [CenterGreyTitle(l10n.server), _buildServer()],
        [const CenterGreyTitle('SSH'), _buildSSH(), const CenterGreyTitle('SFTP'), _buildSFTP()],
        [CenterGreyTitle(l10n.container), _buildContainer(), CenterGreyTitle(l10n.editor), _buildEditor()],

        /// Fullscreen Mode is designed for old mobile phone which can be
        /// used as a status screen.
        if (isMobile) [CenterGreyTitle(l10n.fullScreen), _buildFullScreen()],
      ],
    );
  }
}

enum SettingsTabs {
  app,
  privateKey,
  backup,
  about;

  String get i18n => switch (this) {
    SettingsTabs.app => libL10n.app,
    SettingsTabs.privateKey => l10n.privateKey,
    SettingsTabs.backup => libL10n.backup,
    SettingsTabs.about => libL10n.about,
  };

  Widget get page => switch (this) {
    SettingsTabs.app => const AppSettingsPage(),
    SettingsTabs.privateKey => const PrivateKeysListPage(),
    SettingsTabs.backup => const BackupPage(),
    SettingsTabs.about => const _AppAboutPage(),
  };

  static final List<Widget> pages = SettingsTabs.values.map((e) => e.page).toList();
}
