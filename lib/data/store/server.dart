import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/cached_store.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

class ServerStore extends CachedHiveStore<Spi> {
  ServerStore._() : super('server');

  /// The same seam [SettingStore.forBox] has: `init()` reaches for the
  /// platform's secure storage to get an encryption cipher, which a unit test
  /// has no implementation of.
  @visibleForTesting
  ServerStore.forBox(Box<dynamic> testBox) : super('server_test') {
    box = testBox;
  }

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

      final dockerHost = container.fetch(oldId, ContainerType.docker);
      if (dockerHost != null) {
        container.removeHost(oldId, ContainerType.docker);
        container.put(newId, ContainerType.docker, dockerHost);
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
  final ssh = spi.ssh;
  if (ssh == null) return null;

  var changed = false;
  final newJumpIds = ssh.resolvedJumpIds.map((id) {
    final newId = idMap[id];
    if (newId == null) return id;
    changed = true;
    return newId;
  }).toList();

  final oldJumpId = ssh.jumpId;
  final newJumpId = oldJumpId != null && idMap.containsKey(oldJumpId)
      ? idMap[oldJumpId]
      : oldJumpId;
  changed = changed || newJumpId != oldJumpId;

  if (!changed) return null;
  return spi.copyWith(
    ssh: ssh.copyWith(
      jumpId: newJumpIds.isEmpty ? newJumpId : newJumpIds.first,
      jumpIds: newJumpIds.isEmpty ? null : newJumpIds,
    ),
  );
}
