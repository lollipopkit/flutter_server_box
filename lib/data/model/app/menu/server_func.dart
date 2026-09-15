import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/res/store.dart';

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
  power(1491),
  users(1579),
  scheduledTasks(1579),
  remoteDesktop(1617);

  /// The last released build that did not contain this entry.
  ///
  /// A feature branch's commit count is not a release number: Power was
  /// developed at build 1481 but merged after v1.0.1491, so using 1481 made a
  /// v1491 install look as though it had already seen the entry. A release
  /// boundary remains true no matter how many commits the branch accumulated
  /// before the next tag.
  final int? introducedAfterBuild;

  const ServerFuncBtn([this.introducedAfterBuild]);

  /// Puts entries that arrived during an upgrade into the user's row, which
  /// was last written when they did not exist.
  ///
  /// The window is `(from, to]`, not "everything up to [to]". An entry the
  /// user has since taken *out* of the row was a decision, and a rule that
  /// only looks at [to] re-adds it on every later upgrade — overruling that
  /// decision every time, forever. Only an entry that did not exist the last
  /// time they could have chosen is added.
  ///
  /// [from] is the build this install last ran, 0 on a fresh one — where
  /// [defaultNames] already lists every entry that carries a boundary, so
  /// nothing here fires. An entry left out of the defaults must therefore also
  /// have no [introducedAfterBuild], or a fresh install would be the only kind
  /// that never gets it.
  ///
  /// Driven by [introducedAfterBuild] over [values] rather than by a branch per entry:
  /// the old form needed three near-identical blocks, and a new entry was
  /// added by remembering to write a fourth.
  static void autoAddNewFuncs(int from, int to) {
    final prop = Stores.setting.serverFuncBtns;
    final list = prop.fetch();
    final added = [
      for (final btn in values)
        if (btn.introducedAfterBuild case final boundary?
            when boundary >= from && boundary < to && !list.contains(btn.name))
          btn.name,
    ];
    if (added.isEmpty) return;
    prop.putSync([...list, ...added]);
  }

  static final defaultNames = [
    terminal,
    files,
    container,
    process,
    snippet,
    systemd,
    portForward,
    power,
    users,
    scheduledTasks,
    remoteDesktop,
  ].map((e) => e.name).toList();

  /// The entry a stored row names.
  ///
  /// The enum order used by releases before the name migration.
  ///
  /// This is deliberately separate from [values]. An integer from an older
  /// build must be resolved against the order that wrote it, never today's
  /// declaration order, or a removed entry silently selects another button.
  static const legacyIndexNamesBeforeM021 = <String>[
    'terminal',
    'files',
    'container',
    'process',
    'snippet',
    'iperf',
    'systemd',
    'portForward',
    'power',
  ];

  static const _storedLayoutKey = 'layout';
  static const _storedValuesKey = 'values';
  static const _currentLayout = 'current';
  static const _legacyLayoutBeforeM021 = 'preM021';

  /// Wraps newly synchronized rows with the layout that wrote them.
  static Map<String, Object?>? toStored(List<String>? names) => names == null
      ? null
      : {
          _storedLayoutKey: _currentLayout,
          _storedValuesKey: List<String>.from(names),
        };

  /// Resolves a stored name or current-layout index.
  ///
  /// Pass [legacyIntegerNames] only when the row's provenance proves that it
  /// was written in that older layout. Tagged rows select their own mapping;
  /// untagged integer rows are retained for old backups and use the legacy
  /// mapping only when every integer fits that nine-entry layout. A row with
  /// index 9 or above therefore remains on the current layout, preserving
  /// post-feature entries. Once supplied, out-of-range legacy integers are
  /// rejected instead of falling through to the current enum layout.
  static ServerFuncBtn? byStored(
    Object? stored, {
    List<String>? legacyIntegerNames,
  }) {
    if (stored is String) {
      return values.firstWhereOrNull((btn) => btn.name == stored);
    }
    if (stored is! int) return null;
    if (legacyIntegerNames case final names?) {
      if (stored < 0 || stored >= names.length) return null;
      final name = names[stored];
      return values.firstWhereOrNull((btn) => btn.name == name);
    }
    return stored >= 0 && stored < values.length ? values[stored] : null;
  }

  /// A stored list in either shape, as names this build knows.
  ///
  /// An entry that resolves to nothing is dropped rather than shifting the
  /// ones after it, which is the whole point of the change.
  static List<String> namesFromStored(
    Object? stored, {
    List<String>? legacyIntegerNames,
  }) {
    var values = stored;
    var integerNames = legacyIntegerNames;
    if (stored is Map && stored[_storedValuesKey] is Iterable) {
      values = stored[_storedValuesKey];
      switch (stored[_storedLayoutKey]) {
        case _legacyLayoutBeforeM021:
          integerNames = legacyIndexNamesBeforeM021;
        case _currentLayout:
          integerNames = null;
      }
    }
    if (values is! Iterable) return defaultNames;
    if (integerNames == null) {
      final ints = values.whereType<int>().toList();
      if (ints.isNotEmpty &&
          ints.every(
            (index) =>
                index >= 0 && index < legacyIndexNamesBeforeM021.length,
          )) {
        integerNames = legacyIndexNamesBeforeM021;
      }
    }
    return [
      for (final entry in values)
        if (byStored(entry, legacyIntegerNames: integerNames)
            case final btn?)
          btn.name,
    ];
  }

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
    users => Icons.manage_accounts_outlined,
    scheduledTasks => Icons.schedule,
    remoteDesktop => Icons.desktop_windows_outlined,
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
    container || process || systemd || power || users || scheduledTasks =>
      caps.shell,
    // Browsing files is its own question: a transport could grow a file API
    // without growing a stream this app can point anywhere.
    files => caps.files,
    // A forwarded connection is a byte stream, not a command's output.
    portForward || remoteDesktop => caps.byteStream,
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
    users => l10n.systemUsers,
    scheduledTasks => l10n.scheduledTasks,
    remoteDesktop => l10n.remoteDesktop,
  };
}
