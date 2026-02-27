import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

Spi _spi({required String id, required String name, String? jumpId}) {
  return Spi(
    id: id,
    name: name,
    ip: '$name.example.com',
    port: 22,
    user: 'root',
    jumpId: jumpId,
  );
}

void main() {
  group('JumpChain', () {
    test('wouldCreateJumpCycle returns false for valid chain', () {
      final servers = <String, Spi>{
        'A': _spi(id: 'A', name: 'a'),
        'B': _spi(id: 'B', name: 'b', jumpId: 'A'),
      };

      final result = wouldCreateJumpCycle(
        currentServerId: 'C',
        candidateJumpId: 'B',
        serversById: servers,
      );

      expect(result, isFalse);
    });

    test('wouldCreateJumpCycle detects cycle back to current server', () {
      final servers = <String, Spi>{
        'A': _spi(id: 'A', name: 'a', jumpId: 'B'),
        'B': _spi(id: 'B', name: 'b', jumpId: 'C'),
        'C': _spi(id: 'C', name: 'c'),
      };

      final result = wouldCreateJumpCycle(
        currentServerId: 'C',
        candidateJumpId: 'A',
        serversById: servers,
      );

      expect(result, isTrue);
    });

    test('wouldCreateJumpCycle treats existing malformed loop as invalid', () {
      final servers = <String, Spi>{
        'A': _spi(id: 'A', name: 'a', jumpId: 'B'),
        'B': _spi(id: 'B', name: 'b', jumpId: 'A'),
      };

      final result = wouldCreateJumpCycle(
        currentServerId: 'C',
        candidateJumpId: 'A',
        serversById: servers,
      );

      expect(result, isTrue);
    });

    test('wouldCreateJumpCycle validates new server with null current id', () {
      final servers = <String, Spi>{
        'A': _spi(id: 'A', name: 'a', jumpId: 'B'),
        'B': _spi(id: 'B', name: 'b', jumpId: 'A'),
      };

      final result = wouldCreateJumpCycle(
        currentServerId: null,
        candidateJumpId: 'A',
        serversById: servers,
      );

      expect(result, isTrue);
    });

    test('collectJumpServers collects reachable jump servers', () {
      final target = _spi(id: 'T', name: 'target', jumpId: 'A');
      final servers = <String, Spi>{
        'A': _spi(id: 'A', name: 'a', jumpId: 'B'),
        'B': _spi(id: 'B', name: 'b'),
      };

      final chain = collectJumpServers(spi: target, serversById: servers);

      expect(chain.keys.toList(), ['A', 'B']);
    });
  });
}
