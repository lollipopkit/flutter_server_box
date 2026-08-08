import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/data/model/container/type.dart';

const podmanPsStatusSeparator = '__SERVER_BOX_PODMAN_STATUS__';

sealed class ContainerPs {
  String? get id;
  String? get image;
  String? get name;
  String? get project;
  String? get workingDir;

  /// Human-readable lifecycle text reported by the runtime's STATUS field.
  String? get rawStatus;
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
  final String? rawStatus;
  @override
  final String? project;
  @override
  final String? workingDir;

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
    this.rawStatus,
    this.project,
    this.workingDir,
  });

  @override
  String? get name => names?.firstOrNull;

  @override
  ContainerStatus get status => ContainerStatus.fromPodmanExited(exited);

  @override
  void parseStats(String s, [String? version]) {
    final stats = json.decode(s);
    final cpuD = _asDouble(stats['CPU']).toStringAsFixed(1);
    final cpuAvgD = _asDouble(stats['AvgCPU']).toStringAsFixed(1);
    cpu = '$cpuD% / ${libL10n.pingAvg} $cpuAvgD%';
    final memLimit = _asInt(stats['MemLimit']).bytes2Str;
    final memUsage = _asInt(stats['MemUsage']).bytes2Str;
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
      netIn = _asInt(stats['NetInput']);
      netOut = _asInt(stats['NetOutput']);
    } else if (majorVersionNum >= 5) {
      final network = stats['Network'];
      if (network is Map) {
        for (final entry in network.entries) {
          final interface = entry.value;
          if (interface is! Map) continue;
          netIn += _asInt(interface['RxBytes']);
          netOut += _asInt(interface['TxBytes']);
        }
      }
    }
    net = '↓ ${netIn.bytes2Str} / ↑ ${netOut.bytes2Str}';

    final diskIn = _asInt(stats['BlockInput']).bytes2Str;
    final diskOut = _asInt(stats['BlockOutput']).bytes2Str;
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
    rawStatus: _nonEmpty(json['ServerBoxStatus']?.toString()) ??
        _nonEmpty(json['Status']?.toString()) ??
        _nonEmpty(json['State']?.toString()),
    project: _labelFromLabels(json['Labels'], 'com.docker.compose.project'),
    workingDir: _labelFromLabels(
      json['Labels'],
      'com.docker.compose.project.working_dir',
    ),
  );
}

/// Parses Podman's JSON listing and merges the human-readable `.Status`
/// template output by container ID.
List<PodmanPs> parsePodmanPsOutput(String raw) {
  final lines = raw.split('\n');
  final separatorIndex = lines.indexWhere(
    (line) => line.trim() == podmanPsStatusSeparator,
  );
  final jsonLines = separatorIndex < 0
      ? lines
      : lines.take(separatorIndex);
  final detailedStatuses = <String, String>{};
  if (separatorIndex >= 0) {
    for (final line in lines.skip(separatorIndex + 1)) {
      final separator = line.indexOf('\t');
      if (separator <= 0) continue;
      final id = line.substring(0, separator).trim();
      final status = line.substring(separator + 1).trim();
      if (id.isNotEmpty && status.isNotEmpty) {
        detailedStatuses[_containerIdMarker(id)] = status;
      }
    }
  }

  return jsonLines
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
        final data = json.decode(line) as Map<String, dynamic>;
        final id = (data['Id'] ?? data['ID'])?.toString();
        final detailedStatus = id == null
            ? null
            : detailedStatuses[_containerIdMarker(id)];
        if (detailedStatus != null) {
          data['ServerBoxStatus'] = detailedStatus;
        }
        return PodmanPs.fromJson(data);
      })
      .toList(growable: false);
}

String _containerIdMarker(String id) {
  final value = id.trim();
  return value.length <= 12 ? value : value.substring(0, 12);
}

final class DockerPs implements ContainerPs {
  @override
  final String? id;
  @override
  final String? image;
  final String? names;
  final String? state;
  @override
  String? get rawStatus => state;
  @override
  final String? project;
  @override
  final String? workingDir;

  @override
  String? cpu;
  @override
  String? mem;
  @override
  String? net;
  @override
  String? disk;

  DockerPs({
    this.id,
    this.image,
    this.names,
    this.state,
    this.project,
    this.workingDir,
  });

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

  /// CONTAINER ID\tSTATUS\tNAMES\tIMAGE\tPROJECT\tWORKING_DIR
  /// a049d689e7a1\tUp 3 weeks\taria2-pro\tp3terx/aria2-pro\ttorrent\t/opt/torrent
  factory DockerPs.parse(String raw) {
    final parts = raw.split('\t');
    if (parts.length < 4) {
      throw FormatException(
        'Docker ps row has ${parts.length} fields, expected at least 4',
        raw,
      );
    }
    return DockerPs(
      id: parts[0],
      state: parts[1],
      names: parts[2],
      image: parts[3],
      project: parts.length > 4 ? _nonEmpty(parts[4]) : null,
      workingDir: parts.length > 5 ? _nonEmpty(parts[5]) : null,
    );
  }
}

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

double _asDouble(dynamic val) {
  if (val is num) return val.toDouble();
  return double.tryParse(val?.toString() ?? '') ?? 0;
}

int _asInt(dynamic val) {
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val?.toString() ?? '') ?? 0;
}

String? _labelFromLabels(dynamic labels, String key) {
  if (labels is! Map) return null;
  final value = labels[key];
  if (value is! String) return null;
  return _nonEmpty(value);
}
