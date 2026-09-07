import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/server/capabilities.dart';

enum ServerFuncBtn {
  terminal(),

  /// Not `sftp`: SFTP is one of two ways a server's files are reached, and
  /// which one it is belongs to `ServerFilePage` rather than to the entry that
  /// opens it. A monitor-backed host with no reachable sshd browses over its
  /// agent's file API and never sees SFTP at all.
  files(),
  container(),
  process(),
  snippet(),
  iperf(),
  systemd(1051),
  portForward(1340),
  power(1491);

  /// See [Feature.since].
  final int? introducedAfterBuild;

  const ServerFuncBtn([this.introducedAfterBuild]);

  /// This entry as the registry sees it. [id] is what is stored.
  Feature get feature => Feature(
    id: id,
    slot: FeatureSlot.funcBtn,
    icon: icon,
    label: () => toStr,
    since: introducedAfterBuild,
    needs: availableWith,
  );

  /// Stable, and deliberately not the index.
  ///
  /// It used to be: `serverBtns` held `ServerFuncBtn.index`, so moving a case
  /// silently re-pointed every entry in every stored row — and a row survives
  /// a backup, a sync and an upgrade. `m021` converted the stored lists;
  /// `kLegacyServerFuncBtnIds` is the table it converted them with, and the
  /// declaration order here has been free to change ever since.
  String get id => name;

  /// The row a fresh install starts with. Not every entry: this list *is* the
  /// row, and what is left out is behind "more".
  static final defaultIds = [
    terminal,
    files,
    container,
    process,
    snippet,
    systemd,
    portForward,
    power,
  ].map((e) => e.id).toList();

  IconData get icon => switch (this) {
    // The file tab's own icon, since that is where this entry lands.
    files => Icons.folder_open,
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
    files => caps.files,
    // A forwarded connection is a byte stream, not a command's output.
    portForward => caps.byteStream,
  };

  String get toStr => switch (this) {
    // Named after what it opens, not after the protocol that used to be the
    // only way to get there — the same word the file tab carries.
    files => libL10n.file,
    snippet => libL10n.snippet,
    container => libL10n.container,
    process => libL10n.process,
    terminal => libL10n.terminal,
    iperf => 'iperf',
    systemd => l10n.services,
    portForward => libL10n.portForward,
    power => l10n.power,
  };
}
