import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';

/// Which cards the server detail page draws.
///
/// There is no order any more. The page is the metrics — one chart and a row
/// each — and what is left are the cards for what cannot be a row: a table, or
/// a reading with no line over time. Their order is the order they are
/// declared in, and dragging them around was arranging a list whose length is
/// decided by what the machine reports.
///
/// TODO: `SettingStore.detailCardOrder` is no longer read. Delete the key once
/// a release has shipped without it.
class ServerDetailOrderPage extends StatefulWidget {
  /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const ServerDetailOrderPage({super.key, this.embedded = false});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();

  static const route = AppRouteNoArg(
    page: ServerDetailOrderPage.new,
    path: '/settings/order/server_detail',
  );
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  final disabledProp = Stores.setting.detailCardDisabled;

  late Set<String> _disabled;

  /// The cards this page can switch. The metrics are not among them: they are
  /// the page itself. About is, because it was one before this and an install
  /// that switched it off is still switching this one off.
  static const _cards = [
    ServerDetailCards.about,
    ServerDetailCards.gpu,
    ServerDetailCards.smart,
    ServerDetailCards.sensor,
    ServerDetailCards.temp,
    ServerDetailCards.battery,
    ServerDetailCards.pve,
    ServerDetailCards.bmc,
    ServerDetailCards.custom,
  ];

  @override
  void initState() {
    super.initState();
    _disabled = Set<String>.from(disabledProp.fetch());
  }

  @override
  Widget build(BuildContext context) {
    // Not the bottom: the list takes that as padding of its own, so it can
    // be scrolled through rather than cutting the page short of it.
    final body = SafeArea(bottom: false, child: _buildBody(context));
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.serverDetailCards)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      key: const PageStorageKey('srv_detail_seq'),
      padding: context.padBottom(const EdgeInsets.all(7)),
      children: [
        for (final card in _cards) _buildListItem(card),
      ],
    );
  }

  Widget _buildListItem(ServerDetailCards card) {
    final enabled = !_disabled.contains(card.name);
    return CardX(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.only(left: 17, right: 11),
        secondary: Icon(card.icon),
        title: Text(card.toStr),
        value: enabled,
        onChanged: (_) => _toggle(card.name),
      ),
    );
  }

  void _toggle(String key) {
    setState(() {
      if (!_disabled.remove(key)) _disabled.add(key);
    });
    disabledProp.put(_disabled.toList());
  }
}
