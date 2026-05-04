import 'package:server_box/data/model/server/server_private_info.dart';

/// Returns `true` when assigning [candidateJumpId] to [currentServerId]
/// would create a jump-server cycle.
bool wouldCreateJumpCycle({
  required String? currentServerId,
  required String? candidateJumpId,
  required Map<String, Spi> serversById,
}) {
  return wouldCreateJumpCycleForCandidates(
    currentServerId: currentServerId,
    candidateJumpIds: candidateJumpId == null ? const [] : [candidateJumpId],
    serversById: serversById,
  );
}

/// Returns `true` when assigning [candidateJumpIds] to [currentServerId]
/// would create a jump-server cycle.
bool wouldCreateJumpCycleForCandidates({
  required String? currentServerId,
  required Iterable<String> candidateJumpIds,
  required Map<String, Spi> serversById,
}) {
  for (final candidateJumpId in _normalizeJumpIds(candidateJumpIds)) {
    if (_hasJumpCycleFrom(
      currentServerId: currentServerId,
      checkingId: candidateJumpId,
      serversById: serversById,
      path: <String>{},
    )) {
      return true;
    }
  }
  return false;
}

bool _hasJumpCycleFrom({
  required String? currentServerId,
  required String checkingId,
  required Map<String, Spi> serversById,
  required Set<String> path,
}) {
  if (currentServerId != null && checkingId == currentServerId) {
    return true;
  }
  if (!path.add(checkingId)) {
    // Existing malformed cycle is treated as invalid to prevent linking into it.
    return true;
  }

  final jumpSpi = serversById[checkingId];
  if (jumpSpi == null) {
    path.remove(checkingId);
    return false;
  }

  for (final nextId in jumpSpi.resolvedJumpIds) {
    if (_hasJumpCycleFrom(
      currentServerId: currentServerId,
      checkingId: nextId,
      serversById: serversById,
      path: path,
    )) {
      return true;
    }
  }

  path.remove(checkingId);
  return false;
}

/// Collects all reachable jump servers from [spi.resolvedJumpIds], keyed by server id.
Map<String, Spi> collectJumpServers({
  required Spi spi,
  required Map<String, Spi> serversById,
}) {
  final chain = <String, Spi>{};
  final visited = <String>{};
  final pending = <String>[...spi.resolvedJumpIds];

  while (pending.isNotEmpty) {
    final jumpId = pending.removeAt(0);
    if (jumpId.isEmpty || !visited.add(jumpId)) {
      continue;
    }
    final jumpSpi = serversById[jumpId];
    if (jumpSpi == null) {
      continue;
    }
    chain[jumpSpi.id] = jumpSpi;
    pending.addAll(jumpSpi.resolvedJumpIds);
  }

  return chain;
}

List<String> _normalizeJumpIds(Iterable<String> ids) {
  final normalized = <String>[];
  for (final id in ids) {
    if (id.isEmpty || normalized.contains(id)) continue;
    normalized.add(id);
    if (normalized.length >= 2) break;
  }
  return normalized;
}
