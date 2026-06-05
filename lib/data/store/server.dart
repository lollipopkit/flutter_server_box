import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/cached_store.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

class ServerStore extends CachedHiveStore<Spi> {
  ServerStore._() : super('server');

  static final instance = ServerStore._();

  @override
  String getKey(Spi item) => item.id;

  @override
  Spi? fromJson(Map<String, dynamic> json) => Spi.fromJson(json);

  void migrateIds() {
    final ss = fetch();
    final idMap = <String, String>{};

    for (final s in ss) {
      final newId = s.migrateId();
      if (newId == null) continue;
      idMap[s.oldId] = newId;
    }

    final srvOrder = SettingStore.instance.serverOrder.fetch();
    final snippets = SnippetStore.instance.fetch();
    final container = ContainerStore.instance;

    bool srvOrderChanged = false;
    for (final e in idMap.entries) {
      final oldId = e.key;
      final newId = e.value;

      final srvIdx = srvOrder.indexOf(oldId);
      if (srvIdx != -1) {
        srvOrder[srvIdx] = newId;
        srvOrderChanged = true;
      }

      final spi = get<Spi>(newId);
      if (spi != null) {
        final newSpi = _replaceJumpIds(spi, idMap);
        if (newSpi != null) {
          update(spi, newSpi);
        }
      }

      for (final snippet in snippets) {
        final autoRunsOn = snippet.autoRunOn;
        final idx = autoRunsOn?.indexOf(oldId);
        if (idx != null && idx != -1) {
          final newAutoRunsOn = List<String>.from(autoRunsOn ?? []);
          newAutoRunsOn[idx] = newId;
          final newSnippet = snippet.copyWith(autoRunOn: newAutoRunsOn);
          SnippetStore.instance.update(snippet, newSnippet);
        }
      }

      final dockerHost = container.fetch(oldId);
      if (dockerHost != null) {
        container.remove(oldId);
        container.set(newId, dockerHost);
      }
    }

    for (final spi in ss) {
      if (get(spi.id) == null) continue;
      final newSpi = _replaceJumpIds(spi, idMap);
      if (newSpi != null) {
        update(spi, newSpi);
      }
    }

    if (srvOrderChanged) {
      SettingStore.instance.serverOrder.put(srvOrder);
    }
  }
}

Spi? _replaceJumpIds(Spi spi, Map<String, String> idMap) {
  var changed = false;
  final resolvedJumpIds = spi.resolvedJumpIds;
  final newJumpIds = resolvedJumpIds.map((id) {
    final newId = idMap[id];
    if (newId == null) return id;
    changed = true;
    return newId;
  }).toList();

  final newJumpId = spi.jumpId != null && idMap.containsKey(spi.jumpId)
      ? idMap[spi.jumpId]
      : spi.jumpId;
  changed = changed || newJumpId != spi.jumpId;

  if (!changed) return null;
  return spi.copyWith(
    jumpId: newJumpIds.isEmpty ? newJumpId : newJumpIds.first,
    jumpIds: newJumpIds.isEmpty ? null : newJumpIds,
  );
}
