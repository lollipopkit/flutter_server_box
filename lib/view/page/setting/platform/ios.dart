import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/core/utils/misc.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

class IosSettingsPage extends StatefulWidget {
  /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const IosSettingsPage({super.key, this.embedded = false});

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
    if (success) {
      Toast.success(libL10n.success);
    } else {
      Toast.error(libL10n.fail);
    }
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
    final body = ListView(
      padding: context.padBottom(const EdgeInsets.symmetric(horizontal: 17)),
      children: [
        _buildPushToken(),
        _buildAutoUpdateHomeWidget(),
        _buildWatchApp(),
        _buildWatchLegacyUrls(),
      ].nonNulls.map((e) => CardX(child: e)).toList(),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: const Text('iOS')),
      body: body,
    );
  }

  Widget _buildPushToken() {
    return ListTile(
      title: Text(l10n.pushToken),
      trailing: IconButton(tooltip: libL10n.copy, 
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

  Widget _buildWatchApp() {
    // What the watch will actually show, which is every monitor server bar the
    // ones held back. Counted rather than taken from the exclusion list's
    // length: an id outlives the monitor configuration that made it relevant,
    // and `buildPayload` already skips those — so a raw length is a number the
    // watch never agrees with.
    final count = WatchSync.syncedServerIds().length;
    return ListTile(
      title: const Text('Watch app'),
      subtitle: FutureWidget<bool>(
        future: _watchPairedFuture,
        loading: const Text('...'),
        // Not a blocker: the exclusions are stored here and delivered whenever
        // a watch does show up, so they stay editable either way.
        error: (e, _) => Text('${libL10n.error}: $e', style: UIs.textGrey),
        success: (paired) => Text(
          paired == true
              ? '$count / ${_monitorServers.length}'
              : l10n.watchNotPaired,
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

  void _onTapWatchApp() async {
    final servers = _monitorServers;
    if (servers.isEmpty) {
      Toast.show(l10n.watchNoMonitorServer);
      return;
    }

    final excluded = Stores.setting.watchExcludedServerIds.fetch().toSet();
    final picked = await context.showPickDialog<Spi>(
      title: l10n.watchServers,
      items: servers,
      display: (e) => e.name,
      initial: servers.where((e) => !excluded.contains(e.id)).toList(),
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

    final shown = picked.map((e) => e.id).toSet();
    // Only servers that were on offer. An id the picker never showed — one
    // whose monitor configuration was removed while this page was open — has
    // no business being added to the exclusion list by the act of not being
    // ticked in a dialog it was absent from.
    final next = servers
        .map((e) => e.id)
        .where((id) => !shown.contains(id))
        .toList();
    await WatchSync.instance.updateExclusions(next);
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
