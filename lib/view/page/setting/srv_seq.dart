import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/cardx.dart';

import '../../widget/custom_appbar.dart';

class ServerOrderPage extends StatefulWidget {
  const ServerOrderPage({Key? key}) : super(key: key);

  @override
  _ServerOrderPageState createState() => _ServerOrderPageState();
}

class _ServerOrderPageState extends State<ServerOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.serverOrder),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (Pros.server.serverOrder.isEmpty) {
      return Center(child: Text(l10n.noServerAvailable));
    }
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      onReorder: (oldIndex, newIndex) => setState(() {
        Pros.server.serverOrder.move(
          oldIndex,
          newIndex,
          property: Stores.setting.serverOrder,
        );
      }),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      buildDefaultDragHandles: false,
      itemBuilder: (_, index) =>
          _buildItem(index, Pros.server.serverOrder[index]),
      itemCount: Pros.server.serverOrder.length,
    );
  }

  Widget _buildItem(int index, String id) {
    final spi = Pros.server.pick(id: id)?.spi;
    if (spi == null) {
      return const SizedBox();
    }
    return ReorderableDelayedDragStartListener(
      key: ValueKey('$index'),
      index: index,
      child: CardX(ListTile(
        title: Text(spi.name),
        subtitle: Text(spi.id, style: UIs.textGrey),
        leading: CircleAvatar(
          child: Text(spi.name[0]),
        ),
        trailing: const Icon(Icons.drag_handle),
      )),
    );
  }
}
