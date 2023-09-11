import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../../../core/extension/order.dart';
import '../../../data/store/setting.dart';
import '../../../locator.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/round_rect_card.dart';

class ServerDetailOrderPage extends StatefulWidget {
  const ServerDetailOrderPage({super.key});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  final _store = locator<SettingStore>();

  final Order<String> _cardsOrder = [];

  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    _cardsOrder.addAll(_store.detailCardOrder.fetch());
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
    return ReorderableListView.builder(
      footer: const SizedBox(height: 77),
      onReorder: (oldIndex, newIndex) => setState(() {
        _cardsOrder.move(
          oldIndex,
          newIndex,
          property: _store.detailCardOrder,
        );
      }),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      buildDefaultDragHandles: false,
      itemBuilder: (_, index) => _buildItem(index, _cardsOrder[index]),
      itemCount: _cardsOrder.length,
    );
  }

  Widget _buildItem(int index, String id) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('$index'),
      index: index,
      child: RoundRectCard(ListTile(
        title: Text(id),
        trailing: const Icon(Icons.drag_handle),
      )),
    );
  }
}
