import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/platform/auth.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/page/setting/platform_pub.dart';
import 'package:toolbox/view/widget/custom_appbar.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/cardx.dart';
import 'package:toolbox/view/widget/store_switch.dart';

class AndroidSettingsPage extends StatefulWidget {
  const AndroidSettingsPage({Key? key}) : super(key: key);

  @override
  _AndroidSettingsPageState createState() => _AndroidSettingsPageState();
}

class _AndroidSettingsPageState extends State<AndroidSettingsPage> {
  late SharedPreferences _sp;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) => _sp = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Android'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          _buildBgRun(),
          _buildAndroidWidgetSharedPreference(),
          if (BioAuth.isPlatformSupported)
            PlatformPublicSettings.buildBioAuth(),
        ].map((e) => CardX(e)).toList(),
      ),
    );
  }

  Widget _buildBgRun() {
    return ListTile(
      title: Text(l10n.bgRun),
      trailing: StoreSwitch(prop: Stores.setting.bgRun),
    );
  }

  void _saveWidgetSP(String data, Map<String, String> old) {
    context.pop();
    try {
      final map = Map<String, String>.from(json.decode(data));
      final keysDel = old.keys.toSet().difference(map.keys.toSet());
      for (final key in keysDel) {
        _sp.remove(key);
      }
      map.forEach((key, value) {
        _sp.setString(key, value);
      });
      context.showSnackBar(l10n.success);
    } catch (e) {
      context.showSnackBar(e.toString());
    }
  }

  Widget _buildAndroidWidgetSharedPreference() {
    return ListTile(
      title: Text(l10n.homeWidgetUrlConfig),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        final data = <String, String>{};
        _sp.getKeys().forEach((key) {
          final val = _sp.getString(key);
          if (val != null) {
            data[key] = val;
          }
        });
        final ctrl = TextEditingController(text: json.encode(data));
        context.showRoundDialog(
          title: Text(l10n.homeWidgetUrlConfig),
          child: Input(
            autoFocus: true,
            controller: ctrl,
            label: 'JSON',
            type: TextInputType.visiblePassword,
            maxLines: 7,
            onSubmitted: (p0) => _saveWidgetSP(p0, data),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _saveWidgetSP(ctrl.text, data);
              },
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }
}
