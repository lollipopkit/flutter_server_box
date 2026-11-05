import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/stores.dart';

class ServerDeduplication {
  /// Removes imported servers that match an existing server, or one accepted
  /// earlier in the same batch.
  static List<Spi> deduplicateServers(
    List<Spi> importedServers, {
    List<Spi>? existingServers,
  }) {
    final existing = existingServers ?? Stores.server.fetch();
    final deduplicated = <Spi>[];

    for (final imported in importedServers) {
      if (!_isDuplicate(imported, existing) &&
          !_isDuplicate(imported, deduplicated)) {
        deduplicated.add(imported);
      }
    }

    return deduplicated;
  }

  /// Whether [imported] matches any server in [existing].
  static bool _isDuplicate(Spi imported, List<Spi> existing) {
    for (final existingSpi in existing) {
      if (imported.isSameAs(existingSpi)) {
        return true;
      }
    }

    return false;
  }

  /// Resolves name conflicts by appending numeric suffixes.
  static List<Spi> resolveNameConflicts(
    List<Spi> importedServers, {
    List<Spi>? existingServers,
  }) {
    final existing = existingServers ?? Stores.server.fetch();
    final existingNames = existing.map((s) => s.name).toSet();
    final processedNames = <String>{};
    final result = <Spi>[];

    for (final server in importedServers) {
      // Avoid conflicts with stored servers and earlier entries in this batch.
      final newName = uniqueName(
        server.name,
        taken: (name) =>
            existingNames.contains(name) || processedNames.contains(name),
      );

      processedNames.add(newName);

      if (newName != server.name) {
        result.add(server.copyWith(name: newName));
      } else {
        result.add(server);
      }
    }

    return result;
  }

  /// `name`, or the first `name (n)` that [taken] does not claim.
  ///
  /// Extracted because importing one shared server renames two kinds of record
  /// -- the server here and its private key in `ServerShareInstaller` -- and
  /// the two loops had picked different starting numbers. One collision came
  /// out as a server named `web (1)` beside a key named `laptop (2)`.
  static String uniqueName(
    String name, {
    required bool Function(String) taken,
  }) {
    if (!taken(name)) return name;
    for (var n = 1; ; n++) {
      final candidate = '$name ($n)';
      if (!taken(candidate)) return candidate;
    }
  }

  /// Summarizes how many imported servers remain after deduplication.
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
