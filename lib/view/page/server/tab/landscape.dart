part of 'tab.dart';

extension on _ServerPageState {
  Widget _buildLandscape() {
    final offset = Offset(_offset, _offset);
    return Padding(
      // Avoid display cutout
      padding: EdgeInsets.all(_offset.abs()),
      child: Transform.translate(
        offset: offset,
        child: Stack(
          children: [
            _buildLandscapeBody(),
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
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
    return ServerProvider.serverOrder.listenVal((order) {
      if (order.isEmpty) {
        return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
      }

      return PageView.builder(
        itemCount: order.length,
        itemBuilder: (_, idx) {
          final id = order[idx];
          final srv = ServerProvider.pick(id: id);
          if (srv == null) return UIs.placeholder;

          return srv.listenVal((srv) {
            final title = _buildServerCardTitle(srv);
            final List<Widget> children = [title, _buildNormalCard(srv.status, srv.spi)];

            return _getCardNoti(id).listenVal((_) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              );
            });
          });
        },
      );
    });
  }
}
