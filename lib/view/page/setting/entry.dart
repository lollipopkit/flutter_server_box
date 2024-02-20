import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/colorx.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/extension/locale.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils/function.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/rebuild.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/expand_tile.dart';

import '../../../core/persistant_store.dart';
import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../core/update.dart';
import '../../../data/model/app/net_view.dart';
import '../../../data/provider/app.dart';
import '../../../data/res/build_data.dart';
import '../../../data/res/color.dart';
import '../../../data/res/path.dart';
import '../../../data/res/ui.dart';
import '../../widget/color_picker.dart';
import '../../widget/appbar.dart';
import '../../widget/input_field.dart';
import '../../widget/cardx.dart';
import '../../widget/store_switch.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final _themeKey = GlobalKey<PopupMenuButtonState<int>>();
  final _updateIntervalKey = GlobalKey<PopupMenuButtonState<int>>();
  final _maxRetryKey = GlobalKey<PopupMenuButtonState<int>>();
  final _localeKey = GlobalKey<PopupMenuButtonState<String>>();
  final _editorThemeKey = GlobalKey<PopupMenuButtonState<String>>();
  final _editorDarkThemeKey = GlobalKey<PopupMenuButtonState<String>>();
  final _keyboardTypeKey = GlobalKey<PopupMenuButtonState<int>>();
  //final _rotateQuarterKey = GlobalKey<PopupMenuButtonState<int>>();
  final _netViewTypeKey = GlobalKey<PopupMenuButtonState<NetViewType>>();
  final _setting = Stores.setting;

  late final _selectedColorValue = ValueNotifier(_setting.primaryColor.fetch());
  late final _nightMode = ValueNotifier(_setting.themeMode.fetch());
  late final _maxRetryCount = ValueNotifier(_setting.maxRetryCount.fetch());
  late final _updateInterval =
      ValueNotifier(_setting.serverStatusUpdateInterval.fetch());
  late final _termFontSize = ValueNotifier(_setting.termFontSize.fetch());
  late final _editorFontSize = ValueNotifier(_setting.editorFontSize.fetch());
  late final _localeCode = ValueNotifier('');
  late final _editorTheme = ValueNotifier(_setting.editorTheme.fetch());
  late final _editorDarkTheme = ValueNotifier(_setting.editorDarkTheme.fetch());
  late final _keyboardType = ValueNotifier(_setting.keyboardType.fetch());
  // late final _rotateQuarter =
  //     ValueNotifier(_setting.fullScreenRotateQuarter.fetch());
  late final _netViewType = ValueNotifier(_setting.netViewType.fetch());
  late final _textScaler = ValueNotifier(_setting.textFactor.fetch());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeSettingVal = _setting.locale.fetch();
    if (localeSettingVal.isEmpty) {
      _localeCode.value = l10n.localeName;
    } else {
      _localeCode.value = localeSettingVal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.setting),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => context.showRoundDialog(
              title: Text(l10n.attention),
              child: Text(l10n.askContinue(
                '${l10n.delete}: **${l10n.all}** ${l10n.setting}',
              )),
              actions: [
                TextButton(
                  onPressed: () {
                    _setting.box.deleteAll(_setting.box.keys);
                    context.pop();
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
          /// used as a status screen, so it's only available on mobile phone.
          // if (!isDesktop) _buildTitle(l10n.fullScreen),
          // if (!isDesktop) _buildFullScreen(),
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
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildAppColor(),
      //_buildLaunchPage(),
      _buildCheckUpdate(),
      _buildCollapseUI(),
    ];

    /// Platform specific settings
    if (OS.hasSpecSetting) {
      children.add(_buildPlatformSetting());
    }
    return Column(
      children: children.map((e) => CardX(child: e)).toList(),
    );
  }

  // Widget _buildFullScreen() {
  //   return Column(
  //     children: [
  //       _buildFullScreenSwitch(),
  //       _buildFullScreenJitter(),
  //       _buildFulScreenRotateQuarter(),
  //     ].map((e) => CardX(child: e)).toList(),
  //   );
  // }

  Widget _buildServer() {
    return Column(
      children: [
        _buildKeepStatusWhenErr(),
        _buildServerFuncBtns(),
        _buildServerSeq(),
        _buildServerDetailCardSeq(),
        _buildNetViewType(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        //_buildDiskIgnorePath(),
        _buildDeleteServers(),
        _buildTextScaler(),
        //if (isDesktop) _buildDoubleColumnServersPage(),
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
        _buildFont(),
        _buildTermFontSize(),
        _buildSSHVirtualKeyAutoOff(),
        // Use hardware keyboard on desktop, so there is no need to set it
        if (isMobile) _buildKeyboardType(),
        if (isMobile) _buildSSHVirtKeys(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        _buildEditorFontSize(),
        _buildEditorTheme(),
        _buildEditorDarkTheme(),
        _buildEditorHighlight(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildCheckUpdate() {
    return Consumer<AppProvider>(
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
        return ListTile(
          title: Text(l10n.autoCheckUpdate),
          subtitle: Text(display, style: UIs.textGrey),
          onTap: () => Funcs.throttle(() => doUpdate(ctx)),
          trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
        );
      },
    );
  }

  Widget _buildUpdateInterval() {
    final items = List.generate(
      10,
      (index) => PopupMenuItem(
        value: index,
        child: Text(index == 0 ? l10n.manual : '$index ${l10n.second}'),
      ),
      growable: false,
    ).toList();
    // 1 second is too fast, so remove it
    items.removeAt(1);

    return ListTile(
      title: Text(
        l10n.updateServerStatusInterval,
      ),
      subtitle: Text(
        l10n.willTakEeffectImmediately,
        style: UIs.textGrey,
      ),
      onTap: () {
        _updateIntervalKey.currentState?.showButtonMenu();
      },
      trailing: ListenableBuilder(
        listenable: _updateInterval,
        builder: (_, __) => PopupMenuButton(
          key: _updateIntervalKey,
          itemBuilder: (_) => items,
          initialValue: _updateInterval.value,
          onSelected: (int val) {
            _updateInterval.value = val;
            _setting.serverStatusUpdateInterval.put(val);
            Pros.server.startAutoRefresh();
            if (val == 0) {
              context.showSnackBar(l10n.updateIntervalEqual0);
            }
          },
          child: Text(
            '${_updateInterval.value} ${l10n.second}',
            style: UIs.text15,
          ),
        ),
      ),
    );
  }

  Widget _buildAppColor() {
    return ListTile(
      trailing: ClipOval(
        child: ListenableBuilder(
          listenable: _selectedColorValue,
          builder: (_, __) => Container(
            color: primaryColor,
            height: 27,
            width: 27,
          ),
        ),
      ),
      title: Text(l10n.primaryColorSeed),
      onTap: () async {
        final ctrl = TextEditingController(text: primaryColor.toHex);
        await context.showRoundDialog(
          title: Text(l10n.primaryColorSeed),
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
                  color: primaryColor,
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
    primaryColor = color;
    _selectedColorValue.value = color.value;
    _setting.primaryColor.put(_selectedColorValue.value);
    context.pop();
    RebuildNodes.app.rebuild();
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
    final items = List.generate(
      10,
      (index) => PopupMenuItem(
        value: index,
        child: Text('$index ${l10n.times}'),
      ),
      growable: false,
    ).toList();
    final help = _maxRetryCount.value == 0
        ? l10n.maxRetryCountEqual0
        : l10n.canPullRefresh;

    return ListTile(
      title: Text(
        l10n.maxRetryCount,
        textAlign: TextAlign.start,
      ),
      subtitle: Text(help, style: UIs.textGrey),
      onTap: () {
        _maxRetryKey.currentState?.showButtonMenu();
      },
      trailing: ListenableBuilder(
        builder: (_, __) => PopupMenuButton(
          key: _maxRetryKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _maxRetryCount.value,
          onSelected: (int val) {
            _maxRetryCount.value = val;
            _setting.maxRetryCount.put(_maxRetryCount.value);
          },
          child: Text(
            '${_maxRetryCount.value} ${l10n.times}',
            style: UIs.text15,
          ),
        ),
        listenable: _maxRetryCount,
      ),
    );
  }

  Widget _buildThemeMode() {
    final items = ThemeMode.values
        .map(
          (e) => PopupMenuItem(
            value: e.index,
            child: Text(_buildThemeModeStr(e.index)),
          ),
        )
        .toList();
    // Issue #57
    final len = ThemeMode.values.length;

    /// Add AMOLED theme
    items.add(PopupMenuItem(value: len, child: Text(_buildThemeModeStr(len))));

    /// Add AUTO-AMOLED theme
    items.add(
      PopupMenuItem(value: len + 1, child: Text(_buildThemeModeStr(len + 1))),
    );

    return ListTile(
      title: Text(
        l10n.themeMode,
      ),
      onTap: () {
        _themeKey.currentState?.showButtonMenu();
      },
      trailing: ListenableBuilder(
        listenable: _nightMode,
        builder: (_, __) => PopupMenuButton(
          key: _themeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _nightMode.value,
          onSelected: (int idx) {
            _nightMode.value = idx;
            _setting.themeMode.put(_nightMode.value);

            RebuildNodes.app.rebuild();
          },
          child: Text(
            _buildThemeModeStr(_nightMode.value),
            style: UIs.text15,
          ),
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
    final fontName = getFileName(_setting.fontPath.fetch());
    return ListTile(
      title: Text(l10n.font),
      trailing: Text(
        fontName ?? l10n.notSelected,
        style: UIs.text15,
      ),
      onTap: () {
        context.showRoundDialog(
          title: Text(l10n.font),
          actions: [
            TextButton(
              onPressed: () async => await _pickFontFile(),
              child: Text(l10n.pickFile),
            ),
            TextButton(
              onPressed: () {
                _setting.fontPath.delete();
                context.pop();
                RebuildNodes.app.rebuild();
              },
              child: Text(l10n.clear),
            )
          ],
        );
      },
    );
  }

  Future<void> _pickFontFile() async {
    final path = await pickOneFile();
    if (path != null) {
      // iOS can't copy file to app dir, so we need to use the original path
      if (isIOS) {
        _setting.fontPath.put(path);
      } else {
        final fontFile = File(path);
        final newPath = '${await Paths.font}/${path.split('/').last}';
        await fontFile.copy(newPath);
        _setting.fontPath.put(newPath);
      }

      context.pop();
      RebuildNodes.app.rebuild();
      return;
    }
    context.showSnackBar(l10n.failed);
  }

  Widget _buildTermFontSize() {
    return ListenableBuilder(
      listenable: _termFontSize,
      builder: (_, __) => ListTile(
        title: Text(l10n.fontSize),
        trailing: Text(
          _termFontSize.value.toString(),
          style: UIs.text15,
        ),
        onTap: () => _showFontSizeDialog(_termFontSize, _setting.termFontSize),
      ),
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
    final items = S.supportedLocales
        .map(
          (e) => PopupMenuItem<String>(
            value: e.code,
            child: Text(e.code),
          ),
        )
        .toList();
    return ListTile(
      title: Text(l10n.language),
      onTap: () {
        _localeKey.currentState?.showButtonMenu();
      },
      trailing: ListenableBuilder(
        listenable: _localeCode,
        builder: (_, __) => PopupMenuButton(
          key: _localeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _localeCode.value,
          onSelected: (String idx) {
            _localeCode.value = idx;
            _setting.locale.put(idx);
            RebuildNodes.app.rebuild();
            context.pop();
          },
          child: Text(
            l10n.languageName,
            style: UIs.text15,
          ),
        ),
      ),
    );
  }

  Widget _buildSSHVirtualKeyAutoOff() {
    return ListTile(
      title: Text(l10n.sshVirtualKeyAutoOff),
      subtitle: const Text('Ctrl & Alt', style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sshVirtualKeyAutoOff),
    );
  }

  Widget _buildEditorTheme() {
    final items = themeMap.keys.map(
      (key) {
        return PopupMenuItem<String>(
          value: key,
          child: Text(key),
        );
      },
    ).toList();
    return ListTile(
      title: Text('${l10n.light} ${l10n.theme.toLowerCase()}'),
      trailing: ListenableBuilder(
        listenable: _editorTheme,
        builder: (_, __) => PopupMenuButton(
          key: _editorThemeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _editorTheme.value,
          onSelected: (String idx) {
            _editorTheme.value = idx;
            _setting.editorTheme.put(idx);
          },
          child: Text(
            _editorTheme.value,
            style: UIs.text15,
          ),
        ),
      ),
      onTap: () {
        _editorThemeKey.currentState?.showButtonMenu();
      },
    );
  }

  Widget _buildEditorDarkTheme() {
    final items = themeMap.keys.map(
      (key) {
        return PopupMenuItem<String>(
          value: key,
          child: Text(key),
        );
      },
    ).toList();
    return ListTile(
      title: Text('${l10n.dark} ${l10n.theme.toLowerCase()}'),
      trailing: ListenableBuilder(
        listenable: _editorDarkTheme,
        builder: (_, __) => PopupMenuButton(
          key: _editorDarkThemeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _editorDarkTheme.value,
          onSelected: (String idx) {
            _editorDarkTheme.value = idx;
            _setting.editorDarkTheme.put(idx);
          },
          child: Text(
            _editorDarkTheme.value,
            style: UIs.text15,
          ),
        ),
      ),
      onTap: () {
        _editorDarkThemeKey.currentState?.showButtonMenu();
      },
    );
  }

  // Widget _buildFullScreenSwitch() {
  //   return ListTile(
  //     title: Text(l10n.fullScreen),
  //     trailing: StoreSwitch(
  //       prop: _setting.fullScreen,
  //       callback: (_) => RebuildNodes.app.rebuild(),
  //     ),
  //   );
  // }

  // Widget _buildFullScreenJitter() {
  //   return ListTile(
  //     title: Text(l10n.fullScreenJitter),
  //     subtitle: Text(l10n.fullScreenJitterHelp, style: UIs.textGrey),
  //     trailing: StoreSwitch(prop: _setting.fullScreenJitter),
  //   );
  // }

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

  Widget _buildKeyboardType() {
    const List<String> names = <String>[
      'text',
      'multiline',
      'number',
      'phone',
      'datetime',
      'emailAddress',
      'url',
      'visiblePassword',
      'name',
      'address',
      'none',
    ];
    if (names.length != TextInputType.values.length) {
      // This notify me to update the code
      throw Exception('names.length != TextInputType.values.length');
    }
    final items = TextInputType.values.map(
      (key) {
        return PopupMenuItem<int>(
          value: key.index,
          child: Text(names[key.index]),
        );
      },
    ).toList();
    return ListTile(
      title: Text(l10n.keyboardType),
      subtitle: Text(l10n.keyboardCompatibility, style: UIs.textGrey),
      trailing: ListenableBuilder(
        listenable: _keyboardType,
        builder: (_, __) => PopupMenuButton<int>(
          key: _keyboardTypeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _keyboardType.value,
          onSelected: (idx) {
            _keyboardType.value = idx;
            _setting.keyboardType.put(idx);
          },
          child: Text(
            names[_keyboardType.value],
            style: UIs.text15,
          ),
        ),
      ),
      onTap: () {
        _keyboardTypeKey.currentState?.showButtonMenu();
      },
    );
  }

  Widget _buildSSHVirtKeys() {
    return ListTile(
      title: Text(l10n.editVirtKeys),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoute.sshVirtKeySetting().go(context),
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
      title: Text(l10n.openLastPath),
      subtitle: Text(l10n.openLastPathTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sftpOpenLastPath),
    );
  }

  Widget _buildSftpShowFoldersFirst() {
    return ListTile(
      title: Text(l10n.sftpShowFoldersFirst),
      trailing: StoreSwitch(prop: _setting.sftpShowFoldersFirst),
    );
  }

  Widget _buildNetViewType() {
    final items = NetViewType.values
        .map((e) => PopupMenuItem(
              value: e,
              child: Text(e.toStr),
            ))
        .toList();
    return ListTile(
      title: Text(l10n.netViewType),
      trailing: ListenableBuilder(
        listenable: _netViewType,
        builder: (_, __) => PopupMenuButton<NetViewType>(
          key: _netViewTypeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _netViewType.value,
          onSelected: (idx) {
            _netViewType.value = idx;
            _setting.netViewType.put(idx);
          },
          child: Text(
            _netViewType.value.toStr,
            style: UIs.text15,
          ),
        ),
      ),
      onTap: () {
        _netViewTypeKey.currentState?.showButtonMenu();
      },
    );
  }

  Widget _buildDeleteServers() {
    return ListTile(
      title: Text(l10n.deleteServers),
      trailing: const Icon(Icons.delete_forever),
      onTap: () async {
        context.showRoundDialog<List<String>>(
          title: Text(l10n.choose),
          child: SingleChildScrollView(
            child: StatefulBuilder(builder: (ctx, setState) {
              final keys = Stores.server.box.keys.toList();
              keys.removeWhere((element) => element == BoxX.lastModifiedKey);
              final all = keys.map(
                (e) => TextButton(
                  onPressed: () => context.showRoundDialog(
                    title: Text(l10n.attention),
                    child: Text(l10n.askContinue(
                      '${l10n.delete} ${l10n.server}($e)',
                    )),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Pros.server.delServer(e);
                          ctx.pop();
                          setState(() {});
                        },
                        child: Text(l10n.ok),
                      )
                    ],
                  ),
                  child: Text(e),
                ),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: all.toList(),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildTextScaler() {
    final ctrl = TextEditingController(text: _textScaler.value.toString());
    return ListTile(
      title: Text(l10n.textScaler),
      subtitle: Text(l10n.textScalerTip, style: UIs.textGrey),
      trailing: ListenableBuilder(
        listenable: _textScaler,
        builder: (_, __) => Text(
          _textScaler.value.toString(),
          style: UIs.text15,
        ),
      ),
      onTap: () => context.showRoundDialog(
        title: Text(l10n.textScaler),
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
    _textScaler.value = val;
    _setting.textFactor.put(val);
    RebuildNodes.app.rebuild();
    context.pop();
  }

  Widget _buildServerFuncBtns() {
    return ExpandTile(
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
      onTap: () => AppRoute.serverFuncBtnsOrder().go(context),
    );
  }

  Widget _buildServerSeq() {
    return ListTile(
      title: Text(l10n.serverOrder),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoute.serverOrder().go(context),
    );
  }

  Widget _buildServerDetailCardSeq() {
    return ListTile(
      title: Text(l10n.serverDetailOrder),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => AppRoute.serverDetailOrder().go(context),
    );
  }

  Widget _buildEditorFontSize() {
    return ListenableBuilder(
      listenable: _editorFontSize,
      builder: (_, __) => ListTile(
        title: Text(l10n.fontSize),
        trailing: Text(
          _editorFontSize.value.toString(),
          style: UIs.text15,
        ),
        onTap: () =>
            _showFontSizeDialog(_editorFontSize, _setting.editorFontSize),
      ),
    );
  }

  void _showFontSizeDialog(
    ValueNotifier<double> notifier,
    StorePropertyBase<double> property,
  ) {
    final ctrller = TextEditingController(text: notifier.value.toString());
    void onSave() {
      context.pop();
      final fontSize = double.tryParse(ctrller.text);
      if (fontSize == null) {
        context.showRoundDialog(
          title: Text(l10n.failed),
          child: Text('Parsed failed: ${ctrller.text}'),
        );
        return;
      }
      notifier.value = fontSize;
      property.put(fontSize);
    }

    context.showRoundDialog(
      title: Text(l10n.fontSize),
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
      title: const Text('rm -r'),
      subtitle: Text(l10n.sftpRmrDirSummary, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sftpRmrDir),
    );
  }

  // Widget _buildDoubleColumnServersPage() {
  //   return ListTile(
  //     title: Text(l10n.doubleColumnMode),
  //     trailing: StoreSwitch(prop: _setting.doubleColumnServersPage),
  //   );
  // }

  Widget _buildPlatformSetting() {
    return ListTile(
      title: Text('${OS.type} ${l10n.setting}'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        switch (OS.type) {
          case OS.android:
            AppRoute.androidSettings().go(context);
            break;
          case OS.ios:
            AppRoute.iosSettings().go(context);
            break;
          default:
            break;
        }
      },
    );
  }

  Widget _buildEditorHighlight() {
    return ListTile(
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
      title: Text(l10n.usePodmanByDefault),
      trailing: StoreSwitch(prop: _setting.usePodman),
    );
  }

  Widget _buildContainerTrySudo() {
    return ListTile(
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
      title: Text(l10n.parseContainerStats),
      subtitle: Text(l10n.parseContainerStatsTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.containerParseStat),
    );
  }
}
