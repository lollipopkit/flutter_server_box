import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';

/// A server's other faces, shown beside the one a tab is about.
///
/// The server, terminal and file tabs are three views of one machine. Each can
/// show the other two, and the Agent, next to its own subject — a column on
/// the right where there is room, a sheet over the subject where there is not
/// — one at a time, switched like tabs. Checking the load from a terminal, or
/// the directory a command just wrote to, is then not a trip to another tab
/// and back.
enum CompanionPanel {
  status,
  terminal,
  files,
  agent;

  /// The panels [tab] offers, in the order they are switched between. None
  /// for any other tab.
  static List<CompanionPanel> of(AppTab tab) => switch (tab) {
    AppTab.server => const [terminal, files, agent],
    AppTab.ssh => const [status, files, agent],
    AppTab.file => const [status, terminal, agent],
    _ => const [],
  };
}

/// Whether each tab has its panels open, which one it shows, and how wide they
/// are — stored, because panels somebody set up are how they work.
///
/// Read through [listenable] rather than once: the three tabs are kept alive
/// behind each other, and the width is one setting they all draw.
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
      store.companionPanel.listenable(),
      store.companionOpen.listenable(),
      store.companionWidth.listenable(),
    ]);
  }

  static Object? _listenableOf;
  static Listenable? _listenable;

  /// The panel [tab] shows, open or not: the one it was left on, or its first.
  static CompanionPanel selectedOf(AppTab tab) {
    final offered = CompanionPanel.of(tab);
    final stored = Stores.setting.companionPanel.fetch()[tab.name];
    return offered.firstWhere(
      (panel) => panel.name == stored,
      orElse: () => offered.first,
    );
  }

  static bool isOpen(AppTab tab) =>
      CompanionPanel.of(tab).isNotEmpty &&
      (Stores.setting.companionOpen.fetch()[tab.name] ?? false);

  /// Opens [tab]'s panels, on [panel] when given and on the last one shown
  /// otherwise.
  static void open(AppTab tab, [CompanionPanel? panel]) {
    if (panel != null) {
      Stores.setting.companionPanel.put({
        ...Stores.setting.companionPanel.fetch(),
        tab.name: panel.name,
      });
    }
    _setOpen(tab, true);
  }

  static void close(AppTab tab) => _setOpen(tab, false);

  static void toggle(AppTab tab) => _setOpen(tab, !isOpen(tab));

  static double get width => Stores.setting.companionWidth.fetch();

  static void saveWidth(double width) =>
      Stores.setting.companionWidth.put(width);

  static void _setOpen(AppTab tab, bool open) {
    if (isOpen(tab) == open) return;
    final stored = Map<String, bool>.of(Stores.setting.companionOpen.fetch());
    if (open) {
      stored[tab.name] = true;
    } else {
      stored.remove(tab.name);
    }
    Stores.setting.companionOpen.put(stored);
  }
}
