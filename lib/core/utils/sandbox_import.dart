import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';

/// What [SandboxImport.run] found, so the UI can say so afterwards.
enum SandboxImportResult {
  /// Nothing to do: not the unsandboxed macOS build, this install already has
  /// data of its own, or the import already happened.
  skipped,

  /// No sandboxed install to take data from.
  notFound,

  /// macOS would not let this process read the other build's container.
  denied,

  /// The container's boxes are encrypted with a key this build cannot read, so
  /// copying them would produce data nothing can open.
  noKey,

  /// The data was copied in.
  imported,

  /// The copy failed. The next launch tries again from scratch.
  failed;

  /// Whether the user is looking at an empty app that did not have to be one.
  bool get needsExplaining =>
      this == denied || this == noKey || this == failed;
}

/// Taking over the data of the sandboxed build, once.
///
/// macOS ships two builds of this app. The App Store one must be sandboxed;
/// the DMG one is not, which is the entire difference between them and the
/// reason only one can open a terminal on this machine.
///
/// The sandbox is also a separate data directory: everything installed to date
/// — App Store, and the DMGs that were still sandboxed — keeps its data in
/// `~/Library/Containers/<bundle id>/Data/Documents`, while this build's is
/// `~/Library/Application Support/ServerBox`. Someone who switches would
/// otherwise open an app with no servers in it and no way to tell why.
///
/// So this build copies that container in, once, on the first launch that
/// finds one — before any box is opened, since it rewrites the files those
/// boxes are made of.
abstract final class SandboxImport {
  /// Shared by both builds: they are the same app, signed two ways.
  static const _bundleId = 'com.lollipopkit.toolbox';

  /// Written when the copy finished. Its presence is the whole memory of this
  /// having happened — an install that has since been used must never be
  /// overwritten by a container that has since gone stale.
  static const doneMarker = '.imported_from_sandbox';

  /// Written before the copy starts, removed after. Left behind, it says the
  /// last attempt died halfway and what is in the directory is a mixture.
  static const busyMarker = '.importing_from_sandbox';

  /// fl_lib's pre-keychain home for the box encryption key. Still read as a
  /// fallback (`_HiveEnc._encryptionKey`), so an install old enough to have it
  /// there can be taken over even if the keychain is not shared.
  static const _legacyHiveKeys = ['hive_key', 'flutter.hive_key'];

  /// The preferences worth carrying over, and how to read each one.
  ///
  /// Named one at a time rather than copied wholesale: the container's plist
  /// also holds this app's pre-Hive settings and macOS's own window state, and
  /// restoring those would be restoring the wrong thing.
  static const _prefKeys = <String, Type>{
    'bak_pwd': String,
    'ime_suggestions': bool,
    'webdav_url': String,
    'webdav_user': String,
    'webdav_pwd': String,
    'webdav_sync': bool,
    'icloud_sync': bool,
    'github_token': String,
    'gist_id': String,
    'gist_sync': bool,
    'sync_app_settings': bool,
    'last_ver': int,
  };

  static SandboxImportResult? _result;

  /// What the last [run] concluded, or null before it ran.
  static SandboxImportResult? get result => _result;

  /// The sandboxed build's container, or null off macOS. Its data is under
  /// `Documents`, and its preferences under `Library/Preferences`.
  static String? get containerData {
    final home = Pfs.homeDir;
    if (!isMacOS || home == null) return null;
    return home
        .joinPath('Library')
        .joinPath('Containers')
        .joinPath(_bundleId)
        .joinPath('Data');
  }

  /// Call after `PrefStore.shared.init()` and before any store opens a box.
  static Future<SandboxImportResult> run() async {
    if (!isMacOS || Pfs.isMacSandboxed) {
      return _result = SandboxImportResult.skipped;
    }
    final container = containerData;
    if (container == null) return _result = SandboxImportResult.skipped;

    final result = await importFrom(
      src: Directory(container.joinPath('Documents')),
      dest: Directory(Paths.doc),
      importPrefs: () => importPrefs(
        container
            .joinPath('Library')
            .joinPath('Preferences')
            .joinPath(_bundleId),
      ),
      hasKey: hasBoxKey,
    );
    Loggers.app.info('Sandbox import: ${result.name}');
    return _result = result;
  }

  /// Whether this build can decrypt what the sandboxed one wrote.
  ///
  /// The keychain item is the answer for anything recent. Both builds carry
  /// the same team and bundle id, so the data protection keychain should hand
  /// them the same item — but "should" is not a thing to copy data on, and a
  /// missing key is cheap to check and decisive: the sandboxed build cannot
  /// have written an encrypted box without writing one.
  static Future<bool> hasBoxKey() async {
    try {
      if (await SecureStoreProps.hivePwd.read() != null) return true;
    } catch (e) {
      Loggers.app.warning('Read hive key', e);
    }
    return _legacyHiveKeys.any((e) => PrefStore.shared.get<String>(e) != null);
  }

  /// The copy itself, with every outside dependency passed in so a test can
  /// run it against two temporary directories.
  @visibleForTesting
  static Future<SandboxImportResult> importFrom({
    required Directory src,
    required Directory dest,
    required Future<void> Function() importPrefs,
    required Future<bool> Function() hasKey,
  }) async {
    final destNames = await _names(dest) ?? const <String>[];
    if (destNames.contains(doneMarker)) return SandboxImportResult.skipped;
    final resuming = destNames.contains(busyMarker);
    if (!resuming && destNames.any(_isBox)) return SandboxImportResult.skipped;

    final List<String> srcNames;
    try {
      srcNames = (await src.list().toList()).map((e) => _basename(e.path)).toList();
    } on PathNotFoundException {
      return SandboxImportResult.notFound;
    } on PathAccessException {
      return SandboxImportResult.denied;
    } on FileSystemException catch (e, s) {
      // EPERM / EACCES. Since Sonoma, one app reading another's container is
      // the user's decision, and the answer may have been no.
      const refused = [1, 13];
      if (refused.contains(e.osError?.errorCode)) {
        return SandboxImportResult.denied;
      }
      Loggers.app.warning('List sandbox container', e, s);
      return SandboxImportResult.notFound;
    }

    if (!srcNames.any(_isBox)) return SandboxImportResult.notFound;

    // Before deciding whether the boxes are readable: an old enough install
    // keeps the key here, and that copy is as good as the keychain's.
    await importPrefs();

    if (srcNames.any((e) => e.endsWith('_enc.hive')) && !await hasKey()) {
      return SandboxImportResult.noKey;
    }

    try {
      await File(dest.path.joinPath(busyMarker)).writeAsString(src.path);
      if (resuming) await _clear(dest);
      _copiedBytes = 0;
      final watch = Stopwatch()..start();
      await _copyInto(src: src, dest: dest);
      Loggers.app.info(
        'Sandbox import: ${_copiedBytes ~/ 1024}KiB in ${watch.elapsedMilliseconds}ms',
      );
      await File(dest.path.joinPath(doneMarker)).writeAsString(src.path);
      await File(dest.path.joinPath(busyMarker)).delete();
      return SandboxImportResult.imported;
    } catch (e, s) {
      Loggers.app.warning('Sandbox import', e, s);
      return SandboxImportResult.failed;
    }
  }

  /// Read the named preferences out of the sandboxed build's plist.
  ///
  /// `defaults` rather than reading the file: preferences are a daemon's to
  /// own, the file is a binary plist, and it holds types (dates, data) that no
  /// converter here would keep straight. Only the keys in [_prefKeys] and the
  /// legacy box key are asked for, and only where this install has nothing of
  /// its own to lose.
  /// - [write] takes each value that survived, so a test can watch this run
  ///   against a plist of its own without writing into the preferences of the
  ///   machine it runs on. Defaults to [PrefStore.shared].
  @visibleForTesting
  static Future<void> importPrefs(
    String plistPathWithoutExt, {
    Future<void> Function(String key, Object value)? write,
  }) async {
    if (!isMacOS) return;
    if (!await File('$plistPathWithoutExt.plist').exists()) return;

    final existing = PrefStore.shared.keys(includeInternalKeys: true);
    for (final entry in {
      ..._prefKeys,
      for (final key in _legacyHiveKeys) key: String,
    }.entries) {
      final key = entry.key;
      if (existing.contains(key)) continue;
      final raw = await _defaultsRead(plistPathWithoutExt, key);
      if (raw == null) continue;
      final value = _parsePref(raw, entry.value);
      if (value == null) continue;
      if (write != null) {
        await write(key, value);
      } else {
        await PrefStore.shared.set(key, value);
      }
    }
  }

  /// Undo an import whose data turned out not to open.
  ///
  /// The container is only ever read, so nothing is lost by dropping the copy
  /// — and starting empty beats not starting. The marker stays: a second
  /// attempt would fail the same way, and the user is told to bring a backup
  /// file across instead.
  static Future<void> undo() async {
    await _clear(Directory(Paths.doc));
    _result = SandboxImportResult.failed;
  }

  @visibleForTesting
  static Object? parsePrefForTest(String raw, Type type) =>
      _parsePref(raw, type);

  static Object? _parsePref(String raw, Type type) {
    final val = raw.trim();
    return switch (type) {
      const (bool) => val == '1' || val.toLowerCase() == 'true',
      const (int) => int.tryParse(val),
      _ => val.isEmpty ? null : val,
    };
  }

  static Future<String?> _defaultsRead(String plist, String key) async {
    try {
      final res = await Process.run('defaults', ['read', plist, key]);
      if (res.exitCode != 0) return null;
      final out = res.stdout;
      return out is String ? out : null;
    } catch (e) {
      Loggers.app.warning('defaults read $key', e);
      return null;
    }
  }

  static Future<List<String>?> _names(Directory dir) async {
    try {
      return (await dir.list().toList()).map((e) => _basename(e.path)).toList();
    } catch (_) {
      return null;
    }
  }

  static bool _isBox(String name) => name.endsWith('.hive');

  static String _basename(String path) =>
      path.split(Pfs.seperator).last;

  /// Everything this app wrote into [dir], and nothing a user put there.
  static Future<void> _clear(Directory dir) async {
    final entities = await _names(dir);
    if (entities == null) return;
    for (final name in entities) {
      if (!_isBox(name) &&
          !name.endsWith('.lock') &&
          !name.startsWith('app.db')) {
        continue;
      }
      try {
        await File(dir.path.joinPath(name)).delete();
      } catch (e) {
        Loggers.app.warning('Clear $name', e);
      }
    }
  }

  /// How much the last copy moved, so a slow first launch is explicable.
  ///
  /// Everything but the cache comes across, including the directories the user
  /// downloaded into: those are their files, and leaving them behind to save
  /// time would be losing data to save time.
  static int _copiedBytes = 0;

  static Future<void> _copyInto({
    required Directory src,
    required Directory dest,
  }) async {
    await for (final entity in src.list()) {
      final name = _basename(entity.path);

      // Markers, `.DS_Store`, and whatever else is not the app's.
      if (name.startsWith('.')) continue;

      // A lock belongs to the process that holds it, not to the data.
      if (name.endsWith('.lock')) continue;

      if (entity is Directory) {
        // Rebuilt on demand, and the biggest thing in there.
        if (name == 'cache') continue;
        final child = Directory(dest.path.joinPath(name));
        await child.create(recursive: true);
        await _copyInto(src: entity, dest: child);
        continue;
      }

      if (entity is File) {
        // sqlite's shared-memory file belongs to the processes that had the
        // database open, not to the database. Carried across it describes a
        // WAL index that no longer exists, and sqlite either rebuilds it or
        // refuses — the first is wasted, the second is a broken app. It is
        // rebuilt from `app.db-wal`, which does come across.
        if (name.endsWith('.db-shm')) continue;

        await entity.copy(dest.path.joinPath(name));
        _copiedBytes += await entity.length();
      }
    }
  }
}
