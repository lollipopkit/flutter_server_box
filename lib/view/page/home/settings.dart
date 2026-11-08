// ignore_for_file: invalid_use_of_protected_member

part of '../home.dart';

/// The settings, shown where a tab is shown rather than over the window.
extension _HomePageSettings on _HomePageState {
  /// Whether the tabs are laid out at all.
  ///
  /// Only once the settings have finished arriving. Offstage is not laid out,
  /// so hiding them the moment the animation *starts* would leave nothing to
  /// fade out of.
  bool get _tabsHidden => _settingsOpen && _settingsCtrl.isCompleted && !_settingsSwiping;

  /// Whether the settings are laid out, which they are for the whole of their
  /// own leaving as well.
  bool get _settingsShowing => _settingsOpen || !_settingsCtrl.isDismissed;

  /// The settings' own navigator, crossing with the tabs.
  Widget _buildSettingsPane() {
    // Its own navigator, like a tab's: what the settings push — the private
    // keys, a backup, the raw editor — belongs over the settings and not over
    // the window.
    return Offstage(
      offstage: !_settingsShowing,
      child: TickerMode(
        enabled: _settingsShowing,
        child: IgnorePointer(
          // On the way out it is still painted and still on top, so without
          // this a tap meant for the tab underneath would land on a page that
          // is leaving.
          ignoring: !_settingsOpen,
          child: _crossed(
            leaving: false,
            // Still painted on the way out; back is the tabs' by then.
            child: BackScope(
              enabled: _settingsOpen,
              child: NestedNavigator(
                key: const ValueKey('settings'),
                navigatorKey: _settingsNavKey,
                observers: [AgentScreen.settingsObserver],
                // The window's bottom inset, which the `Scaffold` takes from
                // its body for the bottom bar — and that bar has left with
                // the tabs, so without this the settings' own tabs sat on
                // the home indicator.
                rootBuilder: (ctx) => MediaQuery(
                  data: MediaQuery.of(ctx).copyWith(
                    padding: MediaQuery.paddingOf(ctx).copyWith(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SettingsPage(
                      onLeave: _closeSettings,
                      onSwipe: _followSettingsSwipe,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One side of the crossing between the tabs and the settings.
  ///
  /// [leaving] is the side that is on its way out as the settings arrive —
  /// the tabs — so the two fade in opposite directions and are displaced in
  /// opposite directions, which is what reads as one replacing the other
  /// rather than as two things fading independently.
  ///
  /// Only the fade where the device has asked for less movement. The slide
  /// stays in the tree with nowhere to go rather than being left out: the
  /// tabs are under it, and a different tree would build them again.
  Widget _crossed({required bool leaving, required Widget child}) {
    // A swipe draws its own: the tabs under it as they are, the settings
    // shrunk to the finger, and fading only once let go to leave.
    if (_settingsSwiping) {
      if (leaving) return child;
      return FadeTransition(
        opacity: _settingsAnim,
        child: AnimatedBuilder(
          animation: _settingsSwipe,
          builder: (context, child) => _predictiveBack(_settingsSwipe.value, child!),
          child: child,
        ),
      );
    }
    final shift = context.reduceMotion ? 0.0 : 0.03;
    return FadeTransition(
      opacity: leaving
          ? Tween(begin: 1.0, end: 0.0).animate(_settingsAnim)
          : _settingsAnim,
      child: SlideTransition(
        position: Tween(
          begin: leaving ? Offset.zero : Offset(shift, 0),
          end: leaving ? Offset(-shift, 0) : Offset.zero,
        ).animate(_settingsAnim),
        child: child,
      ),
    );
  }

  /// [page] as Android's predictive back draws a page [progress] of the way
  /// back: smaller, moved toward the finger's side, its corners rounded.
  Widget _predictiveBack(double progress, Widget page) {
    final width = MediaQuery.sizeOf(context).width;
    return Transform.translate(
      offset: Offset(progress * (width / 20 - 8), 0),
      child: Transform.scale(
        scale: 1 - 0.1 * progress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32 * progress),
          child: page,
        ),
      ),
    );
  }

  /// A back swipe on the settings' first page, [progress] of the way; null,
  /// let go short of leaving, back to the settings. A swipe that goes
  /// through puts them away ([_closeSettings]), fading from where it left
  /// the page.
  void _followSettingsSwipe(double? progress) {
    if (!_settingsOpen) return;
    if (progress == null) return _settlePredictiveBack();
    if (!_settingsSwiping) setState(() => _settingsSwiping = true);
    _settingsSwipe.value = progress;
  }

  /// Back to the settings as they were, the swipe undone.
  void _settlePredictiveBack() {
    if (!_settingsSwiping) return;
    _settingsSwipe.reverse().whenCompleteOrCancel(() {
      if (!mounted || !_settingsOpen) return;
      setState(() => _settingsSwiping = false);
    });
  }

  /// Puts the settings away once what they hold agreed to go; false when
  /// something refused.
  Future<bool> _closeSettings() {
    if (!_settingsOpen) return SynchronousFuture(true);
    return _closingSettings ??= _putSettingsAway().whenComplete(
      () => _closingSettings = null,
    );
  }

  Future<bool> _putSettingsAway() async {
    if (!_settingsOpen) return true;
    final nav = _settingsNavKey.currentState;
    // What was agreed to be dropped goes; the rest keeps its place for the
    // next opening, as a tab does.
    if (nav != null && !await PopGuard.leave(nav)) {
      // A swipe may have taken them part of the way.
      if (mounted && _settingsOpen) _settlePredictiveBack();
      return false;
    }
    if (!mounted || !_settingsOpen) return true;
    setState(() => _settingsOpen = false);
    AgentScreen.settingsOpen = false;
    _settingsCtrl.reverse();
    return true;
  }

  /// Shows the settings where a tab is shown, at every width: one form, so a
  /// rotation or a resize changes the layout around them and nothing else.
  void _openSettings() {
    if (_settingsOpen) return;
    setState(() {
      _settingsOpen = true;
      _settingsSeen = true;
    });
    AgentScreen.settingsOpen = true;
    _settingsCtrl.forward();
  }
}
