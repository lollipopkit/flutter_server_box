import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/feature.dart';

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
  pkg;

  /// The tabs a fresh install puts in the bar, and the fallback when a stored
  /// list cannot be read.
  ///
  /// **A subset, not every tab.** This list *is* the bar: what is not in it is
  /// behind "more". Four, because that is where `NavigationBar` stops fitting
  /// labels on a phone — not a cap the code enforces, since the user may add a
  /// fifth and live with it, but the number to start from.
  ///
  /// **Not the declaration order, and it cannot be.** The declaration order is
  /// the `@HiveField` index and what `_parseAppTabFromElement` resolves an
  /// `int` against, so moving a case there would silently re-point every
  /// integer an older record holds at a different tab.
  ///
  /// Snippets are out because they are a library rather than a place: one is
  /// run against a server, from the server's own page, and the tab is where
  /// they are written and kept. Benchmark is out because a run takes a quarter
  /// of an hour and is started deliberately. Updates are out because they are
  /// read when somebody goes looking, and the detail page's card already says
  /// so for the machine in front of them.
  static const defaultOrder = [server, ssh, file, agent];

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
      if (e >= 0 && e < AppTab.values.length) {
        return AppTab.values[e];
      }
    }
    return null;
  }

  String toJson() => name;

  static AppTab fromJson(String json) =>
      _parseAppTabFromElement(json) ?? AppTab.server;

  /// This tab as the registry sees it.
  ///
  /// No [Feature.since], including for tabs added later.
  ///
  /// The other two slots use one to put what arrived in a release into the
  /// arrangement. A tab cannot: [enabledIds] for this slot *is* the bottom
  /// bar, which fits four labels on a phone, so auto-adding one takes a place
  /// from a tab the user chose. A new tab is reachable the moment it exists —
  /// [overflowOf] puts it behind "more" and the arranging page lists it — and
  /// moving it into the bar stays the user's decision.
  Feature get feature => Feature(
    id: name,
    slot: FeatureSlot.homeTab,
    icon: iconData,
    label: () => label,
  );

  /// The tab's mark.
  ///
  /// Here rather than beside the pages, so that the registry — which is data
  /// and must not reach into `view/` — can list a tab the same way it lists a
  /// card or a button. `AppTabViewX` builds the widgets from these.
  IconData get iconData => switch (this) {
    server => BoxIcons.bx_server,
    ssh => Icons.terminal_outlined,
    snippet => Icons.code_outlined,
    file => Icons.folder_open,
    agent => Icons.auto_awesome_outlined,
    benchmark => Icons.speed_outlined,
    pkg => Icons.system_update_alt_outlined,
  };

  /// The filled form, for the tab being looked at.
  IconData get selectedIconData => switch (this) {
    server => BoxIcons.bxs_server,
    ssh => Icons.terminal,
    snippet => Icons.code,
    file => Icons.folder,
    agent => Icons.auto_awesome,
    benchmark => Icons.speed,
    pkg => Icons.system_update_alt,
  };

  String get label => switch (this) {
    server => libL10n.server,
    // Not "SSH": a terminal is what this tab holds, and SSH is only where most
    // of them happen to come from. One already comes from a monitor agent's
    // own PTY, and the name had to stop naming the transport before a shell on
    // this device could live here too.
    ssh => libL10n.terminal,
    snippet => libL10n.snippet,
    file => libL10n.file,
    agent => 'Agent',
    benchmark => l10n.benchmark,
    pkg => l10n.pkgUpdates,
  };
}
