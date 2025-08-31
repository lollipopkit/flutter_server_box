import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

// Mock functions to test the deduplication logic without relying on ServerStore
List<Spi> _mockDeduplicateServers(List<Spi> importedServers, List<Spi> existingServers) {
  final deduplicated = <Spi>[];
  
  for (final imported in importedServers) {
    // Check against existing servers
    if (!_mockIsDuplicate(imported, existingServers)) {
      // Also check against already processed imported servers
      if (!_mockIsDuplicate(imported, deduplicated)) {
        deduplicated.add(imported);
      }
    }
  }
  
  return deduplicated;
}

bool _mockIsDuplicate(Spi imported, List<Spi> existing) {
  for (final existingSpi in existing) {
    // Check for exact match on ip:port@user combination
    if (existingSpi.ip == imported.ip && 
        existingSpi.port == imported.port && 
        existingSpi.user == imported.user) {
      return true;
    }
  }
  
  return false;
}

List<Spi> _mockResolveNameConflicts(List<Spi> importedServers, List<String> existingNames) {
  final existingNamesSet = existingNames.toSet();
  final processedNames = <String>{};
  final result = <Spi>[];
  
  for (final server in importedServers) {
    String newName = server.name;
    int suffix = 2;
    
    // Check against both existing servers and already processed servers
    while (existingNamesSet.contains(newName) || processedNames.contains(newName)) {
      newName = '${server.name} ($suffix)';
      suffix++;
    }
    
    processedNames.add(newName);
    
    if (newName != server.name) {
      result.add(server.copyWith(name: newName));
    } else {
      result.add(server);
    }
  }
  
  return result;
}

void main() {
  group('ServerDeduplication Tests', () {
    late List<Spi> existingServers;
    late List<Spi> importedServers;

    setUp(() {
      // Set up some existing servers for testing
      existingServers = [
        const Spi(
          name: 'production-web',
          ip: '192.168.1.100',
          port: 22,
          user: 'root',
          id: 'existing1',
        ),
        const Spi(
          name: 'staging-db',
          ip: '192.168.1.200',
          port: 22,
          user: 'postgres',
          id: 'existing2',
        ),
        const Spi(
          name: 'dev-server',
          ip: '192.168.1.50',
          port: 2222,
          user: 'developer',
          id: 'existing3',
        ),
      ];
    });

    test('deduplicateServers removes exact duplicates', () {
      importedServers = [
        const Spi(
          name: 'new-server-1',
          ip: '192.168.1.100',
          port: 22,
          user: 'root', // Same as existing1
        ),
        const Spi(
          name: 'new-server-2',
          ip: '192.168.1.300',
          port: 22,
          user: 'admin', // New server
        ),
        const Spi(
          name: 'new-server-3',
          ip: '192.168.1.200',
          port: 22,
          user: 'postgres', // Same as existing2
        ),
      ];

      final deduplicated = _mockDeduplicateServers(importedServers, existingServers);

      expect(deduplicated, hasLength(1));
      expect(deduplicated.first.name, 'new-server-2');
      expect(deduplicated.first.ip, '192.168.1.300');
    });

    test('deduplicateServers considers port and user in deduplication', () {
      importedServers = [
        const Spi(
          name: 'same-ip-diff-port',
          ip: '192.168.1.100',
          port: 2222, // Different port
          user: 'root',
        ),
        const Spi(
          name: 'same-ip-diff-user',
          ip: '192.168.1.100',
          port: 22,
          user: 'admin', // Different user
        ),
        const Spi(
          name: 'exact-duplicate',
          ip: '192.168.1.100',
          port: 22,
          user: 'root', // Exact duplicate
        ),
      ];

      final deduplicated = _mockDeduplicateServers(importedServers, existingServers);

      expect(deduplicated, hasLength(2));
      expect(deduplicated.any((s) => s.name == 'same-ip-diff-port'), isTrue);
      expect(deduplicated.any((s) => s.name == 'same-ip-diff-user'), isTrue);
      expect(deduplicated.any((s) => s.name == 'exact-duplicate'), isFalse);
    });

    test('deduplicateServers handles empty existing servers list', () {
      importedServers = [
        const Spi(
          name: 'server1',
          ip: '192.168.1.100',
          port: 22,
          user: 'root',
        ),
        const Spi(
          name: 'server2',
          ip: '192.168.1.200',
          port: 22,
          user: 'admin',
        ),
      ];

      final deduplicated = _mockDeduplicateServers(importedServers, []);

      expect(deduplicated, hasLength(2));
      expect(deduplicated, equals(importedServers));
    });

    test('deduplicateServers handles empty imported servers list', () {
      final deduplicated = _mockDeduplicateServers([], existingServers);

      expect(deduplicated, isEmpty);
    });

    test('resolveNameConflicts appends numbers to conflicting names', () {
      importedServers = [
        const Spi(
          name: 'production-web', // Conflicts with existing
          ip: '192.168.1.300',
          port: 22,
          user: 'root',
        ),
        const Spi(
          name: 'dev-server', // Conflicts with existing
          ip: '192.168.1.400',
          port: 22,
          user: 'root',
        ),
        const Spi(
          name: 'unique-name', // No conflict
          ip: '192.168.1.500',
          port: 22,
          user: 'root',
        ),
      ];

      final resolved = _mockResolveNameConflicts(
        importedServers,
        existingServers.map((s) => s.name).toList(),
      );

      expect(resolved, hasLength(3));
      expect(resolved[0].name, 'production-web (2)');
      expect(resolved[1].name, 'dev-server (2)');
      expect(resolved[2].name, 'unique-name');
    });

    test('resolveNameConflicts handles multiple conflicts with same base name', () {
      importedServers = [
        const Spi(
          name: 'server',
          ip: '192.168.1.100',
          port: 22,
          user: 'root',
        ),
        const Spi(
          name: 'server',
          ip: '192.168.1.200',
          port: 22,
          user: 'admin',
        ),
        const Spi(
          name: 'server',
          ip: '192.168.1.300',
          port: 2222,
          user: 'root',
        ),
      ];

      final existingNames = ['server', 'server (2)'];
      final resolved = _mockResolveNameConflicts(importedServers, existingNames);

      expect(resolved, hasLength(3));
      expect(resolved[0].name, 'server (3)');
      expect(resolved[1].name, 'server (4)');
      expect(resolved[2].name, 'server (5)');
    });

    test('resolveNameConflicts handles empty input', () {
      final resolved = _mockResolveNameConflicts([], ['existing1', 'existing2']);

      expect(resolved, isEmpty);
    });

    test('getImportSummary calculates correct statistics', () {
      final originalList = [
        const Spi(name: 'server1', ip: '192.168.1.100', port: 22, user: 'root'),
        const Spi(name: 'server2', ip: '192.168.1.200', port: 22, user: 'admin'),
        const Spi(name: 'server3', ip: '192.168.1.300', port: 22, user: 'root'),
        const Spi(name: 'duplicate', ip: '192.168.1.100', port: 22, user: 'root'), // Duplicate of server1
      ];

      final deduplicatedList = [
        const Spi(name: 'server2', ip: '192.168.1.200', port: 22, user: 'admin'),
        const Spi(name: 'server3', ip: '192.168.1.300', port: 22, user: 'root'),
      ];

      final summary = ServerDeduplication.getImportSummary(
        originalList,
        deduplicatedList,
      );

      expect(summary.total, 4);
      expect(summary.duplicates, 2); // server1 and duplicate
      expect(summary.toImport, 2);
    });

    test('getImportSummary handles case with no duplicates', () {
      final originalList = [
        const Spi(name: 'server1', ip: '192.168.1.100', port: 22, user: 'root'),
        const Spi(name: 'server2', ip: '192.168.1.200', port: 22, user: 'admin'),
      ];

      final summary = ServerDeduplication.getImportSummary(
        originalList,
        originalList,
      );

      expect(summary.total, 2);
      expect(summary.duplicates, 0);
      expect(summary.toImport, 2);
    });

    test('getImportSummary handles case with all duplicates', () {
      final originalList = [
        const Spi(name: 'server1', ip: '192.168.1.100', port: 22, user: 'root'),
        const Spi(name: 'server2', ip: '192.168.1.200', port: 22, user: 'admin'),
      ];

      final summary = ServerDeduplication.getImportSummary(
        originalList,
        [],
      );

      expect(summary.total, 2);
      expect(summary.duplicates, 2);
      expect(summary.toImport, 0);
    });

    test('getImportSummary handles empty lists', () {
      final summary = ServerDeduplication.getImportSummary([], []);

      expect(summary.total, 0);
      expect(summary.duplicates, 0);
      expect(summary.toImport, 0);
    });

    test('complete deduplication workflow', () {
      // Simulate a complete import workflow
      importedServers = [
        const Spi(
          name: 'production-web', // Name conflicts with existing
          ip: '192.168.1.400', // Different IP, so not a duplicate
          port: 22,
          user: 'root',
        ),
        const Spi(
          name: 'new-staging',
          ip: '192.168.1.100', // Same as existing1, should be removed
          port: 22,
          user: 'root',
        ),
        const Spi(
          name: 'unique-server',
          ip: '192.168.1.500', // Unique server
          port: 22,
          user: 'admin',
        ),
      ];

      // Step 1: Remove duplicates
      final deduplicated = _mockDeduplicateServers(importedServers, existingServers);

      expect(deduplicated, hasLength(2)); // new-staging should be removed

      // Step 2: Resolve name conflicts
      final resolved = _mockResolveNameConflicts(
        deduplicated,
        existingServers.map((s) => s.name).toList(),
      );

      expect(resolved, hasLength(2));
      expect(resolved.any((s) => s.name == 'production-web (2)'), isTrue);
      expect(resolved.any((s) => s.name == 'unique-server'), isTrue);

      // Step 3: Get summary
      final summary = ServerDeduplication.getImportSummary(
        importedServers,
        resolved,
      );

      expect(summary.total, 3);
      expect(summary.duplicates, 1);
      expect(summary.toImport, 2);
    });

    test('deduplication key generation is consistent', () {
      const server1 = Spi(
        name: 'test1',
        ip: '192.168.1.100',
        port: 22,
        user: 'root',
      );

      const server2 = Spi(
        name: 'test2', // Different name
        ip: '192.168.1.100', // Same IP
        port: 22, // Same port
        user: 'root', // Same user
      );

      final servers = [server1, server2];
      final deduplicated = _mockDeduplicateServers(servers, []);

      // First server should be kept, second should be removed since it has same ip:port@user
      expect(deduplicated, hasLength(1));
      expect(deduplicated.first.name, 'test1');
    });

    test('ImportSummary properties work correctly', () {
      final summary = ServerDeduplication.getImportSummary(
        [
          const Spi(name: 'server1', ip: '192.168.1.100', port: 22, user: 'root'),
          const Spi(name: 'server2', ip: '192.168.1.200', port: 22, user: 'admin'),
        ],
        [
          const Spi(name: 'server2', ip: '192.168.1.200', port: 22, user: 'admin'),
        ],
      );

      expect(summary.total, 2);
      expect(summary.duplicates, 1);
      expect(summary.toImport, 1);
      expect(summary.hasDuplicates, isTrue);
      expect(summary.hasItemsToImport, isTrue);
    });

    test('ImportSummary with no duplicates or imports', () {
      final summary = ServerDeduplication.getImportSummary([], []);

      expect(summary.total, 0);
      expect(summary.duplicates, 0);
      expect(summary.toImport, 0);
      expect(summary.hasDuplicates, isFalse);
      expect(summary.hasItemsToImport, isFalse);
    });
  });
}