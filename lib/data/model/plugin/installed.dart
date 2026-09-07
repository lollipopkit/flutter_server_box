import 'package:flutter/material.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/server/capabilities.dart';
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
    return _feature(status.id, status.label);
  }

  /// The card it draws on the server detail page, or null.
  ///
  /// A separate contribution from [statusFeature] and a different thing: this
  /// one has a surface — the plugin holds state, answers events and is ticked
  /// while it is on screen — where a status contribution only says what to run
  /// and reads the output.
  Feature? get cardFeature {
    final card = manifest.card;
    if (card == null) return null;
    return _feature(card.id, card.label);
  }

  /// The button it puts in the server function bar, or null.
  ///
  /// `needs` is the app's own `availableWith` switch moved into data: a button
  /// the connection cannot serve opens a page that can never load, and which
  /// of those a transport meets is the app's answer rather than the plugin's.
  /// A name this build has none for is ignored rather than refusing the
  /// button — a newer plugin naming a capability that does not exist yet
  /// should show up, not disappear.
  Feature? get pageFeature {
    final page = manifest.page;
    if (page == null) return null;
    final needs = [
      for (final name in page.needs) ?_capabilityOf(name),
    ];
    return Feature(
      id: '$id:${page.id}',
      slot: FeatureSlot.funcBtn,
      icon: Icons.extension_outlined,
      label: () => page.label,
      needs: needs.isEmpty
          ? null
          : (caps) => needs.every((test) => test(caps)),
    );
  }

  static bool Function(ServerCapabilities)? _capabilityOf(String name) =>
      switch (name) {
        'shell' => (caps) => caps.shell,
        'terminal' => (caps) => caps.terminal,
        'files' => (caps) => caps.files,
        'byte_stream' => (caps) => caps.byteStream,
        'stored_history' => (caps) => caps.storedHistory,
        'persistent_session' => (caps) => caps.persistentSession,
        _ => null,
      };

  /// Whether [featureId] is this plugin's card rather than its status
  /// contribution, which is what decides how it is drawn.
  bool isCard(String featureId) =>
      manifest.card != null && featureId == '$id:${manifest.card!.id}';

  /// Whether [featureId] is this plugin's function-bar button.
  bool isPage(String featureId) =>
      manifest.page != null && featureId == '$id:${manifest.page!.id}';

  Feature _feature(String contributionId, String label) => Feature(
    // `<plugin id>:<contribution id>`, which is what keeps two plugins from
    // colliding and what an arrangement stores.
    id: '$id:$contributionId',
    slot: FeatureSlot.detailCard,
    icon: Icons.extension_outlined,
    label: () => label,
  );
}
