import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_key_unlock.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';

/// One end of a transfer: somewhere files live, and a path in it.
///
/// Serializable, because a transfer runs in an isolate and a live `SSHClient`
/// does not cross one. What travels is everything needed to *build* the
/// backend on the other side, which is why [SftpFileRef] carries a whole
/// credential bundle rather than a connection.
///
/// The counterpart of `FileBackend`: that one is a connection somebody already
/// has, this one is a description of how to get it.
sealed class FileRef {
  const FileRef();

  String get path;

  /// The last component. What a transfer list calls the job.
  String get name {
    final normalized = path.replaceAll(r'\', '/');
    final trimmed = normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    // The root has no last component but is still somewhere; without this it
    // would name itself the empty string.
    if (trimmed == '/') return '/';
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  /// A path inside this one, for naming a destination after its source.
  FileRef child(String name);
}

/// This device.
final class LocalFileRef extends FileRef {
  const LocalFileRef(this.path);

  @override
  final String path;

  @override
  LocalFileRef child(String name) =>
      LocalFileRef(path.joinPath(name, separator: '/'));

  @override
  bool operator ==(Object other) =>
      other is LocalFileRef && other.path == path;

  @override
  int get hashCode => Object.hash(LocalFileRef, path);

  @override
  String toString() => 'LocalFileRef($path)';
}

/// A server, over SFTP.
final class SftpFileRef extends FileRef {
  const SftpFileRef({required this.creds, required this.path});

  /// Built from a server the app knows about, resolving its keys now, on the
  /// isolate that has the stores.
  factory SftpFileRef.forServer(Spi spi, String path) =>
      SftpFileRef(creds: SshTransferCreds.forServer(spi), path: path);

  final SshTransferCreds creds;

  @override
  final String path;

  Spi get spi => creds.spi;

  /// Always `/`: the far side is a Linux-like system, whatever this device is.
  @override
  SftpFileRef child(String name) =>
      SftpFileRef(creds: creds, path: path.joinPath(name, separator: '/'));

  @override
  bool operator ==(Object other) =>
      other is SftpFileRef && other.path == path && other.spi.id == spi.id;

  @override
  int get hashCode => Object.hash(SftpFileRef, spi.id, path);

  @override
  String toString() => 'SftpFileRef(${spi.id}:$path)';
}

/// A server, through its `monitor` agent's file API.
///
/// Carries the credential rather than a client, for the same reason
/// [SftpFileRef] carries one — except that this one need not cross an isolate
/// at all: the agent is reached over HTTPS, whose crypto is native rather than
/// pure Dart, so a transfer with this at either end does not peg the UI
/// thread the way an SSH one would.
final class MonitorFileRef extends FileRef {
  const MonitorFileRef({required this.spi, required this.monitor, required this.path});

  factory MonitorFileRef.forServer(Spi spi, String path) {
    final credential = ServerConnectCredential.fromSpi(spi);
    return MonitorFileRef(
      spi: spi,
      monitor: (credential as ServerConnectCredentialMonitorHttp).monitor,
      path: path,
    );
  }

  final Spi spi;
  final MonitorHttpCredential monitor;

  @override
  final String path;

  /// Always `/`: the agent describes a POSIX-shaped filesystem whatever it is
  /// running on.
  @override
  MonitorFileRef child(String name) => MonitorFileRef(
    spi: spi,
    monitor: monitor,
    path: path.joinPath(name, separator: '/'),
  );

  @override
  bool operator ==(Object other) =>
      other is MonitorFileRef && other.path == path && other.spi.id == spi.id;

  @override
  int get hashCode => Object.hash(MonitorFileRef, spi.id, path);

  @override
  String toString() => 'MonitorFileRef(${spi.id}:$path)';
}

/// Everything needed to open an SSH connection somewhere else.
///
/// Read out of the stores when the transfer is queued rather than when it
/// runs, because the isolate that runs it has no stores — this is the whole
/// reason a transfer carries a bundle and not a server id.
class SshTransferCreds {
  SshTransferCreds.forServer(this.spi) {
    privateKeysByKeyId = {};

    // `resolvePrivateKey`, not `Stores.key` directly: a key may be a file this
    // machine holds rather than one the store does, and reading it has to
    // happen here, where there is a filesystem the user granted and a UI to
    // report a refusal to. The isolate has neither.
    final ssh = spi.ssh;
    if (ssh?.keyRef case final keyRef?) {
      privateKey = resolvePrivateKey(ssh!);
      if (privateKey != null) privateKeysByKeyId![keyRef] = privateKey!;
    }

    final allServers = {
      for (final server in Stores.server.fetch()) server.id: server,
    };
    jumpSpisById = collectJumpServers(spi: spi, serversById: allServers);

    final firstJumpId = spi.firstJumpId;
    if (firstJumpId != null) {
      jumpSpi = jumpSpisById?[firstJumpId];
      final jumpSsh = jumpSpi?.ssh;
      if (jumpSsh != null && jumpSsh.keyRef != null) {
        // A jump server whose key cannot be resolved is not fatal here: the
        // hop may authenticate by password, and failing the whole transfer at
        // queue time would take the other candidates with it.
        jumpPrivateKey = _tryResolve(jumpSsh);
        if (jumpPrivateKey != null) {
          privateKeysByKeyId![jumpSsh.keyRef!] = jumpPrivateKey!;
        }
      }
    }

    for (final jump in jumpSpisById?.values ?? const <Spi>[]) {
      final jumpSsh = jump.ssh;
      final jumpKeyRef = jumpSsh?.keyRef;
      if (jumpKeyRef == null || privateKeysByKeyId!.containsKey(jumpKeyRef)) {
        continue;
      }
      final key = _tryResolve(jumpSsh!);
      if (key == null) continue;
      privateKeysByKeyId![jumpKeyRef] = key;
    }

    if (jumpSpisById != null && jumpSpisById!.isEmpty) jumpSpisById = null;
    if (privateKeysByKeyId != null && privateKeysByKeyId!.isEmpty) {
      privateKeysByKeyId = null;
    }

    try {
      knownHostFingerprints = Map<String, String>.from(
        Stores.setting.sshKnownHostFingerprints.get(),
      );
    } catch (e, s) {
      Loggers.app.warning('Failed to load SSH known host fingerprints', e, s);
      knownHostFingerprints = null;
    }
  }

  /// [resolvePrivateKey] for a hop, or null if it could not be had.
  ///
  /// The target server's key is allowed to throw — a transfer to a host whose
  /// key is gone should say so at once. A jump server's is not: it may not need
  /// one, and one unusable candidate must not take the others with it.
  static String? _tryResolve(SshCredential ssh) {
    try {
      return resolvePrivateKey(ssh);
    } catch (e) {
      Loggers.app.warning('Jump server key unavailable', e);
      return null;
    }
  }

  final Spi spi;
  String? privateKey;
  Spi? jumpSpi;
  String? jumpPrivateKey;
  Map<String, Spi>? jumpSpisById;
  Map<String, String>? privateKeysByKeyId;

  Map<String, String>? knownHostFingerprints;

  /// Opens any key in this bundle that is stored encrypted.
  ///
  /// Not in the constructor, for two reasons that point the same way: asking
  /// for a passphrase is a dialog and the constructor is synchronous, and the
  /// isolate this bundle is *for* has no screen to ask on. A key that is still
  /// locked when it crosses can only fail over there, with nothing to say why.
  ///
  /// Awaited once, where the transfer starts. A key already opened this run
  /// costs nothing here.
  Future<void> unlockKeys() async {
    final keys = privateKeysByKeyId;
    if (keys == null) return;
    for (final ref in keys.keys.toList()) {
      final pem = keys[ref]!;
      if (!PrivateKeyUnlock.isLocked(pem)) continue;
      keys[ref] = await PrivateKeyUnlock.open(
        pem,
        cacheKey: ref,
        keyName: privateKeyDisplayName(ref),
      );
    }
    // The two hold the same string for the main server's key, so the copy
    // outside the map has to be moved along with it.
    final mainRef = spi.ssh?.keyRef;
    if (mainRef != null) privateKey = keys[mainRef] ?? privateKey;
    final jumpRef = jumpSpi?.ssh?.keyRef;
    if (jumpRef != null) jumpPrivateKey = keys[jumpRef] ?? jumpPrivateKey;
  }
}
