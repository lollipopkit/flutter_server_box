import 'package:flutter/foundation.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/installed.dart';

/// What the installed plugins add to the feature registry.
///
/// The seam between the two. `Features` is data — it lists what the app can
/// show and must not reach into the plugin layer to find out — and this is
/// where the plugin layer puts its answer.
///
/// Only *enabled* plugins contribute. A plugin the user turned off keeps its
/// configuration, its data and its place in whatever they arranged, and an id
/// nothing claims is ignored when a list is read and kept when it is written
/// (PLUGINS.md section 7) — which is exactly what makes switching one off and
/// on again put it back where it was.
abstract final class PluginContributions {
  static var _byId = <String, InstalledPlugin>{};

  /// Bumped whenever [publish] or [clear] replaces the set.
  ///
  /// What a surface follows so an edit to a development directory reaches a
  /// page that is already open. Without it the whole reload path existed and
  /// nothing ever triggered it: `PluginSurfaceView.didUpdateWidget` reloads
  /// the instance when `spec.source` changes, but the page held the
  /// `InstalledPlugin` captured when it was opened, and nothing told it to
  /// look again.
  ///
  /// A counter rather than the map itself: the value is only ever compared for
  /// change, and handing out the map would let a listener hold plugins that
  /// have since been uninstalled.
  static final revision = ValueNotifier(0);

  /// What the published set was made of, so an unchanged one is not
  /// republished. See [publish].
  static String _fingerprint = '';

  /// Replaces what plugins contribute, after an install, an uninstall, or the
  /// pass at launch that reads them.
  ///
  /// **The revision moves only when something actually changed.** Opening the
  /// plugins settings page re-reads every directory on `initState`, and that
  /// is the common case by far — the files are usually the same bytes they
  /// were. Bumping regardless would rebuild every open plugin surface every
  /// time somebody looked at the list. A surface would then compare its source
  /// and decline to reload, so nothing visible went wrong, which is exactly
  /// why it would never have been noticed.
  static void publish(Iterable<InstalledPlugin> plugins) {
    final next = {
      for (final plugin in plugins)
        if (plugin.record.enabled) plugin.id: plugin,
    };
    _byId = next;
    _bumpIfChanged(_fingerprintOf(next.values));
  }

  static void clear() {
    _byId = {};
    _bumpIfChanged('');
  }

  static void _bumpIfChanged(String next) {
    if (next == _fingerprint) return;
    _fingerprint = next;
    revision.value++;
  }

  /// Everything a surface would rebuild for.
  ///
  /// The source, because that is what a reload compiles; the manifest, because
  /// it decides what is contributed and where; and the grants, because a
  /// permission the user has just withdrawn has to reach a running instance.
  /// Config is not here — it is stored per server and read when a surface is
  /// built, not part of what the registry publishes.
  ///
  /// Hashed rather than compared field by field: the set is small, this runs
  /// once per refresh, and a field added to `InstalledPlugin` that nobody
  /// remembers to add to a comparison is how this stops working quietly.
  static String _fingerprintOf(Iterable<InstalledPlugin> plugins) {
    final parts = [
      for (final p in plugins)
        '${p.id}|${p.record.version}|${p.record.enabled}|'
            '${p.granted.toList()..sort()}|'
            '${p.manifestJson.hashCode}|${p.source.hashCode}',
    ]..sort();
    return parts.join(';');
  }

  static Iterable<InstalledPlugin> get active => _byId.values;

  static InstalledPlugin? byId(String id) => _byId[id];

  /// The plugin behind a contribution id, which is `<plugin id>:<its id>`.
  static InstalledPlugin? ofFeature(String featureId) {
    final at = featureId.lastIndexOf(':');
    return at <= 0 ? null : _byId[featureId.substring(0, at)];
  }

  /// What they add to [slot].
  static List<Feature> of(FeatureSlot slot) => switch (slot) {
    FeatureSlot.detailCard => [
      for (final plugin in _byId.values) ...[
        ?plugin.statusFeature,
        ?plugin.cardFeature,
      ],
    ],
    FeatureSlot.funcBtn => [for (final plugin in _byId.values) ?plugin.pageFeature],
    FeatureSlot.homeTab => [
      for (final plugin in _byId.values) ?plugin.tabFeature,
    ],
  };

  /// Everything [plugin] contributes, whatever slot it goes in.
  ///
  /// A [Feature] rather than an id, because where it goes is part of the
  /// answer: adding a status contribution's id to the function bar as well
  /// would put it in a row that has nothing to draw for it.
  static List<Feature> featuresOf(InstalledPlugin plugin) => [
    ?plugin.statusFeature,
    ?plugin.cardFeature,
    ?plugin.pageFeature,
    ?plugin.tabFeature,
  ];

  /// What a *first* install should be given a place for.
  ///
  /// `default_on` replaces `introducedAfterBuild` for a plugin: a bundled one
  /// is installed by the release that carries it, which is the same moment
  /// the boundary would have named. An update adds nothing — an entry the
  /// user has since taken out was a decision.
  static List<Feature> defaultOnOf(InstalledPlugin plugin) => [
    if (plugin.manifest.status?.defaultOn == true) ?plugin.statusFeature,
    if (plugin.manifest.card?.defaultOn == true) ?plugin.cardFeature,
    if (plugin.manifest.page?.defaultOn == true) ?plugin.pageFeature,
    // Deliberately not `tabFeature`. The home bar fits four labels on a phone,
    // so putting one there is taking a place from a tab the user chose — see
    // `AppTab.feature`, which is why no built-in tab has a `since` either. A
    // plugin's tab is reachable behind "more" and in the arranging page from
    // the moment it is installed.
  ];
}
