import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

Spi _spi({
  required String id,
  required String name,
  String? jumpId,
  List<String>? jumpIds,
}) {
  return Spi(
    id: id,
    name: name,
    ip: '$name.example.com',
    port: 22,
    user: 'root',
    jumpId: jumpId,
    jumpIds: jumpIds,
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

    test('collectJumpServers collects both jump candidates', () {
      final target = _spi(id: 'T', name: 'target', jumpIds: ['A', 'C']);
      final servers = <String, Spi>{
        'A': _spi(id: 'A', name: 'a', jumpId: 'B'),
        'B': _spi(id: 'B', name: 'b'),
        'C': _spi(id: 'C', name: 'c', jumpId: 'D'),
        'D': _spi(id: 'D', name: 'd'),
      };

      final chain = collectJumpServers(spi: target, serversById: servers);

      expect(chain.keys.toList(), ['A', 'C', 'B', 'D']);
    });

    test(
      'wouldCreateJumpCycleForCandidates detects either candidate cycle',
      () {
        final servers = <String, Spi>{
          'A': _spi(id: 'A', name: 'a'),
          'B': _spi(id: 'B', name: 'b', jumpId: 'T'),
        };

        final result = wouldCreateJumpCycleForCandidates(
          currentServerId: 'T',
          candidateJumpIds: ['A', 'B'],
          serversById: servers,
        );

        expect(result, isTrue);
      },
    );

    test('resolvedJumpIds falls back to legacy jumpId', () {
      final target = _spi(id: 'T', name: 'target', jumpId: 'A');

      expect(target.resolvedJumpIds, ['A']);
      expect(target.firstJumpId, 'A');
    });
  });
}
