part of 'tab.dart';

extension _DetailHost on _ServerPageState {
  /// The open server's own page, without the bar this page already has.
  ///
  /// One key for every machine, so that changing which one is open is not a
  /// change the crossing above sees: what that crossing is for is the card
  /// becoming the page, and stepping from one machine to the next is a
  /// movement of its own — see [DirectionalSwap].
  Widget _buildOpenDetail(String id) {
    final spi = ref.read(serversProvider).servers[id];
    if (spi == null) return const SizedBox.shrink();
    return KeyedSubtree(
      key: const ValueKey('detail'),
      // Where the bar floating over this learns that it is being read past.
      // It is not inside the page any more, so it has no controller to ask —
      // and there is a page per machine, so there would be a different one
      // after every step through the list.
      child: NotificationListener<ScrollNotification>(
        onNotification: _onDetailScroll,
        child: DirectionalSwap(
          id: id,
          direction: _swapDirection,
          duration: context.motion(_kOpenDuration),
          child: _detailFor(id, spi),
        ),
      ),
    );
  }

  Widget _detailFor(String id, Spi spi) {
    return KeyedSubtree(
      key: ValueKey('detail:$id'),
      // Opaque, because the grid is drawn on top of it while the card is
      // growing: a translucent page would show the two layouts through each
      // other for the length of the movement.
      child: Material(
        type: MaterialType.canvas,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ServerDetailPage(
          args: SpiRequiredArgs(spi),
          bare: true,
          // Mounted from the first frame of the movement, so what it has that
          // the card has not arrives with the chart rather than after it.
          entrance: _open,
          // Until then the card is the one drawing them.
          readingsShowing: _detailShowing,
        ),
      ),
    );
  }

  /// Whether the page under the function row is being read past.
  bool _onDetailScroll(ScrollNotification n) {
    // The page's own scrollable, not a list inside one of its cards.
    if (n.depth != 0) return false;
    final next = switch (n) {
      UserScrollNotification(:final direction) => switch (direction) {
        // The direction dragged, not the direction the offset moved: a list
        // settling after a fling is not someone asking for this.
        ScrollDirection.reverse => false,
        ScrollDirection.forward => true,
        ScrollDirection.idle => _funcBarVisible.value,
      },
      _ => _funcBarVisible.value,
    };
    // Always there at the top, whatever the last drag was.
    _funcBarVisible.value =
        next || n.metrics.pixels <= n.metrics.minScrollExtent;
    return false;
  }
}
