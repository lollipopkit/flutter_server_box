import 'package:server_box/data/model/server/server_private_info.dart';

/// Returns `true` when assigning [candidateJumpId] to [currentServerId]
/// would create a jump-server cycle.
bool wouldCreateJumpCycle({
  required String? currentServerId,
  required String? candidateJumpId,
  required Map<String, Spi> serversById,
}) {
  if (candidateJumpId == null || candidateJumpId.isEmpty) {
    return false;
  }

  final visited = <String>{};
  var checkingId = candidateJumpId;

  while (true) {
    if (currentServerId != null && checkingId == currentServerId) {
      return true;
    }
    if (!visited.add(checkingId)) {
      // Existing malformed cycle is treated as invalid to prevent linking into it.
      return true;
    }

    final nextId = serversById[checkingId]?.jumpId;
    if (nextId == null || nextId.isEmpty) {
      return false;
    }
    checkingId = nextId;
  }
}

/// Collects all reachable jump servers from [spi.jumpId], keyed by server id.
Map<String, Spi> collectJumpServers({
  required Spi spi,
  required Map<String, Spi> serversById,
}) {
  final chain = <String, Spi>{};
  final visited = <String>{};
  var jumpId = spi.jumpId;

  while (jumpId != null && jumpId.isNotEmpty && visited.add(jumpId)) {
    final jumpSpi = serversById[jumpId];
    if (jumpSpi == null) {
      break;
    }
    chain[jumpSpi.id] = jumpSpi;
    jumpId = jumpSpi.jumpId;
  }

  return chain;
}
