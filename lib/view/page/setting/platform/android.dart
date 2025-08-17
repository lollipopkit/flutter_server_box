import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

class AndroidSettingsPage extends StatefulWidget {
  const AndroidSettingsPage({super.key});

  @override
  State<AndroidSettingsPage> createState() => _AndroidSettingsPageState();

  static const route = AppRouteNoArg(
    page: AndroidSettingsPage.new,
    path: '/settings/android',
  );
}

const _homeWidgetPrefPrefix = 'widget_';

class _AndroidSettingsPageState extends State<AndroidSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text('Android')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          // _buildFgService(),
          _buildBgRun(),
          _buildAndroidWidgetSharedPreference(),
        ].map((e) => CardX(child: e)).toList(),
      ),
    );
  }

  // Widget _buildFgService() {
  //   return ListTile(
  //     title: TipText(l10n.fgService, l10n.fgServiceTip),
  //     trailing: StoreSwitch(prop: Stores.setting.fgService),
  //   );
  // }

  Widget _buildBgRun() {
    return ListTile(
      title: TipText(l10n.bgRun, l10n.bgRunTip),
      trailing: StoreSwitch(prop: Stores.setting.bgRun),
    );
  }

  void _saveWidgetSP(Map<String, String> map, Map<String, String> old) {
    try {
      final keysDel = old.keys.toSet().difference(map.keys.toSet());
      for (final key in keysDel) {
        if (!key.startsWith(_homeWidgetPrefPrefix)) continue;
        PrefStore.shared.remove(key);
      }
      for (final entry in map.entries) {
        if (!entry.key.startsWith(_homeWidgetPrefPrefix)) continue;
        PrefStore.shared.set(entry.key, entry.value);
      }
      context.showSnackBar(libL10n.success);
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
        final keys = PrefStore.shared.keys();

        for (final key in keys) {
          final val = PrefStore.shared.get<String>(key);
          if (val != null) {
            data[key] = val;
          }
        }
        final result = await KvEditor.route.go(
          context,
          KvEditorArgs(data: data, prefix: _homeWidgetPrefPrefix),
        );
        if (result != null) {
          _saveWidgetSP(result, data);
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
