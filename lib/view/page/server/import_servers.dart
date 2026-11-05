import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/store/stores.dart';

/// Imports deduplicated servers and reports the result to the user.
///
/// Callers must ensure [context] is mounted. When [resolvedServers] is
/// provided, it must already be non-empty; pass [originalCount] to retain the
/// pre-deduplication count in user-facing messages.
Future<int> importServersWithNotification({
  List<Spi>? servers,
  required WidgetRef ref,
  required BuildContext context,
  List<Spi>? resolvedServers,
  int? originalCount,
  required String Function(int) allExistMessage,
  required String Function(int) importedMessage,
}) async {
  assert(
    servers != null || resolvedServers != null,
    'Either servers or resolvedServers must be provided',
  );

  final count = originalCount ?? servers?.length ?? resolvedServers!.length;
  final resolved = resolvedServers ?? _resolveServers(servers!);

  if (resolved.isEmpty) {
    Toast.show(allExistMessage(count));
    return 0;
  }

  for (final server in resolved) {
    await ref.read(serversProvider.notifier).addServer(server);
  }
  Toast.show(importedMessage(resolved.length));
  return resolved.length;
}

List<Spi> _resolveServers(List<Spi> servers) {
  final existing = Stores.server.fetch();
  final deduplicated = ServerDeduplication.deduplicateServers(servers, existingServers: existing);
  final resolved = ServerDeduplication.resolveNameConflicts(
    deduplicated,
    existingServers: existing,
  );
  return resolved;
}
