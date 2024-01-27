import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  ;

  IconData get icon => switch (this) {
        sftp => Icons.insert_drive_file,
        snippet => Icons.code,
        pkg => Icons.system_security_update,
        container => Icons.view_agenda,
        process => Icons.list_alt_outlined,
        terminal => Icons.terminal,
        iperf => Icons.speed,
      };

  String get toStr => switch (this) {
        sftp => 'SFTP',
        snippet => l10n.snippet,
        pkg => l10n.pkg,
        container => l10n.container,
        process => l10n.process,
        terminal => l10n.terminal,
        iperf => 'iperf',
      };

  int toJson() => index;

  static ServerFuncBtn fromJson(int i) => values[i];
}
