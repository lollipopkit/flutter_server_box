import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

/// How much of each server the list shows.
///
/// Three answers to one question: how many machines are on screen.
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

  /// How tall a card is taken to be, folded and with its rows out.
  ///
  /// Taken to be, because a card is as tall as what its machine reports and
  /// [autoFor] is asked before any of them is laid out: a folded card with a
  /// line under its chart, an unfolded one with the four rows most machines
  /// have, each with its margin. `test/widget/server_card_test.dart` holds
  /// both against a card as it is actually drawn — these are numbers about a
  /// widget in another file, and nothing else would say when it changed.
  static const cardFolded = 168.0;
  static const cardUnfolded = 350.0;

  String get label => switch (this) {
    auto => libL10n.auto,
    cards => l10n.densityCards,
    rows => l10n.densityRows,
    grid => l10n.densityGrid,
  };

  /// What [auto] means for [count] servers in a list [viewport] big.
  ///
  /// The richest shape that shows all of them at once: cards while they fit,
  /// a line each while those do, and a tile each after. Past what fits, a
  /// shape stops being read and starts being scrolled, which is the point at
  /// which the next one down says more.
  ///
  /// By the window rather than by the count alone. It was the count — six and
  /// twenty-four — and those were what one desktop window of about 1200 by
  /// 800 holds, so every other window got that window's answer: a wide one
  /// went to lines with room for a dozen more cards, and a phone kept cards
  /// it could show two of.
  ///
  /// [folded] is whether a card nobody has touched rests folded — see
  /// `ServerCardExpanded` — and is what decides how tall a card is taken to
  /// be. The setting and not each card's own state: a press that unfolds one
  /// card must not be what turns the whole list into lines.
  static ServerListDensity autoFor(
    int count, {
    required Size viewport,
    required bool folded,
  }) {
    final width = viewport.width - MasonryList.kPadding.horizontal;
    final height = viewport.height - MasonryList.kPadding.vertical;

    // The masonry's own rule, with the width and the gap it lays cards out at.
    final columns =
        ((width + MasonryList.kSpacing) /
                (UIs.columnWidth + MasonryList.kSpacing))
            .floor()
            .clamp(1, 10);
    // One column is a phone, and a second screen of cards there is a flick:
    // held to one screen it has room for two cards, and would never be given
    // cards at all.
    final screens = columns == 1 ? 2 : 1;
    final perColumn =
        (height * screens / (folded ? cardFolded : cardUnfolded)).floor();
    // A card at least, whatever the window: one machine is always a card.
    if (count <= (columns * perColumn).clamp(1, double.infinity)) return cards;

    final line = isMobile ? _kLineTouch : _kLine;
    if (count <= (height / line).floor()) return rows;
    return grid;
  }

  /// What the list actually draws.
  ///
  /// [textScale] past 1 rules out the tightest one: a name in a 44pt tile is
  /// the first thing to stop fitting, and a tile that clips its own name says
  /// less than the row it would have been.
  ServerListDensity resolve({
    required int count,
    required double textScale,
    required Size viewport,
    required bool folded,
  }) {
    final it = this == auto
        ? autoFor(count, viewport: viewport, folded: folded)
        : this;
    if (it == grid && textScale > 1.0) return rows;
    return it;
  }
}

/// A line in the list, with the point above it and below: its height at a
/// pointer's size and at a finger's.
const _kLine = 42.0;
const _kLineTouch = 50.0;

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
