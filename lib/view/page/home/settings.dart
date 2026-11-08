// ignore_for_file: invalid_use_of_protected_member

part of '../home.dart';

/// The settings: a page pushed where a tab is shown, over the tabs and beside
/// the rail, so the rail stays the way back out.
extension _HomePageSettings on _HomePageState {
  /// The tabs, and what is pushed over them in place of a tab: the settings.
  ///
  /// A navigator of its own rather than the window's, which would cover the
  /// rail. The tabs are its first page, so they stay mounted under the
  /// settings — every terminal, scroll and route they hold — and the settings
  /// arrive, leave and are swiped back like any other page.
  ///
  /// The bar is the tabs', so the settings cover it as they arrive; their own
  /// bar is the way out.
  Widget _buildArea({required Widget? bar}) {
    return NestedNavigator(
      navigatorKey: _areaNavKey,
      observers: [_areaRoutes, AgentScreen.settingsObserver],
      // Always a `Scaffold`, the bar or not: a different widget here would
      // mount the tabs again. Its own messenger, so a tab's snack bar stands
      // over the bar rather than on it.
      rootBuilder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildTabPages(),
          bottomNavigationBar: bar,
        ),
      ),
    );
  }

  /// Puts the settings away, once what they hold agreed to go; false when
  /// something refused.
  Future<bool> _closeSettings() async {
    final nav = _areaNavKey.currentState;
    if (nav == null || !_settingsOpen) return true;
    return nav.popUntilGuarded((route) => route.isFirst);
  }

  void _openSettings() {
    if (_settingsOpen) return;
    final nav = _areaNavKey.currentState;
    if (nav == null) return;
    final route = AppPageRoute<void>(
      settings: const RouteSettings(name: AgentScreen.settingsRoute),
      builder: (_) => const SettingsPage(),
    );
    _onSettingsRoute(route);
    unawaited(nav.push(route));
  }

  /// [route] is the settings now, or none is when null.
  void _onSettingsRoute(Route<dynamic>? route) {
    if (_settingsRoute == route) return;
    setState(() => _settingsRoute = route);
  }
}

/// Hears the settings leave [_HomePageSettings._buildArea]'s navigator,
/// however they leave: a back, a swipe, a tab picked on the rail.
final class _AreaRoutes extends NavigatorObserver {
  _AreaRoutes(this.onGone);

  final void Function(Route<dynamic> route) onGone;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => onGone(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => onGone(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) onGone(oldRoute);
  }
}
