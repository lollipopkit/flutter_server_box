import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

enum ServerFuncBtn {
  terminal(),
  sftp(),
  container(),
  process(),
  //pkg(),
  snippet(),
  iperf(),
  // pve(),
  systemd(1058),
  ;

  final int? addedVersion;

  const ServerFuncBtn([this.addedVersion]);

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
