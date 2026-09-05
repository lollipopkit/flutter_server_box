import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/setting/seq/reorder_proxy_decorator.dart';

class SSHVirtKeySettingPage extends StatefulWidget {
    /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const SSHVirtKeySettingPage({super.key, this.embedded = false});

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

  late List<VirtKey> _order;
  late Set<VirtKey> _enabled;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Through [VirtKeyX.loadFromStore], which is where a name this build
    // cannot place is dropped. Read straight out of the store, one such entry —
    // a restore from a newer build — reached `VirtKey.values[key]` below and
    // threw while the list was building, so the page came up as a red box
    // rather than as a list missing a row.
    final keys = VirtKeyX.loadFromStore();
    final disabled = disabledProp.fetch();
    _order = List<VirtKey>.from(keys);
    for (final name in disabled) {
      final key = VirtKeyX.byName(name);
      if (key == null) continue;
      if (!_order.contains(key)) _order.add(key);
    }
    // A key absent from both stored lists has never been configured. This is
    // the normal state for every optional key on an older install, and for a
    // key added by a newer build. Keep it available in settings, but disabled,
    // so opening this page does not silently add it to the terminal strip.
    for (final key in VirtKey.values) {
      if (!_order.contains(key)) _order.add(key);
    }
    _enabled = keys.where((k) => !disabled.contains(k.name)).toSet();
  }

  @override
  Widget build(BuildContext context) {
    // Not the bottom: the list takes that as padding of its own, so it can be
    // scrolled through rather than cutting the page short of it.
    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(7),
            child: _buildVirtKeyRows().cardx,
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.editVirtKeys)),
      body: body,
    );
  }

  /// How many rows of keys the terminal shows at once.
  ///
  /// The switch this replaced said "one row, scrolled sideways", which was the
  /// only alternative to all of them. What anyone actually wants is a strip a
  /// chosen number of rows tall, and the keys that do not fit within reach —
  /// which is what a page swiped sideways is.
  Widget _buildVirtKeyRows() {
    final rows = (_enabled.length / kVirtKeysPerRow).ceil();
    // What the terminal will actually do with the stored number, which is not
    // always the number: a count at or above the rows there are shows all of
    // them, the same as 0. The store keeps what was asked for, so turning keys
    // back on restores it, but the row has to say what is in force rather than
    // what would be if there were more keys.
    final stored = Stores.setting.virtKeyRows.fetch();
    final effective = stored >= rows ? 0 : stored;
    return ListTile(
      title: Text(l10n.virtKeyRows),
      subtitle: Text(l10n.virtKeyRowsTip, style: UIs.textGrey),
      // Nothing to page while every row already fits. The row stays rather
      // than going away, so it does not appear and disappear as keys are
      // turned on and off in the list under it.
      enabled: rows > 1,
      trailing: Text(
        effective <= 0 ? libL10n.all : '$effective',
        style: UIs.text15,
      ),
      onTap: () => _pickVirtKeyRows(rows, effective),
    );
  }

  Future<void> _pickVirtKeyRows(int rows, int current) async {
    // 0 is "all of them", and so is the row count itself — offering both would
    // be two entries doing one thing.
    final picked = await context.showPickSingleDialog<int>(
      title: l10n.virtKeyRows,
      items: [0, for (var i = 1; i < rows; i++) i],
      // The effective value, so the dialog opens on the entry the row above
      // shows. A stored count no longer in the list would open it on nothing.
      initial: current,
    display: (value) => value <= 0 ? libL10n.all : '$value',
    );
    if (picked == null) return;
    Stores.setting.virtKeyRows.put(picked);
    if (mounted) setState(() {});
  }

  Widget _buildBody(BuildContext context) {
    return ReorderableListView.builder(
      key: const PageStorageKey('virt_key'),
      padding: context.padBottom(const EdgeInsets.all(7)),
      buildDefaultDragHandles: false,
      itemCount: _order.length,
      proxyDecorator: reorderProxyDecorator,
      itemBuilder: (_, idx) => _buildListItem(_order[idx], idx),
      onReorderItem: _handleReorder,
    );
  }

  Widget _buildListItem(VirtKey item, int idx) {
    final help = item.help;
    final isEnabled = _enabled.contains(item);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(item),
      index: idx,
      child: CardX(
        child: ListTile(
          title: _buildTitle(item, isEnabled),
          subtitle: help == null ? null : Text(help, style: UIs.textGrey),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckBox(item, isEnabled),
              if (!isDesktop) ...[
                const SizedBox(width: 7),
                ReorderableDragStartListener(
                  index: idx,
                  child: const Icon(Icons.drag_handle),
                ),
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
      child: Opacity(opacity: isEnabled ? 1.0 : 0.5, child: text),
    );
  }

  Widget _buildCheckBox(VirtKey key, bool isEnabled) {
    return Checkbox(value: isEnabled, onChanged: (_) => _toggleEnabled(key));
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final targetIndex = newIndex;
    if (targetIndex == oldIndex) {
      return;
    }

    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(targetIndex, item);
    });
    _saveChanges();
  }

  void _toggleEnabled(VirtKey key) {
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
    prop.put(_order.map((e) => e.name).toList());
    final disabledList = _order
        .where((k) => !_enabled.contains(k))
        .map((e) => e.name)
        .toList();
    disabledProp.put(disabledList);
  }
}
