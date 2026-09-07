import 'package:flutter/widgets.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/res/store.dart';

/// Where an entry appears, and where its arrangement is kept.
///
/// One place naming all three. They were three lists in three shapes with
/// three copies of "add what arrived in this release" — see [Features.autoAdd]
/// — and a fourth surface meant a fourth copy.
enum FeatureSlot {
  /// The row of buttons on a server's detail page.
  funcBtn,

  /// The cards on a server's detail page.
  detailCard,

  /// The tabs at the bottom of the home page.
  homeTab;

  /// What a fresh install starts with, in order.
  ///
  /// Not every entry, for [funcBtn] and [homeTab]: those two lists *are* the
  /// row and the bar, and what is left out is reachable but not shown.
  List<String> get defaultIds => switch (this) {
    funcBtn => ServerFuncBtn.defaultIds,
    detailCard => ServerDetailCards.names,
    homeTab => AppTab.defaultOrder.map((e) => e.name).toList(),
  };

  /// The ids the user has turned on, in the order they arranged them.
  ///
  /// Ids, not enum values: what is stored outlives the build that wrote it,
  /// and a plugin's entry is not an enum case at all.
  List<String> enabledIds() => switch (this) {
    funcBtn => Stores.setting.serverFuncBtns.fetch(),
    detailCard => Stores.setting.detailCardOrder.fetch(),
    homeTab => Stores.setting.homeTabs.fetch().map((e) => e.name).toList(),
  };

  /// Writes [ids] back, de-duplicated.
  ///
  /// **An id this build has nothing for is kept, not dropped.** A plugin that
  /// is not installed right now has no entry here, and dropping its id would
  /// lose where the user had put it — so an unclaimed id is ignored when the
  /// list is *read* and carried when it is written (PLUGINS.md section 7).
  /// A repeat is dropped: these lists are arrangements, and one entry twice
  /// has no meaning.
  ///
  /// [homeTab] is the exception and cannot help it: its property is typed
  /// `List<AppTab>`, so a name no case matches has nowhere to go. Widening it
  /// is part of letting a plugin contribute a tab.
  ///
  /// Synchronous because the callers own a transaction.
  void putEnabledIds(List<String> ids) {
    final kept = <String>[];
    for (final id in ids) {
      if (!kept.contains(id)) kept.add(id);
    }
    switch (this) {
      case funcBtn:
        Stores.setting.serverFuncBtns.putSync(kept);
      case detailCard:
        Stores.setting.detailCardOrder.putSync(kept);
      case homeTab:
        Stores.setting.homeTabs.putSync(AppTab.parseAppTabsFromObj(kept));
    }
  }
}

/// One entry the app can show, declared once.
///
/// Adding a feature used to mean an enum case, a `switch` for its icon,
/// another for its name, a boundary build for upgrading installs, a branch
/// deciding whether the connection can serve it, and an entry in whichever
/// ordering page it belonged to — spread across files that had no reason to
/// know about each other. This is the one declaration those all read.
///
/// The built-in entries are still Dart enums: they carry the widget that draws
/// them and the code that runs when they are tapped, and neither is data. What
/// moves here is everything *about* them, which is the part a plugin's
/// `contributes` block will supply for itself.
@immutable
final class Feature {
  const Feature({
    required this.id,
    required this.slot,
    required this.icon,
    required this.label,
    this.since,
    this.needs,
  });

  /// Stable, stored, and never an index.
  ///
  /// An index stops meaning what it said the moment a case moves — which is
  /// exactly what a registry is supposed to make safe — and these values
  /// outlive the build that wrote them, through a backup and through a sync.
  final String id;

  final FeatureSlot slot;

  final IconData icon;

  /// Read per call rather than held: it is localised, and the locale changes
  /// under a running app.
  final String Function() label;

  /// The last released build that did **not** have this entry, or null for one
  /// that has always been there — or one that is deliberately not offered
  /// until the user goes looking, which is what `iperf` is.
  ///
  /// A feature branch's commit count is not a release number: Power was
  /// developed at build 1481 but merged after v1.0.1491, so 1481 made a v1491
  /// install look as though it had already seen the entry. A release boundary
  /// stays true however many commits the branch collected first.
  ///
  /// **An entry that carries one must also be in its slot's
  /// [FeatureSlot.defaultIds].** A boundary is what reaches an *upgrading*
  /// install and the defaults are what reach a fresh one, so an entry with a
  /// boundary and no default place would arrive everywhere except a new
  /// install — the one combination nobody is asking for.
  final int? since;

  /// What the connection must be able to do, or null where the entry does not
  /// depend on one.
  ///
  /// Asked of the capabilities rather than of the transport, and asked per
  /// entry: the needs are genuinely different, and a server reached over its
  /// monitor agent meets some of them.
  final bool Function(ServerCapabilities caps)? needs;

  bool availableWith(ServerCapabilities caps) => needs?.call(caps) ?? true;
}

/// Every entry the app can show, by slot.
///
/// A view over the built-in declarations rather than a second copy of them:
/// each enum builds its own [Feature], so there is nothing to keep in step.
/// A plugin's contributions are appended here once the app knows which plugins
/// are installed (PLUGINS.md section 10 step 5).
abstract final class Features {
  static List<Feature> of(FeatureSlot slot) => switch (slot) {
    FeatureSlot.funcBtn => [for (final e in ServerFuncBtn.values) e.feature],
    FeatureSlot.detailCard => [
      for (final e in ServerDetailCards.values) e.feature,
    ],
    FeatureSlot.homeTab => [for (final e in AppTab.values) e.feature],
  };

  static Feature? byId(FeatureSlot slot, String id) {
    for (final f in of(slot)) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Puts entries that arrived during an upgrade into the user's list, which
  /// was last written when they did not exist.
  ///
  /// The window is `(from, to]`, not "everything up to [to]". An entry the
  /// user has since taken *out* of their list was a decision, and a rule that
  /// only looks at [to] re-adds it on every later upgrade — overruling that
  /// decision every time, forever. Only an entry that did not exist the last
  /// time they could have chosen is added.
  ///
  /// [from] is 0 on a fresh install, where each slot's default already lists
  /// every entry that carries a boundary, so nothing here fires. An entry left
  /// out of the defaults must therefore also have no [Feature.since], or a
  /// fresh install would be the only kind that never gets it.
  static void autoAdd(int from, int to) {
    for (final slot in FeatureSlot.values) {
      final stored = slot.enabledIds();
      final added = [
        for (final f in of(slot))
          if (f.since case final boundary?
              when boundary >= from && boundary < to && !stored.contains(f.id))
            f.id,
      ];
      if (added.isEmpty) continue;
      slot.putEnabledIds([...stored, ...added]);
    }
  }
}
