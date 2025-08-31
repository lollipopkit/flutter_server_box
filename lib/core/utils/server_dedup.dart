import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/server.dart';

class ServerDeduplication {
  /// Remove duplicate servers from the import list based on existing servers
  /// Returns the deduplicated list
  static List<Spi> deduplicateServers(List<Spi> importedServers) {
    final existingServers = ServerStore.instance.fetch();
    final deduplicated = <Spi>[];
    
    for (final imported in importedServers) {
      if (!_isDuplicate(imported, existingServers)) {
        deduplicated.add(imported);
      }
    }
    
    return deduplicated;
  }
  
  /// Check if an imported server is a duplicate of an existing server
  static bool _isDuplicate(Spi imported, List<Spi> existing) {
    for (final existingSpi in existing) {
      if (imported.isSameAs(existingSpi)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Resolve name conflicts by appending suffixes
  static List<Spi> resolveNameConflicts(List<Spi> importedServers) {
    final existingServers = ServerStore.instance.fetch();
    final existingNames = existingServers.map((s) => s.name).toSet();
    final processedNames = <String>{};
    final result = <Spi>[];
    
    for (final server in importedServers) {
      String newName = server.name;
      int suffix = 1;
      
      // Check against both existing servers and already processed servers
      while (existingNames.contains(newName) || processedNames.contains(newName)) {
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
  
  /// Get summary of import operation
  static ImportSummary getImportSummary(List<Spi> originalList, List<Spi> deduplicatedList) {
    final duplicateCount = originalList.length - deduplicatedList.length;
    return ImportSummary(
      total: originalList.length,
      duplicates: duplicateCount,
      toImport: deduplicatedList.length,
    );
  }
}

class ImportSummary {
  final int total;
  final int duplicates;
  final int toImport;
  
  const ImportSummary({
    required this.total,
    required this.duplicates,
    required this.toImport,
  });
  
  bool get hasDuplicates => duplicates > 0;
  bool get hasItemsToImport => toImport > 0;
}