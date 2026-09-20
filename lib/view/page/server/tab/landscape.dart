part of 'tab.dart';

extension _Widgets on _ServerPageState {
  Widget _buildLandscape() {
    return ValueListenableBuilder<double>(
      valueListenable: _offsetNotifier,
      builder: (context, offsetValue, child) {
        final offset = Offset(offsetValue, offsetValue);
        return Padding(
          // Avoid display cutout
          padding: EdgeInsets.all(offsetValue.abs()),
          child: Transform.translate(offset: offset, child: child),
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
              child: IconButton(
                tooltip: libL10n.setting,
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
      _clearLandscapeController();
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    _syncLandscapeSelection(order);
    final controller = _landscapePageController(order.length);

    return PageView.builder(
      controller: controller,
      key: ValueKey(order.join(',')),
      itemCount: order.length,
      onPageChanged: (idx) => _onLandscapePageChanged(idx, order),
      itemBuilder: (_, idx) {
        final id = order[idx];
        final srv = ref.watch(serverProvider(id));

        return KeyedSubtree(
          key: ValueKey(id),
          child: Center(
            child: SingleChildScrollView(
              // Use the card context so the menu is anchored to the card.
              child: Builder(
                builder: (context) => ServerCard(
                  srv: srv,
                  promoted: _promotedOf(id),
                  onPromote: (kind) => _promote(id, kind),
                  expanded: ServerCardExpanded.all.contains(id),
                  onToggleExpanded: () => _toggleExpanded(id),
                  // Never in place, for the reason the request above is never
                  // split: there is no grid here for a card to grow out of.
                  onTap: () => _onTapCard(context, srv, inPlace: false),
                  onLongPress: () => _onLongPressCard(context, srv),
                  highlighted: id == _menuId,
                ).onSecondary(
                  (at) => _onLongPressCard(context, srv, at: at),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension _LandscapeActions on _ServerPageState {
  void _clearLandscapeController() {
    _landscapeSeenId = null;
    final controller = _landscapeController;
    _landscapeController = null;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  void _syncLandscapeSelection(List<String> order) {
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
        if (current != null &&
            current != targetIdx &&
            current >= 0 &&
            current < order.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _landscapeController == ctrl && ctrl.hasClients) {
              ctrl.jumpToPage(targetIdx);
            }
          });
        }
      }
    } else if (seen != null) {
      final ctrl = _landscapeController;
      final page = ctrl != null && ctrl.hasClients
          ? ctrl.page?.round()
          : ctrl?.initialPage;
      final index = (page ?? 0).clamp(0, order.length - 1).toInt();
      _landscapeSeenId = order[index];
    } else {
      _landscapeSeenId = order.first;
    }
  }

  PageController _landscapePageController(int itemCount) {
    _landscapeController ??= PageController();
    // Clamp controller if order shrank
    if (_landscapeController!.hasClients) {
      final page = _landscapeController!.page;
      if (page != null && page.round() >= itemCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _landscapeController != null &&
              _landscapeController!.hasClients) {
            _landscapeController!.jumpToPage(itemCount - 1);
          }
        });
      }
    }
    return _landscapeController!;
  }

  void _onLandscapePageChanged(int index, List<String> order) {
    if (index >= 0 && index < order.length) _landscapeSeenId = order[index];
  }
}
