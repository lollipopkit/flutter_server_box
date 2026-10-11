import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';

/// A server's other faces, shown beside the one a tab is about.
///
/// The server, terminal and file tabs are three views of one machine. Each can
/// open the other two next to its own subject — a column on the right where
/// there is room, a sheet over the subject where there is not — so checking
/// the load from a terminal, or the directory a command just wrote to, is not a
/// trip to another tab and back.
enum CompanionPanel {
  status,
  terminal,
  files;

  /// The panels [tab] offers: the other two of the three, in the order the
  /// bar shows them. None for any other tab.
  static List<CompanionPanel> of(AppTab tab) => switch (tab) {
    AppTab.server => const [terminal, files],
    AppTab.ssh => const [status, files],
    AppTab.file => const [status, terminal],
    _ => const [],
  };

  static CompanionPanel? byName(String name) => values.asNameMap()[name];
}

/// Which panels each tab has open, and how its column is laid out — stored,
/// because a column somebody set up is how they work.
///
/// Read through [listenable] rather than once: the three tabs are kept alive
/// behind each other, and the column's width is one setting they all draw.
abstract final class CompanionPanels {
  /// One per store: handed to a builder on every build, a new merge each
  /// time would be unsubscribed and subscribed again each time. Per store
  /// rather than for good, because a store registered again (a test) is a new
  /// set of properties.
  static Listenable get listenable {
    final store = Stores.setting;
    if (identical(_listenableOf, store)) return _listenable!;
    _listenableOf = store;
    return _listenable = Listenable.merge([
      store.companionPanels.listenable(),
      store.companionCollapsed.listenable(),
      store.companionWidth.listenable(),
      store.companionFolded.listenable(),
      store.companionSplit.listenable(),
    ]);
  }

  static Object? _listenableOf;
  static Listenable? _listenable;

  /// [tab]'s open panels, the most recently opened last — the one a sheet,
  /// which shows one at a time, puts on top.
  static List<CompanionPanel> openOf(AppTab tab) =>
      _read(Stores.setting.companionPanels.fetch(), tab);

  /// The open panels folded to their header in [tab]'s column.
  static Set<CompanionPanel> collapsedOf(AppTab tab) =>
      _read(Stores.setting.companionCollapsed.fetch(), tab).toSet();

  /// Opens [panel] on [tab], or brings it to the top of the open ones.
  static void open(AppTab tab, CompanionPanel panel) => _write(
    Stores.setting.companionPanels,
    tab,
    [...openOf(tab).where((e) => e != panel), panel],
  );

  static void close(AppTab tab, CompanionPanel panel) => _write(
    Stores.setting.companionPanels,
    tab,
    openOf(tab).where((e) => e != panel),
  );

  static void setCollapsed(AppTab tab, CompanionPanel panel, bool collapsed) {
    final current = collapsedOf(tab);
    if (collapsed ? !current.add(panel) : !current.remove(panel)) return;
    _write(Stores.setting.companionCollapsed, tab, current);
  }

  static double get width => Stores.setting.companionWidth.fetch();

  static void saveWidth(double width) =>
      Stores.setting.companionWidth.put(width);

  static bool get folded => Stores.setting.companionFolded.fetch();

  static void saveFolded(bool folded) =>
      Stores.setting.companionFolded.put(folded);

  /// The share of the column's height the upper of two sections has.
  static double get split => Stores.setting.companionSplit.fetch();

  static void saveSplit(double split) =>
      Stores.setting.companionSplit.put(split);

  /// Names the store no longer knows — a panel since removed — are dropped,
  /// and so is a panel [tab] does not offer.
  static List<CompanionPanel> _read(Map<String, String> stored, AppTab tab) {
    final offered = CompanionPanel.of(tab);
    return [
      for (final name in (stored[tab.name] ?? '').split(','))
        if (CompanionPanel.byName(name) case final panel?)
          if (offered.contains(panel)) panel,
    ];
  }

  static void _write(
    SqlitePropDefault<Map<String, String>> property,
    AppTab tab,
    Iterable<CompanionPanel> panels,
  ) {
    final stored = Map<String, String>.of(property.fetch());
    final value = panels.map((e) => e.name).join(',');
    if (value.isEmpty) {
      stored.remove(tab.name);
    } else {
      stored[tab.name] = value;
    }
    property.put(stored);
  }
}
