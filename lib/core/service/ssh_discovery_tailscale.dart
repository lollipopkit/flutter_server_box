import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// The peers of the tailnet this device is on, read from the local
/// `tailscale` CLI.
final class TailscaleDiscovery implements SshDiscovery {
  const TailscaleDiscovery(this.cli);

  /// The CLI's path.
  final String cli;

  /// Where the CLI is installed, absolute first: an app started from the
  /// desktop does not get a shell's PATH.
  static List<String> get _candidates => [
    if (isMacOS) ...[
      '/Applications/Tailscale.app/Contents/MacOS/Tailscale',
      '/opt/homebrew/bin/tailscale',
      '/usr/local/bin/tailscale',
    ],
    if (isLinux) ...['/usr/bin/tailscale', '/usr/local/bin/tailscale'],
    if (isWindows) r'C:\Program Files\Tailscale\tailscale.exe',
  ];

  /// The source, when the CLI is installed and this build starts processes.
  static Future<TailscaleDiscovery?> find() async {
    if (!isDesktop || !ProcessExec.isSupported) return null;
    for (final path in _candidates) {
      if (await File(path).exists()) return TailscaleDiscovery(path);
    }
    return null;
  }

  /// Phones and tablets, which do not run an SSH server.
  static const _noSsh = {'iOS', 'android'};

  @override
  String get id => 'tailscale';

  @override
  String get label => 'Tailscale';

  @override
  IconData get icon => Icons.hub_outlined;

  @override
  bool get auto => true;

  @override
  SshDiscoveryCredential? get credential => null;

  @override
  Future<String?> scope() async => null;

  @override
  Future<SshDiscoveryRun> discover({String? input}) async {
    final Process proc;
    try {
      proc = await Process.start(cli, const ['status', '--json']);
    } on ProcessException catch (e, s) {
      Loggers.app.warning('tailscale status', e, s);
      throw _stopped();
    }
    unawaited(proc.stderr.drain<void>());
    try {
      final (out, code) = await (
        proc.stdout.transform(utf8.decoder).join(),
        proc.exitCode,
      ).wait.timeout(const Duration(seconds: 10));
      if (code != 0) throw _stopped();
      return parse(out);
    } on TimeoutException {
      // A wedged daemon leaves the CLI waiting on it.
      proc.kill();
      throw _stopped();
    }
  }

  SshDiscoveryException _stopped() =>
      SshDiscoveryException(l10n.tailscaleStopped, tip: l10n.tailscaleStoppedTip);

  /// The peers of a `tailscale status --json`, by MagicDNS name when the
  /// tailnet has it.
  @visibleForTesting
  SshDiscoveryRun parse(String json) {
    final status = jsonDecode(json) as Map<String, dynamic>;
    if (status['BackendState'] != 'Running') throw _stopped();
    final tailnet = status['CurrentTailnet'] as Map<String, dynamic>? ?? {};
    final magicDns = tailnet['MagicDNSEnabled'] == true;
    final peers = (status['Peer'] as Map<String, dynamic>? ?? {}).values
        .cast<Map<String, dynamic>>();
    final hosts = <DiscoveredSshHost>[];
    for (final p in peers) {
      final os = p['OS'] as String? ?? '';
      if (_noSsh.contains(os)) continue;
      final ips = (p['TailscaleIPs'] as List? ?? const []).cast<String>();
      final ip = ips.firstWhereOrNull((e) => !e.contains(':')) ??
          ips.firstOrNull;
      final dns = (p['DNSName'] as String? ?? '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
      final address = magicDns && dns.isNotEmpty ? dns : ip;
      if (address == null) continue;
      final name = p['HostName'] as String? ?? dns.split('.').first;
      hosts.add(
        DiscoveredSshHost(
          key: p['ID'] as String? ?? address,
          server: Spi(
            name: name.isEmpty ? address : name,
            id: ShortId.generate(),
            ssh: SshCredential(ip: address),
          ),
          detail: [?ip, if (os.isNotEmpty) os].join(' · '),
          online: p['Online'] as bool?,
        ),
      );
    }
    // Online first: the ones that can be reached now.
    hosts.sort((a, b) {
      final on = (b.online == true ? 1 : 0) - (a.online == true ? 1 : 0);
      return on != 0 ? on : a.server.name.compareTo(b.server.name);
    });
    return (
      hosts: hosts,
      scope:
          (tailnet['MagicDNSSuffix'] as String?)?.selfNotEmptyOrNull ??
          tailnet['Name'] as String?,
    );
  }
}
