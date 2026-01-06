import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/misc.dart';

sealed class ContainerPs {
  final String? id = null;
  final String? image = null;
  String? get name;
  String? get cmd;
  ContainerStatus get status;

  String? cpu;
  String? mem;
  String? net;
  String? disk;

  factory ContainerPs.fromRaw(String s, ContainerType typ) => typ.ps(s);

  void parseStats(String s, [String? version]);
}

final class PodmanPs implements ContainerPs {
  final List<String>? command;
  final DateTime? created;
  final bool? exited;
  @override
  final String? id;
  @override
  final String? image;
  final List<String>? names;
  final int? startedAt;

  @override
  String? cpu;
  @override
  String? mem;
  @override
  String? net;
  @override
  String? disk;

  PodmanPs({this.command, this.created, this.exited, this.id, this.image, this.names, this.startedAt});

  @override
  String? get name => names?.firstOrNull;

  @override
  String? get cmd => command?.firstOrNull;

  @override
  ContainerStatus get status => ContainerStatus.fromPodmanExited(exited);

  @override
  void parseStats(String s, [String? version]) {
    final stats = json.decode(s);
    final cpuD = (stats['CPU'] as double? ?? 0).toStringAsFixed(1);
    final cpuAvgD = (stats['AvgCPU'] as double? ?? 0).toStringAsFixed(1);
    cpu = '$cpuD% / ${l10n.pingAvg} $cpuAvgD%';
    final memLimit = (stats['MemLimit'] as int? ?? 0).bytes2Str;
    final memUsage = (stats['MemUsage'] as int? ?? 0).bytes2Str;
    mem = '$memUsage / $memLimit';

    int netIn = 0;
    int netOut = 0;
    final majorVersion = version?.split('.').firstOrNull;
    // Podman 4.x uses top-level NetInput/NetOutput fields.
    // Podman 5.x changed network backend (Netavark) and uses nested
    // Network.{iface}.RxBytes/TxBytes structure instead.
    if (majorVersion == '4') {
      netIn = stats['NetInput'] as int? ?? 0;
      netOut = stats['NetOutput'] as int? ?? 0;
    } else if (majorVersion == '5') {
      final network = stats['Network'] as Map<String, dynamic>?;
      if (network != null) {
        for (final interface in network.values) {
          netIn += interface['RxBytes'] as int? ?? 0;
          netOut += interface['TxBytes'] as int? ?? 0;
        }
      }
    }
    net = '↓ ${netIn.bytes2Str} / ↑ ${netOut.bytes2Str}';

    final diskIn = (stats['BlockInput'] as int? ?? 0).bytes2Str;
    final diskOut = (stats['BlockOutput'] as int? ?? 0).bytes2Str;
    disk = '${l10n.read} $diskOut / ${l10n.write} $diskIn';
  }

  factory PodmanPs.fromRawJson(String str) => PodmanPs.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PodmanPs.fromJson(Map<String, dynamic> json) => PodmanPs(
    command: json['Command'] == null ? [] : List<String>.from(json['Command']!.map((x) => x)),
    created: json['Created'] == null ? null : DateTime.parse(json['Created']),
    exited: json['Exited'],
    id: json['Id'],
    image: json['Image'],
    names: json['Names'] == null ? [] : List<String>.from(json['Names']!.map((x) => x)),
    startedAt: json['StartedAt'],
  );

  Map<String, dynamic> toJson() => {
    'Command': command == null ? [] : List<dynamic>.from(command!.map((x) => x)),
    'Created': created?.toIso8601String(),
    'Exited': exited,
    'Id': id,
    'Image': image,
    'Names': names == null ? [] : List<dynamic>.from(names!.map((x) => x)),
    'StartedAt': startedAt,
  };
}

final class DockerPs implements ContainerPs {
  @override
  final String? id;
  @override
  final String? image;
  final String? names;
  final String? state;

  @override
  String? cpu;
  @override
  String? mem;
  @override
  String? net;
  @override
  String? disk;

  DockerPs({this.id, this.image, this.names, this.state});

  @override
  String? get name => names;

  @override
  String? get cmd => null;

  @override
  ContainerStatus get status => ContainerStatus.fromDockerState(state);

  @override
  void parseStats(String s, [String? version]) {
    final stats = json.decode(s);
    cpu = stats['CPUPerc'];
    mem = stats['MemUsage'];
    net = stats['NetIO'];
    disk = stats['BlockIO'];
  }

  /// CONTAINER ID                   NAMES                          IMAGE                          STATUS
  /// a049d689e7a1                   aria2-pro                      p3terx/aria2-pro               Up 3 weeks
  factory DockerPs.parse(String raw) {
    final parts = raw.split(Miscs.multiBlankreg);
    return DockerPs(id: parts[0], state: parts[1], names: parts[2], image: parts[3].trim());
  }
}
