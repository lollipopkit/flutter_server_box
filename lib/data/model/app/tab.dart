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
  agent;

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
    return AppTab.values;
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
