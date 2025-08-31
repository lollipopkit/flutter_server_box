import 'dart:ui';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';

class ServerOrderPage extends ConsumerStatefulWidget {
  const ServerOrderPage({super.key});

  @override
  ConsumerState<ServerOrderPage> createState() => _ServerOrderPageState();

  static const route = AppRouteNoArg(page: ServerOrderPage.new, path: '/settings/order/server');
}

class _ServerOrderPageState extends ConsumerState<ServerOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.serverOrder)),
      body: _buildBody(),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
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
      child: _buildCardTile(index),
    );
  }

  Widget _buildBody() {
    final serverState = ref.watch(serversNotifierProvider);
    final order = serverState.serverOrder;
    
    if (order.isEmpty) {
      return Center(child: Text(libL10n.empty));
    }
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final newOrder = List<String>.from(order);
          newOrder.move(oldIndex, newIndex);
          Stores.setting.serverOrder.put(newOrder);
        });
      },
      padding: const EdgeInsets.all(8),
      buildDefaultDragHandles: false,
      itemBuilder: (_, idx) => _buildItem(idx, order[idx]),
      itemCount: order.length,
      proxyDecorator: _proxyDecorator,
    );
  }

  Widget _buildItem(int index, String id) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('server_item_$id'),
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CardX(child: _buildCardTile(index)),
      ),
    );
  }

  Widget _buildCardTile(int index) {
    final serverState = ref.watch(serversNotifierProvider);
    final order = serverState.serverOrder;
    final id = order[index];
    final spi = serverState.servers[id];
    if (spi == null) {
      return const SizedBox();
    }

    return ListTile(
      title: Text(spi.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(spi.oldId, style: UIs.textGrey),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: Text(spi.name[0]),
      ),
      trailing: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
    );
  }
}
