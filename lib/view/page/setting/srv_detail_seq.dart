import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/res/store.dart';

import '../../../core/extension/order.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/cardx.dart';

class ServerDetailOrderPage extends StatefulWidget {
  const ServerDetailOrderPage({super.key});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  final Order<String> _cardsOrder = [];

  @override
  void initState() {
    super.initState();
    _cardsOrder.addAll(Stores.setting.detailCardOrder.fetch());
  }

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
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      onReorder: (oldIndex, newIndex) => setState(() {
        _cardsOrder.move(
          oldIndex,
          newIndex,
          property: Stores.setting.detailCardOrder,
        );
      }),
      padding: const EdgeInsets.all(17),
      buildDefaultDragHandles: false,
      itemBuilder: (_, index) => _buildItem(index, _cardsOrder[index]),
      itemCount: _cardsOrder.length,
    );
  }

  Widget _buildItem(int index, String id) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('$index'),
      index: index,
      child: CardX(ListTile(
        title: Text(id),
        trailing: const Icon(Icons.drag_handle),
      )),
    );
  }
}
