import 'dart:async';

import 'package:fl_lib/fl_lib.dart' hide Provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/app/tray.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// The desktop status icon, and the window behaviour that makes it worth
/// having.
///
/// Desktop only. The three platforms put it in different places — the macOS
/// menu bar, the Windows notification area, a Linux panel through
/// libayatana-appindicator — and `tray_manager` is what makes those one API.
/// It is the sibling of the `window_manager` this app already ships, which is
/// why there is no hand-written native code here.
///
/// **What it is for.** A machine you are watching is a thing you glance at, and
/// a glance should not cost switching to an app and waiting for a window. The
/// menu says what each machine is doing, and clicking one opens the app on it.
///
/// The icon itself never changes. It was going to go red when something
/// failed, and that is one more thing in a menu bar competing for attention —
/// the row that failed says so, in the place where something can be done about
/// it.
///
/// Nothing here polls. The status comes from the providers that were already
/// refreshing on the app's own cycle, so the tray costs one menu rebuild per
/// change and nothing at all while nothing changes.
class TrayService with TrayListener, WindowListener {
  TrayService(this._ref);

  final Ref _ref;

  /// Per-server subscriptions, keyed by id. Kept so that a server added or
  /// removed while the app runs is picked up: the set of `serverProvider`
  /// instances is not knowable up front.
  final _watched = <String, ProviderSubscription<ServerState>>{};

  ProviderSubscription<ServersState>? _watchedAll;

  /// What was last pushed, so an unchanged model is not pushed again.
  ///
  /// A menu is replaced whole — no platform here offers editing one item — so
  /// a push while the menu is open closes it. At the poll rate that would make
  /// the menu unusable on a machine whose CPU reading moves every cycle.
  TrayModel? _shown;

  Timer? _debounce;
  var _disposed = false;

  Future<void> init() async {
    if (!isDesktop) return;
    trayManager.addListener(this);
    windowManager.addListener(this);
    await _applyCloseBehaviour();
    await _setIcon();

    _watchedAll = _ref.listen<ServersState>(
      serversProvider,
      (_, next) => _resubscribe(next),
      fireImmediately: true,
    );
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    for (final sub in _watched.values) {
      sub.close();
    }
    _watched.clear();
    _watchedAll?.close();
    if (isDesktop) trayManager.destroy();
  }

  /// Whether closing the window leaves the app running.
  ///
  /// Read on every change rather than cached: the switch is on the settings
  /// page and takes effect without a restart, and the window's own prevention
  /// flag is the thing that has to agree with it.
  Future<void> applySetting() => _applyCloseBehaviour();

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
  /// server within a few milliseconds of itself — and each one would otherwise
  /// rebuild the whole menu.
  void _schedule() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _sync);
  }

  Future<void> _sync() async {
    if (_disposed || !isDesktop) return;

    final state = _ref.read(serversProvider);
    final lines = <TrayLine>[];
    for (final id in state.serverOrder) {
      final spi = state.servers[id];
      if (spi == null) continue;
      final server = _ref.read(serverProvider(id));
      lines.add(
        TrayLine(
          id: id,
          name: spi.name,
          state: trayStateOf(server.conn),
          detail: trayDetail(
            conn: server.conn,
            cpuPercent: server.status.cpu.usedPercent(),
            memUsedKib: server.status.mem.total - server.status.mem.avail,
            memTotalKib: server.status.mem.total,
          ),
        ),
      );
    }
    final model = TrayModel(lines);
    if (model == _shown) return;
    _shown = model;

    try {
      await trayManager.setContextMenu(_menu(model));
    } catch (e, s) {
      // Best effort by nature: a Linux desktop with no status area at all is a
      // supported place to run, and the app is not the tray.
      Loggers.app.warning('Tray: updating', e, s);
    }
  }

  /// Once, at startup. Nothing changes it afterwards.
  Future<void> _setIcon() async {
    try {
      await trayManager.setIcon(
        // macOS reads this through the asset bundle; Windows and Linux build a
        // path under the executable, which is why the three are declared as
        // assets rather than loaded here.
        isMacOS
            ? _mac
            : isWindows
            ? _win
            : _linux,
        // Black-and-alpha, which the system inverts along with the menu bar.
        isTemplate: isMacOS,
      );
    } catch (e, s) {
      Loggers.app.warning('Tray: setting the icon', e, s);
    }
  }

  static const _mac = 'assets/tray/mac.png';
  static const _win = 'assets/tray/tray.ico';
  static const _linux = 'assets/tray/tray.png';

  static const _keyOpen = 'open';
  static const _keySettings = 'settings';
  static const _keyQuit = 'quit';
  static const _keyServer = 'server:';

  /// Three groups: the way in, what there is to look at, and what to do with
  /// the app itself.
  ///
  /// Opening the app is first because it is what the icon is most often
  /// clicked for, and last is where a list of servers pushes it further down
  /// with every machine added. The servers sit under a heading — a disabled
  /// item, which is what a native menu makes of one — so that a row is read as
  /// a machine rather than as another command. An install with no servers says
  /// so in that group rather than leaving a heading with nothing under it.
  Menu _menu(TrayModel model) {
    return Menu(
      items: [
        MenuItem(key: _keyOpen, label: '${libL10n.open} ${BuildData.name}'),
        MenuItem.separator(),
        MenuItem(label: libL10n.servers, disabled: true),
        if (model.lines.isEmpty)
          MenuItem(label: libL10n.empty, disabled: true)
        else
          for (final line in model.lines)
            MenuItem(key: '$_keyServer${line.id}', label: line.label),
        MenuItem.separator(),
        MenuItem(key: _keySettings, label: libL10n.setting),
        MenuItem(key: _keyQuit, label: libL10n.exit),
      ],
    );
  }

  // ----------------------------------------------------------------- events

  /// Left click. macOS opens the menu, because a menu bar item with no menu is
  /// a button that does nothing visible; Windows and Linux open the window,
  /// which is what a taskbar icon does there.
  @override
  void onTrayIconMouseDown() {
    if (isMacOS) {
      trayManager.popUpContextMenu();
      return;
    }
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key == null) return;
    if (key == _keyOpen) {
      unawaited(_showWindow());
      return;
    }
    if (key == _keySettings) {
      unawaited(_openSettings());
      return;
    }
    if (key == _keyQuit) {
      // Past the prevention flag, which is the whole point of this item: the
      // window refuses to close while the app is meant to stay resident, and
      // this is the way out that leaves.
      unawaited(windowManager.destroy());
      return;
    }
    if (key.startsWith(_keyServer)) {
      unawaited(_openServer(key.substring(_keyServer.length)));
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

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e, s) {
      Loggers.app.warning('Tray: showing the window', e, s);
    }
  }

  /// Brings the window forward on that server.
  ///
  /// The window first: selecting a server rebuilds a page nobody can see yet,
  /// and doing it in the other order showed the previous selection for a frame.
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
  /// behind the tray — alive. Destroying the window would take both with it.
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
