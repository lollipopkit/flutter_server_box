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
        for (final order in ServerSortOrder.all)
          SheetChoiceTile(
            icon: order.icon,
            title: order.label,
            selected: order.isCurrentFor(tag),
            onTap: () {
              order.save(tag);
              Navigator.of(ctx).pop();
              _sortVersion.notify();
            },
          ),
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

  /// The tags, as rows. The same sheet the session switchers open, for the
  /// same reason: a strip of them would be as wide as the names happened to be.
  Future<void> _showTagSheet(List<String> tags) async {
    await showRowsSheet<void>(
      context,
      rows: (ctx) {
        void pick(String tag) {
          Navigator.of(ctx).pop();
          _tag.value = tag;
        }

        return [
          SheetChoiceTile(
            icon: MingCute.hashtag_line,
            title: libL10n.all,
            selected: _tag.value.isEmpty,
            onTap: () => pick(TagSwitcher.kDefaultTag),
          ),
          const Divider(height: 1),
          // Where tags come from, for the sheet that would otherwise be one
          // row saying "All" — which reads as a broken filter rather than as
          // an empty one. A server's editor is the only place they are made,
          // and nothing on this tab says so.
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 27),
              child: Text(
                l10n.tagsEmptyTip,
                style: UIs.textGrey,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final tag in tags)
              // The same shape as the row above it: the mark, then the name.
              // The mark is the `#`, so the name does not carry one as well.
              SheetChoiceTile(
                icon: MingCute.hashtag_line,
                title: tag,
                selected: tag == _tag.value,
                onTap: () => pick(tag),
              ),
        ];
      },
    );
  }

  /// Every machine, for picking one without going back to the grid.
  ///
  /// The strip of pills over an open card is this same list and answers it for
  /// a handful; past that they stop fitting, and what a longer one wants is
  /// something to type into and the tags to group by.
  Future<void> _showServerSheet(List<String> filtered, String openId) async {
    final picked = await showServerSwitcher(
      context,
      ids: filtered,
      current: openId,
    );
    if (picked == null || !mounted) return;
    _openDetail(picked);
  }
}
