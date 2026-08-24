import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/setting.dart';

/// Raised when the stored data was written by a newer build than this one.
///
/// The only safe response is to stop: this build cannot know what a future
/// schema means, and writing to it would destroy whatever it doesn't
/// understand. Refusing is what makes a downgrade recoverable — the user can
/// reinstall the newer build and their data is still intact.
class SchemaTooNewException implements Exception {
  const SchemaTooNewException({required this.stored, required this.supported});

  /// Version found in the data
  final int stored;

  /// Highest version this build can read
  final int supported;

  @override
  String toString() =>
      'Data was written by a newer version of the app '
      '(schema v$stored, this build supports up to v$supported). '
      'Upgrade the app to read it.';
}

/// One forward-only step between two adjacent schema versions.
///
/// Migrations exist so the model classes only ever describe the *current*
/// shape. Without them, every format change leaves a permanent branch behind
/// in `fromJson` — `Spi.jumpId` has carried a "kept for compatibility" comment
/// alongside `jumpIds` for exactly that reason, with no way to tell when it
/// became safe to delete. A migration, by contrast, has a version it belongs
/// to and a version after which it can be removed.
abstract interface class SchemaMigration {
  /// Applies to data stored at this version, producing [from] + 1
  int get from;

  /// Rewrites the local Hive stores in place. Must be safe to run on data that
  /// is already partially migrated: a crash mid-way leaves the version
  /// unchanged, so the step runs again on the next launch.
  Future<void> apply();
}

/// Version of the app's *local storage* layout.
///
/// Distinct from `BuildData.build` (which gates one-off feature toggles via
/// `Stores.setting.lastVer`) and from a backup file's envelope version, though
/// the backup envelope carries this same number so a file can be checked
/// against the reader's capability.
abstract final class SchemaVersion {
  /// v2: everything up to and including `monitorHttp` on Spi — the last
  ///     layout written before versioning existed, hence the starting point
  ///     rather than v1
  /// v3: Spi's flat SSH fields nested under `ssh`
  /// v4: Hive boxes replaced by one encrypted SQLite database
  ///
  /// There is no migration registered for v2 -> v3 or v3 -> v4. Both are done
  /// by `HiveImport`, which is the only code that reads a Hive box and so the
  /// only place a pre-v3 record can be decoded at all; it records [current]
  /// when it finishes. Every install therefore reaches SQLite already at v4,
  /// and [migrate] has nothing to do until a v5 exists.
  /// v5: entities out of `kv` and into tables with columns, foreign keys
  ///     and per-row sync metadata
  /// v6: per-monitor explicit permission for plaintext HTTP on trusted networks
  /// v7: the BMC side channel's columns on `server`
  /// v8: `private_key.comment`, so a key's label can be edited without
  ///     opening the key to rewrite the copy inside it
  /// v9: the two settings fixups that gated themselves on their own
  ///     `xxxMigrated` flag key, now ordered steps like everything else
  static const current = 9;

  /// Persisted locally, never included in a backup: it describes *this
  /// device's* storage, and restoring another device's number would make the
  /// migrator skip or repeat steps.
  static int get stored => SettingStore.instance.schemaVersion.fetch();

  static void _store(int v) => SettingStore.instance.schemaVersion.put(v);

  /// Brings local storage up to [current], one ordered step at a time.
  ///
  /// Throws [SchemaTooNewException] when the stored version is ahead of this
  /// build. Callers must treat that as fatal for anything that writes — see
  /// the class doc.
  static Future<void> migrate(List<SchemaMigration> migrations) async {
    final from = stored;
    if (from == current) return;
    if (from > current) {
      throw SchemaTooNewException(stored: from, supported: current);
    }

    final byFrom = {for (final m in migrations) m.from: m};
    for (var v = from; v < current; v++) {
      final step = byFrom[v];
      if (step == null) {
        // A gap means the migration list and `current` disagree; running on
        // would silently leave records in a shape nothing reads
        throw StateError('Missing schema migration from v$v to v${v + 1}');
      }
      Loggers.app.info('Schema migration v$v -> v${v + 1}');
      await step.apply();
      // Recorded per step, so an interrupted run resumes rather than restarts
      _store(v + 1);
    }
  }

  /// Marks a fresh install as already current, so its empty stores aren't put
  /// through migrations written for data that doesn't exist.
  static void initFresh() => _store(current);

  /// The layout `HiveImport` produces: entities as JSON rows in `kv`.
  ///
  /// The import is not a fresh install even though it starts from an empty
  /// database — it writes the shape that was current when Hive was dropped,
  /// which later steps still have to convert. Recording [current] instead
  /// would tell the migrator there is nothing to do and strand every record
  /// in the shape it landed in.
  ///
  /// TODO: delete with `HiveImport`, and bump this in step with it until then.
  static const hiveImportProduces = 4;

  /// Marks the layout [HiveImport] wrote, so the steps after it still run.
  static void initAtHiveImport() => _store(hiveImportProduces);
}
