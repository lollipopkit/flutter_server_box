import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:server_box/core/utils/drop_zones.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:xterm/xterm.dart' show CustomTextEditState;

abstract final class MethodChans {
  static const _channel = MethodChannel('${Miscs.pkgName}/main_chan');

  static Future<T?> _invoke<T>(
    String method, {
    required bool supported,
    required String label,
    Object? args,
  }) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e, s) {
      Loggers.app.warning(label, e, s);
      return null;
    }
  }

  static Future<void> _invokeVoid(
    String method, {
    required bool supported,
    required String label,
    Object? args,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e, s) {
      Loggers.app.warning(label, e, s);
    }
  }

  /// iOS tells of every paste, and what it holds, before the text view
  /// inserts it (the app's `sendAction`), so the terminal sends it as one.
  static void listenPastes() {
    const MethodChannel(
      '${Miscs.pkgName}/text_input',
    ).setMethodCallHandler((call) async {
      final text = call.arguments;
      if (call.method == 'paste' && text is String) {
        CustomTextEditState.expectPaste(text);
      }
    });
  }

  /// Tells the system file picker the installed Linux systems changed, so the
  /// roots it lists for them follow (`LinuxDocumentsProvider`, and the Files
  /// app's `ios/LinuxFiles`).
  static Future<void> linuxSystemsChanged() => _invokeVoid(
    'linuxSystemsChanged',
    supported: isAndroid || isIOS,
    label: 'linuxSystemsChanged',
  );

  /// Stops Android's terminal foreground service after its queued starts have
  /// been handled.
  static Future<void> stopService() => _invokeVoid(
    'stopService',
    supported: isAndroid,
    label: 'Failed to stop Android terminal service',
  );

  /// Whether leaving the app should start the keep-alive service. Started by
  /// the activity's own `onPause`, since a request from here can arrive after
  /// the app is background and be refused.
  static Future<void> setKeepAliveInBackground(bool value) => _invokeVoid(
    'setKeepAliveInBackground',
    supported: isAndroid,
    args: value,
    label: 'Failed to set keep-alive',
  );

  static Future<void> updateHomeWidget() => _invokeVoid(
    'updateHomeWidget',
    supported: (isIOS || isAndroid) && Stores.setting.autoUpdateHomeWidget.fetch(),
    label: 'Failed to update home widget',
  );

  /// Hand the home-screen widgets the current monitor server list and a
  /// read-only credential for each.
  ///
  /// The native side splits the payload: the list goes to a container the
  /// widget process reads directly (the iOS App Group, Android's shared
  /// preferences), and every `token` is moved into the platform credential
  /// store instead — see `WidgetSync` for why. It is a full replacement, so a
  /// server absent from [payload] has its stored token dropped as well.
  static Future<void> publishWidgetServers(String payload) async {
    if (!isIOS && !isAndroid) return;
    await _channel.invokeMethod('publishWidgetServers', payload);
  }

  /// Which servers the native side currently holds a widget token for, and
  /// until when — as JSON, `[{"id","endpoint","expiresAt"}]`.
  ///
  /// Never the token itself. The renewal decision needs the endpoint it
  /// belongs to and its deadline, and carrying the credential back across the
  /// channel to answer that would undo the point of storing it natively.
  ///
  /// Answers from the *platform*, not from a copy kept here, because those two
  /// come apart exactly where it matters: a reinstall empties the Keychain
  /// while a restored backup refills this app's own database, and a renewal
  /// decision made from the latter would skip every server whose credential no
  /// longer exists.
  static Future<String?> widgetTokenState() async {
    if (!isIOS && !isAndroid) return null;
    return await _channel.invokeMethod<String>('widgetTokenState');
  }

  /// Last pair pushed by [setIslandBrandColors], so that rebuilding the theme —
  /// which happens on every `MaterialApp` build — does not cross the channel
  /// each time.
  static (int, int)? _islandBrandColors;

  /// Colors for the app name drawn behind the Dynamic Island, as ARGB.
  ///
  /// Follows the theme rather than being fixed, so the badge in a screenshot
  /// matches the app the screenshot is of.
  static Future<void> setIslandBrandColors(int bg, int fg) async {
    if (!isIOS) return;
    if (_islandBrandColors == (bg, fg)) return;
    _islandBrandColors = (bg, fg);
    try {
      await _channel.invokeMethod('setIslandBrandColors', {'bg': bg, 'fg': fg});
    } catch (e, s) {
      _islandBrandColors = null;
      Loggers.app.warning('Failed to set island brand colors', e, s);
    }
  }

  /// Tell the native side whether to cover the app once it leaves the
  /// foreground, hiding its content from the app switcher.
  ///
  /// What "cover" means differs by platform, and deliberately so. iOS lays a
  /// real blur over the Flutter window. Android sets `FLAG_SECURE` instead:
  /// Flutter draws into a `SurfaceView` that `RenderEffect` cannot reach, and
  /// anything that has to render a frame races the system's recents capture,
  /// which the flag does not.
  ///
  /// Pushed on change *and* at launch: the native side answers this from its
  /// own persisted copy, which a reinstall or a restored backup leaves saying
  /// something different from the (synced) settings store.
  ///
  /// Answers whether the native side took it, rather than throwing, so that the
  /// launch-time push can ignore a failure while the switch does not. Storing a
  /// preference the platform never received would leave the user told they are
  /// covered when they are not.
  static Future<bool> setPrivacyBlur(bool enabled) async {
    if (!isIOS && !isAndroid) return true;
    try {
      await _channel.invokeMethod('setPrivacyBlur', enabled);
      return true;
    } catch (e, s) {
      Loggers.app.warning('Failed to set privacy blur', e, s);
      return false;
    }
  }

  /// Tells iOS whether work is in flight that suspension would cut off, so it
  /// asks for background time to finish it. See [InFlightWork].
  static Future<void> setInFlightWork(bool inFlight) => _invokeVoid(
    'setInFlightWork',
    supported: isIOS,
    args: inFlight,
    label: 'Failed to set in-flight work',
  );

  /// Hold the cover in place after the app comes forward, until Flutter has
  /// decided whether a biometric lock is coming.
  ///
  /// Without it the cover comes off the moment the app is frontmost, and the
  /// real UI is on screen for however many frames it takes Flutter to hear
  /// about the lifecycle change at all.
  ///
  /// Cleared just before the lock screen is pushed — on iOS the cover is a view
  /// over the whole Flutter window, so it would otherwise hide that screen
  /// rather than protect it.
  static bool? _privacyBlurLocked;

  static Future<void> setPrivacyBlurLocked(bool locked) async {
    if (!isIOS && !isAndroid) return;
    if (_privacyBlurLocked == locked) return;
    _privacyBlurLocked = locked;
    try {
      await _channel.invokeMethod('setPrivacyBlurLocked', locked);
    } catch (e, s) {
      _privacyBlurLocked = null;
      Loggers.app.warning('Failed to set privacy blur lock', e, s);
    }
  }

  /// Starts or updates Android's terminal foreground service with [payload].
  ///
  /// The native side also owns the notification permission request, so one
  /// call describes the desired state instead of racing a separate start.
  static Future<void> updateSessions(String payload) async {
    if (!isAndroid) return;
    try {
      Loggers.app.info('Updating Android sessions: $payload');
      await _channel.invokeMethod('updateSessions', payload);
    } on PlatformException catch (e, s) {
      // A denied notification permission is a supported state: Android cannot
      // run the foreground service, and the settings page explains how to
      // enable it. Do not turn every ordinary session sync into a warning.
      if (e.code == 'NOTIFICATION_PERMISSION_DENIED') return;
      Loggers.app.warning('Failed to update Android sessions', e, s);
    } catch (e, s) {
      Loggers.app.warning('Failed to update Android sessions', e, s);
    }
  }

  /// Whether Android will let this app post notifications.
  ///
  /// Read by the settings page rather than acted on: without the permission
  /// there is no foreground service, and without that the system freezes the
  /// process as soon as it is backgrounded — so `bgRun` is a switch that cannot
  /// keep its promise, and saying nothing about it leaves the user with a
  /// connection that drops for no reason they can see (#1287).
  ///
  /// True off Android, where the question does not arise.
  static Future<bool> notificationsAllowed() async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod('notificationsAllowed') == true;
    } catch (e, s) {
      Loggers.app.warning('Failed to read the notification permission', e, s);
      // Assumed granted: a failure here is this app's, and reporting it as the
      // user's problem would send them to a settings page to fix nothing.
      return true;
    }
  }

  /// Opens this app's notification settings, for the case above.
  static Future<void> openNotificationSettings() => _invokeVoid(
    'openNotificationSettings',
    supported: isAndroid,
    label: 'Failed to open the notification settings',
  );

  /// Query whether the Android foreground service is currently running.
  /// How the process ended last time, as Android recorded it.
  ///
  /// The only way this app can see a native crash: one takes the process with
  /// it, so nothing in Dart runs afterwards and nothing is written. The system
  /// keeps the record instead, and this reads it on the next launch.
  ///
  /// Null below API 30, and null when there is nothing recorded. Keys:
  /// `reason` (a name — `crash_native`, `anr`, `low_memory`,
  /// `user_requested`, …), `timestamp` (ms, and the only thing distinguishing
  /// one record from another), `description`, `status`, `importance`, and one
  /// of two traces: `trace`, a `String`, for an ANR, or `traceProto`, the
  /// bytes of a `Tombstone` protocol buffer, for a native crash on API 31+.
  /// Both are absent for every other reason, and either can be absent anyway —
  /// the traces live in a global circular buffer that another app's crash can
  /// evict.
  static Future<Map<String, Object?>?> lastExitInfo() async {
    if (!isAndroid) return null;
    try {
      final res = await _channel.invokeMapMethod<String, Object?>(
        'lastExitInfo',
      );
      return res;
    } catch (e, s) {
      Loggers.app.warning('Failed to read the last exit info', e, s);
      return null;
    }
  }

  /// What MetricKit has reported since this was last asked, on iOS and macOS.
  ///
  /// The counterpart to [lastExitInfo], for the platform that has no equivalent
  /// of it. Delivery is on the system's schedule — a payload arrives somewhere
  /// between the next launch and about a day later — so these accumulate and
  /// this hands over whatever has arrived, rather than answering "the last
  /// run". Cleared by the read.
  ///
  /// Each entry has `kind` (`crash` or `hang`), `appVersion`, `callStack`, and
  /// for a crash whichever of `signal`, `exceptionType`, `exceptionCode` and
  /// `terminationReason` the payload carried.
  static Future<List<Map<String, Object?>>> takeCrashDiagnostics() async {
    if (!isIOS && !isMacOS) return const [];
    try {
      final res = await _channel.invokeListMethod<Object?>(
        'takeCrashDiagnostics',
      );
      return [
        for (final e in res ?? const [])
          if (e is Map) e.cast<String, Object?>(),
      ];
    } catch (e, s) {
      Loggers.app.warning('Failed to read crash diagnostics', e, s);
      return const [];
    }
  }

  static Future<bool> isServiceRunning() async =>
      await _invoke<Object?>(
        'isServiceRunning',
        supported: isAndroid,
        label: 'Failed to check if Android service is running',
      ) ==
      true;

  /// Whether this build's APNs tokens are for the development environment,
  /// read from the provisioning profile it was signed with. Null off iOS, or
  /// when the native side cannot say.
  static Future<bool?> apnsSandbox() async {
    final env = await _invoke<String>(
      'apsEnvironment',
      supported: isIOS,
      label: 'Failed to read the APNs environment',
    );
    return env == null ? null : env == 'development';
  }

  // iOS Live Activities controls

  /// Whether iOS would let this app show a Live Activity right now.
  ///
  /// A separate answer from [SettingStore.liveActivity]: that is whether the
  /// app asks, this is whether the system allows. The user can refuse it per
  /// app in Settings, and can turn it off device-wide, and `Activity.request`
  /// simply fails when they have — so without asking this, a switch turned on
  /// here does nothing and says nothing about why.
  ///
  /// False off iOS and on anything before 16.2, which is where
  /// `LiveActivityManager` starts.
  static Future<bool> liveActivityAvailable() async =>
      await _invoke<bool>(
        'liveActivityAvailable',
        supported: isIOS,
        label: 'Failed to query iOS Live Activity availability',
      ) ??
      false;

  static Future<void> updateLiveActivity(String payload) async {
    if (!isIOS) return;
    Loggers.app.info('Updating iOS Live Activity: $payload');
    await _invokeVoid(
      'updateLiveActivity',
      supported: true,
      args: payload,
      label: 'Failed to update iOS Live Activity',
    );
  }

  static Future<void> stopLiveActivity() async {
    if (!isIOS) return;
    Loggers.app.info('Stopping iOS Live Activity');
    await _invokeVoid(
      'stopLiveActivity',
      supported: true,
      label: 'Failed to stop iOS Live Activity',
    );
  }

  /// The contents of a share file the platform handed this app, and clears it.
  ///
  /// A `.sbxsrv` arrives by AirDrop, from the Files app, or from the Finder,
  /// and the platform's answer to all three is to launch or foreground this
  /// app with a URL. The native side reads the bytes — on iOS out of an inbox
  /// directory the app is expected to empty — and holds them until this asks.
  ///
  /// **Apple platforms only.** Android has no file association here: a filter
  /// narrow enough not to claim every unknown binary matches only `file://`,
  /// which nothing has been allowed to send since Android 7 and which this app
  /// could not read without a storage permission anyway. See the note in
  /// `AndroidManifest.xml`; a shared server comes in through the picker there.
  ///
  /// **Pulled, not pushed.** A channel has one handler and `registerHandler`
  /// already owns it, so a push would have to arrive somewhere nothing is
  /// listening. The caller asks after the first frame and again on every
  /// resume, which covers a cold launch and a file opened while the app was
  /// already running.
  ///
  /// Cleared by the read, so a second resume does not raise the same file
  /// again.
  static Future<String?> takeOpenedShare() => _invoke<String>(
    'takeOpenedShare',
    supported: isIOS || isMacOS,
    label: 'Failed to read the opened share',
  );

  /// The `serverbox://` link this app was last opened with, if one is waiting.
  ///
  /// Held natively and pulled, for the same reason as [takeOpenedShare]: on a
  /// cold launch the link arrives before the engine does. Android too, where a
  /// link is an ordinary VIEW intent and needs none of the file handling above.
  ///
  /// Cleared by the read.
  static Future<String?> takeOpenedLink() => _invoke<String>(
    'takeOpenedLink',
    supported: isIOS || isMacOS || isAndroid,
    label: 'Failed to read the opened link',
  );

  /// What another app shared, or sent from its text selection, as the JSON
  /// `{"kind":"text","text"}` or `{"kind":"files","paths"}`. Android only;
  /// held natively and pulled like [takeOpenedLink]. Cleared by the read.
  static Future<Map<String, Object?>?> takeIncoming() async {
    if (!isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<String>('takeIncoming');
      if (raw == null) return null;
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (e, s) {
      Loggers.app.warning('Failed to read incoming content', e, s);
      return null;
    }
  }

  /// Deletes the batches holding [paths], which `IncomingFiles` copied in.
  /// The native side decides what is a batch; anything else is left alone.
  static Future<void> discardIncoming(List<String> paths) => _invokeVoid(
    'discardIncoming',
    supported: isAndroid && paths.isNotEmpty,
    args: paths,
    label: 'Failed to discard incoming files',
  );

  /// The launcher's long-press list: `[{"id","label","uri"}]`, in order.
  static Future<void> setShortcuts(String payload) => _invokeVoid(
    'setShortcuts',
    supported: isAndroid,
    args: payload,
    label: 'Failed to set launcher shortcuts',
  );

  /// Asks the launcher to pin a shortcut; false when it cannot.
  static Future<bool> pinShortcut({
    required String id,
    required String label,
    required String uri,
  }) async =>
      await _invoke<bool>(
        'pinShortcut',
        supported: isAndroid,
        args: {'id': id, 'label': label, 'uri': uri},
        label: 'Failed to pin a shortcut',
      ) ??
      false;

  /// The transfer notification: `{"title","text","progress","chip"}`, or null
  /// to take it down.
  static Future<void> updateTransfers(String? payload) => _invokeVoid(
    'updateTransfers',
    supported: isAndroid,
    args: payload,
    label: 'Failed to update the transfer notification',
  );

  /// The keys listed by the system's shortcut list (Meta+/):
  /// `[{"label","items":[{"label","chord"}]}]`.
  static Future<void> setKeyboardShortcuts(String payload) => _invokeVoid(
    'setKeyboardShortcuts',
    supported: isAndroid,
    args: payload,
    label: 'Failed to set keyboard shortcuts',
  );

  /// The per-app language of Android 13+: `current`, the system's tags
  /// (empty for the system language), and `agreed`, what it held right after
  /// the app last set it (null before the first time). Null below 13.
  static Future<({String current, String? agreed})?> appLocale() async {
    if (!isAndroid) return null;
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('appLocale');
      if (r == null) return null;
      return (current: r['current'] as String? ?? '', agreed: r['agreed'] as String?);
    } catch (e, s) {
      Loggers.app.warning('Failed to read the app locale', e, s);
      return null;
    }
  }

  /// Sets the per-app language, and records what the system then holds as
  /// `agreed`.
  static Future<void> setAppLocale(String tag) => _invokeVoid(
    'setAppLocale',
    supported: isAndroid,
    args: tag,
    label: 'Failed to set the app locale',
  );

  /// Its own channel, deliberately.
  ///
  /// A channel has exactly one handler and [registerHandler] already owns the
  /// main one, so a second `setMethodCallHandler` on that name would silently
  /// replace it. Separate names cannot collide however either side grows.
  static const _shareChannel = MethodChannel(
    '${Miscs.pkgName}/incoming_share',
  );

  /// Runs [onOpened] when the platform hands this app a share or a link while
  /// it is **already frontmost**.
  ///
  /// The lifecycle covers the other two ways in — a cold launch, and coming
  /// forward to answer the open. It does not cover this one: an app that never
  /// left the foreground gets no `resumed` edge, so nothing would ask, and
  /// [takeOpenedShare] would keep holding the payload until some later
  /// unrelated resume raised the prompt out of nowhere. Reachable on iPadOS in
  /// Split View, where two apps are foreground at once.
  ///
  /// Push rather than pull only for the trigger; the payload still comes
  /// back through [takeOpenedShare] or [takeOpenedLink], so there is one path
  /// that reads and clears it however the app was told.
  static void onOpened(VoidCallback onOpened) {
    if (!isIOS && !isMacOS && !isAndroid) return;
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'opened') onOpened();
    });
  }

  static const _windowControlsChannel = MethodChannel(
    '${Miscs.pkgName}/window_controls',
  );

  /// Keeps [WindowControls] at what the platform reports — iPadOS, where a
  /// windowed app has its window controls drawn over it, and iPhone Duo,
  /// whose bars stand in a column at the side or in the top inset.
  ///
  /// Read once as well as listened to: the first report can come before this
  /// handler is set.
  static void watchWindowControls() {
    if (!isIOS) return;
    Rect? rect(Object? raw) => switch (raw) {
      [final num l, final num t, final num r, final num b] =>
        Rect.fromLTRB(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble()),
      _ => null,
    };
    void apply(Object? raw) {
      final state = raw as Map? ?? const {};
      WindowControls.zones.value = [
        for (final z in (state['zones'] as List?) ?? const []) ?rect(z),
      ];
      WindowControls.verticalBar.value = rect(state['bar']);
      WindowControls.topBar.value = rect(state['topBar']);
      WindowControls.fold.value = switch (state['fold']) {
        [final num l, final num t, final num r, final num b, final num a] => (
          rect: Rect.fromLTRB(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble()),
          active: a != 0,
        ),
        _ => null,
      };
      WindowControls.cornerInsets.value = switch (state['corners']) {
        [final num l, final num t, final num r, final num b] =>
          EdgeInsets.fromLTRB(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble()),
        _ => EdgeInsets.zero,
      };
    }

    // The reply to the read below can arrive after a push sent later, and
    // would put back what was there before it.
    var pushed = false;
    _windowControlsChannel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        pushed = true;
        apply(call.arguments);
      }
    });
    _windowControlsChannel
        .invokeMethod<Object?>('state')
        .then((raw) {
          if (!pushed) apply(raw);
        })
        .catchError((Object e) {
          Loggers.app.warning('windowControls', e);
        });
  }

  /// Register a handler for native -> Flutter callbacks.
  /// Currently handles:
  /// - `stopAllConnections` with no arguments
  /// - `notificationPermissionGranted` with no arguments
  /// - `activityPaused` / `activityResumed` with no arguments
  static void registerHandler({
    VoidCallback? onStopAll,
    VoidCallback? onNotificationPermissionGranted,
    void Function(bool backgrounded)? onBackgrounded,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'stopAllConnections':
          onStopAll?.call();
          return null;
        // Asked before a drop from another app is copied in: see [DropZones].
        case 'acceptsDrop':
          return DropZones.accepting;
        // Android asks for the permission asynchronously, so the call that
        // triggered the prompt has already been refused by the time the user
        // answers it. This is the only edge that says the answer was yes, and
        // without acting on it the foreground service stays stopped until
        // something else happens to sync — see [updateSessions].
        case 'notificationPermissionGranted':
          onNotificationPermissionGranted?.call();
          return null;
        case 'activityPaused':
          onBackgrounded?.call(true);
          return null;
        case 'activityResumed':
          onBackgrounded?.call(false);
          return null;
        default:
          return null;
      }
    });
  }
}
