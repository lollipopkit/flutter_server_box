import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/setting/platform/platform_pub.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class IOSSettingsPage extends StatefulWidget {
  const IOSSettingsPage({super.key});

  @override
  State<IOSSettingsPage> createState() => _IOSSettingsPageState();
}

class _IOSSettingsPageState extends State<IOSSettingsPage> {
  final _pushToken = ValueNotifier<String?>(null);

  final wc = WatchConnectivity();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('iOS'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          _buildPushToken(),
          _buildAutoUpdateHomeWidget(),
          _buildWatchApp(),
          if (BioAuth.isPlatformSupported)
            PlatformPublicSettings.buildBioAuth(),
        ].map((e) => CardX(child: e)).toList(),
      ),
    );
  }

  Widget _buildPushToken() {
    return ListTile(
      title: Text(l10n.pushToken),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.zero,
        onPressed: () {
          if (_pushToken.value != null) {
            Pfs.copy(_pushToken.value!);
            context.showSnackBar(l10n.success);
          } else {
            context.showSnackBar(l10n.getPushTokenFailed);
          }
        },
      ),
      subtitle: FutureWidget<String?>(
        future: getToken(),
        loading: Text(l10n.gettingToken),
        error: (error, trace) => Text('${l10n.error}: $error'),
        success: (text) {
          _pushToken.value = text;
          return Text(
            text ?? l10n.nullToken,
            style: UIs.textGrey,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        },
      ),
    );
  }

  Widget _buildAutoUpdateHomeWidget() {
    return ListTile(
      title: Text(l10n.autoUpdateHomeWidget),
      subtitle: Text(l10n.whenOpenApp, style: UIs.textGrey),
      trailing: StoreSwitch(prop: Stores.setting.autoUpdateHomeWidget),
    );
  }

  Widget _buildWatchApp() {
    return FutureWidget(
      future: () async {
        if (!await wc.isPaired) return null;
        return await wc.applicationContext;
      }(),
      loading: UIs.centerLoading,
      error: (e, trace) {
        Loggers.app.warning('WatchOS error', e, trace);
        return ListTile(
          title: const Text('Watch app'),
          subtitle: Text('${l10n.error}: $e', style: UIs.textGrey),
        );
      },
      success: (ctx) {
        if (ctx == null) {
          return ListTile(
            title: const Text('Watch app'),
            subtitle: Text(l10n.watchNotPaired, style: UIs.textGrey),
          );
        }
        return ListTile(
          title: const Text('Watch app'),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async => _onTapWatchApp(ctx),
        );
      },
    );
  }

  void _onTapWatchApp(Map<String, dynamic> map) async {
    final urls = Map<String, String>.from(map['urls'] as Map? ?? {});
    final result = await AppRoutes.kvEditor(data: urls).go(context);
    if (result == null || result is! Map<String, String>) return;

    try {
      await context.showLoadingDialog(fn: () async {
        await wc.updateApplicationContext({'urls': result});
      });
    } catch (e, s) {
      context.showErrDialog(e: e, s: s, operation: 'Watch Context');
      Loggers.app.warning('Update watch config failed', e, s);
    }
  }
}
