import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';

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
      appBar: AppBar(title: Text(l10n.sequence)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (keys) {
        final disabled = ServerFuncBtn.values
            .map((e) => e.index)
            .where((e) => !keys.contains(e))
            .toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(7),
          itemBuilder: (_, idx) {
            final key = allKeys[idx];
            final funcBtn = ServerFuncBtn.values[key];
            return CardX(
              key: ValueKey(idx),
              child: ListTile(
                title: RichText(
                  text: TextSpan(
                    children: [
                      WidgetSpan(child: Icon(funcBtn.icon)),
                      const WidgetSpan(child: UIs.width13),
                      TextSpan(text: funcBtn.toStr, style: UIs.textGrey),
                    ],
                  ),
                ),
                leading: _buildCheckBox(keys, key, idx, idx < keys.length),
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
