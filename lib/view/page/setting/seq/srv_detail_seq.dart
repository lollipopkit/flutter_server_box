import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/model/app/server_detail_card.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/store.dart';

import '../../../../core/extension/order.dart';
import '../../../widget/appbar.dart';
import '../../../widget/cardx.dart';

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
      appBar: CustomAppBar(
        title: Text(l10n.serverDetailOrder),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder(
      valueListenable: prop.listenable(),
      builder: (_, vals, __) {
        final keys = () {
          try {
            return List<String>.from(vals);
          } catch (e) {
            Loggers.app.info('ServerDetailOrderPage: $e');
            return ServerDetailCards.names;
          }
        }();
        final disabled =
            ServerDetailCards.names.where((e) => !keys.contains(e)).toList();
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
            keys.moveByItem(keys, o, n, property: prop);
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
