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
  systemd(1058),
  portForward(1340);

  final int? addedVersion;

  const ServerFuncBtn([this.addedVersion]);

  static void autoAddNewFuncs(int cur) {
    final prop = Stores.setting.serverFuncBtns;
    final list = prop.fetch();
    final originalLength = list.length;

    if (systemd.addedVersion != null && cur >= systemd.addedVersion!) {
      if (!list.contains(systemd.index)) {
        list.add(systemd.index);
      }
    }

    if (portForward.addedVersion != null && cur >= portForward.addedVersion!) {
      if (!list.contains(portForward.index)) {
        list.add(portForward.index);
      }
    }

    if (list.length > originalLength) {
      prop.put(list);
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
    portForward,
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
    portForward => Icons.compare_arrows,
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
    portForward => libL10n.portForward,
  };
}
