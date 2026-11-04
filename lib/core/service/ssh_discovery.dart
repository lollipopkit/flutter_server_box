import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/service/ssh_discovery_parse.dart';
import 'package:server_box/data/model/server/discovery_result.dart';

// Reused across discovery passes to avoid recompiling each pattern per host.

class SshDiscoveryService {
  static const _sshPort = 22;

  static Future<SshDiscoveryReport> discover([
    SshDiscoveryConfig config = const SshDiscoveryConfig(),
  ]) async {
    final t0 = DateTime.now();
    final candidates = <InternetAddress>{};

    // Seed candidates from the local ARP and NDP tables.
    candidates.addAll(await _neighborsIPv4());
    candidates.addAll(await _neighborsIPv6());

    // Enumerate only small local IPv4 subnets to keep the scan bounded.
    final cidrs = await _localIPv4Cidrs();
    for (final c in cidrs) {
      if (c.prefix >= 24 && c.prefix <= 30) {
        candidates.addAll(c.hosts(limit: config.hostEnumerationLimit));
      }
    }

    // Add SSH services advertised through mDNS/Bonjour when requested.
    if (config.enableMdns) {
      candidates.addAll(await _mdnsSshCandidates());
    }

    // Keep only addresses that may identify another reachable host.
    candidates.removeWhere(
      (a) =>
          a.isLoopback ||
          a.isLinkLocal ||
          a.address == '0.0.0.0' ||
          _isBroadcastOrMulticast(a),
    );

    final scanner = _Scanner(
      timeout: Duration(milliseconds: config.timeoutMs),
      maxConcurrency: config.maxConcurrency,
    );

    final results = await scanner.scan(candidates.toList(growable: false));
    results.sort((a, b) => a.addr.address.compareTo(b.addr.address));

    final discoveryResults = results
        .map(
          (r) => SshDiscoveryResult(
            ip: r.addr.address,
            port: _sshPort,
            banner: r.banner?.trim(),
          ),
        )
        .toList();

    return SshDiscoveryReport(
      generatedAt: DateTime.now().toIso8601String(),
      durationMs: DateTime.now().difference(t0).inMilliseconds,
      count: discoveryResults.length,
      items: discoveryResults,
    );
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

        for (final name in DiscoveryParse.dnsSdServices(lines)) {
          final det = await _run('/usr/bin/dns-sd', [
            '-L',
            name,
            '_ssh._tcp',
            'local.',
          ], timeout: const Duration(seconds: 3));
          if (det != null) set.addAll(DiscoveryParse.dnsSdAddresses(det));
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
        SshDiscoveryService._sshPort,
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
    } catch (e, s) {
      Loggers.app.warning('Failed to probe SSH at ${ip.address}', e, s);
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
