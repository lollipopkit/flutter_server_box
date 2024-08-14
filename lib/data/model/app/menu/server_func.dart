import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

part 'server_func.g.dart';

@HiveType(typeId: 6)
enum ServerFuncBtn {
  @HiveField(0)
  terminal._(),
  @HiveField(1)
  sftp._(),
  @HiveField(2)
  container._(),
  @HiveField(3)
  process._(),
  //@HiveField(4)
  //pkg,
  @HiveField(5)
  snippet._(),
  @HiveField(6)
  iperf._(),
  // @HiveField(7)
  // pve,
  @HiveField(8)
  systemd._(1058),
  ;

  final int? addedVersion;

  const ServerFuncBtn._([this.addedVersion]);

  static void autoAddNewFuncs(int cur) {
    if (cur >= systemd.addedVersion!) {
      final prop = Stores.setting.serverFuncBtns;
      final list = prop.fetch();
      if (!list.contains(systemd.index)) {
        list.add(systemd.index);
        prop.put(list);
      }
    }
  }

  static final defaultIdxs = [
    terminal,
    sftp,
    container,
    process,
    //pkg,
    snippet,
    systemd,
  ].map((e) => e.index).toList();

  IconData get icon => switch (this) {
        sftp => Icons.insert_drive_file,
        snippet => Icons.code,
        //pkg => Icons.system_security_update,
        container => FontAwesome.docker_brand,
        process => Icons.list_alt_outlined,
        terminal => Icons.terminal,
        iperf => Icons.speed,
        systemd => MingCute.plugin_2_fill,
      };

  String get toStr => switch (this) {
        sftp => 'SFTP',
        snippet => l10n.snippet,
        //pkg => l10n.pkg,
        container => l10n.container,
        process => l10n.process,
        terminal => l10n.terminal,
        iperf => 'iperf',
        systemd => 'Systemd',
      };
}
