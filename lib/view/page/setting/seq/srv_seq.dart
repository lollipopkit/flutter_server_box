import 'dart:ui';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';

class ServerOrderPage extends ConsumerStatefulWidget {
  const ServerOrderPage({super.key});

  @override
  ConsumerState<ServerOrderPage> createState() => _ServerOrderPageState();

  static const route = AppRouteNoArg(page: ServerOrderPage.new, path: '/settings/order/server');
}

class _ServerOrderPageState extends ConsumerState<ServerOrderPage> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List<String>.from(ref.read(serversProvider).serverOrder);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ServersState>(serversProvider, (_, next) {
      if (listEquals(_order, next.serverOrder)) {
        return;
      }
      setState(() {
        _order = List<String>.from(next.serverOrder);
      });
    });

    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.serverOrder)),
      body: _buildBody(),
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
    final serverState = ref.watch(serversProvider);
    final order = _order;

    if (order.isEmpty) {
      return Center(child: Text(libL10n.empty));
    }
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      onReorder: (oldIndex, newIndex) {
        var targetIndex = newIndex;
        if (targetIndex > oldIndex) {
          targetIndex -= 1;
        }
        if (targetIndex == oldIndex) {
          return;
        }

        final newOrder = List<String>.from(order);
        final moved = newOrder.removeAt(oldIndex);
        newOrder.insert(targetIndex, moved);

        setState(() {
          _order = newOrder;
        });
        ref.read(serversProvider.notifier).updateServerOrder(newOrder);
      },
      padding: const EdgeInsets.all(8),
      buildDefaultDragHandles: false,
      itemBuilder: (_, idx) {
        final id = order[idx];
        final spi = serverState.servers[id];
        return _buildItem(idx, id, spi);
      },
      itemCount: order.length,
      proxyDecorator: _proxyDecorator,
    );
  }

  Widget _buildItem(int index, String id, Spi? spi) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('server_item_$id'),
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: _buildCardTile(index, spi).cardx,
      ),
    );
  }

  Widget _buildCardTile(int index, Spi? spi) {
    if (spi == null) {
      return const SizedBox();
    }

    final name = spi.name.characters.firstOrNull ?? '?';

    return ListTile(
      title: Text(spi.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(spi.oldId, style: UIs.textGrey),
      leading: CircleAvatar(
        child: Text(name),
      ),
      trailing: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
    );
  }
}
