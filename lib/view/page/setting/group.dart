part of 'entry.dart';


/// One row of a settings group.
///
/// [label] is what the search reads and [build] is what is drawn. They are
/// given separately, and the row is built lazily, for two reasons the same
/// shape: a label can be a `TipText`, a value a `ValBuilder` and a control a
/// `StoreSwitch`, none of which a search can read out of a widget without
/// building it — and a row that asks the platform whether notifications are
/// allowed must not do so once per keystroke while somebody types in the
/// search field.
///
/// So [label] is passed in by the row's own builder, from the same variable
/// its title is built from. Writing it twice is what would go stale.
final class SettingsRow {
  const SettingsRow(this.label, this.build, {this.keywords});

  final String label;

  final Widget Function() build;

  /// Anything else this row answers to — a tip, a unit, the English word for
  /// something this locale spells differently.
  final String? keywords;

  bool matches(String needle) =>
      label.toLowerCase().contains(needle) ||
      (keywords?.toLowerCase().contains(needle) ?? false);
}

/// A row described by a file this one is imported by — see [SettingsRowSpec].
extension SettingsRowSpecX on SettingsRowSpec {
  SettingsRow get row => SettingsRow(label, build);
}

/// One named group of settings: a heading, and a card of rows under it.
///
/// A group is what the form is read in. Before this every row was its own
/// card, which on a wide window was a column of identical rounded rectangles
/// with nothing saying which of them belonged together — and the things that
/// did belong together were behind a tile called "More".
final class SettingsGroup {
  const SettingsGroup(this.title, this.rows, {this.carded = true});

  final String title;

  final List<SettingsRow> rows;

  /// Whether the rows go in one card.
  ///
  /// False for a group whose single row draws its own surfaces — the
  /// diagnostics picker is a list of cards, and a card round it is a card
  /// round cards.
  final bool carded;
}

/// A group, drawn.
final class SettingsGroupView extends StatelessWidget {
  const SettingsGroupView(this.group, {super.key, this.animated = false});

  final SettingsGroup group;

  /// Whether the rows arrive and leave rather than appear and vanish.
  ///
  /// For the search, where the list is rebuilt from what has been typed and
  /// what changed between two of those builds is the one thing a reader cannot
  /// see happen. Off everywhere else: a group's rows there change when a
  /// platform answers or a profile is installed, which is rare enough that an
  /// animation would be the first anyone knew of it.
  final bool animated;

  /// The row metrics the design gives this form.
  ///
  /// Scoped to the settings rather than raised into the app's own tile theme:
  /// a row here is one of twenty on a page whose whole job is to be read down,
  /// and the app's tiles are rows of two or three on a page that is mostly
  /// something else. Four points a row is half a screen over a group.
  static const _rowTheme = ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 13),
    horizontalTitleGap: 11,
    minLeadingWidth: 0,
    minVerticalPadding: 7,
    minTileHeight: 40,
  );

  @override
  Widget build(BuildContext context) {
    final rows = [for (final row in group.rows) row.build()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Four, not nothing and not the design's 17: the grid puts nine
        // between two groups and a `CardX` carries four of its own, so four
        // here is the seventeen the design draws.
        GroupTitle(group.title, padding: const EdgeInsets.fromLTRB(3, 4, 3, 7)),
        ListTileTheme.merge(
          contentPadding: _rowTheme.contentPadding,
          horizontalTitleGap: _rowTheme.horizontalTitleGap,
          minLeadingWidth: _rowTheme.minLeadingWidth,
          minVerticalPadding: _rowTheme.minVerticalPadding,
          minTileHeight: _rowTheme.minTileHeight,
          child: group.carded
              // Clipped, so a row growing into the card does not paint past
              // its rounded corners on the way in.
              ? CardX(child: _rows(context, rows))
              : _rows(context, rows),
        ),
      ],
    );
  }

  /// The rows, separated rather than each carded.
  ///
  /// A hairline between two rows of one card is what says they are one thing;
  /// a gap between two cards says the opposite.
  Widget _rows(BuildContext context, List<Widget> rows) {
    final separator = group.carded
        ? Divider(
            height: Hairline.thickness,
            thickness: Hairline.thickness,
            color: Hairline.color(context),
          )
        : null;

    if (animated) {
      // Keyed by the row's own name, which is what says a row survived the
      // keystroke that rebuilt the list. The separator is [AnimatedColumn]'s
      // to place, so that a row leaving takes its own line with it.
      return AnimatedColumn(
        separator: separator,
        children: [
          for (final (at, row) in rows.indexed)
            KeyedSubtree(key: ValueKey(group.rows[at].label), child: row),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (at, row) in rows.indexed) ...[
          if (at > 0 && separator != null) separator,
          row,
        ],
      ],
    );
  }
}
