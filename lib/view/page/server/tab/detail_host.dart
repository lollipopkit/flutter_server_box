part of 'tab.dart';

extension _DetailHost on _ServerPageState {
  /// The open item's own page, without the bar this page already has.
  Widget _buildOpenDetail(StatusCardItem item) {
    final detail = switch (item) {
      ServerCardItem(:final spi) => ServerDetailPage(
        args: SpiRequiredArgs(spi),
        bare: true,
        entrance: _open,
        readingsShowing: _detailShowing,
      ),
      BmcCardItem(:final target) => BmcDetailPage(
        args: BmcTargetRequiredArgs(target),
        bare: true,
        markAnchor: _elementFlight.detailBinding(item.cardKey),
        hideMark: _elementFlight.isFlying(item.cardKey),
      ),
      UptimerCardItem(:final monitor) => UptimerDetailPage(
        args: UptimerDetailArgs(monitor: monitor),
        bare: true,
        stripAnchor: _elementFlight.detailBinding(item.cardKey),
        hideStrip: _elementFlight.isFlying(item.cardKey),
      ),
    };

    return KeyedSubtree(
      key: const ValueKey('detail'),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onDetailScroll,
        child: DirectionalSwap(
          id: item.cardKey,
          direction: _swapDirection,
          duration: context.motion(_kOpenDuration),
          child: KeyedSubtree(
            key: ValueKey('detail:${item.cardKey}'),
            child: Material(
              type: MaterialType.canvas,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: detail,
            ),
          ),
        ),
      ),
    );
  }

  /// Whether the page under the function row is being read past.
  bool _onDetailScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final next = switch (n) {
      UserScrollNotification(:final direction) => switch (direction) {
        ScrollDirection.reverse => false,
        ScrollDirection.forward => true,
        ScrollDirection.idle => _funcBarVisible.value,
      },
      _ => _funcBarVisible.value,
    };
    _funcBarVisible.value =
        next || n.metrics.pixels <= n.metrics.minScrollExtent;
    return false;
  }
}
