import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/model/ssh/virtual_key.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/cardx.dart';

import '../../widget/custom_appbar.dart';

class SSHVirtKeySettingPage extends StatefulWidget {
  const SSHVirtKeySettingPage({Key? key}) : super(key: key);

  @override
  _SSHVirtKeySettingPageState createState() => _SSHVirtKeySettingPageState();
}

class _SSHVirtKeySettingPageState extends State<SSHVirtKeySettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.editVirtKeys),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final keys_ = Stores.setting.sshVirtKeys.fetch();
    final keys = <VirtKey>[];
    for (final key in keys_) {
      keys.add(key);
    }
    final disabled = VirtKey.values.where((e) => !keys.contains(e)).toList();
    final allKeys = [...keys, ...disabled];
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(7),
      itemBuilder: (_, idx) {
        final key = allKeys[idx];
        final help = key.help;
        return CardX(
          key: ValueKey(idx),
          ListTile(
            title: _buildTitle(key),
            subtitle: help == null ? null : Text(help, style: UIs.textGrey),
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
        keys.moveByItem(keys, o, n, property: Stores.setting.sshVirtKeys);
        setState(() {});
      },
    );
  }

  Widget _buildTitle(VirtKey key) {
    return key.icon == null
        ? Text(key.text)
        : Row(
            children: [
              Text(key.text),
              const SizedBox(width: 10),
              Icon(key.icon),
            ],
          );
  }

  Widget _buildCheckBox(List<VirtKey> keys, VirtKey key, int idx, bool value) {
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
        Stores.setting.sshVirtKeys.put(keys);
        setState(() {});
      },
    );
  }
}
