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
  benchmark,
  @HiveField(6)
  remoteDesktop,

  /// Libvirt/KVM and Proxmox VE guests.
  ///
  /// Index 7 by position, the one `monitorSettings` held — see
  /// [_retiredIndices], which is why an integer 7 still resolves to nothing
  /// rather than to this.
  @HiveField(7)
  virt;

  /// Indices that named a tab which no longer exists, and so are never
  /// resolved as an integer.
  ///
  /// 7 was `monitorSettings`, a whole tab for a `monitor` agent's own
  /// configuration. It is reached from the agent's server instead — one button
  /// in that page's bar — which is where someone already is when they want it.
  ///
  /// [values] is positional, so [virt], appended next, took index 7. It stays
  /// listed anyway, and that is safe in both directions: every build since
  /// the SQLite migration stores tabs by name, so no record written by one
  /// holds an integer at all, and the builds that stored integers (Hive) came
  /// before either tab existed. No stored bar can hold a 7, then, and one
  /// that turns up anyway resolves to nothing rather than to a tab nobody
  /// chose.
  // TODO(migration): drop once no stored tab order can still hold it.
  static const _retiredIndices = {7};

  /// The tabs a fresh install puts in the bar, and the fallback when a stored
  /// list cannot be read.
  ///
  /// **A subset, not every tab.** This list *is* the bar: what is not in it is
  /// behind "more". Four was the number to start from, because that is where
  /// `NavigationBar` stops fitting labels on a phone; it is not a cap the code
  /// enforces, and Virtualization made it five (below).
  ///
  /// **Not the declaration order, and it cannot be.** The declaration order is
  /// the `@HiveField` index and what `_parseAppTabFromElement` resolves an
  /// `int` against, so moving a case there would silently re-point every
  /// integer an older record holds at a different tab.
  ///
  /// Snippets are out because they are a library rather than a place: one is
  /// run against a server, from the server's own page, and the tab is where
  /// they are written and kept. Benchmark is out because a run takes a quarter
  /// of an hour and is started deliberately.
  ///
  /// Virtualization is the fifth. A bar the user arranged is stored and keeps
  /// its own tabs (schema step m030 adds this one only where a PVE host was
  /// configured); one never arranged is this list, read at launch, so it gets
  /// the tab like a fresh install does.
  static const defaultOrder = [server, ssh, file, agent, virt];

  /// The tabs not in [enabled], in declaration order — what "more" holds.
  ///
  /// Settings is not among them, and is not an [AppTab] at all: it is a
  /// destination the bar pins to its end, never stored, never arranged, and
  /// never read back from a record. As a case here it would have been a
  /// `@HiveField`, a line in the parser removing it again, a branch in every
  /// exhaustive switch, and a second list saying which cases are real — all of
  /// it to express that this one is not like the others. It is what keeps the
  /// way back to the arranging page reachable when every tab is turned on and
  /// "more" goes away.
  static List<AppTab> overflowOf(Iterable<AppTab> enabled) {
    final on = enabled.toSet();
    return [
      for (final tab in values)
        if (!on.contains(tab)) tab,
    ];
  }

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
      if (_retiredIndices.contains(e)) return null;
      if (e >= 0 && e < AppTab.values.length) {
        return AppTab.values[e];
      }
    }
    return null;
  }

}
