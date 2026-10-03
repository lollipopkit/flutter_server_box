import 'dart:convert';

import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/src/rust/api/pve.dart';

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

  /// `sbm_virt::model::GuestDetail`.
  static VirtGuestDetail detail(Object? json) {
    if (json is! Map) throw _invalid('guest detail');
    List<Map<String, dynamic>> maps(Object? v) => [
      for (final e in (v as List? ?? const []).whereType<Map>())
        Map<String, dynamic>.from(e),
    ];
    final display = json['display'];
    return VirtGuestDetail(
      disks: [for (final d in maps(json['disks'])) VirtDisk.fromJson(d)],
      nics: [for (final n in maps(json['nics'])) VirtNic.fromJson(n)],
      graphics: [for (final g in maps(json['graphics'])) VirtGraphics.fromJson(g)],
      display: display is Map
          ? VirtDisplay.fromJson(Map<String, dynamic>.from(display))
          : null,
      consoles: {
        for (final c in (json['consoles'] as List? ?? const []))
          if (c == 'text') VirtConsoleKind.text else if (c == 'vnc') VirtConsoleKind.vnc,
      },
      description: json['description'] as String?,
      arch: json['arch'] as String?,
      machine: json['machine'] as String?,
    );
  }

  /// A list of `sbm_virt::snapshot::Snapshot`.
  static List<VirtGuestSnapshot> snapshots(Object? json) {
    if (json is! List) throw _invalid('snapshots');
    return [
      for (final s in json.whereType<Map>())
        VirtGuestSnapshot(
          name: s['name'] as String,
          parent: s['parent'] as String?,
          description: s['description'] as String?,
          createdAt: switch (s['created_at']) {
            final int t => DateTime.fromMillisecondsSinceEpoch(t * 1000),
            _ => null,
          },
          current: s['current'] as bool? ?? false,
          withMemory: s['with_memory'] as bool? ?? false,
          external: s['external'] as bool? ?? false,
          layers: [
            for (final l in (s['layers'] as List? ?? const []).whereType<Map>())
              VirtSnapshotLayer(
                target: l['target'] as String,
                file: l['file'] as String?,
                external: l['external'] as bool? ?? false,
              ),
          ],
        ),
    ];
  }

  /// A list of `sbm_virt::snapshot::Diff`.
  static List<VirtSnapDiff> diff(Object? json) {
    if (json is! List) throw _invalid('snapshot diff');
    return [
      for (final d in json.whereType<Map>())
        VirtSnapDiff(
          group: VirtSnapDiffGroup.values.firstWhere(
            (g) => g.name == d['group'],
            orElse: () => VirtSnapDiffGroup.other,
          ),
          key: d['key'] as String,
          before: d['before'] as String?,
          after: d['after'] as String?,
        ),
    ];
  }

  /// `sbm_virt::snapshot::Chain`.
  static VirtSnapChain chain(Object? json) {
    if (json is! Map) throw _invalid('snapshot chain');
    return VirtSnapChain(
      pools: [...(json['pools'] as List? ?? const []).whereType<String>()],
      refusal: json['refusal'] as String?,
      externalRefusal: json['external_refusal'] as String?,
      disks: [
        for (final d in (json['disks'] as List? ?? const []).whereType<Map>())
          VirtSnapChainDisk(
            target: d['target'] as String,
            pool: d['pool'] as String?,
            error: d['error'] as String?,
            files: [
              for (final f in (d['files'] as List? ?? const []).whereType<Map>())
                VirtSnapChainFile(
                  path: f['path'] as String,
                  format: f['format'] as String?,
                  allocation: f['allocation'] as int?,
                  backing: f['backing'] as String?,
                  snap: f['snap'] as String?,
                  active: f['active'] as bool? ?? false,
                ),
            ],
          ),
      ],
    );
  }

  /// A list of `sbm_virt::model::Stats`.
  static List<VirtStats> history(Object? json) {
    if (json is! List) throw _invalid('history');
    return [for (final s in json.whereType<Map>()) _stats(s)];
  }

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

  // -------------------------------------------------------------------------
  // Storage and networks (`sbm_virt::resource`)
  // -------------------------------------------------------------------------

  static List<Map> _maps(Object? json, String what) {
    if (json is! List) throw _invalid(what);
    return [...json.whereType<Map>()];
  }

  static List<String> _strings(Object? v) => [
    ...(v as List? ?? const []).whereType<String>(),
  ];

  static VirtGuestRef guestRef(Map r) => VirtGuestRef(
    guestId: r['guest_id'] as String?,
    vmid: r['vmid'] as int?,
    device: r['device'] as String?,
    mac: r['mac'] as String?,
    ip: r['ip'] as String?,
  );

  static Map<String, Object?> guestRefJson(VirtGuestRef r) => {
    'guest_id': r.guestId,
    'vmid': r.vmid,
    'device': r.device,
    'mac': r.mac,
    'ip': r.ip,
  };

  static List<VirtGuestRef> _refs(Object? v) => [
    for (final r in (v as List? ?? const []).whereType<Map>()) guestRef(r),
  ];

  /// A list of `sbm_virt::resource::Pool`.
  static List<VirtStoragePool> pools(Object? json) => [
    for (final p in _maps(json, 'storage'))
      VirtStoragePool(
        id: p['id'] as String,
        name: p['name'] as String,
        node: p['node'] as String?,
        type: p['type'] as String? ?? '',
        path: p['path'] as String?,
        source: p['source'] as String?,
        capacity: p['capacity'] as int?,
        used: p['used'] as int?,
        available: p['available'] as int?,
        active: p['active'] as bool? ?? true,
        autostart: p['autostart'] as bool?,
        enabled: p['enabled'] as bool?,
        shared: p['shared'] as bool?,
        content: _strings(p['content']),
        volumeCount: p['volume_count'] as int?,
      ),
  ];

  static Map<String, Object?> poolJson(VirtStoragePool p) => {
    'id': p.id,
    'name': p.name,
    'node': p.node,
    'type': p.type,
    'path': p.path,
    'source': p.source,
    'capacity': p.capacity,
    'used': p.used,
    'available': p.available,
    'active': p.active,
    'autostart': p.autostart,
    'enabled': p.enabled,
    'shared': p.shared,
    'content': p.content,
    'volume_count': p.volumeCount,
  };

  /// A list of `sbm_virt::resource::Volume`.
  static List<VirtVolume> volumes(Object? json) => [
    for (final v in _maps(json, 'volumes'))
      VirtVolume(
        id: v['id'] as String,
        name: v['name'] as String,
        path: v['path'] as String?,
        format: v['format'] as String?,
        content: v['content'] as String?,
        capacity: v['capacity'] as int?,
        allocation: v['allocation'] as int?,
        backing: v['backing'] as String?,
        createdAt: switch (v['created_at']) {
          final int t => DateTime.fromMillisecondsSinceEpoch(t * 1000),
          _ => null,
        },
        users: _refs(v['users']),
        backs: _strings(v['backs']),
      ),
  ];

  static Map<String, Object?> volumeJson(VirtVolume v) => {
    'id': v.id,
    'name': v.name,
    'path': v.path,
    'format': v.format,
    'content': v.content,
    'capacity': v.capacity,
    'allocation': v.allocation,
    'backing': v.backing,
    'created_at': switch (v.createdAt) {
      final t? => t.millisecondsSinceEpoch ~/ 1000,
      null => null,
    },
    'users': [for (final r in v.users) guestRefJson(r)],
    'backs': v.backs,
  };

  /// A list of `sbm_virt::resource::Network`.
  static List<VirtNetwork> networks(Object? json) => [
    for (final n in _maps(json, 'networks'))
      VirtNetwork(
        id: n['id'] as String,
        name: n['name'] as String,
        node: n['node'] as String?,
        mode: n['mode'] as String? ?? '',
        bridge: n['bridge'] as String?,
        cidrs: _strings(n['cidrs']),
        gateway: n['gateway'] as String?,
        dhcpRanges: _strings(n['dhcp_ranges']),
        ports: _strings(n['ports']),
        vlanAware: n['vlan_aware'] as bool?,
        vlanId: n['vlan_id'] as int?,
        vlanDevice: n['vlan_device'] as String?,
        bondMode: n['bond_mode'] as String?,
        active: n['active'] as bool? ?? true,
        autostart: n['autostart'] as bool?,
        comment: n['comment'] as String?,
        hosts: [
          for (final h in (n['hosts'] as List? ?? const []).whereType<Map>())
            VirtNetHost(
              mac: h['mac'] as String,
              ip: h['ip'] as String,
              name: h['name'] as String?,
            ),
        ],
        xml: n['xml'] as String? ?? '',
        pendingRestart: n['pending_restart'] as bool? ?? false,
        managementEditable: n['management_editable'] as bool? ?? true,
        users: _refs(n['users']),
      ),
  ];

  static Map<String, Object?> networkJson(VirtNetwork n) => {
    'id': n.id,
    'name': n.name,
    'node': n.node,
    'mode': n.mode,
    'bridge': n.bridge,
    'cidrs': n.cidrs,
    'gateway': n.gateway,
    'dhcp_ranges': n.dhcpRanges,
    'ports': n.ports,
    'vlan_aware': n.vlanAware,
    'vlan_id': n.vlanId,
    'vlan_device': n.vlanDevice,
    'bond_mode': n.bondMode,
    'active': n.active,
    'autostart': n.autostart,
    'comment': n.comment,
    'hosts': [for (final h in n.hosts) _hostJson(h)],
    'xml': n.xml,
    'pending_restart': n.pendingRestart,
    'management_editable': n.managementEditable,
    'users': [for (final r in n.users) guestRefJson(r)],
  };

  static Map<String, Object?> _hostJson(VirtNetHost h) => {
    'mac': h.mac,
    'ip': h.ip,
    'name': h.name,
  };

  /// A list of `sbm_virt::resource::NetworkChanges`.
  static List<VirtNetworkChanges> networkChanges(Object? json) => [
    for (final c in _maps(json, 'network changes'))
      VirtNetworkChanges(node: c['node'] as String, diff: c['diff'] as String),
  ];

  /// [change] as `sbm_virt::resource::Change`: what it is to named by id,
  /// resolved against what the host lists when it is made.
  static Map<String, Object?> changeJson(VirtResourceChange change) =>
      switch (change) {
        VirtPoolCreate(
          :final name,
          :final type,
          :final source,
          :final target,
          :final node,
          :final content,
          :final autostart,
        ) =>
          {
            'op': 'pool_create',
            'name': name,
            'type': type,
            'source': source,
            'target': target,
            'node': node,
            'content': content,
            'autostart': autostart,
          },
        VirtPoolSetActive(:final pool, :final active) => {
          'op': 'pool_set_active',
          'pool': pool.id,
          'active': active,
        },
        VirtPoolSetAutostart(:final pool, :final on) => {
          'op': 'pool_set_autostart',
          'pool': pool.id,
          'on': on,
        },
        VirtPoolRefresh(:final pool) => {'op': 'pool_refresh', 'pool': pool.id},
        VirtPoolDelete(:final pool, :final deleteStorage) => {
          'op': 'pool_delete',
          'pool': pool.id,
          'delete_storage': deleteStorage,
        },
        VirtVolumeCreate(:final pool, :final name, :final gib, :final format) => {
          'op': 'volume_create',
          'pool': pool.id,
          'name': name,
          'gib': gib,
          'format': format,
        },
        VirtVolumeDelete(:final pool, :final volume) => {
          'op': 'volume_delete',
          'pool': pool.id,
          'volume': volume.id,
        },
        VirtVolumeResize(:final pool, :final volume, :final bytes) => {
          'op': 'volume_resize',
          'pool': pool.id,
          'volume': volume.id,
          'bytes': bytes,
        },
        VirtVolumeClone(:final pool, :final volume, :final name) => {
          'op': 'volume_clone',
          'pool': pool.id,
          'volume': volume.id,
          'name': name,
        },
        VirtNetworkCreate(
          :final name,
          :final mode,
          :final node,
          :final bridge,
          :final cidr,
          :final dhcpStart,
          :final dhcpEnd,
          :final vlanAware,
          :final autostart,
        ) =>
          {
            'op': 'network_create',
            'name': name,
            'mode': mode,
            'node': node,
            'bridge': bridge,
            'cidr': cidr,
            'dhcp_start': dhcpStart,
            'dhcp_end': dhcpEnd,
            'vlan_aware': vlanAware,
            'autostart': autostart,
          },
        VirtNetworkEdit(
          :final network,
          :final mode,
          :final bridge,
          :final address,
          :final prefix,
          :final dhcpStart,
          :final dhcpEnd,
          :final hosts,
          :final restart,
        ) =>
          {
            'op': 'network_edit',
            'network': network.id,
            'mode': mode,
            'bridge': bridge,
            'address': address,
            'prefix': prefix,
            'dhcp_start': dhcpStart,
            'dhcp_end': dhcpEnd,
            'hosts': [for (final h in hosts) _hostJson(h)],
            'restart': restart,
            // The definition the edit was made from: one changed since is
            // refused rather than overwritten.
            'base_xml': network.xml.isEmpty ? null : network.xml,
          },
        VirtNetworkEditBridge(
          :final network,
          :final ports,
          :final cidr,
          :final gateway,
          :final vlanAware,
          :final autostart,
        ) =>
          {
            'op': 'network_edit_bridge',
            'network': network.id,
            'ports': ports,
            'cidr': cidr,
            'gateway': gateway,
            'vlan_aware': vlanAware,
            'autostart': autostart,
          },
        VirtNetworkRestart(:final network) => {
          'op': 'network_restart',
          'network': network.id,
          'base_xml': network.xml.isEmpty ? null : network.xml,
        },
        VirtNetworkSetActive(:final network, :final active) => {
          'op': 'network_set_active',
          'network': network.id,
          'active': active,
        },
        VirtNetworkSetAutostart(:final network, :final on) => {
          'op': 'network_set_autostart',
          'network': network.id,
          'on': on,
        },
        VirtNetworkDelete(:final network) => {
          'op': 'network_delete',
          'network': network.id,
        },
        VirtNetworkApply(:final node) => {'op': 'network_apply', 'node': node},
        VirtNetworkRevert(:final node) => {'op': 'network_revert', 'node': node},
      };

  /// `sbm_virt::error::Error` as this app phrases it. What `sbm_virt` leaves
  /// to the caller (`detail_json`) is said in the user's language; the
  /// host's own words otherwise.
  static VirtErr error(PveError e) {
    final type = switch (e.kind) {
      VirtFailure.unreachable => VirtErrType.unreachable,
      VirtFailure.notConfigured => VirtErrType.notConfigured,
      VirtFailure.authFailed => VirtErrType.authFailed,
      VirtFailure.needTfa => VirtErrType.needTfa,
      VirtFailure.certUnconfirmed => VirtErrType.certUnconfirmed,
      VirtFailure.certChanged => VirtErrType.certChanged,
      VirtFailure.permissionDenied => VirtErrType.permissionDenied,
      VirtFailure.invalidResponse => VirtErrType.invalidResponse,
      VirtFailure.actionFailed => VirtErrType.actionFailed,
      VirtFailure.unsupported => VirtErrType.unsupported,
      VirtFailure.exists => VirtErrType.exists,
      VirtFailure.conflict => VirtErrType.conflict,
      VirtFailure.notInstalled => VirtErrType.notInstalled,
      VirtFailure.sudoPasswordRequired => VirtErrType.sudoPasswordRequired,
      VirtFailure.sudoPasswordRejected => VirtErrType.sudoPasswordRejected,
      VirtFailure.closed || VirtFailure.unknown => VirtErrType.unknown,
    };
    final detail = e.detailJson == null ? null : jsonDecode(e.detailJson!);
    final message = switch (detail) {
      {'code': 'no_user'} => 'No user to log in to PVE as. Use an API token.',
      {'code': 'password_required'} => l10n.pvePasswordRequired,
      {'code': 'token_incomplete'} => 'The PVE API token is incomplete',
      {'code': 'otp_required'} => l10n.pveOtpRequired,
      {'code': 'otp_empty'} => l10n.pveOtpCodeRequired,
      {'code': 'otp_rejected'} => l10n.pveOtpVerificationFailed,
      {'code': 'invalid_body'} => l10n.pveInvalidResponseBody,
      {'code': 'invalid_data'} => l10n.pveInvalidResponseData,
      {'code': 'missing_ticket'} => l10n.pveMissingAuthTicket,
      {
        'code': 'no_privileges',
        'token': final bool token,
        'account': final String account,
        'command': final String command,
      } =>
        token
            ? l10n.pveTokenNoPrivileges(account, command)
            : l10n.pveUserNoPrivileges(account, command),
      {
        'code': 'task_still_running',
        'node': final String node,
        'upid': final String upid,
        'minutes': final int minutes,
      } =>
        'Still running on $node after $minutes min; '
            'its task log on the host says how it ends: $upid',
      {
        'code': 'needs_privilege',
        'account': final String account,
        'privilege': final String privilege,
        'path': final String path,
        'command': final String command,
      } =>
        l10n.pveNeedsPrivilege(account, privilege, path, command),
      {'code': 'refused', 'issue': final String issue} =>
        virtResIssueText(VirtResIssue.ofRust(issue)),
      {'code': 'apply_touches_management', 'ifaces': final List ifaces} =>
        'The pending configuration changes ${ifaces.join(', ')}, which '
            "carries the host's management traffic: apply it from the "
            "host's console or PVE's own interface",
      {'code': 'apply_unreadable'} =>
        'Which interfaces the pending configuration changes cannot be told '
            "from its diff: apply it from the host's console or PVE's own "
            'interface',
      {'code': 'cert_not_presented'} =>
        'That certificate was not presented by this server',
      {'code': 'not_offered'} => 'Not offered for this guest',
      _ => e.message,
    };
    final cert = e.cert;
    return VirtErr(
      type: type,
      message:
          (type == VirtErrType.certUnconfirmed ||
                  type == VirtErrType.certChanged) &&
              cert != null
          ? cert.prettyFingerprint
          : message,
      cert: cert,
      previousFingerprint: e.previousFingerprint,
      cause: e,
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
