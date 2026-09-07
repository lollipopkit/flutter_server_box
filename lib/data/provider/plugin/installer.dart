import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

/// Putting a plugin on the device and taking it off again.
///
/// PLUGINS.md section 7. Three things move together and one of them is on the
/// filesystem, so the order matters: the files first, then the record, then
/// the place in whatever the user arranged. A crash between the first two
/// leaves a directory nothing points at, which the next install overwrites —
/// the other order leaves a record naming files that are not there, which is
/// a plugin that fails to load on every launch.
class PluginInstaller {
  PluginInstaller({
    required this.root,
    PluginInstallStore? store,
  }) : _store = store ?? PluginInstallStore.instance;

  /// Where unpacked plugins live: one directory per id under this.
  final Directory root;

  final PluginInstallStore _store;

  /// The app's own, under the data directory rather than the cache: a plugin
  /// removed by a cache sweep is a record naming files that are gone.
  static Directory get appRoot =>
      Directory(Paths.doc.joinPath('plugins'));

  Directory dirOf(String id) => Directory(root.path.joinPath(id));

  /// Reads a package, checks it, and installs it.
  ///
  /// [consented] is what the user agreed to in the install dialog, and is
  /// intersected with what the manifest asks for. **Never the manifest's own
  /// list**: an update that adds a permission must not be able to use it
  /// before the user has seen it (section 6.2).
  ///
  /// [repo] is null for a plugin bundled with the app and
  /// [PluginInstall.devRepo] for a directory on a developer's machine.
  ///
  /// Throws [PluginPackageError] for a package that cannot be read, and
  /// whatever `plugin_read_manifest` throws for a manifest this build refuses
  /// — an ABI it does not implement, a permission it has no name for.
  Future<InstalledPlugin> install(
    List<int> bytes, {
    required Set<String> consented,
    String? repo,
  }) async {
    final package = PluginPackage.read(bytes);
    // The one parser. It also refuses an ABI this build does not implement,
    // which is the check that keeps a newer plugin from half-working.
    final manifest = ffi.pluginReadManifest(manifestJson: package.manifestJson);

    final dir = dirOf(manifest.id);
    final staging = Directory('${dir.path}.new');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    await File(staging.path.joinPath(PluginPackage.manifestName))
        .writeAsString(package.manifestJson);
    await File(staging.path.joinPath(PluginPackage.sourceName))
        .writeAsString(package.source);
    for (final e in package.l10n.entries) {
      final file = File(
        staging.path.joinPath('${PluginPackage.l10nDir}${e.key}.json'),
      );
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(e.value));
    }
    final icon = package.icon;
    if (icon != null) {
      await File(staging.path.joinPath(PluginPackage.iconName))
          .writeAsBytes(icon);
    }

    // Replaced rather than written over: an update that failed halfway would
    // otherwise leave one version's manifest beside another's script.
    if (await dir.exists()) await dir.delete(recursive: true);
    await staging.rename(dir.path);

    final existing = _store.fetch(manifest.id);
    final record = PluginInstall(
      id: manifest.id,
      version: manifest.version,
      repo: repo,
      // An update does not switch a plugin the user turned off back on.
      enabled: existing?.enabled ?? true,
      granted: {
        for (final name in manifest.permissions)
          if (consented.contains(name)) name,
      },
      installedAt: DateTime.now(),
    );
    _store.put(record);

    final plugin = InstalledPlugin(
      record: record,
      manifestJson: package.manifestJson,
      manifest: manifest,
      source: package.source,
      l10n: package.l10n,
    );

    // Only on a first install. An update must not put back an entry the user
    // has since taken out of their arrangement — the same rule as
    // `Features.autoAdd`, and the reason `default_on` replaces
    // `introducedAfterBuild` for a plugin.
    if (existing == null) _addDefaultOn(plugin);
    await refresh();
    return plugin;
  }

  /// Removes the files, the record, and the place in the arrangement.
  ///
  /// [keepData] is the user's choice: a plugin removed to be reinstalled — an
  /// update that went wrong, a repository being switched — should not take the
  /// configuration typed into every server with it.
  Future<void> uninstall(String id, {bool keepData = false}) async {
    final plugin = PluginContributions.byId(id);
    if (plugin != null) _removeFeatures(PluginContributions.featuresOf(plugin));
    _store.remove(id, keepData: keepData);
    final dir = dirOf(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    await refresh();
  }

  /// Turns one on or off without removing anything.
  Future<void> setEnabled(String id, bool enabled) async {
    _store.setEnabled(id, enabled);
    await refresh();
  }

  /// Reads every installed plugin and publishes what they contribute.
  ///
  /// Once at launch and after every change. A record whose files will not read
  /// is skipped rather than fatal: the rest of the app has no stake in one
  /// plugin's directory, and a launch that failed on it would be an app that
  /// cannot start because of something the user installed.
  Future<List<InstalledPlugin>> refresh() async {
    final plugins = <InstalledPlugin>[];
    for (final record in _store.readAll()) {
      try {
        final plugin = await _read(record);
        if (plugin != null) plugins.add(plugin);
      } catch (e, s) {
        Loggers.app.warning('Reading plugin ${record.id}', e, s);
      }
    }
    PluginContributions.publish(plugins);
    return plugins;
  }

  Future<InstalledPlugin?> _read(PluginInstall record) async {
    final dir = dirOf(record.id);
    final manifestFile = File(dir.path.joinPath(PluginPackage.manifestName));
    final sourceFile = File(dir.path.joinPath(PluginPackage.sourceName));
    if (!await manifestFile.exists() || !await sourceFile.exists()) {
      Loggers.app.warning('Plugin ${record.id} has a record but no files');
      return null;
    }
    final manifestJson = await manifestFile.readAsString();
    final l10n = <String, Map<String, String>>{};
    final l10nDir = Directory(dir.path.joinPath('l10n'));
    if (await l10nDir.exists()) {
      await for (final entity in l10nDir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        final locale = name.substring(0, name.length - '.json'.length);
        l10n[locale] = _parseL10n(await entity.readAsString());
      }
    }
    return InstalledPlugin(
      record: record,
      manifestJson: manifestJson,
      manifest: ffi.pluginReadManifest(manifestJson: manifestJson),
      source: await sourceFile.readAsString(),
      l10n: l10n,
    );
  }

  static Map<String, String> _parseL10n(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Each contribution goes in its own slot, and only its own: an id in a row
  /// that has nothing to draw for it is a gap the user cannot explain.
  void _addDefaultOn(InstalledPlugin plugin) {
    for (final feature in PluginContributions.defaultOnOf(plugin)) {
      final stored = feature.slot.enabledIds();
      if (stored.contains(feature.id)) continue;
      feature.slot.putEnabledIds([...stored, feature.id]);
    }
  }

  void _removeFeatures(List<Feature> features) {
    for (final feature in features) {
      final stored = feature.slot.enabledIds();
      final kept = [
        for (final id in stored)
          if (id != feature.id) id,
      ];
      if (kept.length != stored.length) feature.slot.putEnabledIds(kept);
    }
  }
}
