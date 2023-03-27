import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:provider/provider.dart';

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
import '../../data/res/tab.dart';
import '../../data/res/ui.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';
import '../widget/future_widget.dart';
import '../widget/round_rect_card.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late final SettingStore _setting;
  late final ServerProvider _serverProvider;
  late MediaQueryData _media;
  late S _s;

  late int _selectedColorValue;
  late int _launchPageIdx;
  late int _termThemeIdx;
  late int _nightMode;
  late double _maxRetryCount;
  late double _updateInterval;

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
    _updateInterval = _setting.serverStatusUpdateInterval.fetch()!.toDouble();
    _maxRetryCount = _setting.maxRetryCount.fetch()!.toDouble();
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
      _buildFont(),
      _buildCheckUpdate(),
    ];
    if (isIOS) {
      children.add(_buildPushToken());
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
        _buildTermTheme(),
        _buildMaxRetry(),
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
    return ExpansionTile(
      textColor: primaryColor,
      title: Text(
        _s.updateServerStatusInterval,
      ),
      subtitle: Text(
        _s.willTakEeffectImmediately,
        style: grey,
      ),
      trailing: Text(
        '${_updateInterval.toInt()} ${_s.second}',
      ),
      children: [
        Slider(
          thumbColor: primaryColor,
          activeColor: primaryColor.withOpacity(0.7),
          min: 0,
          max: 10,
          value: _updateInterval,
          onChanged: (newValue) {
            setState(() {
              _updateInterval = newValue;
            });
          },
          onChangeEnd: (val) {
            _setting.serverStatusUpdateInterval.put(val.toInt());
            _serverProvider.startAutoRefresh();
          },
          label: '${_updateInterval.toInt()} ${_s.second}',
          divisions: 10,
        ),
        const SizedBox(
          height: 3,
        ),
        _updateInterval == 0.0
            ? Text(
                _s.updateIntervalEqual0,
                style: grey,
                textAlign: TextAlign.center,
              )
            : const SizedBox(),
        const SizedBox(
          height: 13,
        )
      ],
    );
  }

  Widget _buildAppColorPreview() {
    return ExpansionTile(
      textColor: primaryColor,
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
      children: [_buildAppColorPicker(), _buildColorPickerConfirmBtn()],
    );
  }

  Widget _buildAppColorPicker() {
    return MaterialColorPicker(
      shrinkWrap: true,
      onColorChange: (Color color) {
        _selectedColorValue = color.value;
      },
      selectedColor: primaryColor,
    );
  }

  Widget _buildColorPickerConfirmBtn() {
    return IconButton(
      icon: const Icon(Icons.save),
      onPressed: (() {
        _setting.primaryColor.put(_selectedColorValue);
        _showRestartSnackbar();
      }),
    );
  }

  Widget _buildLaunchPage() {
    return ExpansionTile(
      childrenPadding: const EdgeInsets.only(left: 17, right: 7),
      textColor: primaryColor,
      title: Text(
        _s.launchPage,
      ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _media.size.width * 0.35),
        child: Text(
          tabTitleName(context, _launchPageIdx),
          textAlign: TextAlign.right,
        ),
      ),
      children: tabs
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tabTitleName(context, tabs.indexOf(e)),
              ),
              trailing: _buildRadio(tabs.indexOf(e)),
            ),
          )
          .toList(),
    );
  }

  Radio _buildRadio(int index) {
    return Radio<int>(
      value: index,
      groupValue: _launchPageIdx,
      onChanged: (int? value) {
        setState(() {
          _launchPageIdx = value!;
          _setting.launchPage.put(value);
        });
      },
    );
  }

  Widget _buildTermTheme() {
    return ExpansionTile(
      textColor: primaryColor,
      childrenPadding: const EdgeInsets.only(left: 17),
      title: Text(
        _s.termTheme,
      ),
      trailing: Text(
        TerminalColorsPlatform.values[_termThemeIdx].name,
      ),
      children: _buildTermThemeRadioList(),
    );
  }

  List<Widget> _buildTermThemeRadioList() {
    return TerminalColorsPlatform.values
        .map(
          (e) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              e.name,
            ),
            trailing: _buildTermThemeRadio(e),
          ),
        )
        .toList();
  }

  Radio _buildTermThemeRadio(TerminalColorsPlatform platform) {
    return Radio<int>(
      value: platform.index,
      groupValue: _termThemeIdx,
      onChanged: (int? value) {
        setState(() {
          value ??= 0;
          _termThemeIdx = value!;
          _setting.termColorIdx.put(value!);
        });
      },
    );
  }

  Widget _buildMaxRetry() {
    return ExpansionTile(
      textColor: primaryColor,
      title: Text(
        _s.maxRetryCount,
        textAlign: TextAlign.start,
      ),
      trailing: Text(
        '${_maxRetryCount.toInt()} ${_s.times}',
      ),
      children: [
        Slider(
          thumbColor: primaryColor,
          activeColor: primaryColor.withOpacity(0.7),
          min: 0,
          max: 10,
          value: _maxRetryCount,
          onChanged: (newValue) {
            setState(() {
              _maxRetryCount = newValue;
            });
          },
          onChangeEnd: (val) {
            _setting.maxRetryCount.put(val.toInt());
          },
          label: '${_maxRetryCount.toInt()} ${_s.times}',
          divisions: 10,
        ),
        const SizedBox(
          height: 3,
        ),
        _maxRetryCount == 0.0
            ? Text(
                _s.maxRetryCountEqual0,
                style: grey,
                textAlign: TextAlign.center,
              )
            : const SizedBox(),
        const SizedBox(
          height: 13,
        )
      ],
    );
  }

  Widget _buildThemeMode() {
    return ExpansionTile(
      textColor: primaryColor,
      title: Text(
        _s.themeMode,
      ),
      trailing: Text(
        _buildThemeModeStr(_nightMode),
      ),
      children: [
        Slider(
          thumbColor: primaryColor,
          activeColor: primaryColor.withOpacity(0.7),
          min: 0,
          max: 2,
          value: _nightMode.toDouble(),
          onChanged: (newValue) {
            setState(() {
              _nightMode = newValue.toInt();
            });
          },
          onChangeEnd: (val) {
            _setting.themeMode.put(val.toInt());
          },
          label: _buildThemeModeStr(_nightMode),
          divisions: 2,
        ),
      ],
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
      trailing: TextButton(
        child: Text(_s.copy),
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
    return ExpansionTile(
      title: Text(_s.chooseFontFile),
      trailing: Text(getFileName(_setting.fontPath.fetch()) ?? _s.notSelected),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              onPressed: () async => _pickFontFile(),
              child: Text(_s.pickFile),
            ),
            TextButton(
              onPressed: () => setState(() {
                _setting.fontPath.delete();
                _showRestartSnackbar();
              }),
              child: Text(_s.clear),
            )
          ],
        )
      ],
    );
  }

  Future<void> _pickFontFile() async {
    final path = await pickOneFile();
    if (path != null) {
      final fontDir_ = await fontDir;
      final fontFile = File(path);
      final newPath = '${fontDir_.path}/${path.split('/').last}';
      await fontFile.copy(newPath);
      _setting.fontPath.put(newPath);
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
}
