import 'package:hive_ce_flutter/adapters.dart';

part 'tab.g.dart';

@HiveType(typeId: 103)
enum AppTab {
  @HiveField(0)
  server,
  @HiveField(1)
  ssh,
  @HiveField(2)
  file,
  @HiveField(3)
  snippet,
  @HiveField(4)
  agent,
  @HiveField(5)
  benchmark;

  /// What a fresh install gets, and the fallback when a stored list cannot be
  /// read.
  ///
  /// **Not the declaration order, and it cannot be.** The bar shows the first
  /// `_kMaxBarTabs` of these and puts the rest behind "more", so the order is
  /// what decides which tab is a tap away — but the declaration order is also
  /// the `@HiveField` index and what `_parseAppTabFromElement` resolves an
  /// `int` against, so moving a case there would silently re-point every
  /// integer an older record holds at a different tab.
  ///
  /// Snippets are last because they are a library rather than a place: one is
  /// run against a server, from the server's own page, and the tab is where
  /// they are written and kept. The Agent is the opposite — somewhere to be,
  /// and reached from nowhere else.
  ///
  /// Benchmark is after them both: a run takes a quarter of an hour and is
  /// started deliberately, so it is the tab least often wanted and the one that
  /// can afford to sit behind "more".
  static const defaultOrder = [server, ssh, file, agent, snippet, benchmark];

  /// Helper function to parse AppTab list from stored object
  ///
  /// A repeat is dropped rather than kept. The home page is a list of pages
  /// indexed by position and a nav bar of the same length, so a value naming
  /// one tab twice — a restore of a record another build wrote, an edit by
  /// hand — puts the same page on screen twice and leaves "which position is
  /// Terminal" without an answer. First occurrence wins, so the order the user
  /// arranged is what survives.
  static List<AppTab> parseAppTabsFromObj(dynamic val) {
    if (val is List) {
      final tabs = <AppTab>{};
      for (final e in val) {
        final tab = _parseAppTabFromElement(e);
        if (tab != null) {
          tabs.add(tab);
        }
      }
      if (tabs.isNotEmpty) return tabs.toList();
    }
    return defaultOrder;
  }

  /// Helper function to parse a single AppTab from various element types
  static AppTab? _parseAppTabFromElement(dynamic e) {
    if (e is AppTab) {
      return e;
    } else if (e is String) {
      for (final tab in AppTab.values) {
        if (tab.name == e) return tab;
      }
    } else if (e is int) {
      if (e >= 0 && e < AppTab.values.length) {
        return AppTab.values[e];
      }
    }
    return null;
  }

  String toJson() => name;

  static AppTab fromJson(String json) =>
      _parseAppTabFromElement(json) ?? AppTab.server;
}
