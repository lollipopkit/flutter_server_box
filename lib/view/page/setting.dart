import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:provider/provider.dart';

import '../../core/update.dart';
import '../../core/utils/ui.dart';
import '../../data/provider/app.dart';
import '../../data/provider/server.dart';
import '../../data/res/build_data.dart';
import '../../data/res/font_style.dart';
import '../../data/res/tab.dart';
import '../../data/store/setting.dart';
import '../../generated/l10n.dart';
import '../../locator.dart';
import '../widget/primary_color.dart';
import '../widget/round_rect_card.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late final SettingStore _setting;
  late int _selectedColorValue;
  late int _launchPageIdx;
  late final ServerProvider _serverProvider;
  late MediaQueryData _media;
  late ThemeData _theme;
  late S _s;

  var _updateInterval = 5.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
    _s = S.of(context);
  }

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    _setting = locator<SettingStore>();
    _launchPageIdx = _setting.launchPage.fetch()!;
    _updateInterval = _setting.serverStatusUpdateInterval.fetch()!.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.setting),
      ),
      body: PrimaryColor(
        builder: (context, primaryColor) {
          return ListView(
            padding: const EdgeInsets.all(17),
            children: [
              _buildAppColorPreview(primaryColor),
              _buildUpdateInterval(primaryColor),
              _buildCheckUpdate(),
              _buildLaunchPage(primaryColor),
              _buildDistLogoSwitch(),
            ].map((e) => RoundRectCard(e)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildDistLogoSwitch() {
    return ListTile(
      title: Text(
        _s.showDistLogo,
        style: textSize13,
      ),
      subtitle: Text(
        _s.onServerDetailPage,
        style: textSize13Grey,
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
            style: textSize13,
            textAlign: TextAlign.start,
          ),
          onTap: () => doUpdate(context, force: true),
        );
      },
    );
  }

  Widget _buildUpdateInterval(Color priColor) {
    return ExpansionTile(
      textColor: priColor,
      title: Text(
        _s.updateServerStatusInterval,
        style: textSize13,
        textAlign: TextAlign.start,
      ),
      subtitle: Text(
        _s.willTakEeffectImmediately,
        style: textSize13Grey,
      ),
      trailing: Text('${_updateInterval.toInt()} ${_s.second}'),
      children: [
        Slider(
          thumbColor: priColor,
          activeColor: priColor.withOpacity(0.7),
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
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              )
            : const SizedBox(),
        const SizedBox(
          height: 13,
        )
      ],
    );
  }

  Widget _buildAppColorPreview(Color priColor) {
    return ExpansionTile(
      textColor: priColor,
      trailing: ClipOval(
        child: Container(
          color: priColor,
          height: 27,
          width: 27,
        ),
      ),
      title: Text(
        _s.appPrimaryColor,
        style: textSize13,
      ),
      children: [_buildAppColorPicker(priColor), _buildColorPickerConfirmBtn()],
    );
  }

  Widget _buildAppColorPicker(Color selected) {
    return MaterialColorPicker(
        shrinkWrap: true,
        onColorChange: (Color color) {
          _selectedColorValue = color.value;
        },
        selectedColor: selected);
  }

  Widget _buildColorPickerConfirmBtn() {
    return IconButton(
      icon: const Icon(Icons.save),
      onPressed: (() {
        _setting.primaryColor.put(_selectedColorValue);
        setState(() {});
      }),
    );
  }

  Widget _buildLaunchPage(Color priColor) {
    return ExpansionTile(
      textColor: priColor,
      title: Text(
        _s.launchPage,
        style: textSize13,
      ),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _media.size.width * 0.35),
        child: Text(
          tabTitleName(context, _launchPageIdx),
          style: textSize13,
          textAlign: TextAlign.right,
        ),
      ),
      children: tabs
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tabTitleName(context, tabs.indexOf(e)),
                style: TextStyle(
                    fontSize: 14,
                    color: _theme.textTheme.bodyMedium!.color!.withAlpha(177)),
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
}
