import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// A certificate authority trusted to sign host keys — one of OpenSSH's
/// `@cert-authority <hosts> <key>` lines in `known_hosts`.
///
/// A host whose certificate it signed is trusted without being asked about
/// (#1783); one it did not sign is pinned on first use, as before.
final class HostCertAuthority {
  const HostCertAuthority({required this.publicKey, required this.hosts});

  /// The authority's public key as OpenSSH writes it: `type base64 [comment]`.
  final String publicKey;

  /// Which hosts it vouches for, in `known_hosts` pattern syntax: comma
  /// separated, `*` and `?` wildcards, `!` to exclude. A host on a port other
  /// than 22 is matched as `[host]:port`, as OpenSSH matches it. Empty
  /// vouches for none, as a `@cert-authority` line without hosts is invalid.
  final String hosts;

  /// What a person pastes: a whole `known_hosts` line,
  /// `@cert-authority <hosts> <key>`, or a key line alone for [hosts].
  factory HostCertAuthority.parse(String text, {required String hosts}) {
    final parts = text.trim().split(_space);
    if (parts.length >= 3 && parts.first == '@cert-authority') {
      return HostCertAuthority(
        publicKey: parts.skip(2).join(' '),
        hosts: parts[1],
      );
    }
    return HostCertAuthority(publicKey: text.trim(), hosts: hosts.trim());
  }

  static final _space = RegExp(r'\s+');

  /// The key types dartssh2 verifies a certificate's signature with.
  static final _keyTypes = {
    SSHHostkeyType.ed25519.name,
    SSHHostkeyType.rsaSha1.name, // `ssh-rsa`, the key's type, not a signature
    SSHHostkeyType.ecdsa256.name,
    SSHHostkeyType.ecdsa384.name,
    SSHHostkeyType.ecdsa521.name,
  };

  List<String> get _parts => publicKey.trim().split(_space);

  /// The key's type, e.g. `ssh-ed25519`.
  String get type => _parts.first;

  /// What follows the key on its line, usually who it belongs to.
  String get comment => _parts.skip(2).join(' ');

  /// The key, SSH-encoded; null when [publicKey] is not a whole key of a
  /// type this app can use.
  Uint8List? get key {
    final parts = _parts;
    if (parts.length < 2 || !_keyTypes.contains(parts[0])) return null;
    final Uint8List blob;
    try {
      blob = base64.decode(parts[1]);
    } catch (_) {
      return null;
    }
    return _isWhole(parts[0], blob) ? blob : null;
  }

  /// Whether [blob] is a whole key of [type]: the type again, then exactly
  /// the fields it has, so a line cut short when pasted is not taken for one.
  static bool _isWhole(String type, Uint8List blob) {
    final fields = _strings(blob);
    if (fields == null || fields.isEmpty) return false;
    if (utf8.decode(fields[0], allowMalformed: true) != type) return false;
    return switch (type) {
      'ssh-ed25519' => fields.length == 2 && fields[1].length == 32,
      'ssh-rsa' => fields.length == 3 && fields[2].isNotEmpty,
      _ =>
        fields.length == 3 &&
            type ==
                'ecdsa-sha2-${utf8.decode(fields[1], allowMalformed: true)}' &&
            fields[2].isNotEmpty,
    };
  }

  /// [data] as SSH strings, each a length and its bytes; null when it does
  /// not split into them exactly.
  static List<Uint8List>? _strings(Uint8List data) {
    final view = ByteData.sublistView(data);
    final out = <Uint8List>[];
    var at = 0;
    while (at < data.length) {
      if (at + 4 > data.length) return null;
      final length = view.getUint32(at);
      at += 4;
      if (at + length > data.length) return null;
      out.add(Uint8List.sublistView(data, at, at + length));
      at += length;
    }
    return out;
  }

  /// Whether [hosts] names any host at all.
  bool get hasHosts => hosts.split(',').any((p) => p.trim().isNotEmpty);

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

  /// Whether this is [other] again: the same key for the same hosts,
  /// whatever its comment says.
  bool sameAs(HostCertAuthority other) {
    final a = key, b = other.key;
    if (a == null || b == null || hosts.trim() != other.hosts.trim()) {
      return false;
    }
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// What dartssh2 is told for [host], the one dialled: the authorities in
  /// [all] that vouch for it, and the names a certificate may list. Null when
  /// none vouch for it, which leaves the host to the first-use prompt.
  ///
  /// [alsoKnownAs] is the host as configured when another address was
  /// dialled: a certificate names the machine, whichever way it was reached.
  /// The authorities are scoped to the host dialled alone, and every name is
  /// lower-cased, as OpenSSH checks principals.
  static SSHHostCertificateTrust? trustFor(
    Iterable<HostCertAuthority> all, {
    required String host,
    required int port,
    Iterable<String> alsoKnownAs = const [],
  }) {
    final keys = [
      for (final ca in all)
        if (ca.matches(host, port)) ?ca.key,
    ];
    if (keys.isEmpty) return null;
    return SSHHostCertificateTrust(
      authorities: keys,
      principals: {
        for (final name in [host, ...alsoKnownAs]) name.toLowerCase(),
      }.toList(),
    );
  }

  factory HostCertAuthority.fromJson(Map<String, dynamic> json) =>
      HostCertAuthority(
        publicKey: json['publicKey'] as String,
        hosts: switch (json['hosts']) {
          final String hosts => hosts,
          _ => '',
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
