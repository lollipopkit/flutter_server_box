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
    _awaitLanding(overlay, srv, from, becomesRow: true, attempt: 0);
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
    _awaitLanding(overlay, srv, from, becomesRow: false, attempt: 0);
  }

  void _awaitLanding(
    OverlayState overlay,
    ServerState srv,
    Rect from, {
    required bool becomesRow,
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
          return _awaitLanding(
            overlay,
            srv,
            from,
            becomesRow: becomesRow,
            attempt: attempt + 1,
          );
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
        // Both forms, so the card sheds or grows its charts on the way rather
        // than at one end of the trip.
        child: becomesRow ? _flightRow(srv) : _flightCard(srv),
        departing: becomesRow ? _flightCard(srv) : _flightRow(srv),
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

  /// The row form: the rail entry the card lands as.
  ///
  /// Drawn selected, because a card only ever flies into the rail as the thing
  /// that was just opened, and it would otherwise arrive plain and change
  /// colour a frame later. The distribution mark is here for the same reason:
  /// both ends of the trip carry one — the card beside its name, the row in
  /// the rail's leading column — and a form without it makes the glyph blink
  /// out halfway across and back at the end.
  Widget _flightRow(ServerState srv) {
    return SideBarTile(
      title: srv.spi.name,
      leading: DistIconOf(
        srv.status.more[StatusCmdType.sys]?.dist,
        size: 17,
        color: Theme.of(context).colorScheme.primary,
      ),
      selected: true,
      live: srv.conn == ServerConn.finished,
    );
  }

  /// The grid form, charts and all.
  Widget _flightCard(ServerState srv) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.only(
          left: _cardPadSingle,
          right: 3,
          top: _cardPadSingle,
          bottom: _cardPadSingle,
        ),
        child: _buildRealServerCard(srv),
      ),
    );
  }
}
