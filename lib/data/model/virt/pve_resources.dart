import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_rates.dart';

/// Reading PVE API answers into the Virtualization models. Pure functions,
/// tested against captured payloads.
///
/// Lenient where the parser it replaced (the PVE page's `PveRes`) was strict:
/// a field missing from one entry (a guest being created has no name yet, an offline node no
/// figures) costs that field, not the whole listing.
abstract final class PveResources {
  /// `/cluster/resources`: the nodes, the guests (templates included, marked),
  /// and each guest's counters at [at].
  static ({
    List<VirtNode> nodes,
    List<VirtGuest> guests,
    Map<String, VirtCounterSample> samples,
  })
  parse(List<Object?> raw, {required DateTime at}) {
    final nodes = <VirtNode>[];
    final guests = <VirtGuest>[];
    final samples = <String, VirtCounterSample>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      switch (e['type']) {
        case 'node':
          final name = _str(e['node']);
          if (name == null) continue;
          nodes.add(
            VirtNode(
              name: name,
              online: e['status'] == 'online',
              cpu: _double(e['cpu']),
              maxCpu: _int(e['maxcpu']),
              memUsed: _int(e['mem']),
              memTotal: _int(e['maxmem']),
              uptime: _duration(e['uptime']),
            ),
          );
        case final String type when type == 'qemu' || type == 'lxc':
          final vmid = _int(e['vmid']);
          final id = _str(e['id']) ?? (vmid == null ? null : '$type/$vmid');
          if (id == null) continue;
          final kind = type == 'lxc' ? VirtGuestKind.lxc : VirtGuestKind.qemu;
          final status = _str(e['status']);
          final lock = _str(e['lock']);
          final template = _int(e['template']) == 1;
          final state = stateOf(status, lock);
          guests.add(
            VirtGuest(
              id: id,
              name: _str(e['name']) ?? '${vmid ?? id}',
              kind: kind,
              state: state,
              stateReason: lock ?? (status == state.name ? null : status),
              vmid: vmid,
              node: _str(e['node']),
              vcpu: _int(e['maxcpu']),
              memBytes: _int(e['maxmem']),
              uptime: _duration(e['uptime']),
              tags: _tags(e['tags']),
              template: template,
              actions: template
                  ? const {}
                  : actionsOf(status, lock, kind, state),
            ),
          );
          // What runs, whatever holds the lock: a VM being backed up is
          // still running, and its counters still count.
          final active = stateOf(status, null).isActive;
          final cpu = _double(e['cpu']);
          samples[id] = VirtCounterSample(
            at: at,
            cpuPercent: active && cpu != null ? cpu * 100 : null,
            vcpus: _int(e['maxcpu']),
            memUsed: active ? _int(e['mem']) : null,
            memTotal: _int(e['maxmem']),
            // QEMU reports 0 used without the guest agent; that is "not
            // known", not an empty disk.
            diskUsed: _positive(_int(e['disk'])),
            diskTotal: _positive(_int(e['maxdisk'])),
            diskRead: active ? _int(e['diskread']) : null,
            diskWrite: active ? _int(e['diskwrite']) : null,
            netIn: active ? _int(e['netin']) : null,
            netOut: active ? _int(e['netout']) : null,
          );
      }
    }
    return (nodes: nodes, guests: guests, samples: samples);
  }

  /// What a guest with PVE's [status] and [lock] offers, [state] being
  /// [stateOf] the two.
  ///
  /// A lock is an operation in progress (snapshot, clone, rollback, ...) that
  /// PVE refuses power actions during, with two exceptions. `suspended` is a
  /// hibernated VM, which `start` resumes. `backup` still lets a VM be paused
  /// and resumed (`vm_suspend` and `vm_resume` skip the lock check for it,
  /// PVE 9.2 `QemuServer/RunState.pm`; verified, test/e2e/virt_real_test.dart),
  /// which is how a paused VM that a backup job picked up is woken.
  static Set<VirtPowerAction> actionsOf(
    String? status,
    String? lock,
    VirtGuestKind kind,
    VirtGuestState state,
  ) {
    final qemu = kind == VirtGuestKind.qemu;
    return switch (lock) {
      null || 'suspended' => VirtPowerAction.offered(state, pause: qemu),
      'backup' when qemu => switch (status) {
        'running' => const {VirtPowerAction.suspend},
        'paused' => const {VirtPowerAction.resume},
        _ => const {},
      },
      _ => const {},
    };
  }

  /// PVE's `status` and `lock`, as one state.
  ///
  /// `status` is the QEMU run state where `pvestatd` has one, so beside
  /// `running` and `stopped` it can be `paused`, `prelaunch`, `suspended`
  /// (S3), `io-error`, `internal-error`, `guest-panicked`, ... A `lock` wins
  /// where it names what the guest is busy with.
  static VirtGuestState stateOf(String? status, String? lock) {
    switch (lock) {
      case 'backup':
        return VirtGuestState.backup;
      case 'migrate':
        return VirtGuestState.migrating;
      case 'suspending':
        return VirtGuestState.stopping;
    }
    return switch (status) {
      'running' => VirtGuestState.running,
      'stopped' => VirtGuestState.stopped,
      'paused' || 'suspended' || 'io-error' => VirtGuestState.paused,
      'prelaunch' || 'inmigrate' => VirtGuestState.starting,
      'shutdown' => VirtGuestState.stopping,
      'postmigrate' || 'finish-migrate' => VirtGuestState.migrating,
      _ => VirtGuestState.unknown,
    };
  }

  /// `/nodes/{node}/{type}/{vmid}/rrddata`: rates already, bytes per second.
  static List<VirtStats> parseRrd(List<Object?> raw) {
    final out = <VirtStats>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final e = item.cast<String, Object?>();
      final time = _int(e['time']);
      if (time == null) continue;
      final cpu = _double(e['cpu']);
      out.add(
        VirtStats(
          at: DateTime.fromMillisecondsSinceEpoch(time * 1000),
          cpu: cpu == null ? null : cpu * 100,
          memUsed: _double(e['mem'])?.round(),
          memTotal: _double(e['maxmem'])?.round(),
          diskUsed: _positive(_double(e['disk'])?.round()),
          diskTotal: _positive(_double(e['maxdisk'])?.round()),
          diskRead: _double(e['diskread']),
          diskWrite: _double(e['diskwrite']),
          netIn: _double(e['netin']),
          netOut: _double(e['netout']),
        ),
      );
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static final _qemuDisk = RegExp(
    r'^(ide|sata|scsi|virtio|efidisk|tpmstate|unused)(\d+)$',
  );
  static final _lxcDisk = RegExp(r'^(rootfs|mp\d+|unused\d+)$');
  static final _net = RegExp(r'^net(\d+)$');
  static final _serial = RegExp(r'^serial\d+$');

  /// `/nodes/{node}/{type}/{vmid}/config`.
  static VirtGuestDetail parseConfig(
    Map<String, Object?> config,
    VirtGuestKind kind,
  ) {
    final disks = <VirtDisk>[];
    final nics = <VirtNic>[];
    var hasSerial = false;
    final keys = config.keys.toList()..sort(_naturalCompare);
    for (final key in keys) {
      final value = config[key];
      if (value is! String) continue;
      if (kind == VirtGuestKind.qemu && _serial.hasMatch(key)) {
        hasSerial = true;
      }
      final diskMatch = kind == VirtGuestKind.qemu
          ? _qemuDisk.firstMatch(key)
          : _lxcDisk.firstMatch(key);
      if (diskMatch != null) {
        disks.add(_disk(key, value, kind, diskMatch));
        continue;
      }
      if (_net.hasMatch(key)) nics.add(_nic(key, value, kind));
    }

    final vgaRaw = config['vga'];
    final vga = vgaRaw is String ? _options(vgaRaw).first.$2 : 'std';
    // `vga: serial0` puts the display on the serial port, and `none` has no
    // display: neither has a VNC console.
    final hasVnc = vga != 'none' && !vga.startsWith('serial');
    final graphics = <VirtGraphics>[
      if (kind == VirtGuestKind.qemu) VirtGraphics(kind: vga),
    ];
    return VirtGuestDetail(
      disks: disks,
      nics: nics,
      graphics: graphics,
      consoles: switch (kind) {
        VirtGuestKind.lxc => const {VirtConsoleKind.text},
        VirtGuestKind.qemu => {
          if (hasVnc) VirtConsoleKind.vnc,
          if (hasSerial) VirtConsoleKind.text,
        },
      },
      description: _str(config['description']),
      arch: _str(config['arch']),
      machine: _str(config['ostype']) ?? _str(config['machine']),
    );
  }

  static VirtDisk _disk(
    String key,
    String value,
    VirtGuestKind kind,
    RegExpMatch match,
  ) {
    final opts = _options(value);
    final named = {for (final (k, v) in opts) k: v};
    // The first option is the volume, written without a key.
    final volume = opts.first.$1.isEmpty ? opts.first.$2 : named['file'];
    final media = named['media'];
    final source = volume == null || volume == 'none' ? null : volume;
    final String device;
    if (kind == VirtGuestKind.lxc) {
      device = key == 'rootfs' ? 'rootfs' : 'mp';
    } else {
      device = media == 'cdrom' ? 'cdrom' : 'disk';
    }
    return VirtDisk(
      device: device,
      source: source,
      target: key,
      bus: kind == VirtGuestKind.qemu ? match.group(1) : null,
      format: named['format'],
      readonly: named['ro'] == '1' || media == 'cdrom',
      size: _size(named['size']),
    );
  }

  static VirtNic _nic(String key, String value, VirtGuestKind kind) {
    final opts = _options(value);
    final named = {for (final (k, v) in opts) k: v};
    if (kind == VirtGuestKind.lxc) {
      return VirtNic(
        kind: key,
        mac: named['hwaddr'],
        source: named['bridge'],
        model: named['type'] ?? 'veth',
        target: named['name'],
      );
    }
    // `virtio=BC:24:11:AA:BB:CC,bridge=vmbr0`: the model is the key of the
    // pair that carries the MAC.
    const models = {
      'virtio',
      'e1000',
      'e1000e',
      'rtl8139',
      'vmxnet3',
      'i82551',
      'i82557b',
      'i82559er',
      'ne2k_isa',
      'ne2k_pci',
      'pcnet',
    };
    String? model;
    String? mac;
    for (final (k, v) in opts) {
      if (models.contains(k)) {
        model = k;
        mac = v.isEmpty ? null : v;
        break;
      }
    }
    return VirtNic(
      kind: key,
      mac: mac ?? named['macaddr'],
      source: named['bridge'],
      model: model ?? named['model'],
    );
  }

  /// `a,b=c,d=e` → `[('', a), (b, c), (d, e)]`.
  static List<(String, String)> _options(String value) {
    final out = <(String, String)>[];
    for (final part in value.split(',')) {
      final at = part.indexOf('=');
      if (at < 0) {
        out.add(('', part));
      } else {
        out.add((part.substring(0, at), part.substring(at + 1)));
      }
    }
    return out.isEmpty ? [('', '')] : out;
  }

  /// PVE sizes: `32G`, `512M`, `1T`, `4096` (bytes).
  static int? _size(String? s) {
    if (s == null || s.isEmpty) return null;
    const units = {'K': 1 << 10, 'M': 1 << 20, 'G': 1 << 30, 'T': 1 << 40};
    final unit = units[s[s.length - 1].toUpperCase()];
    final number = double.tryParse(
      unit == null ? s : s.substring(0, s.length - 1),
    );
    if (number == null) return null;
    return (number * (unit ?? 1)).round();
  }

  /// `scsi2` before `scsi10`.
  static int _naturalCompare(String a, String b) {
    final ma = RegExp(r'^(\D*)(\d*)$').firstMatch(a);
    final mb = RegExp(r'^(\D*)(\d*)$').firstMatch(b);
    if (ma == null || mb == null) return a.compareTo(b);
    final p = ma.group(1)!.compareTo(mb.group(1)!);
    if (p != 0) return p;
    return (int.tryParse(ma.group(2)!) ?? -1).compareTo(
      int.tryParse(mb.group(2)!) ?? -1,
    );
  }

  static List<String> _tags(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    return raw
        .split(RegExp('[;, ]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  static int? _int(Object? v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  static double? _double(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static int? _positive(int? v) => v == null || v <= 0 ? null : v;

  static Duration? _duration(Object? v) {
    final s = _int(v);
    return s == null || s <= 0 ? null : Duration(seconds: s);
  }
}
