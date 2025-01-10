import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/store.dart';

class SSHVirtKeySettingPage extends StatefulWidget {
  const SSHVirtKeySettingPage({super.key});

  @override
  State<SSHVirtKeySettingPage> createState() => _SSHVirtKeySettingPageState();
}

class _SSHVirtKeySettingPageState extends State<SSHVirtKeySettingPage> {
  final prop = Stores.setting.sshVirtKeys;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editVirtKeys)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(7),
            child: _buildOneLineVirtKey().cardx,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildOneLineVirtKey() {
    return ListTile(
      title: Text(l10n.onlyOneLine),
      trailing: StoreSwitch(prop: Stores.setting.horizonVirtKey),
    );
  }

  Widget _buildBody() {
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (keys) {
        final disabled = VirtKey.values
            .map((e) => e.index)
            .where((e) => !keys.contains(e))
            .toList();
        final allKeys = [...keys, ...disabled];
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(7),
          itemBuilder: (_, idx) {
            final key = allKeys[idx];
            final item = VirtKey.values[key];
            final help = item.help;
            return CardX(
              key: ValueKey(idx),
              child: ListTile(
                title: _buildTitle(item),
                subtitle: help == null ? null : Text(help, style: UIs.textGrey),
                leading: _buildCheckBox(keys, key, idx, idx < keys.length),
                trailing: isDesktop ? null : const Icon(Icons.drag_handle),
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
