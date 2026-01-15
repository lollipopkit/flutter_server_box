import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

void main() {
  group('Jump server', () {
    test('resolveMergedJumpChain throws when injected chain misses jump server', () {
      const spi = Spi(
        name: 'target',
        ip: '10.0.0.10',
        port: 22,
        user: 'root',
        id: 't',
        jumpId: 'missing',
      );

      expect(
        () => resolveMergedJumpChain(spi, jumpChain: const <Spi>[]),
        throwsA(
          isA<SSHErr>().having(
            (e) => e.type,
            'type',
            SSHErrType.connect,
          ),
        ),
      );
    });

    test('resolveMergedJumpChain merges and dedups', () {
      const c = Spi(name: 'c', ip: '10.0.0.30', port: 22, user: 'root', id: 'c');
      const d = Spi(name: 'd', ip: '10.0.0.40', port: 22, user: 'root', id: 'd');
      const b = Spi(
        name: 'b',
        ip: '10.0.0.20',
        port: 22,
        user: 'root',
        id: 'b',
        jumpChainIds: ['c', 'd'],
      );
      const target = Spi(
        name: 'target',
        ip: '10.0.0.10',
        port: 22,
        user: 'root',
        id: 't',
        jumpChainIds: ['b', 'c'],
      );

      final chain = resolveMergedJumpChain(target, jumpChain: const <Spi>[b, c, d]);
      expect(chain.map((e) => e.id).toList(), ['c', 'd', 'b']);
    });

    test('resolveMergedJumpChain detects jump loop', () {
      const b = Spi(
        name: 'b',
        ip: '10.0.0.20',
        port: 22,
        user: 'root',
        id: 'b',
        jumpChainIds: ['c'],
      );
      const c = Spi(
        name: 'c',
        ip: '10.0.0.30',
        port: 22,
        user: 'root',
        id: 'c',
        jumpChainIds: ['b'],
      );
      const target = Spi(
        name: 'target',
        ip: '10.0.0.10',
        port: 22,
        user: 'root',
        id: 't',
        jumpChainIds: ['b'],
      );

      expect(
        () => resolveMergedJumpChain(target, jumpChain: const <Spi>[b, c]),
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

