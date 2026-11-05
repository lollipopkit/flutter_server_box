import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/core/service/ssh_discovery_parse.dart';

/// Hosts on this device's local networks that answer on port 22: the ARP and
/// NDP neighbours, every address of a /24 to /30 subnet, and mDNS `_ssh._tcp`.
final class LanSshDiscovery implements SshDiscovery {
  const LanSshDiscovery();

  static const _sshPort = 22;
  static const _timeout = Duration(milliseconds: 700);
  static const _maxConcurrency = 128;
  static const _hostEnumerationLimit = 4096;

  /// The neighbour tables and interfaces are read with Linux and macOS tools.
  static bool get isSupported => Platform.isLinux || Platform.isMacOS;

  @override
  String get id => 'lan';

  @override
  String get label => l10n.lan;

  @override
  IconData get icon => Icons.wifi;

  @override
  Future<String?> scope() async {
    final cidrs = (await _localIPv4Cidrs()).where(_enumerated);
    return cidrs.isEmpty ? null : cidrs.join(', ');
  }

  static bool _enumerated(DiscoveryCidr c) => c.prefix >= 24 && c.prefix <= 30;

  @override
  Future<List<DiscoveredSshHost>> discover() async {
    // mDNS takes seconds of listening; the tables are read meanwhile.
    final mdns = _mdnsSshCandidates();
    final (v4, v6, cidrs) = await (
      _neighborsIPv4(),
      _neighborsIPv6(),
      _localIPv4Cidrs(),
    ).wait;
    final candidates = <InternetAddress>{...v4, ...v6};
    for (final c in cidrs) {
      if (_enumerated(c)) {
        candidates.addAll(c.hosts(limit: _hostEnumerationLimit));
      }
    }
    candidates.addAll(await mdns);

    // Keep only addresses that may identify another reachable host.
    candidates.removeWhere(
      (a) =>
          a.isLoopback ||
          a.isLinkLocal ||
          a.address == '0.0.0.0' ||
          _isBroadcastOrMulticast(a),
    );

    final scanner = _Scanner(timeout: _timeout, maxConcurrency: _maxConcurrency);
    final results = await scanner.scan(candidates.toList(growable: false));
    results.sort((a, b) => _compareAddr(a.addr, b.addr));
    return [
      for (final r in results)
        DiscoveredSshHost(
          host: r.addr.address,
          port: _sshPort,
          detail: r.banner?.trim(),
        ),
    ];
  }

  /// Numeric, so `192.168.1.10` follows `192.168.1.9`.
  static int _compareAddr(InternetAddress a, InternetAddress b) {
    final x = a.rawAddress, y = b.rawAddress;
    if (x.length != y.length) return x.length - y.length;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return x[i] - y[i];
    }
    return 0;
  }

  static Future<String?> _run(
    String exe,
    List<String> args, {
    Duration? timeout,
  }) async {
    try {
      final p = await Process.start(exe, args, runInShell: false);
      final out = await p.stdout
          .transform(utf8.decoder)
          .join()
          .timeout(
            timeout ?? const Duration(seconds: 5),
            onTimeout: () {
              p.kill();
              return '';
            },
          );
      final code = await p.exitCode;
      if (code == 0) return out;
      // Discovery tools may return partial output with a non-zero exit code.
      if (out.trim().isNotEmpty) return out;
      return null;
    } catch (e, s) {
      Loggers.app.warning(
        'Failed to run command: $exe ${args.join(' ')}',
        e,
        s,
      );
      return null;
    }
  }

  static bool get _isLinux => Platform.isLinux;
  static bool get _isMac => Platform.isMacOS;

  static Future<Set<InternetAddress>> _neighborsIPv4() async {
    if (_isLinux) {
      final s = await _run('ip', ['neigh']);
      return s == null ? {} : DiscoveryParse.ipNeigh(s, InternetAddressType.IPv4);
    }
    if (_isMac) {
      final s = await _run('/usr/sbin/arp', ['-an']);
      if (s == null) return {};
      final found = DiscoveryParse.arp(s);
      if (found.isEmpty) {
        Loggers.app.warning(
          '[ssh_discovery] No ARP entries parsed on macOS; the output may be localized: '
          '${s.length > 100 ? '${s.substring(0, 100)}...' : s}',
        );
      }
      return found;
    }
    return {};
  }

  static Future<Set<InternetAddress>> _neighborsIPv6() async {
    final s = _isLinux
        ? await _run('ip', ['-6', 'neigh'])
        : _isMac
        ? await _run('/usr/sbin/ndp', ['-a'])
        : null;
    return s == null ? {} : DiscoveryParse.ndp(s);
  }

  static Future<List<DiscoveryCidr>> _localIPv4Cidrs() async {
    if (_isLinux) {
      final s = await _run('ip', ['-o', '-4', 'addr', 'show', 'scope', 'global']);
      return s == null ? const [] : DiscoveryParse.ipAddr(s);
    }
    if (_isMac) {
      final s = await _run('/sbin/ifconfig', []);
      return s == null ? const [] : DiscoveryParse.ifconfig(s);
    }
    return const [];
  }

  static bool _isBroadcastOrMulticast(InternetAddress a) {
    // IPv4 broadcast: ends with .255 or is 255.255.255.255
    if (a.type == InternetAddressType.IPv4) {
      if (a.address == '255.255.255.255') return true;
      if (a.address.split('.').last == '255') return true;
      // Multicast: 224.0.0.0 - 239.255.255.255
      final firstOctet = int.tryParse(a.address.split('.').first) ?? 0;
      if (firstOctet >= 224 && firstOctet <= 239) return true;
    } else if (a.type == InternetAddressType.IPv6) {
      // IPv6 multicast: starts with ff
      if (a.address.toLowerCase().startsWith('ff')) return true;
    }
    return false;
  }

  static Future<Set<InternetAddress>> _mdnsSshCandidates() async {
    final set = <InternetAddress>{};
    if (_isMac) {
      try {
        final proc = await Process.start('/usr/bin/dns-sd', [
          '-B',
          '_ssh._tcp',
        ]);
        final lines = <String>[];
        final subscription = proc.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(lines.add);
        await Future<void>.delayed(const Duration(seconds: 2));
        proc.kill();
        await subscription.cancel();

        // At once: `dns-sd -L` never exits on its own, so each lookup lasts
        // its whole timeout.
        final details = await Future.wait([
          for (final name in DiscoveryParse.dnsSdServices(lines))
            _run('/usr/bin/dns-sd', [
              '-L',
              name,
              '_ssh._tcp',
              'local.',
            ], timeout: const Duration(seconds: 3)),
        ]);
        for (final det in details.nonNulls) {
          set.addAll(DiscoveryParse.dnsSdAddresses(det));
        }
      } catch (e, s) {
        Loggers.app.warning(
          'Failed to discover mDNS SSH candidates on macOS',
          e,
          s,
        );
      }
    } else if (_isLinux) {
      // By name, resolved on PATH, the way `ip` above is. An absolute
      // /usr/bin is a guess about the filesystem rather than about the tool —
      // and it is wrong on NixOS, where nothing but /bin/sh and /usr/bin/env
      // live at an FHS path.
      final s = await _run('avahi-browse', ['-rat', '_ssh._tcp']);
      if (s != null) set.addAll(DiscoveryParse.avahiAddresses(s));
    }
    return set;
  }
}

class _ScanResult {
  final InternetAddress addr;
  final String? banner;
  _ScanResult(this.addr, this.banner);
}

class _Scanner {
  final Duration timeout;
  final int maxConcurrency;
  _Scanner({required this.timeout, required this.maxConcurrency});

  Future<List<_ScanResult>> scan(List<InternetAddress> addrs) async {
    final sem = _Semaphore(maxConcurrency);
    final futures = <Future<_ScanResult?>>[];
    for (final a in addrs) {
      futures.add(_guarded(sem, () => _probeSsh(a)));
    }
    final out = await Future.wait(futures);
    return out.whereType<_ScanResult>().toList();
  }

  Future<_ScanResult?> _probeSsh(InternetAddress ip) async {
    Socket? socket;
    StreamSubscription? sub;
    try {
      socket = await Socket.connect(
        ip,
        LanSshDiscovery._sshPort,
        timeout: timeout,
      );
      socket.timeout(timeout);
      final c = Completer<String?>();
      sub = socket.listen(
        (data) {
          final s = utf8.decode(data, allowMalformed: true);
          final line = s.split('\n').firstWhere((_) => true, orElse: () => s);
          if (!c.isCompleted) {
            c.complete(line.trim());
            sub?.cancel();
          }
        },
        onDone: () {
          if (!c.isCompleted) c.complete(null);
        },
        onError: (_) {
          if (!c.isCompleted) c.complete(null);
        },
      );
      final banner = await c.future.timeout(timeout, onTimeout: () => null);
      return _ScanResult(ip, banner);
    } catch (_) {
      // Most addresses of a subnet refuse or time out; that is the answer.
      return null;
    } finally {
      await sub?.cancel();
      socket?.destroy();
    }
  }
}

class _Semaphore {
  int _permits;
  final Queue<Completer<void>> _q = Queue();
  _Semaphore(this._permits);

  Future<T> withPermit<T>(Future<T> Function() fn) async {
    if (_permits > 0) {
      _permits--;
      try {
        return await fn();
      } finally {
        _permits++;
        if (_q.isNotEmpty) _q.removeFirst().complete();
      }
    } else {
      final c = Completer<void>();
      _q.add(c);
      await c.future;
      return withPermit(fn);
    }
  }
}

Future<T> _guarded<T>(_Semaphore sem, Future<T> Function() fn) =>
    sem.withPermit(fn);
