import 'dart:io';
import 'package:toolbox/core/utils/misc.dart' show getHome, pathJoin;
import 'package:toolbox/data/model/app/error.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'private_key_info.g.dart';

@HiveType(typeId: 1)
class PrivateKeyInfo {
  @HiveField(0)
  late String id;
  @HiveField(1)
  late String privateKey;
  @HiveField(2)
  late String password;

  PrivateKeyInfo(
    this.id,
    this.privateKey,
    this.password,
  );
  PrivateKeyInfo.fromJson(Map<String, dynamic> json) {
    id = json["id"].toString();
    privateKey = json["private_key"].toString();
    password = json["password"].toString();
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["id"] = id;
    data["private_key"] = privateKey;
    data["password"] = password;
    return data;
  }
}

class SystemPrivateKeyInfo extends PrivateKeyInfo {
  SystemPrivateKeyInfo() : super("System private key", "", "");

  Future getKey() async {
    File idRsaFile = File(pathJoin(getHome(), ".ssh/id_rsa"));
    if (!await idRsaFile.exists()) {
      this.privateKey="";
    }
    this.privateKey= await idRsaFile.readAsString();
  }
}
