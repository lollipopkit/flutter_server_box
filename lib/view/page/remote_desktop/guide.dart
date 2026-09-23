part of 'viewer.dart';

/// The viewer's walkthrough, once per install.
///
/// What it has to say is what the screen does not: on a touch screen the
/// canvas is a touchpad, so a finger moves the pointer instead of clicking
/// where it lands, and two fingers right-click, scroll and zoom. The buttons
/// after that are the ones whose effect is not on their face — view only
/// looks like a mouse, and Ctrl+Alt+Delete is behind the menu.
///
/// Not the fit and zoom buttons: pressing one shows what it does.
extension _GuideX on _RemoteDesktopViewerState {
  /// Waits for a desktop to be on screen. Before that the canvas is a status
  /// line, and a certificate prompt may still be up over it.
  void _scheduleGuide(RemoteDesktopSessionView session) {
    if (_guideHandled) return;
    if (!session.connected || session.width <= 0) return;
    _guideHandled = true;
    if (Stores.setting.remoteDesktopGuided.fetch()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showGuide());
    });
  }

  Future<void> _showGuide() async {
    // The overlay draws above every route, so it would cover a dialog rather
    // than wait for it. Skipping leaves the guide for the next session.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    // Kept alive behind the other tabs; null is this viewer mounted outside
    // the home page.
    final tab = ref.read(currentHomeTabProvider);
    if (tab != null && tab != AppTab.remoteDesktop) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    Rect? spot(GlobalKey key) => rectInOverlay(key.currentContext, overlay);
    // Null in full screen on a phone, which has no toolbar. Left for later.
    final viewOnly = spot(_viewOnlyKey);
    final more = spot(_moreKey);
    if (viewOnly == null || more == null) return;

    final l10n = context.l10n;
    final touch = isMobile;
    final keyboard = spot(_keyboardKey);
    await GuideOverlay.show(context, [
      if (touch)
        GuideStep(
          title: l10n.remoteDesktopGuideTouch,
          body: l10n.remoteDesktopGuideTouchTip,
          spot: spot(_canvasKey),
        ),
      if (touch && keyboard != null)
        GuideStep(
          title: l10n.remoteDesktopShowKeyboard,
          body: l10n.remoteDesktopGuideKeyboardTip,
          spot: keyboard,
        ),
      GuideStep(
        title: l10n.remoteDesktopViewOnly,
        body: l10n.remoteDesktopGuideViewOnlyTip,
        spot: viewOnly,
      ),
      GuideStep(
        title: l10n.remoteDesktopMoreControls,
        body: touch
            ? '${l10n.remoteDesktopGuideMoreTip} '
                  '${l10n.remoteDesktopGuidePointerTip}'
            : l10n.remoteDesktopGuideMoreTip,
        spot: more,
      ),
    ]);
    // Written when it has been seen through, not when it was scheduled.
    Stores.setting.remoteDesktopGuided.put(true);
  }
}
