import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/ssh_discovery/ssh_discovery.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/src/rust/api/tailscale.dart' as ts_ffi;

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
    final ts_ffi.TailscaleStatusItem status;
    try {
      status = ts_ffi.tailscaleParseStatus(raw: json);
    } on String catch (e, s) {
      Loggers.app.warning('tailscale status parse', e, s);
      throw _stopped();
    }
    if (status.state != 'Running') throw _stopped();
    final magicDns = status.magicDnsEnabled;
    final hosts = <DiscoveredSshHost>[];
    for (final p in status.peers) {
      final os = p.os ?? '';
      if (_noSsh.contains(os)) continue;
      final ip =
          p.ips.firstWhereOrNull((e) => !e.contains(':')) ?? p.ips.firstOrNull;
      final dns = p.dnsName ?? '';
      final address = magicDns && dns.isNotEmpty ? dns : ip;
      if (address == null) continue;
      final name = p.name.isNotEmpty ? p.name : dns.split('.').first;
      hosts.add(
        DiscoveredSshHost(
          key: p.id.isNotEmpty ? p.id : address,
          server: Spi(
            name: name.isEmpty ? address : name,
            id: ShortId.generate(),
            ssh: SshCredential(ip: address),
          ),
          detail: [?ip, if (os.isNotEmpty) os].join(' · '),
          online: p.online,
        ),
      );
    }
    // Online first: the ones that can be reached now. Re-sort after name
    // fallback in case a peer had an empty HostName.
    hosts.sort((a, b) {
      final on = (b.online == true ? 1 : 0) - (a.online == true ? 1 : 0);
      return on != 0 ? on : a.server.name.compareTo(b.server.name);
    });
    return (
      hosts: hosts,
      scope: status.magicDnsSuffix ?? status.tailnet,
    );
  }
}
