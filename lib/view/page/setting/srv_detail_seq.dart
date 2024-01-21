import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/default.dart';
import 'package:toolbox/data/res/store.dart';

import '../../../core/extension/order.dart';
import '../../widget/appbar.dart';
import '../../widget/cardx.dart';

class ServerDetailOrderPage extends StatefulWidget {
  const ServerDetailOrderPage({super.key});

  @override
  State<ServerDetailOrderPage> createState() => _ServerDetailOrderPageState();
}

class _ServerDetailOrderPageState extends State<ServerDetailOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.serverDetailOrder),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final keys_ = Stores.setting.detailCardOrder.fetch();
    final keys = <String>[];
    for (final key in keys_) {
      keys.add(key);
    }
    final disabled =
        Defaults.detailCardOrder.where((e) => !keys.contains(e)).toList();
    final allKeys = [...keys, ...disabled];
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(7),
      itemBuilder: (_, idx) {
        final key = allKeys[idx];
        return CardX(
          key: ValueKey(idx),
          child: ListTile(
            title: Text(key),
            leading: _buildCheckBox(keys, key, idx, idx < keys.length),
            trailing: isDesktop ? null : const Icon(Icons.drag_handle),
          ),
        );
      },
      itemCount: allKeys.length,
      onReorder: (o, n) {
        if (o >= keys.length || n >= keys.length) {
          context.showSnackBar(l10n.disabled);
          return;
        }
        keys.moveByItem(keys, o, n, property: Stores.setting.detailCardOrder);
        setState(() {});
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
        Stores.setting.detailCardOrder.put(keys);
        setState(() {});
      },
    );
  }
}
