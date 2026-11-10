import 'dart:io';

import 'package:fl_lib/fl_lib.dart';

/// What the discovery scan reads off this device's own tools, as pure
/// functions of their output, so each one is tested against what the tool
/// actually prints.
abstract final class DiscoveryParse {
  static final _whitespace = RegExp(r'\s+');
  static final _ipv4InParentheses = RegExp(r'\((\d+\.\d+\.\d+\.\d+)\)');
  static final _interfaceLine = RegExp(r'^([a-z0-9]+):');
  static final _ipAddr = RegExp(r'inet (\d+\.\d+\.\d+\.\d+)/(\d+)');
  static final _ifconfigAddr = RegExp(
    r'inet\s+(\d+\.\d+\.\d+\.\d+)\s+netmask\s+0x([0-9a-fA-F]+)(?:\s+broadcast\s+(\d+\.\d+\.\d+\.\d+))?',
  );
  /// `<time>  Add  <flags> <if> <domain>  _ssh._tcp.  <instance name>`; the
  /// name is the rest of the line and may hold spaces.
  static final _sshService = RegExp(r'\sAdd\s+\d+\s+\d+\s+\S+\s+_ssh\._tcp\.\s+(.+?)\s*$');
  static final _dnsSdAddress = RegExp(r'Address\s*=\s*([0-9a-fA-F:\.]+)');
  static final _avahiAddress = RegExp(r'address = \[(.*?)\]');

  /// `ip neigh` / `ip -6 neigh` (Linux): the address leads each line.
  static Set<InternetAddress> ipNeigh(String out, InternetAddressType type) => {
    for (final line in out.split('\n'))
      if (_leading(line) case final ip?)
        if (InternetAddress.tryParse(ip) case final a? when a.type == type) a,
  };

  /// `arp -an` (macOS): the address in parentheses.
  static Set<InternetAddress> arp(String out) => {
    for (final m in _ipv4InParentheses.allMatches(out)) InternetAddress(m.group(1)!),
  };

  /// `ndp -a` (macOS): the address leads each line, under a header.
  static Set<InternetAddress> ndp(String out) =>
      ipNeigh(out, InternetAddressType.IPv6);

  /// `ip -o -4 addr show scope global` (Linux).
  static List<DiscoveryCidr> ipAddr(String out) => [
    for (final m in _ipAddr.allMatches(out))
      DiscoveryCidr.of(InternetAddress(m.group(1)!), int.parse(m.group(2)!)),
  ];

  /// `ifconfig` (macOS): the netmask in hex, the broadcast when given. A line
  /// that names `inet` and does not match is logged and skipped.
  static List<DiscoveryCidr> ifconfig(String out) {
    final res = <DiscoveryCidr>[];
    for (final raw in out.split('\n')) {
      final line = raw.trimRight();
      if (_interfaceLine.hasMatch(line)) continue;
      if (!line.contains('inet ') || line.contains('127.0.0.1')) continue;
      final m = _ifconfigAddr.firstMatch(line);
      if (m == null) {
        Loggers.app.warning('[ssh_discovery] Unexpected ifconfig line: $line');
        continue;
      }
      final ip = InternetAddress(m.group(1)!);
      final mask = int.parse(m.group(2)!, radix: 16);
      final cidr = DiscoveryCidr.of(ip, _maskToPrefix(mask));
      final broadcast = m.group(3);
      res.add(broadcast == null ? cidr : cidr.withBroadcast(InternetAddress(broadcast)));
    }
    return res;
  }

  /// `dns-sd -B _ssh._tcp` (macOS): the service names it lists.
  static List<String> dnsSdServices(Iterable<String> lines) => [
    for (final l in lines)
      if (_sshService.firstMatch(l) case final m?) m.group(1)!,
  ];

  /// `dns-sd -L <name> _ssh._tcp local.` (macOS): the addresses it resolves.
  static Set<InternetAddress> dnsSdAddresses(String out) => {
    for (final m in _dnsSdAddress.allMatches(out))
      ?InternetAddress.tryParse(m.group(1)!),
  };

  /// `avahi-browse -rat _ssh._tcp` (Linux).
  static Set<InternetAddress> avahiAddresses(String out) => {
    for (final m in _avahiAddress.allMatches(out))
      if (m.group(1)! case final ip when ip.isNotEmpty) ?InternetAddress.tryParse(ip),
  };

  /// The first field, without a `%zone`: whether one parses depends on the
  /// platform having that interface.
  static String? _leading(String line) {
    final first = line.trim().split(_whitespace).first.split('%').first;
    return first.isEmpty ? null : first;
  }

  static int _maskToPrefix(int mask) {
    var c = 0;
    for (var i = 31; i >= 0 && (mask & (1 << i)) != 0; i--) {
      c++;
    }
    return c;
  }
}

/// One IPv4 network this device is on.
final class DiscoveryCidr {
  const DiscoveryCidr._(this.ip, this.prefix, this.network, this.broadcast);

  factory DiscoveryCidr.of(InternetAddress ip, int prefix) {
    final mask = prefix == 0 ? 0 : (0xffffffff << (32 - prefix)) & 0xffffffff;
    final n = _toInt(ip.address) & mask;
    final b = n | (~mask & 0xffffffff);
    return DiscoveryCidr._(ip, prefix, InternetAddress(_toIp(n)), InternetAddress(_toIp(b)));
  }

  final InternetAddress ip;
  final int prefix;
  final InternetAddress network;
  final InternetAddress broadcast;

  DiscoveryCidr withBroadcast(InternetAddress b) => DiscoveryCidr._(ip, prefix, network, b);

  /// The addresses between [network] and [broadcast], neither included: none
  /// for a /31 or a /32, which have no such range.
  Iterable<InternetAddress> hosts({int? limit}) sync* {
    final n = _toInt(network.address);
    final b = _toInt(broadcast.address);
    var emitted = 0;
    for (var v = n + 1; v <= b - 1; v++) {
      if (limit != null && emitted >= limit) break;
      emitted++;
      yield InternetAddress(_toIp(v));
    }
  }

  @override
  String toString() => '${network.address}/$prefix';

  static int _toInt(String ip) {
    final p = ip.split('.').map(int.parse).toList();
    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
  }

  static String _toIp(int v) =>
      '${(v >> 24) & 0xff}.${(v >> 16) & 0xff}.${(v >> 8) & 0xff}.${v & 0xff}';
}
