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

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// A step that does nothing, so a list can be assembled to a shape.
class _Noop implements SchemaMigration {
  const _Noop(this.from);

  @override
  final int from;

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
    for (var v = SchemaVersion.hiveImportProduces; v < SchemaVersion.current; v++) {
      expect(covered, contains(v), reason: 'no step converts v$v to v${v + 1}');
    }
  });

  test('and has no step the migrator would never reach', () {
    for (final m in kSchemaMigrations) {
      expect(
        m.from,
        inInclusiveRange(SchemaVersion.hiveImportProduces, SchemaVersion.current - 1),
        reason: '${m.runtimeType} converts from a version nothing is at',
      );
    }
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
      getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    });

    tearDown(() async {
      await getIt.reset();
      await SqliteDb.close();
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
        () => SchemaVersion.migrate(const [_Noop(SchemaVersion.hiveImportProduces)]),
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
  });
}
