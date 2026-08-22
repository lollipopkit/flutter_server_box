/// What the app is told about the Linux systems it can install.
///
/// The values used to be `switch` arms in [LinuxDistro]. They moved out
/// because they are data that changes on the distributions' schedule and not
/// on the app's: Rocky republishes its container base every few weeks, and a
/// pin compiled into a binary goes stale the day it does. `shellbox-rootfs`
/// publishes this, its CI follows upstream, and the app reads it.
///
/// ## What makes it safe to read
///
/// A manifest decides which bytes get downloaded and run, so whoever can
/// choose the manifest chooses what runs on the device. That is why the
/// fetched copy is signed and the public key is compiled in: the app decides
/// which key, the repository decides the contents, and a mirror still only
/// decides where the bytes come from. Verification lives in the layer that
/// fetches; this file is the shape and the parsing, and it parses strictly —
/// a missing or unrecognised field throws rather than defaulting, because a
/// default here would be a silent answer to "which bytes".
///
/// TODO(manifest rollout): the fetch, the signature check and the serial
/// rollback guard are not here yet. Until they are, the only manifest read is
/// the bundled asset, which is as trustworthy as the binary that carries it.
library;

import 'dart:convert';

import 'package:server_box/data/model/app/linux_distro.dart';

/// Where one system's bytes come from, and what shape they are in.
class RootfsSource {
  /// Absolute, and the only place a URL is allowed to come from.
  final String url;

  /// Of what [url] answers, whatever host serves it.
  final String sha256;

  /// Exact, so the install dialog can round it up itself rather than being
  /// told a number somebody else rounded.
  final int sizeBytes;

  final LinuxRootfsLayout layout;
  final LinuxRootfsCompression compression;

  /// Whether [url] is built under the mirror the user set.
  ///
  /// False for Ubuntu, whose base tarballs are on `cdimage.ubuntu.com` and
  /// whose packages are on `archive.ubuntu.com` — one mirror string cannot
  /// name both, and the one a person sets is the one they want packages from.
  final bool followsMirror;

  const RootfsSource({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.layout,
    required this.compression,
    required this.followsMirror,
  });

  factory RootfsSource.fromJson(Map<String, dynamic> json, String where) {
    return RootfsSource(
      url: _string(json, 'url', where),
      sha256: _sha256(json, 'sha256', where),
      sizeBytes: _positiveInt(json, 'size_bytes', where),
      layout: _enumByName(
        LinuxRootfsLayout.values,
        _string(json, 'layout', where),
        'layout',
        where,
      ),
      compression: _enumByName(
        LinuxRootfsCompression.values,
        _string(json, 'compression', where),
        'compression',
        where,
      ),
      followsMirror: _bool(json, 'follows_mirror', where),
    );
  }

  /// [sizeBytes] as whole megabytes, never rounded down.
  ///
  /// Understating a download is the failure that matters: the dialog is
  /// answered before anything is fetched, and on a metered connection 81 MB
  /// reported as 80 is a smaller lie than 3, but a lie in the same direction.
  int get sizeMb => (sizeBytes + 1048575) ~/ 1048576;
}

/// One installable system.
class RootfsDistro {
  /// Matches a [LinuxDistro] name. It is written into every installed
  /// system's marker file, so it outlives the manifest that introduced it.
  final String id;

  final String label;
  final String version;

  /// What the package manager reads as its release: a suite name for apt, a
  /// branch for apk, a major version for dnf.
  final String branch;

  /// `apk`, `apt`, `dnf`. Named when a system is about to be replaced,
  /// because what that destroys is whatever this put there.
  final String packageManager;

  final String defaultMirror;

  /// The repacked artifact, or null when nothing has been repacked for this
  /// one yet. Preferred over [upstream] when present.
  final RootfsSource? rootfs;

  /// The distribution's own file. Always present: it records where the
  /// repacked one came from, and it is what a device that cannot reach the
  /// repository falls back to.
  final RootfsSource upstream;

  const RootfsDistro({
    required this.id,
    required this.label,
    required this.version,
    required this.branch,
    required this.packageManager,
    required this.defaultMirror,
    required this.rootfs,
    required this.upstream,
  });

  /// What to download.
  RootfsSource get source => rootfs ?? upstream;

  factory RootfsDistro.fromJson(String id, Map<String, dynamic> json) {
    final where = 'distros.$id';
    final repacked = json['rootfs'];
    return RootfsDistro(
      id: id,
      label: _string(json, 'label', where),
      version: _string(json, 'version', where),
      branch: _string(json, 'branch', where),
      packageManager: _string(json, 'package_manager', where),
      defaultMirror: _mirror(json, 'default_mirror', where),
      rootfs: repacked == null
          ? null
          : RootfsSource.fromJson(
              _asMap(repacked, '$where.rootfs'),
              '$where.rootfs',
            ),
      upstream: RootfsSource.fromJson(
        _asMap(json['upstream'], '$where.upstream'),
        '$where.upstream',
      ),
    );
  }
}

/// A whole manifest.
class RootfsManifest {
  /// The shape of this file. A manifest declaring a schema this build does
  /// not know is refused rather than read partially — the fields it would
  /// skip could be the ones that matter.
  static const supportedSchema = 1;

  final int schema;

  /// Monotonic. A fetched manifest whose serial is below the highest already
  /// seen is refused: a signature stays valid forever, so replaying an old
  /// one would otherwise pin a device to a rootfs whose problems are known.
  final int serial;

  final DateTime generatedAt;

  /// When a *fetched* copy stops being acceptable. It does not apply to the
  /// bundled asset, which is part of the binary — expiring that would leave a
  /// long-offline device unable to install anything.
  final DateTime validUntil;

  final Map<String, RootfsDistro> distros;

  const RootfsManifest({
    required this.schema,
    required this.serial,
    required this.generatedAt,
    required this.validUntil,
    required this.distros,
  });

  static RootfsManifest parse(String source) {
    final Object? decoded;
    try {
      decoded = json.decode(source);
    } on FormatException catch (e) {
      throw RootfsManifestException('not JSON: ${e.message}');
    }
    final root = _asMap(decoded, 'the manifest');

    final schema = _positiveInt(root, 'schema', 'the manifest');
    if (schema != supportedSchema) {
      throw RootfsManifestException(
        'schema $schema, and this build reads $supportedSchema',
      );
    }

    final distros = _asMap(root['distros'], 'distros');
    if (distros.isEmpty) {
      throw const RootfsManifestException('distros is empty');
    }

    return RootfsManifest(
      schema: schema,
      serial: _positiveInt(root, 'serial', 'the manifest'),
      generatedAt: _time(root, 'generated_at', 'the manifest'),
      validUntil: _time(root, 'valid_until', 'the manifest'),
      distros: {
        for (final entry in distros.entries)
          entry.key: RootfsDistro.fromJson(
            entry.key,
            _asMap(entry.value, 'distros.${entry.key}'),
          ),
      },
    );
  }
}

/// A manifest that could not be read. Never a reason to carry on with a
/// partial one: the caller falls back to a copy it already trusts.
class RootfsManifestException implements Exception {
  final String message;
  const RootfsManifestException(this.message);

  @override
  String toString() => 'The rootfs manifest is unusable: $message';
}

Map<String, dynamic> _asMap(Object? value, String where) {
  if (value is Map<String, dynamic>) return value;
  throw RootfsManifestException('$where is not an object');
}

String _string(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw RootfsManifestException('$where.$key is not a string');
}

/// Lower-case hex, 64 characters. Checked here rather than where the download
/// is compared, so a malformed digest is a rejected manifest and not a
/// comparison that quietly never matches.
String _sha256(Map<String, dynamic> json, String key, String where) {
  final value = _string(json, key, where);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw RootfsManifestException('$where.$key is not a sha256 digest');
  }
  return value;
}

/// No trailing slash: callers join a path onto it.
String _mirror(Map<String, dynamic> json, String key, String where) {
  final value = _string(json, key, where);
  if (value.endsWith('/')) {
    throw RootfsManifestException('$where.$key ends with a slash');
  }
  if (!value.startsWith('https://') && !value.startsWith('http://')) {
    throw RootfsManifestException('$where.$key is not an http(s) URL');
  }
  return value;
}

int _positiveInt(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is int && value > 0) return value;
  throw RootfsManifestException('$where.$key is not a positive integer');
}

bool _bool(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is bool) return value;
  throw RootfsManifestException('$where.$key is not a boolean');
}

DateTime _time(Map<String, dynamic> json, String key, String where) {
  final value = _string(json, key, where);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw RootfsManifestException('$where.$key is not a timestamp');
  }
  return parsed.toUtc();
}

T _enumByName<T extends Enum>(
  List<T> values,
  String name,
  String key,
  String where,
) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  // By name and never by index, for the reason the marker file stores names:
  // an index silently changes meaning when a case is inserted.
  throw RootfsManifestException('$where.$key is not a known $key: $name');
}
