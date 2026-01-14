import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

void main() {
  group('Jump server', () {
    test('genClient throws when injected chain misses jump server', () async {
      const spi = Spi(
        name: 'target',
        ip: '10.0.0.10',
        port: 22,
        user: 'root',
        id: 't',
        jumpId: 'missing',
      );

      await expectLater(
        () => genClient(
          spi,
          jumpChain: const <Spi>[],
          jumpPrivateKeys: const <String?>[],
          knownHostFingerprints: const <String, String>{},
        ),
        throwsA(
          isA<SSHErr>().having(
            (e) => e.type,
            'type',
            SSHErrType.connect,
          ),
        ),
      );
    });

    test('genClient detects jump loop', () async {
      const spi = Spi(
        name: 'loop',
        ip: '10.0.0.20',
        port: 22,
        user: 'root',
        id: 'loop_id',
        jumpId: 'loop_id',
      );

      await expectLater(
        () => genClient(
          spi,
          jumpChain: const <Spi>[spi],
          jumpPrivateKeys: const <String?>[null],
          knownHostFingerprints: const <String, String>{},
        ),
        throwsA(
          isA<SSHErr>().having(
            (e) => e.type,
            'type',
            SSHErrType.connect,
          ),
        ),
      );
    });
  });
}

