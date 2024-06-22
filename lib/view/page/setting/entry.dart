import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/rebuild.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';

import '../../../core/route.dart';
import '../../../data/model/app/net_view.dart';
import '../../../data/provider/app.dart';
import '../../../data/res/build_data.dart';

const _kIconSize = 23.0;

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final _setting = Stores.setting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.setting),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => context.showRoundDialog(
              title: l10n.attention,
              child: SimpleMarkdown(
                  data: l10n.askContinue(
                '${l10n.delete} **${l10n.all}** ${l10n.setting}',
              )),
              actions: [
                TextButton(
                  onPressed: () {
                    context.pop();
                    _setting.box.deleteAll(_setting.box.keys);
                    context.showSnackBar(l10n.success);
                  },
                  child: Text(
                    l10n.ok,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          _buildTitle('App'),
          _buildApp(),
          _buildTitle(l10n.server),
          _buildServer(),
          _buildTitle(l10n.container),
          _buildContainer(),
          _buildTitle('SSH'),
          _buildSSH(),
          _buildTitle('SFTP'),
          _buildSFTP(),
          _buildTitle(l10n.editor),
          _buildEditor(),

          /// Fullscreen Mode is designed for old mobile phone which can be
          /// used as a status screen.
          if (isMobile) _buildTitle(l10n.fullScreen),
          if (isMobile) _buildFullScreen(),
          const SizedBox(height: 37),
        ],
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 23, bottom: 17),
      child: Center(
        child: Text(
          text,
          style: UIs.textGrey,
        ),
      ),
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

    return Column(
      children: children.map((e) => CardX(child: e)).toList(),
    );
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
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildCheckUpdate() {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(l10n.autoCheckUpdate),
      subtitle: Consumer<AppProvider>(
        builder: (ctx, app, __) {
          String display;
          if (app.newestBuild != null) {
            if (app.newestBuild! > BuildData.build) {
              display = l10n.versionHaveUpdate(app.newestBuild!);
            } else {
              display = l10n.versionUpdated(BuildData.build);
            }
          } else {
            display = l10n.versionUnknownUpdate(BuildData.build);
          }
          return Text(display, style: UIs.textGrey);
        },
      ),
      onTap: () => Funcs.throttle(
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
      title: Text(
        l10n.updateServerStatusInterval,
      ),
      subtitle: Text(
        l10n.willTakEeffectImmediately,
        style: UIs.textGrey,
      ),
      onTap: () async {
        final val = await context.showPickSingleDialog(
          title: l10n.setting,
          items: List.generate(10, (idx) => idx == 1 ? null : idx),
          initial: _setting.serverStatusUpdateInterval.fetch(),
          name: (p0) => p0 == 0 ? l10n.manual : '$p0 ${l10n.second}',
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
      title: Text(l10n.primaryColorSeed),
      trailing: ClipOval(
        child: Container(color: UIs.primaryColor, height: 27, width: 27),
      ),
      onTap: () async {
        final ctrl = TextEditingController(text: UIs.primaryColor.toHex);
        await context.showRoundDialog(
          title: l10n.primaryColorSeed,
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
              children.addAll([
                Input(
                  onSubmitted: _onSaveColor,
                  controller: ctrl,
                  hint: '#8b2252',
                  icon: Icons.colorize,
                ),
                ColorPicker(
                  color: Color(_setting.primaryColor.fetch()),
                  onColorChanged: (c) => ctrl.text = c.toHex,
                )
              ]);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            );
          }),
          actions: [
            TextButton(
              onPressed: () => _onSaveColor(ctrl.text),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _onSaveColor(String s) {
    final color = s.hexToColor;
    if (color == null) {
      context.showSnackBar(l10n.failed);
      return;
    }
    // Change [primaryColor] first, then change [_selectedColorValue],
    // So the [ValueBuilder] will be triggered with the new value
    UIs.colorSeed = color;
    _setting.primaryColor.put(color.value);
    context.pop();
    context.pop();
    RNodes.app.build();
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
        title: Text(
          l10n.maxRetryCount,
          textAlign: TextAlign.start,
        ),
        subtitle: Text(
            val == 0 ? l10n.maxRetryCountEqual0 : l10n.canPullRefresh,
            style: UIs.textGrey),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: l10n.maxRetryCount,
            items: List.generate(10, (index) => index),
            name: (p0) => '$p0 ${l10n.times}',
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
      title: Text(l10n.themeMode),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.themeMode,
          items: List.generate(len + 2, (index) => index),
          name: (p0) => _buildThemeModeStr(p0),
          initial: _setting.themeMode.fetch(),
        );
        if (selected != null) {
          _setting.themeMode.put(selected);
          RNodes.app.build();
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
        return l10n.light;
      case 2:
        return l10n.dark;
      case 3:
        return 'AMOLED';
      case 4:
        return '${l10n.auto} AMOLED';
      default:
        return l10n.auto;
    }
  }

  Widget _buildFont() {
    final fontName = _setting.fontPath.fetch().getFileName();
    return ListTile(
      leading: const Icon(MingCute.font_fill),
      title: Text(l10n.font),
      trailing: Text(
        fontName ?? l10n.notSelected,
        style: UIs.text15,
      ),
      onTap: () {
        context.showRoundDialog(
          title: l10n.font,
          actions: [
            TextButton(
              onPressed: () async => await _pickFontFile(),
              child: Text(l10n.pickFile),
            ),
            TextButton(
              onPressed: () {
                _setting.fontPath.delete();
                context.pop();
                RNodes.app.build();
              },
              child: Text(l10n.clear),
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
    RNodes.app.build();
  }

  Widget _buildTermFontSize() {
    return ListTile(
      leading: const Icon(MingCute.font_size_line),
      title: Text(l10n.fontSize),
      subtitle: Text(l10n.termFontSizeTip, style: UIs.textGrey),
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
      title: Text(l10n.language),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.language,
          items: AppLocalizations.supportedLocales,
          name: (p0) => p0.code,
          initial: _setting.locale.fetch().toLocale,
        );
        if (selected != null) {
          _setting.locale.put(selected.code);
          context.pop();
          RNodes.app.build();
        }
      },
      trailing: ListenBuilder(
        listenable: _setting.locale.listenable(),
        builder: () => Text(
          l10n.languageName,
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
      title: Text('${l10n.light} ${l10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: themeMap.keys.toList(),
          name: (p0) => p0,
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
      title: Text('${l10n.dark} ${l10n.theme.toLowerCase()}'),
      trailing: ValBuilder(
        listenable: _setting.editorDarkTheme.listenable(),
        builder: (val) => Text(val, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
          items: themeMap.keys.toList(),
          name: (p0) => p0,
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
      title: Text(l10n.fullScreen),
      subtitle: Text(l10n.fullScreenTip, style: UIs.textGrey),
      trailing: StoreSwitch(
        prop: _setting.fullScreen,
        callback: (_) => RNodes.app.build(),
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

  // Widget _buildCNKeyboardComp() {
  //   return ListTile(
  //     title: Text(l10n.cnKeyboardComp),
  //     subtitle: Text(l10n.cnKeyboardCompTip, style: UIs.textGrey),
  //     trailing: StoreSwitch(prop: _setting.cnKeyboardComp),
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
        _buildSftpRmrDir(),
        _buildSftpOpenLastPath(),
        _buildSftpShowFoldersFirst(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildSftpOpenLastPath() {
    return ListTile(
      leading: const Icon(MingCute.history_line),
      title: Text(l10n.openLastPath),
      subtitle: Text(l10n.openLastPathTip, style: UIs.textGrey),
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
          name: (p0) => p0.toStr,
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
        final keys = Stores.server.box.keys.toList();
        keys.removeWhere((element) => element == BoxX.lastModifiedKey);
        final strKeys = List<String>.empty(growable: true);
        for (final key in keys) {
          if (key is String) strKeys.add(key);
        }
        final deleteKeys = await context.showPickDialog<String>(
          clearable: true,
          items: strKeys,
        );
        if (deleteKeys == null) return;

        final md = deleteKeys.map((e) => '- $e').join('\n');
        final sure = await context.showRoundDialog(
          title: l10n.attention,
          child: SimpleMarkdown(data: md),
        );

        if (sure != true) return;
        for (final key in deleteKeys) {
          Stores.server.box.delete(key);
        }
        context.showSnackBar(l10n.success);
      },
    );
  }

  Widget _buildTextScaler() {
    final ctrl = TextEditingController(text: _setting.textFactor.toString());
    return ListTile(
      title: Text(l10n.textScaler),
      subtitle: Text(l10n.textScalerTip, style: UIs.textGrey),
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
        ),
        actions: [
          TextButton(
            onPressed: () => _onSaveTextScaler(ctrl.text),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _onSaveTextScaler(String s) {
    final val = double.tryParse(s);
    if (val == null) {
      context.showSnackBar(l10n.failed);
      return;
    }
    _setting.textFactor.put(val);
    RNodes.app.build();
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
      title: Text(l10n.location),
      subtitle: Text(l10n.moveOutServerFuncBtnsHelp, style: UIs.text13Grey),
      trailing: StoreSwitch(prop: _setting.moveOutServerTabFuncBtns),
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

  void _showFontSizeDialog(StorePropertyBase<double> property) {
    final ctrller = TextEditingController(text: property.fetch().toString());
    void onSave() {
      context.pop();
      final fontSize = double.tryParse(ctrller.text);
      if (fontSize == null) {
        context.showRoundDialog(
          title: l10n.failed,
          child: Text('Parsed failed: ${ctrller.text}'),
        );
        return;
      }
      property.put(fontSize);
    }

    context.showRoundDialog(
      title: l10n.fontSize,
      child: Input(
        controller: ctrller,
        autoFocus: true,
        type: TextInputType.number,
        icon: Icons.font_download,
        onSubmitted: (_) => onSave(),
      ),
      actions: [
        TextButton(
          onPressed: onSave,
          child: Text(l10n.ok),
        ),
      ],
    );
  }

  Widget _buildSftpRmrDir() {
    return ListTile(
      leading: const Icon(MingCute.delete_2_fill),
      title: const Text('rm -r'),
      subtitle: Text(l10n.sftpRmrDirSummary, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sftpRmrDir),
    );
  }

  Widget _buildDoubleColumnServersPage() {
    return ListTile(
      title: Text(l10n.doubleColumnMode),
      subtitle: Text(l10n.doubleColumnTip, style: UIs.textGrey),
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
      title: Text('${Pfs.type} ${l10n.setting}'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => func(context),
    );
  }

  Widget _buildEditorHighlight() {
    return ListTile(
      leading: const Icon(MingCute.code_line, size: _kIconSize),
      title: Text(l10n.highlight),
      subtitle: Text(l10n.editorHighlightTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.editorHighlight),
    );
  }

  Widget _buildCollapseUI() {
    return ListTile(
      title: Text(l10n.collapseUI),
      subtitle: Text(l10n.collapseUITip, style: UIs.textGrey),
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
      leading: const Icon(Clarity.administrator_solid),
      title: Text(l10n.trySudo),
      subtitle: Text(l10n.containerTrySudoTip, style: UIs.textGrey),
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
      leading: const Icon(IonIcons.stats_chart, size: _kIconSize),
      title: Text(l10n.parseContainerStats),
      subtitle: Text(l10n.parseContainerStatsTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.containerParseStat),
    );
  }

  Widget _buildServerMore() {
    return ExpandTile(
      leading: const Icon(MingCute.more_3_fill),
      title: Text(l10n.more),
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
      title: Text(l10n.rememberPwdInMem),
      subtitle: Text(l10n.rememberPwdInMemTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.rememberPwdInMem),
    );
  }

  Widget _buildTermTheme() {
    String index2Str(int index) {
      switch (index) {
        case 0:
          return l10n.system;
        case 1:
          return l10n.light;
        case 2:
          return l10n.dark;
        default:
          return l10n.error;
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
          name: (p0) => index2Str(p0),
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
      children: [
        _buildBeta(),
        _buildWakeLock(),
        _buildCollapseUI(),
        _buildCupertinoRoute(),
        if (isDesktop) _buildHideTitleBar(),
        if (isDesktop) PlatformPublicSettings.buildSaveWindowSize(),
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
      subtitle: Text(l10n.hideTitleBarTip, style: UIs.textGrey),
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
          title: l10n.failed,
          child: Text('${l10n.invalid} URL'),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
        return;
      }
      _setting.serverLogoUrl.put(url);
      context.pop();
    }

    return ListTile(
      leading: const Icon(Icons.image),
      title: Text('Logo ${l10n.addr}'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        final ctrl =
            TextEditingController(text: _setting.serverLogoUrl.fetch());
        context.showRoundDialog(
          title: 'Logo ${l10n.addr}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: ctrl,
                autoFocus: true,
                hint: 'https://example.com/logo.png',
                icon: Icons.link,
                maxLines: 2,
                onSubmitted: onSave,
              ),
              ListTile(
                title: Text(l10n.doc),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => Urls.appWiki.launch(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => onSave(ctrl.text),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBeta() {
    return ListTile(
      title: const Text('Beta Program'),
      subtitle: Text(l10n.acceptBeta, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.betaTest),
    );
  }
}
