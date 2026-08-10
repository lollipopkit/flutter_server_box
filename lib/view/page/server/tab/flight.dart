part of 'tab.dart';

/// The tapped card flying to the row it becomes in the narrow list.
///
/// Opening a server beside the list pushes no route, so there is no hero
/// flight to be had — `AdaptivePanes` only changes what the primary pane
/// draws. [OverlayFlight] does the moving; what is left here is the part only
/// this page knows: which card was tapped, and which row it turns into.
///
/// Only that one card flies. Everything else changes shape at once, which is
/// what keeps this affordable — nothing has to track where every card went,
/// and the one that moved is the one the eye is following.
extension _Flight on _ServerPageState {
  /// Grid → list only. Picking another server while the list is already a
  /// column leaves every row where it was, and there is nothing to fly.
  void _flyCardIntoPane(BuildContext cardContext, ServerState srv) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final from = rectInOverlay(cardContext, overlay);
    if (from == null) return;

    // Set before the rebuild this tap causes, so the row it names is built
    // hidden and carrying the key the landing is measured from.
    _flyingId.value = srv.spi.id;
    _awaitLanding(overlay, srv, from, attempt: 0);
  }

  /// List → grid, the way back.
  ///
  /// Measured before the caller clears the selection, because the row being
  /// flown *from* is the one the pane is about to take away — after the
  /// rebuild there is nothing left to ask where it was.
  void _flyRowIntoGrid(ServerState srv) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final from = rectInOverlay(_flightAnchorKey.currentContext, overlay);
    if (from == null) return;

    _flyingId.value = srv.spi.id;
    _awaitLanding(overlay, srv, from, attempt: 0);
  }

  void _awaitLanding(
    OverlayState overlay,
    ServerState srv,
    Rect from, {
    required int attempt,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _flyingId.value != srv.spi.id) return;

      final to = rectInOverlay(_flightAnchorKey.currentContext, overlay);
      if (to == null) {
        // Both ends are built lazily — rows by a `ListView`, cards by the
        // grid's columns — so one below the fold has no context to measure,
        // and the new layout takes a frame or two to settle. Give it those,
        // then give up rather than leave the destination hidden.
        if (attempt < 2) {
          return _awaitLanding(overlay, srv, from, attempt: attempt + 1);
        }
        _flyingId.value = null;
        return;
      }

      _flight?.cancel();
      _flight = OverlayFlight.launch(
        overlay: overlay,
        vsync: this,
        from: from,
        to: to,
        duration: _kFlightDuration,
        child: _flightCard(srv),
        onEnd: () {
          if (mounted) _flyingId.value = null;
        },
      );
    });
  }

  /// Takes down a flight in progress. Safe when there is none.
  void _endFlight() {
    _flight?.cancel();
    _flight = null;
  }

  /// What flies: the card as it will look when it lands.
  ///
  /// The same choice [Hero] makes by default, and the reason the two ends can
  /// be the same widget at all — a card whose server is not connected *is*
  /// this row, so the flight is a card shedding its charts rather than one
  /// widget turning into another.
  Widget _flightCard(ServerState srv) {
    return CardX(
      child: Padding(
        padding: _kPaneTilePadding,
        child: _buildServerCardTitle(srv),
      ),
    );
  }
}
