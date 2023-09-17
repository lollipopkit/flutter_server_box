import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/custom_appbar.dart';
import 'package:toolbox/view/widget/future_widget.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/store_switch.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class IOSSettingsPage extends StatefulWidget {
  const IOSSettingsPage({Key? key}) : super(key: key);

  @override
  _IOSSettingsPageState createState() => _IOSSettingsPageState();
}

class _IOSSettingsPageState extends State<IOSSettingsPage> {
  late S _s;

  final _pushToken = ValueNotifier<String?>(null);

  final wc = WatchConnectivity();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

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
        ].map((e) => RoundRectCard(e)).toList(),
      ),
    );
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
          if (_pushToken.value != null) {
            copy2Clipboard(_pushToken.value!);
            context.showSnackBar(_s.success);
          } else {
            context.showSnackBar(_s.getPushTokenFailed);
          }
        },
      ),
      subtitle: FutureWidget<String?>(
        future: getToken(),
        loading: Text(_s.gettingToken),
        error: (error, trace) => Text('${_s.error}: $error'),
        noData: Text(_s.nullToken),
        success: (text) {
          _pushToken.value = text;
          return Text(
            text ?? _s.nullToken,
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
      title: Text(_s.autoUpdateHomeWidget),
      subtitle: Text(_s.whenOpenApp, style: UIs.textGrey),
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
          subtitle: Text('${_s.error}: $e', style: UIs.textGrey),
        );
      },
      success: (ctx) {
        if (ctx == null) {
          return ListTile(
            title: const Text('Watch app'),
            subtitle: Text(_s.watchNotPaired, style: UIs.textGrey),
          );
        }
        return ListTile(
          title: const Text('Watch app'),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async => _onTapWatchApp(ctx),
        );
      },
      noData: UIs.placeholder,
    );
  }

  void _onTapWatchApp(Map<String, dynamic> map) async {
    /// Encode [map] to String with indent `\t`
    final text = Miscs.jsonEncoder.convert(map);
    final result = await AppRoute.editor(
      text: text,
      langCode: 'json',
      title: 'Watch app',
    ).go(context);
    if (result == null) {
      return;
    }
    try {
      final newCtx = json.decode(result) as Map<String, dynamic>;
      await wc.updateApplicationContext(newCtx);
    } catch (e, trace) {
      context.showRoundDialog(
        title: Text(_s.error),
        child: Text('${_s.save}:\n$e'),
      );
      Loggers.app.warning('Update watch config failed', e, trace);
    }
  }
}
