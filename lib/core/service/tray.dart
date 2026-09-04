import 'dart:async';

import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/app/tray.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:window_manager/window_manager.dart';

/// The desktop status icon, and the window behaviour that makes it worth
/// having.
///
/// **What it is for.** A machine you are watching is a thing you glance at, and
/// a glance should not cost switching to an app and waiting for a window. The
/// menu says what each machine is doing — a chart and two lines where the
/// platform allows it — and clicking one opens the app on that server.
///
/// **Why there is no plugin behind it.** The one on pub sets a menu item's
/// title and nothing else: no image, no attributed title, no view. A row that
/// is a name, a sparkline and a line of readings is not reachable through it on
/// any platform. So each platform draws its own and this side only describes
/// what to draw — see [TrayModel], which crosses with the text already
/// formatted and the series already normalised. Nothing over there has to know
/// what a percentage is or how this app renders a byte count.
///
/// As a map rather than a JSON string, so each side reads it in its own types:
/// an `NSDictionary`, an `EncodableMap`, an `FlValue`. A string would mean a
/// JSON parser in Swift, in C++ and in C, for a payload the channel's own
/// codec already carries.
///
/// **What each platform can do**, because they differ and the difference is not
/// this app's choice:
/// - macOS puts an arbitrary `NSView` in a menu item, so it gets the layout.
/// - Windows owner-draws its menu, so it gets the same.
/// - Linux reaches its panel through libayatana-appindicator, whose menu is
///   serialised over the dbusmenu protocol. A widget cannot cross D-Bus. A
///   label and one image per item can, so a row there is one line — the same
///   line the compact layout draws everywhere else.
///
/// Nothing here polls. The rows come from the providers that were already
/// refreshing on the app's own cycle, so the menu costs one rebuild per change
/// and nothing at all while nothing changes.
class TrayService with WindowListener, WidgetsBindingObserver {
  TrayService(this._ref);

  final Ref _ref;

  static const _channel = MethodChannel('${Miscs.pkgName}/tray');

  /// Per-server subscriptions, keyed by id. Kept so a server added or removed
  /// while the app runs is picked up: which `serverProvider` instances exist is
  /// not knowable up front.
  final _watched = <String, ProviderSubscription<ServerState>>{};

  ProviderSubscription<ServersState>? _watchedAll;
  ValueListenable<String>? _localeListenable;

  /// What was last pushed, so an unchanged model is not pushed again.
  ///
  /// A menu is replaced whole on all three platforms — none of them offers
  /// editing one item — so a push while the menu is open closes it. At the
  /// refresh rate that would make the menu unusable.
  TrayModel? _shown;

  Timer? _debounce;
  var _disposed = false;

  Future<void> init() async {
    if (!isDesktop) return;
    _channel.setMethodCallHandler(_onNative);
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _localeListenable = Stores.setting.locale.listenable()
      ..addListener(_onLocaleChanged);
    await _applyCloseBehaviour();

    _watchedAll = _ref.listen<ServersState>(
      serversProvider,
      (_, next) => _resubscribe(next),
      fireImmediately: true,
    );
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _localeListenable?.removeListener(_onLocaleChanged);
    for (final sub in _watched.values) {
      sub.close();
    }
    _watched.clear();
    _watchedAll?.close();
    if (isDesktop) unawaited(_invoke('destroy'));
  }

  /// Re-reads the settings and pushes what they changed.
  ///
  /// Called by the switches themselves. The layout is part of the payload, so
  /// changing one is a push like any other — except that the model has to be
  /// forgotten first, since the rows may be identical and only the shape
  /// different.
  Future<void> applySetting() async {
    await _applyCloseBehaviour();
    _shown = null;
    _schedule();
  }

  Future<void> _applyCloseBehaviour() async {
    if (!isDesktop) return;
    final keep = Stores.setting.trayKeepRunning.fetch();
    try {
      await windowManager.setPreventClose(keep);
    } catch (e, s) {
      Loggers.app.warning('Tray: setting the close behaviour', e, s);
    }
  }

  void _resubscribe(ServersState state) {
    final ids = state.serverOrder.toSet();
    for (final id in _watched.keys.toList()) {
      if (ids.contains(id)) continue;
      _watched.remove(id)?.close();
    }
    for (final id in ids) {
      if (_watched.containsKey(id)) continue;
      _watched[id] = _ref.listen<ServerState>(
        serverProvider(id),
        (_, _) => _schedule(),
      );
    }
    _schedule();
  }

  /// Coalesced, because a refresh cycle finishing lands as one change per
  /// server within a few milliseconds of itself — and each would otherwise
  /// rebuild the whole menu.
  void _schedule() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _sync);
  }

  void _onLocaleChanged() {
    _shown = null;
    _schedule();
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _onLocaleChanged();

  /// What the settings say the menu should look like.
  TrayConfig get config {
    final metrics = <TrayMetric>[];
    for (final name in Stores.setting.trayMetrics.fetch()) {
      final metric = TrayMetric.byName(name);
      if (metric != null) metrics.add(metric);
    }
    final chart = TrayMetric.byName(Stores.setting.trayChart.fetch());
    return TrayConfig(
      metrics: metrics,
      // A metric a chart can say nothing about is not one to draw — see
      // [TrayMetric.chartable]. Reachable by picking a chart metric and then
      // removing it from the readings, which is where the two settings meet.
      chart: chart != null && chart.chartable ? chart : null,
      compact: Stores.setting.trayCompact.fetch(),
    );
  }

  Future<void> _sync() async {
    if (_disposed || !isDesktop) return;

    final settings = config;
    final state = _ref.read(serversProvider);
    final lines = <TrayLine>[];
    for (final id in state.serverOrder) {
      final spi = state.servers[id];
      if (spi == null) continue;
      final server = _ref.read(serverProvider(id));
      final up = trayStateOf(server.conn) == TrayLineState.ok;
      lines.add(
        TrayLine(
          id: id,
          name: spi.name,
          state: trayStateOf(server.conn),
          // Only for a machine that answered. A row for one that is down says
          // so in its dot, and readings left over from before it went down
          // would be the wrong kind of reassuring.
          readings: up
              ? trayReadings(status: server.status, metrics: settings.metrics)
              : const [],
          chart: up && settings.drawsChart
              ? trayChart(status: server.status, metric: settings.chart)
              : const [],
        ),
      );
    }

    final model = TrayModel(
      lines: lines,
      config: settings,
      labels: TrayMenuLabels(
        open: '${libL10n.open} ServerBox',
        servers: libL10n.servers,
        empty: libL10n.empty,
        settings: libL10n.setting,
        quit: libL10n.exit,
      ),
    );
    if (model == _shown) return;
    _shown = model;
    await _invoke('update', model.toJson());
  }

  Future<void> _invoke(String method, [Object? arg]) async {
    try {
      await _channel.invokeMethod(method, arg);
    } on MissingPluginException {
      // A desktop runner with no tray of its own. Nothing to report: the app
      // is not the tray.
    } catch (e, s) {
      Loggers.app.warning('Tray: $method', e, s);
    }
  }

  // ----------------------------------------------------------------- events

  Future<Object?> _onNative(MethodCall call) async {
    switch (call.method) {
      case 'open':
        await _showWindow();
      case 'settings':
        await _openSettings();
      case 'quit':
        // Past the prevention flag, which is the point of the item: the window
        // refuses to close while the app is meant to stay resident, and this is
        // the way out that leaves.
        await windowManager.destroy();
      case 'server':
        final id = call.arguments;
        if (id is String) await _openServer(id);
    }
    return null;
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e, s) {
      Loggers.app.warning('Tray: showing the window', e, s);
    }
  }

  /// The settings page, over whatever the window was showing.
  ///
  /// Through the root navigator's own context: this runs from a menu, which is
  /// not in the widget tree and has no context of its own.
  Future<void> _openSettings() async {
    await _showWindow();
    final context = AppNavigator.context;
    if (context == null || !context.mounted) return;
    SettingsPage.route.go(context);
  }

  /// Brings the window forward on that server.
  ///
  /// The window first: selecting a server rebuilds a page nobody can see yet,
  /// and the other order showed the previous selection for a frame.
  Future<void> _openServer(String id) async {
    await _showWindow();
    if (_ref.read(serversProvider).servers[id] == null) return;
    _ref.read(homeTabRequestProvider.notifier).go(AppTab.server);
    _ref.read(serverSelectionProvider.notifier).select(id);
  }

  /// Closing the window hides it instead, while the app is meant to stay.
  ///
  /// `setPreventClose` only stops the close; something still has to say what
  /// happens instead, and hiding is what keeps the engine — and so the polling
  /// behind the menu — alive. Destroying the window would take both with it.
  @override
  void onWindowClose() {
    if (!Stores.setting.trayKeepRunning.fetch()) {
      unawaited(windowManager.destroy());
      return;
    }
    unawaited(windowManager.hide());
  }
}

/// Alive for as long as the app is.
///
/// Watched once, from the root — a `Provider` is lazy, and a tray that only
/// existed while some page happened to be built would come and go with
/// navigation.
final trayServiceProvider = Provider<TrayService>((ref) {
  final service = TrayService(ref);
  ref.onDispose(service.dispose);
  unawaited(service.init());
  return service;
});
