import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/status/card_item.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/view/page/server/card/sizes.dart';

/// How much of each item the Status list shows.
///
/// Three answers to one question: what density fits the items on screen cleanly.
enum ServerListDensity {
  /// Whatever fits. The default, and what most installs stay on: a list that
  /// grows past what cards can show — or a window that shrinks under it —
  /// should not need the user to notice and say so.
  auto(Icons.auto_mode),

  /// One reading drawn in full per machine, the rest as rows. What a handful
  /// of servers is worth.
  cards(Icons.view_agenda_outlined),

  /// A line each: a name, two bars, a rate. Every row the same height, so a
  /// machine that cannot be reached does not push the rest down.
  rows(Icons.view_list_outlined),

  /// A tile each, with room for a state, a name and one number. What a wall of
  /// forty is for: which one to look at, and nothing else.
  grid(Icons.grid_view_outlined);

  const ServerListDensity(this.icon);

  final IconData icon;

  /// Resting card heights in [cards] density (margin included), used as
  /// fallbacks before actual laid-out card heights are measured. Verified
  /// against rendered widgets in `test/widget/server_card_test.dart`,
  /// `test/widget/uptimer_widget_test.dart`, and
  /// `test/widget/status_bmc_card_test.dart`.
  static const cardFolded = 168.0;
  static const cardUnfolded = 350.0;
  static const cardCompact = 58.0;
  static const cardServerFailed = 128.0;
  static const cardUptimer = 101.0;
  static const cardUptimerAlert = 135.0;
  static const cardBmc = 85.0;
  static const cardBmcFailed = 116.0;

  /// Minimum fraction of items that must fit completely inside the viewport
  /// (`bottom <= viewportHeight`) for [auto] to keep [cards] or [rows].
  static const minVisibleRatio = 0.9;

  String get label => switch (this) {
    auto => libL10n.auto,
    cards => l10n.densityCards,
    rows => l10n.densityRows,
    grid => l10n.densityGrid,
  };

  /// Number of columns `AnimatedMasonry` creates for [availableWidth].
  static int columnsFor(
    double availableWidth, {
    double columnWidth = UIs.columnWidth,
    double spacing = MasonryList.kSpacing,
  }) {
    if (availableWidth.isNaN || availableWidth <= 0) return 1;
    if (availableWidth.isInfinite) return 10;
    return ((availableWidth + spacing) / (columnWidth + spacing))
        .floor()
        .clamp(1, 10);
  }

  /// Fallback card height for [item] in [cards] density when no measured
  /// height is available yet.
  static double cardHeightOf(
    StatusCardItem item, {
    required bool folded,
    bool Function(int monitorId)? uptimerHasBanner,
  }) => switch (item) {
    ServerCardItem() => folded ? cardFolded : cardUnfolded,
    BmcCardItem() => cardBmc,
    UptimerCardItem(:final monitor) =>
      (uptimerHasBanner?.call(monitor.id) ?? false)
          ? cardUptimerAlert
          : cardUptimer,
  };

  static bool _fitsRatio(int visible, int total) =>
      total <= 1 || visible * 10 >= total * 9;

  /// Simulates exact `AnimatedMasonry` (`cards`) and single-column (`rows`)
  /// placement inside [viewport], counting how many items fit completely
  /// within the viewport height.
  static ({int visibleCards, int visibleRows, double cardsTotal, double rowsTotal})
  _measure({
    required List<List<double>> groups,
    required bool grouped,
    required Size viewport,
    required double textScale,
  }) {
    final width = math.max(
      0.0,
      viewport.width - MasonryList.kPadding.horizontal,
    );
    final height = math.max(
      0.0,
      viewport.height - MasonryList.kPadding.vertical,
    );
    final columns = columnsFor(width);
    final extraScale = math.max(0.0, textScale - 1.0);
    // Row cards have fixed SizedBox heights (`ServerCardSizes.row` / `rowTouch`)
    // plus 2pt vertical margin regardless of `textScale`.
    final line = isMobile ? _kLineTouch : _kLine;

    var yCards = 0.0;
    var yRows = 0.0;
    var visibleCards = 0;
    var visibleRows = 0;
    var emittedGroup = 0;

    for (final group in groups) {
      if (group.isEmpty) continue;
      if (grouped) {
        final heading =
            (emittedGroup == 0 ? _kFirstGroupHeading : _kGroupHeading) *
            (1.0 + extraScale * 0.4);
        yCards += heading;
        yRows += heading;
        emittedGroup++;
      }

      // Mirror `AnimatedMasonry._shortest` (`- 0.5` epsilon) and slot spacing.
      final cols = List<double>.filled(columns, yCards);
      for (final h in group) {
        if (h <= 0) {
          if (yCards <= height + 0.5) visibleCards++;
          continue;
        }
        var shortest = 0;
        for (var i = 1; i < columns; i++) {
          if (cols[i] < cols[shortest] - 0.5) shortest = i;
        }
        final top =
            cols[shortest] +
            (cols[shortest] > yCards ? MasonryList.kSpacing : 0.0);
        final bottom = top + h;
        cols[shortest] = bottom;
        if (bottom <= height + 0.5) visibleCards++;
      }
      var groupBottom = yCards;
      for (final c in cols) {
        if (c > groupBottom) groupBottom = c;
      }
      yCards = groupBottom;

      for (var i = 0; i < group.length; i++) {
        yRows += line;
        if (yRows <= height + 0.5) visibleRows++;
      }
    }

    return (
      visibleCards: visibleCards,
      visibleRows: visibleRows,
      cardsTotal: yCards,
      rowsTotal: yRows,
    );
  }

  static ServerListDensity _decideAuto({
    required int count,
    required List<List<double>> groups,
    required bool grouped,
    required Size viewport,
    required double textScale,
    required bool allowGrid,
  }) {
    if (count <= 1) return cards;
    final m = _measure(
      groups: groups,
      grouped: grouped,
      viewport: viewport,
      textScale: textScale,
    );

    if (_fitsRatio(m.visibleCards, count)) return cards;
    if (m.visibleRows > m.visibleCards && _fitsRatio(m.visibleRows, count)) {
      return rows;
    }

    if (!allowGrid) {
      // When textScale rules out tiny grid tiles, pick whichever of cards vs
      // rows shows more complete items (tie-break: shorter total height).
      if (m.visibleCards != m.visibleRows) {
        return m.visibleCards > m.visibleRows ? cards : rows;
      }
      return m.cardsTotal <= m.rowsTotal ? cards : rows;
    }
    return grid;
  }

  /// What [auto] picks for a homogeneous list of [count] server cards.
  static ServerListDensity autoFor(
    int count, {
    required Size viewport,
    required bool folded,
    double textScale = 1.0,
  }) => auto.resolve(
    count: count,
    textScale: textScale,
    viewport: viewport,
    folded: folded,
  );

  /// What [auto] picks for a mixed list of [StatusCardItem]s (and optional tag
  /// [groups]), deciding dynamically from whether at least 90% of items fit
  /// completely within [viewport].
  static ServerListDensity autoForItems(
    List<StatusCardItem> items, {
    List<List<StatusCardItem>>? groups,
    required Size viewport,
    required bool folded,
    double textScale = 1.0,
    bool Function(int monitorId)? uptimerHasBanner,
    double? Function(StatusCardItem item)? heightOf,
  }) => auto.resolveItems(
    items,
    groups: groups,
    textScale: textScale,
    viewport: viewport,
    folded: folded,
    uptimerHasBanner: uptimerHasBanner,
    heightOf: heightOf,
  );

  /// What the list actually draws for a homogeneous list of [count] servers.
  ///
  /// [textScale] past 1 rules out [grid]: a name in a 44pt tile is the first
  /// thing to stop fitting.
  ServerListDensity resolve({
    required int count,
    required double textScale,
    required Size viewport,
    required bool folded,
  }) {
    final allowGrid = textScale <= 1.0;
    if (this == auto) {
      final cardTextFactor = 1.0 + math.max(0.0, textScale - 1.0) * 0.35;
      final h = (folded ? cardFolded : cardUnfolded) * cardTextFactor;
      return _decideAuto(
        count: count,
        groups: [List<double>.filled(math.max(0, count), h)],
        grouped: false,
        viewport: viewport,
        textScale: textScale,
        allowGrid: allowGrid,
      );
    }
    if (this == grid && !allowGrid) return rows;
    return this;
  }

  /// What the list actually draws for mixed [items] (and optional tag [groups]).
  ///
  /// When [heightOf] returns a non-null measured height for an item, that
  /// height is used directly (already reflecting current `textScale` and live
  /// card contents); otherwise falls back to [cardHeightOf] scaled for text.
  ServerListDensity resolveItems(
    List<StatusCardItem> items, {
    List<List<StatusCardItem>>? groups,
    required double textScale,
    required Size viewport,
    required bool folded,
    bool Function(int monitorId)? uptimerHasBanner,
    double? Function(StatusCardItem item)? heightOf,
  }) {
    final allowGrid = textScale <= 1.0;
    if (this == auto) {
      final cardTextFactor = 1.0 + math.max(0.0, textScale - 1.0) * 0.35;
      double resolveHeight(StatusCardItem item) {
        final measured = heightOf?.call(item);
        if (measured != null && measured > 0) return measured;
        return cardHeightOf(
              item,
              folded: folded,
              uptimerHasBanner: uptimerHasBanner,
            ) *
            cardTextFactor;
      }

      final heightGroups = groups == null
          ? [
              [for (final item in items) resolveHeight(item)],
            ]
          : [
              for (final group in groups)
                [for (final item in group) resolveHeight(item)],
            ];
      return _decideAuto(
        count: items.length,
        groups: heightGroups,
        grouped: groups != null,
        viewport: viewport,
        textScale: textScale,
        allowGrid: allowGrid,
      );
    }
    if (this == grid && !allowGrid) return rows;
    return this;
  }
}

/// A line in the list, with the 1pt vertical margin above and below.
const _kLine = ServerCardSizes.row + 2.0;
const _kLineTouch = ServerCardSizes.rowTouch + 2.0;

/// Approximate height of [ServerGroupHeading] for first and subsequent groups.
const _kFirstGroupHeading = 24.0;
const _kGroupHeading = 38.0;

/// Which density each tag is viewed at.
///
/// Per tag because a tag is a set of machines: `#prod` with forty in it and
/// `#local` with two want different answers, and remembering one setting for
/// both means changing it on every switch.
abstract final class ServerDensityPref {
  /// The key a tag is stored under. The empty tag — "all" — is a set too, and
  /// the one the app opens on.
  static String _key(String tag) => tag;

  static ServerListDensity of(String tag) {
    final name = Stores.setting.serverListDensity.fetch()[_key(tag)];
    return ServerListDensity.values.firstWhereOrNull((e) => e.name == name) ??
        ServerListDensity.auto;
  }

  static void put(String tag, ServerListDensity density) {
    final map = Map<String, String>.from(
      Stores.setting.serverListDensity.fetch(),
    );
    map[_key(tag)] = density.name;
    Stores.setting.serverListDensity.put(map);
  }
}
