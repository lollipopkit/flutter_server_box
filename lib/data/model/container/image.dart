import 'dart:convert';

import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/data/model/container/type.dart';

abstract final class ContainerImg {
  final String? repository = null;
  final String? tag = null;
  final String? id = null;
  String? get sizeMB;
  int? get containersCount;

  factory ContainerImg.fromRawJson(String s, ContainerType typ) => typ.img(s);
}

final class PodmanImg implements ContainerImg {
  @override
  final String? repository;
  @override
  final String? tag;
  @override
  final String? id;
  final int? created;
  final int? size;
  final int? containers;

  PodmanImg({
    this.repository,
    this.tag,
    this.id,
    this.created,
    this.size,
    this.containers,
  });

  @override
  String? get sizeMB => size?.bytes2Str;

  @override
  int? get containersCount => containers;

  factory PodmanImg.fromRawJson(String str) =>
      PodmanImg.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PodmanImg.fromJson(Map<String, dynamic> json) => PodmanImg(
        repository: json["repository"],
        tag: json["tag"],
        id: json["Id"],
        created: json["Created"],
        size: json["Size"],
        containers: json["Containers"],
      );

  Map<String, dynamic> toJson() => {
        "repository": repository,
        "tag": tag,
        "Id": id,
        "Created": created,
        "Size": size,
        "Containers": containers,
      };
}

final class DockerImg implements ContainerImg {
  final String containers;
  final String createdAt;
  @override
  final String id;
  @override
  final String repository;
  final String size;
  @override
  final String tag;

  DockerImg({
    required this.containers,
    required this.createdAt,
    required this.id,
    required this.repository,
    required this.size,
    required this.tag,
  });

  @override
  String? get sizeMB => size;

  @override
  int? get containersCount =>
      containers == 'N/A' ? 0 : int.tryParse(containers);

  factory DockerImg.fromRawJson(String str) =>
      DockerImg.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DockerImg.fromJson(Map<String, dynamic> json) => DockerImg(
        containers: json["Containers"],
        createdAt: json["CreatedAt"],
        id: json["ID"],
        repository: json["Repository"],
        size: json["Size"],
        tag: json["Tag"],
      );

  Map<String, dynamic> toJson() => {
        "Containers": containers,
        "CreatedAt": createdAt,
        "ID": id,
        "Repository": repository,
        "Size": size,
        "Tag": tag,
      };
}
