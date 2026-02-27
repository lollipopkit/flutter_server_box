import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';

class ServerFuncBtnsOrderPage extends StatefulWidget {
  const ServerFuncBtnsOrderPage({super.key});

  @override
  State<ServerFuncBtnsOrderPage> createState() => _ServerDetailOrderPageState();

  static const route = AppRouteNoArg(page: ServerFuncBtnsOrderPage.new, path: '/setting/seq/srv_func');
}

class _ServerDetailOrderPageState extends State<ServerFuncBtnsOrderPage> {
  final prop = Stores.setting.serverFuncBtns;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.sequence)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (keys) {
        final disabled = ServerFuncBtn.values.map((e) => e.index).where((e) => !keys.contains(e)).toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          key: const PageStorageKey('srv_func_seq'),
          padding: const EdgeInsets.all(7),
          itemCount: allKeys.length,
          itemBuilder: (_, idx) => _buildListItem(allKeys[idx], idx, keys),
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

  Widget _buildListItem(int key, int idx, List<int> keys) {
    final funcBtn = ServerFuncBtn.values[key];
    return CardX(
      key: ValueKey(key),
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
  }

  Widget _buildCheckBox(List<int> keys, int key, int idx, bool value) {
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
