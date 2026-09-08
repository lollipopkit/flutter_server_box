import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/home_tab.dart';
import 'package:server_box/view/page/setting/seq/reorder_proxy_decorator.dart';

@visibleForTesting
List<String> availableHomeTabs(Iterable<String> selectedTabs) {
  final selected = selectedTabs.toSet();
  // Asked of the registry rather than of `AppTab`: a plugin's tab is not a
  // case of it, and a page that listed only the enum's would leave one
  // permanently behind "more" with no way to move it into the bar.
  return [
    for (final f in Features.of(FeatureSlot.homeTab))
      if (!selected.contains(f.id)) f.id,
  ];
}

/// Where a drag leaves the two halves of the list, or null when it moves
/// nothing.
///
/// [oldIndex] and [newIndex] address the joined list — enabled, the separator,
/// then disabled — which is what the reorderable is built from, so crossing the
/// separator and moving within one half are the same arithmetic. Whether the
/// result is allowed is the caller's to say.
@visibleForTesting
({List<String> enabled, List<String> disabled})? reorderHomeTabs({
  required List<String> enabled,
  required List<String> disabled,
  required int oldIndex,
  required int newIndex,
}) {
  if (oldIndex == newIndex) return null;
  final items = <String?>[...enabled, null, ...disabled];
  // The separator is not draggable, so this is a reorder of something else's
  // making.
  if (items[oldIndex] == null) return null;

  items.insert(newIndex, items.removeAt(oldIndex));
  final split = items.indexOf(null);
  return (
    enabled: items.take(split).whereType<String>().toList(),
    disabled: items.skip(split + 1).whereType<String>().toList(),
  );
}

class HomeTabsConfigPage extends StatefulWidget {
  /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const HomeTabsConfigPage({super.key, this.embedded = false});

  static const route = AppRouteNoArg(
    page: HomeTabsConfigPage.new,
    path: '/settings/home-tabs',
  );

  @override
  State<HomeTabsConfigPage> createState() => _HomeTabsConfigPageState();
}

class _HomeTabsConfigPageState extends State<HomeTabsConfigPage> {
  /// The tabs the home page shows, in the order it shows them.
  late List<String> _enabled;

  /// The rest, kept as a list rather than derived on every build so that a tab
  /// dragged out stays where it was dropped instead of jumping to wherever the
  /// enum happens to put it.
  late List<String> _disabled;

  /// Stored ids this build has no tab for. See [initState].
  late List<String> _unclaimed;

  @override
  void initState() {
    super.initState();
    // Resolved, not cast. The stored row is ids since m023, and
    // `List<AppTab>.from` on a list of strings compiles and throws — the
    // analyzer cannot see it, because `List.from` takes `Iterable<dynamic>`.
    //
    // An id this page has no tab for is dropped here and carried on save; see
    // `_onReorder`.
    // An id nothing claims — a tab removed in an upgrade, or one a plugin
    // contributed and is no longer installed — is set aside rather than drawn.
    // It cannot be a row: the reorder arithmetic addresses the joined list by
    // position, so a row that is not there would shift every index after it.
    //
    // Kept, not dropped, and carried back on save: it is where the user put a
    // tab, and reinstalling the plugin should find it there. It can only have
    // come from the *enabled* half, since that is the only half stored.
    final stored = Stores.setting.homeTabs.fetch();
    final claimed = {for (final f in Features.of(FeatureSlot.homeTab)) f.id};
    _enabled = [
      for (final id in stored)
        if (claimed.contains(id)) id,
    ];
    _unclaimed = [
      for (final id in stored)
        if (!claimed.contains(id)) id,
    ];
    _disabled = availableHomeTabs(_enabled).toList();
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
            padding: const EdgeInsets.fromLTRB(17, 13, 17, 7),
            child: Text(l10n.homeTabsCustomizeDesc, style: UIs.textGrey),
          ),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.homeTabs)),
      body: body,
    );
  }

  /// One list rather than two, with [_buildSeparator] standing between the two
  /// halves of it. Enabling a tab is then the same gesture as ordering one —
  /// dragging it across that line — and there is nothing left to save.
  Widget _buildList(BuildContext context) {
    final items = _items;
    return ReorderableListView.builder(
      key: const PageStorageKey('home_tabs'),
      padding: context.padBottom(const EdgeInsets.symmetric(horizontal: 7)),
      buildDefaultDragHandles: false,
      proxyDecorator: reorderProxyDecorator,
      itemCount: items.length,
      itemBuilder: (_, idx) {
        final tab = items[idx];
        // The separator itself, which is not draggable: it is where the list
        // is cut, so it has to keep its meaning while something moves past it.
        if (tab == null) return _buildSeparator();
        return _buildTabItem(tab, idx, idx < _enabled.length);
      },
      onReorderItem: _onReorder,
    );
  }

  /// The list as the reorderable sees it: enabled, the separator, disabled.
  List<String?> get _items => [..._enabled, null, ..._disabled];

  Widget _buildSeparator() {
    return Padding(
      key: const ValueKey('separator'),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Text(l10n.availableTabs, style: UIs.textGrey),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  /// Null for an id nothing claims — a tab removed in an upgrade, or one a
  /// plugin contributed and is no longer installed. It stays in the stored row
  /// and is simply not drawn; see `FeatureSlot.putEnabledIds`.
  Widget _buildTabItem(String id, int idx, bool enabled) {
    // Never null: an id nothing claims never reaches a row — see [initState].
    final tab = HomeTab.of(id)!;
    return ReorderableDelayedDragStartListener(
      key: ValueKey(id),
      index: idx,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: CardX(
          child: ListTile(
            leading: tab.icon,
            title: Text(tab.label),
            trailing: ReorderableDragStartListener(
              index: idx,
              child: const Icon(Icons.drag_handle),
            ),
          ),
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final next = reorderHomeTabs(
      enabled: _enabled,
      disabled: _disabled,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (next == null) return;

    // Nothing else to fall back to: the server tab is what the app opens on.
    if (!next.enabled.contains(AppTab.server.name)) {
      Toast.show(l10n.serverTabRequired);
      return;
    }

    setState(() {
      _enabled = next.enabled;
      _disabled = next.disabled;
    });
    // Through the slot rather than the property: it is the one writer for an
    // arrangement, and the rule that an id this build has no entry for is kept
    // rather than dropped lives there. This page only knows about `AppTab`s,
    // so it is also the only thing standing between a stored id it cannot draw
    // and a save that would lose it.
    // The set-aside ids go back on the end. Their old position cannot be kept
    // through a reorder they were not part of, and the end is the honest place
    // for one — a plugin reinstalled later is in the bar, which is where the
    // user had put it, rather than silently gone.
    FeatureSlot.homeTab.putEnabledIds([..._enabled, ..._unclaimed]);
    // What [AppTab.defaultOrder] is a guess about, and the only thing that can
    // judge it. That list is four of six tabs, chosen on an argument about what
    // a tab is *for* — snippets are a library rather than a place, a benchmark
    // takes a quarter of an hour — and a drag here is somebody disagreeing.
    //
    // The names, not a count: which tabs people put in the bar is the whole
    // question, and a tab's name says nothing about the user.
    Diag.crumb(
      DiagCategory.nav,
      'tabs arranged',
      data: {'bar': _enabled.join(' ')},
    );
  }
}
