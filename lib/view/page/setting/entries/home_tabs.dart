import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';

class HomeTabsConfigPage extends ConsumerStatefulWidget {
  const HomeTabsConfigPage({super.key});

  static final route = AppRouteNoArg(page: HomeTabsConfigPage.new, path: '/settings/home-tabs');

  @override
  ConsumerState<HomeTabsConfigPage> createState() => _HomeTabsConfigPageState();
}

class _HomeTabsConfigPageState extends ConsumerState<HomeTabsConfigPage> {
  final _availableTabs = AppTab.values;
  var _selectedTabs = List<AppTab>.from(Stores.setting.homeTabs.fetch());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.homeTabs),
        actions: [
          TextButton(onPressed: _resetToDefault, child: Text(libL10n.reset)),
          TextButton(onPressed: _saveAndExit, child: Text(libL10n.save)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.homeTabsCustomizeDesc, style: context.theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _selectedTabs.length,
              onReorder: _onReorder,
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                final tab = _selectedTabs[index];
                return _buildTabItem(tab, index, true);
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.availableTabs, style: context.theme.textTheme.titleMedium),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _availableTabs.length,
              itemBuilder: (context, index) {
                final tab = _availableTabs[index];
                if (_selectedTabs.contains(tab)) {
                  return const SizedBox.shrink();
                }
                return _buildTabItem(tab, index, false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(AppTab tab, int index, bool isSelected) {
    final canRemove = _selectedTabs.length > 1;
    final child = ListTile(
      leading: tab.navDestination.icon,
      title: Text(tab.navDestination.label),
      trailing: isSelected
          ? IconButton(
              icon: const Icon(Icons.delete),
              onPressed: canRemove ? () => _removeTab(tab) : null,
              color: canRemove ? null : Theme.of(context).disabledColor,
              tooltip: canRemove ? libL10n.delete : l10n.atLeastOneTab,
            )
          : IconButton(icon: const Icon(Icons.add), onPressed: () => _addTab(tab)),
      onTap: isSelected && canRemove ? () => _removeTab(tab) : null,
    );

    return Card(
      key: ValueKey(tab.name),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: isSelected ? ReorderableDragStartListener(index: index, child: child) : child,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final tab = _selectedTabs.removeAt(oldIndex);
      _selectedTabs.insert(newIndex, tab);
    });
  }

  void _addTab(AppTab tab) {
    setState(() {
      _selectedTabs.add(tab);
    });
  }

  void _removeTab(AppTab tab) {
    if (_selectedTabs.length <= 1) {
      context.showSnackBar(l10n.atLeastOneTab);
      return;
    }
    setState(() {
      _selectedTabs.remove(tab);
    });
  }

  void _saveAndExit() {
    Stores.setting.homeTabs.put(_selectedTabs);
    context.pop();
  }

  void _resetToDefault() {
    setState(() {
      _selectedTabs = List<AppTab>.from(AppTab.values);
    });
    Stores.setting.homeTabs.put(_selectedTabs);
  }
}
