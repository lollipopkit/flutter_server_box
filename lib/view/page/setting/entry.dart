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
import '../../widget/custom_appbar.dart';
import '../../widget/input_field.dart';
import '../../widget/cardx.dart';
import '../../widget/store_switch.dart';
import '../../widget/value_notifier.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

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
  final _rotateQuarterKey = GlobalKey<PopupMenuButtonState<int>>();
  final _netViewTypeKey = GlobalKey<PopupMenuButtonState<NetViewType>>();
  final _setting = Stores.setting;

  final _selectedColorValue = ValueNotifier(0);
  final _nightMode = ValueNotifier(0);
  final _maxRetryCount = ValueNotifier(0);
  final _updateInterval = ValueNotifier(0);
  final _termFontSize = ValueNotifier(0.0);
  final _editorFontSize = ValueNotifier(0.0);
  final _localeCode = ValueNotifier('');
  final _editorTheme = ValueNotifier('');
  final _editorDarkTheme = ValueNotifier('');
  final _keyboardType = ValueNotifier(0);
  final _rotateQuarter = ValueNotifier(0);
  final _netViewType = ValueNotifier(NetViewType.speed);

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
  void initState() {
    super.initState();
    _nightMode.value = _setting.themeMode.fetch();
    _updateInterval.value = _setting.serverStatusUpdateInterval.fetch();
    _maxRetryCount.value = _setting.maxRetryCount.fetch();
    _selectedColorValue.value = _setting.primaryColor.fetch();
    _termFontSize.value = _setting.termFontSize.fetch();
    _editorFontSize.value = _setting.editorFontSize.fetch();
    _editorTheme.value = _setting.editorTheme.fetch();
    _editorDarkTheme.value = _setting.editorDarkTheme.fetch();
    _keyboardType.value = _setting.keyboardType.fetch();
    _rotateQuarter.value = _setting.fullScreenRotateQuarter.fetch();
    _netViewType.value = _setting.netViewType.fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.setting),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 17),
            child: InkWell(
              onTap: () => context.showRoundDialog(
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

              /// Only for debug, this will cause the app to crash
              // onDoubleTap: () => context.showRoundDialog(
              //   title: Text(l10n.attention),
              //   child: Text(l10n.sureDelete(l10n.all)),
              //   actions: [
              //     TextButton(
              //       onPressed: () {
              //         Stores.docker.box.deleteFromDisk();
              //         Stores.server.box.deleteFromDisk();
              //         Stores.setting.box.deleteFromDisk();
              //         Stores.history.box.deleteFromDisk();
              //         Stores.snippet.box.deleteFromDisk();
              //         Stores.key.box.deleteFromDisk();
              //         exit(0);
              //       },
              //       child: Text(l10n.ok,
              //           style: const TextStyle(color: Colors.red)),
              //     ),
              //   ],
              // ),
              child: const Icon(Icons.delete),
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
          _buildTitle('SSH'),
          _buildSSH(),
          _buildTitle('SFTP'),
          _buildSFTP(),
          _buildTitle(l10n.editor),
          _buildEditor(),
          _buildTitle(l10n.fullScreen),
          _buildFullScreen(),
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
    ];

    /// Platform specific settings
    if (OS.hasSettings) {
      children.add(_buildPlatformSetting());
    }
    return Column(
      children: children.map((e) => CardX(e)).toList(),
    );
  }

  Widget _buildFullScreen() {
    return Column(
      children: [
        _buildFullScreenSwitch(),
        _buildFullScreenJitter(),
        _buildFulScreenRotateQuarter(),
      ].map((e) => CardX(e)).toList(),
    );
  }

  Widget _buildServer() {
    return Column(
      children: [
        _buildServerFuncBtns(),
        _buildSequence(),
        _buildNetViewType(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        //_buildDiskIgnorePath(),
        _buildDeleteServers(),
        //if (isDesktop) _buildDoubleColumnServersPage(),
      ].map((e) => CardX(e)).toList(),
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
        _buildSSHVirtKeys(),
      ].map((e) => CardX(e)).toList(),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        _buildEditorFontSize(),
        _buildEditorTheme(),
        _buildEditorDarkTheme(),
        _buildEditorHighlight(),
      ].map((e) => CardX(e)).toList(),
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
          onTap: () => doUpdate(ctx),
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
        child: Text('$index ${l10n.second}'),
      ),
      growable: false,
    ).toList();

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
      trailing: ValueBuilder(
        listenable: _updateInterval,
        build: () => PopupMenuButton(
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
            style: UIs.textSize15,
          ),
        ),
      ),
    );
  }

  Widget _buildAppColor() {
    return ListTile(
      trailing: ClipOval(
        child: ValueBuilder(
          listenable: _selectedColorValue,
          build: () => Container(
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
                    func: (_) => setState(() {}),
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
      trailing: ValueBuilder(
        build: () => PopupMenuButton(
          key: _maxRetryKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _maxRetryCount.value,
          onSelected: (int val) {
            _maxRetryCount.value = val;
            _setting.maxRetryCount.put(_maxRetryCount.value);
          },
          child: Text(
            '${_maxRetryCount.value} ${l10n.times}',
            style: UIs.textSize15,
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
      trailing: ValueBuilder(
        listenable: _nightMode,
        build: () => PopupMenuButton(
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
            style: UIs.textSize15,
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
        style: UIs.textSize15,
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
    return ValueBuilder(
      listenable: _termFontSize,
      build: () => ListTile(
        title: Text(l10n.fontSize),
        trailing: Text(
          _termFontSize.value.toString(),
          style: UIs.textSize15,
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
      trailing: ValueBuilder(
        listenable: _localeCode,
        build: () => PopupMenuButton(
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
            style: UIs.textSize15,
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
      trailing: ValueBuilder(
        listenable: _editorTheme,
        build: () => PopupMenuButton(
          key: _editorThemeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _editorTheme.value,
          onSelected: (String idx) {
            _editorTheme.value = idx;
            _setting.editorTheme.put(idx);
          },
          child: Text(
            _editorTheme.value,
            style: UIs.textSize15,
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
      trailing: ValueBuilder(
        listenable: _editorDarkTheme,
        build: () => PopupMenuButton(
          key: _editorDarkThemeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _editorDarkTheme.value,
          onSelected: (String idx) {
            _editorDarkTheme.value = idx;
            _setting.editorDarkTheme.put(idx);
          },
          child: Text(
            _editorDarkTheme.value,
            style: UIs.textSize15,
          ),
        ),
      ),
      onTap: () {
        _editorDarkThemeKey.currentState?.showButtonMenu();
      },
    );
  }

  Widget _buildFullScreenSwitch() {
    return ListTile(
      title: Text(l10n.fullScreen),
      trailing: StoreSwitch(
        prop: _setting.fullScreen,
        func: (_) => RebuildNodes.app.rebuild(),
      ),
    );
  }

  Widget _buildFullScreenJitter() {
    return ListTile(
      title: Text(l10n.fullScreenJitter),
      subtitle: Text(l10n.fullScreenJitterHelp, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.fullScreenJitter),
    );
  }

  Widget _buildFulScreenRotateQuarter() {
    final degrees = List.generate(4, (idx) => '${idx * 90}°').toList();
    final items = List.generate(4, (idx) {
      return PopupMenuItem<int>(
        value: idx,
        child: Text(degrees[idx]),
      );
    }).toList();

    return ListTile(
      title: Text(l10n.rotateAngel),
      onTap: () {
        _rotateQuarterKey.currentState?.showButtonMenu();
      },
      trailing: ValueBuilder(
        listenable: _rotateQuarter,
        build: () => PopupMenuButton(
          key: _rotateQuarterKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _rotateQuarter.value,
          onSelected: (int idx) {
            _rotateQuarter.value = idx;
            _setting.fullScreenRotateQuarter.put(idx);
          },
          child: Text(
            degrees[_rotateQuarter.value],
            style: UIs.textSize15,
          ),
        ),
      ),
    );
  }

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
      trailing: ValueBuilder(
        listenable: _keyboardType,
        build: () => PopupMenuButton<int>(
          key: _keyboardTypeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _keyboardType.value,
          onSelected: (idx) {
            _keyboardType.value = idx;
            _setting.keyboardType.put(idx);
          },
          child: Text(
            names[_keyboardType.value],
            style: UIs.textSize15,
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
      ].map((e) => CardX(e)).toList(),
    );
  }

  Widget _buildSftpOpenLastPath() {
    return ListTile(
      title: Text(l10n.openLastPath),
      subtitle: Text(l10n.openLastPathTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sftpOpenLastPath),
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
      trailing: ValueBuilder(
        listenable: _netViewType,
        build: () => PopupMenuButton<NetViewType>(
          key: _netViewTypeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _netViewType.value,
          onSelected: (idx) {
            _netViewType.value = idx;
            _setting.netViewType.put(idx);
          },
          child: Text(
            _netViewType.value.toStr,
            style: UIs.textSize15,
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
        final all = Stores.server.box.keys.map(
          (e) => TextButton(
            onPressed: () => context.showRoundDialog(
              title: Text(l10n.attention),
              child: Text(l10n.askContinue(
                '${l10n.delete} ${l10n.server}($e)',
              )),
              actions: [
                TextButton(
                  onPressed: () => Pros.server.delServer(e),
                  child: Text(l10n.ok),
                )
              ],
            ),
            child: Text(e),
          ),
        );
        context.showRoundDialog<List<String>>(
          title: Text(l10n.choose),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: all.toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerFuncBtns() {
    return ExpandTile(
      title: Text(l10n.serverFuncBtns),
      subtitle: Text(
        '${l10n.location} / ${l10n.displayName}',
        style: UIs.textSize13Grey,
      ),
      children: [
        ListTile(
          title: Text(l10n.location),
          subtitle:
              Text(l10n.moveOutServerFuncBtnsHelp, style: UIs.textSize13Grey),
          trailing: StoreSwitch(prop: _setting.moveOutServerTabFuncBtns),
        ),
        ListTile(
          title: Text(l10n.displayName),
          trailing: StoreSwitch(prop: _setting.serverFuncBtnsDisplayName),
        ),
      ],
    );
  }

  Widget _buildSequence() {
    return ExpandTile(
      title: Text(l10n.sequence),
      subtitle: Text(
        '${l10n.serverOrder} / ${l10n.serverDetailOrder} ...',
        style: UIs.textGrey,
      ),
      children: [
        ListTile(
          title: Text(l10n.serverOrder),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () => AppRoute.serverOrder().go(context),
        ),
        ListTile(
          title: Text(l10n.serverDetailOrder),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () => AppRoute.serverDetailOrder().go(context),
        ),
      ],
    );
  }

  Widget _buildEditorFontSize() {
    return ValueBuilder(
      listenable: _editorFontSize,
      build: () => ListTile(
        title: Text(l10n.fontSize),
        trailing: Text(
          _editorFontSize.value.toString(),
          style: UIs.textSize15,
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
}
