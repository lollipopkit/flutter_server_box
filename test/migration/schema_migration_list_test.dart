/// The list of migrations, as a list.
///
/// `SchemaVersion.migrate` walks one version at a time and looks each step up
/// by the version it converts *from*. Two questions follow from that, and
/// neither is answered by any single migration's own test: does the list cover
/// every version between where an install can be and where this build is, and
/// does any version have two steps claiming it.
///
/// The second one is the quiet failure. Building the lookup with a
/// collection-for kept the last of two steps and dropped the other with nothing
/// said; whether anyone ever found out depended on which version the install
/// happened to be at when it launched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync/file_log.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';

import '../helpers/test_db.dart';

/// A step that does nothing, so a list can be assembled to a shape.
class _Noop extends SchemaMigration {
  const _Noop(this.from, {this.olderBuildsRead = false});

  @override
  final int from;

  @override
  final bool olderBuildsRead;

  @override
  Future<void> apply() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('covers every version from the import to the current one', () {
    // What the migrator will ask for: one step per version an install has to
    // be walked across. `hiveImportProduces` is the earliest an install can
    // be at — everything older goes through `HiveImport` first.
    final covered = {for (final m in kSchemaMigrations) m.from};
    for (
      var v = SchemaVersion.hiveImportProduces;
      v < SchemaVersion.current;
      v++
    ) {
      expect(covered, contains(v), reason: 'no step converts v$v to v${v + 1}');
    }
  });

  test('and has no step the migrator would never reach', () {
    for (final m in kSchemaMigrations) {
      expect(
        m.from,
        inInclusiveRange(
          SchemaVersion.oldestSupported,
          SchemaVersion.current - 1,
        ),
        reason: '${m.runtimeType} converts from a version nothing is at',
      );
    }
  });

  test('a reader is as old as the readable steps under a version reach', () {
    const steps = [
      _Noop(4),
      _Noop(5, olderBuildsRead: true),
      _Noop(6),
      _Noop(7, olderBuildsRead: true),
      _Noop(8, olderBuildsRead: true),
    ];
    expect(SchemaVersion.minReader(steps, 9), 7);
    expect(SchemaVersion.minReader(steps, 7), 7);
    expect(SchemaVersion.minReader(steps, 6), 5);
    expect(SchemaVersion.minReader(steps, 5), 5);
  });

  test('names each version once', () {
    final byFrom = <int, SchemaMigration>{};
    for (final m in kSchemaMigrations) {
      final clash = byFrom[m.from];
      expect(
        clash,
        isNull,
        reason: 'v${m.from}: ${clash.runtimeType} and ${m.runtimeType}',
      );
      byFrom[m.from] = m;
    }
  });

  group('and the migrator itself', () {
    setUp(() async {
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    });

    tearDown(() async {
      await getIt.reset();
      await closeTestDb();
    });

    test('refuses two steps claiming one version', () async {
      // Named before the walk starts, so it is refused whatever version this
      // install is at. Checked only where the walk crosses it, an install
      // already past that point launches and says nothing — and the step that
      // lost the collision never ran on any of the installs that needed it.
      SettingStore.instance.schemaVersion.put(SchemaVersion.current);

      expect(
        () => SchemaVersion.migrate(const [_Noop(4), _Noop(4)]),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses a version with no step, as it did before', () {
      SettingStore.instance.schemaVersion.put(SchemaVersion.hiveImportProduces);

      expect(
        () => SchemaVersion.migrate(const [
          _Noop(SchemaVersion.hiveImportProduces),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses data written by a build newer than this one', () {
      SettingStore.instance.schemaVersion.put(SchemaVersion.current + 1);

      expect(
        () => SchemaVersion.migrate(kSchemaMigrations),
        throwsA(isA<SchemaTooNewException>()),
      );
    });

    test('refuses it when the newer build names a reader above this one', () {
      SettingStore.instance.schemaVersion.put(SchemaVersion.current + 2);
      SettingStore.instance.schemaMinReader.put(SchemaVersion.current + 1);

      expect(
        () => SchemaVersion.migrate(kSchemaMigrations),
        throwsA(isA<SchemaTooNewException>()),
      );
    });

    test('opens it, unchanged and not synced, when this build is a reader', () async {
      SettingStore.instance.schemaVersion.put(SchemaVersion.current + 2);
      SettingStore.instance.schemaMinReader.put(SchemaVersion.current);

      await SchemaVersion.migrate(kSchemaMigrations);

      expect(SchemaVersion.readsAhead, isTrue);
      expect(fileLog.on(), isFalse);
      expect(SchemaVersion.stored, SchemaVersion.current + 2);
      expect(SettingStore.instance.schemaMinReader.fetch(), SchemaVersion.current);
    });

    test('records the oldest reader of what it leaves', () async {
      SettingStore.instance.schemaVersion.put(SchemaVersion.current);

      await SchemaVersion.migrate(kSchemaMigrations);

      expect(SchemaVersion.readsAhead, isFalse);
      expect(
        SettingStore.instance.schemaMinReader.fetch(),
        SchemaVersion.minReader(kSchemaMigrations, SchemaVersion.current),
      );
    });
  });
}
