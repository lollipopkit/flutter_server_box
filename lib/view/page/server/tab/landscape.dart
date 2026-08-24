part of 'tab.dart';

extension on _ServerPageState {
  Widget _buildLandscape() {
    return ValueListenableBuilder<double>(
      valueListenable: _offsetNotifier,
      builder: (context, offsetValue, child) {
        final offset = Offset(offsetValue, offsetValue);
        return Padding(
          // Avoid display cutout
          padding: EdgeInsets.all(offsetValue.abs()),
          child: Transform.translate(
            offset: offset,
            child: child,
          ),
        );
      },
      // Never split: this layout is one card at a time across the whole
      // screen. Without it a server the Agent asked to open would sit in the
      // queue until the device was turned back.
      child: _ServerOpenRequest(
        split: false,
        onOpen: _openRequestedServer,
        child: Stack(
          children: [
            _buildLandscapeBody(),
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(tooltip: libL10n.setting, 
                onPressed: () => SettingsPage.route.go(context),
                icon: const Icon(Icons.settings, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeBody() {
    final serverState = ref.watch(serversProvider);
    final order = serverState.serverOrder;

    if (order.isEmpty) {
      _landscapeSeenId = null;
      _landscapeController?.dispose();
      _landscapeController = null;
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    // Keep the same server in view when order mutates (reorder/delete).
    // PageView is index-based, so without this a reorder silently switches
    // the visible server. Track by id and jump the controller to that id's
    // new index post-frame.
    final seen = _landscapeSeenId;
    if (seen != null && order.contains(seen)) {
      final targetIdx = order.indexOf(seen);
      final ctrl = _landscapeController;
      if (ctrl != null && ctrl.hasClients) {
        final current = ctrl.page?.round();
        if (current != null && current != targetIdx && current >= 0 && current < order.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _landscapeController == ctrl && ctrl.hasClients) {
              ctrl.jumpToPage(targetIdx);
            }
          });
        }
      }
    } else if (seen == null && order.isNotEmpty) {
      _landscapeSeenId = order.first;
    }

    _landscapeController ??= PageController();
    // Clamp controller if order shrank
    if (_landscapeController!.hasClients) {
      final page = _landscapeController!.page;
      if (page != null && page.round() >= order.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _landscapeController != null && _landscapeController!.hasClients) {
            _landscapeController!.jumpToPage(order.length - 1);
          }
        });
      }
    }

    return PageView.builder(
      controller: _landscapeController,
      key: ValueKey(order.join(',')),
      itemCount: order.length,
      onPageChanged: (idx) {
        if (idx >= 0 && idx < order.length) _landscapeSeenId = order[idx];
      },
      itemBuilder: (_, idx) {
        final id = order[idx];
        final srv = ref.watch(serverProvider(id));

        final title = _buildServerCardTitle(srv);
        final List<Widget> children = [
          title,
          _buildNormalCard(srv.status, srv.spi),
        ];

        return KeyedSubtree(
          key: ValueKey(id),
          child: _getCardNoti(id).listenVal((_) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            );
          }),
        );
      },
    );
  }
}
