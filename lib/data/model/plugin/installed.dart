import 'package:flutter/material.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

/// A plugin the app has, ready to be loaded. PLUGINS.md section 7.
///
/// The record plus what was unpacked from the package: read once at launch,
/// so opening a surface does not read files.
class InstalledPlugin {
  const InstalledPlugin({
    required this.record,
    required this.manifestJson,
    required this.manifest,
    required this.source,
    required this.l10n,
  });

  final PluginInstall record;

  /// Verbatim, because loading passes it back to the one parser.
  final String manifestJson;

  final ffi.PluginManifestInfo manifest;
  final String source;

  /// Locale to its strings.
  final Map<String, Map<String, String>> l10n;

  String get id => record.id;

  /// What it may actually do: what the manifest asks for, intersected with
  /// what the user agreed to.
  ///
  /// The intersection is the runtime's, and this is the same rule stated where
  /// the app needs it — an update that adds a permission must not be able to
  /// use it before the user has seen it (PLUGINS.md 6.2).
  List<String> get granted => [
    for (final name in manifest.permissions)
      if (record.granted.contains(name)) name,
  ];

  /// Whether the manifest asks for anything the user has not agreed to.
  ///
  /// What the settings page shows as "this update wants more".
  bool get needsConsent =>
      manifest.permissions.any((p) => !record.granted.contains(p));

  PluginL10n l10nFor(String locale) => PluginL10n(
    active:
        l10n[locale] ?? l10n[locale.split(RegExp('[-_]')).first] ?? const {},
    fallback: l10n['en'] ?? const {},
  );

  /// What this plugin contributes to the status page, or null.
  Feature? get statusFeature {
    final status = manifest.status;
    if (status == null) return null;
    return Feature(
      // `<plugin id>:<contribution id>`, which is what keeps two plugins from
      // colliding and what an arrangement stores.
      id: '$id:${status.id}',
      slot: FeatureSlot.detailCard,
      icon: Icons.extension_outlined,
      label: () => status.label,
    );
  }
}
