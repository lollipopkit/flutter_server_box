import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/identities.dart';
import 'package:server_box/core/utils/server_share.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Paths.doc = Directory.systemTemp.createTempSync('sbm-multi-key-').path;
  });
  tearDownAll(() => Directory(Paths.doc).deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    await openTestDb();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('SshCredential resolves ordered keyIds with legacy pubKeyId fallback', () {
    final legacy = SshCredential.fromJson({
      'ip': '10.0.0.1',
      'pubKeyId': 'k1',
    });
    expect(legacy.resolvedKeyIds, ['k1']);
    expect(legacy.firstKeyId, 'k1');
    expect(legacy.keyRefs, ['id:k1']);

    const multi = SshCredential(
      ip: '10.0.0.1',
      keyIds: ['k2', 'k1', 'k2', ''],
    );
    expect(multi.resolvedKeyIds, ['k2', 'k1']);
    expect(multi.firstKeyId, 'k2');
    expect(multi.keyRefs, ['id:k2', 'id:k1']);

    final json = multi.toJson();
    expect(json['pubKeyId'], 'k2');
    expect(json['keyIds'], ['k2', 'k1']);

    final decoded = SshCredential.fromJson(json);
    expect(decoded.resolvedKeyIds, ['k2', 'k1']);
    expect(decoded, multi);
    expect(decoded.hashCode, multi.hashCode);

    // Order matters for equality & reconnect check.
    const reordered = SshCredential(ip: '10.0.0.1', keyIds: ['k1', 'k2']);
    expect(multi.isSameAs(reordered), isFalse);

    // Legacy copyWith(keyId: ...) and copyWith(keyIds: ...) normalize cleanly.
    final singleReplaced = multi.copyWith(keyId: 'k3');
    expect(singleReplaced.resolvedKeyIds, ['k3']);
    final cleared = multi.copyWith(keyId: null);
    expect(cleared.resolvedKeyIds, isEmpty);
    expect(cleared.toJson().containsKey('keyIds'), isFalse);
    final clearedList = multi.copyWith(keyIds: const <String>[]);
    expect(clearedList.resolvedKeyIds, isEmpty);
    expect(clearedList.toJson().containsKey('keyIds'), isFalse);
    expect(multi.copyWith(keyId: '').resolvedKeyIds, isEmpty);
    expect(multi.copyWith(keyIds: const ['', 'k2']).keyId, 'k2');
  });

  test('privateKeyDisplayName strips keyRef prefixes and resolves store name', () {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'prod-key', key: 'PEM'));
    expect(privateKeyDisplayName('id:k1'), 'prod-key');
    expect(privateKeyDisplayName('id:unknown'), 'unknown');
    expect(privateKeyDisplayName('path:~/.ssh/id_ed25519'), '~/.ssh/id_ed25519');
  });

  test('resolvePrivateKeys returns stored keys in order and skips a missing one', () async {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'one', key: 'PEM-1'));
    Stores.key.put(const PrivateKeyInfo(id: 'k2', name: 'two', key: 'PEM-2'));

    const ssh = SshCredential(
      ip: '10.0.0.1',
      keyIds: ['k2', 'missing', 'k1'],
    );

    final syncResolved = resolvePrivateKeys(ssh);
    expect(syncResolved.keys.toList(), ['id:k2', 'id:k1']);
    expect(syncResolved.values.toList(), ['PEM-2', 'PEM-1']);

    final asyncResolved = await resolvePrivateKeysAsync(ssh);
    expect(asyncResolved.keys.toList(), ['id:k2', 'id:k1']);
    expect(asyncResolved.values.toList(), ['PEM-2', 'PEM-1']);
  });

  test('ServerShare packs and installs multiple keys in order', () {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'first', key: 'PEM-1'));
    Stores.key.put(const PrivateKeyInfo(id: 'k2', name: 'second', key: 'PEM-2'));

    const spi = Spi(
      id: 'srv-1',
      name: 'prod',
      ssh: SshCredential(
        ip: '10.0.0.9',
        keyId: 'k2',
        keyIds: ['k2', 'k1'],
      ),
    );
    Stores.server.put(spi);

    expect(ServerShare.omissionsOf(spi), isEmpty);
    final share = ServerShare.of(spi);
    expect(share.keys.map((k) => k.id).toList(), ['k2', 'k1']);
    expect(share.spi.ssh!.resolvedKeyIds, ['k2', 'k1']);

    // Simulate installing on a clean device with different existing key ids.
    Stores.server.deleteById('srv-1');
    Stores.key.deleteById('k1');
    Stores.key.deleteById('k2');
    Stores.key.put(
      const PrivateKeyInfo(id: 'local-k1', name: 'first', key: 'PEM-1'),
    );

    final res = ServerShareInstaller.install(share);
    final installed = Stores.server.fetchOneRaw(res.spi.id)!;
    final installedIds = installed.ssh!.resolvedKeyIds;
    expect(installedIds, hasLength(2));
    expect(installedIds[1], 'local-k1');
    expect(Stores.key.fetchOne(installedIds[0])?.key, 'PEM-2');
  });
}
