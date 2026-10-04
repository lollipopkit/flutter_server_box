
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';

/// Reading PVE API answers into the Virtualization models. Pure functions,
/// tested against captured payloads.
///
/// Lenient where the parser it replaced (the PVE page's `PveRes`) was strict:
/// a field missing from one entry (a guest being created has no name yet, an offline node no
/// figures) costs that field, not the whole listing.
abstract final class PveResources {
  /// `GET /nodes/{node}/storage` for [node], with what `GET /storage` (the
  /// cluster's storage configuration, [config]) says of where each one is.
  // TODO(migration): `sbm_virt::pve::resources::parse_storages`; here for the
  // backup storages only, until backups move (#1623 item 5.7).
  static List<VirtStoragePool> parseStorages(
    String node,
    List<Object?> raw, {
    List<Object?>? config,
  }) {
    final configs = <String, Map<String, Object?>>{};
    for (final c in config ?? const <Object?>[]) {
      if (c is! Map) continue;
      final id = _str(c['storage']);
      if (id != null) configs[id] = c.cast<String, Object?>();
    }
    final out = <VirtStoragePool>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final name = _str(e['storage']);
      if (name == null) continue;
      final c = configs[name] ?? const <String, Object?>{};
      final type = _str(e['type']) ?? _str(c['type']) ?? '';
      final total = _positive(_int(e['total']));
      out.add(
        VirtStoragePool(
          id: '$node/$name',
          name: name,
          node: node,
          type: type,
          path: _storagePath(type, c),
          source: _storageSource(c),
          capacity: total,
          used: total == null ? null : _int(e['used']),
          available: total == null ? null : _int(e['avail']),
          active: _int(e['active']) == 1,
          enabled: switch (_int(e['enabled'])) {
            null => null,
            final v => v == 1,
          },
          shared: _int(e['shared']) == 1,
          content: [
            for (final c in (_str(e['content']) ?? _str(c['content']) ?? '')
                .split(','))
              if (c.trim().isNotEmpty) c.trim(),
          ]..sort(),
        ),
      );
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// `GET /nodes/{node}/storage/{storage}/content?content=backup`: the
  /// backups on [storage], newest first. `verification` is an object where a
  /// verify job has looked at one.
  static List<VirtBackup> parseBackups(
    String node,
    String storage,
    List<Object?> raw,
  ) {
    final out = <VirtBackup>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final id = _str(e['volid']);
      if (id == null || (_str(e['content']) ?? 'backup') != 'backup') continue;
      final ctime = _int(e['ctime']);
      final verification = e['verification'];
      out.add(
        VirtBackup(
          id: id,
          storage: storage,
          node: node,
          vmid: _int(e['vmid']),
          createdAt: ctime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(ctime * 1000),
          size: _positive(_int(e['size'])),
          format: _str(e['format']),
          notes: _str(e['notes']),
          protected: _int(e['protected']) == 1,
          verification: verification is Map
              ? _str(verification['state'])
              : null,
          kind: switch (_str(e['subtype'])) {
            'qemu' => VirtGuestKind.qemu,
            'lxc' => VirtGuestKind.lxc,
            _ => null,
          },
        ),
      );
    }
    out.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return out;
  }

  /// `GET /cluster/backup`: the vzdump jobs. With [vmid], only those that
  /// take it — every guest of the node (`all`, less `exclude`), it in
  /// `vmid`, or every guest of its pool (whose members are not in this
  /// answer, so one that takes the guest by pool is left out of a guest's
  /// own Plan group); with [node], the guest's, not those restricted to
  /// another node ([VirtBackupJob.takes]).
  static List<VirtBackupJob> parseBackupJobs(
    List<Object?> raw, {
    int? vmid,
    String? node,
  }) {
    final out = <VirtBackupJob>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final id = _str(e['id']);
      if (id == null || (_str(e['type']) ?? 'vzdump') != 'vzdump') continue;
      final prune = e['prune-backups'];
      final job = VirtBackupJob(
        id: id,
        schedule: _str(e['schedule']) ?? _str(e['starttime']),
        storage: _str(e['storage']),
        mode: _str(e['mode']),
        compress: _str(e['compress']),
        keep: pruneString(prune),
        enabled: _int(e['enabled']) != 0,
        all: _int(e['all']) == 1,
        vmids: _intList(e['vmid']),
        exclude: _intList(e['exclude']),
        pool: _str(e['pool']),
        node: _str(e['node']),
        comment: _str(e['comment']),
        notesTemplate: _str(e['notes-template']),
        mailNotification: _str(e['mailnotification']),
        prune: pruneString(prune),
      );
      if (vmid != null && !job.takes(vmid, node: node)) continue;
      out.add(job);
    }
    return out;
  }

  /// PVE's `prune-backups` as one property string: an object
  /// (`{keep-last: "7"}`) or the string it is stored as.
  static String? pruneString(Object? raw) => switch (raw) {
    final Map m when m.isNotEmpty => [
      for (final MapEntry(:key, :value) in m.entries) '$key=$value',
    ].join(','),
    final String p when p.isNotEmpty => p,
    _ => null,
  };

  /// The `vzdump` request a job's "Run now" sends, from the job as
  /// `GET /cluster/backup/{id}` has it: what PVE's own web UI sends
  /// (`run_backup_now`, pve-manager 9.2) — every field but the ones that
  /// describe the schedule, `all` as `1`/`0`, and the fields PVE answers as
  /// objects (`performance`, `prune-backups`, `fleecing`) as the property
  /// strings `vzdump` takes.
  static Map<String, Object?> vzdumpOfJob(Map<String, Object?> job) => {
    for (final MapEntry(:key, :value) in job.entries)
      if (!_jobScheduleKeys.contains(key) && value != null)
        key: switch (value) {
          _ when key == 'all' => value == true || value == 1 || value == '1' ? 1 : 0,
          final Map m => [
            for (final MapEntry(:key, :value) in m.entries) '$key=$value',
          ].join(','),
          _ => value,
        },
  };

  static const _jobScheduleKeys = {
    'enabled',
    'starttime',
    'dow',
    'id',
    'schedule',
    'type',
    'node',
    'comment',
    'next-run',
    'repeat-missed',
  };

  /// A comma-separated list of VMIDs, as PVE stores `vmid` and `exclude`.
  /// Null and an empty string are both "none", `all` names no single guest,
  /// and anything that is not a number is skipped rather than costing the
  /// listing.
  static List<int> _intList(Object? raw) {
    if (raw is List) return [for (final v in raw) ?_int(v)];
    final text = _str(raw);
    if (text == null || text.isEmpty || text == 'all') return const [];
    return [
      for (final part in text.split(',')) ?int.tryParse(part.trim()),
    ];
  }

  /// Where a storage keeps its volumes, by its type's configuration keys.
  static String? _storagePath(String type, Map<String, Object?> c) {
    if (_str(c['path']) case final path?) return path;
    final vg = _str(c['vgname']);
    final thin = _str(c['thinpool']);
    if (vg != null) return thin == null ? vg : '$vg/$thin';
    return _str(c['pool']) ?? _str(c['datastore']);
  }

  /// Where a network storage comes from.
  static String? _storageSource(Map<String, Object?> c) {
    final server = _str(c['server']) ?? _str(c['portal']);
    final export = _str(c['export']) ?? _str(c['share']) ?? _str(c['target']);
    if (server != null && export != null) return '$server:$export';
    return server ?? _str(c['monhost']);
  }

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static int? _positive(int? v) => v == null || v <= 0 ? null : v;

}
