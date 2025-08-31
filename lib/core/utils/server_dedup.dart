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
      // Check for exact match on ip:port@user combination
      if (existingSpi.ip == imported.ip && 
          existingSpi.port == imported.port && 
          existingSpi.user == imported.user) {
        return true;
      }
      
      // Check for name conflict (same name but different connection details)
      if (existingSpi.name == imported.name &&
          (existingSpi.ip != imported.ip || 
           existingSpi.port != imported.port || 
           existingSpi.user != imported.user)) {
        // This is a name conflict but not the same server
        // We'll keep the imported one with a modified name
        return false;
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