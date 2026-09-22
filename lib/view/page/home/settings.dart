// ignore_for_file: invalid_use_of_protected_member

part of '../home.dart';

/// The settings, shown where a tab is shown rather than over the window.
extension _HomePageSettings on _HomePageState {
  /// Whether the tabs are laid out at all.
  ///
  /// Only once the settings have finished arriving. Offstage is not laid out,
  /// so hiding them the moment the animation *starts* would leave nothing to
  /// fade out of.
  bool get _tabsHidden => _settingsOpen && _settingsCtrl.isCompleted;

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
            child: NestedNavigator(
              key: const ValueKey('settings'),
              navigatorKey: _settingsNavKey,
              rootBuilder: (_) => const SafeArea(
                bottom: false,
                child: SettingsPage(),
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
  Widget _crossed({required bool leaving, required Widget child}) {
    const shift = 0.03;
    return FadeTransition(
      opacity: leaving
          ? Tween(begin: 1.0, end: 0.0).animate(_settingsAnim)
          : _settingsAnim,
      child: SlideTransition(
        position: Tween(
          begin: leaving ? Offset.zero : const Offset(shift, 0),
          end: leaving ? const Offset(-shift, 0) : Offset.zero,
        ).animate(_settingsAnim),
        child: child,
      ),
    );
  }

  /// Puts the settings away, where they are shown in place of a tab.
  void _closeSettings() {
    if (!_settingsOpen) return;
    setState(() => _settingsOpen = false);
    _settingsCtrl.reverse();
  }

  /// Shows the settings where a tab is shown, rather than over everything.
  ///
  /// Only where there is a rail to keep on screen. A phone has none to cover,
  /// and no room for a second strip under the settings' own floating one — so
  /// there they stay a page, with the bar's back button as the way out.
  void _openSettings() {
    if (_narrow) {
      SettingsPage.route.go(context);
      return;
    }
    if (_settingsOpen) return;
    setState(() {
      _settingsOpen = true;
      _settingsSeen = true;
    });
    _settingsCtrl.forward();
  }
}
