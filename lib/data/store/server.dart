import 'dart:async';

import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

class ServerStore extends HiveStore {
  ServerStore._() : super('server');

  static final instance = ServerStore._();

  List<Spi>? _cache;
  StreamSubscription<dynamic>? _boxWatchSub;

  @override
  Future<void> init() async {
    await super.init();
    _boxWatchSub?.cancel();
    _boxWatchSub = box.watch().listen((_) {
      _cache = null;
    });
  }

  void close() {
    _boxWatchSub?.cancel();
    _boxWatchSub = null;
  }

  @override
  bool clear({bool? updateLastUpdateTsOnClear}) {
    _cache = null;
    return super.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
  }

  void invalidateCache() {
    _cache = null;
  }

  void put(Spi info) {
    set(info.id, info);
    _cache = null;
  }

  List<Spi> fetch() {
    return List<Spi>.from(_cache ??= _loadAll());
  }

  List<Spi> _loadAll() {
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
    _cache = null;
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
        final jumpId = spi.jumpId;
        if (jumpId != null && idMap.containsKey(jumpId)) {
          final newJumpId = idMap[jumpId];
          if (spi.jumpId != newJumpId) {
            final newSpi = spi.copyWith(jumpId: newJumpId);
            update(spi, newSpi);
          }
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

    if (srvOrderChanged) {
      SettingStore.instance.serverOrder.put(srvOrder);
    }
  }
}