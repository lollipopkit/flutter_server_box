import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/core/utils/platform/auth.dart';
import 'package:toolbox/core/utils/share.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/page/setting/platform_pub.dart';
import 'package:toolbox/view/widget/custom_appbar.dart';
import 'package:toolbox/view/widget/future_widget.dart';
import 'package:toolbox/view/widget/cardx.dart';
import 'package:toolbox/view/widget/store_switch.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class IOSSettingsPage extends StatefulWidget {
  const IOSSettingsPage({Key? key}) : super(key: key);

  @override
  _IOSSettingsPageState createState() => _IOSSettingsPageState();
}

class _IOSSettingsPageState extends State<IOSSettingsPage> {
  final _pushToken = ValueNotifier<String?>(null);

  final wc = WatchConnectivity();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('iOS'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          _buildPushToken(),
          _buildAutoUpdateHomeWidget(),
          _buildWatchApp(),
          if (BioAuth.isPlatformSupported)
            PlatformPublicSettings.buildBioAuth(),
        ].map((e) => CardX(e)).toList(),
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
            Shares.copy(_pushToken.value!);
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
    return FutureWidget<Map<String, dynamic>?>(
      future: () async {
        if (!await wc.isPaired) {
          return null;
        }
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
    /// Encode [map] to String with indent `\t`
    final text = Miscs.jsonEncoder.convert(map);
    final result = await AppRoute.editor(
      text: text,
      langCode: 'json',
      title: 'Watch app',
    ).go<String>(context);
    if (result == null) {
      return;
    }
    try {
      final newCtx = json.decode(result) as Map<String, dynamic>;
      await wc.updateApplicationContext(newCtx);
    } catch (e, trace) {
      context.showRoundDialog(
        title: Text(l10n.error),
        child: Text('${l10n.save}:\n$e'),
      );
      Loggers.app.warning('Update watch config failed', e, trace);
    }
  }
}
