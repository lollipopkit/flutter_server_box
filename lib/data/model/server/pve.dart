import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/duration.dart';
import 'package:toolbox/core/extension/numx.dart';

enum PveResType {
  lxc,
  qemu,
  node,
  storage,
  sdn,
  ;

  static PveResType fromString(String type) {
    switch (type) {
      case 'lxc':
        return PveResType.lxc;
      case 'qemu':
        return PveResType.qemu;
      case 'node':
        return PveResType.node;
      case 'storage':
        return PveResType.storage;
      case 'sdn':
        return PveResType.sdn;
      default:
        throw Exception('Unknown PveResType: $type');
    }
  }

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

  static PveResIface fromJson(Map<String, dynamic> json) {
    final type = PveResType.fromString(json['type']);
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

final class PveLxc extends PveResIface {
  @override
  final String id;
  @override
  final PveResType type;
  final int vmid;
  final String node;
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
}

final class PveQemu extends PveResIface {
  @override
  final String id;
  @override
  final PveResType type;
  final int vmid;
  final String node;
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

  bool get isRunning => status == 'running';

  String get topRight {
    if (!isRunning) {
      return uptime.secondsToDuration().toStr;
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
}

final class PveStorage extends PveResIface {
  @override
  final String id;
  @override
  final PveResType type;
  final String storage;
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
}

final class PveSdn extends PveResIface {
  @override
  final String id;
  @override
  final PveResType type;
  final String sdn;
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
}
