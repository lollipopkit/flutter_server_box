import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// The `Host` entries of `~/.ssh/config`, with the `ProxyJump` hops each one
/// needs.
final class SshConfigDiscovery implements SshDiscovery {
  const SshConfigDiscovery();

  static const _path = '~/.ssh/config';

  /// Where the file can be: a desktop. One the sandboxed macOS build cannot
  /// see is still offered, to be picked by hand.
  static Future<bool> isAvailable() async {
    if (!isDesktop) return false;
    if (_sandboxed) return true;
    final (_, exists) = await SSHConfig.configExistsAsync();
    return exists;
  }

  static bool get _sandboxed => isMacOS && !ProcessExec.isSupported;

  @override
  String get id => 'ssh_config';

  @override
  String get label => l10n.sshConfig;

  @override
  IconData get icon => Icons.terminal;

  @override
  bool get auto => true;

  @override
  SshDiscoveryCredential? get credential => null;

  @override
  Future<String?> scope() async => _path;

  @override
  Future<SshDiscoveryRun> discover({String? input}) async {
    final List<Spi> servers;
    try {
      servers = await SSHConfig.parseConfig(input);
    } on FileSystemException catch (e) {
      if (e is! PathAccessException && !'$e'.contains('not permitted')) {
        rethrow;
      }
      throw SshDiscoveryException(
        l10n.sshConfigPermissionDenied,
        tip: l10n.sshConfigManualSelect,
        needsFile: true,
      );
    }
    if (servers.isEmpty && input == null && _sandboxed) {
      throw SshDiscoveryException(
        l10n.sshConfigPermissionDenied,
        tip: l10n.sshConfigManualSelect,
        needsFile: true,
      );
    }
    return (hosts: hostsOf(servers), scope: input ?? _path);
  }

  /// One host per server, each carrying the servers its jumps name.
  @visibleForTesting
  static List<DiscoveredSshHost> hostsOf(List<Spi> servers) {
    final byId = {for (final s in servers) s.id: s};
    List<Spi> via(Spi spi, Set<String> seen) => [
      for (final id in spi.ssh?.resolvedJumpIds ?? const <String>[])
        if (byId[id] case final jump? when seen.add(id)) ...[
          ...via(jump, seen),
          jump,
        ],
    ];
    return [
      for (final s in servers)
        DiscoveredSshHost(
          key: s.name,
          server: s,
          detail: [
            if (s.ssh?.resolvedJumpIds.isNotEmpty ?? false)
              'ProxyJump ${s.ssh!.resolvedJumpIds.map((id) => byId[id]?.name ?? id).join(',')}',
            if (s.ssh?.proxyCommand case final cmd?) 'ProxyCommand $cmd',
          ].join(' · ').selfNotEmptyOrNull,
          via: via(s, {s.id}),
          userKnown: true,
        ),
    ];
  }
}
