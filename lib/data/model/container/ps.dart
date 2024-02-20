import 'dart:convert';

import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/data/model/container/type.dart';

abstract final class ContainerPs {
  final String? id = null;
  final String? image = null;
  String? get name;
  String? get cmd;
  bool get running;

  String? cpu;
  String? mem;
  String? net;
  String? disk;

  factory ContainerPs.fromRawJson(String s, ContainerType typ) => typ.ps(s);

  void parseStats(String s);
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

  PodmanPs({
    this.command,
    this.created,
    this.exited,
    this.id,
    this.image,
    this.names,
    this.startedAt,
  });

  @override
  String? get name => names?.firstOrNull;

  @override
  String? get cmd => command?.firstOrNull;

  @override
  bool get running => exited != true;

  @override
  void parseStats(String s) {
    final stats = json.decode(s);
    final cpuD = (stats['CPU'] as double? ?? 0).toStringAsFixed(1);
    final cpuAvgD = (stats['AvgCPU'] as double? ?? 0).toStringAsFixed(1);
    cpu = '$cpuD% / ${l10n.pingAvg} $cpuAvgD%';
    final memLimit = (stats['MemLimit'] as int? ?? 0).bytes2Str;
    final memUsage = (stats['MemUsage'] as int? ?? 0).bytes2Str;
    mem = '$memUsage / $memLimit';
    final netIn = (stats['NetInput'] as int? ?? 0).bytes2Str;
    final netOut = (stats['NetOutput'] as int? ?? 0).bytes2Str;
    net = '↓ $netIn / ↑ $netOut';
    final diskIn = (stats['BlockInput'] as int? ?? 0).bytes2Str;
    final diskOut = (stats['BlockOutput'] as int? ?? 0).bytes2Str;
    disk = '${l10n.read} $diskOut / ${l10n.write} $diskIn';
  }

  factory PodmanPs.fromRawJson(String str) =>
      PodmanPs.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PodmanPs.fromJson(Map<String, dynamic> json) => PodmanPs(
        command: json["Command"] == null
            ? []
            : List<String>.from(json["Command"]!.map((x) => x)),
        created:
            json["Created"] == null ? null : DateTime.parse(json["Created"]),
        exited: json["Exited"],
        id: json["Id"],
        image: json["Image"],
        names: json["Names"] == null
            ? []
            : List<String>.from(json["Names"]!.map((x) => x)),
        startedAt: json["StartedAt"],
      );

  Map<String, dynamic> toJson() => {
        "Command":
            command == null ? [] : List<dynamic>.from(command!.map((x) => x)),
        "Created": created?.toIso8601String(),
        "Exited": exited,
        "Id": id,
        "Image": image,
        "Names": names == null ? [] : List<dynamic>.from(names!.map((x) => x)),
        "StartedAt": startedAt,
      };
}

final class DockerPs implements ContainerPs {
  final String? command;
  final String? createdAt;
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

  DockerPs({
    this.command,
    this.createdAt,
    this.id,
    this.image,
    this.names,
    this.state,
  });

  @override
  String? get name => names;

  @override
  String? get cmd => command;

  @override
  bool get running => state == 'running';

  @override
  void parseStats(String s) {
    final stats = json.decode(s);
    cpu = stats['CPUPerc'];
    mem = stats['MemUsage'];
    net = stats['NetIO'];
    disk = stats['BlockIO'];
  }

  factory DockerPs.fromRawJson(String str) =>
      DockerPs.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DockerPs.fromJson(Map<String, dynamic> json) => DockerPs(
        command: json["Command"],
        createdAt: json["CreatedAt"],
        id: json["ID"],
        image: json["Image"],
        names: json["Names"],
        state: json["State"],
      );

  Map<String, dynamic> toJson() => {
        "Command": command,
        "CreatedAt": createdAt,
        "ID": id,
        "Image": image,
        "Names": names,
        "State": state,
      };
}
