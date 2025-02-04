import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:server_box/data/store/setting.dart';

import 'package:server_box/generated/l10n/l10n.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/github_id.dart';
import 'package:server_box/data/res/rebuild.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';

import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/editor.dart';
import 'package:server_box/view/page/private_key/list.dart';

const _kIconSize = 23.0;

enum SettingsTabs {
  app,
  privateKey,
  backup,
  about,
  ;

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
        SettingsTabs.about => const AppAboutPage(),
      };

  static final List<Widget> pages =
      SettingsTabs.values.map((e) => e.page).toList();
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const route = AppRouteNoArg(page: SettingsPage.new, path: '/settings');

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final _tabCtrl =
      TabController(length: SettingsTabs.values.length, vsync: this);

  @override
  void dispose() {
    super.dispose();
    _tabCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(libL10n.setting, style: const TextStyle(fontSize: 20)),
        bottom: TabBar(
          controller: _tabCtrl,
          dividerHeight: 0,
          tabAlignment: TabAlignment.center,
          isScrollable: true,
          tabs: SettingsTabs.values
              .map((e) => Tab(text: e.i18n))
              .toList(growable: false),
        ),
        actions: [
          Btn.text(
            text: 'Logs',
            onTap: () => DebugPage.route.go(
              context,
              args: const DebugPageArgs(title: 'Logs(${BuildData.build})'),
            ),
          ),
          Btn.icon(
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
                    context.pop();
                    final keys = SettingStore.instance.box.keys;
                    SettingStore.instance.box.deleteAll(keys);
                    context.showSnackBar(libL10n.success);
                  },
                  afterColor: Colors.red,
                )
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(controller: _tabCtrl, children: SettingsTabs.pages),
    );
  }
}

final class AppAboutPage extends StatefulWidget {
  const AppAboutPage({super.key});

  @override
  State<AppAboutPage> createState() => _AppAboutPageState();
}

final class _AppAboutPageState extends State<AppAboutPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(13),
      children: [
        UIs.height13,
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 47, maxWidth: 47),
          child: UIs.appIcon,
        ),
        const Text(
          '${BuildData.name}\nv${BuildData.build}',
          textAlign: TextAlign.center,
          style: UIs.text15,
        ),
        UIs.height13,
        SizedBox(
          height: 77,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Btn.elevated(
                icon: const Icon(Icons.edit_document),
                text: 'Wiki',
                onTap: Urls.appWiki.launchUrl,
              ),
              Btn.elevated(
                icon: const Icon(Icons.feedback),
                text: libL10n.feedback,
                onTap: Urls.appHelp.launchUrl,
              ),
              Btn.elevated(
                icon: const Icon(MingCute.question_fill),
                text: l10n.license,
                onTap: () => showLicensePage(context: context),
              ),
            ].joinWith(UIs.width13),
          ),
        ),
        UIs.height13,
        SimpleMarkdown(
          data: '''
#### Contributors
${GithubIds.contributors.map((e) => '[$e](${e.url})').join(' ')}

#### Participants
${GithubIds.participants.map((e) => '[$e](${e.url})').join(' ')}

#### My other apps
[GPT Box](https://github.com/lollipopkit/flutter_gpt_box)

${l10n.madeWithLove('[lollipopkit](${Urls.myGithub})')}
''',
        ).paddingAll(13).cardx,
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

final class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends State<AppSettingsPage> {
  final _setting = Stores.setting;

  @override
  Widget build(BuildContext context) {
    return MultiList(
      thumbVisibility: true,
      children: [
        [const CenterGreyTitle('App'), _buildApp()],
        [CenterGreyTitle(l10n.server), _buildServer()],
        [
          const CenterGreyTitle('SSH'),
          _buildSSH(),
          const CenterGreyTitle('SFTP'),
          _buildSFTP()
        ],
        [
          CenterGreyTitle(l10n.container),
          _buildContainer(),
          CenterGreyTitle(l10n.editor),
          _buildEditor(),
        ],

        /// Fullscreen Mode is designed for old mobile phone which can be
        /// used as a status screen.
        if (isMobile) [CenterGreyTitle(l10n.fullScreen), _buildFullScreen()],
      ],
    );
  }

  Widget _buildApp() {
    final specific = _buildPlatformSetting();
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildAppColor(),
      //_buildLaunchPage(),
      _buildCheckUpdate(),

      /// Platform specific settings
      if (specific != null) specific,
      _buildAppMore(),
    ];

    return Column(children: children.map((e) => e.cardx).toList());
  }

  Widget _buildFullScreen() {
    return Column(
      children: [
        _buildFullScreenSwitch(),
        _buildFullScreenJitter(),
        // _buildFulScreenRotateQuarter(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildServer() {
    return Column(
      children: [
        _buildServerLogoUrl(),
        _buildServerFuncBtns(),
        _buildNetViewType(),
        _buildServerSeq(),
        _buildServerDetailCardSeq(),
        //_buildDiskIgnorePath(),
        _buildDeleteServers(),
        _buildCpuView(),
        _buildServerMore(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildContainer() {
    return Column(
      children: [
        _buildUsePodman(),
        _buildContainerTrySudo(),
        _buildContainerParseStat(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildSSH() {
    return Column(
      children: [
        _buildLetterCache(),
        _buildSSHWakeLock(),
        _buildTermTheme(),
        _buildFont(),
        _buildTermFontSize(),
        _buildSSHVirtualKeyAutoOff(),
        //if (isAndroid) _buildCNKeyboardComp(),
        if (isMobile) _buildSSHVirtKeys(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        _buildEditorWrap(),
        _buildEditorFontSize(),
        _buildEditorTheme(),
        _buildEditorDarkTheme(),
        _buildEditorHighlight(),
        _buildEditorCloseAfterEdit(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildCheckUpdate() {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(libL10n.checkUpdate),
      subtitle: ValBuilder(
        listenable: AppUpdateIface.newestBuild,
        builder: (val) {
          String display;
          if (val != null) {
            if (val > BuildData.build) {
              display = libL10n.versionHasUpdate(val);
            } else {
              display = libL10n.versionUpdated(BuildData.build);
            }
          } else {
            display = libL10n.versionUnknownUpdate(BuildData.build);
          }
          return Text(display, style: UIs.textGrey);
        },
      ),
      onTap: () => Fns.throttle(
        () => AppUpdateIface.doUpdate(
          context: context,
          build: BuildData.build,
          url: Urls.updateCfg,
          force: BuildMode.isDebug,
        ),
      ),
      trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
    );
  }

  Widget _buildUpdateInterval() {
    return ListTile(
      title: Text(l10n.updateServerStatusInterval),
      onTap: () async {
        final val = await context.showPickSingleDialog(
          title: libL10n.setting,
          items: List.generate(10, (idx) => idx == 1 ? null : idx),
          initial: _setting.serverStatusUpdateInterval.fetch(),
          display: (p0) => p0 == 0 ? l10n.manual : '$p0 ${l10n.second}',
        );
        if (val != null) {
          _setting.serverStatusUpdateInterval.put(val);
        }
      },
      trailing: ValBuilder(
        listenable: _setting.serverStatusUpdateInterval.listenable(),
        builder: (val) => Text(
          '$val ${l10n.second}',
          style: UIs.text15,
        ),
      ),
    );
  }

  Widget _buildAppColor() {
    return ListTile(
      leading: const Icon(Icons.colorize),
      title: Text(libL10n.primaryColorSeed),
      trailing: _setting.colorSeed.listenable().listenVal(
        (val) {
          final c = Color(val);
          return ClipOval(child: Container(color: c, height: 27, width: 27));
        },
      ),
      onTap: () async {
        final ctrl = TextEditingController(text: UIs.primaryColor.toHex);
        await context.showRoundDialog(
          title: libL10n.primaryColorSeed,
          child: StatefulBuilder(builder: (context, setState) {
            final children = <Widget>[
              /// Plugin [dynamic_color] is not supported on iOS
              if (!isIOS)
                ListTile(
                  title: Text(l10n.followSystem),
                  trailing: StoreSwitch(
                    prop: _setting.useSystemPrimaryColor,
                    callback: (_) => setState(() {}),
                  ),
                )
            ];
            if (!_setting.useSystemPrimaryColor.fetch()) {
              children.add(ColorPicker(
                color: Color(_setting.colorSeed.fetch()),
                onColorChanged: (c) => ctrl.text = c.toHex,
              ));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            );
          }),
          actions: Btn.ok(onTap: () => _onSaveColor(ctrl.text)).toList,
        );
      },
    );
  }

  void _onSaveColor(String s) {
    final color = s.fromColorHex;
    if (color == null) {
      context.showSnackBar(libL10n.fail);
      return;
    }
    UIs.colorSeed = color;
    _setting.colorSeed.put(color.value255);
    context.pop();
    Future.delayed(Durations.medium1, RNodes.app.notify);
  }

  // Widget _buildLaunchPage() {
  //   final items = AppTab.values
  //       .map(
  //         (e) => PopupMenuItem(
  //           value: e.index,
  //           child: Text(tabTitleName(context, e)),
  //         ),
  //       )
  //       .toList();

  //   return ListTile(
  //     title: Text(
  //      l10n.launchPage,
  //     ),
  //     onTap: () {
  //       _startPageKey.currentState?.showButtonMenu();
  //     },
  //     trailing: ValueBuilder(
  //       listenable: _launchPageIdx,
  //       build: () => PopupMenuButton(
  //         key: _startPageKey,
  //         itemBuilder: (BuildContext context) => items,
  //         initialValue: _launchPageIdx.value,
  //         onSelected: (int idx) {
  //           _launchPageIdx.value = idx;
  //           _setting.launchPage.put(_launchPageIdx.value);
  //         },
  //         child: ConstrainedBox(
  //           constraints: BoxConstraints(maxWidth: _media.size.width * 0.35),
  //           child: Text(
  //             tabTitleName(context, AppTab.values[_launchPageIdx.value]),
  //             textAlign: TextAlign.right,
  //             style: textSize15,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildMaxRetry() {
    return ValBuilder(
      listenable: _setting.maxRetryCount.listenable(),
      builder: (val) => ListTile(
        title: Text(l10n.maxRetryCount),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: l10n.maxRetryCount,
            items: List.generate(10, (index) => index),
            display: (p0) => '$p0 ${l10n.times}',
            initial: val,
          );
          if (selected != null) {
            _setting.maxRetryCount.put(selected);
          }
        },
        trailing: Text(
          '$val ${l10n.times}',
          style: UIs.text15,
        ),
      ),
    );
  }

  Widget _buildThemeMode() {
    // Issue #57
    final len = ThemeMode.values.length;
    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill),
      title: Text(libL10n.themeMode),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.themeMode,
          items: List.generate(len + 2, (index) => index),
          display: (p0) => _buildThemeModeStr(p0),
          initial: _setting.themeMode.fetch(),
        );
        if (selected != null) {
          _setting.themeMode.put(selected);
          RNodes.app.notify();
        }
      },
      trailing: ValBuilder(
        listenable: _setting.themeMode.listenable(),
        builder: (val) => Text(
          _buildThemeModeStr(val),
          style: UIs.text15,
        ),
      ),
    );
  }

  String _buildThemeModeStr(int n) {
    switch (n) {
      case 1:
        return libL10n.bright;
      case 2:
        return libL10n.dark;
      case 3:
        return 'AMOLED';
      case 4:
        return '${libL10n.auto} AMOLED';
      default:
        return libL10n.auto;
    }
  }

  Widget _buildFont() {
    return ListTile(
      leading: const Icon(MingCute.font_fill),
      title: Text(l10n.font),
      trailing: _setting.fontPath.listenable().listenVal(
        (val) {
          final fontName = val.getFileName();
          return Text(
            fontName ?? libL10n.empty,
            style: UIs.text15,
          );
        },
      ),
      onTap: () {
        context.showRoundDialog(
          title: l10n.font,
          actions: [
            TextButton(
              onPressed: () async => await _pickFontFile(),
              child: Text(libL10n.file),
            ),
            TextButton(
              onPressed: () {
                _setting.fontPath.delete();
                context.pop();
                RNodes.app.notify();
              },
              child: Text(libL10n.clear),
            )
          ],
        );
      },
    );
  }

  Future<void> _pickFontFile() async {
    final path = await Pfs.pickFilePath();
    if (path == null) return;

    // iOS can't copy file to app dir, so we need to use the original path
    if (isIOS) {
      _setting.fontPath.put(path);
    } else {
      final fontFile = File(path);
      await fontFile.copy(Paths.font);
      _setting.fontPath.put(Paths.font);
    }

    context.pop();
    RNodes.app.notify();
  }

  Widget _buildTermFontSize() {
    return ListTile(
      leading: const Icon(MingCute.font_size_line),
      // title: Text(l10n.fontSize),
      // subtitle: Text(l10n.termFontSizeTip, style: UIs.textGrey),
      title: TipText(l10n.fontSize, l10n.termFontSizeTip),
      trailing: ValBuilder(
        listenable: _setting.termFontSize.listenable(),
        builder: (val) => Text(
          val.toString(),
          style: UIs.text15,
        ),
      ),
      onTap: () => _showFontSizeDialog(_setting.termFontSize),
    );
  }

  // Widget _buildDiskIgnorePath() {
  //   final paths = _setting.diskIgnorePath.fetch();
  //   return ListTile(
  //     title: Text(l10n.diskIgnorePath),
  //     trailing: Text(l10n.edit, style: textSize15),
  //     onTap: () {
  //       final ctrller = TextEditingController(text: json.encode(paths));
  //       void onSubmit() {
  //         try {
  //           final list = List<String>.from(json.decode(ctrller.text));
  //           _setting.diskIgnorePath.put(list);
  //           context.pop();
  //           showSnackBar(context, Text(l10n.success));
  //         } catch (e) {
  //           showSnackBar(context, Text(e.toString()));
  //         }
  //       }

  //       showRoundDialog(
  //         context: context,
  //         title: Text(l10n.diskIgnorePath),
  //         child: Input(
  //           autoFocus: true,
  //           controller: ctrller,
  //           label: 'JSON',
  //           type: TextInputType.visiblePassword,
  //           maxLines: 3,
  //           onSubmitted: (_) => onSubmit(),
  //         ),
  //         actions: [
  //           TextButton(onPressed: onSubmit, child: Text(l10n.ok)),
  //         ],
  //       );
  //     },
  //   );
  // }

  Widget _buildLocale() {
    return ListTile(
      leading: const Icon(IonIcons.language),
      title: Text(libL10n.language),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.language,
          items: AppLocalizations.supportedLocales,
          display: (p0) => p0.nativeName,
          initial: _setting.locale.fetch().toLocale,
        );
        if (selected != null) {
          _setting.locale.put(selected.code);
          context.pop();
          RNodes.app.notify();
        }
      },
      trailing: ListenBuilder(
        listenable: _setting.locale.listenable(),
        builder: () => Text(
          context.localeNativeName,
          style: UIs.text15,
        ),
      ),
    );
  }

  Widget _buildSSHVirtualKeyAutoOff() {
    return ListTile(
      leading: const Icon(MingCute.hotkey_fill),
      title: Text(l10n.sshVirtualKeyAutoOff),
      subtitle: const Text('Ctrl & Alt', style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sshVirtualKeyAutoOff),
    );
  }

  Widget _buildEditorTheme() {
    return ListTile(
      leading: const Icon(MingCute.sun_fill),
      title: Text('${libL10n.bright} ${l10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: themeMap.keys.toList(),
          display: (p0) => p0,
          initial: _setting.editorTheme.fetch(),
        );
        if (selected != null) {
          _setting.editorTheme.put(selected);
        }
      },
    );
  }

  Widget _buildEditorDarkTheme() {
    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill),
      title: Text('${libL10n.dark} ${l10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorDarkTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: themeMap.keys.toList(),
          display: (p0) => p0,
          initial: _setting.editorDarkTheme.fetch(),
        );
        if (selected != null) {
          _setting.editorDarkTheme.put(selected);
        }
      },
    );
  }

  Widget _buildFullScreenSwitch() {
    return ListTile(
      leading: const Icon(Bootstrap.phone_landscape_fill),
      // title: Text(l10n.fullScreen),
      // subtitle: Text(l10n.fullScreenTip, style: UIs.textGrey),
      title: TipText(l10n.fullScreen, l10n.fullScreenTip),
      trailing: StoreSwitch(
        prop: _setting.fullScreen,
        callback: (_) => RNodes.app.notify(),
      ),
    );
  }

  Widget _buildFullScreenJitter() {
    return ListTile(
      leading: const Icon(AntDesign.shake_outline),
      title: Text(l10n.fullScreenJitter),
      subtitle: Text(l10n.fullScreenJitterHelp, style: UIs.textGrey),
      trailing: StoreSwitch(
        prop: _setting.fullScreenJitter,
        callback: (_) {
          context.showSnackBar(l10n.needRestart);
        },
      ),
    );
  }

  // Widget _buildFulScreenRotateQuarter() {
  //   final degrees = List.generate(4, (idx) => '${idx * 90}°').toList();
  //   final items = List.generate(4, (idx) {
  //     return PopupMenuItem<int>(
  //       value: idx,
  //       child: Text(degrees[idx]),
  //     );
  //   }).toList();

  //   return ListTile(
  //     title: Text(l10n.rotateAngel),
  //     onTap: () {
  //       _rotateQuarterKey.currentState?.showButtonMenu();
  //     },
  //     trailing: ListenableBuilder(
  //       listenable: _rotateQuarter,
  //       builder: (_, __) => PopupMenuButton(
  //         key: _rotateQuarterKey,
  //         itemBuilder: (BuildContext context) => items,
  //         initialValue: _rotateQuarter.value,
  //         onSelected: (int idx) {
  //           _rotateQuarter.value = idx;
  //           _setting.fullScreenRotateQuarter.put(idx);
  //         },
  //         child: Text(
  //           degrees[_rotateQuarter.value],
  //           style: UIs.text15,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSSHVirtKeys() {
    return ListTile(
      leading: const Icon(BoxIcons.bxs_keyboard),
      title: Text(l10n.editVirtKeys),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoutes.sshVirtKeySetting().go(context),
    );
  }

  Widget _buildSFTP() {
    return Column(
      children: [
        _buildSftpEditor(),
        _buildSftpRmrDir(),
        _buildSftpOpenLastPath(),
        _buildSftpShowFoldersFirst(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildSftpOpenLastPath() {
    return ListTile(
      leading: const Icon(MingCute.history_line),
      // title: Text(l10n.openLastPath),
      // subtitle: Text(l10n.openLastPathTip, style: UIs.textGrey),
      title: TipText(l10n.openLastPath, l10n.openLastPathTip),
      trailing: StoreSwitch(prop: _setting.sftpOpenLastPath),
    );
  }

  Widget _buildSftpShowFoldersFirst() {
    return ListTile(
      leading: const Icon(MingCute.folder_fill),
      title: Text(l10n.sftpShowFoldersFirst),
      trailing: StoreSwitch(prop: _setting.sftpShowFoldersFirst),
    );
  }

  Widget _buildNetViewType() {
    return ListTile(
      leading: const Icon(ZondIcons.network, size: _kIconSize),
      title: Text(l10n.netViewType),
      trailing: ValBuilder(
        listenable: _setting.netViewType.listenable(),
        builder: (val) => Text(
          val.toStr,
          style: UIs.text15,
        ),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.netViewType,
          items: NetViewType.values,
          display: (p0) => p0.toStr,
          initial: _setting.netViewType.fetch(),
        );
        if (selected != null) {
          _setting.netViewType.put(selected);
        }
      },
    );
  }

  Widget _buildDeleteServers() {
    return ListTile(
      title: Text(l10n.deleteServers),
      leading: const Icon(Icons.delete_forever),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final keys = Stores.server.keys();
        final deleteKeys = await context.showPickDialog<String>(
          clearable: true,
          items: keys.toList(),
        );
        if (deleteKeys == null) return;

        final md = deleteKeys.map((e) => '- $e').join('\n');
        final sure = await context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(data: md),
        );

        if (sure != true) return;
        for (final key in deleteKeys) {
          Stores.server.box.delete(key);
        }
        context.showSnackBar(libL10n.success);
      },
    );
  }

  Widget _buildTextScaler() {
    final ctrl = TextEditingController(text: _setting.textFactor.toString());
    return ListTile(
      // title: Text(l10n.textScaler),
      // subtitle: Text(l10n.textScalerTip, style: UIs.textGrey),
      title: TipText(l10n.textScaler, l10n.textScalerTip),
      trailing: ValBuilder(
        listenable: _setting.textFactor.listenable(),
        builder: (val) => Text(
          val.toString(),
          style: UIs.text15,
        ),
      ),
      onTap: () => context.showRoundDialog(
        title: l10n.textScaler,
        child: Input(
          autoFocus: true,
          type: TextInputType.number,
          hint: '1.0',
          icon: Icons.format_size,
          controller: ctrl,
          onSubmitted: _onSaveTextScaler,
          suggestion: false,
        ),
        actions: Btn.ok(onTap: () => _onSaveTextScaler(ctrl.text)).toList,
      ),
    );
  }

  void _onSaveTextScaler(String s) {
    final val = double.tryParse(s);
    if (val == null) {
      context.showSnackBar(libL10n.fail);
      return;
    }
    _setting.textFactor.put(val);
    RNodes.app.notify();
    context.pop();
  }

  Widget _buildServerFuncBtns() {
    return ExpandTile(
      leading: const Icon(BoxIcons.bxs_joystick_button, size: _kIconSize),
      title: Text(l10n.serverFuncBtns),
      children: [
        _buildServerFuncBtnsSwitch(),
        _buildServerFuncBtnsOrder(),
      ],
    );
  }

  Widget _buildServerFuncBtnsSwitch() {
    return ListTile(
      // title: Text(l10n.location),
      // subtitle: Text(l10n.moveOutServerFuncBtnsHelp, style: UIs.text13Grey),
      title: TipText(l10n.location, l10n.moveOutServerFuncBtnsHelp),
      trailing: StoreSwitch(prop: _setting.moveServerFuncs),
    );
  }

  Widget _buildServerFuncBtnsOrder() {
    return ListTile(
      title: Text(l10n.sequence),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoutes.serverFuncBtnsOrder().go(context),
    );
  }

  Widget _buildServerSeq() {
    return ListTile(
      leading: const Icon(OctIcons.sort_desc, size: _kIconSize),
      title: Text(l10n.serverOrder),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoutes.serverOrder().go(context),
    );
  }

  Widget _buildServerDetailCardSeq() {
    return ListTile(
      leading: const Icon(OctIcons.sort_desc, size: _kIconSize),
      title: Text(l10n.serverDetailOrder),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoutes.serverDetailOrder().go(context),
    );
  }

  Widget _buildEditorFontSize() {
    return ListTile(
      leading: const Icon(MingCute.font_size_line),
      title: Text(l10n.fontSize),
      trailing: ValBuilder(
        listenable: _setting.editorFontSize.listenable(),
        builder: (val) => Text(
          val.toString(),
          style: UIs.text15,
        ),
      ),
      onTap: () => _showFontSizeDialog(_setting.editorFontSize),
    );
  }

  void _showFontSizeDialog(HiveProp<double> property) {
    final ctrller = TextEditingController(text: property.get().toString());
    void onSave() {
      context.pop();
      final fontSize = double.tryParse(ctrller.text);
      if (fontSize == null) {
        context.showRoundDialog(
          title: libL10n.fail,
          child: Text('Parsed failed: ${ctrller.text}'),
        );
        return;
      }
      property.set(fontSize);
    }

    context.showRoundDialog(
      title: l10n.fontSize,
      child: Input(
        controller: ctrller,
        autoFocus: true,
        type: TextInputType.number,
        icon: Icons.font_download,
        suggestion: false,
        onSubmitted: (_) => onSave(),
      ),
      actions: Btn.ok(onTap: onSave).toList,
    );
  }

  Widget _buildSftpRmrDir() {
    return ListTile(
      leading: const Icon(MingCute.delete_2_fill),
      title: TipText('rm -r', l10n.sftpRmrDirSummary),
      trailing: StoreSwitch(prop: _setting.sftpRmrDir),
    );
  }

  Widget _buildDoubleColumnServersPage() {
    return ListTile(
      // title: Text(l10n.doubleColumnMode),
      // subtitle: Text(l10n.doubleColumnTip, style: UIs.textGrey),
      title: TipText(l10n.doubleColumnMode, l10n.doubleColumnTip),
      trailing: StoreSwitch(prop: _setting.doubleColumnServersPage),
    );
  }

  Widget? _buildPlatformSetting() {
    final func = switch (Pfs.type) {
      Pfs.android => AppRoutes.androidSettings().go,
      Pfs.ios => AppRoutes.iosSettings().go,
      _ => null,
    };
    if (func == null) return null;
    return ListTile(
      leading: const Icon(Icons.phone_android),
      title: Text('${Pfs.type} ${libL10n.setting}'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => func(context),
    );
  }

  Widget _buildEditorHighlight() {
    return ListTile(
      leading: const Icon(MingCute.code_line, size: _kIconSize),
      // title: Text(l10n.highlight),
      // subtitle: Text(l10n.editorHighlightTip, style: UIs.textGrey),
      title: TipText(l10n.highlight, l10n.editorHighlightTip),
      trailing: StoreSwitch(prop: _setting.editorHighlight),
    );
  }

  Widget _buildCollapseUI() {
    return ListTile(
      title: TipText('UI ${libL10n.fold}', l10n.collapseUITip),
      trailing: StoreSwitch(prop: _setting.collapseUIDefault),
    );
  }

  Widget _buildUsePodman() {
    return ListTile(
      leading: const Icon(IonIcons.logo_docker),
      title: Text(l10n.usePodmanByDefault),
      trailing: StoreSwitch(prop: _setting.usePodman),
    );
  }

  Widget _buildContainerTrySudo() {
    return ListTile(
      leading: const Icon(EvaIcons.person_done),
      title: TipText(l10n.trySudo, l10n.containerTrySudoTip),
      trailing: StoreSwitch(prop: _setting.containerTrySudo),
    );
  }

  Widget _buildKeepStatusWhenErr() {
    return ListTile(
      title: Text(l10n.keepStatusWhenErr),
      subtitle: Text(l10n.keepStatusWhenErrTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.keepStatusWhenErr),
    );
  }

  Widget _buildContainerParseStat() {
    return ListTile(
      leading: const Icon(MingCute.chart_line_line, size: _kIconSize),
      // title: Text(l10n.parseContainerStats),
      // subtitle: Text(l10n.parseContainerStatsTip, style: UIs.textGrey),
      title: TipText(l10n.stat, l10n.parseContainerStatsTip),
      trailing: StoreSwitch(prop: _setting.containerParseStat),
    );
  }

  Widget _buildServerMore() {
    return ExpandTile(
      leading: const Icon(MingCute.more_3_fill),
      title: Text(l10n.more),
      initiallyExpanded: false,
      children: [
        _buildRememberPwdInMem(),
        _buildTextScaler(),
        _buildKeepStatusWhenErr(),
        _buildDoubleColumnServersPage(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
      ],
    );
  }

  Widget _buildRememberPwdInMem() {
    return ListTile(
      // title: Text(l10n.rememberPwdInMem),
      // subtitle: Text(l10n.rememberPwdInMemTip, style: UIs.textGrey),
      title: TipText(l10n.rememberPwdInMem, l10n.rememberPwdInMemTip),
      trailing: StoreSwitch(prop: _setting.rememberPwdInMem),
    );
  }

  Widget _buildTermTheme() {
    String index2Str(int index) {
      switch (index) {
        case 0:
          return l10n.system;
        case 1:
          return libL10n.bright;
        case 2:
          return libL10n.dark;
        default:
          return libL10n.error;
      }
    }

    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill, size: _kIconSize),
      title: Text(l10n.theme),
      trailing: ValBuilder(
        listenable: _setting.termTheme.listenable(),
        builder: (val) => Text(
          index2Str(val),
          style: UIs.text15,
        ),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: List.generate(3, (index) => index),
          display: (p0) => index2Str(p0),
          initial: _setting.termTheme.fetch(),
        );
        if (selected != null) {
          _setting.termTheme.put(selected);
        }
      },
    );
  }

  Widget _buildAppMore() {
    return ExpandTile(
      leading: const Icon(MingCute.more_3_fill),
      title: Text(l10n.more),
      initiallyExpanded: false,
      children: [
        _buildBeta(),
        if (isMobile) _buildWakeLock(),
        _buildCollapseUI(),
        _buildCupertinoRoute(),
        if (isDesktop) _buildHideTitleBar(),
        _buildEditRawSettings(),
      ],
    );
  }

  Widget _buildCupertinoRoute() {
    return ListTile(
      title: Text('Cupertino ${l10n.route}'),
      trailing: StoreSwitch(prop: _setting.cupertinoRoute),
    );
  }

  Widget _buildHideTitleBar() {
    return ListTile(
      title: Text(l10n.hideTitleBar),
      trailing: StoreSwitch(prop: _setting.hideTitleBar),
    );
  }

  Widget _buildCpuView() {
    return ExpandTile(
      leading: const Icon(OctIcons.cpu, size: _kIconSize),
      title: Text('CPU ${l10n.view}'),
      children: [
        ListTile(
          title: Text(l10n.noLineChart),
          subtitle: Text(l10n.cpuViewAsProgressTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.cpuViewAsProgress),
        ),
        ListTile(
          title: Text(l10n.displayCpuIndex),
          trailing: StoreSwitch(prop: _setting.displayCpuIndex),
        ),
      ],
    );
  }

  Widget _buildEditorWrap() {
    return ListTile(
      leading: const Icon(MingCute.align_center_line),
      title: Text(l10n.softWrap),
      trailing: StoreSwitch(prop: _setting.editorSoftWrap),
    );
  }

  Widget _buildWakeLock() {
    return ListTile(
      title: Text(l10n.wakeLock),
      trailing: StoreSwitch(prop: _setting.generalWakeLock),
    );
  }

  Widget _buildSSHWakeLock() {
    return ListTile(
      leading: const Icon(MingCute.lock_fill),
      title: Text(l10n.wakeLock),
      trailing: StoreSwitch(prop: _setting.sshWakeLock),
    );
  }

  Widget _buildServerLogoUrl() {
    void onSave(String url) {
      if (url.isEmpty || !url.startsWith('http')) {
        context.showRoundDialog(
          title: libL10n.fail,
          child: Text('${l10n.invalid} URL'),
          actions: Btnx.oks,
        );
        return;
      }
      _setting.serverLogoUrl.put(url);
      context.pop();
    }

    return ListTile(
      leading: const Icon(Icons.image),
      title: const Text('Logo URL'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        final ctrl =
            TextEditingController(text: _setting.serverLogoUrl.fetch());
        context.showRoundDialog(
          title: 'Logo URL',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: ctrl,
                autoFocus: true,
                hint: 'https://example.com/logo.png',
                icon: Icons.link,
                maxLines: 2,
                suggestion: false,
                onSubmitted: onSave,
              ),
              ListTile(
                title: Text(libL10n.doc),
                trailing: const Icon(Icons.open_in_new),
                onTap: Urls.appWiki.launchUrl,
              ),
            ],
          ),
          actions: Btn.ok(onTap: () => onSave(ctrl.text)).toList,
        );
      },
    );
  }

  Widget _buildBeta() {
    return ListTile(
      title: TipText('Beta Program', l10n.acceptBeta),
      trailing: StoreSwitch(prop: _setting.betaTest),
    );
  }

  Widget _buildLetterCache() {
    return ListTile(
      leading: const Icon(Bootstrap.alphabet),
      // title: Text(l10n.letterCache),
      // subtitle: Text(
      //   '${l10n.letterCacheTip}\n${l10n.needRestart}',
      //   style: UIs.textGrey,
      // ),
      title: TipText(
          l10n.letterCache, '${l10n.letterCacheTip}\n${l10n.needRestart}'),
      trailing: StoreSwitch(prop: _setting.letterCache),
    );
  }

  Widget _buildSftpEditor() {
    return _setting.sftpEditor.listenable().listenVal(
      (val) {
        return ListTile(
          leading: const Icon(MingCute.edit_fill),
          title: TipText(l10n.editor, l10n.sftpEditorTip),
          trailing: Text(
            val.isEmpty ? l10n.inner : val,
            style: UIs.text15,
          ),
          onTap: () async {
            final ctrl = TextEditingController(text: val);
            void onSave() {
              final s = ctrl.text.trim();
              _setting.sftpEditor.put(s);
              context.pop();
            }

            await context.showRoundDialog<bool>(
              title: libL10n.select,
              child: Input(
                controller: ctrl,
                autoFocus: true,
                label: l10n.editor,
                hint: '\$EDITOR / vim / nano ...',
                icon: Icons.edit,
                suggestion: false,
                onSubmitted: (_) => onSave(),
              ),
              actions: Btn.ok(onTap: onSave).toList,
            );
          },
        );
      },
    );
  }

  Widget _buildEditRawSettings() {
    return ListTile(
      title: const Text('(Dev) Edit raw json'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _editRawSettings,
    );
  }

  Future<void> _editRawSettings() async {
    final map = await Stores.setting.getAllMap(includeInternalKeys: true);
    final keys = map.keys;

    void onSave(BuildContext context, EditorPageRet ret) {
      if (ret.typ != EditorPageRetType.text) {
        context.showRoundDialog(
          title: libL10n.fail,
          child: Text(l10n.invalid),
        );
        return;
      }
      try {
        final newSettings = json.decode(ret.val) as Map<String, dynamic>;
        Stores.setting.box.putAll(newSettings);
        final newKeys = newSettings.keys;
        final removedKeys = keys.where((e) => !newKeys.contains(e));
        for (final key in removedKeys) {
          Stores.setting.box.delete(key);
        }
      } catch (e, trace) {
        context.showRoundDialog(
          title: libL10n.error,
          child: Text('${l10n.save}:\n$e'),
        );
        Loggers.app.warning('Update json settings failed', e, trace);
      }
    }

    /// Encode [map] to String with indent `\t`
    final text = jsonIndentEncoder.convert(map);
    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        text: text,
        langCode: 'json',
        title: libL10n.setting,
        onSave: onSave,
      ),
    );
  }

  Widget _buildEditorCloseAfterEdit() {
    return ListTile(
      leading: const Icon(MingCute.edit_fill),
      title: Text(l10n.closeAfterSave),
      trailing: StoreSwitch(prop: _setting.closeAfterSave),
    );
  }
}
