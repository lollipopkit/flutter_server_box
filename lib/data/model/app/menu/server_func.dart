import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/res/store.dart';

enum ServerFuncBtn {
  terminal(),
  sftp(),
  container(),
  process(),
  snippet(),
  iperf(),
  systemd(1058),
  portForward(1340),
  power(1481);

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

    if (power.addedVersion != null && cur >= power.addedVersion!) {
      if (!list.contains(power.index)) {
        list.add(power.index);
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
    snippet,
    systemd,
    portForward,
    power,
  ].map((e) => e.index).toList();

  IconData get icon => switch (this) {
    sftp => Icons.insert_drive_file,
    snippet => Icons.code,
    container => FontAwesome.docker_brand,
    process => Icons.list_alt_outlined,
    terminal => Icons.terminal,
    iperf => Icons.speed,
    systemd => MingCute.plugin_2_fill,
    portForward => Icons.compare_arrows,
    power => Icons.power_settings_new,
  };

  /// Whether a connection with [caps] can actually do what this entry opens.
  ///
  /// Asked of the capabilities rather than of the transport, and asked per
  /// entry rather than once for all of them: these three needs are genuinely
  /// different, and a server reached over its monitor agent meets two of them.
  bool availableWith(ServerCapabilities caps) => switch (this) {
    // All three end in the terminal — snippets and iperf hand it a command to
    // start with, and nothing else.
    terminal || snippet || iperf => caps.terminal,
    container || process || systemd || power => caps.shell,
    // Browsing files is its own question: a transport could grow a file API
    // without growing a stream this app can point anywhere.
    sftp => caps.files,
    // A forwarded connection is a byte stream, not a command's output.
    portForward => caps.byteStream,
  };

  String get toStr => switch (this) {
    sftp => 'SFTP',
    snippet => libL10n.snippet,
    container => libL10n.container,
    process => libL10n.process,
    terminal => libL10n.terminal,
    iperf => 'iperf',
    systemd => 'Systemd',
    portForward => libL10n.portForward,
    power => l10n.power,
  };
}
