import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
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
      while (existingNames.contains(newName) ||
          processedNames.contains(newName)) {
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
  static ImportSummary getImportSummary(
    List<Spi> originalList,
    List<Spi> deduplicatedList,
  ) {
    final duplicateCount = originalList.length - deduplicatedList.length;
    return ImportSummary(
      total: originalList.length,
      duplicates: duplicateCount,
      toImport: deduplicatedList.length,
    );
  }

  /// Import servers with deduplication and show appropriate notifications
  /// Returns the number of servers actually imported
  /// Note: Caller must check mounted before calling this method
  /// If resolvedServers is provided, it should be pre-filtered (non-empty)
  /// [originalCount] should be provided when passing resolvedServers to show
  /// the true pre-dedup count in messages
  static Future<int> importServersWithNotification({
    List<Spi>? servers,
    required WidgetRef ref,
    required BuildContext context,
    List<Spi>? resolvedServers,
    int? originalCount,
    required String Function(String) allExistMessage,
    required String Function(String) importedMessage,
  }) async {
    assert(
      servers != null || resolvedServers != null,
      'Either servers or resolvedServers must be provided',
    );

    final count = originalCount ?? servers?.length ?? resolvedServers!.length;
    final resolved = resolvedServers ?? _resolveServers(servers!);

    if (resolved.isEmpty) {
      context.showSnackBar(allExistMessage('$count'));
      return 0;
    }

    for (final server in resolved) {
      ref.read(serversProvider.notifier).addServer(server);
    }
    context.showSnackBar(importedMessage('${resolved.length}'));
    return resolved.length;
  }

  static List<Spi> _resolveServers(List<Spi> servers) {
    final deduplicated = deduplicateServers(servers);
    final resolved = resolveNameConflicts(deduplicated);
    return resolved;
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
