import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/store_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records whether the database was still in place when the vault was reset.
class _Vault extends TestFlutterSecureStoragePlatform {
  _Vault(this.db) : super({'hivePwd': 'unreadable'});

  final File db;
  final resets = <({Map<String, String> options, bool dbInPlace})>[];

  @override
  Future<void> deleteAll({required Map<String, String> options}) {
    resets.add((options: options, dbInPlace: db.existsSync()));
    return super.deleteAll(options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File db;
  late _Vault vault;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('store_recovery');
    db = File('${dir.path}/${SqliteDb.fileName}')..writeAsBytesSync(List.filled(4096, 0x5a));
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    vault = _Vault(db);
    FlutterSecureStoragePlatform.instance = vault;
  });

  tearDown(() async {
    await StoreRecovery.acknowledge();
    dir.deleteSync(recursive: true);
  });

  StoreUnreadableException err(StoreUnreadableReason reason) =>
      StoreUnreadableException(reason, db.path, null);

  test('vaultFailed resets the vault, then sets the file aside', () async {
    await StoreRecovery.recover(err(StoreUnreadableReason.vaultFailed), StackTrace.current);

    final reset = vault.resets.single;
    expect(reset.dbInPlace, isTrue);
    expect(reset.options['resetOnError'], 'true');
    expect(vault.data, isEmpty);
    expect(db.existsSync(), isFalse);
    expect(File(StoreRecovery.result!.aside).existsSync(), isTrue);
    expect(StoreRecovery.result!.reason, StoreUnreadableReason.vaultFailed);
  });

  for (final reason in [StoreUnreadableReason.keyLost, StoreUnreadableReason.keyRejected]) {
    test('${reason.name} leaves the vault alone', () async {
      await StoreRecovery.recover(err(reason), StackTrace.current);
      expect(vault.resets, isEmpty);
      expect(vault.data, isNotEmpty);
      expect(db.existsSync(), isFalse);
    });
  }

  test('a failed reset leaves the file in place', () async {
    FlutterSecureStoragePlatform.instance = _ThrowingVault();
    await expectLater(
      StoreRecovery.recover(err(StoreUnreadableReason.vaultFailed), StackTrace.current),
      throwsA(isA<StateError>()),
    );
    expect(db.existsSync(), isTrue);
    expect(StoreRecovery.result, isNull);
  });
}

class _ThrowingVault extends TestFlutterSecureStoragePlatform {
  _ThrowingVault() : super({});

  @override
  Future<void> deleteAll({required Map<String, String> options}) => throw StateError('reset failed');
}
