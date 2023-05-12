import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/model/app/tab.dart';

import '../../core/utils/misc.dart';
import '../../core/utils/platform.dart';
import '../../data/model/ssh/terminal_color.dart';
import '../../core/update.dart';
import '../../core/utils/ui.dart';
import '../../data/provider/app.dart';
import '../../data/provider/server.dart';
import '../../data/res/build_data.dart';
import '../../data/res/color.dart';
import '../../data/res/path.dart';
import '../../data/res/ui.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';
import '../widget/future_widget.dart';
import '../widget/popup_menu.dart';
import '../widget/round_rect_card.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final themeKey = GlobalKey<PopupMenuButtonState<int>>();
  final startPageKey = GlobalKey<PopupMenuButtonState<int>>();
  final updateIntervalKey = GlobalKey<PopupMenuButtonState<int>>();
  final termThemeKey = GlobalKey<PopupMenuButtonState<int>>();
  final maxRetryKey = GlobalKey<PopupMenuButtonState<int>>();

  late final SettingStore _setting;
  late final ServerProvider _serverProvider;
  late MediaQueryData _media;
  late S _s;

  late int _selectedColorValue;
  late int _launchPageIdx;
  late int _termThemeIdx;
  late int _nightMode;
  late int _maxRetryCount;
  late int _updateInterval;

  String? _pushToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    _setting = locator<SettingStore>();
    _launchPageIdx = _setting.launchPage.fetch()!;
    _termThemeIdx = _setting.termColorIdx.fetch()!;
    _nightMode = _setting.themeMode.fetch()!;
    _updateInterval = _setting.serverStatusUpdateInterval.fetch()!;
    _maxRetryCount = _setting.maxRetryCount.fetch()!;
    _selectedColorValue = _setting.primaryColor.fetch()!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.setting),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          // App
          _buildTitle('App'),
          _buildApp(),
          // Server
          _buildTitle(_s.server),
          _buildServer(),
          // SSH
          _buildTitle('SSH'),
          _buildSSH(),
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
          style: grey,
        ),
      ),
    );
  }

  Widget _buildApp() {
    final children = [
      _buildThemeMode(),
      _buildAppColorPreview(),
      _buildLaunchPage(),
      _buildCheckUpdate(),
    ];
    if (isIOS) {
      children.add(_buildPushToken());
    }
    if (isAndroid) {
      children.add(_buildBgRun());
    }
    return Column(
      children: children.map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildServer() {
    return Column(
      children: [
        _buildDistLogoSwitch(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildSSH() {
    return Column(
      children: [
        _buildTermTheme(),
        _buildFont(),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildDistLogoSwitch() {
    return ListTile(
      title: Text(
        _s.showDistLogo,
      ),
      subtitle: Text(
        _s.onServerDetailPage,
        style: grey,
      ),
      contentPadding: const EdgeInsets.only(left: 17, right: 11),
      trailing: buildSwitch(context, _setting.showDistLogo),
    );
  }

  Widget _buildCheckUpdate() {
    return Consumer<AppProvider>(
      builder: (_, app, __) {
        String display;
        if (app.newestBuild != null) {
          if (app.newestBuild! > BuildData.build) {
            display = _s.versionHaveUpdate(app.newestBuild!);
          } else {
            display = _s.versionUpdated(BuildData.build);
          }
        } else {
          display = _s.versionUnknownUpdate(BuildData.build);
        }
        return ListTile(
          trailing: const Icon(Icons.keyboard_arrow_right),
          title: Text(
            display,
          ),
          onTap: () => doUpdate(context, force: true),
        );
      },
    );
  }

  Widget _buildUpdateInterval() {
    final items = List.generate(
      10,
      (index) => PopupMenuItem(
        value: index,
        child: Text('$index ${_s.second}'),
      ),
      growable: false,
    ).toList();

    return ListTile(
      title: Text(
        _s.updateServerStatusInterval,
      ),
      subtitle: Text(
        _s.willTakEeffectImmediately,
        style: grey,
      ),
      onTap: () {
        updateIntervalKey.currentState?.showButtonMenu();
      },
      trailing: PopupMenuButton(
        key: updateIntervalKey,
        itemBuilder: (BuildContext context) => items,
        initialValue: _updateInterval,
        onSelected: (int val) {
          setState(() {
            _updateInterval = val;
          });
          _setting.serverStatusUpdateInterval.put(_updateInterval.toInt());
          _serverProvider.startAutoRefresh();
          if (val == 0) {
            showSnackBar(context, Text(_s.updateIntervalEqual0));
          }
        },
        child: Text(
          '${_updateInterval.toInt()} ${_s.second}',
        ),
      ),
    );
  }

  Widget _buildAppColorPreview() {
    return ListTile(
      trailing: ClipOval(
        child: Container(
          color: primaryColor,
          height: 27,
          width: 27,
        ),
      ),
      title: Text(
        _s.appPrimaryColor,
      ),
      onTap: () async {
        await showRoundDialog(
          context: context,
          child: MaterialColorPicker(
            shrinkWrap: true,
            allowShades: true,
            onColorChange: (color) {
              _selectedColorValue = color.value;
            },
            selectedColor: primaryColor,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _setting.primaryColor.put(_selectedColorValue);
                Navigator.pop(context);
                _showRestartSnackbar();
              },
              child: Text(_s.ok),
            )
          ],
        );
      },
    );
  }

  Widget _buildLaunchPage() {
    final items = AppTab.values
        .map(
          (e) => PopupMenuItem(
            value: e.index,
            child: Text(tabTitleName(context, e.index)),
          ),
        )
        .toList();

    return ListTile(
      title: Text(
        _s.launchPage,
      ),
      onTap: () {
        startPageKey.currentState?.showButtonMenu();
      },
      trailing: PopupMenuButton(
        key: startPageKey,
        itemBuilder: (BuildContext context) => items,
        initialValue: _launchPageIdx,
        onSelected: (int idx) {
          setState(() {
            _launchPageIdx = idx;
          });
          _setting.launchPage.put(_launchPageIdx);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _media.size.width * 0.35),
          child: Text(
            tabTitleName(context, _launchPageIdx),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }

  Widget _buildTermTheme() {
    final items = TerminalColorsPlatform.values
        .map(
          (e) => PopupMenuItem<int>(
            value: e.index,
            child: Text(e.name),
          ),
        )
        .toList();
    return ListTile(
      title: Text(
        _s.termTheme,
      ),
      onTap: () {
        termThemeKey.currentState?.showButtonMenu();
      },
      trailing: PopupMenuButton(
        key: termThemeKey,
        itemBuilder: (BuildContext context) => items,
        initialValue: _termThemeIdx,
        onSelected: (int idx) {
          setState(() {
            _termThemeIdx = idx;
          });
          _setting.termColorIdx.put(idx);
        },
        child: Text(
          TerminalColorsPlatform.values[_termThemeIdx].name,
        ),
      ),
    );
  }

  Widget _buildMaxRetry() {
    final items = List.generate(
      10,
      (index) => PopupMenuItem(
        value: index,
        child: Text('$index ${_s.times}'),
      ),
      growable: false,
    ).toList();
    final help =
        _maxRetryCount == 0 ? _s.maxRetryCountEqual0 : _s.canPullRefresh;

    return ListTile(
      title: Text(
        _s.maxRetryCount,
        textAlign: TextAlign.start,
      ),
      subtitle: Text(help, style: grey),
      onTap: () {
        maxRetryKey.currentState?.showButtonMenu();
      },
      trailing: PopupMenuButton(
        key: maxRetryKey,
        itemBuilder: (BuildContext context) => items,
        initialValue: _maxRetryCount,
        onSelected: (int val) {
          setState(() {
            _maxRetryCount = val;
          });
          _setting.maxRetryCount.put(_maxRetryCount);
        },
        child: Text(
          '${_maxRetryCount.toInt()} ${_s.times}',
        ),
      ),
    );
  }

  Widget _buildThemeMode() {
    final items = ThemeMode.values.map(
      (e) {
        final str = _buildThemeModeStr(e.index);
        return PopupMenuItem(
          value: e.index,
          child: Text(str),
        );
      },
    ).toList();

    return ListTile(
      title: Text(
        _s.themeMode,
      ),
      onTap: () {
        themeKey.currentState?.showButtonMenu();
      },
      trailing: PopupMenuButton(
        key: themeKey,
        itemBuilder: (BuildContext context) => items,
        initialValue: _nightMode,
        onSelected: (int idx) {
          setState(() {
            _nightMode = idx;
          });
          _setting.themeMode.put(_nightMode);
        },
        child: Text(_buildThemeModeStr(_nightMode)),
      ),
    );
  }

  String _buildThemeModeStr(int n) {
    switch (n) {
      case 1:
        return _s.light;
      case 2:
        return _s.dark;
      default:
        return _s.auto;
    }
  }

  Widget _buildPushToken() {
    return ListTile(
      title: Text(
        _s.pushToken,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.zero,
        onPressed: () {
          if (_pushToken != null) {
            copy(_pushToken!);
            showSnackBar(context, Text(_s.success));
          } else {
            showSnackBar(context, Text(_s.getPushTokenFailed));
          }
        },
      ),
      subtitle: FutureWidget<String?>(
        future: getToken(),
        loading: Text(_s.gettingToken),
        error: (error, trace) => Text('${_s.error}: $error'),
        noData: Text(_s.nullToken),
        success: (text) {
          _pushToken = text;
          return Text(
            text ?? _s.nullToken,
            style: grey,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        },
      ),
    );
  }

  Widget _buildFont() {
    return ListTile(
      title: Text(_s.chooseFontFile),
      trailing: Text(getFileName(_setting.fontPath.fetch()) ?? _s.notSelected),
      onTap: () {
        showRoundDialog(
          context: context,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: () async => await _pickFontFile(),
                child: Text(_s.pickFile),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _setting.fontPath.delete();
                  context.pop();
                  _showRestartSnackbar();
                }),
                child: Text(_s.clear),
              )
            ],
          ),
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
        final fontDir_ = await fontDir;
        final fontFile = File(path);
        final newPath = '${fontDir_.path}/${path.split('/').last}';
        await fontFile.copy(newPath);
        _setting.fontPath.put(newPath);
      }

      context.pop();
      setState(() {});
      _showRestartSnackbar();
      return;
    }
    showSnackBar(context, Text(_s.failed));
  }

  void _showRestartSnackbar() {
    showSnackBarWithAction(
      context,
      '${_s.success}\n${_s.needRestart}',
      _s.restart,
      () => rebuildAll(context),
    );
  }

  Widget _buildBgRun() {
    return ListTile(
      title: Text(_s.bgRun),
      trailing: buildSwitch(context, _setting.bgRun),
    );
  }
}
