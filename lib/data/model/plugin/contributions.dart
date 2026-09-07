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

  /// Replaces what plugins contribute, after an install, an uninstall, or the
  /// pass at launch that reads them.
  static void publish(Iterable<InstalledPlugin> plugins) {
    _byId = {
      for (final plugin in plugins)
        if (plugin.record.enabled) plugin.id: plugin,
    };
  }

  static void clear() => _byId = {};

  static Iterable<InstalledPlugin> get active => _byId.values;

  static InstalledPlugin? byId(String id) => _byId[id];

  /// The plugin behind a contribution id, which is `<plugin id>:<its id>`.
  static InstalledPlugin? ofFeature(String featureId) {
    final at = featureId.lastIndexOf(':');
    return at <= 0 ? null : _byId[featureId.substring(0, at)];
  }

  /// What they add to [slot].
  static List<Feature> of(FeatureSlot slot) {
    if (slot != FeatureSlot.detailCard) return const [];
    return [
      for (final plugin in _byId.values) ...[
        ?plugin.statusFeature,
        ?plugin.cardFeature,
      ],
    ];
  }

  /// Everything [plugin] contributes, whatever slot it goes in.
  ///
  /// A [Feature] rather than an id, because where it goes is part of the
  /// answer: adding a status contribution's id to the function bar as well
  /// would put it in a row that has nothing to draw for it.
  static List<Feature> featuresOf(InstalledPlugin plugin) => [
    ?plugin.statusFeature,
    ?plugin.cardFeature,
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
  ];
}
