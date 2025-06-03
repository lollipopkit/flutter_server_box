import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

class ServerStore extends HiveStore {
  ServerStore._() : super('server');

  static final instance = ServerStore._();

  void put(Spi info) {
    set(info.id, info);
  }

  List<Spi> fetch() {
    final List<Spi> ss = [];
    for (final id in keys()) {
      final s = get<Spi>(
        id,
        fromObj: (val) {
          if (val is Spi) return val;
          if (val is Map<dynamic, dynamic>) {
            final map = val.toStrDynMap;
            if (map == null) return null;
            try {
              final spi = Spi.fromJson(map as Map<String, dynamic>);
              put(spi);
              return spi;
            } catch (e) {
              dprint('Parsing Spi from JSON', e);
            }
          }
          return null;
        },
      );
      if (s != null) {
        ss.add(s);
      }
    }
    return ss;
  }

  void delete(String id) {
    remove(id);
  }

  void update(Spi old, Spi newInfo) {
    if (!have(old)) {
      throw Exception('Old spi: $old not found');
    }
    delete(old.id);
    put(newInfo);
  }

  bool have(Spi s) => get(s.id) != null;

  void migrateIds() {
    final ss = fetch();
    final idMap = <String, String>{};

    // Collect all old to new ID mappings
    for (final s in ss) {
      final newId = s.migrateId();
      if (newId == null) continue;
      // Use s.oldId as the key, because s.id would be empty for a server being migrated.
      // s.oldId represents the identifier used before migration.
      idMap[s.oldId] = newId;
    }

    final srvOrder = SettingStore.instance.serverOrder.fetch();
    final snippets = SnippetStore.instance.fetch();
    final container = ContainerStore.instance;

    bool srvOrderChanged = false;
    // Update all references to the servers
    for (final e in idMap.entries) {
      final oldId = e.key;
      final newId = e.value;

      // Replace ids in ordering settings.
      final srvIdx = srvOrder.indexOf(oldId);
      if (srvIdx != -1) {
        srvOrder[srvIdx] = newId;
        srvOrderChanged = true;
      }

      // Replace ids in jump server settings.
      final spi = get<Spi>(newId);
      if (spi != null) {
        final jumpId = spi.jumpId; // This could be an oldId.
        // Check if this jumpId corresponds to a server that was also migrated.
        if (jumpId != null && idMap.containsKey(jumpId)) {
          final newJumpId = idMap[jumpId];
          if (spi.jumpId != newJumpId) {
            final newSpi = spi.copyWith(jumpId: newJumpId);
            update(spi, newSpi);
          }
        }
      }

      // Replace ids in [Snippet]
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

      // Replace ids in [Container]
      final dockerHost = container.fetch(oldId);
      if (dockerHost != null) {
        container.remove(oldId);
        container.set(newId, dockerHost);
      }
    }

    if (srvOrderChanged) {
      SettingStore.instance.serverOrder.put(srvOrder);
    }
  }
}
