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
  snippet;

  /// Helper function to parse AppTab list from stored object
  static List<AppTab> parseAppTabsFromObj(dynamic val) {
    if (val is List) {
      final tabs = <AppTab>[];
      for (final e in val) {
        final tab = _parseAppTabFromElement(e);
        if (tab != null) {
          tabs.add(tab);
        }
      }
      if (tabs.isNotEmpty) return tabs;
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
}
