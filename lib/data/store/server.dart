import 'dart:convert';

import 'package:drift/drift.dart' as d;
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/db/app_db.dart' as adb;
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';

class ServerStore {
  ServerStore._();

  static final instance = ServerStore._();

  adb.AppDb get _db => adb.AppDb.instance;

  Future<void> put(Spi info) async {
    await _upsert(info);
  }

  Future<List<Spi>> fetch() async {
    final rows = await _db.select(_db.servers).get();
    if (rows.isEmpty) return const <Spi>[];
    return _composeSpis(rows);
  }

  Future<Spi?> fetchOne(String id) async {
    return _readSpi(id);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.servers)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> update(Spi old, Spi newInfo) async {
    if (!await have(old)) {
      throw Exception('Old spi: $old not found');
    }

    if (old.id != newInfo.id) {
      await delete(old.id);
    }
    await put(newInfo);
  }

  Future<bool> have(Spi s) async => await fetchOne(s.id) != null;

  Future<Set<String>> keys() async {
    final rows = _db.selectOnly(_db.servers)..addColumns([_db.servers.id]);
    final result = await rows.get();
    return result
        .map((row) => row.read(_db.servers.id))
        .whereType<String>()
        .toSet();
  }

  Future<void> clear() async {
    await _db.delete(_db.servers).go();
  }

  Future<void> migrateIds() async {
    // IDs are now normalized on write during migration into ORM tables.
    final ss = await fetch();
    if (ss.isEmpty) return;

    final idMap = <String, String>{};
    for (final s in ss) {
      final currentId = s.id;
      final legacyId = currentId.isEmpty ? s.oldId : currentId;
      final shouldMigrate = currentId.isEmpty || currentId == s.oldId;
      if (!shouldMigrate) continue;

      final newId = ShortId.generate();
      final migrated = s.copyWith(id: newId);

      if (legacyId != newId) {
        await delete(legacyId);
      }
      await put(migrated);
      idMap[legacyId] = newId;
    }

    if (idMap.isEmpty) return;

    final srvOrder = SettingStore.instance.serverOrder.fetch();
    final snippets = await SnippetStore.instance.fetch();
    final container = ContainerStore.instance;

    var srvOrderChanged = false;
    for (final e in idMap.entries) {
      final oldId = e.key;
      final newId = e.value;

      final srvIdx = srvOrder.indexOf(oldId);
      if (srvIdx != -1) {
        srvOrder[srvIdx] = newId;
        srvOrderChanged = true;
      }

      final spi = await fetchOne(newId);
      if (spi != null) {
        final jumpId = spi.jumpId;
        if (jumpId != null && idMap.containsKey(jumpId)) {
          final newJumpId = idMap[jumpId];
          if (spi.jumpId != newJumpId) {
            final newSpi = spi.copyWith(jumpId: newJumpId);
            await update(spi, newSpi);
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
          await SnippetStore.instance.update(snippet, newSnippet);
        }
      }

      final dockerHost = await container.fetch(oldId);
      if (dockerHost != null) {
        await container.remove(oldId);
        await container.set(newId, dockerHost);
      }
    }

    if (srvOrderChanged) {
      await SettingStore.instance.serverOrder.put(srvOrder);
    }
  }

  Future<Spi?> _readSpi(String id) async {
    final server = await (_db.select(
      _db.servers,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (server == null) return null;

    final custom = await (_db.select(
      _db.serverCustoms,
    )..where((tbl) => tbl.serverId.equals(id))).getSingleOrNull();

    final wol = await (_db.select(
      _db.serverWolCfgs,
    )..where((tbl) => tbl.serverId.equals(id))).getSingleOrNull();

    final tags = await (_db.select(
      _db.serverTags,
    )..where((tbl) => tbl.serverId.equals(id))).get();

    final envs = await (_db.select(
      _db.serverEnvs,
    )..where((tbl) => tbl.serverId.equals(id))).get();

    final disabledCmds = await (_db.select(
      _db.serverDisabledCmdTypes,
    )..where((tbl) => tbl.serverId.equals(id))).get();

    final mapEnvs = envs.isEmpty
        ? null
        : <String, String>{for (final e in envs) e.envKey: e.envVal};

    final cmdMap = _decodeStringMap(custom?.cmdsJson);

    final serverCustom = custom == null
        ? null
        : ServerCustom(
            pveAddr: custom.pveAddr,
            pveIgnoreCert: custom.pveIgnoreCert,
            cmds: cmdMap,
            preferTempDev: custom.preferTempDev,
            logoUrl: custom.logoUrl,
            netDev: custom.netDev,
            scriptDir: custom.scriptDir,
          );

    final wolCfg = wol == null
        ? null
        : WakeOnLanCfg(mac: wol.mac, ip: wol.ip, pwd: wol.pwd);

    return Spi(
      id: server.id,
      name: server.name,
      ip: server.ip,
      port: server.port,
      user: server.user,
      pwd: server.pwd,
      keyId: server.keyId,
      tags: tags.map((e) => e.tag).toList(growable: false),
      alterUrl: server.alterUrl,
      autoConnect: server.autoConnect,
      jumpId: server.jumpId,
      custom: serverCustom,
      wolCfg: wolCfg,
      envs: mapEnvs,
      customSystemType: server.customSystemType == null
          ? null
          : SystemType.values.firstWhereOrNull(
              (e) => e.name == server.customSystemType,
            ),
      disabledCmdTypes: disabledCmds
          .map((e) => e.cmdType)
          .toList(growable: false),
    );
  }

  Future<List<Spi>> _composeSpis(List<adb.Server> servers) async {
    if (servers.isEmpty) return const <Spi>[];

    final ids = servers.map((e) => e.id).toList(growable: false);

    final customRows = await (_db.select(
      _db.serverCustoms,
    )..where((tbl) => tbl.serverId.isIn(ids))).get();
    final customById = <String, adb.ServerCustom>{
      for (final row in customRows) row.serverId: row,
    };

    final wolRows = await (_db.select(
      _db.serverWolCfgs,
    )..where((tbl) => tbl.serverId.isIn(ids))).get();
    final wolById = <String, adb.ServerWolCfg>{
      for (final row in wolRows) row.serverId: row,
    };

    final tagRows = await (_db.select(
      _db.serverTags,
    )..where((tbl) => tbl.serverId.isIn(ids))).get();
    final tagsById = <String, List<String>>{};
    for (final row in tagRows) {
      tagsById.putIfAbsent(row.serverId, () => <String>[]).add(row.tag);
    }

    final envRows = await (_db.select(
      _db.serverEnvs,
    )..where((tbl) => tbl.serverId.isIn(ids))).get();
    final envsById = <String, Map<String, String>>{};
    for (final row in envRows) {
      envsById.putIfAbsent(row.serverId, () => <String, String>{})[row.envKey] =
          row.envVal;
    }

    final disabledRows = await (_db.select(
      _db.serverDisabledCmdTypes,
    )..where((tbl) => tbl.serverId.isIn(ids))).get();
    final disabledById = <String, List<String>>{};
    for (final row in disabledRows) {
      disabledById.putIfAbsent(row.serverId, () => <String>[]).add(row.cmdType);
    }

    final list = <Spi>[];
    for (final server in servers) {
      final id = server.id;
      final custom = customById[id];
      final wol = wolById[id];

      final cmdMap = _decodeStringMap(custom?.cmdsJson);
      final serverCustom = custom == null
          ? null
          : ServerCustom(
              pveAddr: custom.pveAddr,
              pveIgnoreCert: custom.pveIgnoreCert,
              cmds: cmdMap,
              preferTempDev: custom.preferTempDev,
              logoUrl: custom.logoUrl,
              netDev: custom.netDev,
              scriptDir: custom.scriptDir,
            );
      final wolCfg = wol == null
          ? null
          : WakeOnLanCfg(mac: wol.mac, ip: wol.ip, pwd: wol.pwd);

      list.add(
        Spi(
          id: server.id,
          name: server.name,
          ip: server.ip,
          port: server.port,
          user: server.user,
          pwd: server.pwd,
          keyId: server.keyId,
          tags: tagsById[id] ?? const <String>[],
          alterUrl: server.alterUrl,
          autoConnect: server.autoConnect,
          jumpId: server.jumpId,
          custom: serverCustom,
          wolCfg: wolCfg,
          envs: envsById[id],
          customSystemType: server.customSystemType == null
              ? null
              : SystemType.values.firstWhereOrNull(
                  (e) => e.name == server.customSystemType,
                ),
          disabledCmdTypes: disabledById[id] ?? const <String>[],
        ),
      );
    }
    return list;
  }

  Future<void> _upsert(Spi info) async {
    final now = DateTimeX.timestamp;
    final spi = info.id.isEmpty ? info.copyWith(id: ShortId.generate()) : info;

    await _db.transaction(() async {
      await _db
          .into(_db.servers)
          .insertOnConflictUpdate(
            adb.ServersCompanion.insert(
              id: spi.id,
              name: spi.name,
              ip: spi.ip,
              port: spi.port,
              user: spi.user,
              pwd: d.Value(spi.pwd),
              keyId: d.Value(spi.keyId),
              alterUrl: d.Value(spi.alterUrl),
              autoConnect: d.Value(spi.autoConnect),
              jumpId: d.Value(spi.jumpId),
              customSystemType: d.Value(spi.customSystemType?.name),
              updatedAt: now,
            ),
          );

      final custom = spi.custom;
      if (custom == null) {
        await (_db.delete(
          _db.serverCustoms,
        )..where((tbl) => tbl.serverId.equals(spi.id))).go();
      } else {
        await _db
            .into(_db.serverCustoms)
            .insertOnConflictUpdate(
              adb.ServerCustomsCompanion.insert(
                serverId: spi.id,
                pveAddr: d.Value(custom.pveAddr),
                pveIgnoreCert: d.Value(custom.pveIgnoreCert),
                cmdsJson: d.Value(
                  custom.cmds == null ? null : json.encode(custom.cmds),
                ),
                preferTempDev: d.Value(custom.preferTempDev),
                logoUrl: d.Value(custom.logoUrl),
                netDev: d.Value(custom.netDev),
                scriptDir: d.Value(custom.scriptDir),
                updatedAt: now,
              ),
            );
      }

      final wol = spi.wolCfg;
      if (wol == null) {
        await (_db.delete(
          _db.serverWolCfgs,
        )..where((tbl) => tbl.serverId.equals(spi.id))).go();
      } else {
        await _db
            .into(_db.serverWolCfgs)
            .insertOnConflictUpdate(
              adb.ServerWolCfgsCompanion.insert(
                serverId: spi.id,
                mac: wol.mac,
                ip: wol.ip,
                pwd: d.Value(wol.pwd),
                updatedAt: now,
              ),
            );
      }

      await (_db.delete(
        _db.serverTags,
      )..where((tbl) => tbl.serverId.equals(spi.id))).go();
      for (final tag in spi.tags ?? const <String>[]) {
        await _db
            .into(_db.serverTags)
            .insert(
              adb.ServerTagsCompanion.insert(serverId: spi.id, tag: tag),
              mode: d.InsertMode.insertOrIgnore,
            );
      }

      await (_db.delete(
        _db.serverEnvs,
      )..where((tbl) => tbl.serverId.equals(spi.id))).go();
      for (final entry in (spi.envs ?? const <String, String>{}).entries) {
        await _db
            .into(_db.serverEnvs)
            .insert(
              adb.ServerEnvsCompanion.insert(
                serverId: spi.id,
                envKey: entry.key,
                envVal: entry.value,
              ),
              mode: d.InsertMode.insertOrIgnore,
            );
      }

      await (_db.delete(
        _db.serverDisabledCmdTypes,
      )..where((tbl) => tbl.serverId.equals(spi.id))).go();
      for (final cmdType in spi.disabledCmdTypes ?? const <String>[]) {
        await _db
            .into(_db.serverDisabledCmdTypes)
            .insert(
              adb.ServerDisabledCmdTypesCompanion.insert(
                serverId: spi.id,
                cmdType: cmdType,
              ),
              mode: d.InsertMode.insertOrIgnore,
            );
      }
    });
  }

  Map<String, String>? _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return null;
    }
  }
}
