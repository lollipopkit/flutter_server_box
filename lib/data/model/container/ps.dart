import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';

sealed class ContainerPs {
  String? get id;
  String? get image;
  String? get name;
  ContainerStatus get status;

  String? cpu;
  String? mem;
  String? net;
  String? disk;

  factory ContainerPs.fromRaw(String s, ContainerType typ) => typ.ps(s);

  void parseStats(String s, [String? version]);
}

final class PodmanPs implements ContainerPs {
  final bool? exited;
  @override
  final String? id;
  @override
  final String? image;
  final List<String>? names;

  @override
  String? cpu;
  @override
  String? mem;
  @override
  String? net;
  @override
  String? disk;

  PodmanPs({
    this.exited,
    this.id,
    this.image,
    this.names,
  });

  @override
  String? get name => names?.firstOrNull;

  @override
  ContainerStatus get status => ContainerStatus.fromPodmanExited(exited);

  @override
  void parseStats(String s, [String? version]) {
    final stats = json.decode(s);
    final cpuD = (stats['CPU'] as double? ?? 0).toStringAsFixed(1);
    final cpuAvgD = (stats['AvgCPU'] as double? ?? 0).toStringAsFixed(1);
    cpu = '$cpuD% / ${libL10n.pingAvg} $cpuAvgD%';
    final memLimit = (stats['MemLimit'] as int? ?? 0).bytes2Str;
    final memUsage = (stats['MemUsage'] as int? ?? 0).bytes2Str;
    mem = '$memUsage / $memLimit';

    int netIn = 0;
    int netOut = 0;
    final majorVersion = version?.split('.').firstOrNull;
    final majorVersionNum = majorVersion != null
        ? int.tryParse(majorVersion)
        : null;

    // Podman 4.x and earlier use top-level NetInput/NetOutput fields.
    // Podman 5.x changed network backend (Netavark) and uses nested
    // Network.{iface}.RxBytes/TxBytes structure instead.
    if (majorVersionNum == null || majorVersionNum <= 4) {
      netIn = stats['NetInput'] as int? ?? 0;
      netOut = stats['NetOutput'] as int? ?? 0;
    } else if (majorVersionNum >= 5) {
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
    disk = '${l10n.read} $diskIn / ${l10n.write} $diskOut';
  }

  factory PodmanPs.fromRawJson(String str) =>
      PodmanPs.fromJson(json.decode(str));

  factory PodmanPs.fromJson(Map<String, dynamic> json) => PodmanPs(
    exited: json['Exited'],
    id: json['Id'],
    image: json['Image'],
    names: json['Names'] == null
        ? []
        : List<String>.from(json['Names']!.map((x) => x)),
  );
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
  ContainerStatus get status => ContainerStatus.fromDockerState(state);

  @override
  void parseStats(String s, [String? version]) {
    final stats = json.decode(s);
    cpu = stats['CPUPerc'];
    mem = stats['MemUsage'];

    final netIO = stats['NetIO'] as String? ?? '0B / 0B';
    final netParts = netIO.split(' / ');
    net =
        '↓ ${netParts.firstOrNull ?? '0B'} / ↑ ${netParts.length > 1 ? netParts[1] : '0B'}';

    final blockIO = stats['BlockIO'] as String? ?? '0B / 0B';
    final blockParts = blockIO.split(' / ');
    disk =
        '${l10n.read} ${blockParts.firstOrNull ?? '0B'} / ${l10n.write} ${blockParts.length > 1 ? blockParts[1] : '0B'}';
  }

  /// CONTAINER ID\tSTATUS\tNAMES\tIMAGE
  /// a049d689e7a1\tUp 3 weeks\taria2-pro\tp3terx/aria2-pro
  factory DockerPs.parse(String raw) {
    final parts = raw.split('\t');
    if (parts.length < 4) {
      throw FormatException(
        'Docker ps row has ${parts.length} fields, expected 4',
        raw,
      );
    }
    return DockerPs(
      id: parts[0],
      state: parts[1],
      names: parts[2],
      image: parts[3],
    );
  }
}
