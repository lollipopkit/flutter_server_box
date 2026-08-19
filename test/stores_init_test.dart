import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/hive/hive_registrar.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `Stores.init` against a database that is not open yet.
///
/// Every other suite calls `SqliteDb.openInMemory()` in `setUp`, which makes
/// `SqliteStore.init` return at its `isOpen` guard — so none of them exercise
/// the path a cold launch actually takes, where the file has to be opened
/// first. That gap hid a crash on every launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-stores-init-');
    // `late final`, so once per process.
    Paths.doc = tempDir.path;

    // `HiveImport` runs inside `Stores.init` and opens boxes through
    // `HiveStore`; registering twice throws, so this is once per process too.
    Hive.init(tempDir.path);
    Hive.registerAdapters();
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  setUp(() async {
    // One seeded generator reused, not a new one per byte — `Random(7)` inside
    // the closure would have produced the same value 32 times.
    final rng = Random(7);
    FlutterSecureStorage.setMockInitialValues({
      'hivePwd': base64UrlEncode(
        Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256))),
      ),
    });
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();

  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('it opens the database before any store reads it', () async {
    // The whole test. `ConnectionStatsStore.init` and
    // `AgentConversationStore.init` reach `SqliteDb.instance` synchronously to
    // create their tables, so they cannot be started in the same batch as the
    // K-V stores that are still opening the file.
    await Stores.init();

    expect(SqliteDb.isOpen, isTrue);
    expect(SqliteDb.path, tempDir.path.joinPath(SqliteDb.fileName));
  });

  test('every store is usable once init returns', () async {
    await Stores.init();

    Stores.setting.timeout.put(11);
    expect(Stores.setting.timeout.get(), 11);

    // The two table-backed stores answer only if their tables were created.
    expect(Stores.connectionStats.getAllServerStats(), isEmpty);
    expect(Stores.agentConversation.fetchForServer('srv'), isEmpty);
  });

  test('a second launch reopens the same file', () async {
    // Deliberately not deleting the file between the two `Stores.init` calls.
    await Stores.init();
    Stores.setting.timeout.put(23);

    await getIt.reset();
    await SqliteDb.close();

    await Stores.init();
    expect(Stores.setting.timeout.get(), 23);
  });

  test('the schema version does not travel in a backup', () async {
    await Stores.init();

    // It describes this device's storage. Carried in a backup, restoring one
    // taken on a device still on the previous release wrote that version back,
    // and the next launch found no migration registered for it and threw a
    // StateError nothing catches.
    expect(Stores.setting.getAllMap().keys, isNot(contains('schemaVersion')));
    expect(
      Stores.setting.getAllMap().keys.any((k) => k.contains('schemaVersion')),
      isFalse,
    );
    expect(SchemaVersion.stored, SchemaVersion.current);
  });

  test('clearing the settings does not make the import run again', () async {
    const marker = '${StoreDefaults.prefixKey}hiveImported';

    await Stores.init();
    expect(Stores.setting.get<bool>(marker), isTrue);
    Stores.setting.timeout.put(31);

    Stores.setting.clear();

    // The marker is internal, so `clear` leaves it — directly, not inferred
    // from the schema version. Were it dropped, the next launch would copy the
    // retained Hive boxes back over everything the user has since changed.
    expect(Stores.setting.timeout.get(), isNot(31), reason: 'settings cleared');
    expect(Stores.setting.get<bool>(marker), isTrue);

    await getIt.reset();
    await SqliteDb.close();
    await Stores.init();

    expect(Stores.setting.get<bool>(marker), isTrue);
    expect(SchemaVersion.stored, SchemaVersion.current);
  });
}
