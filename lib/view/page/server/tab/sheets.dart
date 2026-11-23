part of 'tab.dart';

extension _Sheets on _ServerPageState {
  Future<void> _showDensitySheet(int count) async {
    final stored = ServerDensityPref.of(_tag.value);
    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        for (final density in ServerListDensity.values)
          SheetChoiceTile(
            icon: density.icon,
            title: density.label,
            // What `auto` means right now, said where the choice is made: the
            // control otherwise gives no clue which of the three it picked.
            selected: density == stored,
            onTap: () {
              Navigator.of(ctx).pop();
              _setDensity(density);
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 7, 17, 27),
          child: Text(
            '${libL10n.auto} · $count → '
            '${_resolvedDensity(ServerListDensity.auto, count).label}',
            style: UIs.text11Grey,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// How to order the list, and whether to cut it into sections.
  ///
  /// The default is the arrangement from the settings, so this starts as a
  /// view of what the user already decided rather than as a decision it takes
  /// from them.
  ///
  /// The two are in one sheet and are not one choice: an order is which
  /// machine comes first, and grouping is which machines are read together.
  /// So picking an order closes the sheet — it is the question that was asked
  /// — and the switch under them does not, because it is a second question
  /// that has only now become visible.
  Future<void> _showSortSheet() async {
    final tag = _tag.value;
    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        ...serverSortRows(ctx, tag, _sortVersion.notify),
        const Divider(height: 1),
        StatefulBuilder(
          builder: (_, setSheetState) {
            final on = ServerListGrouping.of(tag) == ServerListGrouping.tag;
            return SwitchListTile(
              secondary: const Icon(MingCute.hashtag_line),
              title: Text(l10n.groupByTag),
              // What it is for, where it is turned on: the sections are cut by
              // the tags a machine carries, which is a thing set in the
              // server's own editor and not here.
              subtitle: Text(l10n.groupByTagTip, style: UIs.text11Grey),
              value: on,
              onChanged: (next) {
                ServerListGrouping.put(
                  tag,
                  next ? ServerListGrouping.tag : ServerListGrouping.none,
                );
                setSheetState(() {});
                _sortVersion.notify();
              },
            );
          },
        ),
      ],
    );
  }

  /// Where tags come from is a server's editor, and nothing on this tab
  /// says so — see [showTagSheet].
  Future<void> _showTagSheet(List<String> tags) => showTagSheet(
    context,
    tags: tags,
    current: _tag.value,
    onPick: (tag) => _tag.value = tag,
    emptyTip: l10n.tagsEmptyTip,
  );

  /// Every machine, for picking one without going back to the grid.
  ///
  /// The column beside an open card is this same list, where there is room
  /// for one; this is for where there is not, and for a list long enough to
  /// want something to type into and the tags to group by.
  Future<void> _showItemSheet(
    List<StatusCardItem> filtered,
    StatusCardItem openItem,
  ) async {
    final hasNonServer = filtered.any((i) => i is! ServerCardItem);
    if (!hasNonServer && openItem is ServerCardItem) {
      final picked = await showServerSwitcher(
        context,
        ids: [for (final i in filtered) i.id],
        current: openItem.id,
      );
      if (picked == null || !mounted) return;
      final item = filtered.firstWhereOrNull((i) => i.id == picked);
      if (item != null) _openDetail(item);
      return;
    }

    final picked = await showRowsSheet<StatusCardItem>(
      context,
      rows: (ctx) => [
        for (final item in filtered)
          SheetChoiceTile(
            icon: switch (item) {
              ServerCardItem() => BoxIcons.bx_server,
              BmcCardItem() => Icons.developer_board,
            },
            title: item.name,
            subtitle: item.displayAddr,
            selected: item.cardKey == openItem.cardKey,
            onTap: () => Navigator.of(ctx).pop(item),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    _openDetail(picked);
  }
}
