part of 'edit.dart';

extension _JumpChain on _ServerEditPageState {
  Widget _buildJumpChain() {
    final serversState = ref.watch(serversProvider);
    final servers = serversState.servers;
    final selfId = spi?.id;

    if (selfId == null) {
      return ListTile(
        leading: const Icon(Icons.map),
        title: Text(l10n.jumpServer),
        subtitle: Text(libL10n.empty, style: UIs.textGrey),
      ).cardx;
    }

    String serverNameOrId(String id) {
      return servers[id]?.name ?? id;
    }

    List<String> flattenHopIds(String id, {required Set<String> visited}) {
      if (!visited.add(id)) return const <String>[];
      final spi = servers[id];
      if (spi == null) return const <String>[];

      final hops = spi.jumpChainIds;
      if (hops == null || hops.isEmpty) return const <String>[];

      final flat = <String>[];
      for (final hopId in hops) {
        flat.add(hopId);
        flat.addAll(flattenHopIds(hopId, visited: visited));
      }
      return flat;
    }

    bool containsCycleWithCandidate(String candidateId) {
      final visited = <String>{selfId};
      final queue = [..._jumpChain.value, candidateId];

      for (final hopId in queue) {
        if (hopId == selfId) return true;
        if (!visited.add(hopId)) return true;
      }

      for (final hopId in queue) {
        final extra = flattenHopIds(hopId, visited: visited);
        for (final id in extra) {
          if (id == selfId) return true;
        }
      }
      return false;
    }

    String? buildTextNearToFar() {
      if (_jumpChain.value.isEmpty) return null;
      final flat = <String>[];
      final visited = <String>{selfId};
      for (final hopId in _jumpChain.value) {
        flat.add(hopId);
        flat.addAll(flattenHopIds(hopId, visited: visited));
      }
      final names = flat.map(serverNameOrId).toList();
      if (names.isEmpty) return null;
      return names.join(' → ');
    }

    String? buildTextFarToNear() {
      final text = buildTextNearToFar();
      if (text == null) return null;
      return text.split(' → ').reversed.join(' → ');
    }

    return _jumpChain.listenVal((_) {
      final nearToFar2 = buildTextNearToFar();
      final farToNear2 = buildTextFarToNear();

      return ListTile(
        leading: const Icon(Icons.map),
        title: Text(l10n.jumpServer),
        subtitle: (nearToFar2 == null)
            ? Text(libL10n.empty, style: UIs.textGrey)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${l10n.route}: $nearToFar2', style: UIs.textGrey),
                  Text('${libL10n.path}: $farToNear2', style: UIs.textGrey),
                ],
              ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () async {
          if (serversState.serverOrder.isEmpty) {
            context.showSnackBar(libL10n.empty);
            return;
          }

          final candidates = serversState.serverOrder.where((e) => e != selfId).toList();
          if (candidates.isEmpty) {
            context.showSnackBar(libL10n.empty);
            return;
          }

          // Add a hop
          final nextHop = await context.showPickSingleDialog<String>(
            title: '${l10n.jumpServer} (+1)',
            items: candidates.where((id) => !containsCycleWithCandidate(id)).toList(),
            display: serverNameOrId,
            clearable: true,
          );
          if (nextHop == null) return;

          _jumpChain.value = [..._jumpChain.value, nextHop];

          // If user wants to manage order/remove, offer a simple editor dialog
          await context.showRoundDialog<void>(
            title: l10n.jumpServer,
            child: SizedBox(
              width: 320,
              child: _jumpChain.listenVal((hops) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: hops.length,
                  itemBuilder: (context, index) {
                    final id = hops[index];
                    return ListTile(
                      title: Text(serverNameOrId(id)),
                      subtitle: Text(id, style: UIs.textGrey),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: index == 0
                                ? null
                                : () {
                                    final list = [..._jumpChain.value];
                                    final tmp = list[index - 1];
                                    list[index - 1] = list[index];
                                    list[index] = tmp;
                                    _jumpChain.value = list;
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: index == hops.length - 1
                                ? null
                                : () {
                                    final list = [..._jumpChain.value];
                                    final tmp = list[index + 1];
                                    list[index + 1] = list[index];
                                    list[index] = tmp;
                                    _jumpChain.value = list;
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () {
                              final list = [..._jumpChain.value]..removeAt(index);
                              _jumpChain.value = list;
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
            actions: Btnx.oks,
          );
        },
      ).cardx;
    });
  }
}
