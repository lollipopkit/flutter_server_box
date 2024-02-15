import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/model/app/menu/server_func.dart';
import 'package:toolbox/data/res/store.dart';

import '../../../../core/extension/order.dart';
import '../../../widget/appbar.dart';
import '../../../widget/cardx.dart';

class ServerFuncBtnsOrderPage extends StatefulWidget {
  const ServerFuncBtnsOrderPage({super.key});

  @override
  State<ServerFuncBtnsOrderPage> createState() => _ServerDetailOrderPageState();
}

class _ServerDetailOrderPageState extends State<ServerFuncBtnsOrderPage> {
  final prop = Stores.setting.serverFuncBtns;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.sequence),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder(
      valueListenable: prop.listenable(),
      builder: (_, vals, __) {
        final keys = List<int>.from(vals);
        final disabled = ServerFuncBtn.values
            .map((e) => e.index)
            .where((e) => !keys.contains(e))
            .toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(7),
          itemBuilder: (_, idx) {
            final key = allKeys[idx];
            return CardX(
              key: ValueKey(idx),
              child: ListTile(
                title: Text(ServerFuncBtn.values[key].toStr),
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
            keys.moveByItem(keys, o, n, property: prop);
          },
        );
      },
    );
  }

  Widget _buildCheckBox(
    List<int> keys,
    int key,
    int idx,
    bool value,
  ) {
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
