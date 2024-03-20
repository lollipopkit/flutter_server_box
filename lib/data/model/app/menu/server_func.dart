import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:toolbox/core/extension/context/locale.dart';

part 'server_func.g.dart';

@HiveType(typeId: 6)
enum ServerFuncBtn {
  @HiveField(0)
  terminal,
  @HiveField(1)
  sftp,
  @HiveField(2)
  container,
  @HiveField(3)
  process,
  @HiveField(4)
  pkg,
  @HiveField(5)
  snippet,
  @HiveField(6)
  iperf,
  @HiveField(7)
  pve,
  ;

  static const defaultFuncs = [
    terminal,
    sftp,
    container,
    process,
    pkg,
    snippet,
    pve,
  ];

  Icon get icon => switch (this) {
        sftp => const Icon(Icons.insert_drive_file, size: 15),
        snippet => const Icon(Icons.code, size: 15),
        pkg => const Icon(Icons.system_security_update, size: 15),
        container => const Icon(FontAwesome.docker_brand, size: 14),
        process => const Icon(Icons.list_alt_outlined, size: 15),
        terminal => const Icon(Icons.terminal, size: 15),
        iperf => const Icon(Icons.speed, size: 15),
        pve => const Icon(FontAwesome.server_solid, size: 13),
      };

  String get toStr => switch (this) {
        sftp => 'SFTP',
        snippet => l10n.snippet,
        pkg => l10n.pkg,
        container => l10n.container,
        process => l10n.process,
        terminal => l10n.terminal,
        iperf => 'iperf',
        pve => 'PVE',
      };

  int toJson() => index;

  static ServerFuncBtn fromJson(int i) => values[i];
}
