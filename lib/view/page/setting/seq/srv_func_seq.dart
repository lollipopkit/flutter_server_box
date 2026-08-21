import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';

class ServerFuncBtnsOrderPage extends StatefulWidget {
    /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const ServerFuncBtnsOrderPage({super.key, this.embedded = false});

  @override
  State<ServerFuncBtnsOrderPage> createState() => _ServerDetailOrderPageState();

  static const route = AppRouteNoArg(
    page: ServerFuncBtnsOrderPage.new,
    path: '/setting/seq/srv_func',
  );
}

class _ServerDetailOrderPageState extends State<ServerFuncBtnsOrderPage> {
  final prop = Stores.setting.serverFuncBtns;

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody(context);
    return Scaffold(
      appBar: CustomAppBar(title: Text(libL10n.sequence)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (keys) {
        final disabled = ServerFuncBtn.values
            .map((e) => e.index)
            .where((e) => !keys.contains(e))
            .toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          key: const PageStorageKey('srv_func_seq'),
          padding: context.padBottom(const EdgeInsets.all(7)),
          itemCount: allKeys.length,
          itemBuilder: (_, idx) => _buildListItem(allKeys[idx], idx, keys),
          onReorderItem: (o, n) {
            if (o >= keys.length || n >= keys.length) {
              Toast.show(libL10n.disabled);
              return;
            }
            if (o == n) {
              return;
            }
            final moved = keys.removeAt(o);
            keys.insert(n, moved);
            prop.set(keys);
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
