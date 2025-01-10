import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/res/store.dart';

class ServerDetailOrderPage extends StatefulWidget {
  const ServerDetailOrderPage({super.key});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  final prop = Stores.setting.detailCardOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverDetailOrder)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (keys) {
        final disabled =
            ServerDetailCards.names.where((e) => !keys.contains(e)).toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(7),
          buildDefaultDragHandles: false,
          itemBuilder: (_, idx) {
            final key = allKeys[idx];
            return ReorderableDelayedDragStartListener(
              key: ValueKey(idx),
              index: idx,
              child: CardX(
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 23, right: 11),
                  leading: Icon(ServerDetailCards.fromName(key)?.icon),
                  title: Text(key),
                  trailing: _buildCheckBox(keys, key, idx, idx < keys.length),
                ),
              ),
            );
          },
          itemCount: allKeys.length,
          onReorder: (o, n) {
            if (o >= keys.length || n >= keys.length) {
              context.showSnackBar(libL10n.disabled);
              return;
            }
            keys.moveByItem(o, n, property: prop);
          },
        );
      },
    );
  }

  Widget _buildCheckBox(List<String> keys, String key, int idx, bool value) {
    return Checkbox(
      value: value,
      onChanged: (val) {
        if (val == null) return;
        if (val) {
          if (idx >= keys.length) {
            keys.add(key);
          } else {
            keys.insert(idx - 1, key);
          }
        } else {
          keys.remove(key);
        }
        prop.put(keys);
      },
    );
  }
}
