import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class AndroidSettingsPage extends StatefulWidget {
  const AndroidSettingsPage({super.key});

  @override
  State<AndroidSettingsPage> createState() => _AndroidSettingsPageState();
}

class _AndroidSettingsPageState extends State<AndroidSettingsPage> {
  late SharedPreferences _sp;
  final wc = WatchConnectivity();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) => _sp = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Android'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          _buildBgRun(),
          _buildAndroidWidgetSharedPreference(),
          if (BioAuth.isPlatformSupported)
            PlatformPublicSettings.buildBioAuth(),
        ].map((e) => CardX(child: e)).toList(),
      ),
    );
  }

  Widget _buildBgRun() {
    return ListTile(
      title: Text(l10n.bgRun),
      subtitle: Text(l10n.bgRunTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: Stores.setting.bgRun),
    );
  }

  void _saveWidgetSP(Map<String, String> map, Map<String, String> old) {
    try {
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
      onTap: () async {
        final data = <String, String>{};
        _sp.getKeys().forEach((key) {
          final val = _sp.getString(key);
          if (val != null) {
            data[key] = val;
          }
        });
        final result = await AppRoutes.kvEditor(data: data).go(context);
        if (result != null) {
          if (result is Map<String, String>) {
            _saveWidgetSP(result, data);
          } else {
            final err = 'Save Android widget SharedPreference failed: '
                'unexpected type: ${result.runtimeType}';
            Loggers.app.warning(err);
            context.showRoundDialog(
              title: l10n.error,
              child: SingleChildScrollView(
                child: SimpleMarkdown(data: '$err\n\n```$result```'),
              ),
            );
          }
        }
      },
    );
  }

  /// It's removed due to Issue #381
  // Widget _buildWatch() {
  //   return FutureWidget(
  //     future: wc.isReachable,
  //     error: (e, s) {
  //       Loggers.app.warning('WatchOS error', e, s);
  //       return ListTile(
  //         title: const Text('Watch app'),
  //         subtitle: Text(l10n.viewErr, style: UIs.textGrey),
  //         trailing: const Icon(Icons.keyboard_arrow_right),
  //         onTap: () {
  //           context.showRoundDialog(
  //             title: l10n.error,
  //             child: SingleChildScrollView(
  //               child: SimpleMarkdown(data: '${e.toString()}\n```$s```'),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //     success: (val) {
  //       if (val == null) {
  //         return ListTile(
  //           title: const Text('Watch app'),
  //           subtitle: Text(l10n.watchNotPaired, style: UIs.textGrey),
  //         );
  //       }
  //       return ListTile(
  //         title: const Text('Watch app'),
  //         subtitle: Text(l10n.sync, style: UIs.textGrey),
  //         trailing: const Icon(Icons.keyboard_arrow_right),
  //         onTap: () async {},
  //       );
  //     },
  //   );
  // }
}
