import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class IosSettingsPage extends StatefulWidget {
  const IosSettingsPage({super.key});

  @override
  State<IosSettingsPage> createState() => _IosSettingsPageState();

  static const route = AppRouteNoArg(page: IosSettingsPage.new, path: '/settings/ios');
}

class _IosSettingsPageState extends State<IosSettingsPage> {
  final _pushToken = ValueNotifier<String?>(null);

  final wc = WatchConnectivity();

  @override
  void dispose() {
    super.dispose();
    _pushToken.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text('iOS')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          _buildPushToken(),
          _buildAutoUpdateHomeWidget(),
          _buildWatchApp(),
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
          final val = _pushToken.value;
          if (val != null) {
            Pfs.copy(val);
            context.showSnackBar(libL10n.success);
          } else {
            context.showSnackBar(libL10n.fail);
          }
        },
      ),
      subtitle: FutureWidget<String?>(
        future: getToken(),
        loading: const Text('...'),
        error: (error, trace) => Text('${libL10n.error}: $error'),
        success: (text) {
          _pushToken.value = text;
          return Text(text ?? 'null', style: UIs.textGrey, overflow: TextOverflow.ellipsis, maxLines: 1);
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
          subtitle: Text('${libL10n.error}: $e', style: UIs.textGrey),
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
    final result = await KvEditor.route.go(context, KvEditorArgs(data: urls));
    if (result == null) return;

    final (_, err) = await context.showLoadingDialog(
      fn: () async {
        final data = {'urls': result};

        // Try realtime update (app must be running foreground).
        try {
          if (await wc.isReachable) {
            await wc.sendMessage(data);
            return;
          }
        } catch (e) {
          Loggers.app.warning('Failed to send message to watch', e);
        }

        // fallback
        await wc.updateApplicationContext(data);
      },
    );
    if (err == null) {
      context.showSnackBar(libL10n.success);
    }
  }
}
