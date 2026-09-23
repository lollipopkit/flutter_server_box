import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

/// What going back to the version before would give.
///
/// Answered by [PluginInstaller.rollbackOf], and the two fields are separate
/// on purpose: whether there *is* one, and whether taking it is safe for the
/// data the installed version has been writing.
class PluginRollback {
  const PluginRollback({
    required this.id,
    required this.from,
    required this.to,
    required this.dataCompatible,
  });

  final String id;

  /// The installed version, which going back would replace.
  final String from;

  /// The version that was kept.
  final String to;

  /// Whether the kept version declares the same `data_version`.
  ///
  /// **False is a warning, not a refusal.** A version that raised it started
  /// writing something the version before cannot read, so the old code would
  /// misread its own records — silently, since nothing checks a shape it has
  /// never heard of. Whether that is worse than the update being broken is the
  /// user's call, and only they know which one they are looking at.
  final bool dataCompatible;
}

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

  /// Where the version an update replaced is kept.
  ///
  /// Beside the installed copy rather than inside it, so nothing that walks a
  /// plugin's own directory — the asset lookup, the l10n reader — can wander
  /// into the version before. Suffixes rather than a directory of their own for
  /// the same reason [repair] can work: a name says what a directory is, so a
  /// crash leaves state that reads.
  Directory prevDirOf(String id) => Directory('${dirOf(id).path}.prev');

  /// Where a package is unpacked before it replaces anything.
  Directory _stagingOf(String id) => Directory('${dirOf(id).path}.new');

  /// Reads a package, checks it, and installs it.
  ///
  /// [consented] is what the user agreed to in the install dialog, and is
  /// intersected with what the manifest asks for. **Never the manifest's own
  /// list**: an update that adds a permission must not be able to use it
  /// before the user has seen it (section 6.2).
  ///
  /// [repo] is where it came from: a repository's address,
  /// [PluginInstall.fileRepo] for a `.sbp` the user opened, or
  /// [PluginInstall.devRepo] for a directory on a developer's machine. It is
  /// what decides who may replace this copy later, so a caller that leaves it
  /// out is saying the plugin came from a file.
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
    final staging = _stagingOf(manifest.id);
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
    for (final e in package.assets.entries) {
      final file = File(
        staging.path.joinPath('${PluginPackage.assetDir}${e.key}'),
      );
      await file.create(recursive: true);
      await file.writeAsBytes(e.value);
    }

    final existing = _store.fetch(manifest.id);

    // Replaced rather than written over: an update that failed halfway would
    // otherwise leave one version's manifest beside another's script.
    //
    // **Moved aside rather than deleted.** An update that turns out to be
    // broken used to leave nothing to go back to — the files were gone, and
    // recovering meant finding a `.sbp` for the old version. The previous
    // version now stays under `<id>.prev` and [rollback] puts it back.
    //
    // Two renames with a window between them, which [repair] closes: a crash
    // there leaves `<id>.prev` and no `<id>`, and the next launch moves it
    // back.
    final prev = prevDirOf(manifest.id);
    final replacing = await dir.exists();
    if (replacing) {
      // One level, never a chain: the copy from two updates ago is a version
      // nobody asked to go back to and a directory that would only grow.
      if (await prev.exists()) await prev.delete(recursive: true);
      await dir.rename(prev.path);
    } else if (await prev.exists()) {
      // A first install for an id that has a leftover — an uninstall that
      // failed to clean up, or a package installed over a removed plugin. It
      // names a version this record has no memory of, so nothing could offer
      // it back.
      await prev.delete(recursive: true);
    }
    await staging.rename(dir.path);

    // Installing a package for an id that is also a development directory is a
    // request for the package. The registration goes, or the record would say
    // one thing — this version, from this repository — while `refresh` kept
    // loading the directory: which is how a store install of 1.0.1 ended up
    // running a working tree's 1.1.0, with nothing on screen able to say so.
    if (Stores.setting.pluginDevDirs.fetch().isNotEmpty) {
      await _forgetDevDirsOf(manifest.id, because: 'installed from a package');
    }

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
      // The record that went with the files now under `<id>.prev`, and only
      // when there are any. It carries `granted`, which the directory cannot:
      // that is what the user *agreed to*, and re-deriving it from the old
      // manifest would grant whatever that version asked for.
      //
      // A development registration is not a version to go back to — the files
      // are the developer's own, sitting where they wrote them — so a record
      // marked `dev` is dropped rather than kept.
      previous: replacing && existing != null && !existing.isDev
          // Its own `previous` is left behind, or a chain would build up
          // through repeated updates.
          ? existing.copyWith(clearPrevious: true)
          : null,
    );
    _store.put(record);

    final plugin = InstalledPlugin(
      record: record,
      manifestJson: package.manifestJson,
      manifest: manifest,
      source: package.source,
      l10n: package.l10n,
      dir: dir.path,
    );

    // Only on a first install. An update must not put back an entry the user
    // has since taken out of their arrangement — the same rule as
    // `Features.autoAdd`, and the reason `default_on` replaces
    // `introducedAfterBuild` for a plugin.
    if (existing == null) _addDefaultOn(plugin);
    await refresh();
    return plugin;
  }

  /// What going back would give, or null when there is nothing to go back to.
  ///
  /// Both halves have to hold: the files of the previous version are still
  /// there, **and** the record that went with them is readable. Either alone
  /// is not a rollback — files without the record would mean guessing what the
  /// user had consented to, and a record without files names nothing.
  Future<PluginRollback?> rollbackOf(String id) async {
    final record = _store.fetch(id);
    final previous = record?.previous;
    if (record == null || previous == null) return null;
    final dir = prevDirOf(id);
    if (!await dir.exists()) return null;

    // Read rather than trusted: the manifest under `<id>.prev` is the code
    // that would run, and `data_version` is the one thing it can say about
    // whether it can read what the installed version has been writing.
    int? previousData;
    try {
      final manifestFile = File(dir.path.joinPath(PluginPackage.manifestName));
      if (await manifestFile.exists()) {
        previousData = ffi
            .pluginReadManifest(manifestJson: await manifestFile.readAsString())
            .dataVersion;
      }
    } catch (e, s) {
      // An old manifest this build refuses — an ABI it does not implement, a
      // permission it has no name for. Going back to it would not load, so
      // there is nothing to offer.
      Loggers.app.warning('Reading the kept version of $id', e, s);
      return null;
    }
    if (previousData == null) return null;

    int? installedData;
    try {
      installedData = PluginContributions.byId(id)?.manifest.dataVersion;
      installedData ??= ffi
          .pluginReadManifest(
            manifestJson: await File(
              dirOf(id).path.joinPath(PluginPackage.manifestName),
            ).readAsString(),
          )
          .dataVersion;
    } catch (_) {
      installedData = null;
    }

    return PluginRollback(
      id: id,
      from: record.version,
      to: previous.version,
      // **The stored data is the reason this can be refused.** A version that
      // raised `data_version` started writing something the version before it
      // cannot read, so putting the old code back would hand it records it
      // will misread — silently, since nothing checks a shape it has never
      // heard of. Unknown counts as a mismatch: the safe answer to "can that
      // code read this" is no.
      dataCompatible: installedData != null && installedData == previousData,
    );
  }

  /// Puts the version an update replaced back.
  ///
  /// The reverse of the two renames in [install], with the same window and the
  /// same repair: the installed copy moves aside, the kept one moves in, and
  /// the record goes back to what it was.
  ///
  /// **One level.** After this there is nothing kept, because what was kept is
  /// now what is installed — so a plugin cannot be walked backwards through
  /// its history, and the next update starts the pair again.
  ///
  /// Throws [StateError] when there is nothing to go back to, which a caller
  /// that asked [rollbackOf] first cannot hit.
  Future<InstalledPlugin?> rollback(String id) async {
    final record = _store.fetch(id);
    final previous = record?.previous;
    final prev = prevDirOf(id);
    if (record == null || previous == null || !await prev.exists()) {
      throw StateError('nothing was kept for $id');
    }

    final dir = dirOf(id);
    final discarded = _stagingOf(id);
    if (await discarded.exists()) await discarded.delete(recursive: true);
    // Out of the way first, and under the staging name: a crash here leaves
    // `<id>.new` and no `<id>`, which [repair] reads the same way it reads an
    // install that died at the same point — put the kept copy back.
    if (await dir.exists()) await dir.rename(discarded.path);
    await prev.rename(dir.path);
    if (await discarded.exists()) await discarded.delete(recursive: true);

    // `enabled` is the user's switch and belongs to now rather than to the
    // record being restored; everything else — the version, where it came
    // from, and what was consented to — is what went with these files.
    _store.put(
      previous.copyWith(enabled: record.enabled, clearPrevious: true),
    );
    Loggers.app.info('Plugin $id rolled back to ${previous.version}');
    final plugins = await refresh();
    return plugins.firstWhereOrNull((p) => p.id == id);
  }

  /// Finishes or undoes an install that a crash interrupted.
  ///
  /// Two renames stand between "the old version is installed" and "the new one
  /// is": a process that died between them left `<id>.prev` and no `<id>`, and
  /// every launch after that read a record naming files that are not there.
  ///
  /// Called at the start of [refresh], which is what runs before anything asks
  /// what is installed. Cheap: one directory listing, and nothing to do in the
  /// ordinary case.
  Future<void> repair() async {
    if (!await root.exists()) return;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;

      // Unpacked and never moved into place. The install that wrote it did not
      // finish, so nothing points at it and the next install overwrites it —
      // but it is a whole copy of a package, so leaving it costs disk for as
      // long as the plugin is installed.
      //
      // `<id>.new` is also where [rollback] parks the copy it is discarding,
      // and both mean the same thing here: not the installed version.
      if (name.endsWith('.new')) {
        final id = name.substring(0, name.length - '.new'.length);
        if (await dirOf(id).exists()) {
          await entity.delete(recursive: true);
          continue;
        }
        // No installed copy at all: this is a rollback that died between its
        // two renames, and `<id>.prev` holds the version being restored. The
        // branch below puts it back; this one only clears the way.
        await entity.delete(recursive: true);
        continue;
      }

      if (!name.endsWith('.prev')) continue;
      final id = name.substring(0, name.length - '.prev'.length);
      if (await dirOf(id).exists()) continue;
      // An install or a rollback that died between the two renames. The kept
      // copy is the only one there is, so it becomes the installed one.
      await entity.rename(dirOf(id).path);
      Loggers.app.warning(
        'Plugin $id: an interrupted install left no installed copy; '
        'the version that was kept has been put back',
      );
      // The record still describes the version that was being installed and
      // is now not there. Put back the one that goes with these files, where
      // there is one.
      final record = _store.fetch(id);
      final previous = record?.previous;
      if (record != null && previous != null) {
        _store.put(
          previous.copyWith(enabled: record.enabled, clearPrevious: true),
        );
      }
    }
  }

  /// Adds an unpacked directory as a plugin. PLUGINS.md section 8.2.
  ///
  /// **The directory is not copied.** It is remembered and re-read on every
  /// refresh, so editing `plugin.js` and restarting the app is the whole
  /// development cycle — an installed copy would mean repackaging to see a
  /// one-line change.
  ///
  /// Which is also why there is no signature and no repository: the files are
  /// the developer's own, sitting where they wrote them. It is desktop-only
  /// for the same reason — a phone has no directory a developer edits in.
  ///
  /// Throws [PluginPackageError] if the directory is not a plugin, and
  /// whatever `plugin_read_manifest` throws for a manifest this build refuses.
  Future<InstalledPlugin> addDevDir(
    String path, {
    required Set<String> consented,
  }) async {
    final plugin = await readDevDir(path);
    if (plugin == null) {
      throw const PluginPackageError('no manifest.json and plugin.js there');
    }

    final existing = _store.fetch(plugin.id);
    final record = PluginInstall(
      id: plugin.id,
      version: plugin.manifest.version,
      repo: PluginInstall.devRepo,
      enabled: existing?.enabled ?? true,
      granted: {
        for (final name in plugin.manifest.permissions)
          if (consented.contains(name)) name,
      },
      installedAt: DateTime.now(),
    );
    _store.put(record);

    final dirs = Stores.setting.pluginDevDirs.fetch();
    if (!dirs.contains(path)) {
      Stores.setting.pluginDevDirs.put([...dirs, path]);
    }

    final withRecord = plugin.copyWith(record: record);
    if (existing == null) _addDefaultOn(withRecord);
    await refresh();
    return withRecord;
  }

  /// Forgets a development directory without touching what is in it.
  ///
  /// The record goes with it — a `dev` record whose directory is no longer
  /// listed names nothing, and would be a row that cannot load on every
  /// launch.
  Future<void> removeDevDir(String path) async {
    final plugin = await readDevDir(path);
    Stores.setting.pluginDevDirs.put([
      for (final p in Stores.setting.pluginDevDirs.fetch())
        if (p != path) p,
    ]);
    if (plugin != null) await uninstall(plugin.id);
    await refresh();
  }

  /// Every development directory that currently reads as a plugin, by id.
  Future<Map<String, String>> devDirs() async {
    final byId = <String, String>{};
    for (final path in Stores.setting.pluginDevDirs.fetch()) {
      try {
        final plugin = await readDevDir(path);
        if (plugin != null) byId[plugin.id] = path;
      } catch (_) {}
    }
    return byId;
  }

  /// Reads a directory laid out like an unpacked package, or null.
  ///
  /// Null for "not a plugin directory"; a manifest this build refuses still
  /// throws, since that is a plugin the developer needs told about rather than
  /// a directory to skip.
  Future<InstalledPlugin?> readDevDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return null;
    return _readFrom(
      dir,
      // A placeholder until the manifest says what the id is. Nothing reads it
      // — `_readFrom` replaces the record with the stored one, or the caller
      // writes a real one.
      PluginInstall(
        id: '',
        version: '',
        repo: PluginInstall.devRepo,
        granted: const {},
        installedAt: DateTime.now(),
      ),
    );
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
    // Only under the app's own root, never a development directory: those are
    // the developer's files, sitting where they wrote them, and removing a
    // plugin from the app is not a request to delete a working tree.
    for (final dir in [dirOf(id), prevDirOf(id), _stagingOf(id)]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    await _forgetDevDirsOf(id);
    await refresh();
  }

  /// Drops any development directory holding [id], leaving its files alone.
  ///
  /// A listed path whose plugin has been removed would be loaded again on the
  /// next launch, which is an uninstall that does not stick.
  ///
  /// [because] is logged when there is something to forget: dropping a
  /// developer's registration is invisible otherwise, and the next edit to that
  /// directory changing nothing is the confusing part.
  Future<void> _forgetDevDirsOf(String id, {String? because}) async {
    final dirs = Stores.setting.pluginDevDirs.fetch();
    final kept = <String>[];
    for (final path in dirs) {
      try {
        if ((await readDevDir(path))?.id == id) continue;
      } catch (_) {
        // Unreadable: kept, since it cannot be shown to be this one.
      }
      kept.add(path);
    }
    if (kept.length == dirs.length) return;
    Stores.setting.pluginDevDirs.put(kept);
    if (because != null) {
      Loggers.app.info('Plugin $id: development directory dropped, $because');
    }
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
    // Before anything is read: an install a crash interrupted leaves a record
    // naming files that are not there, and every launch after that skips the
    // plugin without ever saying what happened.
    try {
      await repair();
    } catch (e, s) {
      // A directory that will not move is not a reason to refuse to list what
      // is installed. What it costs is one plugin, which is what the loop
      // below already tolerates.
      Loggers.app.warning('Repairing the plugin directory', e, s);
    }

    // Read first, so a record marked `dev` is served from the developer's own
    // directory rather than from a copy under the app — which is what makes an
    // edit visible on the next launch.
    //
    // **Only a record marked `dev`.** A directory used to win for any id it
    // named, so installing a package for a plugin somebody had also registered
    // as a directory wrote a record naming a version and a repository, and then
    // kept running the directory. The record is the answer to "what is
    // installed", and `addDevDir` writes one saying `dev`.
    final dev = <String, Directory>{};
    for (final path in Stores.setting.pluginDevDirs.fetch()) {
      try {
        final plugin = await readDevDir(path);
        if (plugin != null) dev[plugin.id] = Directory(path);
      } catch (e, s) {
        Loggers.app.warning('Reading the plugin directory $path', e, s);
      }
    }

    final plugins = <InstalledPlugin>[];
    for (final record in _store.readAll()) {
      try {
        final plugin = await _readFrom(
          (record.isDev ? dev[record.id] : null) ?? dirOf(record.id),
          record,
        );
        if (plugin != null) plugins.add(plugin);
      } catch (e, s) {
        Loggers.app.warning('Reading plugin ${record.id}', e, s);
      }
    }
    PluginContributions.publish(plugins);
    return plugins;
  }

  Future<InstalledPlugin?> _readFrom(Directory dir, PluginInstall record) async {
    final manifestFile = File(dir.path.joinPath(PluginPackage.manifestName));
    final sourceFile = File(dir.path.joinPath(PluginPackage.sourceName));
    if (!await manifestFile.exists() || !await sourceFile.exists()) {
      if (record.id.isNotEmpty) {
        Loggers.app.warning('Plugin ${record.id} has a record but no files');
      }
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
    final manifest = ffi.pluginReadManifest(manifestJson: manifestJson);
    _warnAboutMissingL10n(dir, manifestJson, l10n);
    return InstalledPlugin(
      dir: dir.path,
      // A development directory is read before its id is known, so the record
      // handed in may be the placeholder. The manifest is what says which
      // plugin this is either way — and for a development directory it says
      // which *version*, too: those files are edited in place, so a version
      // frozen at the moment the directory was added is a number nothing on
      // disk agrees with.
      record: record.id.isEmpty
          ? record.copyWith(id: manifest.id, version: manifest.version)
          : (record.isDev && record.version != manifest.version
                ? record.copyWith(version: manifest.version)
                : record),
      manifestJson: manifestJson,
      manifest: manifest,
      source: await sourceFile.readAsString(),
      l10n: l10n,
    );
  }

  /// Says when a plugin promised translations its directory does not have.
  ///
  /// Silence here is what a missing translation looks like from the outside:
  /// every string draws as `l10n.itsKey`, which reads as a rendering bug rather
  /// than a missing file. It happened for real — the build staged the script
  /// and the manifest into `dist/` and left `l10n/` behind, so a development
  /// directory was English-only-by-accident while the packaged copy of the same
  /// plugin was translated.
  ///
  /// The manifest's own list, parsed here rather than read off
  /// `PluginManifestInfo`, which does not carry it. One decode per plugin per
  /// refresh, of a document that was just read anyway.
  static void _warnAboutMissingL10n(
    Directory dir,
    String manifestJson,
    Map<String, Map<String, String>> l10n,
  ) {
    try {
      final declared = (jsonDecode(manifestJson) as Map)['l10n'];
      if (declared is! List || declared.isEmpty) return;
      final missing = [
        for (final locale in declared)
          if (locale is String && !l10n.containsKey(locale)) locale,
      ];
      if (missing.isEmpty) return;
      Loggers.app.warning(
        'Plugin at ${dir.path} declares $missing and carries no such file; '
        'its strings will draw as their keys',
      );
    } catch (_) {
      // The manifest is the host parser's business, and it has already read it.
    }
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
