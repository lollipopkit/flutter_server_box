import 'dart:ui';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';

class ServerDetailOrderPage extends StatefulWidget {
  const ServerDetailOrderPage({super.key});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();

  static const route = AppRouteNoArg(page: ServerDetailOrderPage.new, path: '/settings/order/server_detail');
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  final prop = Stores.setting.detailCardOrder;

  late List<String> _order;
  late Set<String> _enabled;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final keys = prop.fetch();
    _order = List<String>.from(keys);
    _enabled = Set<String>.from(keys);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.serverDetailOrder)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _proxyDecorator(Widget child, int _, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(1, 6, animValue)!;
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: Card(elevation: elevation, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildBody() {
    return ReorderableListView.builder(
      key: const PageStorageKey('srv_detail_seq'),
      padding: const EdgeInsets.all(7),
      buildDefaultDragHandles: false,
      itemCount: _order.length,
      proxyDecorator: _proxyDecorator,
      itemBuilder: (_, idx) => _buildListItem(_order[idx], idx),
      onReorder: _handleReorder,
    );
  }

  Widget _buildListItem(String key, int idx) {
    final isEnabled = _enabled.contains(key);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(key),
      index: idx,
      child: CardX(
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 23, right: 11),
          leading: Icon(ServerDetailCards.fromName(key)?.icon),
          title: Text(key, style: isEnabled ? null : TextStyle(color: Colors.grey)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckBox(key, isEnabled),
              ReorderableDragStartListener(index: idx, child: const Icon(Icons.drag_handle)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckBox(String key, bool isEnabled) {
    return Checkbox(
      value: isEnabled,
      onChanged: (_) => _toggleEnabled(key),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      var targetIndex = newIndex;
      if (targetIndex > oldIndex) {
        targetIndex -= 1;
      }
      if (targetIndex == oldIndex) {
        return;
      }

      final item = _order.removeAt(oldIndex);
      _order.insert(targetIndex, item);
    });
    prop.put(_order);
  }

  void _toggleEnabled(String key) {
    setState(() {
      if (_enabled.contains(key)) {
        _enabled.remove(key);
      } else {
        _enabled.add(key);
      }
    });
    prop.put(_order);
  }
}
