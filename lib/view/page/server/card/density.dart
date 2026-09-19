import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

/// How much of each server the list shows.
///
/// Three answers to one question — how many machines are on screen — and the
/// question is asked by the number of them rather than by the size of the
/// window: three servers on a desktop are still three servers, and forty on a
/// desktop are still forty.
enum ServerListDensity {
  /// Whatever the count calls for. The default, and what most installs stay
  /// on: a list that grows past what cards can show should not need the user
  /// to notice and say so.
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

  String get label => switch (this) {
    auto => libL10n.auto,
    cards => l10n.densityCards,
    rows => l10n.densityRows,
    grid => l10n.densityGrid,
  };

  /// What [auto] means for [count] servers.
  ///
  /// The boundaries are where one shape stops answering: past six, cards are
  /// taller than a window and the list becomes scrolling rather than reading;
  /// past two dozen, a line each is still a page of scrolling and what is
  /// wanted is the whole estate at once.
  static ServerListDensity autoFor(int count) {
    if (count <= 6) return cards;
    if (count <= 24) return rows;
    return grid;
  }

  /// What the list actually draws.
  ///
  /// [textScale] past 1 rules out the tightest one: a name in a 44pt tile is
  /// the first thing to stop fitting, and a tile that clips its own name says
  /// less than the row it would have been.
  ServerListDensity resolve({required int count, required double textScale}) {
    final it = this == auto ? autoFor(count) : this;
    if (it == grid && textScale > 1.0) return rows;
    return it;
  }
}

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
