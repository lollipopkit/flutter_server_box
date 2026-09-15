import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/schema.dart';

void main() {
  group('Spi.fromJson accepts the pre-v3 flat layout', () {
    test('lifts every SSH key under ssh', () {
      final spi = Spi.fromJson({
        'name': 'web',
        'id': 'abc',
        'ip': '10.0.0.1',
        'port': 2222,
        'user': 'deploy',
        'pwd': 'secret',
        'pubKeyId': 'key-1',
        'alterUrl': 'deploy@10.0.0.2:22',
        'jumpId': 'jump-1',
        'jumpIds': ['jump-1', 'jump-2'],
        'proxyCommand': 'nc %h %p',
        'autoConnect': false,
      });

      final ssh = spi.ssh;
      expect(ssh, isNotNull);
      expect(ssh!.ip, '10.0.0.1');
      expect(ssh.port, 2222);
      expect(ssh.user, 'deploy');
      expect(ssh.pwd, 'secret');
      expect(ssh.keyId, 'key-1');
      expect(ssh.alterUrl, 'deploy@10.0.0.2:22');
      expect(ssh.jumpId, 'jump-1');
      expect(ssh.jumpIds, ['jump-1', 'jump-2']);
      expect(ssh.proxyCommand, 'nc %h %p');
      // Non-SSH fields stay put
      expect(spi.name, 'web');
      expect(spi.id, 'abc');
      expect(spi.autoConnect, isFalse);
    });

    test('a record without a host yields no credential', () {
      // Monitor-only servers written by the intermediate build carried a host
      // derived from the monitor URL; ones without any host must not be given
      // an empty credential, which would look reachable
      final spi = Spi.fromJson({'name': 'no-ssh', 'id': 'x'});
      expect(spi.ssh, isNull);
      expect(Spi.fromJson({'name': 'blank', 'id': 'y', 'ip': ''}).ssh, isNull);
    });

    test('the nested layout is passed through untouched', () {
      final spi = Spi.fromJson({
        'name': 'web',
        'id': 'abc',
        'ssh': {'ip': '10.0.0.1', 'port': 22, 'user': 'root'},
      });
      expect(spi.ssh?.ip, '10.0.0.1');
    });

    test('round-trips through JSON in the nested layout only', () {
      final original = Spi(
        name: 'web',
        id: 'abc',
        ssh: const SshCredential(ip: '10.0.0.1', port: 22, user: 'root'),
      );
      // toJson leaves nested models as objects (same as custom/wolCfg/
      // monitorHttp); json.encode's default toEncodable calls their toJson
      final encoded =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      expect(encoded.containsKey('ip'), isFalse);
      expect(encoded['ssh'], isA<Map>());
      expect(Spi.fromJson(encoded), original);
    });
  });

  group('backup version guard', () {
    test('refuses an envelope from a newer build', () {
      final future = jsonEncode({
        'version': BackupV2.formatVer + 1,
        'date': 0,
        'spis': <String, Object?>{},
        'snippets': <String, Object?>{},
        'keys': <String, Object?>{},
        'container': <String, Object?>{},
        'history': <String, Object?>{},
        'settings': <String, Object?>{},
      });
      expect(
        () => BackupV2.fromJsonString(future),
        throwsA(isA<SchemaTooNewException>()),
      );
    });

    test('accepts its own and older envelopes', () {
      for (final v in [1, BackupV2.formatVer]) {
        final bak = BackupV2.fromJsonString(
          jsonEncode({
            'version': v,
            'date': 0,
            'spis': <String, Object?>{},
            'snippets': <String, Object?>{},
            'keys': <String, Object?>{},
            'container': <String, Object?>{},
            'history': <String, Object?>{},
            'settings': <String, Object?>{},
          }),
        );
        expect(bak.version, v);
      }
    });
  });

  group('SchemaVersion', () {
    test('the backup envelope and the store schema share one number', () {
      expect(BackupV2.formatVer, SchemaVersion.current);
    });
  });

  group('an unknown preferred transport', () {
    test('reads as null rather than taking the record with it', () {
      // Stored by name, and a build that grows a third transport writes a word
      // this one has never seen. Without `unknownEnumValue` the decode throws,
      // and `Spi.fromJson` failing loses the *whole server* — through a backup
      // restore, a sync, or a shared QR code.
      final spi = Spi.fromJson({
        'name': 'box',
        'id': 's-1',
        'ssh': {'ip': '10.0.0.1', 'port': 22, 'user': 'root'},
        'monitorHttp': {'addr': 'https://h:3770'},
        'preferredTransport': 'quicOverCarrierPigeon',
      });

      expect(spi.name, 'box');
      expect(spi.preferredTransport, isNull);
      // And falls back to the resolution an absent preference already gets.
      expect(spi.transport, ServerTransport.ssh);
    });

    test('a known one still decodes', () {
      final spi = Spi.fromJson({
        'name': 'box',
        'id': 's-1',
        'ssh': {'ip': '10.0.0.1', 'port': 22, 'user': 'root'},
        'monitorHttp': {'addr': 'https://h:3770'},
        'preferredTransport': 'monitorHttp',
      });

      expect(spi.transport, ServerTransport.monitorHttp);
    });
  });
}
