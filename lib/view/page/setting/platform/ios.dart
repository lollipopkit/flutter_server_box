import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/utils/misc.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

class IosSettingsPage extends StatefulWidget {
  const IosSettingsPage({super.key});

  @override
  State<IosSettingsPage> createState() => _IosSettingsPageState();

  static const route = AppRouteNoArg(
    page: IosSettingsPage.new,
    path: '/settings/ios',
  );
}

class _IosSettingsPageState extends State<IosSettingsPage> {
  final _pushToken = ValueNotifier<String?>(null);

  /// Asked of [WatchSync] rather than of a fresh `WatchConnectivity`, which
  /// would install itself as the channel's only method call handler and take
  /// the callbacks away from it.
  late final _watchPairedFuture = WatchSync.instance.isWatchPaired;
  late final _pushTokenFuture = getToken();

  void _showCopyResult(bool success) {
    context.showSnackBar(success ? libL10n.success : libL10n.fail);
  }

  /// Every tile here reads straight from the store, so redrawing is all that
  /// is needed after an edit. `setState` is protected, hence the indirection
  /// for the actions extension.
  void _refresh() {
    if (mounted) setState(() {});
  }

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
          _buildAccessoryWidgetServer(),
          _buildWatchApp(),
          _buildWatchLegacyUrls(),
        ].nonNulls.map((e) => CardX(child: e)).toList(),
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
            _showCopyResult(true);
          } else {
            _showCopyResult(false);
          }
        },
      ),
      subtitle: FutureWidget<String?>(
        future: _pushTokenFuture,
        loading: const Text('...'),
        error: (error, trace) => Text('${libL10n.error}: $error'),
        success: (text) {
          _pushToken.value = text;
          return Text(
            text ?? 'null',
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

  /// The lock screen / inline families can't carry the intent configuration the
  /// home screen ones use, so they read one URL out of the App Group instead.
  Widget _buildAccessoryWidgetServer() {
    final spi = _accessoryServer;
    return ListTile(
      title: Text(l10n.accessoryWidgetServer),
      subtitle: Text(
        spi?.name ?? libL10n.empty,
        style: UIs.textGrey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapAccessoryWidgetServer,
    );
  }

  Widget _buildWatchApp() {
    final count = Stores.setting.watchServerIds.fetch().length;
    return ListTile(
      title: const Text('Watch app'),
      subtitle: FutureWidget<bool>(
        future: _watchPairedFuture,
        loading: const Text('...'),
        // Not a blocker: the selection is stored here and delivered whenever a
        // watch does show up, so it stays editable either way.
        error: (e, _) => Text('${libL10n.error}: $e', style: UIs.textGrey),
        success: (paired) => Text(
          paired == true ? '$count' : l10n.watchNotPaired,
          style: UIs.textGrey,
        ),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapWatchApp,
    );
  }

  /// Only offered when one exists — nothing can create these any more.
  ///
  /// TODO: drop with `SettingStore.watchLegacyUrls`.
  Widget? _buildWatchLegacyUrls() {
    final urls = Stores.setting.watchLegacyUrls.fetch();
    if (urls.isEmpty) return null;
    return ListTile(
      title: Text(l10n.watchLegacyUrls),
      subtitle: Text('${urls.length}', style: UIs.textGrey),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => _onTapWatchLegacyUrls(urls),
    );
  }
}

extension _Actions on _IosSettingsPageState {
  /// Servers the watch can actually load: it talks to a monitor agent over
  /// HTTP and has no SSH client of its own.
  List<Spi> get _monitorServers =>
      Stores.server.fetch().where((e) => e.monitor != null).toList();

  Spi? get _accessoryServer {
    final id = Stores.setting.accessoryWidgetServerId.fetch();
    return id.isEmpty ? null : Stores.server.get<Spi>(id);
  }

  void _onTapAccessoryWidgetServer() async {
    final servers = _monitorServers;
    if (servers.isEmpty) {
      context.showSnackBar(l10n.watchNoMonitorServer);
      return;
    }

    final current = _accessoryServer;
    // `showPickSingleDialog` collapses "dismissed" and "cleared" into the same
    // null, which would make the choice impossible to unset. The multi-value
    // form keeps them apart: null is dismissed, empty is cleared.
    final picked = await context.showPickDialog<Spi>(
      title: l10n.accessoryWidgetServer,
      items: servers,
      display: (e) => e.name,
      multi: false,
      clearable: true,
      initial: current == null ? null : [current],
    );
    if (picked == null) return;

    Stores.setting.accessoryWidgetServerId.put(
      picked.isEmpty ? '' : picked.first.id,
    );
    await MethodChans.syncAccessoryWidgetUrl();
    _refresh();
  }

  void _onTapWatchApp() async {
    final servers = _monitorServers;
    if (servers.isEmpty) {
      context.showSnackBar(l10n.watchNoMonitorServer);
      return;
    }

    final selectedIds = Stores.setting.watchServerIds.fetch();
    final picked = await context.showPickDialog<Spi>(
      title: l10n.watchServers,
      items: servers,
      display: (e) => e.name,
      initial: servers.where((e) => selectedIds.contains(e.id)).toList(),
      actions: [
        TextButton(
          onPressed: () => context.showRoundDialog(
            title: l10n.watchServers,
            child: Text(l10n.watchServersTip),
          ),
          child: Text(libL10n.note),
        ),
      ],
    );
    if (picked == null) return;

    final pickedIds = picked.map((e) => e.id).toSet();
    // Keep the order the user already had and append what is new, rather than
    // rebuilding from the picker's order — the watch pages through this list.
    final next = [
      ...selectedIds.where(pickedIds.contains),
      ...pickedIds.where((id) => !selectedIds.contains(id)),
    ];
    Stores.setting.watchServerIds.put(next);
    await WatchSync.instance.push();
    _refresh();
  }

  /// TODO: drop with `SettingStore.watchLegacyUrls`.
  void _onTapWatchLegacyUrls(List<String> urls) async {
    final result = await JsonListEditor.route.go(
      context,
      JsonListEditorArgs(data: urls),
    );
    if (result == null) return;

    Stores.setting.watchLegacyUrls.put(
      result.whereType<String>().where((e) => e.trim().isNotEmpty).toList(),
    );
    await WatchSync.instance.push();
    _refresh();
  }
}
