import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../widget/custom_appbar.dart';

class ServerOrderPage extends StatefulWidget {
  const ServerOrderPage({Key? key}) : super(key: key);

  @override
  _ServerOrderPageState createState() => _ServerOrderPageState();
}

class _ServerOrderPageState extends State<ServerOrderPage> {
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(_s.serverOrder),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (Providers.server.serverOrder.isEmpty) {
      return Center(child: Text(_s.noServerAvailable));
    }
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      onReorder: (oldIndex, newIndex) => setState(() {
        Providers.server.serverOrder.move(
          oldIndex,
          newIndex,
          property: Stores.setting.serverOrder,
        );
      }),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      buildDefaultDragHandles: false,
      itemBuilder: (_, index) =>
          _buildItem(index, Providers.server.serverOrder[index]),
      itemCount: Providers.server.serverOrder.length,
    );
  }

  Widget _buildItem(int index, String id) {
    final spi = Providers.server.servers[id]?.spi;
    if (spi == null) {
      return const SizedBox();
    }
    return ReorderableDelayedDragStartListener(
      key: ValueKey('$index'),
      index: index,
      child: RoundRectCard(ListTile(
        title: Text(spi.name),
        subtitle: Text(spi.id),
        leading: CircleAvatar(
          child: Text(spi.name[0]),
        ),
        trailing: const Icon(Icons.drag_handle),
      )),
    );
  }
}
