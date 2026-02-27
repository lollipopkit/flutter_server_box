import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
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
  systemd(1058);

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
    snippet => libL10n.snippet,
    //pkg => libL10n.pkg,
    container => libL10n.container,
    process => libL10n.process,
    terminal => libL10n.terminal,
    iperf => 'iperf',
    systemd => 'Systemd',
  };
}
