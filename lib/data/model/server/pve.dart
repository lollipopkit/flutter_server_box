import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum PveResType {
  lxc,
  qemu,
  node,
  storage,
  sdn,
  ;

  static PveResType? fromString(String type) => switch (type.toLowerCase()) {
        'lxc' => PveResType.lxc,
        'qemu' => PveResType.qemu,
        'node' => PveResType.node,
        'storage' => PveResType.storage,
        'sdn' => PveResType.sdn,
        _ => null,
      };

  String get toStr => switch (this) {
        PveResType.node => l10n.node,
        PveResType.qemu => 'QEMU',
        PveResType.lxc => 'LXC',
        PveResType.storage => l10n.storage,
        PveResType.sdn => 'SDN',
      };
}

sealed class PveResIface {
  String get id;
  String get status;
  PveResType get type;

  static PveResIface? fromJson(Map<String, dynamic> json) {
    final type = PveResType.fromString(json['type']);
    if (type == null) return null;
    switch (type) {
      case PveResType.lxc:
        return PveLxc.fromJson(json);
      case PveResType.qemu:
        return PveQemu.fromJson(json);
      case PveResType.node:
        return PveNode.fromJson(json);
      case PveResType.storage:
        return PveStorage.fromJson(json);
      case PveResType.sdn:
        return PveSdn.fromJson(json);
    }
  }
}

abstract interface class PveCtrlIface {
  String get node;
  String get id;
  bool get available;
  String get summary;
  String get name;
}

final class PveLxc extends PveResIface implements PveCtrlIface {
  @override
  final String id;
  @override
  final PveResType type;
  final int vmid;
  @override
  final String node;
  @override
  final String name;
  @override
  final String status;
  final int uptime;
  final int mem;
  final int maxmem;
  final double cpu;
  final int maxcpu;
  final int disk;
  final int maxdisk;
  final int diskread;
  final int diskwrite;
  final int netin;
  final int netout;

  PveLxc({
    required this.id,
    required this.type,
    required this.vmid,
    required this.node,
    required this.name,
    required this.status,
    required this.uptime,
    required this.mem,
    required this.maxmem,
    required this.cpu,
    required this.maxcpu,
    required this.disk,
    required this.maxdisk,
    required this.diskread,
    required this.diskwrite,
    required this.netin,
    required this.netout,
  });

  static PveLxc fromJson(Map<String, dynamic> json) {
    return PveLxc(
      id: json['id'],
      type: PveResType.lxc,
      vmid: json['vmid'],
      node: json['node'],
      name: json['name'],
      status: json['status'],
      uptime: json['uptime'],
      mem: json['mem'],
      maxmem: json['maxmem'],
      cpu: (json['cpu'] as num).toDouble(),
      maxcpu: json['maxcpu'],
      disk: json['disk'],
      maxdisk: json['maxdisk'],
      diskread: json['diskread'],
      diskwrite: json['diskwrite'],
      netin: json['netin'],
      netout: json['netout'],
    );
  }

  @override
  bool get available => status == 'running';

  @override
  String get summary {
    if (available) {
      return uptime.secondsToDuration().toAgoStr;
    }
    return l10n.stopped;
  }
}

final class PveQemu extends PveResIface implements PveCtrlIface {
  @override
  final String id;
  @override
  final PveResType type;
  final int vmid;
  @override
  final String node;
  @override
  final String name;
  @override
  final String status;
  final int uptime;
  final int mem;
  final int maxmem;
  final double cpu;
  final int maxcpu;
  final int disk;
  final int maxdisk;
  final int diskread;
  final int diskwrite;
  final int netin;
  final int netout;

  PveQemu({
    required this.id,
    required this.type,
    required this.vmid,
    required this.node,
    required this.name,
    required this.status,
    required this.uptime,
    required this.mem,
    required this.maxmem,
    required this.cpu,
    required this.maxcpu,
    required this.disk,
    required this.maxdisk,
    required this.diskread,
    required this.diskwrite,
    required this.netin,
    required this.netout,
  });

  static PveQemu fromJson(Map<String, dynamic> json) {
    return PveQemu(
      id: json['id'],
      type: PveResType.qemu,
      vmid: json['vmid'],
      node: json['node'],
      name: json['name'],
      status: json['status'],
      uptime: json['uptime'],
      mem: json['mem'],
      maxmem: json['maxmem'],
      cpu: (json['cpu'] as num).toDouble(),
      maxcpu: json['maxcpu'],
      disk: json['disk'],
      maxdisk: json['maxdisk'],
      diskread: json['diskread'],
      diskwrite: json['diskwrite'],
      netin: json['netin'],
      netout: json['netout'],
    );
  }

  @override
  bool get available => status == 'running';

  @override
  String get summary {
    if (available) {
      return uptime.secondsToDuration().toAgoStr;
    }
    return l10n.stopped;
  }
}

final class PveNode extends PveResIface {
  @override
  final String id;
  @override
  final PveResType type;
  final String node;
  @override
  final String status;
  final int uptime;
  final int mem;
  final int maxmem;
  final double cpu;
  final int maxcpu;

  PveNode({
    required this.id,
    required this.type,
    required this.node,
    required this.status,
    required this.uptime,
    required this.mem,
    required this.maxmem,
    required this.cpu,
    required this.maxcpu,
  });

  static PveNode fromJson(Map<String, dynamic> json) {
    return PveNode(
      id: json['id'],
      type: PveResType.node,
      node: json['node'],
      status: json['status'],
      uptime: json['uptime'],
      mem: json['mem'],
      maxmem: json['maxmem'],
      cpu: (json['cpu'] as num).toDouble(),
      maxcpu: json['maxcpu'],
    );
  }

  bool get isRunning => status == 'online';

  String get topRight {
    if (isRunning) {
      return uptime.secondsToDuration().toAgoStr;
    }
    return l10n.stopped;
  }
}

final class PveStorage extends PveResIface implements PveCtrlIface {
  @override
  final String id;
  @override
  final PveResType type;
  final String storage;
  @override
  final String node;
  @override
  final String status;
  final String plugintype;
  final String content;
  final int shared;
  final int disk;
  final int maxdisk;

  PveStorage({
    required this.id,
    required this.type,
    required this.storage,
    required this.node,
    required this.status,
    required this.plugintype,
    required this.content,
    required this.shared,
    required this.disk,
    required this.maxdisk,
  });

  static PveStorage fromJson(Map<String, dynamic> json) {
    return PveStorage(
      id: json['id'],
      type: PveResType.storage,
      storage: json['storage'],
      node: json['node'],
      status: json['status'],
      plugintype: json['plugintype'],
      content: json['content'],
      shared: json['shared'],
      disk: json['disk'],
      maxdisk: json['maxdisk'],
    );
  }

  @override
  bool get available => status == 'available';

  @override
  String get name => storage;

  @override
  String get summary {
    if (available) {
      return '${l10n.used}: ${disk.bytes2Str} / ${l10n.total}: ${maxdisk.bytes2Str}';
    }
    return l10n.notAvailable;
  }
}

final class PveSdn extends PveResIface implements PveCtrlIface {
  @override
  final String id;
  @override
  final PveResType type;
  final String sdn;
  @override
  final String node;
  @override
  final String status;

  PveSdn({
    required this.id,
    required this.type,
    required this.sdn,
    required this.node,
    required this.status,
  });

  static PveSdn fromJson(Map<String, dynamic> json) {
    return PveSdn(
      id: json['id'],
      type: PveResType.sdn,
      sdn: json['sdn'],
      node: json['node'],
      status: json['status'],
    );
  }

  @override
  bool get available => status == 'ok';

  @override
  String get name => sdn;

  @override
  String get summary => available ? status : l10n.notAvailable;
}

final class PveRes {
  final List<PveNode> nodes;
  final List<PveQemu> qemus;
  final List<PveLxc> lxcs;
  final List<PveStorage> storages;
  final List<PveSdn> sdns;

  const PveRes({
    required this.nodes,
    required this.qemus,
    required this.lxcs,
    required this.storages,
    required this.sdns,
  });

  bool get onlyOneNode => nodes.length == 1;

  int get length =>
      qemus.length + lxcs.length + nodes.length + storages.length + sdns.length;

  PveResIface operator [](int index) {
    if (index < nodes.length) {
      return nodes[index];
    }
    index -= nodes.length;
    if (index < qemus.length) {
      return qemus[index];
    }
    index -= qemus.length;
    if (index < lxcs.length) {
      return lxcs[index];
    }
    index -= lxcs.length;
    if (index < storages.length) {
      return storages[index];
    }
    index -= storages.length;
    return sdns[index];
  }

  static Future<PveRes> parse((List list, PveRes? old) val) async {
    final (list, old) = val;
    final items = list.map((e) => PveResIface.fromJson(e)).toList();
    final List<PveQemu> qemus = [];
    final List<PveLxc> lxcs = [];
    final List<PveNode> nodes = [];
    final List<PveStorage> storages = [];
    final List<PveSdn> sdns = [];
    for (final item in items) {
      if (item == null) continue;
      switch (item.type) {
        case PveResType.lxc:
          lxcs.add(item as PveLxc);
          break;
        case PveResType.qemu:
          qemus.add(item as PveQemu);
          break;
        case PveResType.node:
          nodes.add(item as PveNode);
          break;
        case PveResType.storage:
          storages.add(item as PveStorage);
          break;
        case PveResType.sdn:
          sdns.add(item as PveSdn);
          break;
      }
    }

    if (old != null) {
      qemus.reorder(
          order: old.qemus.map((e) => e.id).toList(),
          finder: (e, s) => e.id == s);
      lxcs.reorder(
          order: old.lxcs.map((e) => e.id).toList(),
          finder: (e, s) => e.id == s);
      nodes.reorder(
          order: old.nodes.map((e) => e.id).toList(),
          finder: (e, s) => e.id == s);
      storages.reorder(
          order: old.storages.map((e) => e.id).toList(),
          finder: (e, s) => e.id == s);
      sdns.reorder(
          order: old.sdns.map((e) => e.id).toList(),
          finder: (e, s) => e.id == s);
    }

    return PveRes(
      qemus: qemus,
      lxcs: lxcs,
      nodes: nodes,
      storages: storages,
      sdns: sdns,
    );
  }
}
