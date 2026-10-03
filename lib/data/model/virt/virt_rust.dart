import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';

/// `sbm_virt::model::HostView` JSON (snake_case, the agent's wire format) read
/// into this app's models. What a guest offers, its state and its usage are
/// decided in Rust for both backends; this only carries them over.
abstract final class VirtRust {
  static VirtSnapshot snapshot(Object? json, {required String serverId}) {
    if (json is! Map) throw _invalid('host view');
    final host = json['host'];
    final guests = json['guests'];
    final stats = json['stats'];
    final caps = json['capabilities'];
    if (host is! Map || guests is! List || stats is! Map || caps is! Map) {
      throw _invalid('host view');
    }
    return VirtSnapshot(
      host: VirtHost(
        serverId: serverId,
        kind: _hostKind(host['kind']),
        version: host['version'] as String?,
        hypervisor: host['hypervisor'] as String?,
        nodes: [
          for (final n in (host['nodes'] as List? ?? const []).whereType<Map>())
            VirtNode(
              name: n['name'] as String,
              online: n['online'] as bool? ?? true,
              cpu: (n['cpu'] as num?)?.toDouble(),
              maxCpu: n['max_cpu'] as int?,
              memUsed: n['mem_used'] as int?,
              memTotal: n['mem_total'] as int?,
              uptime: _seconds(n['uptime']),
            ),
        ],
      ),
      guests: [for (final g in guests.whereType<Map>()) guest(g)],
      stats: {
        for (final MapEntry(:key, :value) in stats.entries)
          if (key is String && value is Map) key: _stats(value),
      },
      capabilities: capabilities(caps),
    );
  }

  static VirtGuest guest(Map g) => VirtGuest(
    id: g['id'] as String,
    name: g['name'] as String,
    kind: g['kind'] == 'lxc' ? VirtGuestKind.lxc : VirtGuestKind.qemu,
    state: _state(g['state']),
    stateReason: g['state_reason'] as String?,
    vmid: g['vmid'] as int?,
    node: g['node'] as String?,
    vcpu: g['vcpu'] as int?,
    memBytes: g['mem_bytes'] as int?,
    uptime: _seconds(g['uptime']),
    tags: [...(g['tags'] as List? ?? const []).whereType<String>()],
    template: g['template'] as bool? ?? false,
    autostart: g['autostart'] as bool?,
    actions: {
      for (final a in (g['actions'] as List? ?? const []).whereType<String>())
        ?_action(a),
    },
  );

  static VirtStats _stats(Map s) => VirtStats(
    at: DateTime.fromMillisecondsSinceEpoch(s['at'] as int),
    cpu: (s['cpu'] as num?)?.toDouble(),
    memUsed: s['mem_used'] as int?,
    memTotal: s['mem_total'] as int?,
    diskUsed: s['disk_used'] as int?,
    diskTotal: s['disk_total'] as int?,
    diskRead: (s['disk_read'] as num?)?.toDouble(),
    diskWrite: (s['disk_write'] as num?)?.toDouble(),
    netIn: (s['net_in'] as num?)?.toDouble(),
    netOut: (s['net_out'] as num?)?.toDouble(),
  );

  static VirtCapabilities capabilities(Map c) {
    bool b(String key) => c[key] == true;
    List<String> l(String key) => [...(c[key] as List? ?? const []).whereType<String>()];
    return VirtCapabilities(
      lxc: b('lxc'),
      pause: b('pause'),
      snapshots: b('snapshots'),
      snapshotMemoryRequired: b('snapshot_memory_required'),
      snapshotExternal: b('snapshot_external'),
      snapshotSupported: b('snapshot_supported'),
      storage: b('storage'),
      network: b('network'),
      backup: b('backup'),
      clone: b('clone'),
      linkedClone: b('linked_clone'),
      template: b('template'),
      cloneTarget: b('clone_target'),
      backupJobs: b('backup_jobs'),
      cluster: b('cluster'),
      serialConsole: b('serial_console'),
      vncConsole: b('vnc_console'),
      termConsole: b('term_console'),
      storedHistory: b('stored_history'),
      create: b('create'),
      deleteKeepsDisks: b('delete_keeps_disks'),
      hardware: b('hardware'),
      hardwareRevert: b('hardware_revert'),
      hardwareRevertPending: b('hardware_revert_pending'),
      storageEdit: b('storage_edit'),
      poolTypes: l('pool_types'),
      poolAutostart: b('pool_autostart'),
      poolDeleteStorage: b('pool_delete_storage'),
      volumeResize: b('volume_resize'),
      volumeClone: b('volume_clone'),
      upload: b('upload'),
      networkEdit: b('network_edit'),
      networkModes: l('network_modes'),
      networkStart: b('network_start'),
      networkApply: b('network_apply'),
      networkEditExisting: b('network_edit_existing'),
      networkRestart: b('network_restart'),
    );
  }

  /// The wire name of [action] (`force_stop`).
  static String actionName(VirtPowerAction action) => switch (action) {
    VirtPowerAction.forceStop => 'force_stop',
    _ => action.name,
  };

  static VirtPowerAction? _action(String name) => switch (name) {
    'start' => VirtPowerAction.start,
    'shutdown' => VirtPowerAction.shutdown,
    'reboot' => VirtPowerAction.reboot,
    'force_stop' => VirtPowerAction.forceStop,
    'suspend' => VirtPowerAction.suspend,
    'resume' => VirtPowerAction.resume,
    _ => null,
  };

  static VirtGuestState _state(Object? name) =>
      VirtGuestState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => VirtGuestState.unknown,
      );

  static VirtHostKind _hostKind(Object? name) =>
      name == 'pve' ? VirtHostKind.pve : VirtHostKind.libvirt;

  static Duration? _seconds(Object? v) =>
      v is int && v > 0 ? Duration(seconds: v) : null;

  static VirtErr _invalid(String what) =>
      VirtErr(type: VirtErrType.invalidResponse, message: 'Unreadable $what');
}
