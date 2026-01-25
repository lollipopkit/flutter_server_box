import 'dart:ui';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/store.dart';

class SSHVirtKeySettingPage extends StatefulWidget {
  const SSHVirtKeySettingPage({super.key});

  @override
  State<SSHVirtKeySettingPage> createState() => _SSHVirtKeySettingPageState();

  static const route = AppRouteNoArg(
    page: SSHVirtKeySettingPage.new,
    path: '/settings/ssh_virt_key',
  );
}

class _SSHVirtKeySettingPageState extends State<SSHVirtKeySettingPage> {
  final prop = Stores.setting.sshVirtKeys;
  final disabledProp = Stores.setting.sshVirtKeysDisabled;

  late List<int> _order;
  late Set<int> _enabled;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final keys = prop.fetch();
    final disabled = disabledProp.fetch();
    _order = List<int>.from(keys);
    for (final d in disabled) {
      if (!_order.contains(d)) {
        _order.add(d);
      }
    }
    _enabled = Set<int>.from(keys.where((k) => !disabled.contains(k)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.editVirtKeys)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(7),
              child: _buildOneLineVirtKey().cardx,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildOneLineVirtKey() {
    return ListTile(
      title: Text(l10n.onlyOneLine),
      trailing: StoreSwitch(prop: Stores.setting.horizonVirtKey),
    );
  }

  Widget _proxyDecorator(Widget child, int _, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(1, 6, animValue)!;
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: Card(elevation: elevation, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildBody() {
    return ReorderableListView.builder(
      key: const PageStorageKey('virt_key'),
      padding: const EdgeInsets.all(7),
      buildDefaultDragHandles: false,
      itemCount: _order.length,
      proxyDecorator: _proxyDecorator,
      itemBuilder: (_, idx) => _buildListItem(_order[idx], idx),
      onReorder: _handleReorder,
    );
  }

  Widget _buildListItem(int key, int idx) {
    final item = VirtKey.values[key];
    final help = item.help;
    final isEnabled = _enabled.contains(key);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(key),
      index: idx,
      child: CardX(
        child: ListTile(
          title: _buildTitle(item, isEnabled),
          subtitle: help == null ? null : Text(help, style: UIs.textGrey),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckBox(key, isEnabled),
              if (!isDesktop) ...[
                const SizedBox(width: 7),
                ReorderableDragStartListener(index: idx, child: const Icon(Icons.drag_handle)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(VirtKey key, bool isEnabled) {
    final text = key.icon == null
        ? Text(key.text)
        : Row(
            children: [
              Text(key.text),
              const SizedBox(width: 10),
              Icon(key.icon),
            ],
          );
    return IgnorePointer(
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: text,
      ),
    );
  }

  Widget _buildCheckBox(int key, bool isEnabled) {
    return Checkbox(
      value: isEnabled,
      onChanged: (_) => _toggleEnabled(key),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      var targetIndex = newIndex;
      if (targetIndex > oldIndex) {
        targetIndex -= 1;
      }
      if (targetIndex == oldIndex) {
        return;
      }

      final item = _order.removeAt(oldIndex);
      _order.insert(targetIndex, item);
    });
    _saveChanges();
  }

  void _toggleEnabled(int key) {
    setState(() {
      if (_enabled.contains(key)) {
        _enabled.remove(key);
      } else {
        _enabled.add(key);
      }
    });
    _saveChanges();
  }

  void _saveChanges() {
    prop.put(_order);
    final disabledList = _order.where((k) => !_enabled.contains(k)).toList();
    disabledProp.put(disabledList);
  }
}
