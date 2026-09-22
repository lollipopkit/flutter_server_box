part of '../home.dart';

/// The app coming and going: the lock screen and the privacy cover, a
/// share opened from outside, what a launch has to say, the server
/// refresh cycle, and the system UI a fullscreen tab hides.
extension _HomePageLifecycle on _HomePageState {
  /// What a lifecycle edge means on a phone. A desktop never gets here —
  /// see [_HomePageState.didChangeAppLifecycleState].
  void _handleMobileLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Before anything else, so the foreground service can be let go while
        // the app is allowed to ask for it again.
        TermSessionManager.setBackgrounded(false);
        _lastFullscreenMode = null;
        if (_shouldAuth) {
          final delay = Stores.setting.delayBioAuthLock.fetch();
          if (delay > 0 && _pausedTime != null) {
            final now = DateTime.now();
            if (now.difference(_pausedTime ?? now).inSeconds > delay) {
              unawaited(_authed = _goAuth());
            } else {
              _shouldAuth = false;
              _releasePrivacyCover();
            }
            _pausedTime = null;
          } else {
            unawaited(_authed = _goAuth());
          }
        } else {
          _releasePrivacyCover();
        }
        unawaited(_restartServerRefreshCycle());
        unawaited(MethodChans.updateHomeWidget());
        _syncFullscreenSystemUi();
        break;
      case AppLifecycleState.paused:
        _lastFullscreenMode = null;
        _pausedTime = DateTime.now();
        _shouldAuth = true;
        // Decided here rather than on the way back: the native cover comes off
        // the moment the app is frontmost, which is several frames before
        // Flutter hears about it and can push the lock screen.
        if (Stores.setting.useBioAuth.fetch()) {
          unawaited(MethodChans.setPrivacyBlurLocked(true));
        }
        if (!(isAndroid && Stores.setting.bgRun.fetch())) {
          _stopServerRefreshCycle();
        }
        break;
      case AppLifecycleState.inactive:
        // Not in `paused`, which is too late. Android refuses to *start* a
        // foreground service for an app that is already in the background, and
        // `paused` is delivered from `onStop` — by then the activity is gone.
        // `inactive` comes from `onPause`, while it is still visible, which is
        // the last moment the request is allowed.
        //
        // The cost is that pulling down the notification shade also reads as
        // leaving, so a device with nothing connected can show the keep-alive
        // notification for as long as the shade is open. That is the same
        // notification `bgRun` asks for anyway, and the alternative is a
        // request the system turns down.
        TermSessionManager.setBackgrounded(true);
        break;
      default:
        break;
    }
  }

  /// The launch notices and then the guide, one after another and behind
  /// the lock screen — see [_HomePageState.afterFirstLayout].
  Future<void> _showLaunchNotices(Future<void> authed) async {
    // Behind the lock screen, not beside it. Every one of these is a
    // root-navigator dialog, and the lock page is on that navigator too —
    // see [_goAuth]. Completes immediately when no lock is configured.
    await authed;
    if (!mounted) return;
    // Says so when this launch took over the sandboxed build's data, or
    // when it could not — see [SandboxImport].
    await SandboxImportNotice.showIfNeeded(context);
    if (!mounted) return;
    // Says so when this upgrade took a feature away — see
    // [LegacyStatusUrlsMigration].
    await LegacyStatusNotice.showIfNeeded(context);
    if (!mounted) return;
    // Nothing about the previous run is raised here any more. A crash used
    // to put a toast in front of somebody who had just opened the app to do
    // something else, once, on the one launch that read the marker; the
    // report is now kept and waits under **Settings → Privacy** — see
    // [CrashReportDialog]. The two notices above stay: both are about data
    // this launch changed, which is not something to find out about later.
    // A share opened from AirDrop or the Files app while this app was not
    // running: the platform launched it with the URL, and the native side
    // has been holding the bytes since before the first frame.
    //
    // **Before the guide, not after.** The guide is an overlay above every
    // route and skips itself when something else is up — which only works if
    // the something else is already there. With this second, a launch that
    // had both drew the hint on top of the passphrase prompt the user had
    // just asked for, and the guide's own button sat over the dialog's.
    // Answering the file the user opened comes first either way.
    await _consumePendingShare();
    if (!mounted) return;
    await _maybeShowNavGuide();
  }

  /// Takes in a `.sbxsrv` the platform handed this app, if one is waiting.
  Future<void> _consumePendingShare() async {
    if (_consumingShare) return;
    // Before the launch path has decided whether there is a lock, [_authed] is
    // null and awaiting it waits for nothing — so a `resumed` edge arriving
    // first (a cold launch on macOS, where opening the file is what activates
    // the app) would put the passphrase prompt on the same root navigator as
    // the lock page, over it. Returning costs nothing: the launch path calls
    // this itself once it has assigned it, and taking the guard below would
    // have made that call a no-op instead.
    if (_authed == null) return;
    _consumingShare = true;
    try {
      final text = await MethodChans.takeOpenedShare();
      if (text == null || text.isEmpty || !mounted) return;
      // Behind the lock screen for the same reason the launch notices are: it
      // is a root-navigator dialog, and the lock page is on that navigator.
      //
      // Read here rather than captured on entry, and that ordering matters:
      // this method is called from the top of `didChangeAppLifecycleState`,
      // before the branch that starts the lock. The platform call above is a
      // channel round trip, so the rest of that method — including assigning
      // the new [_authed] — has run by the time this line does.
      await _authed;
      if (!mounted) return;
      await ServerShareUi.consume(context, ref, text, digitsOnly: false);
    } catch (e, s) {
      Loggers.app.warning('Consume the opened share', e, s);
    } finally {
      _consumingShare = false;
    }
  }

  /// Completes once the lock screen, if there is one, has been dismissed.
  ///
  /// Awaited by the launch notices. `showRoundDialog` puts a dialog on the
  /// *root* navigator, which is the one holding the lock page, so anything
  /// raised while it is up draws over it — and the crash report renders the
  /// previous run's log, which is precisely what a lock screen exists to keep
  /// unread. The other two notices are no better placed there.
  /// [showGuide] is false on the launch path, where the caller shows the guide
  /// itself once the launch notices have been through.
  ///
  /// The call below runs *before* this method's own future completes, so a
  /// launch with a lock configured had the guide up before the crash and
  /// migration notices it is supposed to follow — the ordering the caller
  /// spells out, defeated by the one branch that does not go through it.
  /// Resuming has no such sequence and is where this still has to happen.
  Future<void> _goAuth({bool showGuide = true}) async {
    // First, and on every path out of here. On iOS the cover is a view over the
    // Flutter window, so it is *above* every route drawn inside it — left up it
    // would hide the lock screen instead of protecting it. Releasing it before
    // the push costs at most the frames until the route appears, and in
    // practice the channel round trip outlasts the push.
    //
    // The path that matters is the early return below. Backgrounding *from* the
    // lock screen and coming back re-locks the cover and lands here, where
    // `alreadyIn` is true — and skipping this left the cover over that screen
    // with nothing that would ever take it off, since the next trip out and
    // back returns at exactly the same place.
    _releasePrivacyCover();

    if (!Stores.setting.useBioAuth.fetch()) return;
    if (LocalAuthPage.route.alreadyIn) return;

    // The route's own future, not `onAuthSuccess`. That callback runs from
    // inside `context.pop()`, while the lock screen is still the route the
    // navigator answers with — so the guide's "is the home page current"
    // check would say no and skip it every launch, on exactly the devices
    // this branch exists for. The future completes once the pop has.
    await LocalAuthPage.route.go(
      context,
      args: LocalAuthPageArgs(
        onAuthSuccess: () => _shouldAuth = false,
        onUnavailable: _onAuthUnavailable,
      ),
    );
    if (showGuide) await _maybeShowNavGuide();
  }

  /// This device cannot answer the lock, so stop asking it.
  ///
  /// The setting is only ever true here because it arrived from somewhere else:
  /// a backup taken on a phone, restored onto a machine with no sensor. The
  /// lock screen has no way to open on such a machine, and the settings page
  /// hides the switch when `LocalAuth.isAvail` is false — so the one control
  /// that would turn it off is missing on exactly the devices that need it,
  /// and the app was unusable (#1406).
  ///
  /// Written without a sync timestamp. This is a fact about *this* machine, and
  /// stamping it would let the next sync carry it to the phone the backup came
  /// from and silently unlock that too.
  void _onAuthUnavailable() {
    _shouldAuth = false;
    final prop = Stores.setting.useBioAuth;
    final saved = prop.store.set(prop.key, false, updateLastUpdateTsOnSet: false);
    // `set` answers false rather than throwing. Worth a line and nothing more:
    // the app is already past the lock either way, and the cost of a failed
    // write is being asked once more on the next launch.
    if (saved != true) {
      Loggers.app.warning('Could not turn ${prop.key} off on a device '
          'that cannot authenticate');
    }
  }

  /// Let the native privacy cover come off, now that either the lock screen is
  /// about to take over or it was established that none is coming.
  void _releasePrivacyCover() {
    unawaited(MethodChans.setPrivacyBlurLocked(false));
  }

  bool get _canRefreshServers {
    if (isDesktop) return true;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      return true;
    }
    return isAndroid && Stores.setting.bgRun.fetch();
  }

  /// Starts a new polling cycle without letting its timer race the first run.
  ///
  /// The generation prevents a refresh that finishes after pause, dispose or a
  /// newer restart from turning the timer back on. Repeated restart requests
  /// share the notifier's global refresh queue; only the latest one schedules
  /// the next poll.
  Future<void> _restartServerRefreshCycle() async {
    final cycle = ++_serverRefreshCycle;
    _notifier.stopAutoRefresh();
    try {
      await _notifier.refresh();
    } catch (error, stackTrace) {
      Loggers.app.warning('Initial server refresh failed', error, stackTrace);
    }
    if (!mounted || cycle != _serverRefreshCycle || !_canRefreshServers) return;
    await _notifier.startAutoRefresh();
  }

  void _stopServerRefreshCycle() {
    _serverRefreshCycle++;
    _notifier.stopAutoRefresh();
  }

  bool get _isServerFullscreenMode {
    if (!Stores.setting.fullScreen.fetch()) return false;
    if (_tabs.isEmpty) return false;
    final selectedIndex = _selectIndex.value;
    if (selectedIndex < 0 || selectedIndex >= _tabs.length) return false;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return isLandscape && _tabs[selectedIndex] == AppTab.server;
  }

  void _syncFullscreenSystemUi({bool? forceHide}) {
    if (!isMobile) return;
    final hide = forceHide ?? _isServerFullscreenMode;
    if (_lastFullscreenMode == hide) return;
    _lastFullscreenMode = hide;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemUIs.switchStatusBar(hide: hide);
    });
  }
}
