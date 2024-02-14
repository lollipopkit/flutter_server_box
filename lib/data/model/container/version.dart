import 'dart:convert';

class Containerd {
  final ContainerdClient client;

  Containerd({
    required this.client,
  });

  factory Containerd.fromRawJson(String str) =>
      Containerd.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Containerd.fromJson(Map<String, dynamic> json) => Containerd(
        client: ContainerdClient.fromJson(json["Client"]),
      );

  Map<String, dynamic> toJson() => {
        "Client": client.toJson(),
      };
}

class ContainerdClient {
  final String apiVersion;
  final String version;
  final String goVersion;
  final String gitCommit;
  final String? builtTime;
  final int? built; // more fields should be marked nullable
  final String? osArch;
  final String os;

  ContainerdClient({
    required this.apiVersion,
    required this.version,
    required this.goVersion,
    required this.gitCommit,
    required this.builtTime,
    required this.built,
    required this.osArch,
    required this.os,
  });

  factory ContainerdClient.fromRawJson(String str) =>
      ContainerdClient.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ContainerdClient.fromJson(Map<String, dynamic> json) =>
      ContainerdClient(
        apiVersion: json["ApiVersion"], 
        version: json["Version"],
        goVersion: json["GoVersion"],
        gitCommit: json["GitCommit"],
        builtTime: json["BuildTime"],
        built: json["Built"], // should be Build?
        osArch: json["OsArch"],
        os: json["Os"],
      );

  Map<String, dynamic> toJson() => {
        "ApiVersion": apiVersion,
        "Version": version,
        "GoVersion": goVersion,
        "GitCommit": gitCommit,
        "BuildTime": builtTime,
        "Built": built,
        "OsArch": osArch,
        "Os": os,
      };
}
