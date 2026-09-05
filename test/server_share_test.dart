/// The share payload, end to end.
///
/// Two things here are worth more than the round trips. One is that installing
/// a payload is *additive* — it is the difference from a backup restore, where
/// an absent key means a deletion, and the whole reason this format has no
/// reader in common with `BackupV2`. The other is that a key arriving from
/// someone else's device may not overwrite one of the receiver's own, which is
/// exactly what reusing `EntityStore.reconcile` would have done.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server_share.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';

import 'helpers/test_db.dart';

const _keyMaterial = '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END-----';
const _otherMaterial = '-----BEGIN OPENSSH PRIVATE KEY-----\nxyz\n-----END-----';

Spi _spi({
  String id = 'srv1',
  String name = 'web',
  String ip = '10.0.0.1',
  String? keyId,
  String? jumpId,
  String? keyPath,
  BmcCfg? bmc,
}) => Spi(
  id: id,
  name: name,
  bmc: bmc,
  ssh: SshCredential(
    ip: ip,
    port: 22,
    user: 'root',
    pwd: 'hunter2',
    keyId: keyId,
    keyPath: keyPath,
    jumpId: jumpId,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    if (!getIt.isRegistered<ServerStore>()) {
      getIt.registerSingleton<ServerStore>(ServerStore());
    }
    if (!getIt.isRegistered<PrivateKeyStore>()) {
      getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    }
    Stores.server.dropCache();
    Stores.key.dropCache();
  });

  tearDown(closeTestDb);

  group('packing', () {
    test('the key the server points at travels with it', () {
      Stores.key.put(
        const PrivateKeyInfo(id: 'k1', name: 'laptop', key: _keyMaterial),
      );
      final share = ServerShare.of(_spi(keyId: 'k1'));

      expect(share.keys, hasLength(1));
      expect(share.keys.single.key, _keyMaterial);
      expect(share.spi.ssh?.keyId, 'k1');
      // The point of carrying it at all: the password is not the only
      // credential a server has, and a QR that dropped this was a server the
      // receiver could not connect with.
      expect(share.spi.ssh?.pwd, 'hunter2');
    });

    test('references that only mean something here are dropped', () {
      final share = ServerShare.of(
        _spi(
          jumpId: 'other-server',
          keyPath: '/home/me/.ssh/id_ed25519',
          bmc: const BmcCfg(addr: 'https://bmc.local', credId: 'cred1'),
        ),
      );

      expect(share.spi.ssh?.jumpId, isNull);
      expect(share.spi.ssh?.keyPath, isNull);
      expect(share.spi.bmc?.credId, isNull);
      // The address is not a reference and survives; only the account goes.
      expect(share.spi.bmc?.addr, 'https://bmc.local');
    });

    test('a key id nothing can resolve is dropped, not handed over', () {
      // The sender's store has no `k-gone`. Keeping the id would hand over a
      // server that looks like it uses key auth and cannot authenticate.
      final share = ServerShare.of(_spi(keyId: 'k-gone'));
      expect(share.keys, isEmpty);
      expect(share.spi.ssh?.keyId, isNull);
    });

    test('omissionsOf names each of them', () {
      expect(ServerShare.omissionsOf(_spi()), isEmpty);
      expect(
        ServerShare.omissionsOf(_spi(jumpId: 'x')),
        contains(ServerShareOmission.jumpServer),
      );
      expect(
        ServerShare.omissionsOf(_spi(keyPath: '/x')),
        contains(ServerShareOmission.localKeyPath),
      );
      expect(
        ServerShare.omissionsOf(_spi(keyId: 'k-gone')),
        contains(ServerShareOmission.missingKey),
      );
      expect(
        ServerShare.omissionsOf(
          _spi(bmc: const BmcCfg(addr: 'a', credId: 'c')),
        ),
        contains(ServerShareOmission.bmcCredential),
      );
    });
  });

  group('codec', () {
    test('a QR payload round-trips under its code', () {
      final share = ServerShare.of(_spi(), ttl: ShareCarrier.qr.ttl);
      final code = ServerShareCodec.generateCode();
      final text = ServerShareCodec.encode(share, code, ShareCarrier.qr);

      expect(ServerShareCodec.needsPassword(text), isTrue);
      final back = ServerShareCodec.decode(text, password: code);
      expect(back.spi.name, 'web');
      expect(back.spi.ssh?.pwd, 'hunter2');
    });

    test('generateCode is six digits', () {
      for (var i = 0; i < 50; i++) {
        final code = ServerShareCodec.generateCode();
        expect(code, hasLength(ServerShareCodec.codeDigits));
        expect(int.tryParse(code), isNotNull);
      }
    });

    test('a file payload round-trips under its passphrase', () {
      final share = ServerShare.of(_spi());
      final text = ServerShareCodec.encode(
        share,
        'a long passphrase',
        ShareCarrier.file,
      );
      expect(
        ServerShareCodec.decode(text, password: 'a long passphrase').spi.name,
        'web',
      );
    });

    test('the wrong code is refused', () {
      final text = ServerShareCodec.encode(
        ServerShare.of(_spi()),
        '111111',
        ShareCarrier.qr,
      );
      expect(
        () => ServerShareCodec.decode(text, password: '111112'),
        throwsA(isA<Exception>()),
      );
    });

    test('a payload with no password supplied says so', () {
      final text = ServerShareCodec.encode(
        ServerShare.of(_spi()),
        '111111',
        ShareCarrier.qr,
      );
      expect(
        () => ServerShareCodec.decode(text),
        throwsA(isA<ServerShareUnreadableException>()),
      );
    });

    /// The deadline is what makes twenty bits of code worth anything: an
    /// attacker who photographs the QR and starts guessing gets, at the end of
    /// it, a payload the app refuses.
    test('an expired payload is refused after it decrypts', () {
      final expired = ServerShare(
        version: ServerShare.formatVer,
        spi: _spi(),
        expiresAt: DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
      );
      final text = ServerShareCodec.encode(expired, '111111', ShareCarrier.qr);
      expect(
        () => ServerShareCodec.decode(text, password: '111111'),
        throwsA(isA<ServerShareExpiredException>()),
      );
    });

    test('a payload with no deadline never expires', () {
      expect(ServerShare.of(_spi()).isExpired(), isFalse);
    });

    test('the boundary is exclusive', () {
      final at = DateTime(2026, 1, 1);
      final share = ServerShare(
        version: ServerShare.formatVer,
        spi: _spi(),
        expiresAt: at.millisecondsSinceEpoch,
      );
      expect(share.isExpired(at), isFalse);
      expect(share.isExpired(at.add(const Duration(milliseconds: 1))), isTrue);
    });

    /// Every QR shared before this format is a bare `Spi` in clear text. One
    /// printed and stuck on a rack has to keep working.
    test('a clear-text Spi from an older build still reads', () {
      final legacy = json.encode(_spi(name: 'old').toJson());
      expect(ServerShareCodec.needsPassword(legacy), isFalse);
      final share = ServerShareCodec.decode(legacy);
      expect(share.spi.name, 'old');
      expect(share.keys, isEmpty);
    });

    test('a payload from a newer build is refused', () {
      final text = ServerShareCodec.encode(
        ServerShare(
          version: ServerShare.formatVer + 1,
          spi: _spi(),
        ),
        '111111',
        ShareCarrier.qr,
      );
      expect(
        () => ServerShareCodec.decode(text, password: '111111'),
        throwsA(isA<ServerShareTooNewException>()),
      );
    });

    /// The shape carries `keys`, so accepting it in clear text would mean a
    /// file handing over a private key with no password asked for — and
    /// `needsPassword` answering false, so the user is never prompted either.
    /// Nothing has ever written one, so there is no compatibility to keep.
    test('a clear-text ServerShare is refused, keys and all', () {
      final text = json.encode({
        'version': ServerShare.formatVer,
        'spi': _spi().toJson(),
        'keys': [
          const PrivateKeyInfo(
            id: 'k1',
            name: 'laptop',
            key: _keyMaterial,
          ).toJson(),
        ],
      });
      expect(ServerShareCodec.needsPassword(text), isFalse);
      expect(
        () => ServerShareCodec.decode(text),
        throwsA(isA<ServerShareUnreadableException>()),
      );
    });

    test('a hand-edited payload says so rather than leaking a TypeError', () {
      for (final broken in [
        <String, Object?>{'version': ServerShare.formatVer},
        <String, Object?>{'version': '1', 'spi': _spi().toJson()},
        <String, Object?>{'version': ServerShare.formatVer, 'spi': 'nope'},
      ]) {
        // Through the envelope, since the encrypted branch is the only one
        // that reads this shape at all.
        final text = Cryptor.encrypt(json.encode(broken), '111111');
        expect(
          () => ServerShareCodec.decode(text, password: '111111'),
          throwsA(isA<ServerShareUnreadableException>()),
          reason: '$broken',
        );
      }
    });

    test('text that is neither shape is refused', () {
      expect(
        () => ServerShareCodec.decode('https://example.com'),
        throwsA(isA<ServerShareUnreadableException>()),
      );
      expect(
        () => ServerShareCodec.decode('[]'),
        throwsA(isA<ServerShareUnreadableException>()),
      );
    });
  });

  group('installing', () {
    test('the key lands and the server points at it', () {
      final share = ServerShare(
        version: ServerShare.formatVer,
        spi: _spi(keyId: 'k1'),
        keys: const [
          PrivateKeyInfo(id: 'k1', name: 'laptop', key: _keyMaterial),
        ],
      );

      final result = ServerShareInstaller.install(share);
      expect(result.addedKeys, hasLength(1));

      final stored = Stores.server.fetchOneRaw(result.spi.id);
      expect(stored, isNotNull);
      final keyId = stored!.ssh?.keyId;
      expect(keyId, isNotNull);
      expect(Stores.key.fetchOne(keyId)?.key, _keyMaterial);
    });

    /// The case reusing `EntityStore.reconcile` would have got wrong. It
    /// resolves a name collision by taking the existing row's id, and `put`
    /// then writes the incoming material over it — so accepting a share would
    /// have replaced the receiver's own key with the sender's.
    test('a same-named local key is not overwritten', () {
      Stores.key.put(
        const PrivateKeyInfo(id: 'mine', name: 'laptop', key: _otherMaterial),
      );

      ServerShareInstaller.install(
        ServerShare(
          version: ServerShare.formatVer,
          spi: _spi(keyId: 'k1'),
          keys: const [
            PrivateKeyInfo(id: 'k1', name: 'laptop', key: _keyMaterial),
          ],
        ),
      );

      expect(Stores.key.fetchOne('mine')?.key, _otherMaterial);
      final keys = Stores.key.fetch();
      expect(keys, hasLength(2));
      // `(1)`, the same numbering `ServerDeduplication` gives the server that
      // arrived with it. The two used to disagree.
      expect(keys.map((e) => e.name).toSet(), {'laptop', 'laptop (1)'});
    });

    test('a renamed key and its server are numbered the same way', () {
      Stores.server.put(_spi(id: 'ours', name: 'web', ip: '192.168.1.9'));
      Stores.key.put(
        const PrivateKeyInfo(id: 'mine', name: 'laptop', key: _otherMaterial),
      );

      final result = ServerShareInstaller.install(
        ServerShare(
          version: ServerShare.formatVer,
          spi: _spi(keyId: 'k1'),
          keys: const [
            PrivateKeyInfo(id: 'k1', name: 'laptop', key: _keyMaterial),
          ],
        ),
      );

      expect(result.spi.name, 'web (1)');
      expect(Stores.key.fetchOne(result.spi.ssh?.keyId)?.name, 'laptop (1)');
    });

    test('a key the device already has by material is reused, not copied', () {
      Stores.key.put(
        const PrivateKeyInfo(id: 'mine', name: 'laptop', key: _keyMaterial),
      );

      final result = ServerShareInstaller.install(
        ServerShare(
          version: ServerShare.formatVer,
          spi: _spi(keyId: 'k1'),
          // A different id and a different name, the same key.
          keys: const [
            PrivateKeyInfo(id: 'k1', name: 'their laptop', key: _keyMaterial),
          ],
        ),
      );

      expect(result.addedKeys, isEmpty);
      expect(Stores.key.fetch(), hasLength(1));
      expect(result.spi.ssh?.keyId, 'mine');
    });

    test('installing the same share twice adds a second server, not a fork of '
        'the first', () {
      final share = ServerShare(
        version: ServerShare.formatVer,
        spi: _spi(keyId: 'k1'),
        keys: const [
          PrivateKeyInfo(id: 'k1', name: 'laptop', key: _keyMaterial),
        ],
      );

      final first = ServerShareInstaller.install(share);
      final second = ServerShareInstaller.install(share);

      expect(second.spi.id, isNot(first.spi.id));
      expect(second.spi.name, isNot(first.spi.name));
      expect(Stores.server.fetch(), hasLength(2));
      // One key, because the material matched.
      expect(Stores.key.fetch(), hasLength(1));
    });

    test('nothing the receiver had is removed', () {
      Stores.server.put(_spi(id: 'ours', name: 'ours', ip: '192.168.1.9'));
      Stores.key.put(
        const PrivateKeyInfo(id: 'ourkey', name: 'ours', key: _otherMaterial),
      );

      ServerShareInstaller.install(
        ServerShare(version: ServerShare.formatVer, spi: _spi()),
      );

      expect(Stores.server.fetchOneRaw('ours'), isNotNull);
      expect(Stores.key.fetchOne('ourkey'), isNotNull);
    });

    group('findExisting', () {
      test('matches on id', () {
        Stores.server.put(_spi(id: 'srv1'));
        expect(ServerShareInstaller.findExisting(_spi(id: 'srv1')), isNotNull);
      });

      test('matches on the ssh endpoint', () {
        Stores.server.put(_spi(id: 'a', ip: '10.0.0.1'));
        expect(
          ServerShareInstaller.findExisting(_spi(id: 'b', ip: '10.0.0.1'))?.id,
          'a',
        );
      });

      test('a different endpoint is a different machine', () {
        Stores.server.put(_spi(id: 'a', ip: '10.0.0.1'));
        expect(
          ServerShareInstaller.findExisting(_spi(id: 'b', ip: '10.0.0.2')),
          isNull,
        );
      });

      /// What `Spi.isSameAs` answers wrong: it compares SSH credentials and
      /// nothing else, so two servers that both have none read as the same
      /// machine. This is why the share path has its own comparison.
      test('two monitor-only servers are not the same machine', () {
        const a = Spi(
          id: 'a',
          name: 'a',
          monitorHttp: MonitorHttpCredential(addr: 'https://a.example'),
        );
        const b = Spi(
          id: 'b',
          name: 'b',
          monitorHttp: MonitorHttpCredential(addr: 'https://b.example'),
        );
        Stores.server.put(a);
        expect(ServerShareInstaller.findExisting(b), isNull);
        expect(a.isSameAs(b), isTrue, reason: 'the behaviour being avoided');
      });
    });
  });
}
