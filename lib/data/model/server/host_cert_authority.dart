import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// A certificate authority trusted to sign host keys — one of OpenSSH's
/// `@cert-authority <hosts> <key>` lines in `known_hosts`.
///
/// A host whose certificate it signed is trusted without being asked about
/// (#1783); one it did not sign is pinned on first use, as before.
final class HostCertAuthority {
  const HostCertAuthority({required this.publicKey, this.hosts = '*'});

  /// The authority's public key as OpenSSH writes it: `type base64 [comment]`.
  final String publicKey;

  /// Which hosts it vouches for, in `known_hosts` pattern syntax: comma
  /// separated, `*` and `?` wildcards, `!` to exclude. A host on a port other
  /// than 22 is matched as `[host]:port`, as OpenSSH matches it.
  final String hosts;

  static const _keyTypes = {
    'ssh-ed25519',
    'ssh-rsa',
    'ecdsa-sha2-nistp256',
    'ecdsa-sha2-nistp384',
    'ecdsa-sha2-nistp521',
  };

  /// The key, SSH-encoded; null when [publicKey] is not one this app can use.
  Uint8List? get key {
    final parts = publicKey.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || !_keyTypes.contains(parts[0])) return null;
    try {
      final blob = base64.decode(parts[1]);
      // The type is written twice, outside and inside the blob; a line whose
      // two disagree is not a key anyone generated.
      return SSHHostKey.getType(blob) == parts[0] ? blob : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether this vouches for [host] reached on [port].
  bool matches(String host, int port) {
    final name = (port == 22 ? host : '[$host]:$port').toLowerCase();
    var matched = false;
    for (final raw in hosts.split(',')) {
      final pattern = raw.trim().toLowerCase();
      if (pattern.isEmpty) continue;
      final negated = pattern.startsWith('!');
      final glob = negated ? pattern.substring(1) : pattern;
      if (!_glob(glob, name)) continue;
      if (negated) return false;
      matched = true;
    }
    return matched;
  }

  /// What dartssh2 is told for [host]: the authorities in [all] that vouch
  /// for it, and the name a certificate must list. Null when none do, which
  /// leaves the host to the first-use prompt.
  ///
  /// [host] is the one dialled: the authorities are scoped to it, and the
  /// certificate is checked against it, lower-cased as OpenSSH does.
  static SSHHostCertificateTrust? trustFor(
    Iterable<HostCertAuthority> all, {
    required String host,
    required int port,
  }) {
    final keys = [
      for (final ca in all)
        if (ca.matches(host, port)) ?ca.key,
    ];
    if (keys.isEmpty) return null;
    return SSHHostCertificateTrust(
      authorities: keys,
      principals: [host.toLowerCase()],
    );
  }

  factory HostCertAuthority.fromJson(Map<String, dynamic> json) =>
      HostCertAuthority(
        publicKey: json['publicKey'] as String,
        hosts: switch (json['hosts']) {
          final String hosts when hosts.trim().isNotEmpty => hosts,
          _ => '*',
        },
      );

  Map<String, dynamic> toJson() => {'publicKey': publicKey, 'hosts': hosts};

  @override
  bool operator ==(Object other) =>
      other is HostCertAuthority &&
      other.publicKey == publicKey &&
      other.hosts == hosts;

  @override
  int get hashCode => Object.hash(publicKey, hosts);
}

/// OpenSSH's `match_pattern`: `*` is any run of characters, `?` any one.
bool _glob(String pattern, String text) {
  var p = 0, t = 0, star = -1, mark = 0;
  while (t < text.length) {
    if (p < pattern.length &&
        (pattern[p] == '?' || pattern[p] == text[t])) {
      p++;
      t++;
    } else if (p < pattern.length && pattern[p] == '*') {
      star = p++;
      mark = t;
    } else if (star != -1) {
      p = star + 1;
      t = ++mark;
    } else {
      return false;
    }
  }
  while (p < pattern.length && pattern[p] == '*') {
    p++;
  }
  return p == pattern.length;
}
