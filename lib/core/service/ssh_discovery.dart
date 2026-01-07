import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/discovery_result.dart';

class SshDiscoveryService {
  static const _sshPort = 22;

  static Future<SshDiscoveryReport> discover([SshDiscoveryConfig config = const SshDiscoveryConfig()]) async {
    final t0 = DateTime.now();
    final candidates = <InternetAddress>{};

    // 1) Get neighbors from ARP/NDP tables
    candidates.addAll(await _neighborsIPv4());
    candidates.addAll(await _neighborsIPv6());

    // 2) Enumerate small subnets from local interfaces (IPv4 only)
    final cidrs = await _localIPv4Cidrs();
    for (final c in cidrs) {
      if (c.prefix >= 24 && c.prefix <= 30) {
        candidates.addAll(c.enumerateHosts(limit: config.hostEnumerationLimit));
      }
    }

    // 3) Optional: mDNS/Bonjour SSH services
    if (config.enableMdns) {
      candidates.addAll(await _mdnsSshCandidates());
    }

    // Filter out unwanted addresses: loopback, link-local, 0.0.0.0, broadcast, multicast
    candidates.removeWhere(
      (a) => a.isLoopback || a.isLinkLocal || a.address == '0.0.0.0' || _isBroadcastOrMulticast(a),
    );

    // 4) Concurrent SSH port scanning
    final scanner = _Scanner(
      timeout: Duration(milliseconds: config.timeoutMs),
      maxConcurrency: config.maxConcurrency,
    );

    final results = await scanner.scan(candidates.toList(growable: false));
    results.sort((a, b) => a.addr.address.compareTo(b.addr.address));

    final discoveryResults = results
        .map((r) => SshDiscoveryResult(ip: r.addr.address, port: _sshPort, banner: r.banner?.trim()))
        .toList();

    return SshDiscoveryReport(
      generatedAt: DateTime.now().toIso8601String(),
      durationMs: DateTime.now().difference(t0).inMilliseconds,
      count: discoveryResults.length,
      items: discoveryResults,
    );
  }

  static Future<String?> _run(String exe, List<String> args, {Duration? timeout}) async {
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
      // Some tools return non-zero but still have useful output
      if (out.trim().isNotEmpty) return out;
      return null;
    } catch (e, s) {
      Loggers.app.warning('Failed to run command: $exe ${args.join(' ')}', e, s);
      return null;
    }
  }

  static bool get _isLinux => Platform.isLinux;
  static bool get _isMac => Platform.isMacOS;

  static Future<Set<InternetAddress>> _neighborsIPv4() async {
    final set = <InternetAddress>{};
    if (_isLinux) {
      final s = await _run('ip', ['neigh']);
      if (s != null) {
        for (final line in const LineSplitter().convert(s)) {
          final tok = line.split(RegExp(r'\s+'));
          if (tok.isNotEmpty) {
            final ip = tok[0];
            if (InternetAddress.tryParse(ip)?.type == InternetAddressType.IPv4) {
              set.add(InternetAddress(ip));
            }
          }
        }
      }
    } else if (_isMac) {
      final s = await _run('/usr/sbin/arp', ['-an']);
      if (s != null) {
        int matchCount = 0;
        for (final line in const LineSplitter().convert(s)) {
          final m = RegExp(r'\((\d+\.\d+\.\d+\.\d+)\)').firstMatch(line);
          if (m != null) {
            set.add(InternetAddress(m.group(1)!));
            matchCount++;
          }
        }
        if (matchCount == 0) {
          lprint(
            '[ssh_discovery] Warning: No ARP entries parsed on macOS. Output may be unexpected or localized. Output sample: ${s.length > 100 ? '${s.substring(0, 100)}...' : s}',
          );
        }
      }
    }
    return set;
  }

  static Future<Set<InternetAddress>> _neighborsIPv6() async {
    final set = <InternetAddress>{};
    if (_isLinux) {
      final s = await _run('ip', ['-6', 'neigh']);
      if (s != null) {
        for (final line in const LineSplitter().convert(s)) {
          final ip = line.split(RegExp(r'\s+')).firstOrNull;
          if (ip != null && InternetAddress.tryParse(ip)?.type == InternetAddressType.IPv6) {
            set.add(InternetAddress(ip));
          }
        }
      }
    } else if (_isMac) {
      final s = await _run('/usr/sbin/ndp', ['-a']);
      if (s != null) {
        for (final line in const LineSplitter().convert(s)) {
          final ip = line.trim().split(RegExp(r'\s+')).firstOrNull;
          if (ip != null && InternetAddress.tryParse(ip)?.type == InternetAddressType.IPv6) {
            set.add(InternetAddress(ip));
          }
        }
      }
    }
    return set;
  }

  static Future<List<_Cidr>> _localIPv4Cidrs() async {
    final res = <_Cidr>[];
    if (_isLinux) {
      final s = await _run('ip', ['-o', '-4', 'addr', 'show', 'scope', 'global']);
      if (s != null) {
        for (final line in const LineSplitter().convert(s)) {
          final m = RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)\/(\d+)').firstMatch(line);
          if (m != null) {
            final ip = InternetAddress(m.group(1)!);
            final prefix = int.parse(m.group(2)!);
            final mask = _prefixToMask(prefix);
            final net = _networkAddress(ip, mask);
            final brd = _broadcastAddress(ip, mask);
            res.add(_Cidr(ip, prefix, mask, net, brd));
          }
        }
      }
    } else if (_isMac) {
      final s = await _run('/sbin/ifconfig', []);
      if (s != null) {
        for (final raw in const LineSplitter().convert(s)) {
          final line = raw.trimRight();
          final ifMatch = RegExp(r'^([a-z0-9]+):').firstMatch(line);
          if (ifMatch != null) {
            continue;
          }
          if (line.contains('inet ') && !line.contains('127.0.0.1')) {
            try {
              final ipm = RegExp(
                r'inet\s+(\d+\.\d+\.\d+\.\d+)\s+netmask\s+0x([0-9a-fA-F]+)(?:\s+broadcast\s+(\d+\.\d+\.\d+\.\d+))?',
              ).firstMatch(line);
              if (ipm == null) {
                // Log unexpected format but continue processing other lines
                lprint('[ssh_discovery] Warning: Unexpected ifconfig line format: $line');
                continue;
              }
              final ip = InternetAddress(ipm.group(1)!);
              final hexMask = int.parse(ipm.group(2)!, radix: 16);
              final dotted =
                  '${(hexMask >> 24) & 0xff}.${(hexMask >> 16) & 0xff}.${(hexMask >> 8) & 0xff}.${hexMask & 0xff}';
              final mask = InternetAddress(dotted);
              final prefix = _maskToPrefix(mask.address);
              final net = _networkAddress(ip, mask);
              final brd = InternetAddress(ipm.group(3) ?? _broadcastAddress(ip, mask).address);
              res.add(_Cidr(ip, prefix, mask, net, brd));
            } catch (e) {
              lprint('[ssh_discovery] Error parsing ifconfig output: $e, line: $line');
              continue;
            }
          }
        }
      }
    }
    return res;
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
        final proc = await Process.start('/usr/bin/dns-sd', ['-B', '_ssh._tcp']);
        final lines = <String>[];
        final subscription = proc.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(lines.add);
        await Future<void>.delayed(const Duration(seconds: 2));
        proc.kill();
        await subscription.cancel();

        for (final l in lines) {
          final m = RegExp(r'Add\s+\d+\s+(\S+)\.\s+_ssh\._tcp\.').firstMatch(l);
          if (m != null) {
            final name = m.group(1)!;
            final det = await _run('/usr/bin/dns-sd', [
              '-L',
              name,
              '_ssh._tcp',
              'local.',
            ], timeout: const Duration(seconds: 3));
            if (det != null) {
              for (final ip in RegExp(
                r'Address\s*=\s*([0-9a-fA-F:\.]+)',
              ).allMatches(det).map((e) => e.group(1)!)) {
                final parsed = InternetAddress.tryParse(ip);
                if (parsed != null) set.add(parsed);
              }
            }
          }
        }
      } catch (e, s) {
        Loggers.app.warning('Failed to discover mDNS SSH candidates on macOS', e, s);
      }
    } else if (_isLinux) {
      final s = await _run('/usr/bin/avahi-browse', ['-rat', '_ssh._tcp']);
      if (s != null) {
        for (final ip in RegExp(
          r'address = \[(.*?)\]',
        ).allMatches(s).map((m) => m.group(1)!).where((e) => e.isNotEmpty)) {
          final parsed = InternetAddress.tryParse(ip);
          if (parsed != null) set.add(parsed);
        }
      }
    }
    return set;
  }
}

class _Cidr {
  final InternetAddress ip;
  final int prefix;
  final InternetAddress netmask;
  final InternetAddress network;
  final InternetAddress broadcast;

  _Cidr(this.ip, this.prefix, this.netmask, this.network, this.broadcast);

  Iterable<InternetAddress> enumerateHosts({int? limit}) sync* {
    final n = _ipv4ToInt(network.address);
    final b = _ipv4ToInt(broadcast.address);
    int emitted = 0;
    for (int v = n + 1; v <= b - 1; v++) {
      if (limit != null && emitted >= limit) break;
      emitted++;
      yield InternetAddress(_intToIPv4(v));
    }
  }

  @override
  String toString() => '${network.address}/$prefix';
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
      socket = await Socket.connect(ip, SshDiscoveryService._sshPort, timeout: timeout);
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
      sub?.cancel();
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

Future<T> _guarded<T>(_Semaphore sem, Future<T> Function() fn) => sem.withPermit(fn);

// IPv4 utilities

int _ipv4ToInt(String ip) {
  final p = ip.split('.').map(int.parse).toList();
  return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

String _intToIPv4(int v) => '${(v >> 24) & 0xff}.${(v >> 16) & 0xff}.${(v >> 8) & 0xff}.${v & 0xff}';

InternetAddress _prefixToMask(int prefix) {
  final mask = prefix == 0 ? 0 : 0xffffffff << (32 - prefix);
  return InternetAddress(_intToIPv4(mask & 0xffffffff));
}

int _maskToPrefix(String mask) {
  final v = _ipv4ToInt(mask);
  int c = 0;
  for (int i = 31; i >= 0; i--) {
    if ((v & (1 << i)) != 0) {
      c++;
    } else {
      break;
    }
  }
  return c;
}

InternetAddress _networkAddress(InternetAddress ip, InternetAddress mask) {
  final v = _ipv4ToInt(ip.address) & _ipv4ToInt(mask.address);
  return InternetAddress(_intToIPv4(v));
}

InternetAddress _broadcastAddress(InternetAddress ip, InternetAddress mask) {
  final n = _ipv4ToInt(ip.address) & _ipv4ToInt(mask.address);
  final b = n | (~_ipv4ToInt(mask.address) & 0xffffffff);
  return InternetAddress(_intToIPv4(b));
}
